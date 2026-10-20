#!/usr/bin/env bash
# Tests runtime/scripts/project-files.py, the check of a project's copies of devshop files against
# a devshop version (W10.4.7, L-49), and the session-start line that reports their drift. A scratch
# devshop repo has four versions: v0 (no manifest), v1, v2 and v3 (each with runtime/project-files.txt;
# v3 adds an executable seed).
# `check` passes identical copies and ignores seeds; it fails a copy that differs, is missing, lost
# its executable bit (in the index or on disk) or is a symlink; it can't run on an unknown version,
# a bad manifest, a missing git or project. `plan` shows each delta; `apply` writes one devshop file
# and refuses the rest. `init` places every entry into a fresh repo, or writes nothing (AC-1, AC-2 of
# specs/new-project.md). A 4th field `optional` (specs/project-contract.md AC-6): `check` skips an
# absent optional copy and compares a present one, `init` doesn't place it, `plan` shows its state.
# Session start runs in a private mount namespace with a scratch /opt (L-41).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/runtime/scripts/project-files.py"
command -v python3 >/dev/null || fail "python3 not found"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
[ -f "$script" ] || fail "no runtime/scripts/project-files.py"

# --- A scratch devshop with three versions ---
ds="$work/devshop"
new_repo "$ds"
mkdir -p "$ds/scripts" "$ds/runtime/templates"
printf '#!/bin/sh\necho scan v0\n' >"$ds/scripts/scan.sh" && chmod +x "$ds/scripts/scan.sh"
git -C "$ds" add -A && git -C "$ds" commit -qm "v0: no manifest"
v0=$(git -C "$ds" rev-parse HEAD)
printf '#!/bin/sh\necho scan v1\n' >"$ds/scripts/scan.sh"
printf 'one\ntwo\n' >"$ds/runtime/templates/ci.yml"
printf 'old helper\n' >"$ds/runtime/templates/old.txt"
cat >"$ds/runtime/project-files.txt" <<'EOF'
# owner   devshop path               project path
devshop   scripts/scan.sh            scripts/scan.sh
seed      runtime/templates/ci.yml   .github/workflows/ci.yml
seed      runtime/templates/old.txt  old.txt
EOF
git -C "$ds" add -A && git -C "$ds" commit -qm "v1: manifest"
v1=$(git -C "$ds" rev-parse HEAD)
printf '#!/bin/sh\necho scan v2\n' >"$ds/scripts/scan.sh"
printf 'one\ntwo\nthree\n' >"$ds/runtime/templates/ci.yml"
git -C "$ds" add -A && git -C "$ds" commit -qm "Template gains a third line"
cat >"$ds/runtime/project-files.txt" <<'EOF'
devshop   scripts/scan.sh            scripts/scan.sh
seed      runtime/templates/ci.yml   .github/workflows/ci.yml
EOF
git -C "$ds" add -A && git -C "$ds" commit -qm "v2: drop old.txt"
v2=$(git -C "$ds" rev-parse HEAD)
dsgit="$ds/.git"

# new_project <dir> <version>: a project whose copies are the version's, and whose seed it adapted.
new_project() {
  new_repo "$1"
  mkdir -p "$1/scripts" "$1/.github/workflows"
  git -C "$ds" show "$2:scripts/scan.sh" >"$1/scripts/scan.sh" && chmod +x "$1/scripts/scan.sh"
  printf 'our own ci\n' >"$1/.github/workflows/ci.yml"
  printf 'our old.txt\n' >"$1/old.txt"
  git -C "$1" add -A && git -C "$1" commit -qm "copies"
}

# run <name> <want exit> <pattern the output must match, or ''> -- <args>
run() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  "$script" "$@" >"$work/out" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$pat" ] || grep -Eq -- "$pat" "$work/out" || { cat "$work/out" >&2; fail "$name: output lacks /$pat/"; }
  echo "ok - $name"
}
check() { local p=$1 v=$2; shift 2; run "$@" -- check --devshop-git "$dsgit" --version "$v" --project "$p"; }

# --- check ---
p="$work/p" && new_project "$p" "$v1"
check "$p" "$v1" "identical copies and adapted seeds pass" 0 ''
[ ! -s "$work/out" ] || { cat "$work/out" >&2; fail "a clean check printed something"; }
check "$p" "$v2" "a copy that differs from the version is drift, named" 1 '^scripts/scan\.sh: differs'
grep -q 'ci.yml' "$work/out" && fail "a seed was reported as drift"
echo "ok - a seed that differs is never drift"

printf 'edited\n' >>"$p/scripts/scan.sh"
check "$p" "$v1" "an edited copy is drift" 1 '^scripts/scan\.sh: differs'
git -C "$p" checkout -q -- scripts/scan.sh

chmod -x "$p/scripts/scan.sh"
check "$p" "$v1" "a copy that lost its executable bit on disk is drift" 1 '^scripts/scan\.sh: .*executable'
chmod +x "$p/scripts/scan.sh"
git -C "$p" update-index --chmod=-x scripts/scan.sh
check "$p" "$v1" "a copy committed without its executable bit is drift (what CI gets)" 1 '^scripts/scan\.sh: .*100644.*100755'
git -C "$p" update-index --chmod=+x scripts/scan.sh

mv "$p/scripts/scan.sh" "$work/scan.keep"
check "$p" "$v1" "a missing copy is drift" 1 '^scripts/scan\.sh: missing'
ln -s "$work/scan.keep" "$p/scripts/scan.sh"
check "$p" "$v1" "a symlink in place of a copy is drift" 1 '^scripts/scan\.sh: .*symlink'
rm "$p/scripts/scan.sh" && mv "$work/scan.keep" "$p/scripts/scan.sh"
check "$p" "$v1" "restored copy passes again" 0 ''

check "$p" "$v0" "a version without a manifest has nothing to check (exit 3)" 3 'no runtime/project-files\.txt'
check "$p" "0000000000000000000000000000000000000000" "a version not in the copy can't run" 2 'not in the devshop copy'
check "$p" "--all" "a version that is not a revision can't run" 2 ''
run "a missing devshop git dir can't run" 2 '' -- check --devshop-git "$work/nope.git" --version "$v1" --project "$p"
run "a missing project can't run" 2 '' -- check --devshop-git "$dsgit" --version "$v1" --project "$work/nope"
run "a missing argument can't run" 2 'usage' -- check --devshop-git "$dsgit" --project "$p"
run "an unknown command can't run" 2 'usage' -- sync --devshop-git "$dsgit" --version "$v1" --project "$p"
mkdir -p "$work/nogit" && ln -s "$(command -v python3)" "$work/nogit/python3"
rc=0 && PATH="$work/nogit" "$script" check --devshop-git "$dsgit" --version "$v1" --project "$p" >"$work/out" 2>&1 || rc=$?
[ "$rc" = 2 ] || { cat "$work/out" >&2; fail "no git on PATH: expected exit 2, got $rc"; }
echo "ok - no git can't run"

# bad_manifest <name> <pattern> <manifest text>: a version whose manifest is broken can't run.
bad_manifest() {
  local b="$work/bad-$RANDOM"
  git clone -q "$ds" "$b"
  printf '%s\n' "$3" >"$b/runtime/project-files.txt"
  git -C "$b" add -A && git -C "$b" commit -qm "bad manifest"
  run "$1" 2 "$2" -- check --devshop-git "$b/.git" --version HEAD --project "$p"
}
bad_manifest "a manifest with an unknown owner can't run" 'owner' 'locked scripts/scan.sh scripts/scan.sh'
bad_manifest "a manifest line with two fields can't run" 'fields' 'devshop scripts/scan.sh'
bad_manifest "an absolute project path can't run" 'path' 'devshop scripts/scan.sh /etc/passwd'
bad_manifest "a project path leaving the project can't run" 'path' 'devshop scripts/scan.sh ../x'
bad_manifest "a devshop path leaving the repo can't run" 'path' 'devshop ../x scripts/scan.sh'
bad_manifest "a './' path (one file, two spellings) can't run" 'path' 'devshop scripts/scan.sh ./scripts/scan.sh'
bad_manifest "a project path listed twice can't run" 'twice' "$(printf 'devshop scripts/scan.sh a\nseed scripts/scan.sh a')"
bad_manifest "a source the version lacks can't run" 'lacks' 'devshop scripts/nope.sh scripts/scan.sh'
bad_manifest "an empty manifest can't run" 'no entries' '# nothing'
bad_manifest "AC-6: a 4th field other than 'optional' can't run" "4th field" 'devshop scripts/scan.sh scripts/scan.sh maybe'
bad_manifest "AC-6: five fields can't run" 'fields' 'devshop scripts/scan.sh scripts/scan.sh optional x'
bad_manifest "AC-6: 'optional' on a seed can't run" 'devshop only' 'seed runtime/templates/ci.yml ci.yml optional'

# AC-6: an optional devshop copy (specs/project-contract.md): absent is fine, present is compared.
printf 'console.log("ui v4")\n' >"$ds/runtime/templates/ui.mjs"
cat >"$ds/runtime/project-files.txt" <<'EOF'
devshop   scripts/scan.sh             scripts/scan.sh
seed      runtime/templates/ci.yml    .github/workflows/ci.yml
devshop   runtime/templates/ui.mjs    scripts/ui/ui.mjs  optional
EOF
git -C "$ds" add -A && git -C "$ds" commit -qm "v4: an optional copy"
v4=$(git -C "$ds" rev-parse HEAD)
o="$work/o" && new_project "$o" "$v1" && git -C "$ds" show "$v4:scripts/scan.sh" >"$o/scripts/scan.sh"
check "$o" "$v4" "AC-6: an absent optional copy is not drift" 0 ''
mkdir -p "$o/scripts/ui" && printf 'console.log("edited")\n' >"$o/scripts/ui/ui.mjs"
check "$o" "$v4" "AC-6: a present optional copy that differs is drift" 1 '^scripts/ui/ui\.mjs: differs'
printf 'keep\n' >"$work/target"
rm "$o/scripts/ui/ui.mjs" && ln -s "$work/target" "$o/scripts/ui/ui.mjs"
check "$o" "$v4" "AC-6: a symlink where an optional copy would be is drift" 1 '^scripts/ui/ui\.mjs: .*symlink'
rm "$o/scripts/ui/ui.mjs"
run "AC-6: plan shows an absent optional copy as not there" 0 'scripts/ui/ui\.mjs \(devshop, optional.*doesn.t have it' \
  -- plan --devshop-git "$dsgit" --from "$v1" --to "$v4" --project "$o"
run "AC-6: apply writes an optional copy on request" 0 'scripts/ui/ui\.mjs: written' \
  -- apply --devshop-git "$dsgit" --version "$v4" --project "$o" --file scripts/ui/ui.mjs
check "$o" "$v4" "AC-6: after apply the optional copy matches" 0 ''
run "AC-6: plan shows a present optional copy's state" 0 'scripts/ui/ui\.mjs \(devshop, optional.*same as the new version' \
  -- plan --devshop-git "$dsgit" --from "$v1" --to "$v4" --project "$o"
git -C "$ds" tag v2.4.1 "$v4"
n="$work/n" && new_repo "$n"
run "AC-6: init doesn't place an optional copy" 0 'scripts/scan\.sh' -- init --devshop-git "$dsgit" --version v2.4.1 --project "$n" --codeowner a
[ ! -e "$n/scripts/ui/ui.mjs" ] || fail "AC-6: init placed an optional copy"
grep -q 'ui.mjs' "$work/out" && fail "AC-6: init listed an optional copy"
echo "ok - AC-6: init leaves optional copies to the project"
git -C "$ds" checkout -q "$v2" -- runtime/project-files.txt && git -C "$ds" rm -q --cached runtime/templates/ui.mjs && rm "$ds/runtime/templates/ui.mjs" \
  && git -C "$ds" commit -qm "back to v2's manifest" # the versions below build on v2's manifest

# --- plan ---
plan() { run "$@" -- plan --devshop-git "$dsgit" --from "$v1" --to "$v2" --project "$p"; }
plan "plan shows a devshop copy's diff to the new version" 0 '^\+echo scan v2$'
grep -q '^-echo scan v1$' "$work/out" || fail "plan: the copy's old line isn't shown removed"
grep -Eq '^== scripts/scan\.sh \(devshop' "$work/out" || fail "plan: no header for the devshop copy"
grep -q '^+three$' "$work/out" || fail "plan: the seed template's change isn't shown"
grep -q 'Template gains a third line' "$work/out" || fail "plan: the seed template's commits aren't shown"
grep -Eq 'old\.txt.*(removed|dropped)' "$work/out" || fail "plan: the entry dropped from the manifest isn't shown"
[ -f "$p/old.txt" ] || fail "plan deleted a project file"
[ "$(git -C "$p" status --porcelain)" = "" ] || fail "plan changed the project"
echo "ok - plan shows the template change and its commits, the dropped entry, and changes nothing"
run "plan from a version without a manifest says removals can't be listed" 0 'removals can.t be listed' \
  -- plan --devshop-git "$dsgit" --from "$v0" --to "$v2" --project "$p"
b="$work/bad-old" && git clone -q "$ds" "$b" && git -C "$b" checkout -q "$v1"
printf 'locked x y\n' >"$b/runtime/project-files.txt" && git -C "$b" commit -qam "a broken manifest"
run "plan from a version with a broken manifest still plans, saying removals can't be listed" 0 "removals can.t be listed: .*owner" \
  -- plan --devshop-git "$b/.git" --from HEAD --to "$v2" --project "$p"
run "plan to a version not in the copy stops and says to rebuild" 2 'rebuild' \
  -- plan --devshop-git "$dsgit" --from "$v1" --to 0000000000000000000000000000000000000000 --project "$p"
run "plan to a version without a manifest can't run" 2 'no runtime/project-files\.txt' \
  -- plan --devshop-git "$dsgit" --from "$v1" --to "$v0" --project "$p"

# --- apply ---
apply() { local f=$1; shift; run "$@" -- apply --devshop-git "$dsgit" --version "$v2" --project "$p" --file "$f"; }
chmod -x "$p/scripts/scan.sh"
apply scripts/scan.sh "apply writes a devshop copy" 0 ''
check "$p" "$v2" "after apply the copy matches the new version, executable bit included" 0 ''
apply .github/workflows/ci.yml "apply refuses a seed" 2 'seed'
[ "$(cat "$p/.github/workflows/ci.yml")" = "our own ci" ] || fail "apply changed a seed"
apply old.txt "apply refuses a path the manifest doesn't list" 2 'not in'
printf 'keep\n' >"$work/target"
rm "$p/scripts/scan.sh" && ln -s "$work/target" "$p/scripts/scan.sh"
apply scripts/scan.sh "apply refuses to write through a symlink" 2 'symlink'
[ "$(cat "$work/target")" = keep ] || fail "apply wrote through a symlink"
rm "$p/scripts/scan.sh" && rmdir "$p/scripts" && mkdir "$work/outside" && ln -s "$work/outside" "$p/scripts"
apply scripts/scan.sh "apply refuses a path whose directory leaves the project" 2 'leaves the project'
[ ! -e "$work/outside/scan.sh" ] || fail "apply wrote outside the project"

# --- init (specs/new-project.md) ---
# v3 adds an executable seed: init writes seeds with their git mode, as CI calls them directly.
printf '#!/bin/sh\necho slow\n' >"$ds/runtime/templates/check.sh" && chmod +x "$ds/runtime/templates/check.sh"
cat >"$ds/runtime/project-files.txt" <<'EOF'
devshop   scripts/scan.sh             scripts/scan.sh
seed      runtime/templates/ci.yml    .github/workflows/ci.yml
seed      runtime/templates/check.sh  scripts/check.sh
EOF
git -C "$ds" add -A && git -C "$ds" commit -qm "v3: an executable seed"
v3=$(git -C "$ds" rev-parse HEAD)
# init pins a release tag, never a SHA or a branch: v3 is released as v2.3.0, v0 as v0.1.0, and a
# branch named like a release is not one.
git -C "$ds" tag v2.3.0 "$v3" && git -C "$ds" tag -a -m "annotated" v2.3.1 "$v3" && git -C "$ds" tag v0.1.0 "$v0"
git -C "$ds" branch v2.4.0 "$v3"
for t in release-3 2.3.0 v2.3 v2.3.0-rc1 v02.3.0; do git -C "$ds" tag "$t" "$v3"; done # present, wrong shape
# init_into <name> <want exit> <pattern> <project> [args...]: init at v2.3.0.
init_into() {
  local name=$1 want=$2 pat=$3 proj=$4
  shift 4
  run "$name" "$want" "$pat" -- init --devshop-git "$dsgit" --version v2.3.0 --project "$proj" "$@"
}
# untouched <project>: init wrote nothing (the README commit only, nothing untracked).
untouched() {
  [ -z "$(git -C "$1" status --porcelain --untracked-files=all)" ] || { git -C "$1" status --short >&2; fail "init wrote into $1"; }
}
# same <version:path> <file>: the file is byte-identical to the version's.
same() { git -C "$ds" show "$1" >"$work/want" && cmp -s "$work/want" "$2"; }

i="$work/i" && new_repo "$i"
init_into "AC-1: init writes every entry, .devshop-version and CODEOWNERS" 0 'scripts/check\.sh' "$i" --codeowner example-owner
same "$v3:scripts/scan.sh" "$i/scripts/scan.sh" || fail "AC-1: the devshop copy isn't byte-identical"
same "$v3:runtime/templates/ci.yml" "$i/.github/workflows/ci.yml" || fail "AC-1: the seed isn't the template"
same "$v3:runtime/templates/check.sh" "$i/scripts/check.sh" || fail "AC-1: the executable seed isn't the template"
[ -x "$i/scripts/scan.sh" ] || fail "AC-1: the devshop copy lost its executable bit"
[ -x "$i/scripts/check.sh" ] || fail "AC-1: the executable seed lost its executable bit"
[ ! -x "$i/.github/workflows/ci.yml" ] || fail "AC-1: a 644 seed was written executable"
[ "$(cat "$i/.devshop-version")" = v2.3.0 ] || fail "AC-1: .devshop-version isn't the release tag"
[ "$(cat "$i/.github/CODEOWNERS")" = "* @example-owner" ] || fail "AC-1: CODEOWNERS isn't '* @example-owner'"
[ "$(cat "$i/README.md")" = hello ] || fail "AC-1: init changed the README"
echo "ok - AC-1: contents, modes, the pin, CODEOWNERS; the README left alone"
git -C "$i" add -A && git -C "$i" commit -qm "init"
check "$i" "$v3" "AC-1: after init, committed, check passes (modes in the index too)" 0 ''
j="$work/j" && new_repo "$j"
run "AC-1: init takes an annotated release tag" 0 '' \
  -- init --devshop-git "$dsgit" --version v2.3.1 --project "$j" --codeowner a
[ "$(cat "$j/.devshop-version")" = v2.3.1 ] || fail "AC-1: an annotated tag wasn't written as the tag"
same "$v3:scripts/scan.sh" "$j/scripts/scan.sh" || fail "AC-1: an annotated tag placed another version's files"
echo "ok - AC-1: an annotated tag is written as the tag, with its commit's files"

# AC-2: every refusal writes nothing.
printf 'keep\n' >"$work/target"
for t in scripts/scan.sh .github/workflows/ci.yml scripts/check.sh .devshop-version .github/CODEOWNERS; do
  for kind in file dir symlink; do
    r="$work/r-$RANDOM" && new_repo "$r" && mkdir -p "$r/$(dirname "$t")"
    case $kind in
      file) printf 'theirs\n' >"$r/$t" ;;
      dir) mkdir "$r/$t" && touch "$r/$t/x" ;;
      symlink) ln -s "$work/target" "$r/$t" ;;
    esac
    git -C "$r" add -A && git -C "$r" commit -qm "existing $t"
    init_into "AC-2: an existing $t ($kind) is refused" 2 "$t" "$r" --codeowner example-owner
    untouched "$r"
  done
done
[ "$(cat "$work/target")" = keep ] || fail "AC-2: init wrote through a symlink"
r="$work/r-$RANDOM" && new_repo "$r" && printf 'a file\n' >"$r/.github"
git -C "$r" add -A && git -C "$r" commit -qm "a file where a directory goes"
init_into "AC-2: a file where a target's directory goes is refused" 2 '\.github/workflows/ci\.yml: .*not a directory' "$r" --codeowner example-owner
untouched "$r"
r="$work/r-out" && new_repo "$r" && mkdir -p "$work/elsewhere" && ln -s "$work/elsewhere" "$r/scripts"
git -C "$r" add -A && git -C "$r" commit -qm "scripts is a link out"
init_into "AC-2: a target whose directory leaves the project is refused" 2 'leaves the project' "$r" --codeowner example-owner
untouched "$r"
[ -z "$(ls -A "$work/elsewhere")" ] || fail "AC-2: init wrote outside the project"
for h in "" "-lead" "trail-" "two--dashes" "under_score" "a@b" "@owner" "$(printf 'x%.0s' {1..40})" "a b"; do
  r="$work/r-$RANDOM" && new_repo "$r"
  init_into "AC-2: codeowner '$h' is refused" 2 'codeowner' "$r" --codeowner "$h"
  untouched "$r"
done
r="$work/r-$RANDOM" && new_repo "$r"
run "AC-2: a missing --codeowner is refused" 2 'codeowner' -- init --devshop-git "$dsgit" --version v2.3.0 --project "$r"
untouched "$r"
for v in "$v3" "${v3:0:12}" main release-3 2.3.0 v2.3 v2.3.0-rc1 v02.3.0; do
  run "AC-2: version '$v' (not a vX.Y.Z release tag) is refused" 2 'is not a release tag' \
    -- init --devshop-git "$dsgit" --version "$v" --project "$r" --codeowner a
done
run "AC-2: a branch named like a release is refused" 2 "release tag 'v2.4.0' is not in" \
  -- init --devshop-git "$dsgit" --version v2.4.0 --project "$r" --codeowner a
run "AC-2: an unknown release tag is refused" 2 'not in the devshop copy' \
  -- init --devshop-git "$dsgit" --version v9.9.9 --project "$r" --codeowner a
run "AC-2: a release with no manifest is refused" 2 'no runtime/project-files\.txt' \
  -- init --devshop-git "$dsgit" --version v0.1.0 --project "$r" --codeowner a
untouched "$r"
b="$work/bad-src" && git clone -q "$ds" "$b"
printf 'devshop scripts/scan.sh scripts/scan.sh\nseed runtime/templates/gone.yml x.yml\n' >"$b/runtime/project-files.txt"
git -C "$b" add -A && git -C "$b" commit -qm "a source the version lacks" && git -C "$b" tag v9.0.0
run "AC-2: a manifest source missing at the version is refused" 2 'lacks' \
  -- init --devshop-git "$b/.git" --version v9.0.0 --project "$r" --codeowner a
untouched "$r"
init_into "AC-2: an initialised project is refused whole" 2 '' "$i" --codeowner other
[ "$(cat "$i/.github/CODEOWNERS")" = "* @example-owner" ] || fail "AC-2: init rewrote an existing project"
untouched "$i"

# --- session start ---
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
git -C "$ds" tag v2.0.0 "$v1" # a release tag pins the same version as its SHA (AC-9)
git clone -q --bare "$ds" /opt/devshop.git
ln -s "$repo_root/runtime" /opt/devshop-current
start=/opt/devshop-current/hooks/session-start.sh
# start_lines <project>: the DEVSHOP: lines about the project's copies.
start_lines() { CLAUDE_PROJECT_DIR="$1" "$start" 2>&1 | grep -i 'copies' || true; }
s="$work/s" && new_project "$s" "$v1"
cp "$repo_root/runtime/templates/ci.yml" "$s/.github/workflows/ci.yml" # no CI line in the way
printf 'drifted\n' >>"$s/scripts/scan.sh"
[ -z "$(start_lines "$s")" ] || fail "session start reported drift without a .devshop-version"
echo "ok - without a pinned version session start says nothing about copies"
echo "$v1" >"$s/.devshop-version"
out=$(start_lines "$s")
grep -Eq "^DEVSHOP: the project's copies of devshop files differ from its pinned version ${v1:0:12}: scripts/scan\.sh \(differs" <<<"$out" \
  || { echo "$out" >&2; fail "session start: no drift line naming the copy"; }
[ "$(wc -l <<<"$out")" = 1 ] || { echo "$out" >&2; fail "session start: want one line"; }
echo "ok - with a pin, drift is one DEVSHOP: line naming the copy"
echo v2.0.0 >"$s/.devshop-version"
out=$(start_lines "$s")
grep -Eq "^DEVSHOP: the project's copies of devshop files differ from its pinned version v2\.0\.0: scripts/scan\.sh \(differs" <<<"$out" \
  || { echo "$out" >&2; fail "AC-9: session start: no drift line for a release tag pin"; }
echo "ok - AC-9: a release tag pin is checked as its version, and named in full"
echo "$v1" >"$s/.devshop-version"
git -C "$s" checkout -q -- scripts/scan.sh
[ -z "$(start_lines "$s")" ] || fail "session start reported clean copies"
echo "ok - clean copies get no line"
echo "$v0" >"$s/.devshop-version"
[ -z "$(start_lines "$s")" ] || fail "session start reported a pin without a manifest"
echo "ok - a pin older than the manifest gets no line"
echo 0000000000000000000000000000000000000000 >"$s/.devshop-version"
start_lines "$s" | grep -q "^DEVSHOP: couldn't check the project's copies of devshop files (exit 2)" \
  || fail "session start: a check that can't run isn't reported"
echo "ok - a check that can't run is reported"
