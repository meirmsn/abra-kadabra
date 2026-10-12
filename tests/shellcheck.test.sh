#!/usr/bin/env bash
# Tests scripts/shellcheck.sh, the shell lint CI runs: it must fail on a finding in any shell script
# git knows of (by extension or by shebang), skip the spikes kept as notes, pass on clean scripts,
# and fail closed when shellcheck is missing or there is nothing to check.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/shellcheck.sh"
source "$repo_root/tests/lib.sh"
command -v "${SHELLCHECK:-shellcheck}" >/dev/null || fail "shellcheck not found (set \$SHELLCHECK or put it on PATH)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

run_check() {
  local rc=0
  (cd "$1" && "$script") >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
expect() {
  [ "$3" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $3"; }
  echo "ok - $1"
}
# shellcheck disable=SC2016 # literal script text, not to be expanded here
clean_script='#!/usr/bin/env bash
set -euo pipefail
dir=${1:-.}
ls -- "$dir"'
# SC2086: unquoted expansion, a word-splitting bug.
# shellcheck disable=SC2016
bad_script='#!/usr/bin/env bash
dir=$1
rm -rf $dir/build'

r="$work/clean"; new_repo "$r"
commit_file "$r" run.sh "$clean_script"
expect "clean scripts pass" 0 "$(run_check "$r")"

r="$work/bad-ext"; new_repo "$r"
commit_file "$r" run.sh "$clean_script"
commit_file "$r" build.sh "$bad_script"
expect "a finding in a .sh file fails" 1 "$(run_check "$r")"
grep -q "SC2086" "$work/out.log" || fail "the finding is not reported"

r="$work/bad-shebang"; new_repo "$r"
mkdir -p "$r/bin"; commit_file "$r" bin/build "$bad_script"
expect "a finding in an extensionless script with a shell shebang fails" 1 "$(run_check "$r")"

r="$work/untracked"; new_repo "$r"
commit_file "$r" run.sh "$clean_script"
printf '%s\n' "$bad_script" >"$r/new.sh"
expect "a finding in a new, not yet committed script fails" 1 "$(run_check "$r")"

r="$work/spikes"; new_repo "$r"
commit_file "$r" run.sh "$clean_script"
mkdir -p "$r/kit/notes/revamp/spikes/x"; commit_file "$r" kit/notes/revamp/spikes/x/old.sh "$bad_script"
expect "spikes kept as notes are skipped" 0 "$(run_check "$r")"

r="$work/none"; new_repo "$r"
expect "no shell scripts to check fails" 2 "$(run_check "$r")"

rc=0; (cd "$work/clean" && SHELLCHECK=/nonexistent/shellcheck "$script") >"$work/out.log" 2>&1 || rc=$?
expect "missing shellcheck fails closed" 2 "$rc"
echo "PASS: shellcheck.sh"
