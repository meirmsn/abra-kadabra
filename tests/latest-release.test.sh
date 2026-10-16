#!/usr/bin/env bash
# Tests install/plugin/devshop/upgrade/latest-release.sh (spec specs/devshop-releases.md, AC-9): the
# upgrade skill's default NEW is the newest vX.Y.Z tag (X >= 2) in the local copy, by version order;
# v1's tags, pre-releases and branches never count; no release says so; no git dir can't run.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/install/plugin/devshop/upgrade/latest-release.sh"
source "$repo_root/tests/lib.sh"
[ -x "$script" ] || fail "no executable $script"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
new_repo "$work/ds"
git -C "$work/ds" tag v1.10.2
git -C "$work/ds" tag v1-final
git clone -q --bare "$work/ds" "$work/copy.git"

# run <name> <want exit> <want stdout or ''>
run() {
  local rc=0 out
  out=$("$script" --devshop-git "$work/copy.git" 2>"$work/err") || rc=$?
  [ "$rc" = "$2" ] || { cat "$work/err" >&2; fail "$1: expected exit $2, got $rc"; }
  [ "$out" = "$3" ] || fail "$1: printed '$out', want '$3'"
  echo "ok - $1"
}
run "AC-9: only v1's tags: no release" 1 ''
grep -q "use main" "$work/err" || fail "no release doesn't say to use main"
for t in v2.0.0 v2.9.0 v2.10.0 v3.0.0-rc.1 v20.0; do git --git-dir="$work/copy.git" tag "$t"; done
git --git-dir="$work/copy.git" branch v9.0.0
run "AC-9: the newest by version order; a pre-release, a short tag and a branch don't count" 0 v2.10.0
git --git-dir="$work/copy.git" tag v10.0.0
run "AC-9: v10.0.0 is above v2.10.0" 0 v10.0.0

rc=0; "$script" --devshop-git "$work/nope.git" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a missing git dir: want exit 2, got $rc"
rc=0; "$script" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "no arguments: want exit 2, got $rc"
echo "ok - no git dir or no arguments can't run"

# AC-9: the upgrade skill uses it for its default NEW (step 1) and writes NEW as named (step 3).
skill="$repo_root/install/plugin/devshop/upgrade/skills/upgrade/SKILL.md"
step() { awk -v h="## $1." 'index($0, h) == 1 { on = 1; next } /^## / { on = 0 } on' "$skill"; }
# shellcheck disable=SC2016 # literal text in the skill, not expansions
step 1 | grep -qF 'upgrade/latest-release.sh --devshop-git $D' || fail "AC-9: step 1 doesn't default NEW to latest-release.sh"
# shellcheck disable=SC2016
step 3 | grep -qF 'Write NEW as named (a release tag, else the full SHA) to `.devshop-version`' \
  || fail "AC-9: step 3 doesn't write NEW as named"
echo "ok - AC-9: the upgrade skill's step 1 defaults to the newest release, step 3 writes NEW as named"
