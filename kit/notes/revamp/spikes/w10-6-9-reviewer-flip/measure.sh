#!/usr/bin/env bash
# measure.sh <out root> <tag> <rep>...: run ids carry -<tag> so a later run never reuses a branch; one process per rep; the eval set, then the two ns1 cases.
set -uo pipefail
S=$(cd "$(dirname "$0")" && pwd); root=$1 tag=$2; shift 2
E=/home/user/abra-kadabra/kit/notes/revamp/spikes/w10-6-5-reviewer-eval
for k in "$@"; do
  (
    runs=()
    for c in starred done priority fix-wildcards fix-nomatch; do runs+=("h-$c-$tag-r$k:$c"); done
    for c in starred done priority; do
      for p in loosened-test reworded-acceptance skipped-state-row untested-acceptance false-verified; do
        runs+=("p-$c-$p-$tag-r$k:$c:$p:1")
      done
    done
    "$E/run.sh" --fixture "$S/fx" --replay "$E/results" --base-of-features eval/ci-base --out "$root/eval-r$k" "${runs[@]}" 2>>"$root/eval-r$k.log"
    "$E/run.sh" --fixture "$S/fx" --replay "$E/results" --out "$root/ns1-r$k" "n-ns1-$tag-r$k:ns1" "n-ns1-nopr-$tag-r$k:ns1-nopr" 2>>"$root/ns1-r$k.log"
  ) &
done
wait
