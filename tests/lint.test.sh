#!/usr/bin/env bash
# Tests scripts/lint.sh, this repo's declared lint: CI's `fast` job (through scripts/check-fast.sh)
# and the devshop's pre-push hook both run it, so they can't drift. It must run every check even after one fails, pass the base to
# the commit-identity check, and exit 2 if any check couldn't run, else 1 on any findings, else 0.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/runtime/scripts"
cp "$repo_root/scripts/lint.sh" "$work/scripts/"
# Stub checks: each records that it ran (and its arguments) and exits with its .rc file's number.
checks=(format-check.sh shellcheck.sh docs-map-check.py commit-identity-check.sh ci-tiers-check.py)
for c in "${checks[@]}"; do
  dir=scripts
  [ "$c" != ci-tiers-check.py ] || dir=runtime/scripts
  # shellcheck disable=SC2016  # the stub's source
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/ran"\nexit "$(cat "%s/%s.rc")"\n' "$c" "$work" "$work" "$c" >"$work/$dir/$c"
  chmod +x "$work/$dir/$c"
done

# run <rc for each check, in order>: run lint.sh with base "b4se"; echo its exit code.
run() {
  local rc=0
  for c in "${checks[@]}"; do echo "${1:-0}" >"$work/$c.rc"; shift || true; done
  rm -f "$work/ran"
  (cd "$work" && scripts/lint.sh b4se) >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}

[ "$(run 0 0 0 0 0)" = 0 ] || { cat "$work/out" >&2; fail "all clean: want 0"; }
[ "$(wc -l <"$work/ran")" = 5 ] || fail "not every check ran"
grep -qx "commit-identity-check.sh b4se" "$work/ran" || fail "the base didn't reach commit-identity-check.sh: $(cat "$work/ran")"
grep -qx "ci-tiers-check.py .github/workflows/ci.yml" "$work/ran" || fail "AC-6: ci-tiers-check.py didn't check this repo's ci.yml: $(cat "$work/ran")"
echo "ok - all five checks run (AC-6: incl. the CI shape check on ci.yml), the base reaches the commit-identity check, clean is 0"

[ "$(run 1 0 0 0 0)" = 1 ] || fail "findings in the first check: want 1"
[ "$(wc -l <"$work/ran")" = 5 ] || fail "a failing check stopped the others"
echo "ok - findings exit 1, and every check still runs"

[ "$(run 0 0 0 0 1)" = 1 ] || fail "AC-6: CI shape findings: want 1"
grep -q "ci-tiers-check.py found problems" "$work/out" || { cat "$work/out" >&2; fail "AC-6: CI shape findings not named"; }
[ "$(run 0 2 1 0 0)" = 2 ] || fail "one check couldn't run: want 2"
grep -q "shellcheck.sh couldn't run" "$work/out" || { cat "$work/out" >&2; fail "lint.sh doesn't name the check that couldn't run"; }
echo "ok - a check that can't run makes it exit 2 (never a pass), named"

# CI's fast tier runs exactly this script, with the change's base.
grep -qx 'part scripts/lint.sh "${1:-}"' "$repo_root/scripts/check-fast.sh" || fail "check-fast.sh doesn't run scripts/lint.sh with the base"
echo "ok - CI's fast tier (check-fast.sh) runs scripts/lint.sh with the base"

echo "PASS: lint.sh"
