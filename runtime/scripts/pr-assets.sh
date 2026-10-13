#!/usr/bin/env bash
# pr-assets: puts a PR's screenshots on GitHub and prints the lines that embed them (W10.6.9, TARGET
# Review 4). The images become one orphan commit, made through GitHub's REST git-data API (a cloud
# session's git proxy only accepts pushes to the session branch), kept alive by its own ref,
# refs/devshop-assets/<branch>/<HEAD's first 12>-<the commit's first 12>: not a branch, so it is never
# cloned, starts no workflow and leaves `main` alone; never moved, so links already posted keep working. The links name that commit's SHA, so they work before and after
# the merge, after the branch is deleted, and for a private repo's signed-in viewers (L-30).
#   usage: pr-assets.sh <image>...   (from the worktree root of the PR's branch, HEAD = the commit shown)
# Prints one "![<label>](https://github.com/<owner>/<repo>/raw/<commit>/<file>)" line per image, then
# "ASSETS: <n> image(s) · <commit> · <ref>". The label is the file name without its order prefix and
# extension (01-empty_state.png → "empty state"). Images: png, jpg, jpeg, gif or webp, at most 10 MB,
# names of letters, digits, ".", "_" and "-". Run again (screenshots retaken, or a new HEAD), it makes a
# new commit and ref; earlier ones stay.
# Exit 0 = uploaded and read back; 2 = could not run (nothing printed but the reason).
set -uo pipefail

MAX_BYTES=$((10 * 1024 * 1024))
cnr() { printf 'pr-assets: could not run: %s\n' "$1" >&2; exit 2; }
[ $# -gt 0 ] || cnr "no images (usage: pr-assets.sh <image>...)"
for t in git jq gh base64 od; do command -v "$t" >/dev/null || cnr "$t not found"; done

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

tmp=$(mktemp -d) || cnr "mktemp failed"
trap 'rm -rf "$tmp"' EXIT
api() { gh api "$@" 2>"$tmp/err"; }
why() { tr '\n' ' ' <"$tmp/err" | cut -c1-200; }

# --- Blobs, each checked against git's own SHA of the file, then the tree and the orphan commit.
entries='[]'
for f in "$@"; do
  name=${f##*/}
  want=$(git hash-object -- "$f") || cnr "git hash-object failed on $name"
  base64 <"$f" | tr -d '\n' >"$tmp/b64"
  jq -n --rawfile c "$tmp/b64" '{content: $c, encoding: "base64"}' >"$tmp/req" || cnr "can't encode $name"
  got=$(api -X POST "repos/$slug/git/blobs" --input "$tmp/req" | jq -r '.sha // empty') \
    || cnr "uploading $name failed: $(why)"
  [ "$got" = "$want" ] || cnr "GitHub stored $name with SHA '$got', not its git SHA $want"
  entries=$(jq --arg p "$name" --arg s "$want" '. + [{path: $p, mode: "100644", type: "blob", sha: $s}]' <<<"$entries")
done
jq -n --argjson t "$entries" '{tree: $t}' >"$tmp/req"
tree=$(api -X POST "repos/$slug/git/trees" --input "$tmp/req" | jq -r '.sha // empty') && [ -n "$tree" ] \
  || cnr "creating the tree failed: $(why)"
msg=$(printf 'devshop assets: %s at %s\n\nScreenshots for the PR from %s, taken at %s.\nKept by refs/devshop-assets/%s/%s-<this commit>; never merged.\n' \
  "$branch" "${head:0:12}" "$branch" "$head" "$branch" "${head:0:12}")
jq -n --arg m "$msg" --arg t "$tree" '{message: $m, tree: $t, parents: []}' >"$tmp/req"
commit=$(api -X POST "repos/$slug/git/commits" --input "$tmp/req" | jq -r '.sha // empty') && [ -n "$commit" ] \
  || cnr "creating the commit failed: $(why)"

# --- The commit's own ref, never moved. If it exists already (the identical upload again), the
# read-back below checks it holds this commit.
ref="refs/devshop-assets/$branch/${head:0:12}-${commit:0:12}"
ref_path=$(jq -rn --arg r "${ref#refs/}" '$r | split("/") | map(@uri) | join("/")')
jq -n --arg r "$ref" --arg s "$commit" '{ref: $r, sha: $s}' >"$tmp/req"
if ! api -X POST "repos/$slug/git/refs" --input "$tmp/req" >/dev/null; then
  grep -q "already exists" "$tmp/err" \
    || cnr "GitHub would not create $ref ($(why)). If it refuses refs outside refs/heads, the fallback is a never-merged devshop-assets branch (W10.6.9): ask the owner"
fi

# --- Read it all back: the ref, the commit, every file's SHA.
got=$(api "repos/$slug/git/ref/$ref_path" | jq -r '.object.sha // empty') || cnr "reading $ref back failed: $(why)"
[ "$got" = "$commit" ] || cnr "$ref reads back at '$got', not the assets commit $commit"
api "repos/$slug/git/commits/$commit" >"$tmp/commit" || cnr "reading the assets commit back failed: $(why)"
jq -e --arg t "$tree" '.tree.sha == $t and (.parents | length) == 0' "$tmp/commit" >/dev/null \
  || cnr "the assets commit reads back with another tree or with parents"
api "repos/$slug/git/trees/$tree" >"$tmp/tree" || cnr "reading the tree back failed: $(why)"
jq -e --argjson want "$entries" '[.tree[] | {path, sha}] | sort == ($want | map({path, sha}) | sort)' "$tmp/tree" >/dev/null \
  || cnr "the tree reads back with other files or SHAs than were uploaded"

for f in "$@"; do
  name=${f##*/} label=${f##*/}
  label=${label%.*}
  label=$(sed -E 's/^[0-9]+[-_. ]*//; s/[-_]+/ /g' <<<"$label")
  printf '![%s](https://github.com/%s/raw/%s/%s)\n' "${label:-$name}" "$slug" "$commit" "$name"
done
n=$#; s=s; [ "$n" != 1 ] || s=""
echo "ASSETS: $n image$s · $commit · $ref"
