#!/bin/bash
# PreToolUse hook: warn if working tree has untracked/unstaged files before git commit.
set -euo pipefail

DIRTY=$(git status --porcelain 2>/dev/null | grep -E '^\?\?|^ [MD]' || true)

if [ -n "$DIRTY" ]; then
  echo "⚠ Working tree not clean before commit. These files are untracked or unstaged:"
  echo "$DIRTY"
  echo ""
  echo "Address these before committing — stage, gitignore, or commit separately as appropriate."
fi
