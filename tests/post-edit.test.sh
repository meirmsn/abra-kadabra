#!/usr/bin/env bash
# Tests the devshop's per-edit nudge: the plugin's PostToolUse hook (install/plugin/devshop/hooks/
# hooks.json) runs this version's runtime/hooks/post-edit.sh, which runs the repo's own
# `scripts/lint-file.sh <file>` on the file Claude just edited. Findings and "couldn't run" go back
# to Claude (exit 2, stderr) in the same turn; clean is silent. Feedback, not a wall: the pre-push
# hook and required CI run the full checks. Runs in a private mount namespace with a scratch /opt.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
command -v jq >/dev/null || fail "jq not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
ln -s "$repo_root/runtime" /opt/devshop-current
mkdir -p /opt/devshop-tools/bin

# The command the plugin registers for PostToolUse on Claude's edit tools.
hooks_json="$repo_root/install/plugin/devshop/hooks/hooks.json"
matcher=$(jq -er '.hooks.PostToolUse[0].matcher' "$hooks_json") || fail "the plugin registers no PostToolUse hook"
for tool in Edit Write MultiEdit; do
  grep -Eqx "$matcher" <<<"$tool" || fail "PostToolUse matcher '$matcher' misses $tool"
done
cmd=$(jq -er '.hooks.PostToolUse[0].hooks[0].command' "$hooks_json")

# A project whose scripts/lint-file.sh records its argument and exits with .lint-rc's number.
new_repo "$work/p"
mkdir -p "$work/p/scripts" "$work/p/src"
# shellcheck disable=SC2016  # the fake lint-file.sh's source
printf '#!/usr/bin/env bash\necho "$1" >.lint-arg\necho "lint-file says: problem in $1"\nexit "$(cat .lint-rc)"\n' >"$work/p/scripts/lint-file.sh"
chmod +x "$work/p/scripts/lint-file.sh"
echo "x" >"$work/p/src/a.sh"

# edit <file> [PATH]: run the hook as Claude Code does after an Edit of <file>; sets out and rc.
edit() {
  local input
  input=$(jq -nc --arg f "$1" '{tool_name: "Edit", tool_input: {file_path: $f}}')
  rc=0
  out=$(cd "$work/p" && PATH=${2:-$PATH} CLAUDE_PROJECT_DIR="$work/p" bash -c "$cmd" <<<"$input" 2>&1) || rc=$?
}

echo 1 >"$work/p/.lint-rc" && edit "$work/p/src/a.sh"
{ [ "$rc" = 2 ] && grep -q "problem in src/a.sh" <<<"$out"; } || { echo "$out" >&2; fail "findings: want exit 2 with lint-file's output, got $rc"; }
[ "$(cat "$work/p/.lint-arg")" = src/a.sh ] || fail "lint-file.sh got '$(cat "$work/p/.lint-arg")', want the repo-relative path"
echo "ok - findings go back to Claude (exit 2) with lint-file.sh's output, for the repo-relative path"

echo 2 >"$work/p/.lint-rc" && edit "$work/p/src/a.sh"
{ [ "$rc" = 2 ] && grep -q "couldn't run" <<<"$out"; } || { echo "$out" >&2; fail "can't run: want exit 2 saying it couldn't run, got $rc"; }
echo "ok - lint-file.sh that can't run is reported, never silent"

echo 0 >"$work/p/.lint-rc" && edit "$work/p/src/a.sh"
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || { echo "$out" >&2; fail "clean: want exit 0 and no output, got $rc"; }
echo "ok - a clean file is silent"

rm -f "$work/p/.lint-arg" && echo 1 >"$work/p/.lint-rc"
echo "x" >"$work/outside.sh" && edit "$work/outside.sh"
{ [ "$rc" = 0 ] && [ ! -e "$work/p/.lint-arg" ]; } || fail "a file outside the project was linted"
echo "ok - files outside the project are left alone"

mv "$work/p/scripts/lint-file.sh" "$work/p/scripts/off" && edit "$work/p/src/a.sh"
{ [ "$rc" = 0 ] && [ -z "$out" ]; } || { echo "$out" >&2; fail "no lint-file.sh: want silent exit 0, got $rc"; }
mv "$work/p/scripts/off" "$work/p/scripts/lint-file.sh"
echo "ok - a repo that declares no per-file lint gets no nudge"

# No jq: the hook can't read which file was edited; it says so instead of passing silently.
mkdir -p "$work/minbin"
for t in bash git cat dirname readlink realpath env; do ln -sf "$(command -v "$t")" "$work/minbin/$t"; done
edit "$work/p/src/a.sh" "$work/minbin"
{ [ "$rc" = 2 ] && grep -q "jq not found" <<<"$out"; } || { echo "$out" >&2; fail "no jq: want exit 2 saying so, got $rc"; }
echo "ok - missing jq is reported, never a silent pass"

echo "all post-edit scenarios passed"
