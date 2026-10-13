#!/usr/bin/env bash
# W10.6.5 reviewer eval (A-12): runs the real, pinned reviewer on honest and planted fixture changes.
# Not in CI: it calls the real model (D-06). Run it in a session where `claude` is logged in.
#
#   usage: run.sh --fixture <dir> (--harness <dir> | --replay <dir>) [--base-of-features <rev>]
#                 --out <dir> <run> [<run> ...]
#   <run> = <id>:<case>[:<plant>[:<seed>]]
#     <case>  one of the cases below; its change is the local fixture branch eval/<case>
#     <plant> a harness plant id; applied by the harness's own scripts/apply-plants.mjs, or with
#             --replay replayed from <dir>/p-<case>-<plant>.plants.json by replay-plants.py
#             (W10.6.8: no harness access), and committed as plant-run.sh commits it
#             ("Follow-up edits", as github-actions[bot])
#   --base-of-features  the base starred/done/priority were cut from (default baseline-2;
#             eval/ci-base after prepare.sh)
#   ns1, ns1-nopr  (W10.6.9) the north-star run-1 commit the reviewer passed then failed (fixture
#             1337cc0 on baseline-3), with the PR words in pr/ns1.json and with none; make the local
#             branches eval/ns1 and eval/ns1-nopr at that commit first
#
# Each run starts from the case's honest commit in a fresh worktree on its own branch
# (eval-run/<id>), so every review is round 1 and no run sees another's plant. Removing the
# worktree is the reset: nothing is pushed and the fixture's main and baseline tag never move.
# Writes <out>/<id>.verdict.json (copy of the verdict file), <out>/<id>.plants.json (planted runs)
# and appends one line to <out>/results.tsv:
#   id case plant seed commit exit outcome blocking low cost_usd
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
devshop=$(cd "$here/../../../../.." && pwd)
reviewer="$devshop/runtime/reviewer/review.sh"

# case → the base the change was cut from (the PR's base)
case_base() {
  case $1 in
    starred | done | priority) echo "$feature_base" ;;
    fix-wildcards | fix-nomatch) echo eval/search-base ;;
    ns1 | ns1-nopr) echo baseline-3 ;;
    *) echo "unknown case '$1'" >&2; return 2 ;;
  esac
}

fixture="" harness="" replay="" out="" feature_base=baseline-2
while [ $# -gt 0 ]; do
  case $1 in
    --fixture) fixture=$(cd "$2" && pwd); shift 2 ;;
    --harness) harness=$(cd "$2" && pwd); shift 2 ;;
    --replay) replay=$(cd "$2" && pwd); shift 2 ;;
    --base-of-features) feature_base=$2; shift 2 ;;
    --out) mkdir -p "$2"; out=$(cd "$2" && pwd); shift 2 ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ -n "$fixture" ] && [ -n "$harness$replay" ] && { [ -z "$harness" ] || [ -z "$replay" ]; } && [ -n "$out" ] && [ $# -gt 0 ] \
  || { sed -n 4,18p "$0" >&2; exit 2; }

run_one() {
  local id case plant seed base wt rc=0 line verdict
  IFS=: read -r id case plant seed <<<"$1"
  [[ "$id" =~ ^[a-z0-9-]+$ ]] || { echo "bad run id '$id'" >&2; return 2; }
  base=$(case_base "$case")
  wt=$(mktemp -d)/wt
  git -C "$fixture" worktree add -q -b "eval-run/$id" "$wt" "eval/$case"
  if [ -n "$plant" ]; then
    if [ -n "$replay" ]; then
      python3 -I "$here/replay-plants.py" "$wt" "$replay/p-$case-$plant.plants.json"
      cp "$replay/p-$case-$plant.plants.json" "$out/$id.plants.json"
    else
      node "$harness/scripts/apply-plants.mjs" --repo "$wt" --base "$base" --plants "$plant" \
        --run "$id" --seed "${seed:-1}" >"$out/$id.plants.json"
    fi
    GIT_AUTHOR_NAME='github-actions[bot]' GIT_COMMITTER_NAME='github-actions[bot]' \
      GIT_AUTHOR_EMAIL='41898282+github-actions[bot]@users.noreply.github.com' \
      GIT_COMMITTER_EMAIL='41898282+github-actions[bot]@users.noreply.github.com' \
      git -C "$wt" commit -qam "Follow-up edits"
  fi
  local pr=()
  [ ! -f "$here/pr/$case.json" ] || pr=(--pr "$here/pr/$case.json")
  line=$(cd "$wt" && "$reviewer" --base "$base" "${pr[@]}") || rc=$?
  echo "$id: $line" >&2
  verdict=$(awk -F' · ' '{print $NF}' <<<"$line")
  if [ -f "$verdict" ]; then
    cp "$verdict" "$out/$id.verdict.json"
    jq -r --arg id "$id" --arg case "$case" --arg plant "${plant:--}" --arg seed "${seed:--}" --arg rc "$rc" \
      '[$id, $case, $plant, $seed, .commit[0:12], $rc, .outcome, .blocking, .low, (.reviewer.cost_usd // "null")] | @tsv' \
      "$out/$id.verdict.json" >>"$out/results.tsv"
  else
    printf '%s\t%s\t%s\t%s\t-\t%s\tno-verdict\t-\t-\t-\n' "$id" "$case" "${plant:--}" "${seed:--}" "$rc" >>"$out/results.tsv"
  fi
  git -C "$fixture" worktree remove --force "$wt"
}

for r in "$@"; do run_one "$r"; done
