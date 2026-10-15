#!/usr/bin/env bash
# W10.10.7, the reviewer's eval-on-change: run by hand before any PR that changes how the reviewer
# reviews (runtime/reviewer/review.sh, prompt.md, settings.json, verdict.schema.json, its model, or
# a Claude Code CLI update). It runs the W10.6.5 eval as run 6 did, on the reviewer under test:
# prepare.sh's branches in a fresh fixture clone, the 15 honest runs, the 15 seed-1 plants replayed
# from results/, then score.sh. Not in CI: it calls the real model (D-06), about $2 and 15 minutes.
#
#   usage: check.sh --fixture <fresh fixture clone> --out <new dir> [--reviewer <dir>]
#                   [--prepared] [--replay <dir>]
#          check.sh --list    (the run ids, one per line)
#   --reviewer  the reviewer directory under test (default runtime/reviewer of this checkout)
#   --prepared  the clone already has prepare.sh's branches (the test's made-up fixture)
#   --replay    the plant records (default results/, the records runs 1-6 used)
#
# Exit 0: every honest change passed and every planted one failed. 1: any miss (a could-not-run is
# one). 2: bad arguments, an out dir that already has results, or a clone an earlier run used. The out dir gets run.sh's verdicts
# and results.tsv, and claude-version: the CLI the reviewer ran on (F-NEW-57), to trace a change in
# behaviour to a CLI update.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
usage() { sed -n 8,13p "$0" >&2; exit 2; }

runs() {
  local n c p
  for n in 1 2 3; do
    for c in starred "done" priority fix-wildcards fix-nomatch; do echo "h-$c-$n:$c"; done
  done
  for c in starred "done" priority; do
    for p in loosened-test reworded-acceptance skipped-state-row untested-acceptance false-verified; do
      echo "p-$c-$p:$c:$p"
    done
  done
}

fixture="" out="" reviewer=() prepared=0 replay="$here/results"
while [ $# -gt 0 ]; do
  case $1 in
    --list) runs | cut -d: -f1; exit 0 ;;
    --fixture) [ $# -ge 2 ] || usage; fixture=$2; shift 2 ;;
    --out) [ $# -ge 2 ] || usage; out=$2; shift 2 ;;
    --reviewer) [ $# -ge 2 ] || usage; reviewer=(--reviewer "$2"); shift 2 ;;
    --prepared) prepared=1; shift ;;
    --replay) [ $# -ge 2 ] || usage; replay=$2; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$fixture" ] && [ -n "$out" ] || usage
[ ! -e "$out/results.tsv" ] || { echo "check: $out already has results; give a new --out" >&2; exit 2; }
[ -z "$(git -C "$fixture" branch --list 'eval-run/*')" ] \
  || { echo "check: $fixture has eval-run/* branches from an earlier run; use a fresh clone" >&2; exit 2; }
mkdir -p "$out"

{ command -v claude >/dev/null && claude --version 2>&1 || echo "not found"; } | head -1 >"$out/claude-version"
echo "claude: $(cat "$out/claude-version")"

[ "$prepared" = 1 ] || "$here/prepare.sh" --fixture "$fixture"
mapfile -t spec < <(runs)
rc=0
"$here/run.sh" --fixture "$fixture" --replay "$replay" --base-of-features eval/ci-base \
  "${reviewer[@]}" --out "$out" "${spec[@]}" || rc=$?
[ "$rc" = 0 ] || echo "check: run.sh stopped (exit $rc); the runs it didn't record are misses"
mapfile -t ids < <(runs | cut -d: -f1)
"$here/score.sh" "$out" "${ids[@]}" || exit 1
