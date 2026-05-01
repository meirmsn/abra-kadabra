#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-branch-not-main.sh
# PreToolUse hook that blocks Claude from committing directly to main/master.

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/commit-hooks/check-branch-not-main.sh"
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

# --- Whitelist parity (mirrors check-hook-bypass.sh PR #19) ---

@test "allows gh pr create with body text mentioning git commit" {
  # Without the leading-executable whitelist, the outer Bash(*git*commit*)
  # matcher would let this through to the regex check, which is harmless
  # here but inefficient. The whitelist exits 0 before any further work.
  run_check 'gh pr create --body "running git commit on every push"'
  assert_success
}

@test "allows pnpm command with git commit in its arguments" {
  run_check 'pnpm exec lint-staged --commit-message "git commit hash"'
  assert_success
}

# --- Quoted-value -c flag support (the parity bug from PR E) ---

@test "blocks git -c key=\"quoted value\" commit on main" {
  # The OLD regex ( +-[cC] +[^ ]+)* had [^ ]+ that consumed up to the first
  # space, so `git -c devshop.foo="quoted val" commit` failed to match — the
  # on-main check silently skipped. After this fix, the sed-strip removes
  # the -c flag segment cleanly and the commit-verb regex resolves.
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd 'git -c devshop.dirtyTreeReason="WIP for review" commit -m test' '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks git -c key='single-quoted value' commit on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd "git -c devshop.dirtyTreeReason='WIP for review' commit -m test" '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks multiple -c flags with quoted values on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd 'git -c user.email="a b@x.com" -c devshop.dirtyTreeReason="WIP one two" commit -m test' '{"tool_input": {"command": $cmd}}')
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "still allows quoted-value -c with non-commit verb (git -c key=\"quoted\" status)" {
  # After stripping the -c segment, the result `git status` should NOT match
  # the commit-verb regex — confirms we strip flags but don't bias toward
  # block.
  run_check 'git -c devshop.dirtyTreeReason="WIP" status'
  assert_success
}

# --- Symmetric `export` chain support ---

@test "blocks export VAR=val && git commit when in dir on main" {
  # Symmetric form to `VAR=val git commit` (which is already handled by
  # env-var stripping). The whitelist must accept `export` as LEAD; the
  # cwd-based branch detection handles the rest.
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  local json
  json=$(jq -n --arg cmd "export GIT_AUTHOR_NAME=Test && cd $TEST_REPO && git commit -m test" '{"tool_input": {"command": $cmd}}')
  run bash "$CHECK" <<< "$json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}
