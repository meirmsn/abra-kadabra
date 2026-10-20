#!/usr/bin/env bash
# Tests runtime/scripts/contract-check.py and runtime/project-contract.txt (spec
# specs/project-contract.md): the one check of what a project must provide. A project holding every
# required item passes, naming the absent optional ones; each missing or malformed item fails,
# named; a contract or supplies file that can't be parsed can't run, never passes. The real
# contract, the manifest, the templates and the stack homes' `supplies` files agree.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/runtime/scripts/contract-check.py"
contract="$repo_root/runtime/project-contract.txt"
command -v python3 >/dev/null || fail "python3 not found"
[ -f "$script" ] || fail "no runtime/scripts/contract-check.py"
[ -f "$contract" ] || fail "no runtime/project-contract.txt"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# run <name> <want exit> <pattern the output must match, or ''> -- <args>
run() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  "$script" "$@" >"$work/out" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$pat" ] || grep -Eq -- "$pat" "$work/out" || { cat "$work/out" >&2; fail "$name: output lacks /$pat/"; }
  echo "ok - $name"
}
none() { # none <name> <pattern the output must not match>
  grep -Eq -- "$2" "$work/out" && { cat "$work/out" >&2; fail "$1: output has /$2/"; }
  true
}

# --- A small contract of our own, every check kind and both whens ---
cat >"$work/contract.txt" <<'EOF'
# A test contract.
item: .devshop-version
owner: project
when: required
check: version-pin
must: Pin one devshop version.
for: the dispatcher

item: scripts/check-fast.sh
owner: seed
when: required
check: executable
must: Run the fast tier.
for: CI's fast job

item: CLAUDE.md
owner: seed
when: required
check: file
must: Say how changes land.
for: build

item: specs/
owner: project
when: required
check: directory
must: Hold one spec per change.
for: the reviewer

item: scripts/local-run.sh
owner: project
when: optional
check: executable
must: Serve the site on 127.0.0.1:$PORT until stopped.
for: the reviewer's browser

item: DESIGN.md
owner: project
when: optional
check: file
must: Say what the design is.
for: the design review
EOF
c="$work/contract.txt"

# new_project <dir>: a git repo holding every required item of the test contract.
new_project() {
  new_repo "$1"
  mkdir -p "$1/scripts" "$1/specs"
  echo v2.0.0 >"$1/.devshop-version"
  printf '#!/bin/sh\nexit 0\n' >"$1/scripts/check-fast.sh" && chmod +x "$1/scripts/check-fast.sh"
  echo "# Rules" >"$1/CLAUDE.md"
  touch "$1/specs/.gitkeep"
  git -C "$1" add -A && git -C "$1" commit -qm "required items"
}
check() { local p=$1; shift; run "$@" -- --contract "$c" --project "$p"; }

p="$work/p" && new_project "$p"
check "$p" "AC-2: every required item present passes, absent optional items named" 0 '^absent \(optional\): scripts/local-run\.sh$'
grep -q '^absent (optional): DESIGN.md$' "$work/out" || fail "AC-2: DESIGN.md not named as absent"
[ "$(grep -vc '^absent (optional): ' "$work/out")" = 0 ] || { cat "$work/out" >&2; fail "AC-2: a clean project printed more than the absent list"; }
(cd "$p" && "$script" --contract "$c") >"$work/out" 2>&1 || fail "AC-2: the project defaults to the current directory"
echo "ok - AC-2: --project defaults to the current directory"

# Required file: missing, whitespace-only, a symlink, a directory.
mv "$p/CLAUDE.md" "$work/claude.keep"
check "$p" "AC-2: a missing required file fails, named" 1 '^CLAUDE\.md: missing'
printf ' \n\t\n' >"$p/CLAUDE.md"
check "$p" "AC-2: a whitespace-only required file fails" 1 '^CLAUDE\.md: .*empty'
rm "$p/CLAUDE.md" && ln -s "$work/claude.keep" "$p/CLAUDE.md"
check "$p" "AC-2: a symlink in place of a required file fails" 1 '^CLAUDE\.md: .*symlink'
rm "$p/CLAUDE.md" && mkdir "$p/CLAUDE.md"
check "$p" "AC-2: a directory in place of a required file fails" 1 '^CLAUDE\.md: .*not a regular file'
rmdir "$p/CLAUDE.md" && mv "$work/claude.keep" "$p/CLAUDE.md"
check "$p" "AC-2: restored, it passes again" 0 ''

# Required executable: the bit on disk, the committed mode.
chmod -x "$p/scripts/check-fast.sh"
check "$p" "AC-2: a required executable without its bit on disk fails" 1 '^scripts/check-fast\.sh: .*not executable'
chmod +x "$p/scripts/check-fast.sh"
git -C "$p" update-index --chmod=-x scripts/check-fast.sh
check "$p" "AC-2: a required executable tracked as 100644 fails (what CI gets)" 1 '^scripts/check-fast\.sh: .*100644'
mkdir -p "$work/nogit" && ln -s "$(command -v python3)" "$work/nogit/python3"
rc=0 && PATH="$work/nogit" "$script" --contract "$c" --project "$p" >"$work/out" 2>&1 || rc=$?
[ "$rc" = 0 ] || { cat "$work/out" >&2; fail "AC-2: with no git on PATH the disk bit should decide (exit 0), got $rc"; }
echo "ok - AC-2: with no git on PATH the disk bit decides"
git -C "$p" update-index --chmod=+x scripts/check-fast.sh
check "$p" "AC-2: restored mode passes" 0 ''

# Directory: a file or a symlink in its place.
rm -r "$p/specs" && touch "$p/specs"
check "$p" "AC-2: a file in place of a directory item fails" 1 '^specs/: .*not a directory'
rm "$p/specs" && mkdir "$work/specs-elsewhere" && ln -s "$work/specs-elsewhere" "$p/specs"
check "$p" "AC-2: a symlink in place of a directory item fails" 1 '^specs/: .*symlink'
rm "$p/specs" && mkdir "$p/specs"

# version-pin: a tag with whitespace passes; whitespace-only, two tokens, another word fail; a SHA passes.
printf '  v2.3.4\n\n' >"$p/.devshop-version"
check "$p" "AC-2: a release tag with surrounding whitespace passes" 0 ''
printf '%s\n' "$(printf 'a%.0s' {1..40})" >"$p/.devshop-version"
check "$p" "AC-2: a 40-hex SHA passes" 0 ''
printf '\n \n' >"$p/.devshop-version"
check "$p" "AC-2: a whitespace-only pin fails" 1 '^\.devshop-version: .*empty'
printf 'v2.0.0 v2.0.1\n' >"$p/.devshop-version"
check "$p" "AC-2: two tokens fail" 1 '^\.devshop-version: .*not a devshop version'
printf 'main\n' >"$p/.devshop-version"
check "$p" "AC-2: a branch name fails" 1 '^\.devshop-version: .*not a devshop version'
printf '%s\n' "$(printf 'a%.0s' {1..39})" >"$p/.devshop-version"
check "$p" "AC-2: 39 hex characters fail" 1 '^\.devshop-version: .*not a devshop version'
echo v2.0.0 >"$p/.devshop-version"

# Optional items: present but wrong fails; absent is not a problem; --supplies makes one required.
printf '#!/bin/sh\nexit 0\n' >"$p/scripts/local-run.sh"
check "$p" "AC-2: an optional executable present without its bit fails" 1 '^scripts/local-run\.sh: .*not executable'
none "AC-2: a present optional item is not listed as absent" 'absent \(optional\): scripts/local-run'
chmod +x "$p/scripts/local-run.sh"
check "$p" "AC-2: a present, right optional item passes" 0 ''
none "AC-2: a present optional item is not listed as absent" 'local-run'
rm "$p/scripts/local-run.sh"
printf '# what the stack gives\nscripts/local-run.sh\n' >"$work/supplies"
printf 'DESIGN.md\n' >"$work/supplies2"
run "AC-2: an optional item a stack supplies is required when absent" 1 '^scripts/local-run\.sh: missing.*stack' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies"
run "AC-2: the same item in two supplies files is one requirement" 1 '^scripts/local-run\.sh: missing' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies" --supplies "$work/supplies"
[ "$(grep -c 'local-run' "$work/out")" = 1 ] || { cat "$work/out" >&2; fail "AC-2: the item was reported twice"; }
run "AC-2: two supplies files add up" 1 '^DESIGN\.md: missing' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies" --supplies "$work/supplies2"
grep -q '^scripts/local-run.sh: missing' "$work/out" || fail "AC-2: the first supplies file was dropped"
check "$p" "AC-2: without --supplies the same project passes" 0 ''
printf 'CLAUDE.md\n' >"$work/supplies-req"
run "AC-2: a supplies file naming a required item can't run" 2 'not an optional item' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies-req"
printf 'scripts/nope.sh\n' >"$work/supplies-unknown"
run "AC-2: a supplies file naming an item not in the contract can't run" 2 'not an optional item' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies-unknown"
printf 'DESIGN.md/\n' >"$work/supplies-slash"
run "AC-2: a supplies line spelled with a trailing slash can't run" 2 'not an optional item' \
  -- --contract "$c" --project "$p" --supplies "$work/supplies-slash"
run "AC-2: a missing supplies file can't run" 2 "can't read" \
  -- --contract "$c" --project "$p" --supplies "$work/nope"

# --list prints every item with its fields; supplies show as required (stack).
run "AC-1: --list prints every item with owner, when, must and for" 0 '^scripts/local-run\.sh  project  optional$' \
  -- --contract "$c" --project "$p" --list
grep -q '^\.devshop-version  project  required$' "$work/out" || fail "--list lacks the pin's line"
grep -q 'must: Serve the site' "$work/out" || fail "--list lacks a must line"
grep -q "for: the reviewer's browser" "$work/out" || fail "--list lacks a for line"
[ "$(grep -c '^[^ ]' "$work/out")" = 6 ] || { cat "$work/out" >&2; fail "--list: want 6 item lines"; }
run "AC-1: --list shows a supplied item as required (stack)" 0 '^scripts/local-run\.sh  project  required \(stack\)$' \
  -- --contract "$c" --project "$p" --list --supplies "$work/supplies"

# --- Can't run: the contract itself ---
bad() { # bad <name> <pattern> <contract text>
  printf '%s\n' "$3" >"$work/bad.txt"
  run "AC-2: $1" 2 "$2" -- --contract "$work/bad.txt" --project "$p"
}
block='item: CLAUDE.md
owner: seed
when: required
check: file
must: Say how changes land.
for: build'
sub() { printf '%s' "${block/"$1"/"$2"}"; } # sub <text in block> <replacement>: the block with one change
run "AC-2: no contract can't run" 2 "can't read" -- --contract "$work/nope.txt" --project "$p"
bad "an unknown key can't run" 'unknown key' "$block
extra: nope"
bad "a missing key can't run" 'missing' "$(grep -v '^for:' <<<"$block")"
bad "a repeated key can't run" 'twice' "$block
must: again"
bad "an unknown owner can't run" 'owner' "$(sub 'owner: seed' 'owner: vendor')"
bad "an unknown when can't run" 'when' "$(sub 'when: required' 'when: sometimes')"
bad "an unknown check can't run" 'check' "$(sub 'check: file' 'check: exists')"
bad "a trailing slash with check: file can't run" 'directory' "$(sub 'item: CLAUDE.md' 'item: docs/')"
bad "check: directory without a trailing slash can't run" 'directory' "$(sub 'check: file' 'check: directory')"
bad "an absolute item can't run" 'path' "$(sub 'item: CLAUDE.md' 'item: /etc/passwd')"
bad "an item with ./ can't run" 'path' "$(sub 'item: CLAUDE.md' 'item: ./CLAUDE.md')"
bad "an item leaving the project can't run" 'path' "$(sub 'item: CLAUDE.md' 'item: ../CLAUDE.md')"
bad "an item listed twice can't run" 'twice' "$block

$block"
bad "a devshop path in a for line can't run" 'devshop path' "$(sub 'for: build' 'for: runtime/skills/build')"
bad "a devshop path in a must line can't run" 'devshop path' "$(sub 'must: Say how changes land.' 'must: As /opt/devshop-current/x says.')"
bad "a line that isn't key: value can't run" 'key: value' "$block
just words"
bad "an empty contract can't run" 'no items' '# nothing here'
printf 'item: CLAUDE.md\r\nowner: seed\r\nwhen: required\r\ncheck: file\r\nmust: x\r\nfor: y\r\n' >"$work/crlf.txt"
run "AC-2: CR line ends can't run" 2 'CR' -- --contract "$work/crlf.txt" --project "$p"
printf '\xef\xbb\xbf%s\n' "$block" >"$work/bom.txt"
run "AC-2: a BOM can't run" 2 'BOM' -- --contract "$work/bom.txt" --project "$p"
printf '%s\nextra: nope\n' "$block" >"$work/bad.txt"
run "AC-2: --list on a bad contract can't run" 2 'unknown key' -- --contract "$work/bad.txt" --project "$p" --list
run "a missing project can't run" 2 'project' -- --contract "$c" --project "$work/nope"
run "an unknown argument can't run" 2 'usage' -- --contract "$c" --project "$p" --verbose
run "a value-less --supplies can't run" 2 'usage' -- --contract "$c" --project "$p" --supplies

# --- The real contract (AC-1, AC-9, AC-10) ---
run "AC-1: the real contract parses and --list prints it" 0 '^scripts/contract-check\.py  devshop  required$' \
  -- --contract "$contract" --project "$p" --list
for want in .devshop-version .github/CODEOWNERS .github/workflows/ci.yml scripts/check-fast.sh scripts/check-slow.sh \
  scripts/secret-scan.sh scripts/spec-check.py scripts/pr-title-check.py scripts/contract-check.py \
  scripts/deploy-comment.mjs scripts/project-contract.txt .gitleaks.toml specs/ CLAUDE.md; do
  grep -q "^$want  [a-z]*  required$" "$work/out" || fail "AC-1: '$want' is not a required item of the real contract"
done
for want in scripts/setup.sh scripts/lint.sh scripts/lint-file.sh scripts/deploy.sh scripts/local-run.sh \
  scripts/ui/tokens-check.mjs scripts/ui/render-check.mjs DESIGN.md ROADMAP.md FINDINGS.md docs/README.md; do
  grep -q "^$want  [a-z]*  optional$" "$work/out" || fail "AC-1: '$want' is not an optional item of the real contract"
done
[ "$(grep -c '^[^ ]' "$work/out")" = 25 ] || { cat "$work/out" >&2; fail "AC-1: the real contract has $(grep -c '^[^ ]' "$work/out") items, want 25"; }
echo "ok - AC-1: the real contract has the 14 required and 11 optional items"
if grep -En '(^|[^A-Za-z])(runtime|install|kit)/|/opt/' "$contract"; then fail "AC-1: the real contract names a devshop path"; fi
echo "ok - AC-1: the real contract names no devshop path"

# AC-10: the contract, the manifest and the templates agree.
python3 - "$repo_root" "$script" <<'PY' || fail "AC-10: the contract, manifest and templates disagree (above)"
import importlib.util, os, re, subprocess, sys
root, script = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("cc", script)
cc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cc)
items = {i["item"]: i for i in cc.parse(open(os.path.join(root, "runtime/project-contract.txt"), "rb").read(), "contract")}
manifest = {}
for line in open(os.path.join(root, "runtime/project-files.txt")):
    line = line.split("#", 1)[0].split()
    if line:
        manifest[line[2]] = (line[0], line[1], line[3:] == ["optional"])
problems = []
for dst, (owner, src, optional) in manifest.items():
    if owner == "devshop":
        it = items.get(dst)
        if not it or it["owner"] != "devshop":
            problems.append(f"manifest devshop entry {dst} is not a contract item with owner devshop")
            continue
        mode = subprocess.run(["git", "-C", root, "ls-files", "-s", "--", src], capture_output=True, text=True).stdout.split()
        mode = mode[0] if mode else ("100755" if os.stat(os.path.join(root, src)).st_mode & 0o100 else "100644")  # untracked yet: the disk bit
        want = "executable" if mode == "100755" else "file"
        if it["check"] != want:
            problems.append(f"{dst}: source {src} has mode {mode} but the contract's check is {it['check']}")
        if (it["when"] == "optional") != optional:
            problems.append(f"{dst}: the contract says {it['when']}, the manifest {'optional' if optional else 'required'}")
for item, it in items.items():
    if it["owner"] in ("devshop", "seed"):
        m = manifest.get(item)
        if not m or m[0] != it["owner"]:
            problems.append(f"contract item {item} (owner {it['owner']}) is not in the manifest with that owner")
named = set()
for t in ("runtime/templates/ci.yml", "runtime/templates/check-fast.sh"):
    for line in open(os.path.join(root, t)):
        if line.strip().startswith("#"):
            continue
        named |= set(re.findall(r"scripts/[A-Za-z0-9_./-]+", line))
for name in sorted(named):
    if name not in items:
        problems.append(f"{name} is run by a template but is not a contract item")
for p in problems:
    print(p)
sys.exit(1 if problems else 0)
PY
echo "ok - AC-10: every manifest devshop entry, contract devshop/seed item and template script agree"

# AC-9: every stack home's supplies names only optional items of the real contract; Cloudflare's four.
for s in "$repo_root"/runtime/stacks/*/; do
  [ -f "$s/supplies" ] || continue
  run "AC-9: $(basename "$s")'s supplies parse against the real contract" 0 '' \
    -- --contract "$contract" --project "$p" --list --supplies "$s/supplies"
done
cf="$repo_root/runtime/stacks/cloudflare/supplies"
[ -f "$cf" ] || fail "AC-9: no runtime/stacks/cloudflare/supplies"
[ "$(grep -v '^#' "$cf" | grep -c .)" = 4 ] || fail "AC-9: the Cloudflare home supplies $(grep -v '^#' "$cf" | grep -c .) items, want 4"
for want in scripts/setup.sh scripts/deploy.sh scripts/local-run.sh scripts/ui/render-check.mjs; do
  grep -qx "$want" "$cf" || fail "AC-9: the Cloudflare home doesn't supply $want"
done
echo "ok - AC-9: the Cloudflare home supplies setup.sh, deploy.sh, local-run.sh and render-check.mjs"

echo "PASS: contract-check.py"
