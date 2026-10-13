#!/usr/bin/env bash
# ship: the one way Claude puts a change on a PR (W10.6.7). Reviews the committed HEAD with exactly
# the given title and body, locally (review.sh, beside this file); only a pass goes on: it pushes the
# branch, creates the PR (or updates the open PR's title, body and base) with exactly those words,
# sets them back once if GitHub changed them, and posts the verdict comment (pr-comment.sh). Code and
# words go up together. Contract: kit/notes/revamp/workstreams/W10-v2.md § W10.6.7.
#   usage: ship.sh --title <text> --body-file <file> [--base <branch>]   (from the worktree root)
# Exit 0 = shipped (last line "SHIPPED: PR #<n> · <url> · <commit12>"); 1 = the review failed:
# nothing pushed, fix, commit, ship again; 3 = ask-owner; 2 = could-not-run (bad input, a result
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
for t in git jq gh sha256sum; do command -v "$t" >/dev/null || cnr "$t not found"; done
[ -x "$here/review.sh" ] || cnr "$here/review.sh is missing or not executable"

# --- The worktree: a branch, everything committed, a GitHub-style origin.
top=$(git rev-parse --show-toplevel 2>/dev/null) || cnr "not in a git worktree"
cd "$top" || cnr "can't enter $top"
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
  [ -n "$base" ] || base=$(gh api "repos/$slug" --jq .default_branch 2>/dev/null) || true
  [ -n "$base" ] || cnr "can't tell the base branch; pass --base"
fi
git fetch -q origin "$base" 2>/dev/null || cnr "can't fetch the base branch '$base' from origin"

# --- The review, of HEAD with exactly these words.
words_file=$(mktemp) || cnr "mktemp failed"
trap 'rm -f "$words_file"' EXIT
jq -n --arg t "$title" --arg b "$body" '{title: $t, body: $b}' | "$here/pr-words.sh" >"$words_file" || cnr "can't write the PR's words"
words_sum=$(sha256sum <"$words_file" | cut -c1-64)
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
words_now() { gh api "repos/$slug/pulls/$number" | "$here/pr-words.sh" | sha256sum | cut -c1-64; }
changed=""
if [ "$(words_now)" != "$words_sum" ]; then # GitHub changed them (a server footer): set them back once
  gh api -X PATCH "repos/$slug/pulls/$number" --input - <<<"$(jq '{title, body}' <<<"$fields")" >/dev/null
  [ "$(words_now)" = "$words_sum" ] || changed=1
fi
comment=$("$here/pr-comment.sh" "$verdict") || cnr "pushed $branch and set PR #$number's words, but can't render the verdict"
jq -n --arg b "$comment" '{body: $b}' | gh api -X POST "repos/$slug/issues/$number/comments" --input - >/dev/null \
  || cnr "pushed $branch and set PR #$number's words, but posting the verdict comment failed"
if [ -n "$changed" ]; then
  cnr "PR #$number is shipped and its verdict posted, but GitHub changed the PR's title or body after ship set them, twice"
fi
echo "SHIPPED: PR #$number · $(jq -r .html_url <<<"$pr") · ${head:0:12}"
