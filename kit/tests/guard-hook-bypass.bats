#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-hook-bypass.sh
# PreToolUse hook that reads JSON from stdin, blocks git commands bypassing pre-commit

setup() {
  load helpers/setup
  setup_mock_bin
  CHECK="$SCRIPTS_DIR/commit-hooks/check-hook-bypass.sh"
}

# Helper: construct valid JSON and pipe to the check script
run_check() {
  local cmd="$1"
  local json
  json=$(jq -n --arg cmd "$cmd" '{"tool_input": {"command": $cmd}}')
  run bash "$CHECK" <<< "$json"
}

# Helper: run check with adversarial-review mocked (replaces SCRIPT_DIR reference)
run_check_with_review() {
  local cmd="$1" review_result="$2"
  mock_adversarial_review "$review_result"
  local json
  json=$(jq -n --arg cmd "$cmd" '{"tool_input": {"command": $cmd}}')
  local wrapper="$BATS_TEST_TMPDIR/check-wrapper.sh"
  sed "s|bash \"\$SCRIPT_DIR/../adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$CHECK" > "$wrapper"
  chmod +x "$wrapper"
  run bash "$wrapper" <<< "$json"
}

# --- Tier 1: Always blocked ---

@test "blocks core.hooksPath" {
  run_check 'git -c core.hooksPath=/dev/null commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "blocks HUSKY=0" {
  run_check 'HUSKY=0 git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "HUSKY"
}

@test "blocks HUSKY_SKIP" {
  run_check 'HUSKY_SKIP=1 git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks devshop.humanReviewed from Claude" {
  run_check 'git -c devshop.humanReviewed="approve: looks fine" commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "humanReviewed"
}

@test "allows commit messages that mention devshop.humanReviewed as a doc citation" {
  # False-positive guard: the regex must require `=` (the actual bypass form),
  # not match bare mentions like 'see devshop.humanReviewed'.
  run_check 'git commit -m "docs: explain devshop.humanReviewed bypass boundary"'
  assert_success
}

@test "blocks DEVSHOP_SKIP_ADVERSARIAL=1 env-var bypass" {
  run_check 'DEVSHOP_SKIP_ADVERSARIAL=1 git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "DEVSHOP_SKIP_ADVERSARIAL"
}

@test "blocks DEVSHOP_SKIP_ADVERSARIAL=true (any value) env-var bypass" {
  run_check 'DEVSHOP_SKIP_ADVERSARIAL=true git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "DEVSHOP_SKIP_ADVERSARIAL"
}

@test "allows commit messages that mention DEVSHOP_SKIP_ADVERSARIAL= as literal text" {
  # False-positive guard: the regex must anchor to env-var-prefix usage,
  # not match every occurrence of the string in the command (which would
  # block any commit message documenting the bypass).
  run_check 'git commit -m "fix(hooks): note that DEVSHOP_SKIP_ADVERSARIAL= bypass is human-only"'
  assert_success
}

# --- Tier 2: --no-verify without reason ---

@test "blocks --no-verify without bypass reason" {
  run_check 'git commit --no-verify -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "hookBypassReason"
}

# --- Tier 3: --no-verify with reason + adversarial review ---

@test "allows --no-verify with reason when adversarial review passes" {
  run_check_with_review 'git -c devshop.hookBypassReason="migration commit" commit --no-verify -m test' PASS
  assert_success
}

@test "blocks --no-verify with reason when adversarial review rejects" {
  run_check_with_review 'git -c devshop.hookBypassReason="just because" commit --no-verify -m test' FAIL
  assert_failure 2
  assert_output --partial "BLOCKED"
}

# --- Normal commands (no bypass flags) ---

@test "allows normal git commit" {
  run_check 'git commit -m "feat: add feature"'
  assert_success
}

@test "allows non-git commands" {
  run_check 'pnpm turbo run test'
  assert_success
}

# --- Outer-matcher false-positive guards ---
# The `if: Bash(*git*commit*)` matcher fires on any command containing both
# `git` and `commit` substrings — including `gh pr create` bodies that mention
# "git commit" in their PR description. The hook now early-exits unless the
# command is an actual git commit invocation.

@test "allows gh pr create with body text mentioning git commit" {
  run_check 'gh pr create --title "fix(hooks): tighten" --body "ensures git commit chain remains protected"'
  assert_success
}

@test "allows gh issue comment with body text mentioning git commit" {
  run_check 'gh issue comment 42 --body "see git commit a1b2c3d for context"'
  assert_success
}

@test "allows echo with git commit in literal text" {
  run_check 'echo "run git commit -am foo to commit changes"'
  assert_success
}

@test "allows git log search containing the word commit" {
  # Has leading `git` but not a commit — bypass-string regex would exit 0
  # anyway (no bypass present). Just verifies the whitelist doesn't break it.
  run_check 'git log --grep="initial commit" --oneline'
  assert_success
}

@test "allows HUSKY=0 mentioned in body text of gh pr create" {
  # Whitelist exits early because LEAD is `gh`, not `git`/`cd`. Bypass-string
  # regex never gets to false-positive on the body content.
  run_check 'gh pr create --body "fix HUSKY=0 bypass detection in git commit chain"'
  assert_success
}

@test "still blocks bypass on cd <dir> && git commit chain" {
  # cd is whitelisted, so the chain proceeds to bypass-string regex which
  # catches HUSKY=0 in env-var-prefix position.
  run_check 'cd /tmp && HUSKY=0 git commit -m test'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "still blocks bypass when leading is path-qualified git" {
  run_check '/usr/bin/git -c core.hooksPath=/dev/null commit -m test'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "still blocks bypass with env-var prefix on git command" {
  # Whitelist must strip env-var prefix before inspecting LEAD.
  run_check 'HUSKY=0 git commit -m test'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "HUSKY"
}

# --- Edge cases ---

@test "blocks on unparseable JSON" {
  run bash "$CHECK" <<< "not json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks on empty input" {
  run bash "$CHECK" <<< ""
  assert_failure 2
  assert_output --partial "BLOCKED"
}
