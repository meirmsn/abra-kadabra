#!/usr/bin/env bash
# Tests runtime/scripts/project-files.py, the check of a project's copies of devshop files against
# a devshop version (W10.4.7, L-49), and the session-start line that reports their drift. A scratch
# devshop repo has three versions: v0 (no manifest), v1 and v2 (each with runtime/project-files.txt).
# `check` passes identical copies and ignores seeds; it fails a copy that differs, is missing, lost
# its executable bit (in the index or on disk) or is a symlink; it can't run on an unknown version,
# a bad manifest, a missing git or project. `plan` shows each delta; `apply` writes one devshop file
# and refuses the rest. Session start runs in a private mount namespace with a scratch /opt (L-41).
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

# --- session start ---
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"
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
