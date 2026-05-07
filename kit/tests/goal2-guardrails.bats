#!/usr/bin/env bats
# Goal 2 (Guardrails built in): Claude can't weaken its own constraints
# Smoke tests verifying the security model holds across the guard suite

setup() {
  load helpers/setup
  setup_mock_bin
}

# --- Hook bypass protection ---

@test "guardrails: core.hooksPath always blocked (no escape)" {
  local json
  json=$(jq -n '{"tool_input": {"command": "git -c core.hooksPath=/dev/null commit -m test"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-hook-bypass.sh" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "guardrails: HUSKY=0 always blocked (no escape)" {
  local json
  json=$(jq -n '{"tool_input": {"command": "HUSKY=0 git commit -m test"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-hook-bypass.sh" <<< "$json"
  assert_failure 2
}

@test "guardrails: humanReviewed flag reserved for humans only" {
  local json
  json=$(jq -n '{"tool_input": {"command": "git -c devshop.humanReviewed=\"approve: ok\" commit -m test"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-hook-bypass.sh" <<< "$json"
  assert_failure 2
  assert_output --partial "human-only"
}

@test "guardrails: --no-verify requires a reason" {
  local json
  json=$(jq -n '{"tool_input": {"command": "git commit --no-verify -m test"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-hook-bypass.sh" <<< "$json"
  assert_failure 2
  assert_output --partial "hookBypassReason"
}

# --- Memory classification gate ---

@test "guardrails: memory file writes blocked until classified" {
  local json
  json=$(jq -n '{"tool_input": {"file_path": "/workspace/.claude/memory/insight.md"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-memory-created.sh" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "classify"
}

@test "guardrails: MEMORY.md index writes allowed" {
  local json
  json=$(jq -n '{"tool_input": {"file_path": "/workspace/.claude/memory/MEMORY.md"}}')
  run bash "$SCRIPTS_DIR/commit-hooks/check-memory-created.sh" <<< "$json"
  assert_success
}

# --- Pre-commit routing ---

@test "guardrails: unknown repo blocked from committing" {
  create_test_repo
  local wrapper="$BATS_TEST_TMPDIR/hook-wrapper.sh"
  cp "$HOOKS_DIR/pre-commit.sh" "$wrapper"
  sed -i "s|SCRIPTS_DIR=\"\$DEVSHOP/kit/scripts\"|SCRIPTS_DIR=\"$MOCK_BIN\"|" "$wrapper"
  sed -i 's|GIT_ROOT=$(git rev-parse.*|GIT_ROOT="/unknown"|' "$wrapper"
  chmod +x "$wrapper"
  run bash -c "cd '$TEST_REPO' && bash '$wrapper'"
  assert_failure 1
  assert_output --partial "Cannot determine git root"
}

# --- Security file enforcement ---

@test "guardrails: missing settings.json blocks commit" {
  local ds="$BATS_TEST_TMPDIR/devshop"
  local ws="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$ds/.claude" "$ds/kit/scripts" "$ws/.claude"
  echo '{}' > "$ds/.claude/settings.json"
  echo '[packs]' > "$ds/.dcg.toml"
  cp "$SCRIPTS_DIR/sync/normalize-devshop-paths.sh" "$ds/kit/scripts/"
  # Don't create settings.json in workspace
  cp "$ds/.dcg.toml" "$ws/.dcg.toml"
  run bash -c "DEVSHOP='$ds' WS='$ws' bash '$SCRIPTS_DIR/commit-hooks/check-security-files-freshness.sh'"
  assert_failure 1
  assert_output --partial "MISSING"
}

@test "guardrails: symlinked settings.json blocks commit" {
  local ds="$BATS_TEST_TMPDIR/devshop"
  local ws="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$ds/.claude" "$ds/kit/scripts" "$ws/.claude"
  echo '{}' > "$ds/.claude/settings.json"
  echo '[packs]' > "$ds/.dcg.toml"
  cp "$SCRIPTS_DIR/sync/normalize-devshop-paths.sh" "$ds/kit/scripts/"
  ln -s "$ds/.claude/settings.json" "$ws/.claude/settings.json"
  cp "$ds/.dcg.toml" "$ws/.dcg.toml"
  run bash -c "DEVSHOP='$ds' WS='$ws' bash '$SCRIPTS_DIR/commit-hooks/check-security-files-freshness.sh'"
  assert_failure 1
  assert_output --partial "SYMLINK"
}

# --- Clean tree enforcement ---

@test "guardrails: dirty working tree blocks commit" {
  create_test_repo
  create_untracked "forgotten-file.txt"
  run bash -c "cd '$TEST_REPO' && bash '$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh'"
  assert_failure 1
  assert_output --partial "forgotten-file.txt"
}

# --- Docs coverage enforcement ---
# Pre-PR-C this asserted commit-guard.sh's docs-reviewed check fired on devshop
# tooling changes. After PR-C of the audit-time docs+tests migration, that check
# moved to audit-time `/ak-docs-review` (orchestrated by `/ak-check-docs-and-tests`).
# Per-commit coverage now lives in check-docs-coverage-{project,devshop}.sh; the
# devshop-side variant is exercised by guard-docs-coverage-devshop.bats. Here we
# pin commit-guard.sh's actual surviving behavior: a kit/scripts change in the
# devshop repo no longer triggers a commit-guard.sh failure.

@test "guardrails: commit-guard.sh no longer judges docs coverage (moved to audit-time in PR-C)" {
  TEST_REPO="$BATS_TEST_TMPDIR/devshop-test"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/docs"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"

  local wrapper="$BATS_TEST_TMPDIR/guard-wrapper.sh"
  cp "$SCRIPTS_DIR/commit-hooks/commit-guard.sh" "$wrapper"
  chmod +x "$wrapper"

  stage_file "kit/scripts/new-thing.sh" "#!/bin/bash"
  run bash -c "cd '$TEST_REPO' && bash '$wrapper'"
  assert_success
  refute_output --partial "docs review required"
}
