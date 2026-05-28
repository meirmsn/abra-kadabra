#!/usr/bin/env bats
# Tests for kit/scripts/preship/roster-check.sh
# Track B roster: gate completeness enforcement + hero capture validation.
# See specs/local-env-pillar/spec.md § T2, § Tests.

setup() {
  load helpers/setup
  SCRIPT="$SCRIPTS_DIR/preship/roster-check.sh"

  # Create fixture directories.
  GATES_DIR="$BATS_TEST_TMPDIR/gates"
  HERO_DIR="$BATS_TEST_TMPDIR/hero"
  PREFLIGHT_SINK="$GATES_DIR/preflight.md"
  mkdir -p "$GATES_DIR" "$HERO_DIR"

  # Write a default preflight sink with all scope vars set (full-scope PR).
  cat > "$PREFLIGHT_SINK" <<'EOF'
## Preflight

- TOUCHES_UI=apps/web/components/Foo.tsx
- TOUCHES_MIGRATIONS=supabase/migrations/001.sql
- TOUCHES_FUNCTIONS=supabase/functions/hello/index.ts
- TOUCHES_KIT=kit/scripts/foo.sh
- TOUCHES_CODE=apps/web/components/Foo.tsx
- TOUCHES_USER_CODE=apps/web/components/Foo.tsx
- HAS_TURBO=yes
- Chromium: yes
- Supabase: ok: local Supabase up
- Supabase healthy: yes
- Result: pass
EOF

  # Create all expected gate sinks for a full-scope PR.
  # Always-run:
  for gate in simplify docs-and-tests-review review cso qa convention slow-job-lifecycle design-conformance; do
    echo "## Gate: $gate" > "$GATES_DIR/${gate}.md"
    echo "- Result: pass" >> "$GATES_DIR/${gate}.md"
  done
  # UI-conditional:
  for gate in responsive-theme design-review benchmark; do
    echo "## Gate: $gate" > "$GATES_DIR/${gate}.md"
    echo "- Result: pass" >> "$GATES_DIR/${gate}.md"
  done
  # Turbo-conditional:
  for gate in fast-job-local preflight-final; do
    echo "## Gate: $gate" > "$GATES_DIR/${gate}.md"
    echo "- Result: pass" >> "$GATES_DIR/${gate}.md"
  done
  # Kit-conditional:
  echo "## Gate: docs-check" > "$GATES_DIR/docs-check.md"
  # Migration-conditional:
  for gate in rls-coverage migration-rollback-roundtrip advisor-clean; do
    echo "## Gate: $gate" > "$GATES_DIR/${gate}.md"
  done
  # Code-conditional:
  echo "## Gate: changed-tests-local" > "$GATES_DIR/changed-tests-local.md"
  # User-code-conditional:
  echo "## Gate: metrics-check" > "$GATES_DIR/metrics-check.md"

  # Default hero: PNGs present.
  touch "$HERO_DIR/screenshot-01.png"
}

# Helper: run roster-check with fixture dirs.
run_roster() {
  run bash "$SCRIPT" "$PREFLIGHT_SINK" "$GATES_DIR" "$HERO_DIR"
}

# --- exits 0 when all expected sinks present ---

@test "exits 0 when all expected sinks present (full-scope PR)" {
  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

# --- exits 1 and lists missing gates on incomplete roster ---

@test "exits 1 and lists missing gates when review sink is absent" {
  rm "$GATES_DIR/review.md"
  run_roster
  assert_failure
  assert_output --partial "ROSTER INCOMPLETE"
  assert_output --partial "review"
}

@test "exits 1 and lists multiple missing gates" {
  rm "$GATES_DIR/review.md" "$GATES_DIR/cso.md" "$GATES_DIR/qa.md"
  run_roster
  assert_failure
  assert_output --partial "review"
  assert_output --partial "cso"
  assert_output --partial "qa"
}

# --- scope-conditional gates: absent on non-UI diff = ok ---

@test "non-UI diff: UI-only gates absent is ok" {
  # Rewrite preflight sink with no UI, no migrations, no functions.
  cat > "$PREFLIGHT_SINK" <<'EOF'
## Preflight

- TOUCHES_UI=
- TOUCHES_MIGRATIONS=
- TOUCHES_FUNCTIONS=
- TOUCHES_KIT=kit/scripts/foo.sh
- TOUCHES_CODE=apps/web/lib/utils.ts
- TOUCHES_USER_CODE=apps/web/lib/utils.ts
- HAS_TURBO=yes
- Chromium: not available
- Supabase: ok
- Result: pass
EOF

  # Remove UI-only and migration-only sinks (not expected for this scope).
  rm -f "$GATES_DIR/responsive-theme.md" "$GATES_DIR/design-review.md" "$GATES_DIR/benchmark.md"
  rm -f "$GATES_DIR/rls-coverage.md" "$GATES_DIR/migration-rollback-roundtrip.md" "$GATES_DIR/advisor-clean.md"

  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

@test "non-turbo project: turbo-only gates absent is ok" {
  # Remove HAS_TURBO.
  cat > "$PREFLIGHT_SINK" <<'EOF'
## Preflight

- TOUCHES_UI=apps/web/components/Foo.tsx
- TOUCHES_MIGRATIONS=supabase/migrations/001.sql
- TOUCHES_FUNCTIONS=supabase/functions/hello/index.ts
- TOUCHES_KIT=kit/scripts/foo.sh
- TOUCHES_CODE=apps/web/components/Foo.tsx
- TOUCHES_USER_CODE=apps/web/components/Foo.tsx
- HAS_TURBO=
- Chromium: yes
- Supabase: ok
- Result: pass
EOF

  rm -f "$GATES_DIR/fast-job-local.md" "$GATES_DIR/preflight-final.md"

  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

# --- hero capture: PNGs present = ok ---

@test "hero capture: PNGs present passes" {
  # Already have PNGs from setup.
  run_roster
  assert_success
}

# --- hero capture: SKIP.md with valid reason = ok ---

@test "hero capture: SKIP.md with 'non-UI PR' reason passes" {
  rm -f "$HERO_DIR/"*.png
  cat > "$HERO_DIR/SKIP.md" <<'EOF'
# Hero Screenshot Skip

Reason: non-UI PR
EOF
  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

@test "hero capture: SKIP.md with 'Chromium unavailable' reason passes" {
  rm -f "$HERO_DIR/"*.png
  cat > "$HERO_DIR/SKIP.md" <<'EOF'
# Hero Screenshot Skip

Reason: Chromium unavailable
EOF
  run_roster
  assert_success
}

@test "hero capture: bulleted '- Reason: non-UI PR (context)' passes (SKILL.md format)" {
  rm -f "$HERO_DIR/"*.png
  cat > "$HERO_DIR/SKIP.md" <<'EOF'
# Hero capture skipped

- Reason: non-UI PR (TOUCHES_UI empty — diff does not touch apps/, packages/ui/, or components/)
- Date: 2026-05-27T10:00:00Z
- SHA: abc1234
EOF
  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

# --- hero capture: SKIP.md with unknown reason = fail ---

@test "hero capture: SKIP.md with unknown reason fails" {
  rm -f "$HERO_DIR/"*.png
  cat > "$HERO_DIR/SKIP.md" <<'EOF'
# Hero Screenshot Skip

Reason: ran out of time
EOF
  run_roster
  assert_failure
  assert_output --partial "ROSTER INCOMPLETE"
  assert_output --partial "hero-capture"
  assert_output --partial "unknown reason"
}

# --- hero capture: missing Reason line = fail ---

@test "hero capture: SKIP.md without Reason line fails" {
  rm -f "$HERO_DIR/"*.png
  cat > "$HERO_DIR/SKIP.md" <<'EOF'
# Hero Screenshot Skip

We skipped because reasons.
EOF
  run_roster
  assert_failure
  assert_output --partial "hero-capture"
  assert_output --partial "missing Reason: line"
}

# --- hero capture: neither present = fail ---

@test "hero capture: no PNGs and no SKIP.md fails" {
  rm -f "$HERO_DIR/"*.png
  run_roster
  assert_failure
  assert_output --partial "hero-capture"
  assert_output --partial "no PNGs and no SKIP.md"
}

# --- preflight sink parsing ---

@test "preflight sink parsing matches SKILL.md format (leading bullet)" {
  # Verify the script reads the "- TOUCHES_UI=" format correctly.
  # Write a sink with only TOUCHES_KIT set (the rest empty).
  cat > "$PREFLIGHT_SINK" <<'EOF'
## Preflight

- TOUCHES_UI=
- TOUCHES_MIGRATIONS=
- TOUCHES_FUNCTIONS=
- TOUCHES_KIT=kit/docs/guide/foo.md
- TOUCHES_CODE=
- TOUCHES_USER_CODE=
- HAS_TURBO=
- Result: pass
EOF

  # Only always-run + docs-check should be expected.
  # Remove all conditional gate sinks that won't be expected.
  rm -f "$GATES_DIR/responsive-theme.md" "$GATES_DIR/design-review.md" "$GATES_DIR/benchmark.md"
  rm -f "$GATES_DIR/fast-job-local.md" "$GATES_DIR/preflight-final.md"
  rm -f "$GATES_DIR/rls-coverage.md" "$GATES_DIR/migration-rollback-roundtrip.md" "$GATES_DIR/advisor-clean.md"
  rm -f "$GATES_DIR/changed-tests-local.md" "$GATES_DIR/metrics-check.md"

  run_roster
  assert_success
  assert_output --partial "ROSTER COMPLETE"
}

# --- usage error ---

@test "exits 64 on missing arguments" {
  run bash "$SCRIPT"
  assert_failure
  [ "$status" -eq 64 ]
  assert_output --partial "Usage:"
}
