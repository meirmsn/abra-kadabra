#!/usr/bin/env bash
# Tests scripts/format-check.sh, the pinned `prettier --check` CI runs: it must fail on a file
# Prettier would change, pass on formatted files, and fail closed when Prettier is missing, is not
# the version package.json pins, or has nothing to check.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/format-check.sh"
source "$repo_root/tests/lib.sh"
[ -x "$repo_root/node_modules/.bin/prettier" ] || fail "pinned prettier not installed (run npm ci)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# run_check <dir> [prettier]: echo the script's exit code.
run_check() {
  local rc=0
  (cd "$1" && PRETTIER=${2:-} "$script") >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
expect() {
  [ "$3" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $3"; }
  echo "ok - $1"
}

d="$work/clean"; mkdir -p "$d"
printf '# Title\n\nSome text.\n' >"$d/doc.md"
printf '{ "a": 1 }\n' >"$d/data.json"
expect "formatted files pass" 0 "$(run_check "$d")"

d="$work/bad"; mkdir -p "$d"
printf '# Title\n\nSome text.\n' >"$d/doc.md"
printf '{"a":1,\n    "b":   2}\n' >"$d/data.json"
expect "a file Prettier would change fails" 1 "$(run_check "$d")"
grep -q "data.json" "$work/out.log" || fail "the failing file is not named in the output"

d="$work/ignored"; mkdir -p "$d"
cp "$work/bad/data.json" "$work/clean/doc.md" "$d/"
printf 'data.json\n' >"$d/.prettierignore"
expect ".prettierignore is honoured" 0 "$(run_check "$d")"

d="$work/empty"; mkdir -p "$d"
expect "nothing to check fails" 2 "$(run_check "$d")"

expect "missing prettier fails closed" 2 "$(run_check "$work/clean" /nonexistent/prettier)"

fake="$work/fake-prettier"
printf '#!/bin/sh\necho 2.0.0\n' >"$fake" && chmod +x "$fake"
expect "an unpinned prettier version fails closed" 2 "$(run_check "$work/clean" "$fake")"
grep -q "pins" "$work/out.log" || fail "version mismatch is not explained"
echo "PASS: format-check.sh"
