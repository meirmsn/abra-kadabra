#!/usr/bin/env bash
# Posts "How this change went" on the session's merged PR once its deploy comment reaches a final state
# (specs/deploy-and-metrics-comments.md, part 2). Run by devshop:pr § 5 at each check-in after the merge,
# from the project's root; it gathers the PR's data with `gh api`, and change-metrics.py (beside this
# file) computes every number from it and the session's transcript.
#   usage: change-metrics.sh post --pr <n> --cost <usd|unknown>
#     --cost: the session's cost now, get_session's external_metadata.usage.cost_usd (no script can
#     read it); "unknown" when the field is absent.
# Exit 0 = posted, or already posted (a second run posts nothing); 3 = not yet: the deploy comment isn't
# final and the merge was less than an hour ago, so check in again; 2 = can't run (bad arguments, no
# GitHub remote, gh failing, the PR not merged). Never blocks anything: the merge and the deploy are done.
# Setting for tests: CHANGE_METRICS_NOW, the time to take as now (ISO 8601).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cnr() { echo "change-metrics: $*" >&2; exit 2; }

[ "${1:-}" = post ] || cnr "usage: change-metrics.sh post --pr <n> --cost <usd|unknown>"
shift
pr='' cost=''
while [ $# -gt 0 ]; do
  case $1 in
    --pr) pr=${2:-}; shift 2 || cnr "--pr needs a value" ;;
    --cost) cost=${2:-}; shift 2 || cnr "--cost needs a value" ;;
    *) cnr "unknown argument: $1" ;;
  esac
done
[[ "$pr" =~ ^[1-9][0-9]*$ ]] || cnr "--pr is not a PR number: '$pr'"
[[ "$cost" =~ ^([0-9]+(\.[0-9]+)?|unknown)$ ]] || cnr "--cost is not a cost in USD or 'unknown': '$cost'"
command -v gh >/dev/null || cnr "gh is not installed"
command -v jq >/dev/null || cnr "jq is not installed"
slug=$(git remote get-url origin 2>/dev/null | sed -nE 's#.*[:/]([^/:]+)/([^/]+)$#\1/\2#p' | sed -E 's#\.git/?$##')
[[ "$slug" =~ ^[^/]+/[^/]+$ ]] || cnr "origin is not a GitHub-style <owner>/<repo> remote"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
api() { gh api "$@" 2>"$work/gh.err" || cnr "gh api $1 failed: $(head -c 300 "$work/gh.err")"; }
# list <path>: every page of a list endpoint, as one array.
list() { api --paginate "$1" | jq -s 'add // []'; }

api "repos/$slug/pulls/$pr" >"$work/pr.json"
list "repos/$slug/issues/$pr/comments?per_page=100" >"$work/comments.json"
# Only the session's own comments count: it is the PR's author, and anyone can write a look-alike.
me=$(jq -r '.user.login' "$work/pr.json")
if jq -e --arg me "$me" 'any(.[]; .user.login == $me and ((.body // "") | startswith("<!-- devshop-metrics")))' \
  "$work/comments.json" >/dev/null; then
  echo "change-metrics: PR #$pr already has its metrics comment; nothing posted"
  exit 0
fi
list "repos/$slug/pulls/$pr/reviews?per_page=100" >"$work/reviews.json"
list "repos/$slug/pulls/$pr/comments?per_page=100" >"$work/review-comments.json"

# The PR's pull_request runs of the ci workflow, each with its earlier attempts' conclusions.
head=$(jq -r '.head.ref' "$work/pr.json")
if gh api "repos/$slug/actions/workflows/ci.yml/runs?branch=$(jq -rn --arg h "$head" '$h | @uri')&event=pull_request&per_page=100" \
  >"$work/runs-page.json" 2>/dev/null; then
  echo '[]' >"$work/runs.json"
  while read -r run; do
    id=$(jq -r '.id' <<<"$run") n=$(jq -r '.run_attempt // 1' <<<"$run")
    attempts='[]'
    for ((k = 1; k < n; k++)); do
      c=$(api "repos/$slug/actions/runs/$id/attempts/$k" | jq -r '.conclusion // ""')
      attempts=$(jq -c --arg c "$c" '. + [$c]' <<<"$attempts")
    done
    jq --argjson r "$run" --argjson a "$attempts" '. + [$r + {attempts: $a}]' "$work/runs.json" >"$work/runs.next"
    mv "$work/runs.next" "$work/runs.json"
  done < <(jq -c '.workflow_runs[] | {id, head_sha, conclusion, run_attempt, created_at}' "$work/runs-page.json")
else
  echo null >"$work/runs.json"
fi
jq -n --slurpfile pr "$work/pr.json" --slurpfile c "$work/comments.json" --slurpfile r "$work/reviews.json" \
  --slurpfile rc "$work/review-comments.json" --slurpfile runs "$work/runs.json" \
  '{pr: $pr[0], comments: $c[0], reviews: $r[0], review_comments: $rc[0], runs: $runs[0]}' >"$work/data.json"

# A later change in the session starts its cost where the session's last metrics comment left it.
prev=()
earlier=$(python3 "$here/change-metrics.py" previous-pr --pr "$pr") || cnr "can't read the transcript"
if [ -n "$earlier" ]; then
  was=$(list "repos/$slug/issues/$earlier/comments?per_page=100" |
    jq -r --arg me "$me" '[.[] | select(.user.login == $me) | .body // ""
      | capture("^<!-- devshop-metrics cost:(?<c>[0-9.]+) -->").c] | first // "unknown"')
  prev=(--prev-cost "$was")
fi

# Whether a deploy comment is awaited follows the workflow as of the merge commit, not today's.
ci=()
merge=$(jq -r 'if .merged_at then .merge_commit_sha // "" else "" end' "$work/pr.json")
if [ -n "$merge" ]; then
  git cat-file -e "$merge^{commit}" 2>/dev/null || git fetch -q origin "$merge" 2>/dev/null ||
    cnr "can't fetch the merge commit $merge"
  git show "$merge:.github/workflows/ci.yml" >"$work/ci.yml" 2>/dev/null || : >"$work/ci.yml"
  ci=(--ci "$work/ci.yml")
fi
# The reviewer's verdict files for the PR's branch, one per round (review.sh writes them there).
vdir="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)/devshop/reviews/${head//\//__}"
now=()
[ -z "${CHANGE_METRICS_NOW:-}" ] || now=(--now "$CHANGE_METRICS_NOW")
rc=0
python3 "$here/change-metrics.py" render --pr-data "$work/data.json" --cost "$cost" --verdicts "$vdir" \
  "${ci[@]}" "${prev[@]}" "${now[@]}" >"$work/body.md" || rc=$?
[ "$rc" = 3 ] && { echo "change-metrics: not yet: PR #$pr's deploy comment isn't final; check in again"; exit 3; }
[ "$rc" = 0 ] || exit 2
jq -n --rawfile b "$work/body.md" '{body: ($b | rtrimstr("\n"))}' | api -X POST "repos/$slug/issues/$pr/comments" --input - >/dev/null
echo "POSTED: PR #$pr · $(sed -n 2p "$work/body.md")"
