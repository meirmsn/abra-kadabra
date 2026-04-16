#!/usr/bin/env bats
# Tests for kit/hooks/pre-commit.sh
# Router that calls different guards based on repo type

setup() {
  load helpers/setup
  setup_mock_bin
  HOOK="$HOOKS_DIR/pre-commit.sh"

  # Create stubs for all scripts the router calls — we only test routing logic
  for script in check-security-files-freshness.sh check-clean-tree.sh \
                check-manifest.sh devshop-commit-guard.sh; do
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
  for script in check-security-files-freshness.sh check-clean-tree.sh \
                check-manifest.sh devshop-commit-guard.sh; do
    [ -f "$MOCK_BIN/${script}.args" ] && called="$called $script"
  done
  echo "$called"
}

@test "project repo (/workspace): calls security-freshness + clean-tree + commit-guard" {
  create_test_repo
  # Override git rev-parse in the wrapper to return /workspace
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/workspace"|' "$WRAPPER"
  # No kit/ dir → not devshop-self
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  # Verify correct scripts were called
  [ -f "$MOCK_BIN/check-security-files-freshness.sh.args" ]
  [ -f "$MOCK_BIN/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/devshop-commit-guard.sh.args" ]
  # Manifest check should NOT be called for project repos
  [ ! -f "$MOCK_BIN/check-manifest.sh.args" ]
}

@test "devshop repo (/devshop): calls clean-tree + manifest + commit-guard" {
  create_test_repo
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/devshop"|' "$WRAPPER"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/devshop-commit-guard.sh.args" ]
  # Security freshness should NOT be called for devshop repo
  [ ! -f "$MOCK_BIN/check-security-files-freshness.sh.args" ]
}

@test "devshop-self mode (kit/ is real dir): calls clean-tree + manifest + commit-guard" {
  create_test_repo
  # Create a real kit/ dir to trigger devshop-self detection
  mkdir -p "$TEST_REPO/kit"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/devshop-commit-guard.sh.args" ]
  [ ! -f "$MOCK_BIN/check-security-files-freshness.sh.args" ]
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
  create_capturing_stub "check-security-files-freshness.sh" "FAIL: stale" 1
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_failure 1

  # clean-tree and commit-guard should NOT have been called (set -e stops)
  [ ! -f "$MOCK_BIN/check-clean-tree.sh.args" ]
  [ ! -f "$MOCK_BIN/devshop-commit-guard.sh.args" ]
}
