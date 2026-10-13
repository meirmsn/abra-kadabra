#!/usr/bin/env bash
# Tests scripts/findings-check.py (W10.6.13): the findings ledger's mechanical rules. It must fail a
# missing or misordered section, a bad entry heading, field, grade or source, a Leverage or Score that
# doesn't match its formula, a Seen count that doesn't match its lines, either list out of order, a
# low-impact Fix entry seen fewer than 5 times, a Watch entry seen 5 times, a duplicate ID and a
# malformed Closed table; pass a sound ledger and the boundaries; fail closed when it can't run; and
# pass the real FINDINGS.md.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/findings-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A sound ledger: the Fix queue sorted by Leverage with a tie broken by Impact, the Watch list by
# Score, and Closed rows, one with an escaped pipe and one with an empty Ref.
sound() {
  cat <<'EOF'
# Findings

Free text before the lists is not checked.

## Fix queue

### F-NEW-02 · A tie on Leverage, higher impact
- **Source:** fixture
- **Grades:** Impact M · Risk XS · Cost XS · Leverage 12
- **Observation:** a gap.
- **Action:** close it.
- **Task:** —
- **Seen (1):**
  - 2026-10-13 · run 1: seen.

### F-NEW-03 · The tie, lower impact, seen five times
- **Source:** fixture
- **Grades:** Impact XS · Risk M · Cost XS · Leverage 12
- **Observation:** small, but it keeps coming back.
- **Action:** tidy it.
- **Task:** —
- **Seen (5):**
  - 2026-10-09 · one.
  - 2026-10-10 · two.
  - 2026-10-11 · three.
  - 2026-10-12 · four.
  - 2026-10-13 · five.

### F-NEW-01 · The first fix
- **Source:** devshop
- **Grades:** Impact L · Risk L · Cost M · Leverage 6.4
- **Observation:** something broke.
- **Action:** fix it.
- **Task:** W1.1
- **Seen (1):**
  - 2026-10-13 · W1.1: it broke once.

## Watch list

### F-NEW-04 · Seen four times
- **Source:** devshop
- **Grades:** Impact S · Score 8
- **Observation:** a symptom to grep for.
- **Guess:** a cause, and what might fix it.
  1. A first likely cause.
- **Seen (4):**
  - 2026-10-10 · one.
  - 2026-10-11 · two.
  - 2026-10-12 · three.
  - 2026-10-13 · four.

### F-NEW-05 · Seen once
- **Source:** lalista
- **Grades:** Impact M · Score 3
- **Observation:** odd.
- **Guess:** unknown.
- **Seen (1):**
  - 2026-10-13 · once.

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
bad "sections out of order fail" "sections must come in the order" \
  "## Fix queue" "## Watch list" "## Watch list\n\n### F-NEW-04" "## Fix queue\n\n### F-NEW-04"

# Entries and fields
bad "a bad ID fails" "bad entry heading" "### F-NEW-05 · Seen once" "### X-5 · Seen once"
bad "an entry without a title fails" "bad entry heading" "### F-NEW-05 · Seen once" "### F-NEW-05 · "
bad "a missing Action fails" "F-NEW-01: missing field Action" "- **Action:** fix it.\n" ""
bad "a missing Guess fails" "F-NEW-05: missing field Guess" "- **Guess:** unknown.\n" ""
bad "a Watch entry with an Action fails" "F-NEW-05: unknown field Action" "- **Guess:** unknown." "- **Guess:** unknown.\n- **Action:** do it."
bad "an empty field fails" "F-NEW-05: empty field Observation" "- **Observation:** odd." "- **Observation:**"
bad "a repeated field fails" "F-NEW-05: field Observation twice" "- **Observation:** odd." "- **Observation:** odd.\n- **Observation:** again."
bad "a bad source fails" "F-NEW-05: bad Source" "- **Source:** lalista" "- **Source:** Lalista Project"
bad "stray text in an entry fails" "F-NEW-05: unexpected line" "- **Observation:** odd." "- **Observation:** odd.\nloose words"
good "a field's indented sub-items pass" "- **Observation:** odd." "- **Observation:** odd:\n  - one part;\n  - another."

# Grades and formulas
bad "a grade off the scale fails" "F-NEW-05: bad Grades" "Impact M · Score 3" "Impact XXL · Score 3"
bad "a wrong Leverage fails" "F-NEW-01: Leverage 7 should be 6.4" "Leverage 6.4" "Leverage 7"
bad "a wrong Score fails" "F-NEW-05: Score 4 should be 3" "Impact M · Score 3" "Impact M · Score 4"
bad "Watch grades on a Fix entry fail" "F-NEW-01: bad Grades" "Impact L · Risk L · Cost M · Leverage 6.4" "Impact L · Score 4"
good "a Leverage written with one decimal passes" "Impact XS · Risk M · Cost XS · Leverage 12" "Impact XS · Risk M · Cost XS · Leverage 12.0"

# Seen
bad "a Seen count above its lines fails" "F-NEW-05: Seen (2) but 1 line" "- **Seen (1):**\n  - 2026-10-13 · once." "- **Seen (2):**\n  - 2026-10-13 · once."
bad "a Seen line without a date fails" "F-NEW-05: bad Seen line" "  - 2026-10-13 · once." "  - yesterday · once."
good "a wrapped Seen line counts once" "  - 2026-10-13 · once." "  - 2026-10-13 · once, and a long\n    story wrapped here."
bad "a Seen line indented wrongly fails" "F-NEW-05: bad Seen line" "  - 2026-10-13 · once." "  - 2026-10-13 · once.\n   - 2026-10-14 · three spaces."
bad "Seen without a count fails" "F-NEW-05: unknown field Seen" "- **Seen (1):**\n  - 2026-10-13 · once." "- **Seen:** once."

# Order
bad "the Fix queue out of order fails" "Fix queue out of order" "Impact L · Risk L · Cost M · Leverage 6.4" "Impact L · Risk L · Cost XS · Leverage 64"
bad "a Leverage tie in the wrong Impact order fails" "Fix queue out of order" \
  "Impact M · Risk XS · Cost XS · Leverage 12" "Impact XS · Risk M · Cost XS · Leverage 12" \
  "Impact XS · Risk M · Cost XS · Leverage 12\n- **Observation:** small" "Impact M · Risk XS · Cost XS · Leverage 12\n- **Observation:** small"
bad "the Watch list out of order fails" "Watch list out of order" "Impact S · Score 8" "Impact XS · Score 4" "Impact M · Score 3" "Impact XL · Score 5"

# The rule of 5
bad "a low-impact Fix entry seen 4 times fails" "F-NEW-03: impact XS in the Fix queue needs 5 sightings" \
  "- **Seen (5):**" "- **Seen (4):**" "  - 2026-10-13 · five.\n" ""
bad "an impact-S Fix entry seen once fails" "F-NEW-02: impact S in the Fix queue needs 5 sightings" \
  "Impact M · Risk XS · Cost XS · Leverage 12" "Impact S · Risk L · Cost M · Leverage 3.2"
bad "a Watch entry seen 5 times fails" "F-NEW-04: seen 5 times" \
  "Impact S · Score 8" "Impact S · Score 10" "- **Seen (4):**" "- **Seen (5):**" "  - 2026-10-13 · four." "  - 2026-10-13 · four.\n  - 2026-10-13 · five."

# Closed table and IDs
bad "a Closed row with a missing cell fails" "Closed row O-01: 3 cells" "| O-01     | An opportunity        | devshop | v2 requirement     |             |" "| O-01 | An opportunity | devshop |"
bad "a Closed row without an outcome fails" "Closed row O-01: empty Outcome" "| devshop | v2 requirement     |" "| devshop |                    |"
bad "a Closed row with a bad source fails" "Closed row O-01: bad Source" "| O-01     | An opportunity        | devshop |" "| O-01     | An opportunity        | Dev Shop |"
bad "a bad Closed header fails" "Closed: header must be" "| ID       | Finding               | Source  | Outcome            | Ref         |" "| ID | Finding | Outcome | Ref |"
bad "a duplicate ID fails" "F-NEW-01: ID appears twice" "| O-01     |" "| F-NEW-01 |"
bad "a Closed table with no rows fails" "Closed: no rows" \
  "| F-SEC-01 | A pipe \`a \\| b\` here  | devshop | won't fix — v1     | \`x.sh:1\`    |\n" "" \
  "| O-01     | An opportunity        | devshop | v2 requirement     |             |\n" ""
bad "text after the Closed table fails" "Closed: unexpected line" "| O-01     | An opportunity        | devshop | v2 requirement     |             |" "| O-01     | An opportunity        | devshop | v2 requirement     |             |\nmore words"

# Fails closed
expect "a missing file can't run" 2 "$(run_check "$work/missing.md")" "can't read"
: >"$work/empty.md"
expect "an empty file fails" 1 "$(run_check "$work/empty.md")" "no '## Fix queue' section"

# --ids lists every ID, live and closed, in file order
sound >"$work/f.md"
"$script" --ids "$work/f.md" >"$work/ids.txt"
[ "$(tr '\n' ' ' <"$work/ids.txt")" = "F-NEW-02 F-NEW-03 F-NEW-01 F-NEW-04 F-NEW-05 F-SEC-01 O-01 " ] || { cat "$work/ids.txt" >&2; fail "--ids lists the wrong IDs"; }
echo "ok - --ids lists every ID in file order"

# The real ledger
expect "the real FINDINGS.md passes" 0 "$(run_check "$repo_root/kit/notes/revamp/FINDINGS.md")"
