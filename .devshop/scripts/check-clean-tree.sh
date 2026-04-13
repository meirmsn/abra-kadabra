#!/bin/bash
# PreToolUse hook: block if working tree has untracked/unstaged files before commit.
# Prevents accidental partial commits. Bypass with a reason for intentional subsets.
set -euo pipefail

DIRTY=$(git status --porcelain 2>/dev/null | grep -E '^\?\?|^ [MD]' || true)
[ -z "$DIRTY" ] && exit 0

# --- Read pending command from Claude Code hook stdin ---
HOOK_COMMAND=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
  HOOK_COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
fi

# Check for bypass
BYPASS=""
if [ -n "$HOOK_COMMAND" ]; then
  BYPASS=$(echo "$HOOK_COMMAND" | sed -n 's/.*-c devshop.dirtyTreeReason="\([^"]*\)".*/\1/p')
  [ -z "$BYPASS" ] && BYPASS=$(echo "$HOOK_COMMAND" | sed -n 's/.*-c devshop.dirtyTreeReason=\([^ "]*\).*/\1/p')
fi
[ -z "$BYPASS" ] && BYPASS=$(git config --get devshop.dirtyTreeReason 2>/dev/null || true)

if [ -n "$BYPASS" ]; then
  echo "✓ Dirty tree acknowledged: $BYPASS" >&2
  exit 0
fi

echo "" >&2
echo "✖ Working tree not clean before commit. Untracked or unstaged files:" >&2
echo "$DIRTY" | sed 's/^/    /' >&2
echo "" >&2
echo "  Address these before committing — stage, gitignore, or stash." >&2
echo "  If intentionally committing a subset, bypass with a reason:" >&2
echo "    git -c devshop.dirtyTreeReason=\"<reason>\" commit ..." >&2
exit 2
