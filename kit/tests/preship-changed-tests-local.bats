#!/usr/bin/env bats
# Tests for kit/scripts/preship/changed-tests-local.sh
# The new pre-ship gate that runs the cheap halves of integration + E2E test
# execution locally. See specs/cheap-test-gates-local/spec.md § Tests.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/changed-tests-local.sh"

  # Stub `pnpm` so any playwright/vitest invocation succeeds by default.
  cat > "$MOCK_BIN/pnpm" <<'STUB'
#!/bin/bash
echo "pnpm $*" >> "$MOCK_BIN/pnpm.calls"
exit 0
STUB
  chmod +x "$MOCK_BIN/pnpm"

  # Default `realpath` exists on the host but ensure consistent resolution
  # in the test repo by using the standard tool from /usr/bin.
}

# Helper: run the script in TEST_REPO with isolated PATH so we control all stubs.
run_script() {
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="HEAD~1" \
      bash "$SCRIPT" "$TEST_REPO"
}

# Helper: stage and commit a file so HEAD~1 exists.
commit_file() {
  local path="$1" content="${2:-test}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "add $path"
}

# Helper: stage two commits so HEAD~1 → HEAD diff has the latter file.
two_commit() {
  # First commit just establishes a baseline.
  echo "base" > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "baseline"
  # Second commit adds the file we want to be in the diff.
  local path="$1" content="${2:-test}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "add $path"
}

# --- n/a outcomes ---

@test "n/a when diff has no stack-needing paths (docs-only diff)" {
  two_commit README.md "docs"
  run_script
  assert_success
  assert_output --partial "n/a (no stack-needing paths in diff)"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

@test "n/a when diff contains only kit/ docs (devshop-side diff)" {
  two_commit kit/docs/guide/foo.md "doc"
  run_script
  assert_success
  assert_output --partial "n/a (no stack-needing paths in diff)"
}

# --- pass outcomes ---

@test "pass when diff is stack-needing but no playwright config + no integration changes (no work to do)" {
  # apps/** triggers stack-needing classification; absent playwright config means
  # the gate has no parse-check / E2E / smoke step to run; absent
  # *.integration.test.ts means no integration step. Result: pass with no work.
  two_commit apps/web/components/Foo.tsx "tsx"
  run_script
  assert_success
  assert_output --partial "pass"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

# --- bypass-flag short-circuits ---

@test "bypass: localTestSkipReason set + adversarial review PASS → skipped pass" {
  mock_adversarial_review PASS
  two_commit apps/web/components/Foo.tsx "tsx"
  git -C "$TEST_REPO" config devshop.localTestSkipReason "specific reason — see TODOS.md § X"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="HEAD~1" \
      ADVERSARIAL_REVIEW_SCRIPT="$MOCK_BIN/adversarial-review.sh" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "pass (skipped — adversarially reviewed)"
  assert_output --partial "skipped via devshop.localTestSkipReason"
}

@test "bypass: localTestSkipReason set + adversarial review FAIL → findings (1) pending" {
  mock_adversarial_review FAIL
  two_commit apps/web/components/Foo.tsx "tsx"
  git -C "$TEST_REPO" config devshop.localTestSkipReason "ran out of time"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="HEAD~1" \
      ADVERSARIAL_REVIEW_SCRIPT="$MOCK_BIN/adversarial-review.sh" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "findings (1) pending"
  assert_output --partial "localTestSkipReason rejected"
}

# --- output shape (Dismissals body contract) ---

@test "output shape: Dismissals = None when no findings (n/a path)" {
  two_commit README.md "docs"
  run_script
  assert_success
  # Dismissals section appears, body is exactly "None".
  [[ "$output" == *"## Dismissals"$'\n'"None"* ]]
}

@test "output shape: outcome line is the FIRST line of stdout" {
  two_commit README.md "docs"
  run_script
  assert_success
  # First line should be the outcome — not a blank, not a finding bullet.
  first_line=$(echo "$output" | head -1)
  [[ "$first_line" == n/a* ]]
}

# --- parse-check short-circuit (when playwright is configured) ---

@test "parse-check failure short-circuits before execution steps" {
  two_commit apps/web/components/Foo.tsx "tsx"
  # Add a playwright config so the parse-check step runs.
  cat > "$TEST_REPO/playwright.config.ts" <<'TS'
export default { testDir: './e2e' }
TS
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "playwright config"

  # Stub pnpm to fail when called with `playwright test --list`, succeed otherwise.
  cat > "$MOCK_BIN/pnpm" <<'STUB'
#!/bin/bash
echo "pnpm $*" >> "$MOCK_BIN/pnpm.calls"
case "$*" in
  *"playwright test --list"*) exit 1 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/pnpm"

  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="HEAD~2" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "parse-check failed"
}

@test "no parse-check when project has no playwright config (gate still runs)" {
  two_commit apps/web/components/Foo.tsx "tsx"
  run_script
  assert_success
  # No parse-check finding because no config exists.
  refute_output --partial "parse-check failed"
}

# --- bypass-flag with no adversarial-review available (graceful degrade) ---

@test "bypass: localTestSkipReason set but adversarial-review missing → skipped pass with note" {
  two_commit apps/web/components/Foo.tsx "tsx"
  git -C "$TEST_REPO" config devshop.localTestSkipReason "any reason"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="HEAD~1" \
      ADVERSARIAL_REVIEW_SCRIPT="/nonexistent/adversarial-review.sh" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "pass (skipped"
}
