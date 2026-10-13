#!/usr/bin/env bash
# Tests runtime/scripts/pr-assets.sh (W10.6.9d): it puts a PR's screenshots in one parentless commit S
# and moves the branch to a merge commit M whose files are exactly HEAD's and whose second parent is S.
# ship's ordinary push of the branch (the one push a cloud session's proxy allows) carries S to
# GitHub; the printed image lines link S by SHA, and pr-body-check.py accepts them. Nothing in the
# PR's files changes, so there is nothing to remove before the merge. It refuses a repo that allows
# merge commits or rebase merges (they would carry S into the default branch), and fails closed.
# Also walks the life of a PR on a local "GitHub": fix rounds, retakes, a squash merge, the branch
# deleted, a fresh clone. Runs against a stub `gh` that only reads the repo's merge settings.
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

# --- A stub gh: GET repos/example/app only. $GH_DIR/merge-allowed or rebase-allowed: that merge
# method is on; $GH_DIR/fail: the call fails; any write is a test failure.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_DIR/calls"
[ "$*" = "api repos/example/app" ] || { echo "stub gh: unexpected call: $*" >&2; exit 1; }
[ ! -f "$GH_DIR/fail" ] || { echo "HTTP 502" >&2; exit 1; }
m=false r=false
[ ! -f "$GH_DIR/merge-allowed" ] || m=true
[ ! -f "$GH_DIR/rebase-allowed" ] || r=true
jq -n --argjson m $m --argjson r $r '{allow_squash_merge: true, allow_merge_commit: $m, allow_rebase_merge: $r}'
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"
export GH_DIR="$work/gh"
mkdir -p "$GH_DIR"

# --- "GitHub": a bare repo with main; the project: a clone on branch feat/cart, origin github-style
# for the script, pushes going to the bare repo.
git init -q --bare "$work/remote.git"
new_repo "$work/app"
git -C "$work/app" remote add origin https://github.com/example/app.git
git -C "$work/app" remote set-url --push origin "$work/remote.git"
git -C "$work/app" push -q origin main
git -C "$work/app" checkout -qb feat/cart
commit_file "$work/app" cart.txt "the cart feature"
code=$(git -C "$work/app" rev-parse HEAD)

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

# run <want exit> <args...>: in the project; output in $work/out.log
run() {
  local want=$1 rc=0; shift
  rm -f "$GH_DIR"/{fail,merge-allowed,rebase-allowed}
  for f in ${GH_FLAGS-}; do touch "$GH_DIR/$f"; done
  (cd "$work/app" && "$script" "$@") >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "${NAME}: expected exit $want, got $rc"; }
}
names() { grep -qF -- "$1" "$work/out.log" || { cat "$work/out.log" >&2; fail "${NAME}: output doesn't name '$1'"; }; }
assets() { sed -nE 's/^ASSETS: [0-9]+ images? · ([0-9a-f]{40}) · .*/\1/p' "$work/out.log"; }
g() { git -C "$work/app" "$@"; }

# --- The happy path.
NAME="three images" run 0 "$work/shots/01-add-item.png" "$work/shots/02-empty_state.png" "$work/shots/03-error.jpg"
s=$(assets); [ -n "$s" ] || { cat "$work/out.log"; fail "no ASSETS line with the screenshots commit"; }
m=$(g rev-parse HEAD)
for want in "![add item](https://github.com/example/app/raw/$s/01-add-item.png)" \
  "![empty state](https://github.com/example/app/raw/$s/02-empty_state.png)" \
  "![error](https://github.com/example/app/raw/$s/03-error.jpg)"; do names "$want"; done
names "ASSETS: 3 images · $s · feat/cart at ${m:0:12}"
ok "prints one image line per file, linking the screenshots commit by SHA, and the ASSETS line"
[ "$(g rev-list --parents -n1 "$s" | wc -w)" = 1 ] || fail "the screenshots commit has parents"
[ "$(g ls-tree --name-only "$s" | tr '\n' ' ')" = "01-add-item.png 02-empty_state.png 03-error.jpg " ] \
  || fail "screenshots tree: $(g ls-tree --name-only "$s")"
for f in 01-add-item.png 02-empty_state.png 03-error.jpg; do
  g cat-file blob "$s:$f" | cmp -s - "$work/shots/$f" || fail "$f was not stored byte for byte"
done
g log -1 --format=%B "$s" | grep -qF "$code" || fail "the screenshots commit doesn't name the commit it shows"
ok "the screenshots commit is parentless, holds each image byte for byte and names the commit shown"
[ "$(g rev-list --parents -n1 HEAD)" = "$m $code $s" ] || fail "HEAD is not a merge of the code commit and the screenshots"
[ "$(g rev-parse "HEAD^{tree}")" = "$(g rev-parse "$code^{tree}")" ] || fail "the merge changes the PR's files"
[ "$(g diff main..HEAD --name-only)" = cart.txt ] || fail "the PR's diff gained files"
[ -z "$(g status --porcelain)" ] || fail "the worktree is not clean after the upload"
[ "$(g symbolic-ref --short HEAD)" = feat/cart ] || fail "HEAD left the branch"
ok "the branch moved to a merge of the code commit and the screenshots; the PR's files and diff are unchanged"
grep -q '^api repos/example/app$' "$GH_DIR/calls" || fail "the repo's merge settings were not read"
ok "it read the repo's merge settings (squash only), and wrote nothing to GitHub"
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

# --- A PR's life on the local "GitHub": ship pushes; a retake; a fix round; squash merge; the branch
# deleted; the PR's ref kept (as refs/pull/<n>/head is); a fresh clone.
g push -q origin feat/cart
git -C "$work/remote.git" cat-file -e "$s" || fail "the push did not carry the screenshots commit"
ok "an ordinary push of the branch carries the screenshots commit"
NAME="a retake at the same code" run 0 "$work/shots/02-empty_state.png"
s2=$(assets); [ -n "$s2" ] && [ "$s2" != "$s" ] || fail "a retake made no new screenshots commit"
[ "$(g rev-list --parents -n1 HEAD | cut -d' ' -f2-)" = "$m $s2" ] || fail "a retake doesn't build on the previous merge"
g merge-base --is-ancestor "$s" HEAD || fail "a retake dropped the earlier screenshots"
commit_file "$work/app" cart.txt "the cart feature, fixed"
NAME="after a fix commit" run 0 "$work/shots/01-add-item.png"
s3=$(assets)
g log -1 --format=%B "$s3" | grep -qF "$(g rev-parse HEAD^1)" || fail "the new screenshots don't name the fixed commit"
for x in "$s" "$s2" "$s3"; do g merge-base --is-ancestor "$x" HEAD || fail "screenshots $x left the branch"; done
[ "$(g diff main..HEAD --name-only)" = cart.txt ] || fail "the PR's diff gained files after rounds"
ok "retakes and fix rounds add screenshots; every earlier set stays on the branch, links included"
g push -q origin feat/cart
git -C "$work/remote.git" update-ref refs/pull/1/head "$(g rev-parse HEAD)"
tmp=$(mktemp -d "$work/squash.XXXX")
git clone -q "$work/remote.git" "$tmp/c"
git -C "$tmp/c" merge -q --squash origin/feat/cart >/dev/null
git -C "$tmp/c" commit -qm "The cart feature (#1)"
git -C "$tmp/c" push -q origin main
git -C "$work/remote.git" update-ref -d refs/heads/feat/cart
git -C "$work/remote.git" cat-file -e "$s" || fail "the screenshots are gone from GitHub after the merge"
git -C "$work/remote.git" merge-base --is-ancestor "$s" refs/pull/1/head || fail "refs/pull/1/head doesn't keep the screenshots"
git clone -q "file://$work/remote.git" "$tmp/fresh"  # file://: a real fetch, as from GitHub, not a copy of the store
[ "$(git -C "$tmp/fresh" ls-tree -r --name-only main | sort | tr '\n' ' ')" = "README.md cart.txt " ] \
  || fail "main has other files than the change: $(git -C "$tmp/fresh" ls-tree -r --name-only main)"
for x in "$s" "$s2" "$s3"; do
  ! git -C "$tmp/fresh" cat-file -e "$x" 2>/dev/null || fail "a fresh clone downloaded screenshots $x"
done
ok "after a squash merge and the branch deleted: main holds only the change, a fresh clone has no screenshots, and the PR's ref still keeps them"

# --- Signing: with commit.gpgsign on, both commits are signed like any other commit (git commit-tree
# alone ignores that setting, and GitHub would show them Unverified). A stub stands in for ssh-keygen.
cat >"$work/bin/fake-sign" <<'SIGNER'
#!/usr/bin/env bash
echo "$*" >>"$GH_DIR/signed"
for f; do :; done
printf -- '-----BEGIN SSH SIGNATURE-----\nZmFrZQ==\n-----END SSH SIGNATURE-----\n' >"$f.sig"
SIGNER
chmod +x "$work/bin/fake-sign"
touch "$work/signing-key"
g config commit.gpgsign true
g config gpg.format ssh
g config gpg.ssh.program "$work/bin/fake-sign"
g config user.signingkey "$work/signing-key"
NAME="signed commits" run 0 "$work/shots/01-add-item.png"
for c in "$(assets)" "$(g rev-parse HEAD)"; do
  g cat-file -p "$c" | grep -q '^gpgsig ' || fail "commit $c is not signed though commit.gpgsign is on"
done
g config --unset commit.gpgsign
ok "with commit.gpgsign on, both commits are signed"

# --- Refusals: the repo's merge settings, bad input, a state the screenshots can't be tied to.
git -C "$work/app" checkout -qb feat/two main
commit_file "$work/app" two.txt "two"
before=$(g rev-parse HEAD)
GH_FLAGS="merge-allowed" NAME="merge commits allowed" run 2 "$work/shots/01-add-item.png"; names "squash"
GH_FLAGS="rebase-allowed" NAME="rebase merges allowed" run 2 "$work/shots/01-add-item.png"; names "squash"
GH_FLAGS="fail" NAME="gh failing" run 2 "$work/shots/01-add-item.png"; names "merge settings"
[ "$(g rev-parse HEAD)" = "$before" ] || fail "a refused upload moved the branch"
ok "a repo whose merges could carry the screenshots into main, or unreadable settings, fails closed, branch untouched"
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
g checkout -q README.md
g checkout -q --detach
NAME="a detached HEAD" run 2 "$work/shots/01-add-item.png"; names "detached"
g checkout -q feat/two
g remote set-url origin /srv/git/app
NAME="a non-GitHub origin" run 2 "$work/shots/01-add-item.png"; names "origin"
g remote set-url origin https://github.com/example/app.git
[ "$(g rev-parse HEAD)" = "$before" ] || fail "a refused upload moved the branch"
ok "a state the screenshots can't be tied to fails closed: uncommitted, detached, no GitHub origin"

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
