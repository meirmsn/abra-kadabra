#!/usr/bin/env bash
# What: PreToolUse hook — blocks memory file writes until user classifies and approves
# Why: Memories must be routed correctly — project insights to /workspace/.claude/memory/,
#      devshop insights to /devshop/CLAUDE.md. Claude classifies, user confirms.
# Does NOT: Allow the write — blocks it and tells Claude to classify and ask first

set -euo pipefail

# Read the tool input from stdin (JSON with file_path)
INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  echo "BLOCKED: Could not parse tool input. Write blocked as a precaution."
  exit 2
fi

# Only trigger for memory files (not MEMORY.md index)
if [[ ("$FILE_PATH" == *".claude/memory/"* || "$FILE_PATH" == *".claude/projects/"*/memory/*) && "$FILE_PATH" != *"MEMORY.md" ]]; then
  FILENAME="$(basename "$FILE_PATH")"
  cat <<HOOK_EOF
BLOCKED: Memory file write blocked: $FILENAME

Before writing, classify this memory and present your assessment to the user:
1. Project memory (project-specific insight) → write to /workspace/.claude/memory/
2. Devshop memory (devshop conventions/workflow/infrastructure insight) → incorporate into /devshop/CLAUDE.md instead
3. Unclear → tell the user why it could be either and let them decide

Present which category you think it is and why, then wait for the user to confirm before proceeding.
HOOK_EOF
  exit 2
fi
