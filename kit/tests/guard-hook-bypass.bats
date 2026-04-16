#!/usr/bin/env bats
# Tests for kit/scripts/check-hook-bypass.sh
# PreToolUse hook that reads JSON from stdin, blocks git commands bypassing pre-commit

setup() {
  load helpers/setup
  setup_mock_bin
  CHECK="$SCRIPTS_DIR/check-hook-bypass.sh"
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
  sed "s|bash \"\$SCRIPT_DIR/adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$CHECK" > "$wrapper"
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
