#!/bin/bash
# PostToolUse hook: after git commit, check for remaining work.
# Two checks:
#   1. Current repo still dirty — address remaining files
#   2. Other repo has uncommitted changes — commit there too
set -euo pipefail

MESSAGES=()

# --- Check 1: Current repo still dirty ---
DIRTY=$(git status --porcelain 2>/dev/null | head -10 || true)
if [ -n "$DIRTY" ]; then
  MESSAGES+=("BLOCKING: Working tree still dirty after commit. You MUST address every remaining file BEFORE doing anything else. Remaining files:
$DIRTY
For each file: stage + commit, stash, or add to .gitignore. If you do not know what to do with a file, ask the user. Do NOT move on to other work until the tree is clean.")
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
    MESSAGES+=("BLOCKING: The $OTHER_NAME repo ($OTHER_REPO) still has uncommitted changes:
$OTHER_DIRTY
You MUST commit or address these files BEFORE doing anything else. If you do not know what to do, ask the user.")
  fi
fi

# --- Reminder: cwd may have changed after cd-ing to the other repo ---
if [ "$GIT_ROOT" != "/workspace" ]; then
  MESSAGES+=("You are in $GIT_ROOT — use 'cd /workspace' or absolute paths for project work.")
fi

[ ${#MESSAGES[@]} -eq 0 ] && exit 0

# Combine all messages and output as properly escaped JSON
COMBINED=$(printf '%s\n\n' "${MESSAGES[@]}")
jq -n --arg ctx "$COMBINED" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
