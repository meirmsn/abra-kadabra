#!/usr/bin/env bash
# The PR's verdict check (W10.6.6): polls the PR's comments through `gh` until verdict-check.sh says
# ok for the head commit, or the wait runs out. It waits because the verdict comment is posted just
# after the PR is created or pushed, and a comment-triggered run would report on the default branch,
# not on the PR. Deterministic, no model (D-06). A tripwire, not a wall.
#   usage: verdict-wait.sh --repo <owner/name> --pr <number> --head <sha> --wait <seconds> --every <seconds>
# Stdout: verdict-check.sh's last line. Exit 0 = ok; 1 = still missing, stale or failing at the end
# of the wait; 2 = could-not-run (bad arguments, no gh, a gh error, bad input).
set -uo pipefail

here=${BASH_SOURCE[0]%/*}
cnr() { echo "VERDICT: could-not-run · $1"; exit 2; }
repo="" pr="" head="" wait="" every=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo | --pr | --head | --wait | --every)
      [ $# -ge 2 ] || cnr "$1 needs a value"
      case "$1" in --repo) repo=$2 ;; --pr) pr=$2 ;; --head) head=$2 ;; --wait) wait=$2 ;; --every) every=$2 ;; esac
      shift 2 ;;
    *) cnr "unknown argument '$1'" ;;
  esac
done
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || cnr "--repo must be <owner>/<name>"
[[ "$pr" =~ ^[1-9][0-9]*$ ]] || cnr "--pr must be a PR number"
[[ "$wait" =~ ^[0-9]+$ ]] && [[ "$every" =~ ^[0-9]+$ ]] || cnr "--wait and --every must be whole seconds"
command -v gh >/dev/null || cnr "gh not found"

deadline=$(($(date +%s) + wait))
while :; do
  list=$(gh api --paginate "repos/$repo/issues/$pr/comments" --jq '.[] | {body}') || cnr "gh api failed"
  rc=0
  line=$(jq -s . <<<"$list" | "$here/verdict-check.sh" --head "$head" --comments /dev/stdin) || rc=$?
  [ "$rc" = 1 ] && [ "$(date +%s)" -lt "$deadline" ] || { echo "$line"; exit "$rc"; }
  sleep "$every"
done
