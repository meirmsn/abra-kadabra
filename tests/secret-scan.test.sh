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

# Lockfiles resolve packages only from a public registry (F-NEW-146): a session's npm can copy a
# preinstalled tree's internal mirror URLs into one, and the host then leaks into public history and
# CI's `npm ci` hangs. A registry the project names in its committed .npmrc is allowed. The host is
# never printed whole (CI logs can be public).
lock() { # lock <url>: an npm lockfile resolving one package from <url>
  printf '{\n  "packages": {\n    "node_modules/a": {\n      "resolved": "%s/a/-/a-1.0.0.tgz"\n    }\n  }\n}\n' "$1"
}
expect_lock() { # expect_lock <name> <rc>: a lockfile failure, naming the file, never the whole host
  { [ "$2" = 1 ] && grep -q "lockfile resolves from a registry that isn't public" "$work/out.log" \
    && ! grep -q "mirror.internal.example.com" "$work/out.log"; } \
    || { cat "$work/out.log" >&2; fail "$1: expected a lockfile failure without the host, got exit $2"; }
  echo "ok - $1"
}
r="$work/lock-public"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" package-lock.json "$(lock https://registry.npmjs.org)"
expect "a lockfile on the public registry passes" pass "$(run_scan "$r" "$base")"
r="$work/lock-internal"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" package-lock.json "$(lock https://mirror.internal.example.com/api/npm)"
expect_lock "a lockfile on an internal mirror fails" "$(run_scan "$r" "$base")"
grep -q "package-lock.json" "$work/out.log" || fail "the lockfile failure doesn't name the file"
r="$work/lock-fixed"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" package-lock.json "$(lock http://mirror.internal.example.com)"
commit_file "$r" package-lock.json "$(lock https://registry.npmjs.org)"
expect_lock "an internal mirror URL added then fixed in the change fails (it stays in its commits)" "$(run_scan "$r" "$base")"
r="$work/lock-yarn"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD); mkdir -p "$r/web"
commit_file "$r" web/yarn.lock "$(printf 'a@^1.0.0:\n  version "1.0.0"\n  resolved "https://mirror.internal.example.com/a/-/a-1.0.0.tgz#abc"\n')"
expect_lock "a yarn.lock on an internal mirror fails, in a subdirectory too" "$(run_scan "$r" "$base")"
r="$work/lock-tree"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
lock https://mirror.internal.example.com >"$r/npm-shrinkwrap.json"
expect_lock "an uncommitted lockfile on an internal mirror fails" "$(run_scan "$r" "$base")"
r="$work/lock-tree-yarn"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
printf 'a@^1.0.0:\n  resolved "https://mirror.internal.example.com/a.tgz"\n' >"$r/yarn.lock"
expect_lock "an uncommitted yarn.lock on an internal mirror fails" "$(run_scan "$r" "$base")"
r="$work/lock-npmrc"; new_repo "$r"; base=$(git -C "$r" rev-parse HEAD)
commit_file "$r" .npmrc "@acme:registry=https://npm.example.com/"
commit_file "$r" package-lock.json "$(lock https://npm.example.com)"
expect "a registry the committed .npmrc names passes" pass "$(run_scan "$r" "$base")"
r="$work/lock-internal"; base=$(git -C "$r" rev-list --max-parents=0 HEAD)
rc=0; (cd "$r" && GITLEAKS=/nonexistent/gitleaks "$script" --lockfiles "$base") >"$work/out.log" 2>&1 || rc=$?
expect_lock "--lockfiles checks the lockfiles alone, with no gitleaks" "$rc"
rc=0; (cd "$work/lock-public" && GITLEAKS=/nonexistent/gitleaks "$script" --lockfiles) >"$work/out.log" 2>&1 || rc=$?
expect "--lockfiles passes clean lockfiles" pass "$rc"

# Bad input fails closed: an unknown base, and a missing gitleaks.
expect "unknown base fails closed" 2 "$(run_scan "$work/clean" deadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"
rc=0; (cd "$work/clean" && GITLEAKS=/nonexistent/gitleaks "$script") >"$work/out.log" 2>&1 || rc=$?
expect "missing gitleaks fails closed" 2 "$rc"
echo "PASS: secret-scan.sh"
