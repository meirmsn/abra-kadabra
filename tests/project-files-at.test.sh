#!/usr/bin/env bash
# Tests install/plugin/devshop/upgrade/project-files-at.sh (W10.4.8): it runs the given version's
# own runtime/scripts/project-files.py from a devshop git dir, so an upgrade uses the target
# version's code, not the pinned one's. A scratch devshop has v0 (no script), v1 and v2 (each a
# script that says which version it is and exits 7). It runs the version asked for, passes the
# arguments and the exit status through, and can't run (exit 2) on an unknown or malformed
# version, a version without the script, a missing argument, a missing git dir or no python3.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
wrapper="$repo_root/install/plugin/devshop/upgrade/project-files-at.sh"
[ -x "$wrapper" ] || fail "no executable install/plugin/devshop/upgrade/project-files-at.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

ds="$work/devshop"
new_repo "$ds"
v0=$(git -C "$ds" rev-parse HEAD)
mkdir -p "$ds/runtime/scripts"
# version_script <name>: commit a project-files.py that prints <name> and its arguments, exits 7; echo the SHA.
version_script() {
  printf 'import sys\nprint("%s", *sys.argv[1:])\nsys.exit(7)\n' "$1" >"$ds/runtime/scripts/project-files.py"
  git -C "$ds" add -A && git -C "$ds" commit -qm "$1"
  git -C "$ds" rev-parse HEAD
}
v1=$(version_script v1)
v2=$(version_script v2)

# run <name> <want exit> <pattern the output must match, or ''> -- <wrapper args>
run() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  "$wrapper" "$@" >"$work/out" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$pat" ] || grep -Eq -- "$pat" "$work/out" || { cat "$work/out" >&2; fail "$name: output lacks /$pat/"; }
  echo "ok - $name"
}

run "runs the asked version's script with the arguments, exit passed through" 7 '^v1 plan --devshop-git [^ ]+ --from a --to b$' \
  -- --devshop-git "$ds/.git" --at "$v1" plan --from a --to b
run "another version runs its own script" 7 '^v2 check --devshop-git [^ ]+$' -- --devshop-git "$ds/.git" --at "$v2" check
run "a version given by name runs" 7 '^v2 check --devshop-git [^ ]+$' -- --devshop-git "$ds/.git" --at main check
run "a version without the script can't run" 2 'has no runtime/scripts/project-files\.py' \
  -- --devshop-git "$ds/.git" --at "$v0" check
run "a version not in the copy can't run and says to rebuild" 2 'rebuild' \
  -- --devshop-git "$ds/.git" --at 0000000000000000000000000000000000000000 check
run "a version that looks like an option can't run" 2 'not a devshop version' -- --devshop-git "$ds/.git" --at --all check
run "a missing --at can't run" 2 'usage' -- --devshop-git "$ds/.git" check
run "a missing command can't run" 2 'usage' -- --devshop-git "$ds/.git" --at "$v1"
run "a missing devshop git dir can't run" 2 'no devshop git dir' -- --devshop-git "$work/nope.git" --at "$v1" check
mkdir -p "$work/nopy"
for t in git mktemp rm cat dirname; do ln -s "$(command -v "$t")" "$work/nopy/$t"; done
rc=0 && PATH="$work/nopy" "$BASH" "$wrapper" --devshop-git "$ds/.git" --at "$v1" check >"$work/out" 2>&1 || rc=$?
if [ "$rc" != 2 ] || ! grep -q python3 "$work/out"; then
  cat "$work/out" >&2
  fail "no python3: expected exit 2 naming python3, got $rc"
fi
echo "ok - no python3 can't run"

# The real thing: with this repo as the copy, HEAD's project-files.py runs (its usage error, exit 2).
run "this repo's own script runs at HEAD" 2 'usage: project-files\.py' -- --devshop-git "$repo_root/.git" --at HEAD sync
