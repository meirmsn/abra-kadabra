#!/usr/bin/env bash
# Tests scripts/table-rows-check.py (specs/parallel-safe-shared-files.md AC-13): a Markdown table row
# padded with two or more spaces beside a pipe fails, naming file and line; compact rows pass; a
# missing file or one with no table exits 2, never 0. Then runs it on the real FINDINGS.md and
# ROADMAP.md (AC-14). TABLE_ROWS_CHECK overrides the script, for the mutant run.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="${TABLE_ROWS_CHECK:-$repo_root/scripts/table-rows-check.py}" # the override is for the mutant run
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <text the output must hold, or ""> <files...>
check() {
  local name=$1 want=$2 text=$3 rc=0
  shift 3
  python3 "$script" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$text" ] || grep -qF -- "$text" "$work/out.log" || { cat "$work/out.log" >&2; fail "$name: output doesn't hold '$text'"; }
  echo "ok - $name"
}

cat >"$work/good.md" <<'MD'
# Findings

Prose with  two spaces is not a table.

| ID | Severity | What was noticed | Seen |
| --- | --- | --- | --- |
| F-NEW-1 | low | A thing, with `a | b` in code. | 2026-11-10 · R-22 |
| F-2026-11-10-a-slug | med | Another  thing, double-spaced inside a cell. | 2026-11-10 · R-22 |
MD
check "parallel-safe-shared-files AC-13: compact rows pass" 0 "" "$work/good.md"

# One known-bad row per way padding shows: after a pipe, before a pipe, a padded delimiter row, the
# header, and a row's last cell.
bad=(
  '| F-NEW-1  | low | A thing. | 2026-11-10 |'
  '| F-NEW-1 |  low | A thing. | 2026-11-10 |'
  '| --- | -------- | --- | --- |  '
  '| ID      | Severity | What was noticed | Seen |'
  '| F-NEW-1 | low | A thing. | 2026-11-10   |'
)
i=0
for row in "${bad[@]}"; do
  i=$((i + 1))
  sed "6s/.*/$(printf '%s' "$row" | sed 's/[&/\]/\\&/g')/" "$work/good.md" >"$work/bad$i.md"
  [ "$i" = 3 ] || sed -i "6s/.*/| --- | --- | --- | --- |/" "$work/bad$i.md"
  [ "$i" = 3 ] || sed -i "7s/.*/$(printf '%s' "$row" | sed 's/[&/\]/\\&/g')/" "$work/bad$i.md"
  check "parallel-safe-shared-files AC-13: padded row $i ($row) fails, naming file:line" 1 "bad$i.md:" "$work/bad$i.md"
done
check "parallel-safe-shared-files AC-13: every file is checked; one padded file fails" 1 "bad1.md:7:" "$work/good.md" "$work/bad1.md"

printf '# No table\n\nJust prose | with a pipe.\n' >"$work/none.md"
check "parallel-safe-shared-files AC-13: a file with no table can't run" 2 "no table" "$work/none.md"
check "parallel-safe-shared-files AC-13: a missing file can't run" 2 "can't read" "$work/nope.md"
check "parallel-safe-shared-files AC-13: no file can't run" 2 "usage"

# AC-14: the real records are compact.
check "parallel-safe-shared-files AC-14: the real FINDINGS.md and ROADMAP.md are compact" 0 "" \
  "$repo_root/FINDINGS.md" "$repo_root/ROADMAP.md"
grep -qx 'FINDINGS.md' "$repo_root/.prettierignore" || fail "AC-14: FINDINGS.md isn't in .prettierignore"
grep -qx 'ROADMAP.md' "$repo_root/.prettierignore" || fail "AC-14: ROADMAP.md isn't in .prettierignore"
grep -q 'table-rows-check.py FINDINGS.md ROADMAP.md' "$repo_root/scripts/lint.sh" || fail "AC-14: lint doesn't run the row check"
echo "ok - parallel-safe-shared-files AC-14: both records are out of the formatter and lint checks their rows"
