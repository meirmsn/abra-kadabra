#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-exempt-additions.sh
# Pre-commit check (project repos) — adversarially reviews additions to
# .devshop-test-coverage-exempt / .devshop-docs-freshness-exempt.
#
# Two layers:
#   Pre-flight (deterministic): cited file paths in inline reasons must exist
#   Layer 2 (adversarial): inline reasons must be specific; mocked here

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-exempt-additions.sh"
  cd "$TEST_REPO"
}

# Helper: invoke the script with adversarial-review mocked. Mirror the
# wrapper-rewrite pattern from guard-hook-bypass.bats.
run_with_review() {
  local result="$1"
  mock_adversarial_review "$result"
  local wrapper="$BATS_TEST_TMPDIR/check-wrapper.sh"
  sed "s|bash \"\$SCRIPT_DIR/../adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$SCRIPT" > "$wrapper"
  chmod +x "$wrapper"
  run bash "$wrapper"
}

# Helper: invoke without mocking review (for tests that exit before review)
run_script() {
  run bash "$SCRIPT"
}

# --- Early-exit guards ---

@test "exits 0 when run in devshop-self mode (kit/ is real dir)" {
  mkdir -p "$TEST_REPO/kit"
  echo placeholder > "$TEST_REPO/kit/anything"
  git -C "$TEST_REPO" add kit/anything
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

@test "exits 0 when neither exempt file is staged" {
  stage_file apps/web/src/foo.ts "export const x = 1;"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
  refute_output --partial "adversarial"
}

@test "exits 0 when exempt file is staged but only comments/blanks added" {
  stage_file .devshop-test-coverage-exempt $'# header comment\n\n# another comment'
  run_script
  assert_success
  refute_output --partial "adversarial"
}

# --- Pre-flight: cited paths must exist ---

@test "BLOCK when added entry cites a covering test that does not exist" {
  stage_file .devshop-test-coverage-exempt 'apps/web/src/foo.ts  # covered by e2e/nonexistent.spec.ts'
  run_script
  assert_failure
  assert_output --partial "BLOCKING: Exempt-file addition cites file(s) that don't exist"
  assert_output --partial "e2e/nonexistent.spec.ts"
  # Pre-flight is a hard block — no adversarial review invoked.
  refute_output --partial "reviewing inline reasons"
}

@test "BLOCK when added entry cites a covering spec that does not exist" {
  stage_file .devshop-docs-freshness-exempt 'apps/web/app/foo/page.tsx  # see specs/foo/spec.md'
  run_script
  assert_failure
  assert_output --partial "BLOCKING: Exempt-file addition cites file(s) that don't exist"
  assert_output --partial "specs/foo/spec.md"
}

@test "PASS pre-flight when cited test file exists in the repo" {
  stage_file e2e/list.spec.ts "test('list', () => {})"
  stage_file .devshop-test-coverage-exempt 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts'
  run_with_review PASS
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Pre-flight: no path-like tokens in reason → skip pre-flight, go to review ---

@test "skips pre-flight when reason has no path-like tokens" {
  stage_file .devshop-test-coverage-exempt 'apps/web/src/foo.ts  # pure type re-export with no runtime behavior'
  run_with_review PASS
  assert_success
  refute_output --partial "BLOCKING"
  assert_output --partial "adversarial review accepted"
}

# --- Layer 2: adversarial review ---

@test "BLOCK when adversarial review rejects the additions" {
  stage_file .devshop-test-coverage-exempt 'apps/web/src/foo.ts  # TODO test'
  run_with_review FAIL
  assert_failure
  assert_output --partial "ADVERSARIAL REVIEW REJECTED"
  assert_output --partial "Improve the inline reason"
}

@test "PASS when adversarial review accepts the additions" {
  stage_file e2e/auth.spec.ts "test('auth', () => {})"
  stage_file .devshop-test-coverage-exempt 'apps/web/app/sign-in/page.tsx  # covered by e2e/auth.spec.ts'
  run_with_review PASS
  assert_success
  assert_output --partial "adversarial review accepted"
}

# --- Multi-file: both exempt files staged in one commit ---

@test "reviews additions from BOTH exempt files in a single invocation" {
  stage_file e2e/list.spec.ts "test('list', () => {})"
  stage_file .devshop-test-coverage-exempt 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts'
  stage_file .devshop-docs-freshness-exempt 'apps/web/app/healthz/route.ts  # internal liveness probe — no user-visible surface'
  run_with_review PASS
  assert_success
  assert_output --partial "adversarial review accepted"
}

# --- Diff-only: edits/removals don't trigger review ---

@test "exits 0 when only EXISTING entries are edited (no new additions)" {
  # Pre-existing entry committed
  echo 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts' > "$TEST_REPO/.devshop-test-coverage-exempt"
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  git -C "$TEST_REPO" commit -q -m "seed exempt"
  # Now only modify the comment — the path itself is unchanged
  echo 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts (better wording)' > "$TEST_REPO/.devshop-test-coverage-exempt"
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  # The diff shows the line as removed AND added — strictly an addition. Verify
  # the script catches this as an addition (since the new line text is new).
  stage_file e2e/list.spec.ts "test('list', () => {})"
  run_with_review PASS
  assert_success
}

@test "exits 0 when only entries are removed (relaxing exemption is safe)" {
  # Two entries pre-existing
  printf 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts\napps/web/app/sign-in/page.tsx  # covered by e2e/auth.spec.ts\n' > "$TEST_REPO/.devshop-test-coverage-exempt"
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  git -C "$TEST_REPO" commit -q -m "seed exempt"
  # Remove one entry
  echo 'apps/web/app/list/page.tsx  # covered by e2e/list.spec.ts' > "$TEST_REPO/.devshop-test-coverage-exempt"
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  run_script
  assert_success
  refute_output --partial "adversarial"
}

# --- New file vs. addition ---

@test "treats first-time-creation of exempt file like ordinary additions" {
  # File does not exist pre-commit; whole content is "added" in the diff
  stage_file e2e/auth.spec.ts "test('auth', () => {})"
  stage_file .devshop-test-coverage-exempt 'apps/web/app/sign-in/page.tsx  # covered by e2e/auth.spec.ts'
  run_with_review PASS
  assert_success
}
