#!/usr/bin/env bash
# Tests the devshop's git hooks (runtime/git-hooks/) and the session-start step that points a
# project's core.hooksPath at them (runtime/hooks/session-start.sh). Real `git push` to a local bare
# remote, real gitleaks (the version CI pins). Hooks are feedback (`--no-verify` skips them); the
# wall is required CI. Runs in a private mount namespace with a scratch /opt, so the session's real
# /opt/devshop-current is never touched (L-41).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

if [ -z "${DEVSHOP_TEST_NS:-}" ]; then
  command -v unshare >/dev/null || fail "unshare not found (util-linux)"
  ns=(--mount)
  [ "$(id -u)" = 0 ] || ns+=(--map-root-user)
  DEVSHOP_TEST_NS=1 exec unshare "${ns[@]}" bash "$0" "$@"
fi
gitleaks_bin=$(command -v "${GITLEAKS:-gitleaks}") || fail "gitleaks not found (set \$GITLEAKS or put it on PATH)"
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
# The installed devshop: this checkout's runtime as the current version, the pinned tools in bin/.
ln -s "$repo_root/runtime" /opt/devshop-current
mkdir -p /opt/devshop-tools/bin && ln -s "$gitleaks_bin" /opt/devshop-tools/bin/gitleaks
start=/opt/devshop-current/hooks/session-start.sh
[ -x "$start" ] || fail "no runtime/hooks/session-start.sh"

# new_project <name>: a project clone with one pushed commit and a bare remote.
new_project() {
  git init -q --bare "$work/$1.git"
  git clone -q "$work/$1.git" "$work/$1" 2>/dev/null
  commit_file "$work/$1" README.md "hello"
  git -C "$work/$1" push -q origin HEAD:main 2>/dev/null
}
# push <project> [git push args]: push the current branch; prints the output, returns git's status.
push() { local p=$1; shift; git -C "$work/$p" push origin "HEAD:${PUSH_REF:-main}" "$@" 2>&1; }
expect_blocked() { # expect_blocked <case> <output> <status> <pattern the output must contain>
  [ "$3" != 0 ] || { echo "$2" >&2; fail "$1: push went through"; }
  grep -Eq "$4" <<<"$2" || { echo "$2" >&2; fail "$1: output lacks /$4/"; }
  echo "ok - $1"
}
expect_pushed() { # expect_pushed <case> <output> <status> [pattern]
  [ "$3" = 0 ] || { echo "$2" >&2; fail "$1: push was blocked"; }
  [ -z "${4:-}" ] || grep -Eq "$4" <<<"$2" || { echo "$2" >&2; fail "$1: output lacks /$4/"; }
  echo "ok - $1"
}

# Session start points the project's git at the devshop's hooks, remembering its own to chain to.
new_project p
CLAUDE_PROJECT_DIR="$work/p" "$start" >"$work/out" 2>&1 || { cat "$work/out" >&2; fail "session-start failed"; }
[ "$(git -C "$work/p" config core.hooksPath)" = /opt/devshop-current/git-hooks ] || fail "core.hooksPath not set"
[ "$(git -C "$work/p" config --get devshop.chainHooksPath || echo unset)" = "" ] || fail "chain path should be '' (git's default)"
CLAUDE_PROJECT_DIR="$work/p" "$start" >/dev/null 2>&1
[ "$(git -C "$work/p" config --get devshop.chainHooksPath)" = "" ] || fail "a second session start changed the chain path"
mkdir -p "$work/not-git"
CLAUDE_PROJECT_DIR="$work/not-git" "$start" || fail "session-start failed outside a git repo"
echo "ok - session start sets core.hooksPath, keeps the project's own path to chain to, is idempotent"

# A clean change pushes.
commit_file "$work/p" app.txt "nothing secret"
out=$(push p) && rc=0 || rc=$?
expect_pushed "clean commit pushes" "$out" "$rc" "no repo lint declared"

# A secret in a commit the push adds blocks it; the remote doesn't get it.
before=$(git -C "$work/p.git" rev-parse main)
commit_file "$work/p" keys.ini "aws_access_key_id = $(fake_aws_key)"
out=$(push p) && rc=0 || rc=$?
expect_blocked "secret in an unpushed commit blocks the push" "$out" "$rc" "leaks? found|gitleaks"
[ "$(git -C "$work/p.git" rev-parse main)" = "$before" ] || fail "the secret reached the remote"
# ...also when it was removed again in a later unpushed commit.
git -C "$work/p" rm -q keys.ini && git -C "$work/p" commit -qm "remove keys"
out=$(push p) && rc=0 || rc=$?
expect_blocked "secret added then removed before the push still blocks" "$out" "$rc" "leaks? found|gitleaks"
# ...and on a new branch (no remote ref yet): everything not on the remote is scanned.
out=$(PUSH_REF=feature push p) && rc=0 || rc=$?
expect_blocked "secret on a new branch blocks the push" "$out" "$rc" "leaks? found|gitleaks"
# --no-verify skips the hooks: they are feedback, not a wall (required CI is the wall).
out=$(PUSH_REF=bypass push p --no-verify) && rc=0 || rc=$?
expect_pushed "--no-verify bypasses the hook (feedback, not a wall)" "$out" "$rc"

# Only the commits a push adds are scanned: history already on the remote doesn't block new pushes.
new_project q
commit_file "$work/q" old.ini "aws_access_key_id = $(fake_aws_key)"
git -C "$work/q" push -q origin HEAD:main 2>/dev/null
CLAUDE_PROJECT_DIR="$work/q" "$start" >/dev/null
commit_file "$work/q" app.txt "clean"
out=$(push q) && rc=0 || rc=$?
expect_pushed "a secret already on the remote doesn't block a clean push" "$out" "$rc"

# No gitleaks: the push stops and says why (a missing tool never passes).
rm /opt/devshop-tools/bin/gitleaks
commit_file "$work/q" more.txt "clean"
out=$(push q) && rc=0 || rc=$?
expect_blocked "missing gitleaks blocks the push" "$out" "$rc" "gitleaks not found"
ln -s "$gitleaks_bin" /opt/devshop-tools/bin/gitleaks

# The repo's own lint (scripts/lint.sh <base>) runs: 1 = findings and 2 = couldn't run both block.
mkdir -p "$work/q/scripts"
# shellcheck disable=SC2016  # the fake lint.sh's source
printf '#!/usr/bin/env bash\necho "$1" >"$(git rev-parse --git-dir)/lint-base"\nexit "$(cat .lint-rc)"\n' >"$work/q/scripts/lint.sh"
chmod +x "$work/q/scripts/lint.sh"
for rc_want in 1 2 0; do
  echo "$rc_want" >"$work/q/.lint-rc"
  commit_file "$work/q" lint-case.txt "case $rc_want"
  remote_before=$(git -C "$work/q.git" rev-parse main)
  out=$(push q) && rc=0 || rc=$?
  case $rc_want in
    1) expect_blocked "repo lint findings block the push" "$out" "$rc" "scripts/lint.sh found problems" ;;
    2) expect_blocked "repo lint that can't run blocks the push" "$out" "$rc" "scripts/lint.sh couldn't run" ;;
    0) expect_pushed "clean repo lint lets the push through" "$out" "$rc" ;;
  esac
  [ "$(cat "$work/q/.git/lint-base")" = "$remote_before" ] || fail "lint.sh got base '$(cat "$work/q/.git/lint-base")', want the remote's $remote_before"
done

# The project's own hooks still run, chained after the devshop's: from its old core.hooksPath...
new_project h
mkdir -p "$work/h/.hooks"
# shellcheck disable=SC2016  # the project hook's source
printf '#!/usr/bin/env bash\necho "project pre-commit ran" >"$(git rev-parse --git-dir)/pc-ran"\n' >"$work/h/.hooks/pre-commit"
printf '#!/usr/bin/env bash\necho "project pre-push says no" >&2\nexit 1\n' >"$work/h/.hooks/pre-push"
chmod +x "$work/h/.hooks/pre-commit" "$work/h/.hooks/pre-push"
git -C "$work/h" config core.hooksPath .hooks
CLAUDE_PROJECT_DIR="$work/h" "$start" >/dev/null
[ "$(git -C "$work/h" config devshop.chainHooksPath)" = .hooks ] || fail "the project's own core.hooksPath wasn't kept to chain to"
commit_file "$work/h" a.txt "a"
[ -f "$work/h/.git/pc-ran" ] || fail "the project's own pre-commit didn't run"
out=$(push h) && rc=0 || rc=$?
expect_blocked "the project's own pre-push still runs and can stop the push" "$out" "$rc" "project pre-push says no"
# ...but never hook scripts the project committed without configuring them in this clone: git never
# runs committed hooks, so checking out an untrusted branch must not run its .husky/* (security review).
new_project k
mkdir -p "$work/k/.husky"
printf 'echo "unconfigured husky hook ran" >&2\nexit 3\n' >"$work/k/.husky/pre-push"
# shellcheck disable=SC2016  # the committed hook's source
printf 'echo "unconfigured husky hook ran" >"$(git rev-parse --git-dir)/pco-ran"\n' >"$work/k/.husky/post-checkout"
CLAUDE_PROJECT_DIR="$work/k" "$start" >/dev/null
git -C "$work/k" add -A && git -C "$work/k" commit -qm "husky files" && git -C "$work/k" checkout -q -b other
[ ! -e "$work/k/.git/pco-ran" ] || fail "a committed, unconfigured .husky/post-checkout ran on checkout"
out=$(push k) && rc=0 || rc=$?
expect_pushed "committed but unconfigured .husky hooks never run" "$out" "$rc"
grep -q "unconfigured husky hook ran" <<<"$out" && fail "an unconfigured .husky/pre-push ran"
# ...and once the project configures husky (core.hooksPath .husky, as before the session), it runs.
new_project m
mkdir -p "$work/m/.husky"
printf '#!/usr/bin/env sh\necho "husky pre-push ran"\nexit 3\n' >"$work/m/.husky/pre-push"
chmod +x "$work/m/.husky/pre-push"
git -C "$work/m" config core.hooksPath .husky
CLAUDE_PROJECT_DIR="$work/m" "$start" >/dev/null
commit_file "$work/m" b.txt "b"
out=$(push m) && rc=0 || rc=$?
expect_blocked "a configured husky pre-push is chained" "$out" "$rc" "husky pre-push ran"

echo "all git hook scenarios passed"
