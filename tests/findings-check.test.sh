#!/usr/bin/env bash
# Tests scripts/findings-check.py (W10.6.13, W10.6.14): the findings ledger's mechanical rules. It
# must fail a missing or misordered section, a bad table header or row, a bad ID, source, grade or
# glyph, a Leverage or Score that doesn't match its formula, a Seen cell whose dots don't match its
# sightings, either list out of order, a low-impact Fix row seen fewer than 5 times, a Watch row seen
# 5 times and a duplicate ID; pass a sound ledger and the boundaries; fail closed when it can't run;
# and pass the real FINDINGS.md.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/findings-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A sound ledger: the Fix queue sorted by Leverage with a tie broken by Impact, the Watch list by
# Score, Closed rows with an escaped pipe and an empty Ref.
sound() {
  cat <<'EOF'
# Findings

Free text before the lists is not checked.

## Fix queue

Free text before a table is fine.

| ID       | Finding                        | Action    | Source  | Impact | Risk  | Cost  | Leverage | Task | Seen                                                                                               |
| -------- | ------------------------------ | --------- | ------- | ------ | ----- | ----- | -------- | ---- | -------------------------------------------------------------------------------------------------- |
| F-NEW-02 | **A tie, higher impact.** gap  | close it  | fixture | 🟡 M   | 🟢🟢 XS | 🟢🟢 XS | 🔥 12    | —    | ●○○○○ 2026-10-13 · run 1: seen.                                                                     |
| F-NEW-03 | **The tie, lower impact.** odd | tidy it   | fixture | 🟢🟢 XS | 🟡 M  | 🟢🟢 XS | 🔥 12    | —    | ●●●●● 2026-10-09 · one.<br>2026-10-10 · two.<br>2026-10-11 · three.<br>2026-10-12 · four.<br>2026-10-13 · five. |
| F-NEW-01 | **The first fix.** it broke    | fix it    | devshop | 🔴 L   | 🔴 L  | 🟡 M  | 🔥 6.4   | W1.1 | ●○○○○ 2026-10-13 · W1.1: it broke once.                                                            |
| F-NEW-06 | **A cheap one.** small         | do it     | devshop | 🟡 M   | 🟢 S  | 🟡 M  | 🟡 2.4   | M2   | ●○○○○ 2026-10-13 · once.                                                                           |
| F-NEW-07 | **A dear one.** big            | rebuild   | devshop | 🟡 M   | 🟢 S  | 🔴🔴 XL | ⚪ 0.7   | M2   | ●○○○○ 2026-10-13 · once.                                                                           |

## Watch list

| ID       | Finding                    | Guess                              | Source  | Impact | Seen                                                                              | Score |
| -------- | -------------------------- | ---------------------------------- | ------- | ------ | --------------------------------------------------------------------------------- | ----- |
| F-NEW-04 | **Seen four times.** a sym | 1) a cause; 2) another             | devshop | 🟢 S   | ●●●●○ 2026-10-10 · one.<br>2026-10-11 · two.<br>2026-10-12 · three.<br>2026-10-13 · four. | 8     |
| F-NEW-05 | **Seen once.** odd         | unknown                            | lalista | 🟡 M   | ●○○○○ 2026-10-13 · once.                                                          | 3     |

## Closed

| ID       | Finding               | Source  | Outcome            | Ref         |
| -------- | --------------------- | ------- | ------------------ | ----------- |
| F-SEC-01 | A pipe `a \| b` here  | devshop | won't fix — v1     | `x.sh:1`    |
| O-01     | An opportunity        | devshop | v2 requirement     |             |
EOF
}

run_check() {
  local rc=0
  "$script" "$1" >"$work/out.log" 2>&1 || rc=$?
  echo "$rc"
}
expect() { # <name> <expected exit> <actual exit> [text the output must contain]
  [ "$3" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $3"; }
  if [ -n "${4:-}" ]; then grep -qF -- "$4" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output lacks '$4'"; }; fi
  echo "ok - $1"
}
# mutate <file> <old> <new> [<old> <new>...]: each <old> replaced once by <new> (\n = newline); each must be found.
mutate() {
  python3 -c '
import sys
p, pairs = sys.argv[1], sys.argv[2:]
s = open(p).read()
for old, new in zip(pairs[::2], pairs[1::2]):
    old, new = old.replace("\\n", "\n"), new.replace("\\n", "\n")
    assert old in s, f"mutation target not found: {old!r}"
    s = s.replace(old, new, 1)
open(p, "w").write(s)
' "$@"
}
# bad <name> <text> <old> <new> [<old> <new>...]: the sound ledger so changed must exit 1 and say <text>.
bad() {
  local name=$1 text=$2
  shift 2
  sound >"$work/f.md"
  mutate "$work/f.md" "$@"
  expect "$name" 1 "$(run_check "$work/f.md")" "$text"
}
# good <name> <old> <new> [...]: the sound ledger so changed must pass.
good() {
  local name=$1
  shift
  sound >"$work/f.md"
  mutate "$work/f.md" "$@"
  expect "$name" 0 "$(run_check "$work/f.md")"
}

sound >"$work/f.md"
expect "a sound ledger passes" 0 "$(run_check "$work/f.md")"

# Sections
bad "a missing Closed section fails" "no '## Closed' section" "## Closed" "## Done"
bad "a missing Fix queue fails" "no '## Fix queue' section" "## Fix queue" "## Queue"
bad "a repeated section fails" "'## Closed' appears twice" "## Watch list" "## Closed"
bad "sections out of order fail" "sections must come in the order" "## Fix queue" "## Watch list" "## Watch list\n\n| ID       | Finding                    |" "## Fix queue\n\n| ID       | Finding                    |"
bad "a section without a table fails" "Watch list: no table" "## Watch list\n" "## Watch list\n\nNothing yet.\n\n## Old\n"

# Tables
bad "a bad Fix header fails" "Fix queue: header must be" "| Leverage | Task |" "| Leverage | Owner |"
bad "a bad Closed header fails" "Closed: header must be" "| ID       | Finding               | Source  | Outcome            | Ref         |" "| ID | Finding | Outcome | Ref |"
bad "a row with a missing cell fails" "Closed row O-01: 3 cells, want 5" "| O-01     | An opportunity        | devshop | v2 requirement     |             |" "| O-01 | An opportunity | devshop |"
bad "text after a table fails" "Closed: unexpected line" "| O-01     | An opportunity        | devshop | v2 requirement     |             |" "| O-01     | An opportunity        | devshop | v2 requirement     |             |\nmore words"
bad "an empty table fails" "Closed: no rows" "| F-SEC-01 | A pipe \`a \\| b\` here  | devshop | won't fix — v1     | \`x.sh:1\`    |\n" "" "| O-01     | An opportunity        | devshop | v2 requirement     |             |\n" ""

# Cells
bad "a bad ID fails" "bad ID 'X-5'" "| F-NEW-05 | **Seen once.**" "| X-5 | **Seen once.**"
bad "an empty Finding fails" "F-NEW-05: empty Finding" "| F-NEW-05 | **Seen once.** odd         |" "| F-NEW-05 |                            |"
bad "an empty Guess fails" "F-NEW-05: empty Guess" "| unknown                            |" "|                                    |"
bad "an empty Outcome fails" "Closed row O-01: empty Outcome" "| devshop | v2 requirement     |" "| devshop |                    |"
bad "a bad source fails" "F-NEW-05: bad Source" "| lalista |" "| Lalista Project |"
bad "a Closed row with a bad source fails" "O-01: bad Source" "| O-01     | An opportunity        | devshop |" "| O-01     | An opportunity        | Dev Shop |"
bad "a duplicate ID fails" "F-NEW-01: ID appears twice" "| O-01     |" "| F-NEW-01 |"

# Grades and glyphs
bad "a grade off the scale fails" "F-NEW-05: bad Impact" "| lalista | 🟡 M   |" "| lalista | 🟡 XXL |"
bad "a grade without its glyph fails" "F-NEW-05: bad Impact" "| lalista | 🟡 M   |" "| lalista | M      |"
bad "the wrong glyph fails" "F-NEW-05: Impact M needs 🟡" "| lalista | 🟡 M   |" "| lalista | 🔴 M   |"
bad "the wrong Cost glyph fails" "F-NEW-07: Cost XL needs 🔴🔴" "| 🔴🔴 XL | ⚪ 0.7" "| 🔴 XL | ⚪ 0.7"
bad "a wrong Leverage fails" "F-NEW-01: Leverage 7 should be 6.4" "| 🔥 6.4   |" "| 🔥 7     |"
bad "the wrong Leverage band fails" "F-NEW-06: Leverage 2.4 needs 🟡" "| 🟡 2.4   |" "| 🔥 2.4   |"
bad "a low Leverage marked mid fails" "F-NEW-07: Leverage 0.7 needs ⚪" "| ⚪ 0.7   |" "| 🟡 0.7   |"
bad "a wrong Score fails" "F-NEW-05: Score 4 should be 3" "| ●○○○○ 2026-10-13 · once.                                                          | 3     |" "| ●○○○○ 2026-10-13 · once.                                                          | 4     |"
good "a Leverage written with one decimal passes" "| 🔥 12    | —    | ●●●●●" "| 🔥 12.0  | —    | ●●●●●"
good "Leverage 5 is the top band" "| 🟡 M   | 🟢 S  | 🟡 M  | 🟡 2.4   |" "| 🔴🔴 XL | 🔴🔴 XL | 🔴 L | 🔥 5 |"
good "Leverage 2 is the middle band" "| 🟡 M   | 🟢 S  | 🔴🔴 XL | ⚪ 0.7   |" "| 🔴🔴 XL | 🟢 S | 🔴 L | 🟡 2 |"

# Seen
bad "Seen dots below the sightings fail" "F-NEW-05: Seen shows ●●○○○ but has 1 sighting" "| ●○○○○ 2026-10-13 · once.                                                          | 3" "| ●●○○○ 2026-10-13 · once.                                                          | 3"
bad "Seen without dots fails" "F-NEW-05: bad Seen" "| ●○○○○ 2026-10-13 · once.                                                          | 3" "| 2026-10-13 · once.                                                          | 3"
bad "a sighting without a date fails" "F-NEW-05: bad sighting 'yesterday · once.'" "| ●○○○○ 2026-10-13 · once.                                                          | 3" "| ●○○○○ yesterday · once.                                                          | 3"
good "more than 5 sightings show the count" "| ●●●●● 2026-10-09 · one.<br>" "| ●●●●● 6 2026-10-08 · zero.<br>2026-10-09 · one.<br>"
bad "more than 5 sightings without the count fail" "F-NEW-03: Seen shows ●●●●● but has 6 sightings" "| ●●●●● 2026-10-09 · one.<br>" "| ●●●●● 2026-10-08 · zero.<br>2026-10-09 · one.<br>"

# Order
bad "the Fix queue out of order fails" "Fix queue out of order" "| 🔴 L   | 🔴 L  | 🟡 M  | 🔥 6.4   |" "| 🔴 L   | 🔴 L  | 🟢🟢 XS | 🔥 64    |"
bad "a Leverage tie in the wrong Impact order fails" "Fix queue out of order" \
  "| fixture | 🟡 M   | 🟢🟢 XS | 🟢🟢 XS | 🔥 12" "| fixture | 🟢🟢 XS | 🟡 M | 🟢🟢 XS | 🔥 12" \
  "| fixture | 🟢🟢 XS | 🟡 M  | 🟢🟢 XS | 🔥 12" "| fixture | 🟡 M | 🟢🟢 XS | 🟢🟢 XS | 🔥 12"
bad "the Watch list out of order fails" "Watch list out of order" "| devshop | 🟢 S   | ●●●●○" "| devshop | 🟢🟢 XS | ●●●●○" "| 8     |" "| 4     |" "| lalista | 🟡 M   |" "| lalista | 🔴🔴 XL |" "| 3     |" "| 5     |"

# The rule of 5
bad "a low-impact Fix row seen 4 times fails" "F-NEW-03: impact XS in the Fix queue needs 5 sightings" "| ●●●●● 2026-10-09 · one.<br>" "| ●●●●○ "
bad "an impact-S Fix row seen once fails" "F-NEW-06: impact S in the Fix queue needs 5 sightings" "| devshop | 🟡 M   | 🟢 S  | 🟡 M  | 🟡 2.4" "| devshop | 🟢 S   | 🟡 M  | 🟡 M  | 🟡 2.4"
bad "a Watch row seen 5 times fails" "F-NEW-04: seen 5 times" "| ●●●●○ 2026-10-10 · one.<br>" "| ●●●●● 2026-10-09 · zero.<br>2026-10-10 · one.<br>" "| 8     |" "| 10    |"

# Fails closed
expect "a missing file can't run" 2 "$(run_check "$work/missing.md")" "can't read"
: >"$work/empty.md"
expect "an empty file fails" 1 "$(run_check "$work/empty.md")" "no '## Fix queue' section"

# --ids lists every ID, live and closed, in file order
sound >"$work/f.md"
"$script" --ids "$work/f.md" >"$work/ids.txt"
[ "$(tr '\n' ' ' <"$work/ids.txt")" = "F-NEW-02 F-NEW-03 F-NEW-01 F-NEW-06 F-NEW-07 F-NEW-04 F-NEW-05 F-SEC-01 O-01 " ] || { cat "$work/ids.txt" >&2; fail "--ids lists the wrong IDs"; }
echo "ok - --ids lists every ID in file order"

# The real ledger
expect "the real FINDINGS.md passes" 0 "$(run_check "$repo_root/kit/notes/revamp/FINDINGS.md")"
