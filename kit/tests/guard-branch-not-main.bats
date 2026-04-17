#!/usr/bin/env bats
# Tests for kit/scripts/check-branch-not-main.sh
# PreToolUse hook that blocks Claude from committing directly to main/master.

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/check-branch-not-main.sh"
  create_test_repo
}

# Helper: build JSON tool_input and pipe to the hook.
# Runs the hook from TEST_REPO so its cwd-fallback branch check targets the test repo.
run_check() {
  local cmd="$1"
  local json
  json=$(jq -n --arg cmd "$cmd" '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'" <<< "$json"
}

# --- Non-commit commands pass through ---

@test "allows non-git commands" {
  run_check 'pnpm turbo run test'
  assert_success
}

@test "allows git status (not a commit)" {
  run_check 'git status'
  assert_success
}

@test "allows git log (not a commit)" {
  run_check 'git log --oneline -5'
  assert_success
}

@test "allows git commit-tree (not an actual commit)" {
  run_check 'git commit-tree abc123'
  assert_success
}

# --- Feature branches pass through ---

@test "allows commit on feat/ branch" {
  git -C "$TEST_REPO" checkout -q -b feat/x
  run_check 'git commit -m "test"'
  assert_success
}

@test "allows commit on fix/ branch" {
  git -C "$TEST_REPO" checkout -q -b fix/bug
  run_check 'git commit -m "test"'
  assert_success
}

@test "allows commit on docs/ branch" {
  git -C "$TEST_REPO" checkout -q -b docs/readme
  run_check 'git commit -m "test"'
  assert_success
}

@test "allows commit on chore/ branch" {
  git -C "$TEST_REPO" checkout -q -b chore/deps
  run_check 'git commit -m "test"'
  assert_success
}

# --- Main / master block ---

@test "blocks commit when HEAD is main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  [ "$(git -C "$TEST_REPO" branch --show-current)" = "main" ]
  run_check 'git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "main/master"
}

@test "blocks commit when HEAD is master" {
  git -C "$TEST_REPO" branch -m master 2>/dev/null || true
  [ "$(git -C "$TEST_REPO" branch --show-current)" = "master" ]
  run_check 'git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks git -C <dir> commit when that dir is on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd "git -C $TEST_REPO commit -m test" '{"tool_input": {"command": $cmd}}')
  run bash "$CHECK" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks cd <dir> && git commit when that dir is on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd "cd $TEST_REPO && git commit -m test" '{"tool_input": {"command": $cmd}}')
  run bash "$CHECK" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks git -c foo=bar commit on main (rejects flag noise)" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  run_check 'git -c commit.gpgsign=false commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

# --- Edge cases ---

@test "allows empty input (no command field)" {
  run bash "$CHECK" <<< '{}'
  assert_success
}

@test "allows when not a git repo (cwd fallback)" {
  # Run from a non-repo directory — hook should exit 0 and let git handle it.
  local tmp="$BATS_TEST_TMPDIR/not-a-repo"
  mkdir -p "$tmp"
  local json
  json=$(jq -n --arg cmd "git commit -m test" '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$tmp' && bash '$CHECK'" <<< "$json"
  assert_success
}

@test "does not match arbitrary text containing 'commit'" {
  run_check 'echo "the commit is ready"'
  assert_success
}
