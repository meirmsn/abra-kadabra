#!/usr/bin/env bash
# Tests tests/run.sh's tiers (spec specs/ci-fast-slow-tiers.md, AC-4): a test file is slow when its
# leading comment block has the exact line "# tier: slow". `run.sh fast` runs the others, `run.sh
# slow` only those, `run.sh` all; an unknown tier and a tier with no files fail; the marker further
# down a file (in a heredoc, say) doesn't count. Runs a copy of run.sh over fake test files.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/tests"
cp "$repo_root/tests/run.sh" "$work/tests/"
# fake <name> <header lines…>: a test file that records its name when run.
fake() {
  local name="$1.test.sh"
  shift
  { echo '#!/usr/bin/env bash'; printf '%s\n' "$@"; echo "echo $name >>\"\$(dirname \"\$0\")/ran\""; } >"$work/tests/$name"
}
fake unit-a '# A unit test.'
fake unit-b '# A unit test whose body mentions the marker.' 'cat <<EOF' '# tier: slow' 'EOF'
fake e2e '# An end-to-end test.' '# tier: slow' 'set -e'

# run <args…>: run the copy; set rc and ran (the files it ran, sorted, space-separated).
run() {
  rm -f "$work/tests/ran"
  rc=0
  "$work/tests/run.sh" "$@" >"$work/out" 2>&1 || rc=$?
  ran=$( (sort "$work/tests/ran" 2>/dev/null || true) | tr "\n" " ")
}

run fast
{ [ "$rc" = 0 ] && [ "$ran" = "unit-a.test.sh unit-b.test.sh " ]; } || { cat "$work/out" >&2; fail "AC-4: fast ran '$ran' (rc $rc), want the two unmarked files"; }
echo "ok - AC-4: run.sh fast runs every file without the marker, and a marker below the header doesn't count"
run slow
{ [ "$rc" = 0 ] && [ "$ran" = "e2e.test.sh " ]; } || { cat "$work/out" >&2; fail "AC-4: slow ran '$ran' (rc $rc), want only the marked file"; }
echo "ok - AC-4: run.sh slow runs only the marked files"
run
{ [ "$rc" = 0 ] && [ "$ran" = "e2e.test.sh unit-a.test.sh unit-b.test.sh " ]; } || { cat "$work/out" >&2; fail "AC-4: no tier ran '$ran' (rc $rc), want all"; }
echo "ok - AC-4: run.sh with no tier runs all"
run medium
{ [ "$rc" != 0 ] && [ -z "$ran" ]; } || { cat "$work/out" >&2; fail "AC-4: an unknown tier ran '$ran' (rc $rc)"; }
echo "ok - AC-4: an unknown tier fails and runs nothing"
rm "$work/tests/e2e.test.sh"
run slow
[ "$rc" != 0 ] || { cat "$work/out" >&2; fail "AC-4: a slow tier with no files passed"; }
echo "ok - AC-4: a tier with no files fails"

echo "PASS: run.sh tiers"
