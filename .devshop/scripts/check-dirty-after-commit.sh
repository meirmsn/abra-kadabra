#!/bin/bash
# PostToolUse hook: after git commit, check for remaining work.
# Two checks:
#   1. Current repo still dirty — address remaining files
#   2. Other repo has uncommitted changes — commit there too
set -euo pipefail

MESSAGES=()

# --- Check 1: Current repo still dirty ---
DIRTY=$(git status --porcelain 2>/dev/null || true)
if [ -n "$DIRTY" ]; then
  MESSAGES+=("Working tree still dirty after commit. Remaining files:\\n$(echo "$DIRTY" | sed 's/"/\\"/g' | head -10)\\nAddress each file: stage + commit, stash, or add to .gitignore. Do not leave a dirty tree.")
fi

# --- Check 2: Other repo has uncommitted changes ---
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
case "$GIT_ROOT" in
  /workspace) OTHER_REPO=/devshop;  OTHER_NAME="devshop (abra-kadabra)" ;;
  /devshop)   OTHER_REPO=/workspace; OTHER_NAME="project" ;;
  *)          OTHER_REPO="" ;;
esac

if [ -n "$OTHER_REPO" ] && [ -d "$OTHER_REPO/.git" ]; then
  OTHER_DIRTY=$(git -C "$OTHER_REPO" status --porcelain 2>/dev/null | head -5 || true)
  if [ -n "$OTHER_DIRTY" ]; then
    MESSAGES+=("The $OTHER_NAME repo ($OTHER_REPO) still has uncommitted changes:\\n$(echo "$OTHER_DIRTY" | sed 's/"/\\"/g')\\nCommit there too before moving on to other work.")
  fi
fi

# --- Reminder: cwd may have changed after cd-ing to the other repo ---
if [ "$GIT_ROOT" != "/workspace" ]; then
  MESSAGES+=("You are in $GIT_ROOT — use 'cd /workspace' or absolute paths for project work.")
fi

[ ${#MESSAGES[@]} -eq 0 ] && exit 0

# Combine all messages into one additionalContext block
COMBINED=$(IFS='\\n\\n'; echo "${MESSAGES[*]}")
cat <<HOOK_OUTPUT
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"$COMBINED"}}
HOOK_OUTPUT
