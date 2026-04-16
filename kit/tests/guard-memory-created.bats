#!/usr/bin/env bats
# Tests for kit/scripts/check-memory-created.sh
# PreToolUse hook that blocks memory file writes until classified

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/check-memory-created.sh"
}

# Helper: construct Write tool JSON and pipe to the check script
run_check() {
  local file_path="$1"
  local json
  json=$(jq -n --arg fp "$file_path" '{"tool_input": {"file_path": $fp}}')
  run bash "$CHECK" <<< "$json"
}

@test "blocks write to .claude/memory/ file" {
  run_check "/workspace/.claude/memory/insight.md"
  assert_failure 2
  assert_output --partial "BLOCKED"
  assert_output --partial "Memory file write blocked"
}

@test "blocks write to .claude/projects/*/memory/ file" {
  run_check "/home/node/.claude/projects/-workspace/memory/project-note.md"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "allows write to MEMORY.md index" {
  run_check "/workspace/.claude/memory/MEMORY.md"
  assert_success
}

@test "allows write to projects MEMORY.md index" {
  run_check "/home/node/.claude/projects/-workspace/memory/MEMORY.md"
  assert_success
}

@test "allows write to non-memory file" {
  run_check "/workspace/src/component.ts"
  assert_success
}

@test "blocks on empty file_path" {
  run bash "$CHECK" <<< '{"tool_input": {}}'
  assert_failure 2
  assert_output --partial "BLOCKED"
}

@test "blocks on unparseable JSON" {
  run bash "$CHECK" <<< "not json"
  assert_failure 2
  assert_output --partial "BLOCKED"
}

# Note: Bash writes to memory paths are blocked by deny rules in settings.json,
# not by this hook script. Deny rules are enforced by Claude Code at the tool
# level and can't be tested via BATS. The structural-invariants.bats test
# "wiring: devshop settings.json is valid JSON" ensures the deny rules are parseable.
