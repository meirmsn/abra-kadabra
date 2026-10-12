#!/usr/bin/env bash
# Tests scripts/secret-scan.sh, the scan CI runs: it must fail on a secret anywhere in the commits
# a change adds or in the working tree, pass when both are clean, and fail closed on bad input.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/secret-scan.sh"
source "$repo_root/tests/lib.sh"
command -v "${GITLEAKS:-gitleaks}" >/dev/null || fail "gitleaks not found (set \$GITLEAKS or put it on PATH)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# run_scan <repo> [base]: echo the script's exit code.
run_scan() {
  local rc=0
  (cd "$1" && "$script" "${2:-}") >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
# expect <name> <want: pass|fail (= leaks reported)|<exit code>> <rc>
expect() {
  case "$2" in
    pass) [ "$3" = 0 ] ;;
    fail) [ "$3" = 1 ] && grep -q "leaks found" "$work/out.log" ;;
    *) [ "$3" = "$2" ] ;;
  esac || { cat "$work/out.log" >&2; fail "$1: expected $2, got exit $3"; }
  echo "ok - $1"
}

# A clean change passes.
r="$work/clean"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" app.txt "nothing secret here"
expect "clean change passes" pass "$(run_scan "$r" "$base")"

# A secret in a commit the change adds fails.
r="$work/added"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" keys.ini "aws_access_key_id = $(fake_aws_key)"
expect "secret added by the change fails" fail "$(run_scan "$r" "$base")"

# A secret added then deleted within the change still fails (it stays in the PR's commits).
r="$work/deleted"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" keys.ini "aws_access_key_id = $(fake_aws_key)"
git -C "$r" rm -q keys.ini && git -C "$r" commit -qm "remove keys"
expect "secret added then removed in the change fails" fail "$(run_scan "$r" "$base")"

# A secret only in the working tree (not committed) fails.
r="$work/tree"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" >"$r/untracked.ini"
expect "secret in the working tree fails" fail "$(run_scan "$r" "$base")"

# No base (new branch, all-zero sha) scans all history: an old secret fails.
r="$work/nobase"; new_repo "$r"
commit_file "$r" keys.ini "aws_access_key_id = $(fake_aws_key)"
git -C "$r" rm -q keys.ini && git -C "$r" commit -qm "remove keys"
expect "no base scans all history" fail "$(run_scan "$r" "")"
expect "all-zero base scans all history" fail "$(run_scan "$r" 0000000000000000000000000000000000000000)"

# Bad input fails closed: an unknown base, and a missing gitleaks.
expect "unknown base fails closed" 2 "$(run_scan "$work/clean" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"
rc=0; (cd "$work/clean" && GITLEAKS=/nonexistent/gitleaks "$script") >"$work/out.log" 2>&1 || rc=$?
expect "missing gitleaks fails closed" 2 "$rc"
echo "PASS: secret-scan.sh"
