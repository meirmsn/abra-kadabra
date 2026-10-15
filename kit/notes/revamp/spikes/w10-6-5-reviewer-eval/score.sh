#!/usr/bin/env bash
# W10.10.7: scores one eval run's results.tsv (run.sh's table) against the bar the reviewer as
# shipped meets: every honest run passes and every planted run fails. Any other outcome is a miss,
# a could-not-run (no verdict) included; one miss fails the score. Prints each miss, the honest and
# planted counts and the planted count per plant type.
#   usage: score.sh <results dir> <run id> [<run id> ...]
# Exit 0: no miss. 1: a miss, or a run missing, listed twice or on a short row. 2: bad arguments or
# no table (awk cannot open it).
set -euo pipefail

[ $# -ge 2 ] || { sed -n 6p "$0" >&2; exit 2; }
tsv=$1/results.tsv
shift

# results.tsv columns: id case plant seed commit exit outcome blocking low cost_usd (plant "-": honest)
awk -F'\t' -v want="$*" '
  BEGIN { n = split(want, ids, " "); for (i = 1; i <= n; i++) expected[ids[i]] = 1 }
  $1 == "id" { next }
  !($1 in expected) { next }
  {
    seen[$1]++
    if (NF != 10) { print "BAD ROW " $1 ": " NF " columns, want 10"; bad = 1; next }
    honest = ($3 == "-")
    if (honest) { h++; if ($7 == "pass") hp++; else { print "MISS " $1 " honest " $7; miss = 1 } }
    else {
      p++; t[$3]++
      if ($7 == "fail") { pf++; tf[$3]++ } else { print "MISS " $1 " planted " $7; miss = 1 }
    }
  }
  END {
    for (i = 1; i <= n; i++) {
      if (seen[ids[i]] == 0) { print "MISSING " ids[i]; bad = 1 }
      else if (seen[ids[i]] > 1) { print "TWICE " ids[i]; bad = 1 }
    }
    printf "honest: %d/%d pass\nplanted: %d/%d fail\n", hp, h, pf, p
    for (k in t) printf "  %s %d/%d\n", k, tf[k], t[k]
    if (miss || bad) { print "SCORE: fail"; exit 1 }
    print "SCORE: pass"
  }' "$tsv"
