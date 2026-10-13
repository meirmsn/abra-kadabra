#!/usr/bin/env bash
# Tests runtime/scripts/pr-assets.sh (W10.6.9): it puts a PR's screenshots on GitHub as one orphan
# commit, through the REST git-data API, kept alive by its own ref,
# refs/devshop-assets/<branch>/<head12>-<assets12> (not a branch: never cloned, starts no workflow;
# never moved, so links already posted keep working), and prints image lines pinned to that commit that
# pr-body-check.py accepts. It reads everything back and fails closed. Runs against a stub `gh` that
# keeps a fake git-object store in $GH_DIR (blob SHAs from `git hash-object`, as GitHub's are).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/runtime/scripts/pr-assets.sh"
source "$repo_root/tests/lib.sh"
command -v jq >/dev/null || fail "jq not found"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
ok() { echo "ok - $1"; }
NAME="setup"

# --- A stub gh: POST git/blobs|trees|commits|refs, PATCH git/refs/<ref>, GET git/ref/<ref>|commits/<sha>|
# trees/<sha>. $GH_DIR/fail-<blobs|trees|commits|refs|patch|get>: that call fails; $GH_DIR/bad-blob: blob
# SHAs come back wrong; $GH_DIR/wrong-ref: the ref reads back at another commit (also when it already exists); $GH_DIR/wrong-tree: the
# tree reads back with another file; $GH_DIR/refuse-ref: GitHub
# refuses a ref outside refs/heads (422).
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_DIR/calls"
[ "$1" = api ] || { echo "stub gh: only api" >&2; exit 1; }
shift; method=GET path="" input=""
while [ $# -gt 0 ]; do case $1 in -X) method=$2; shift 2 ;; --input) input=$(cat "$2"); [ "$2" != - ] || input=$(cat); shift 2 ;; *) path=$1; shift ;; esac; done
store="$GH_DIR/store"; mkdir -p "$store/refs"
p=${path#repos/example/app/git/}
[ "$p" != "$path" ] || { echo "stub gh: unexpected path $path" >&2; exit 1; }
id() { sha1sum | cut -c1-40; }
case "$method $p" in
  "POST blobs")
    [ ! -f "$GH_DIR/fail-blobs" ] || { echo "HTTP 502" >&2; exit 1; }
    [ "$(jq -r .encoding <<<"$input")" = base64 ] || { echo "HTTP 422: encoding" >&2; exit 1; }
    jq -r .content <<<"$input" | base64 -d >"$store/tmp"
    sha=$(git hash-object "$store/tmp"); mv "$store/tmp" "$store/$sha"
    [ ! -f "$GH_DIR/bad-blob" ] || sha=$(echo x | id)
    jq -n --arg s "$sha" '{sha: $s}' ;;
  "POST trees")
    [ ! -f "$GH_DIR/fail-trees" ] || { echo "HTTP 502" >&2; exit 1; }
    sha=$(id <<<"$input"); jq --arg s "$sha" '{sha: $s, tree: .tree}' <<<"$input" | tee "$store/$sha" ;;
  "POST commits")
    [ ! -f "$GH_DIR/fail-commits" ] || { echo "HTTP 502" >&2; exit 1; }
    sha=$(id <<<"$input")
    jq --arg s "$sha" '{sha: $s, message: .message, parents: (.parents | map({sha: .})), tree: {sha: .tree}}' <<<"$input" | tee "$store/$sha" ;;
  "POST refs")
    [ ! -f "$GH_DIR/fail-refs" ] || { echo "HTTP 502" >&2; exit 1; }
    ref=$(jq -r .ref <<<"$input")
    case $ref in refs/heads/* | refs/tags/*) ;; *) [ ! -f "$GH_DIR/refuse-ref" ] || { echo "HTTP 422: Reference name is invalid" >&2; exit 1; } ;; esac
    f="$store/refs/$(jq -rn --arg r "$ref" '$r | @uri')"
    [ ! -f "$f" ] || { echo "HTTP 422: Reference already exists" >&2; exit 1; }
    jq -r .sha <<<"$input" >"$f"; jq -n --arg r "$ref" --arg s "$(cat "$f")" '{ref: $r, object: {sha: $s}}' ;;
  "PATCH refs/"*)
    [ ! -f "$GH_DIR/fail-patch" ] || { echo "HTTP 502" >&2; exit 1; }
    ref=refs/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "${p#refs/}")
    f="$store/refs/$(jq -rn --arg r "$ref" '$r | @uri')"
    [ -f "$f" ] || { echo "HTTP 404" >&2; exit 1; }
    [ "$(jq -r .force <<<"$input")" = true ] || { echo "HTTP 422: not a fast forward" >&2; exit 1; }
    jq -r .sha <<<"$input" >"$f"; jq -n --arg r "$ref" --arg s "$(cat "$f")" '{ref: $r, object: {sha: $s}}' ;;
  "GET ref/"*)
    [ ! -f "$GH_DIR/fail-get" ] || { echo "HTTP 502" >&2; exit 1; }
    ref=refs/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "${p#ref/}")
    f="$store/refs/$(jq -rn --arg r "$ref" '$r | @uri')"
    [ -f "$f" ] || { echo "HTTP 404" >&2; exit 1; }
    sha=$(cat "$f"); [ ! -f "$GH_DIR/wrong-ref" ] || sha=$(echo y | id)
    jq -n --arg r "$ref" --arg s "$sha" '{ref: $r, object: {sha: $s, type: "commit"}}' ;;
  "GET commits/"* | "GET trees/"*)
    [ ! -f "$GH_DIR/fail-get" ] || { echo "HTTP 502" >&2; exit 1; }
    f="$store/${p#*/}"; [ -f "$f" ] || { echo "HTTP 404" >&2; exit 1; }
    if [ -f "$GH_DIR/wrong-tree" ] && [ "${p%%/*}" = trees ]; then jq '.tree[0].path = "other.png"' "$f"; else cat "$f"; fi ;;
  *) echo "stub gh: unexpected $method $p" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"

# --- A project: a clone on branch feat/cart with a GitHub-style origin.
new_repo "$work/app"
git -C "$work/app" checkout -qb feat/cart
git -C "$work/app" remote add origin https://github.com/example/app.git
head=$(git -C "$work/app" rev-parse HEAD)

# Images: real magic bytes, different content.
mkdir -p "$work/shots"
png() { python3 - "$1" "$2" <<'PY'
import struct, sys, zlib
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
c = int(sys.argv[2]); raw = b"".join(b"\x00" + bytes([c, 0, 0]) * 4 for _ in range(4))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0))
                             + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
PY
}
png "$work/shots/01-add-item.png" 10
png "$work/shots/02-empty_state.png" 200
printf '\xff\xd8\xff\xe0 jpeg' >"$work/shots/03-error.jpg"

# run <want exit> <args...>: in the project, with a fresh store; output in $work/out.log
run() {
  local want=$1 rc=0; shift
  export GH_DIR="$work/gh-$RANDOM$RANDOM"; mkdir -p "$GH_DIR"
  for f in ${GH_FLAGS-}; do touch "$GH_DIR/$f"; done
  (cd "$work/app" && "$script" "$@") >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "${NAME}: expected exit $want, got $rc"; }
}
names() { grep -qF -- "$1" "$work/out.log" || { cat "$work/out.log" >&2; fail "${NAME}: output doesn't name '$1'"; }; }

# --- The happy path.
NAME="three images upload" run 0 "$work/shots/01-add-item.png" "$work/shots/02-empty_state.png" "$work/shots/03-error.jpg"
commit=$(sed -nE 's/^ASSETS: 3 images · ([0-9a-f]{40}) · (.*)$/\1/p' "$work/out.log")
[ -n "$commit" ] || { cat "$work/out.log"; fail "no ASSETS line with 3 images and a commit"; }
ref="refs/devshop-assets/feat/cart/${head:0:12}-${commit:0:12}"
names " · $ref"
for want in "![add item](https://github.com/example/app/raw/$commit/01-add-item.png)" \
  "![empty state](https://github.com/example/app/raw/$commit/02-empty_state.png)" \
  "![error](https://github.com/example/app/raw/$commit/03-error.jpg)"; do names "$want"; done
ok "prints one image line per file, pinned to the assets commit, and the ASSETS line"
store="$GH_DIR/store"
[ "$(cat "$store/refs/$(jq -rn --arg r "$ref" '$r | @uri')")" = "$commit" ] || fail "the ref doesn't point at the assets commit"
[ "$(find "$store/refs" -type f | wc -l)" = 1 ] || fail "more than one ref was made"
! grep -q "refs/heads" "$GH_DIR/calls" || fail "a branch was touched"
ok "the commit is kept by $ref, and no branch is touched"
jq -e '.parents == []' "$store/$commit" >/dev/null || fail "the assets commit has parents"
jq -e --arg h "$head" '.message | contains($h) and contains("feat/cart")' "$store/$commit" >/dev/null \
  || fail "the commit message doesn't name the branch and HEAD"
tree=$(jq -r .tree.sha "$store/$commit")
[ "$(jq -r '[.tree[].path] | join(" ")' "$store/$tree")" = "01-add-item.png 02-empty_state.png 03-error.jpg" ] \
  || fail "tree paths: $(jq -c '[.tree[].path]' "$store/$tree")"
for f in 01-add-item.png 02-empty_state.png 03-error.jpg; do
  b=$(jq -r --arg p "$f" '.tree[] | select(.path == $p) | .sha' "$store/$tree")
  cmp -s "$store/$b" "$work/shots/$f" || fail "$f was not stored byte for byte"
done
ok "an orphan commit naming the branch and HEAD, its tree holding each image byte for byte"
{
  printf 'Carts can be saved.\n\nA cart now stays when you leave. It matters because carts were lost.\n\n'
  printf '**Preview:** none — test\n\n## What you should know\n\n- **Behaviour change:** x\n- **Decisions:** x\n'
  printf -- '- **Changed after the go:** nothing\n- **Tests deleted or loosened:** none\n- **Manual steps for you:** none\n\n'
  printf '## Evidence\n\n- **Screenshots:**\n'
  grep '^!\[' "$work/out.log" | sed 's/^/  - step: /'
  printf -- '- **Reviewer:** pass\n- **CI:** green\n- **Low findings:** none\n\n'
  printf '<details>\n<summary>Engineering details</summary>\n\nx\n\n</details>\n'
} >"$work/body.md"
"$repo_root/runtime/scripts/pr-body-check.py" "$work/body.md" >"$work/check.log" 2>&1 \
  || { cat "$work/check.log" "$work/body.md"; fail "pr-body-check.py refuses the printed lines"; }
ok "pr-body-check.py accepts a body built from the printed lines"

# --- Again at the same HEAD (screenshots retaken): a new commit with its own ref; the first stays.
refkey() { jq -rn --arg r "$1" '$r | @uri'; }
GH_DIR="$work/gh-again"; mkdir -p "$GH_DIR/store/refs"
cp -R "$store/refs/." "$GH_DIR/store/refs/"
(cd "$work/app" && "$script" "$work/shots/02-empty_state.png") >"$work/out.log" 2>&1 || { cat "$work/out.log"; fail "a second upload at the same HEAD failed"; }
second=$(sed -nE 's/^ASSETS: 1 image · ([0-9a-f]{40}) · .*/\1/p' "$work/out.log")
[ -n "$second" ] && [ "$second" != "$commit" ] || fail "second upload: no new commit"
[ "$(cat "$GH_DIR/store/refs/$(refkey "$ref")")" = "$commit" ] || fail "the first upload's ref was moved or lost"
[ "$(cat "$GH_DIR/store/refs/$(refkey "refs/devshop-assets/feat/cart/${head:0:12}-${second:0:12}")")" = "$second" ] \
  || fail "the second upload has no ref of its own"
! grep -q -- "-X PATCH" "$GH_DIR/calls" || fail "a ref was moved"
ok "a second upload at the same HEAD gets its own ref; the first upload's ref and links stay"
# The very same upload again (GitHub gives the same commit): its ref exists at that commit, which is fine.
(cd "$work/app" && "$script" "$work/shots/02-empty_state.png") >"$work/out.log" 2>&1 || { cat "$work/out.log"; fail "repeating an identical upload failed"; }
grep -q "^ASSETS: 1 image · $second · " "$work/out.log" || fail "repeating an identical upload: another commit"
ok "repeating an identical upload finds its ref already at that commit and succeeds"
echo 0000000000000000000000000000000000000000 >"$GH_DIR/store/refs/$(refkey "refs/devshop-assets/feat/cart/${head:0:12}-${second:0:12}")"
rc=0; (cd "$work/app" && "$script" "$work/shots/02-empty_state.png") >"$work/out.log" 2>&1 || rc=$?
if [ "$rc" != 2 ] || ! grep -q "reads back" "$work/out.log"; then
  cat "$work/out.log"; fail "an existing ref at another commit: expected exit 2 naming the read-back, got $rc"
fi
! grep -q '^!\[' "$work/out.log" || fail "an existing ref at another commit: image lines printed"
ok "a ref that already exists at another commit fails closed"

# --- A later commit on the branch (a fix round, or main merged in): a new upload for the new HEAD;
# the earlier ones keep their refs.
commit_file "$work/app" fix.txt "a fix"
head2=$(git -C "$work/app" rev-parse HEAD)
(cd "$work/app" && "$script" "$work/shots/01-add-item.png") >"$work/out.log" 2>&1 || { cat "$work/out.log"; fail "an upload after a new commit failed"; }
third=$(sed -nE 's/^ASSETS: 1 image · ([0-9a-f]{40}) · .*/\1/p' "$work/out.log")
names "refs/devshop-assets/feat/cart/${head2:0:12}-${third:0:12}"
jq -e --arg h "$head2" '.message | contains($h)' "$GH_DIR/store/$third" >/dev/null || fail "the new upload doesn't name the new HEAD"
[ "$(find "$GH_DIR/store/refs" -type f | wc -l)" = 3 ] || fail "earlier uploads' refs were not all kept"
ok "after a new commit the upload names the new HEAD, and every earlier upload keeps its ref"

# --- Refusals: bad input, a state ship can't trust, GitHub failing. Nothing printed as a success.
NAME="no files" run 2; names "usage"
NAME="a missing file" run 2 "$work/shots/nope.png"; names "nope.png"
printf 'just text' >"$work/shots/fake.png"
NAME="not really an image" run 2 "$work/shots/fake.png"; names "not a PNG, JPEG, GIF or WebP image"
cp "$work/shots/01-add-item.png" "$work/shots/shot.bmp"
NAME="an unsupported type" run 2 "$work/shots/shot.bmp"; names "png, jpg, jpeg, gif or webp"
cp "$work/shots/01-add-item.png" "$work/shots/with space.png"
NAME="a name a URL would mangle" run 2 "$work/shots/with space.png"; names "letters, digits"
mkdir -p "$work/other"; cp "$work/shots/01-add-item.png" "$work/other/"
NAME="two files with one name" run 2 "$work/shots/01-add-item.png" "$work/other/01-add-item.png"; names "twice"
python3 -c 'import sys; open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024))' "$work/shots/huge.png"
NAME="an image over 10 MB" run 2 "$work/shots/huge.png"; names "10 MB"
ok "bad input fails closed: no files, missing, not an image, wrong type, unsafe name, duplicate, too big"

echo change >>"$work/app/README.md"
NAME="uncommitted changes" run 2 "$work/shots/01-add-item.png"; names "uncommitted"
git -C "$work/app" checkout -q README.md
git -C "$work/app" checkout -q --detach
NAME="a detached HEAD" run 2 "$work/shots/01-add-item.png"; names "detached"
git -C "$work/app" checkout -q feat/cart
git -C "$work/app" remote set-url origin /srv/git/app
NAME="a non-GitHub origin" run 2 "$work/shots/01-add-item.png"; names "origin"
git -C "$work/app" remote set-url origin https://github.com/example/app.git
ok "a state the screenshots can't be tied to fails closed: uncommitted, detached, no GitHub origin"

for step in blobs trees commits get; do
  GH_FLAGS="fail-$step" NAME="gh failing at $step" run 2 "$work/shots/01-add-item.png"
  ! grep -q '^!\[' "$work/out.log" || fail "gh failing at $step: image lines printed"
  ! grep -q '^ASSETS:' "$work/out.log" || fail "gh failing at $step: ASSETS line printed"
done
GH_FLAGS="fail-refs" NAME="gh failing at the ref" run 2 "$work/shots/01-add-item.png"; names "ref"
GH_FLAGS="refuse-ref" NAME="GitHub refusing a ref outside refs/heads" run 2 "$work/shots/01-add-item.png"; names "fallback is a never-merged devshop-assets branch"
GH_FLAGS="bad-blob" NAME="a blob that comes back with another SHA" run 2 "$work/shots/01-add-item.png"; names "SHA"
GH_FLAGS="wrong-ref" NAME="the ref read back at another commit" run 2 "$work/shots/01-add-item.png"; names "reads back"
GH_FLAGS="wrong-tree" NAME="the tree read back with another file" run 2 "$work/shots/01-add-item.png"; names "tree reads back"
ok "GitHub failing or answering wrong fails closed, with no image line printed"

mkdir -p "$work/nogh"  # every tool on PATH but gh (CI runners keep gh in /usr/bin)
IFS=: read -ra dirs <<<"$PATH"
for d in "${dirs[@]}"; do
  for t in "$d"/*; do
    n=${t##*/}; [ "$n" = gh ] || [ -e "$work/nogh/$n" ] || [ ! -x "$t" ] || ln -s "$t" "$work/nogh/$n"
  done
done
PATH="$work/nogh" NAME="no gh" run 2 "$work/shots/01-add-item.png"; names "gh not found"
ok "a missing gh fails closed"
echo "PASS: pr-assets.sh"
