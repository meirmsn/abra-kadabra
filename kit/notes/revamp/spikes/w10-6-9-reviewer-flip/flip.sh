#!/usr/bin/env bash
# W10.6.9 (F-NEW-40): how often the reviewer's outcome flips on identical input. Reads verdict files
# named <case>-r<k>.verdict.json (the same case reviewed k times, each in a fresh worktree) and, per
# case, prints the outcomes, whether they flip, and each blocking item with the share of runs that
# had it and its severities: an unmet AC-<n>, or a non-low finding as lens/item.
# A finding is also counted at `low` for its key, so an item that is high in one run and low in
# another shows as such (a severity flip, not a miss).
#   usage: flip.sh <dir>...
# Needs jq. Exit 0 = report printed; 2 = no verdict files or jq missing.
set -euo pipefail
command -v jq >/dev/null || { echo "flip.sh: jq not found" >&2; exit 2; }
files=()
for d in "$@"; do for f in "$d"/*-r[0-9]*.verdict.json; do [ -e "$f" ] && files+=("$f"); done; done
[ "${#files[@]}" -gt 0 ] || { echo "flip.sh: no <case>-r<k>.verdict.json files in $*" >&2; exit 2; }

for f in "${files[@]}"; do
  jq -c --arg case "$(basename "$f" .verdict.json | sed -E 's/-r[0-9]+$//')" '{case: $case, outcome,
    keys: ([(.acceptance[] | select(.met | not) | {k: ("unmet " + .item), s: "unmet"}),
            (.findings[] | {k: (.lens + "/" + (if .item == "" then (.file // "") else .item end)), s: .severity})])}' "$f"
done | jq -rs '
  group_by(.case)
  | (map(select([.[].outcome] | unique | length > 1)) | length) as $flips
  | "cases: \(length) · flipping: \($flips) · runs: \(map(length) | add)",
    (.[] | . as $runs | ($runs | length) as $n
      | ([$runs[].outcome] | group_by(.) | map("\(.[0]) \(length)") | join(", ")) as $o
      | (if ([$runs[].outcome] | unique | length) > 1 then "FLIPS" else "stable" end) as $st
      | "\($runs[0].case): \($o) of \($n) · \($st)",
        ([$runs[] | .keys | unique_by(.k + .s)[]] | group_by(.k)
          | map(select(any(.[]; .s != "low")))
          | .[] | "    \(.[0].k): \([.[] | .s] | group_by(.) | map("\(.[0]) \(length)") | join(", ")) of \($n)"))'
