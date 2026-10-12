#!/usr/bin/env bash
# This devshop version's own SessionStart step (the plugin's dispatcher runs it): points the
# project's git at the devshop's hooks, /opt/devshop-current/git-hooks, and keeps the project's own
# core.hooksPath in devshop.chainHooksPath, so the project's hooks still run, chained after the
# devshop's. Session-local git config in this clone; nothing is committed. Feedback, not a wall:
# the agent can change it back, and required CI runs the same checks.
hooks=/opt/devshop-current/git-hooks
proj=${CLAUDE_PROJECT_DIR:-.}
git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 || exit 0
top=$(git -C "$proj" rev-parse --show-toplevel)

# The repo's declared session setup (e.g. `npm ci` for its pinned tools), so its checks can run. The
# repo's own code, like its tests and lint scripts; silent when it works, loud when it fails.
if [ -x "$top/scripts/setup.sh" ]; then
  (cd "$top" && timeout 600 scripts/setup.sh) >/tmp/devshop-project-setup.log 2>&1 \
    || echo "DEVSHOP: the project's setup (scripts/setup.sh) failed (exit $?); its checks may not run: see /tmp/devshop-project-setup.log"
fi
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
