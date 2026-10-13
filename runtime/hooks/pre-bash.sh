#!/usr/bin/env bash
# This devshop version's Bash guard (the plugin's PreToolUse hook on Bash runs it): hands the command
# Claude is about to run to the pinned dcg (Destructive Command Guard), which blocks destructive ones
# (git reset --hard, force pushes, git clean -f, rm -rf, ...) and tells Claude why and what to do
# instead. Fails closed (L-11): a missing dcg, one that fails or hangs, or hook input it can't parse
# blocks the command. Feedback, not a wall (L-36): the agent can get around it (a script file, an
# interpreter); GitHub's protection on main, required CI and the owner's approval are the walls.
dcg=/opt/devshop-tools/bin/dcg
block() {
  echo "devshop pre-bash: $1, so this command was not run. Tell the owner: the environment's setup installs dcg (log: /tmp/devshop-setup.log)." >&2
  exit 2
}
[ -x "$dcg" ] || block "dcg not found at $dcg"
input=$(cat)
out=$(DCG_FAIL_CLOSED=1 timeout 10 "$dcg" <<<"$input" 2>/dev/null)
rc=$?
[ "$rc" != 124 ] || block "dcg timed out after 10 s"
[ "$rc" = 0 ] || block "dcg couldn't run (exit $rc)"
# Empty: allowed. Otherwise dcg's hook JSON, a deny with its reason.
[ -z "$out" ] || printf '%s\n' "$out"
exit 0
