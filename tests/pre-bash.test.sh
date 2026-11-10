#!/usr/bin/env bash
# Tests the devshop's Bash guard: the plugin's PreToolUse hook on Bash (install/plugin/devshop/hooks/
# hooks.json) runs this version's runtime/hooks/pre-bash.sh, which asks the pinned dcg (Destructive
# Command Guard) about the command before it runs. Destructive commands are blocked with dcg's
# reason; others pass silently; a missing, failing or hung dcg, or input it can't parse, blocks
# (fails closed, L-11). Feedback, not a wall (L-36). Uses the real dcg (version pinned in ci.yml).
# Runs in a private mount namespace with a scratch /opt.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

real_dcg=$(command -v dcg) || fail "dcg not found (install the version pinned in .github/workflows/ci.yml)"
if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# In a devshop session the dcg on PATH lives under /opt, which the scratch /opt hides: copy it.
cp "$(readlink -f "$real_dcg")" "$work/dcg" || fail "can't copy $real_dcg"
real_dcg=$work/dcg
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
command -v jq >/dev/null || fail "jq not found"

export HOME="$work/home" && mkdir -p "$HOME"
ln -s "$repo_root/runtime" /opt/devshop-current
mkdir -p /opt/devshop-tools/bin
ln -s "$real_dcg" /opt/devshop-tools/bin/dcg

# The command the plugin registers for PreToolUse on Bash.
hooks_json="$repo_root/install/plugin/devshop/hooks/hooks.json"
matcher=$(jq -er '.hooks.PreToolUse[0].matcher' "$hooks_json") || fail "the plugin registers no PreToolUse hook"
grep -Eqx "$matcher" <<<"Bash" || fail "PreToolUse matcher '$matcher' misses Bash"
cmd=$(jq -er '.hooks.PreToolUse[0].hooks[0].command' "$hooks_json")
# The command runs the plugin's own bash-gate.sh, from the plugin's root as Claude Code sets it.
export CLAUDE_PLUGIN_ROOT="$repo_root/install/plugin/devshop"

# run_raw <stdin>: run the hook as Claude Code does before a Bash call; sets out, err and rc.
run_raw() {
  rc=0
  out=$(bash -c "$cmd" <<<"$1" 2>"$work/err") || rc=$?
  err=$(cat "$work/err")
}
# run <command>: the hook input for a Bash call of <command>.
run() { run_raw "$(jq -nc --arg c "$1" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')"; }
# denied_by_dcg: dcg's own block, as Claude Code's hook JSON on stdout (exit 0).
denied_by_dcg() {
  [ "$rc" = 0 ] && [ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out" 2>/dev/null)" = deny ] \
    && jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out" | grep -q "BLOCKED by dcg"
}

for c in 'git reset --hard' 'git push --force origin main' 'git clean -fd' 'git checkout -- .' 'rm -rf ./build'; do
  run "$c"
  denied_by_dcg || { echo "rc=$rc out=$out err=$err" >&2; fail "'$c' was not blocked by dcg"; }
done
echo "ok - destructive commands are blocked with dcg's reason"

for c in 'ls -la' 'git status' 'git stash' 'git push origin HEAD' 'npm ci'; do
  run "$c"
  { [ "$rc" = 0 ] && [ -z "$out" ]; } || { echo "rc=$rc out=$out err=$err" >&2; fail "'$c' was not let through silently"; }
done
echo "ok - ordinary commands pass silently"
# With dcg present, the repair command too goes to dcg: a stand-in dcg that blocks everything shows it.
printf '#!/usr/bin/env bash\necho "dcg saw it" >&2\nexit 7\n' >"$work/dcg-all" && chmod +x "$work/dcg-all"
ln -sfn "$work/dcg-all" /opt/devshop-tools/bin/dcg
run /opt/devshop-plugin/devshop/hooks/repair-tools.sh
[ "$rc" = 2 ] || { echo "rc=$rc out=$out err=$err" >&2; fail "pinned-tools-survive-outage AC-6: with dcg present, the repair command skipped pre-bash.sh"; }
ln -sfn "$real_dcg" /opt/devshop-tools/bin/dcg
echo "ok - pinned-tools-survive-outage AC-6: with dcg present, the repair command goes through pre-bash.sh like any other"

run_raw "not json"
denied_by_dcg || { echo "rc=$rc out=$out err=$err" >&2; fail "unparseable hook input was not blocked"; }
echo "ok - hook input dcg can't parse is blocked (dcg's own default is to allow it)"

# blocked_by_hook <what>: the hook's own block (exit 2, reason on stderr), naming <what>.
blocked_by_hook() { [ "$rc" = 2 ] && grep -q "$1" <<<"$err" && grep -q "was not run" <<<"$err"; }

rm /opt/devshop-tools/bin/dcg
run 'ls -la'
blocked_by_hook "dcg not found" || { echo "rc=$rc out=$out err=$err" >&2; fail "missing dcg: want exit 2 saying so"; }
echo "ok - a missing dcg blocks, never a silent pass"

# pinned-tools-survive-outage AC-6: without dcg, only the exact repair command gets through the gate.
REPAIR=/opt/devshop-plugin/devshop/hooks/repair-tools.sh
run "$REPAIR"
{ [ "$rc" = 0 ] && [ -z "$out" ] && [ -z "$err" ]; } || { echo "rc=$rc out=$out err=$err" >&2; fail "pinned-tools-survive-outage AC-6: the exact repair command was not let through without dcg"; }
for c in "$REPAIR --help" "$REPAIR; true" "$REPAIR && true" "$REPAIR | cat" "bash $REPAIR" " $REPAIR" "$REPAIR " "$REPAIR"$'\n' \
  "$REPAIR"$'\n'"ls" "/opt/devshop-plugin/devshop/hooks/../hooks/repair-tools.sh" "/opt/devshop-plugin/devshop/hooks/repair-tools.shx" 'ls -la'; do
  run "$c"
  blocked_by_hook "dcg not found" || { echo "rc=$rc out=$out err=$err" >&2; fail "pinned-tools-survive-outage AC-6: '$c' got through the gate without dcg"; }
done
run_raw "not json"
blocked_by_hook "dcg not found" || { echo "rc=$rc out=$out err=$err" >&2; fail "pinned-tools-survive-outage AC-6: input that isn't JSON got through the gate"; }
run_raw "$(jq -nc --arg c "$REPAIR" '{tool_name: "Bash", tool_input: {command: [$c]}}')"
blocked_by_hook "dcg not found" || fail "pinned-tools-survive-outage AC-6: a command that isn't a string got through the gate"
# Without jq on PATH the gate can't compare, so every command goes to pre-bash.sh.
mkdir -p "$work/nojq"
for t in bash cat dirname timeout; do ln -sf "$(command -v "$t")" "$work/nojq/$t"; done
rc=0
err=$(PATH="$work/nojq" bash -c "$cmd" 2>&1 >/dev/null <<<"$(jq -nc --arg c "$REPAIR" '{tool_input: {command: $c}}')") || rc=$?
{ [ "$rc" = 2 ] && grep -q "dcg not found" <<<"$err"; } || { echo "rc=$rc err=$err" >&2; fail "pinned-tools-survive-outage AC-6: without jq the repair command got through the gate"; }
rc=0
bash "$CLAUDE_PLUGIN_ROOT/hooks/bash-gate.sh" <<<'{"tool_input":{"command":"ls"}}' 2>/dev/null || rc=$?
[ "$rc" = 2 ] || fail "bash-gate.sh with no guard named didn't block (exit $rc)"
echo "ok - pinned-tools-survive-outage AC-6: without dcg only the exact repair command passes; anything added, non-JSON input or no jq goes to pre-bash.sh and is blocked"

printf '#!/usr/bin/env bash\necho "dcg crashed" >&2\nexit 3\n' >"$work/dcg-broken" && chmod +x "$work/dcg-broken"
ln -sfn "$work/dcg-broken" /opt/devshop-tools/bin/dcg
run 'ls -la'
blocked_by_hook "couldn't run (exit 3)" || { echo "rc=$rc out=$out err=$err" >&2; fail "failing dcg: want exit 2 saying so"; }
echo "ok - a dcg that fails blocks"

printf '#!/usr/bin/env bash\nsleep 60\n' >"$work/dcg-hung" && chmod +x "$work/dcg-hung"
ln -sfn "$work/dcg-hung" /opt/devshop-tools/bin/dcg
start=$(date +%s)
run 'ls -la'
blocked_by_hook "timed out" || { echo "rc=$rc out=$out err=$err" >&2; fail "hung dcg: want exit 2 saying it timed out"; }
[ $(($(date +%s) - start)) -lt 30 ] || fail "hung dcg: the hook outlived its own timeout"
timeout=$(jq -er '.hooks.PreToolUse[0].hooks[0].timeout' "$hooks_json") || fail "the PreToolUse hook sets no timeout"
[ "$timeout" -gt 10 ] || fail "the hook's timeout ($timeout s) must exceed the script's 10 s dcg limit, or Claude Code's timeout lets the command through"
echo "ok - a hung dcg blocks within the hook's own timeout"

echo "all pre-bash scenarios passed"
