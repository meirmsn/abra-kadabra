#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh narrowing (PR-C of the audit-time
# docs+tests migration — see kit/ROADMAP.md § PR-C § F).
#
# After PR-C, the case statement carries only bypass-reason check-types:
#   prDescStaleReason, dirtyTreeReason, dirtyPushReason, manifestReviewed,
#   hookBypass, exemptAddition, dismissalLog
# Coverage-judging check-types moved to audit-time `/ak-check-docs-and-tests`:
#   docsReviewed, testCoverage, testCoverageProject, docsFreshnessProject
# Calling the script with one of those should fail with "unknown check type"
# rather than firing the old code path.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"

  # Mock `claude` to capture stdin and return PASS so any case that reaches
  # the LLM step does so cleanly (we don't want network calls in the test).
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
cat > "$CAPTURED_PROMPT"
echo "PASS - mocked"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  # Make the test repo look devshop-self by adding a real kit/ dir.
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"
}

# === Removed check-types: must fail with "unknown check type" ===

@test "removed: docsReviewed → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsReviewed "any reason"
  assert_failure
  assert_output --partial "unknown check type"
  assert_output --partial "docsReviewed"
}

@test "removed: testCoverage → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" testCoverage "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: testCoverageProject → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" testCoverageProject "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: docsFreshnessProject → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsFreshnessProject "any reason"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "removed: bare 'unknown' / nonsense → unknown check type" {
  cd "$TEST_REPO"
  run bash "$REVIEW" madeUpCheck "x"
  assert_failure
  assert_output --partial "unknown check type"
}

@test "fail message names the audit-time replacement" {
  cd "$TEST_REPO"
  run bash "$REVIEW" docsReviewed "x"
  assert_failure
  assert_output --partial "/ak-check-docs-and-tests"
}

# === Surviving check-types: still construct prompts and invoke claude ===
#
# These tests assert the script reaches the LLM step (mocked) and exits PASS,
# proving the case statement still recognizes the check-type. Detailed
# context-construction / prompt content is covered by the per-guard bats files
# that own each check-type's caller.

@test "surviving: dirtyTreeReason reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dirtyTreeReason "untracked debug.log from local testing"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dirtyTreeReason" "$CAPTURED_PROMPT"
}

@test "surviving: dirtyPushReason reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dirtyPushReason "stashed branch X to push hotfix Y"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dirtyPushReason" "$CAPTURED_PROMPT"
}

@test "surviving: manifestReviewed reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" manifestReviewed "added .husky/prepare-commit-msg as [locked] per template/.husky lifecycle"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: manifestReviewed" "$CAPTURED_PROMPT"
}

@test "surviving: hookBypass reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" hookBypass "binary lockfile breaks lint-staged; verified gitleaks pass via standalone scan"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: hookBypass" "$CAPTURED_PROMPT"
}

@test "surviving: exemptAddition reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" exemptAddition "apps/web/lib/util.ts  # transitively covered by api.test.ts"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: exemptAddition" "$CAPTURED_PROMPT"
}

@test "surviving: dismissalLog reaches claude (mocked PASS)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" dismissalLog "- finding: xyz; rationale: deferred per spec § In scope" qa "$BATS_TEST_TMPDIR/missing-review.md"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dismissalLog" "$CAPTURED_PROMPT"
}

@test "surviving: testReviewSkipReason reaches claude (mocked PASS)" {
  # Audit-time halt-override review — used by /ak-build Phase 5.8.
  # PR-C explicitly KEPT this check-type even while removing testCoverage*.
  cd "$TEST_REPO"
  # Seed a bare review.md so the case branch's audit-section harvesting has something to read.
  mkdir -p "$TEST_REPO/specs/test-feature"
  cat > "$TEST_REPO/specs/test-feature/review.md" <<'EOF'
## Audit 1
<!-- audited-at: abc1234 -->
findings: high=1 medium=0 low=0
- high: foo.test.ts missing onError assertion
EOF
  git -C "$TEST_REPO" checkout -b feature/test-feature -q 2>/dev/null || true
  run bash "$REVIEW" testReviewSkipReason "deferring foo.test.ts coverage; tracked at TODOS.md § follow-ups"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: testReviewSkipReason" "$CAPTURED_PROMPT"
}

# === CONVENTIONS_TO_INCLUDE narrowing ===

@test "exemptAddition still inlines Test Presence + Project Docs Coverage + Project Docs Hierarchy" {
  cd "$TEST_REPO"
  cat > "$TEST_REPO/kit/docs/guide/conventions.md" <<'EOF'
# conventions
## Test Presence
test-presence body
## Project Docs Coverage
docs-coverage body
## Project Docs Hierarchy
hierarchy body
## Other
out-of-map content here
EOF
  run bash "$REVIEW" exemptAddition "apps/web/lib/util.ts  # covered by api.test.ts"
  assert_success
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "test-presence body" "$CAPTURED_PROMPT"
  grep -q "docs-coverage body" "$CAPTURED_PROMPT"
  grep -q "hierarchy body" "$CAPTURED_PROMPT"
  # The "## Other / out-of-map" section must NOT be inlined. Scope the assertion
  # to the conventions block — "unrelated" appears in the prompt template's
  # dirtyPushReason rule ("stashed branch X to push unrelated branch Y") so a
  # whole-file grep would false-positive.
  CONVS_BLOCK=$(awk '/^=== Relevant conventions/{flag=1} flag{print} /^The reason must be specific/{flag=0}' "$CAPTURED_PROMPT")
  echo "$CONVS_BLOCK" | grep -qv "out-of-map content here" || true
  ! echo "$CONVS_BLOCK" | grep -q "out-of-map content here"
}
