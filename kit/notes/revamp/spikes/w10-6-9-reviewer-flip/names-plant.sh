#!/usr/bin/env bash
# W10.6.9: does each planted fail block on its plant? For every p-<case>-<plant>[-<tag>]-r<k> verdict
# that failed, the text of its blocking items (unmet items' evidence, non-low findings' item, file and
# what) must name the plant's file or an AC-<n> in the planted line, from the plant record
# <records>/p-<case>-<plant>.plants.json. A coarse check: it confirms the fail points at the plant,
# not that the reasoning is right (read the verdicts for that).
#   usage: names-plant.sh <records dir> <verdict dir>...
# Prints each fail that names nothing, then the counts. Exit 0 = all name their plant; 1 = some
# don't; 2 = bad input.
set -euo pipefail
command -v jq >/dev/null || { echo "names-plant.sh: jq not found" >&2; exit 2; }
[ $# -ge 2 ] || { sed -n 7p "$0" >&2; exit 2; }
records=$1; shift
ok=0 miss=0
for d in "$@"; do
  for f in "$d"/p-*-r[0-9]*.verdict.json; do
    [ -e "$f" ] || continue
    [ "$(jq -r .outcome "$f")" = fail ] || continue
    id=$(basename "$f" .verdict.json)
    rec="$records/$(sed -E 's/(-[a-z])?-r[0-9]+$//' <<<"$id").plants.json"
    [ -f "$rec" ] || { echo "names-plant.sh: no plant record $rec" >&2; exit 2; }
    text=$(jq -r '[(.acceptance[] | select(.met | not) | .item + " " + .evidence),
      (.findings[] | select(.severity != "low") | .item + " " + .file + " " + .what)] | join(" ")' "$f")
    hit=0
    while IFS= read -r k; do
      [ -n "$k" ] && grep -qF -- "$k" <<<"$text" && hit=1
    done < <(jq -r '.plants[] | (.file | split("/")[-1]), ((.before + " " + .after) | [scan("AC-[0-9]+")] | .[])' "$rec")
    if [ "$hit" = 1 ]; then ok=$((ok + 1)); else miss=$((miss + 1)); echo "names nothing: $id"; fi
  done
done
[ $((ok + miss)) -gt 0 ] || { echo "names-plant.sh: no failing planted verdicts in $*" >&2; exit 2; }
echo "$ok of $((ok + miss)) planted fails name their plant"
[ "$miss" = 0 ]
