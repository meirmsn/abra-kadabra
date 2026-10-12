#!/usr/bin/env bash
# Says whether a PR carries a passing reviewer verdict for its head commit (W10.6.6, TARGET Verify 7):
# the latest comment whose FIRST line is pr-comment.sh's marker decides. Deterministic, no network:
# verdict-wait.sh feeds it the PR's comments. A tripwire, not a wall: anyone who can comment on the
# PR, the agent included, can post a marker.
#   usage: verdict-check.sh --head <40-hex sha> --comments <file: JSON list of {"body": ...}>
# Stdout: one line, "VERDICT: <ok|missing|stale|failing|could-not-run> · <why>".
# Exit 0 = ok; 1 = missing, stale or failing; 2 = could-not-run (bad arguments or input).
set -uo pipefail

cnr() { echo "VERDICT: could-not-run · $1"; exit 2; }
head="" file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --head) [ $# -ge 2 ] || cnr "--head needs a value"; head=$2; shift 2 ;;
    --comments) [ $# -ge 2 ] || cnr "--comments needs a value"; file=$2; shift 2 ;;
    *) cnr "unknown argument '$1'" ;;
  esac
done
[[ "$head" =~ ^[0-9a-f]{40}$ ]] || cnr "--head must be a full 40-hex commit sha"
[ -n "$file" ] || cnr "--comments is required"
command -v jq >/dev/null || cnr "jq not found"
list=$(cat -- "$file" 2>/dev/null) || cnr "cannot read '$file'"

# The latest marker comment: its first line (CR stripped) is exactly the marker, else it isn't one.
marker=$(jq -r 'if type == "array" and all(.[]; type == "object" and (.body | type == "string")) then
    [.[] | .body | split("\n")[0] | rtrimstr("\r") | capture("^<!-- devshop-review (?<j>\\{.*\\}) -->$").j]
    | if length == 0 then "none" else last end
  else error("not a list of comments") end' <<<"$list" 2>/dev/null) \
  || cnr "the comments are not a JSON list of {\"body\": <string>}"
[ "$marker" != none ] || { echo "VERDICT: missing · no reviewer verdict comment on this PR"; exit 1; }
jq -e 'type == "object" and (.commit | type == "string") and (.outcome | type == "string")' <<<"$marker" >/dev/null 2>&1 \
  || cnr "the latest verdict marker is not valid: $marker"
commit=$(jq -r .commit <<<"$marker") outcome=$(jq -r .outcome <<<"$marker")
if [ "$commit" != "$head" ]; then
  echo "VERDICT: stale · the latest verdict is for ${commit:0:12}, the head is ${head:0:12}"; exit 1
fi
if [ "$outcome" != pass ]; then
  echo "VERDICT: failing · the latest verdict for ${head:0:12} is $outcome"; exit 1
fi
echo "VERDICT: ok · pass for ${head:0:12}"
