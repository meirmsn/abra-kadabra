#!/usr/bin/env bash
# Tests scripts/check-fast.sh and scripts/check-slow.sh, this repo's two CI tiers (spec
# specs/ci-fast-slow-tiers.md, AC-5). check-fast.sh <base> runs the secret scan and lint with the
# base, then the fast tests; check-slow.sh runs the slow tests. Each runs every part even after one
# fails and exits with the worst: 2 if any couldn't run, else 1 on any failure, else 0.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/scripts" "$work/tests"
cp "$repo_root/scripts/check-fast.sh" "$repo_root/scripts/check-slow.sh" "$work/scripts/"
# Stub parts: each records that it ran (and its arguments) and exits with its .rc file's number.
parts=(scripts/secret-scan.sh scripts/lint.sh tests/run.sh)
for p in "${parts[@]}"; do
  rcfile="$work/$(basename "$p").rc"
  # shellcheck disable=SC2016  # the stub's source
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/ran"\nexit "$(cat "%s")"\n' "$p" "$work" "$rcfile" >"$work/$p"
  chmod +x "$work/$p"
done

# run <script> <rc for secret-scan, lint, run.sh>: run it with base "b4se"; echo its exit code.
run() {
  local s=$1 rc=0
  shift
  for p in "${parts[@]}"; do echo "${1:-0}" >"$work/$(basename "$p").rc"; shift || true; done
  rm -f "$work/ran"
  (cd "$work" && "scripts/$s" b4se) >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}
ran() { tr '\n' '|' <"$work/ran"; }

[ "$(run check-fast.sh 0 0 0)" = 0 ] || { cat "$work/out" >&2; fail "AC-5: fast, all clean: want 0"; }
[ "$(ran)" = "scripts/secret-scan.sh b4se|scripts/lint.sh b4se|tests/run.sh fast|" ] || fail "AC-5: check-fast.sh ran '$(ran)'"
echo "ok - AC-5: check-fast.sh runs the secret scan and lint with the base, then the fast tests; clean is 0"

[ "$(run check-fast.sh 1 0 0)" = 1 ] || fail "AC-5: a secret found: want 1"
[ "$(wc -l <"$work/ran")" = 3 ] || fail "AC-5: a failing part stopped the others: $(ran)"
grep -q "secret-scan.sh failed" "$work/out" || { cat "$work/out" >&2; fail "AC-5: the failing part isn't named"; }
echo "ok - AC-5: a failure exits 1, named, and every part still runs"

[ "$(run check-fast.sh 0 2 1)" = 2 ] || fail "AC-5: lint couldn't run: want 2"
grep -q "lint.sh couldn't run" "$work/out" || { cat "$work/out" >&2; fail "AC-5: the part that couldn't run isn't named"; }
echo "ok - AC-5: a part that couldn't run makes it exit 2 (never a pass)"

[ "$(run check-slow.sh 0 0 0)" = 0 ] || { cat "$work/out" >&2; fail "AC-5: slow, clean: want 0"; }
[ "$(ran)" = "tests/run.sh slow|" ] || fail "AC-5: check-slow.sh ran '$(ran)'"
[ "$(run check-slow.sh 0 0 1)" = 1 ] || fail "AC-5: slow tests failing: want 1"
echo "ok - AC-5: check-slow.sh runs the slow tests and passes on their result"

echo "PASS: check-fast.sh, check-slow.sh"
