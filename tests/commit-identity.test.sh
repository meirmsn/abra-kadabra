#!/usr/bin/env bash
# Tests scripts/commit-identity-check.sh (L-41): CI must reject any commit a change adds whose
# author or committer is a test identity (an email at a domain reserved for examples and tests,
# like the one tests/lib.sh gives every test repo), pass real identities, and fail closed.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/commit-identity-check.sh"
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work" # every commit below is made by the test identity unless overridden

run_check() {
  local rc=0
  (cd "$1" && "$script" "${2:-}") >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
expect() {
  [ "$3" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $3"; }
  echo "ok - $1"
}
# real_commit <repo> <path>: a commit by a made-up identity outside the reserved domains.
real_commit() {
  GIT_AUTHOR_NAME="Ada Dev" GIT_AUTHOR_EMAIL="ada@devshop-dev.io" \
    GIT_COMMITTER_NAME="Ada Dev" GIT_COMMITTER_EMAIL="ada@devshop-dev.io" commit_file "$@"
}

r="$work/clean"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
real_commit "$r" a.txt "a"
real_commit "$r" b.txt "b"
# new_repo's first commit is a test one, but it is before the base, so not this change's.
expect "commits by real identities pass" 0 "$(run_check "$r" "$base")"

r="$work/fixture"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
real_commit "$r" a.txt "a"
commit_file "$r" b.txt "b" # the identity tests/lib.sh sets
real_commit "$r" c.txt "c"
expect "a commit by the tests' own identity fails" 1 "$(run_check "$r" "$base")"
grep -q "scan-test@example.com" "$work/out.log" || fail "the offending identity is not named"

r="$work/committer"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
GIT_AUTHOR_NAME="Ada Dev" GIT_AUTHOR_EMAIL="ada@devshop-dev.io" commit_file "$r" a.txt "a"
expect "a real author with a test committer fails" 1 "$(run_check "$r" "$base")"

for email in bot@example.org x@ci.example.net Someone@EXAMPLE.COM t@fixture.test t@host.invalid \
  t@localhost t@box.localhost t@acme.example test@test.com; do
  r="$work/domain-$email"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
  GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_EMAIL="ada@devshop-dev.io" commit_file "$r" a.txt "a"
  expect "reserved test domain fails: $email" 1 "$(run_check "$r" "$base")"
done

for email in ada@example.com.au ada@myexample.com ada@testing.io ada@latest.com; do
  r="$work/lookalike-$email"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
  GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_EMAIL="$email" commit_file "$r" a.txt "a"
  expect "a lookalike real domain passes: $email" 0 "$(run_check "$r" "$base")"
done

# No base (new branch, all-zero sha) checks all history: new_repo's first commit is a test one.
expect "no base checks all history" 1 "$(run_check "$work/clean" "")"
expect "all-zero base checks all history" 1 "$(run_check "$work/clean" 0000000000000000000000000000000000000000)"

expect "unknown base fails closed" 2 "$(run_check "$work/clean" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"
expect "outside a git repo fails closed" 2 "$(run_check "$work" "")"
echo "PASS: commit-identity-check.sh"
