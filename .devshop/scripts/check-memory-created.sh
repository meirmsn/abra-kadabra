#!/usr/bin/env bash
# What: PreToolUse hook — blocks memory file writes until user approves
# Why: User wants to decide what happens with memories before they're created
# Does NOT: Allow the write — blocks it and tells Claude to ask first

set -euo pipefail

# Read the tool input from stdin (JSON with file_path)
INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"

# Only trigger for memory files (not MEMORY.md index)
if [[ ("$FILE_PATH" == *".claude/memory/"* || "$FILE_PATH" == *".claude/projects/"*/memory/*) && "$FILE_PATH" != *"MEMORY.md" ]]; then
  FILENAME="$(basename "$FILE_PATH")"
  cat <<HOOK_EOF
BLOCKED: Memory file write blocked: $FILENAME

Do NOT write memory files without explicit user approval.
Instead, tell the user what you want to remember and ask:
"I'd like to save this as a memory — keep as memory, move to CLAUDE.md, or skip?"

Wait for their answer before proceeding.
HOOK_EOF
  exit 2
fi
