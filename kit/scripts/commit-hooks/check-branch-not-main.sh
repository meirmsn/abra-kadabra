#!/usr/bin/env bash
# What: PreToolUse hook — blocks Claude from committing directly to main/master
# Why: Main/master is PR-only. Humans can still commit from the terminal (for
#      release.sh version bumps); this hook only intercepts Claude's Bash calls.
# Does NOT: Block merge/rebase/cherry-pick; block commits on feature branches.

set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || CMD=""
[ -z "$CMD" ] && exit 0

# Leading-executable whitelist (parity with check-hook-bypass.sh — see that
# script's comment block for the rationale). The outer `if: Bash(*git*commit*)`
# matcher uses substring globbing, so it fires on any command containing both
# "git" and "commit" — including `gh pr create --body "...git commit..."` and
# `echo "git commit ready"`. Strip env-var assignments at command start
# (KEY=value), then inspect the leading executable token. Only proceed when
# the command actually starts with `git` (any path), `cd` (for `cd /foo &&
# git commit` chains), or `export` (for `export VAR=val && git commit`
# chains — symmetric to the `VAR=val git commit` form already covered by
# env-var stripping).
STRIPPED=$(echo "$CMD" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//')
LEAD=$(echo "$STRIPPED" | awk '{print $1}')
case "$LEAD" in
  git|*/git|cd|export) ;;  # proceed
  *) exit 0 ;;
esac

# Now verify it's actually `git commit` (not `git commit-tree`, `git status`,
# `git log --grep="commit"`, `cd /tmp && git status`). Strip `-c key=val` and
# `-C dir` flag segments first — handles quoted values containing spaces.
# The previous regex form `( +-[cC] +[^ ]+)*` had a latent bug: `[^ ]+`
# consumes up to the first space, so `git -c devshop.foo="quoted val" commit`
# failed to match because the regex couldn't resync past the space inside
# the quoted value. Symptom was harmless (false negative — legitimate commits
# slipped past the on-main check) but the asymmetry with the canonical
# Tier-3 bypass form caused the same class of bug to bite check-hook-bypass.sh
# in PR #19. Stripping flag-segments first via sed handles all three quoting
# forms (double, single, unquoted) cleanly. After stripping, what remains is
# the bare command minus -c/-C flags; the on-`commit` regex then resolves
# unambiguously without space-handling concerns.
PRUNED=$(echo "$CMD" | sed -E '
s/-[cC][[:space:]]+[^[:space:]"'\'']*"[^"]*"//g
s/-[cC][[:space:]]+[^[:space:]"'\'']*'\''[^'\'']*'\''//g
s/-[cC][[:space:]]+[^[:space:]]+//g
')
echo "$PRUNED" | grep -qE '(^|[^a-zA-Z0-9_/])git[[:space:]]+commit([^a-zA-Z0-9_-]|$)' || exit 0

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
