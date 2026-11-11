#!/usr/bin/env bash
# The plugin's PreToolUse hook on Bash. Usage: bash-gate.sh <guard>, the devshop version's Bash guard
# (hooks.json passes /opt/devshop-current/hooks/pre-bash.sh; versions' session-start scripts look for
# that path in hooks.json to know the guard is registered). Hands the call to the guard, which fails
# closed without dcg. One exception
# (specs/pinned-tools-survive-outage.md): while dcg is missing, the exact command
# /opt/devshop-plugin/devshop/hooks/repair-tools.sh, compared byte for byte inside jq (nothing
# trimmed), is allowed, so a session can repair the tool that unblocks Bash. Any other input, input
# jq can't parse, or no jq at all, goes to pre-bash.sh as before. No version active (no pre-bash.sh):
# allowed, as before. Feedback, not a wall: a session that can write /opt can change what that
# command runs.
REPAIR_CMD=/opt/devshop-plugin/devshop/hooks/repair-tools.sh
guard=${1:-}
# No guard named: blocked (exit 2), never let through (an exit 1 would let the command run).
[ -n "$guard" ] || { echo "devshop bash-gate: no guard named (usage: bash-gate.sh <guard>), so this command was not run. Tell the owner." >&2; exit 2; }
input=$(cat; echo x)
input=${input%x}
if [ ! -x /opt/devshop-tools/bin/dcg ] && command -v jq >/dev/null 2>&1 \
  && printf '%s' "$input" | jq -e --arg c "$REPAIR_CMD" '.tool_input.command == $c' >/dev/null 2>&1; then
  exit 0
fi
[ -x "$guard" ] || exit 0
printf '%s' "$input" | exec "$guard"
