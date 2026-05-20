#!/usr/bin/env bats
# Tests for kit/scripts/preship/fault-injected-qa.sh
# Gate 9 fault-injection sub-step — detects Tier A2 surfaces, verifies
# matching Playwright harnesses, orchestrates per-surface runs.

bats_require_minimum_version 1.5.0  # for `run --separate-stderr`

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPT="$SCRIPTS_DIR/preship/fault-injected-qa.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK/apps/web/components" "$WORK/apps/web/e2e/fault-injected" "$WORK/packages/ui/src"
  # Init a git repo so `git -C ... config` calls don't error.
  git -C "$WORK" init -q
  git -C "$WORK" config user.email "test@test"
  git -C "$WORK" config user.name "test"
}

# Write a spec with a `## Surface mapping` table containing the given rows.
# Each row arg is a "|"-prefixed table row, e.g.:
#   write_spec_with_table "| AddItemSheet save | A2 | hook [route:/api/items] |"
write_spec_with_table() {
  local spec="$WORK/spec.md"
  {
    echo "# Spec"
    echo ""
    echo "## Decisions"
    echo ""
    echo "### Surface mapping"
    echo ""
    echo "| Surface | Tier | Notes |"
    echo "|---------|------|-------|"
    for row in "$@"; do echo "$row"; done
    echo ""
    echo "## In scope"
  } > "$spec"
}

write_empty_spec() {
  echo "# Empty spec" > "$WORK/spec.md"
}

# --- detect-surfaces: spec-table primary ---

@test "detect-surfaces: extracts single A2 row from spec table" {
  write_spec_with_table "| AddItemSheet save | A2 | useOptimisticMutation({ failureMode: 'banner' }) [route:/api/items] |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "add-item-sheet-save"
  assert_output --partial "/api/items"
}

@test "detect-surfaces: splits camelCase boundaries into kebab-case slug" {
  write_spec_with_table "| addItem saveButton | A2 | hook |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Inserts a dash before each Upper preceded by a lowercase/digit;
  # consecutive caps (e.g. "HTML") are NOT split — only the boundary case.
  assert_output --partial "add-item-save-button"
}

@test "detect-surfaces: ignores non-A2 rows (A1, C, D)" {
  write_spec_with_table \
    "| Toggle row | A1 | rollback |" \
    "| List nav | C | LoadingArea |" \
    "| Theme switch | D | CSS only |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output ""
}

@test "detect-surfaces: returns multiple A2 rows" {
  write_spec_with_table \
    "| AddItemSheet save | A2 | hook [route:/api/items] |" \
    "| EditRow submit | A2 | hook [route:/api/rows] |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "add-item-sheet-save"
  assert_output --partial "edit-row-submit"
}

@test "detect-surfaces: extracts route hint from [route:...] annotation" {
  write_spec_with_table "| Save | A2 | hook [route:/functions/v1/save] |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Tab-separated columns: slug<TAB>notes<TAB>route
  [[ "$output" == *$'\t/functions/v1/save' ]]
}

@test "detect-surfaces: emits empty route when no annotation present" {
  write_spec_with_table "| Save | A2 | hook |"
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Exact format: <slug>\t<notes>\t<route> — route empty leaves trailing tab.
  assert_equal "$output" $'save\thook\t'
}

@test "detect-surfaces: scopes table parse to Surface mapping section only" {
  cat > "$WORK/spec.md" <<'EOF'
# Spec

## Surface mapping

| Surface | Tier | Notes |
|---------|------|-------|
| RealOne | A2 | hook |

## Some other table

| Name | Tier | x |
|------|------|---|
| FakeOne | A2 | should not be picked up |
EOF
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "real-one"
  refute_output --partial "fake-one"
}

# --- detect-surfaces: heuristic grep fallback ---

@test "detect-surfaces: falls back to grep when spec table is empty" {
  write_empty_spec
  cat > "$WORK/apps/web/components/SaveSheet.tsx" <<'EOF'
import { useOptimisticMutation } from '@/lib/hooks'
export function SaveSheet() {
  const m = useOptimisticMutation({
    failureMode: 'banner',
    bannerLabel: 'Could not save',
  })
  return null
}
EOF
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "save-sheet"
  assert_output --partial "apps/web/components/SaveSheet.tsx"
}

@test "detect-surfaces: grep fallback ignores rollback-mode call sites" {
  write_empty_spec
  cat > "$WORK/apps/web/components/Toggle.tsx" <<'EOF'
import { useOptimisticMutation } from '@/lib/hooks'
export function Toggle() {
  const m = useOptimisticMutation({ failureMode: 'rollback' })
  return null
}
EOF
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output ""
}

@test "detect-surfaces: grep fallback ignores files lacking the hook entirely" {
  write_empty_spec
  cat > "$WORK/apps/web/components/Plain.tsx" <<'EOF'
export function Plain() { return null }
EOF
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output ""
}

@test "detect-surfaces: spec table presence suppresses grep fallback (authoritative)" {
  # Spec declares one A2 row; src tree has a different call site.
  # Result: only the spec row is reported.
  write_spec_with_table "| FromSpec | A2 | hook |"
  cat > "$WORK/apps/web/components/FromCode.tsx" <<'EOF'
import { useOptimisticMutation } from '@/lib/hooks'
export const FromCode = () => useOptimisticMutation({ failureMode: 'banner' })
EOF
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "from-spec"
  refute_output --partial "from-code"
}

# --- verify-harness ---

@test "verify-harness: exits 0 when all slugs have matching spec files" {
  touch "$WORK/apps/web/e2e/fault-injected/a.spec.ts" \
        "$WORK/apps/web/e2e/fault-injected/b.spec.ts"
  run bash "$SCRIPT" verify-harness --slugs a,b --root "$WORK"
  assert_success
}

@test "verify-harness: exits non-zero with missing slugs on stderr (not stdout)" {
  touch "$WORK/apps/web/e2e/fault-injected/a.spec.ts"
  run --separate-stderr bash "$SCRIPT" verify-harness --slugs a,b,c --root "$WORK"
  assert_failure
  # The missing list must land on stderr (cmd_run consumes it via 2>&1).
  [[ "$stderr" == *"b,c"* ]]
  # And NOT on stdout — a silent stdout/stderr swap would otherwise pass.
  [ -z "$output" ]
}

@test "verify-harness: tolerates whitespace around slug names" {
  touch "$WORK/apps/web/e2e/fault-injected/a.spec.ts"
  run bash "$SCRIPT" verify-harness --slugs "  a  " --root "$WORK"
  assert_success
}

# --- run: scope-exempt pass path ---

@test "run: emits scope-exempt pass when no Tier A2 surfaces detected" {
  write_empty_spec
  run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "pass (no Tier A2 surfaces in scope)"
}

# --- run: blocked path ---

@test "run: emits blocked when A2 surface detected but harness missing" {
  write_spec_with_table "| AddItem | A2 | hook |"
  # No harness file at apps/web/e2e/fault-injected/add-item.spec.ts
  run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "blocked (missing fault-injected harness:"
  assert_output --partial "add-item"
}

# --- run: Playwright-stub paths (pass + findings) ---

@test "run: emits pass when Playwright stub succeeds for every surface" {
  write_spec_with_table "| AddItem | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts"
  # /bin/true exits 0 — every surface "passes" the stubbed Playwright invocation.
  PLAYWRIGHT_BIN=/bin/true run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  # Final outcome line is exactly "pass" — not scope-exempt, not bypassed.
  [[ "${lines[-1]}" == "pass" ]]
  # Per-surface JSON output written under specs/<feature>/gates/.
  [ -f "$WORK/specs/foo/gates/fault-injected-add-item.json" ]
}

@test "run: emits findings (N) when Playwright stub fails per-surface" {
  write_spec_with_table "| AddItem | A2 | hook |" "| EditRow | A2 | hook |"
  touch "$WORK/apps/web/e2e/fault-injected/add-item.spec.ts" \
        "$WORK/apps/web/e2e/fault-injected/edit-row.spec.ts"
  # /bin/false exits 1 — every surface "fails" the stubbed Playwright run.
  PLAYWRIGHT_BIN=/bin/false run bash "$SCRIPT" run --feature foo --spec "$WORK/spec.md" --root "$WORK"
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "add-item"
  assert_output --partial "edit-row"
}

# --- detect-surfaces: --diff-range coverage ---

@test "detect-surfaces: --diff-range scopes grep fallback to changed files only" {
  # Baseline commit with one pre-existing A2 call site.
  write_empty_spec
  cat > "$WORK/apps/web/components/Existing.tsx" <<'EOF'
import { useOptimisticMutation } from '@/lib/hooks'
export const Existing = () => useOptimisticMutation({ failureMode: 'banner' })
EOF
  git -C "$WORK" add -A
  git -C "$WORK" commit -q -m "baseline"
  # New commit adds a fresh call site.
  cat > "$WORK/apps/web/components/Fresh.tsx" <<'EOF'
import { useOptimisticMutation } from '@/lib/hooks'
export const Fresh = () => useOptimisticMutation({ failureMode: 'banner' })
EOF
  git -C "$WORK" add -A
  git -C "$WORK" commit -q -m "new surface"
  # --diff-range should yield only the new file, not the pre-existing one.
  run bash "$SCRIPT" detect-surfaces --spec "$WORK/spec.md" --root "$WORK" --diff-range HEAD~1..HEAD
  assert_success
  assert_output --partial "fresh"
  refute_output --partial "existing"
}

# --- error handling ---

@test "detect-surfaces: errors when --spec is missing" {
  run bash "$SCRIPT" detect-surfaces
  assert_failure
  assert_output --partial "--spec is required"
}

@test "verify-harness: errors when --slugs is missing" {
  run bash "$SCRIPT" verify-harness --root "$WORK"
  assert_failure
  assert_output --partial "--slugs is required"
}

@test "main: errors on unknown subcommand" {
  run bash "$SCRIPT" frobnicate
  assert_failure
  assert_output --partial "unknown subcommand: frobnicate"
}
