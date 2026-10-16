#!/usr/bin/env bash
# ship: the one way Claude puts a change on a PR (W10.6.7). First the title and body must have the PR
# template's shape (pr-body-check.py, F-NEW-52), and the title pass the repo's own
# scripts/pr-title-check.py if it has one. Then it reviews the committed HEAD with exactly the
# given title and body, locally (review.sh, beside this file); only a pass goes on: it pushes the
# branch, creates the PR (or updates the open PR's title, body and base) with exactly those words,
# checks GitHub kept them (text it appends to the body is fine), and posts the verdict comment. Code and
# words go up together. Contract: kit/notes/revamp/workstreams/W10-v2.md § W10.6.7.
#   usage: ship.sh --title <text> --body-file <file> [--base <branch>]   (from the worktree root)
# Exit 0 = shipped (last line "SHIPPED: PR #<n> · <url> · <commit12>"); 1 = the words don't have the
# template's shape or the repo's title rule, or the review failed: nothing pushed, fix, commit, ship again; 3 = ask-owner; 2 = could-not-run (bad input, a result
# ship can't trust, or GitHub failing; what was done is said). For 2 and 3, stop and ask the owner.
# Feedback, not a wall: the review guard refuses the other ways to a PR, but can be got around.
set -uo pipefail

here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)
OWNER="Stop and tell the owner, with the lines above; don't retry until they decide."
cnr() { printf 'ship: could not run: %s\n%s\n' "$1" "$OWNER" >&2; exit 2; }
title="" body_file="" base="" have_title=0
while [ $# -gt 0 ]; do
  case "$1" in
    --title | --body-file | --base)
      [ $# -ge 2 ] || cnr "$1 needs a value"
      case "$1" in --title) title=$2 have_title=1 ;; --body-file) body_file=$2 ;; --base) base=$2 ;; esac
      shift 2 ;;
    *) cnr "unknown argument '$1' (usage: ship.sh --title <text> --body-file <file> [--base <branch>])" ;;
  esac
done
[ "$have_title" = 1 ] && [ -n "${title//[[:space:]]/}" ] || cnr "--title is required and can't be blank"
[ -n "$body_file" ] || cnr "--body-file is required"
body=$(cat -- "$body_file" 2>/dev/null && echo x) || cnr "can't read the body file '$body_file'"
body=${body%x}
for t in git jq gh; do command -v "$t" >/dev/null || cnr "$t not found"; done
[ -x "$here/review.sh" ] || cnr "$here/review.sh is missing or not executable"

# --- The words have the PR template's shape, before anything is reviewed or pushed.
body_check="$here/../scripts/pr-body-check.py"
[ -x "$body_check" ] || cnr "$body_check is missing or not executable"
crc=0
cout=$("$body_check" "$body_file" "$title" 2>&1) || crc=$?
case $crc in
  0) ;;
  1) printf '%s\n' "$cout"
     echo "The PR's words don't have the template's shape; nothing was reviewed or pushed. Fix them and ship again."
     exit 1 ;;
  *) cnr "pr-body-check.py couldn't run (exit $crc): $cout" ;;
esac

# --- The worktree: a branch, everything committed, a GitHub-style origin.
top=$(git rev-parse --show-toplevel 2>/dev/null) || cnr "not in a git worktree"
cd "$top" || cnr "can't enter $top"
# The repo's own title rule, if it has one, checked like the body's shape: before the review (the
# devshop's: a Conventional Commit type, spec specs/devshop-releases.md). Projects have none.
if [ -e scripts/pr-title-check.py ]; then
  [ -x scripts/pr-title-check.py ] || cnr "scripts/pr-title-check.py is not executable"
  trc=0
  tout=$(scripts/pr-title-check.py "$title" 2>&1) || trc=$?
  case $trc in
    0) ;;
    1) printf '%s\n' "$tout"
       echo "The PR's title doesn't follow this repo's scripts/pr-title-check.py; nothing was reviewed or pushed. Fix it and ship again."
       exit 1 ;;
    *) cnr "scripts/pr-title-check.py couldn't run (exit $trc): $tout" ;;
  esac
fi
branch=$(git symbolic-ref --short -q HEAD) || cnr "HEAD is detached; check out the branch to ship"
[ -z "$(git status --porcelain)" ] || cnr "the worktree has uncommitted changes; commit them first (only a commit is reviewed)"
head=$(git rev-parse HEAD)
slug=$(git remote get-url origin 2>/dev/null | sed -nE 's#.*[:/]([^/:]+)/([^/]+)$#\1/\2#p' | sed -E 's#\.git/?$##')
[[ "$slug" =~ ^[^/]+/[^/]+$ ]] || cnr "origin is not a GitHub-style <owner>/<repo> remote"

# --- The open PR, if any, and the base.
q=$(jq -rn --arg h "${slug%%/*}:$branch" '$h | @uri')
{ prs=$(gh api "repos/$slug/pulls?head=$q&state=open") && jq -e 'type == "array"' <<<"$prs" >/dev/null; } \
  || cnr "can't look up the open PR for $branch (gh failed)"
number=$(jq -r '.[0].number // empty' <<<"$prs")
if [ -z "$base" ]; then
  base=$(jq -r '.[0].base.ref // empty' <<<"$prs")
  [ -n "$base" ] || base=$(git symbolic-ref --short -q refs/remotes/origin/HEAD | sed 's#^origin/##')
  [ -n "$base" ] || base=$(gh api "repos/$slug" 2>/dev/null | jq -r '.default_branch // empty') || true
  [ -n "$base" ] || cnr "can't tell the base branch; pass --base"
fi
# By name, so origin/<base> exists and is current even in a single-branch clone.
git fetch -q origin "+refs/heads/$base:refs/remotes/origin/$base" 2>/dev/null || cnr "can't fetch the base branch '$base' from origin"

# --- The review, of HEAD with exactly these words.
words_file=$(mktemp) || cnr "mktemp failed"
trap 'rm -f "$words_file"' EXIT
jq -n --arg t "$title" --arg b "$body" '{title: $t, body: $b}' | "$here/pr-words.sh" >"$words_file" || cnr "can't write the PR's words"
rc=0
out=$("$here/review.sh" --base "origin/$base" --pr "$words_file") || rc=$?
lines=$(grep -c '^REVIEW: ' <<<"$out")
[ "$lines" = 1 ] || cnr "review.sh printed $lines REVIEW: lines (exit $rc)"
line=$(grep '^REVIEW: ' <<<"$out")
outcome=$(sed -E 's/^REVIEW: ([a-z-]+) .*/\1/' <<<"$line") verdict=${line##* · }
case "$rc:$outcome" in 0:pass | 1:fail | 2:could-not-run | 3:ask-owner) ;; *) cnr "review.sh exit $rc doesn't match its line: $line" ;; esac
echo "$line"
if [ "$outcome" != pass ]; then
  jq -r '(.acceptance[] | select(.met | not) | "- unmet \(.item): \(.evidence)"),
    (.findings[] | select(.severity != "low") | "- \(.severity) · \(.lens)\(if (.file // "") != "" then " · " + .file else "" end): \(.what) — fix: \(.fix)"),
    (if (.reason // "") != "" then "Reason: \(.reason)" else empty end)' "$verdict" 2>/dev/null
  case "$outcome" in
    fail) echo "The review failed; nothing was pushed. Fix the findings, commit, and ship again."; exit 1 ;;
    ask-owner) echo "$OWNER"; exit 3 ;;
    *) echo "$OWNER"; exit 2 ;;
  esac
fi

# --- A pass: push, then the PR's words, then the verdict.
git push -q -u origin "HEAD:refs/heads/$branch" || cnr "the review passed, but git push failed; nothing else was done"
fields=$(jq -n --arg t "$title" --arg b "$body" --arg base "$base" '{title: $t, body: $b, base: $base}')
if [ -n "$number" ]; then
  pr=$(gh api -X PATCH "repos/$slug/pulls/$number" --input - <<<"$fields") \
    || cnr "pushed $branch, but updating PR #$number's words failed; the verdict was not posted"
else
  pr=$(gh api -X POST "repos/$slug/pulls" --input - <<<"$(jq --arg h "$branch" '. + {head: $h}' <<<"$fields")") \
    || cnr "pushed $branch, but creating the PR failed; the verdict was not posted"
  number=$(jq -r .number <<<"$pr")
fi
# What GitHub kept: the same title, and a body that starts with the reviewed one. Text GitHub
# appends (an attribution footer) can't change what was reviewed; a rewrite or new title can.
kept=$(gh api "repos/$slug/pulls/$number" | jq -r --arg t "$title" --arg b "$body" \
  '.title == $t and ((.body // "") | startswith($b))') || kept=unknown
comment=$("$here/pr-comment.sh" "$verdict") || cnr "pushed $branch and set PR #$number's words, but can't render the verdict"
jq -n --arg b "$comment" '{body: $b}' | gh api -X POST "repos/$slug/issues/$number/comments" --input - >/dev/null \
  || cnr "pushed $branch and set PR #$number's words, but posting the verdict comment failed"
if [ "$kept" != true ]; then
  cnr "PR #$number is shipped and its verdict posted, but GitHub changed the PR's title or body after ship set them (or couldn't be read back)"
fi
echo "SHIPPED: PR #$number · $(jq -r .html_url <<<"$pr") · ${head:0:12}"
