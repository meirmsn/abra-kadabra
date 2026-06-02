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
  for script in commit-hooks/check-not-test-identity.sh \
                commit-hooks/check-security-files-freshness.sh commit-hooks/check-clean-tree.sh \
                commit-hooks/check-manifest.sh \
                commit-hooks/check-port-offset-unique.sh \
                commit-hooks/check-tests-coverage-devshop.sh \
                commit-hooks/check-docs-coverage-devshop.sh \
                commit-hooks/check-claude-md-classification.sh \
                commit-hooks/check-bats-devshop.sh \
                commit-hooks/check-exempt-additions.sh \
                commit-hooks/check-tests-coverage-project.sh \
                commit-hooks/check-docs-coverage-project.sh \
                commit-hooks/check-rollback-prose.sh \
                commit-hooks/check-template-propagation.sh \
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

@test "project repo (/workspace): calls security-freshness + clean-tree + exempt-additions + tests-coverage-project + docs-coverage-project + rollback-prose + commit-guard + template-propagation" {
  create_test_repo
  # Override git rev-parse in the wrapper to return /workspace
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/workspace"|' "$WRAPPER"
  # Force project mode: when this suite runs from the devshop devcontainer,
  # /workspace/kit is a real bind-mounted dir → auto detect-mode would say
  # devshop-self and skip the project-mode branch this test wants to exercise.
  run bash -c "cd '$TEST_REPO' && DEVSHOP_FORCE_MODE=project bash '$WRAPPER'"
  assert_success

  # Verify correct scripts were called
  [ -f "$MOCK_BIN/commit-hooks/check-not-test-identity.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-exempt-additions.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-tests-coverage-project.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-docs-coverage-project.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-claude-md-classification.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-rollback-prose.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-template-propagation.sh.args" ]
  # Manifest, port-offset, and devshop-side coverage scripts should NOT be called for project repos
  [ ! -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-port-offset-unique.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-tests-coverage-devshop.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-docs-coverage-devshop.sh.args" ]
}

@test "devshop repo (/devshop): calls clean-tree + manifest + tests-coverage-devshop + docs-coverage-devshop + bats + commit-guard" {
  create_test_repo
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/devshop"|' "$WRAPPER"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/commit-hooks/check-not-test-identity.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-port-offset-unique.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-tests-coverage-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-docs-coverage-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-claude-md-classification.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-bats-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  # Security freshness + template-propagation + rollback-prose should NOT be called for devshop repo
  [ ! -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-template-propagation.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-rollback-prose.sh.args" ]
}

@test "devshop-self mode (kit/ is real dir): calls clean-tree + manifest + port-offset-unique + tests-coverage-devshop + docs-coverage-devshop + bats + commit-guard" {
  create_test_repo
  # Create a real kit/ dir to trigger devshop-self detection
  mkdir -p "$TEST_REPO/kit"
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
  assert_success

  [ -f "$MOCK_BIN/commit-hooks/check-not-test-identity.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-manifest.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-port-offset-unique.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-tests-coverage-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-docs-coverage-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-claude-md-classification.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/check-bats-devshop.sh.args" ]
  [ -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-security-files-freshness.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-template-propagation.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/check-rollback-prose.sh.args" ]
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
  # Force project mode (see "project repo" test above for rationale).
  run bash -c "cd '$TEST_REPO' && DEVSHOP_FORCE_MODE=project bash '$WRAPPER'"
  assert_failure 1

  # clean-tree and commit-guard should NOT have been called (set -e stops)
  [ ! -f "$MOCK_BIN/commit-hooks/check-clean-tree.sh.args" ]
  [ ! -f "$MOCK_BIN/commit-hooks/commit-guard.sh.args" ]
}
