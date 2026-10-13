#!/usr/bin/env bash
# probe.sh <out root>: the ns1 cases x5 on each variant, and the honest set x2 on v1. One process per
# variant and rep.
set -uo pipefail
S=$(cd "$(dirname "$0")" && pwd); root=$1
E=/home/user/abra-kadabra/kit/notes/revamp/spikes/w10-6-5-reviewer-eval
for v in v1 v2 v3; do
  for k in 1 2 3 4 5; do
    "$E/run.sh" --fixture "$S/fx" --replay "$E/results" --reviewer "$S/rev-$v" --out "$root/$v-ns1-r$k" \
      "n-ns1-$v-r$k:ns1" "n-ns1-nopr-$v-r$k:ns1-nopr" 2>>"$root/$v-ns1-r$k.log" &
  done
done
for k in 1 2; do
  runs=()
  for c in starred done priority fix-wildcards fix-nomatch; do runs+=("h-$c-v1-r$k:$c"); done
  "$E/run.sh" --fixture "$S/fx" --replay "$E/results" --base-of-features eval/ci-base --reviewer "$S/rev-v1" \
    --out "$root/v1-eval-r$k" "${runs[@]}" 2>>"$root/v1-eval-r$k.log" &
done
wait
