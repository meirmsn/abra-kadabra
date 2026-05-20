#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh's blockedGateOverride check-type.
# Added with the mechanical Phase 3 → 4 halt — judges operator override reasons
# when /ak-build's AskUserQuestion advances past a `blocked` gate. Companion to
# the existing dismissalLog tests (rationale judgment) — blockedGateOverride
# judges a stronger claim (the gate didn't run at all).

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"
  CAPTURED_MODEL="$BATS_TEST_TMPDIR/captured-model.txt"

  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--model" ]; then
    echo "\$2" > "$CAPTURED_MODEL"
    shift 2
    continue
  fi
  shift
done
cat > "$CAPTURED_PROMPT"
echo "\${MOCK_CLAUDE_VERDICT:-PASS - mocked}"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"

  # Stage a spec + review.md so the case branch's spec-scope and
  # advance-log inlining have content to grab.
  mkdir -p "$TEST_REPO/specs/demo"
  cat > "$TEST_REPO/specs/demo/spec.md" <<'SPEC'
# demo

## Core user story

User adds an item to their list and sees it persist after refresh.

## In scope

- Add-item form on apps/web/app/items/page.tsx
- Persist to items table via /api/items
- /qa walk validates the add → refresh → persist loop
SPEC
  cat > "$TEST_REPO/specs/demo/review.md" <<'REVIEW'
## Gate 8: /design-review

- Result: blocked (chromium unavailable in sandbox)
REVIEW
}

# === New check-type wired correctly (no "unknown") ===

@test "blockedGateOverride: case statement recognized (no 'unknown check type')" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason naming the gate + tracker" \
    "Gate 8: /design-review" "kit/TODOS.md § chromium-image-roll" \
    "$TEST_REPO/specs/demo/review.md"
  refute_output --partial "unknown check type"
}

@test "blockedGateOverride: prompt header includes 'Check type: blockedGateOverride'" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: blockedGateOverride" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt context names the gate being overridden" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Gate being overridden: Gate 8: /design-review" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt context inlines the follow-up tracker pointer" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § chromium-image-roll" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "kit/TODOS.md § chromium-image-roll" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt context inlines spec § Core user story (off-limits surface)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "MUST NOT be waived by override" "$CAPTURED_PROMPT"
  grep -q "adds an item to their list" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt context inlines spec § In scope (contract surface)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "what this PR committed to" "$CAPTURED_PROMPT"
  grep -q "/qa walk validates" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt context flags missing tracker pointer" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "not provided — automatic FAIL per rule 12(c)" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt rules include rule #12 with the four PASS sub-criteria" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "^12\. For blockedGateOverride" "$CAPTURED_PROMPT"
  grep -q "Gate-specific reason" "$CAPTURED_PROMPT"
  grep -q "core-story crossing" "$CAPTURED_PROMPT"
  grep -q "Verifiable follow-up tracker" "$CAPTURED_PROMPT"
  grep -q "In-scope contradiction" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: prompt rules reject precedent framing explicitly" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "matches PR #27" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  # The rule names the exact precedent phrasings the home-os PRs used.
  grep -q "matches PR #27" "$CAPTURED_PROMPT"
  grep -q "we've done this before" "$CAPTURED_PROMPT"
}

# === Sonnet routing ===

@test "blockedGateOverride: routes to Sonnet (judgment-heavy, high-blast-radius)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific reason" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_MODEL" ]
  grep -q "sonnet" "$CAPTURED_MODEL"
}

# === FAIL paths (claude returns FAIL) ===

@test "blockedGateOverride: 'matches the decide-state precedent' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: precedent framing is exactly what rule 12(a) rejects"
  run bash "$REVIEW" blockedGateOverride "matches the decide-state precedent" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  assert_failure
  assert_output --partial "FAIL"
}

@test "blockedGateOverride: 'sandbox env, will fix' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: generic + no tracker pointer"
  run bash "$REVIEW" blockedGateOverride "sandbox env, will fix" \
    "Gate 8: /design-review" "" \
    "$TEST_REPO/specs/demo/review.md"
  assert_failure
  assert_output --partial "FAIL"
}

# === PASS paths ===

@test "blockedGateOverride: gate-specific reason + verifiable tracker → PASS" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" blockedGateOverride \
    "Chromium not installable in this devcontainer image; /design-review will run in CI on the host build (tracked kit/TODOS.md § chromium-image-roll)" \
    "Gate 8: /design-review" "kit/TODOS.md § chromium-image-roll" \
    "$TEST_REPO/specs/demo/review.md"
  assert_success
}

# === Prior advance-log precedent surface ===

@test "blockedGateOverride: prompt inlines prior advance-log entries from review.md" {
  cd "$TEST_REPO"
  cat >> "$TEST_REPO/specs/demo/review.md" <<'PRIOR'

## Phase 3 → 4 advance log

### 2026-05-17T12:00:00Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** Prior PR's identical wording — sandbox env
**Follow-up tracker:** kit/TODOS.md § chromium-image-roll
<!-- adversarial-review-stamp: blockedGateOverride PASS @ 2026-05-17T12:00:00Z -->
PRIOR
  run bash "$REVIEW" blockedGateOverride "specific" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    "$TEST_REPO/specs/demo/review.md"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Prior advance-log entries" "$CAPTURED_PROMPT"
  grep -q "Prior PR's identical wording" "$CAPTURED_PROMPT"
}

@test "blockedGateOverride: graceful degrade when review.md path is empty" {
  cd "$TEST_REPO"
  run bash "$REVIEW" blockedGateOverride "specific" \
    "Gate 8: /design-review" "kit/TODOS.md § x" \
    ""
  [ -f "$CAPTURED_PROMPT" ]
  # No crash. The "Spec § Core user story" block prints the (not declared) fallback.
  grep -q "not declared — spec lacks Core user story section" "$CAPTURED_PROMPT"
}

# === Survived narrowing test ===

@test "blockedGateOverride: enumerated in unknown-check-type fallback message" {
  cd "$TEST_REPO"
  run bash "$REVIEW" madeUpCheck "x"
  assert_failure
  assert_output --partial "blockedGateOverride"
}
