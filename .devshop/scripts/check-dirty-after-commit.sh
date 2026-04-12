#!/bin/bash
# PostToolUse hook: after git commit, check if working tree is still dirty.
# If yes, output additionalContext so Claude addresses remaining files.
set -euo pipefail

DIRTY=$(git status --porcelain 2>/dev/null || true)
[ -z "$DIRTY" ] && exit 0

# Format for Claude's additionalContext
cat <<HOOK_OUTPUT
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Working tree still dirty after commit. Remaining files:\n$(echo "$DIRTY" | sed 's/"/\\"/g' | head -10)\n\nAddress each file: stage + commit, stash, or add to .gitignore. Do not leave a dirty tree."}}
HOOK_OUTPUT
