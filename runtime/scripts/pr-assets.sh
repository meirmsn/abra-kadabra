#!/usr/bin/env bash
# pr-assets: puts a PR's screenshots on its branch and prints the lines that embed them (W10.6.9,
# TARGET Review 4). The images become one parentless commit S, and the branch moves to a merge commit
# whose files are exactly HEAD's and whose second parent is S. Nothing in the PR's files or diff
# changes, so there is nothing to remove before the merge. ship's ordinary push of the branch (the
# one push a cloud session's git proxy allows) carries S to GitHub, and GitHub keeps it with the PR
# (refs/pull/<n>/head) after the merge and the branch's deletion. The links name S's SHA
# (https://github.com/<owner>/<repo>/raw/<S>/<file>), which a private repo's signed-in viewers can
# open, and anyone once it is public (L-30). With squash merges, the default branch never gets S, and
# a clone of it never downloads it; so the script refuses a repo that also allows merge commits or
# rebase merges.
#   usage: pr-assets.sh <image>...   (from the PR branch's worktree, HEAD = the commit shown)
# Prints one "![<label>](https://github.com/<owner>/<repo>/raw/<S>/<file>)" line per image, then
# "ASSETS: <n> image(s) · <S> · <branch> at <merge12>". The label is the file name without its order
# prefix and extension (01-empty_state.png → "empty state"). Images: png, jpg, jpeg, gif or webp, at
# most 10 MB, names of letters, digits, ".", "_" and "-". Run it again after retaking screenshots or
# after a new commit: each run adds its own S, and earlier ones stay on the branch.
# Exit 0 = done (then ship); 2 = could not run (nothing changed, and nothing printed but the reason).
set -uo pipefail

MAX_BYTES=$((10 * 1024 * 1024))
cnr() { printf 'pr-assets: could not run: %s\n' "$1" >&2; exit 2; }
[ $# -gt 0 ] || cnr "no images (usage: pr-assets.sh <image>...)"
for t in git jq gh od; do command -v "$t" >/dev/null || cnr "$t not found"; done

# --- The images: real, small, safely named, each name once.
declare -A seen=()
for f in "$@"; do
  [ -f "$f" ] || cnr "no such file: $f"
  name=${f##*/}
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || cnr "'$name': use only letters, digits, '.', '_' and '-' in names (they become URLs)"
  case ${name##*.} in png | jpg | jpeg | gif | webp) ;; *) cnr "'$name': want a png, jpg, jpeg, gif or webp file" ;; esac
  [ -z "${seen[$name]:-}" ] || cnr "'$name' is given twice"
  seen[$name]=1
  [ "$(wc -c <"$f")" -le "$MAX_BYTES" ] || cnr "'$name' is over 10 MB"
  magic=$(od -An -tx1 -N12 -- "$f" | tr -d ' \n')
  case $magic in
    89504e470d0a1a0a* | ffd8ff* | 47494638*) ;;
    52494646????????57454250) ;;
    *) cnr "'$name' is not a PNG, JPEG, GIF or WebP image" ;;
  esac
done

# --- The commit the screenshots show: a branch, nothing uncommitted, a GitHub-style origin.
top=$(git rev-parse --show-toplevel 2>/dev/null) || cnr "not in a git worktree"
branch=$(git -C "$top" symbolic-ref --short -q HEAD) || cnr "HEAD is detached; check out the PR's branch"
[ -z "$(git -C "$top" status --porcelain --untracked-files=no)" ] \
  || cnr "the worktree has uncommitted changes; the screenshots must show a commit"
head=$(git -C "$top" rev-parse HEAD)
slug=$(git -C "$top" remote get-url origin 2>/dev/null | sed -nE 's#.*github\.com[:/]([^/:]+)/([^/]+)$#\1/\2#p' | sed -E 's#\.git/?$##')
[[ "$slug" =~ ^[^/]+/[^/]+$ ]] || cnr "origin is not a github.com <owner>/<repo> remote"

# --- Squash merges only, so the default branch never gets the screenshots.
settings=$(gh api "repos/$slug" 2>&1) || cnr "can't read $slug's merge settings: $(tr '\n' ' ' <<<"$settings" | cut -c1-200)"
jq -e '.allow_merge_commit == false and .allow_rebase_merge == false' <<<"$settings" >/dev/null 2>&1 \
  || cnr "$slug allows merge commits or rebase merges, which would carry the screenshots into its default branch; make squash the only merge method, or ask the owner"

# --- S: the images, parentless. Then the merge, with HEAD's own tree. Signed when commits are
# (commit-tree ignores commit.gpgsign; GitHub would show them Unverified, and a rule may refuse them).
sign=()
[ "$(git -C "$top" config --bool commit.gpgsign 2>/dev/null)" != true ] || sign=(-S)
entries=""
for f in "$@"; do
  blob=$(git -C "$top" hash-object -w -- "$f") || cnr "git hash-object failed on ${f##*/}"
  entries+=$(printf '100644 blob %s\t%s' "$blob" "${f##*/}")$'\n'
done
tree=$(printf '%s' "$entries" | git -C "$top" mktree) || cnr "git mktree failed"
s=$(printf 'devshop assets: %s at %s\n\nScreenshots for the PR from %s, taken at %s. Not part of the change: the\nmerge that brings them has the files of %s.\n' \
  "$branch" "${head:0:12}" "$branch" "$head" "${head:0:12}" | git -C "$top" commit-tree "${sign[@]}" "$tree") || cnr "git commit-tree failed for the screenshots"
m=$(printf 'Attach the PR screenshots taken at %s (no file changes)\n\nScreenshots commit: %s (devshop pr-assets.sh, W10.6.9).\n' "${head:0:12}" "$s" \
  | git -C "$top" commit-tree "${sign[@]}" "$(git -C "$top" rev-parse "HEAD^{tree}")" -p "$head" -p "$s") || cnr "git commit-tree failed for the merge"
git -C "$top" update-ref -m "pr-assets: attach screenshots" "refs/heads/$branch" "$m" "$head" \
  || cnr "couldn't move $branch to the merge (did it move meanwhile?)"

# --- Read it back: the branch, the files unchanged, every image.
[ "$(git -C "$top" rev-parse HEAD)" = "$m" ] || cnr "HEAD is not the merge after moving the branch"
[ "$(git -C "$top" rev-parse "HEAD^{tree}")" = "$(git -C "$top" rev-parse "$head^{tree}")" ] || cnr "the merge changed the PR's files"
for f in "$@"; do
  git -C "$top" cat-file blob "$s:${f##*/}" | cmp -s - "$f" || cnr "${f##*/} doesn't read back byte for byte"
done

for f in "$@"; do
  name=${f##*/} label=${f##*/}
  label=${label%.*}
  label=$(sed -E 's/^[0-9]+[-_. ]*//; s/[-_]+/ /g' <<<"$label")
  printf '![%s](https://github.com/%s/raw/%s/%s)\n' "${label:-$name}" "$slug" "$s" "$name"
done
n=$#; p=s; [ "$n" != 1 ] || p=""
echo "ASSETS: $n image$p · $s · $branch at ${m:0:12}"
