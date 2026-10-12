#!/usr/bin/env bash
# This devshop version's own SessionStart step (the plugin's dispatcher runs it): points the
# project's git at the devshop's hooks, /opt/devshop-current/git-hooks, and keeps the project's own
# core.hooksPath in devshop.chainHooksPath, so the project's hooks still run, chained after the
# devshop's. Session-local git config in this clone; nothing is committed. Feedback, not a wall:
# the agent can change it back, and required CI runs the same checks.
hooks=/opt/devshop-current/git-hooks
proj=${CLAUDE_PROJECT_DIR:-.}
git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 || exit 0
cur=$(git -C "$proj" config --get core.hooksPath)
[ "$cur" = "$hooks" ] && exit 0
if git -C "$proj" config --get devshop.chainHooksPath >/dev/null; then
  echo "DEVSHOP: core.hooksPath had been changed to '${cur:-git default}' after the devshop set it; set back to the devshop's hooks"
else
  git -C "$proj" config devshop.chainHooksPath "$cur"
fi
git -C "$proj" config core.hooksPath "$hooks" \
  || echo "DEVSHOP: couldn't point core.hooksPath at $hooks; the devshop's git hooks won't run"
exit 0
