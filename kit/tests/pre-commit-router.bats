#!/usr/bin/env bats
# Tests for kit/hooks/pre-commit.sh
# Router that calls different guards based on repo type

setup() {
  load helpers/setup
  setup_mock_bin
  HOOK="$HOOKS_DIR/pre-commit.sh"

  # Create stubs for all scripts the router calls — we only test routing logic.
  # Scripts live under commit-hooks/ (post v1.19 reorg); the stub helper takes
  # the subpath relative to $MOCK_BIN.
  mkdir -p "$MOCK_BIN/commit-hooks"
  for script in commit-hooks/check-security-files-freshness.sh commit-hooks/check-clean-tree.sh \
                commit-hooks/check-manifest.sh commit-hooks/check-test-coverage.sh \
                commit-hooks/check-exempt-additions.sh \
                commit-hooks/check-test-coverage-project.sh commit-hooks/check-docs-freshness-project.sh \
                commit-hooks/commit-guard.sh; do
    create_capturing_stub "$script" "" 0
  done

  # Create wrapper with configurable DEVSHOP pointing to our mock scripts
  WRAPPER="$BATS_TEST_TMPDIR/pre-commit-wrapper.sh"
  cp "$HOOK" "$WRAPPER"
  sed -i "s|SCRIPTS_DIR=\"\$DEVSHOP/kit/scripts\"|SCRIPTS_DIR=\"$MOCK_BIN\"|" "$WRAPPER"
  chmod +x "$WRAPPER"
}

# Helper to check which scripts were called
scripts_called() {
  local called=""
  for script in commit-hooks/check-security-files-freshness.sh commit-hooks/check-clean-tree.sh \
                commit-hooks/check-manifest.sh commit-hooks/commit-guard.sh; do
    [ -f "$MOCK_BIN/${script}.args" ] && called="$called $script"
  done
  echo "$called"
}

@test "project repo (/workspace): calls security-freshness + clean-tree + exempt-additions + test-coverage-project + docs-freshness-project + commit-guard" {
  create_test_repo
  # Override git rev-parse in the wrapper to return /workspace
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/workspace"|' "$WRAPPER"
  # No kit/ dir → not devshop-self
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  # Verify correct scripts were called
  [ -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-exempt-additions.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-test-coverage-project.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-docs-freshness-project.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  # Manifest and (devshop-side) test-coverage should NOT be called for project repos
  [ ! -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-test-coverage.sh.args" ]
}

@test "devshop repo (/devshop): calls clean-tree + manifest + test-coverage + commit-guard" {
  create_test_repo
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/devshop"|' "$WRAPPER"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-test-coverage.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  # Security freshness should NOT be called for devshop repo
  [ ! -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
}

@test "devshop-self mode (kit/ is real dir): calls clean-tree + manifest + test-coverage + commit-guard" {
  create_test_repo
  # Create a real kit/ dir to trigger devshop-self detection
  mkdir -p "$TEST_REPO/kit"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-test-coverage.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
}

@test "unknown git root: exits 1" {
  create_test_repo
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/unknown"|' "$WRAPPER"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_failure 1
  assert_output --partial "Cannot determine git root"
}

@test "stops on first failing guard" {
  create_test_repo
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/workspace"|' "$WRAPPER"
  # Make security-freshness fail
  create_capturing_stub "commit-hooks/check-security-files-freshness.sh" "FAIL: stale" 1
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_failure 1

  # clean-tree and commit-guard should NOT have been called (set -e stops)
  [ ! -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
}
