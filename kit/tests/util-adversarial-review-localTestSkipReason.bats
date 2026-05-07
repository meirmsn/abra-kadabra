#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh's localTestSkipReason check-type.
# Added in sub-fix 1 of cheap-test-gates-local — judges bypass reasons for the
# changed-tests-local pre-ship gate (#2d).
# Spec: specs/cheap-test-gates-local/spec.md § D7, § Tests.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"
  CAPTURED_MODEL="$BATS_TEST_TMPDIR/captured-model.txt"

  # Mock `claude` to capture stdin + the --model arg, and return whatever
  # MOCK_CLAUDE_VERDICT says (default PASS).
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
# Capture --model argument
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
  # Make the test repo look devshop-self by adding a real kit/ dir.
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"
}

# === New check-type wired correctly (no "unknown") ===

@test "localTestSkipReason: case statement recognized (no 'unknown check type')" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific reason naming each category and TODOS pointer"
  # MUST NOT fall through to the unknown-check-type branch.
  refute_output --partial "unknown check type"
}

@test "localTestSkipReason: prompt header includes 'Check type: localTestSkipReason'" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific reason — see TODOS.md § X"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: localTestSkipReason" "$CAPTURED_PROMPT"
}

@test "localTestSkipReason: prompt context includes the diff-paths section" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific reason"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Diff paths" "$CAPTURED_PROMPT"
}

@test "localTestSkipReason: prompt context names the four test categories the gate runs" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "parse-check" "$CAPTURED_PROMPT"
  grep -q "changed E2E" "$CAPTURED_PROMPT"
  grep -q "changed integration" "$CAPTURED_PROMPT"
  grep -q "smoke set" "$CAPTURED_PROMPT"
}

@test "localTestSkipReason: prompt rules include rule #10 with the four PASS sub-criteria" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific"
  [ -f "$CAPTURED_PROMPT" ]
  # Rule 10 mirrors testReviewSkipReason's shape with (a)-(d).
  grep -q "^10\. For localTestSkipReason" "$CAPTURED_PROMPT"
  grep -q "Per-finding engagement" "$CAPTURED_PROMPT"
  grep -q "core-flow dismissal" "$CAPTURED_PROMPT"
  grep -q "silent-broken-env" "$CAPTURED_PROMPT"
}

# === Sonnet routing ===

@test "localTestSkipReason: routes to Sonnet (high-blast-radius, judgment-heavy)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" localTestSkipReason "specific reason"
  [ -f "$CAPTURED_MODEL" ]
  grep -q "sonnet" "$CAPTURED_MODEL"
}

# === FAIL paths (claude returns FAIL) ===

@test "localTestSkipReason: weak reason 'will fix later' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'will fix later' is generic; name a TODOS.md entry"
  run bash "$REVIEW" localTestSkipReason "will fix later"
  assert_failure
  assert_output --partial "FAIL"
}

@test "localTestSkipReason: weak reason 'ran out of time' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'ran out of time' is exactly the pattern rule 10 calls out"
  run bash "$REVIEW" localTestSkipReason "ran out of time"
  assert_failure
  assert_output --partial "FAIL"
}

@test "localTestSkipReason: weak reason 'low risk' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'low risk' has no per-category rationale"
  run bash "$REVIEW" localTestSkipReason "low risk"
  assert_failure
  assert_output --partial "FAIL"
}

# === PASS paths ===

@test "localTestSkipReason: specific reason naming category + TODOS pointer → PASS" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" localTestSkipReason "skipping smoke set because pnpm dev wedges in this devcontainer (TODOS.md § wedge); changed E2E specs ran fine; CI smoke job will catch any regression"
  assert_success
}

# === Diff path enumeration in context ===

@test "localTestSkipReason: stages a diff path into context when origin/main exists" {
  cd "$TEST_REPO"
  # Set up origin/main → first commit; HEAD has a stack-needing path.
  echo "base" > base.md
  git add base.md
  git commit -q -m "baseline"
  git update-ref refs/remotes/origin/main HEAD
  mkdir -p apps/web/components
  echo "x" > apps/web/components/Foo.tsx
  git add -A
  git commit -q -m "add Foo"

  run bash "$REVIEW" localTestSkipReason "specific"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "apps/web/components/Foo.tsx" "$CAPTURED_PROMPT"
}

@test "localTestSkipReason: graceful degrade when origin/main is missing (HEAD~1 fallback)" {
  cd "$TEST_REPO"
  # Two commits, no origin/main. HEAD~1 exists.
  mkdir -p apps/web/components
  echo "x" > apps/web/components/Foo.tsx
  git add -A
  git commit -q -m "add Foo"

  run bash "$REVIEW" localTestSkipReason "specific"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "apps/web/components/Foo.tsx" "$CAPTURED_PROMPT"
}

# === Survived narrowing test (no longer "unknown" but old narrowing assertions also hold) ===

@test "localTestSkipReason: enumerated in unknown-check-type fallback message" {
  cd "$TEST_REPO"
  # Trigger the unknown-check-type branch and assert localTestSkipReason is now in the surviving list.
  run bash "$REVIEW" madeUpCheck "x"
  assert_failure
  assert_output --partial "localTestSkipReason"
}
