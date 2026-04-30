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

@test "blocks core.hooksPath via -c flag" {
  run_check 'git -c core.hooksPath=/dev/null commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "blocks core.hooksPath via -c flag with quoted value" {
  run_check 'git -c "core.hooksPath=/dev/null" commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "blocks core.hooksPath via git config (persistent set)" {
  run_check 'git config core.hooksPath /dev/null && git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "blocks core.hooksPath via git config --global" {
  run_check 'git config --global core.hooksPath /dev/null'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "blocks core.hooksPath via GIT_CONFIG_PARAMETERS env-var smuggle" {
  run_check "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null'\" git commit -m test"
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "core.hooksPath"
}

@test "allows commit messages that mention core.hooksPath as a doc citation" {
  # False-positive guard: bare mentions of `core.hooksPath` in commit messages
  # or doc text must not trigger — only the load-bearing forms above do.
  run_check 'git commit -m "docs: explain core.hooksPath bypass detection"'
  assert_success
}

@test "allows command chains where core.hooksPath only appears as literal text after a separator" {
  # False-positive guard: `git config user.name foo; echo core.hooksPath` must
  # not match — the `git config` arm of the regex bounds on `[^;&|]*` so the
  # config invocation can't reach across a shell separator.
  run_check 'git config user.name foo && echo "see docs for core.hooksPath details"'
  assert_success
}

@test "blocks HUSKY=0" {
  run_check 'HUSKY=0 git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "HUSKY"
}

@test "blocks HUSKY_SKIP" {
  run_check 'HUSKY_SKIP=pre-commit git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks export HUSKY=0 followed by commit" {
  run_check 'export HUSKY=0 && git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "HUSKY"
}

@test "blocks HUSKY=0 after a shell separator" {
  run_check 'cd /tmp; HUSKY=0 git commit -m "test"'
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "HUSKY"
}

@test "allows commit messages that mention HUSKY=0 as a doc citation" {
  # False-positive guard: the regex must anchor on env-var-prefix position,
  # not match every occurrence in command text.
  run_check 'git commit -m "docs: HUSKY=0 disables hooks but is blocked here"'
  assert_success
}

@test "allows commit messages that mention HUSKY_SKIP= as a doc citation" {
  run_check 'git commit -m "fix(hooks): document HUSKY_SKIP=pre-commit bypass"'
  assert_success
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
