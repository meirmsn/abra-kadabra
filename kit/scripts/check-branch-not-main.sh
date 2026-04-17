#!/usr/bin/env bash
# What: PreToolUse hook — blocks Claude from committing directly to main/master
# Why: Main/master is PR-only. Humans can still commit from the terminal (for
#      release.sh version bumps); this hook only intercepts Claude's Bash calls.
# Does NOT: Block merge/rebase/cherry-pick; block commits on feature branches.

set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || CMD=""
[ -z "$CMD" ] && exit 0

# Only fire on actual `git commit` (not `git commit-tree`, not arbitrary text
# with "commit" in it). Accept `git -c key=val commit`, `git -C <dir> commit`.
echo "$CMD" | grep -qE '(^|[^a-zA-Z0-9_/])git( +-[cC] +[^ ]+)* +commit([^a-zA-Z0-9_-]|$)' || exit 0

# Figure out which repo the commit targets. Order:
#   1. `git -C <dir> commit` — explicit
#   2. `cd <dir> && git commit` — implicit
#   3. hook cwd — fallback
DIR=""
if echo "$CMD" | grep -qE 'git +-C +'; then
  DIR=$(echo "$CMD" | grep -oE 'git +-C +[^ ]+' | head -1 | awk '{print $NF}')
elif echo "$CMD" | grep -qE '(^|[;&|]|&&)[[:space:]]*cd +'; then
  DIR=$(echo "$CMD" | grep -oE '(^|[;&|]|&&)[[:space:]]*cd +[^ &;|]+' | head -1 | awk '{print $NF}')
fi

if [ -n "$DIR" ]; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null || echo "")
else
  BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi

# Not a git repo or detached HEAD — let git itself handle the error.
[ -z "$BRANCH" ] && exit 0

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  cat >&2 <<'HOOK_EOF'
BLOCKED: direct commit to main/master.

Main/master is PR-only. Create a branch first:

  git checkout -b <type>/<topic>

Where <type> matches your commit type:
  feat   new functionality (paired with a spec)
  fix    bug fix
  docs   docs-only changes
  chore  tooling / deps / refactor with no behavior change

Pick <topic> from the work at hand (e.g. docs/overview-pointers,
feat/auth, fix/session-refresh). Then re-stage and commit.

Note: this block only applies to commits initiated by Claude Code.
Humans can commit to main from the terminal directly (release.sh
uses this for version bumps).
HOOK_EOF
  exit 2
fi

exit 0
