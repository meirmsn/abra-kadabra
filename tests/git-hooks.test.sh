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
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# In a devshop session the gitleaks on PATH lives under /opt, which the scratch /opt hides: copy it.
cp "$(readlink -f "$gitleaks_bin")" "$work/gitleaks" || fail "can't copy $gitleaks_bin"
gitleaks_bin=$work/gitleaks
mount -t tmpfs devshop-test-opt /opt || fail "can't mount a scratch /opt"

isolate_git "$work"
# The installed devshop: this checkout's runtime as the current version, the pinned tools in bin/.
ln -s "$repo_root/runtime" /opt/devshop-current
mkdir -p /opt/devshop-tools/bin && ln -s "$gitleaks_bin" /opt/devshop-tools/bin/gitleaks
start=/opt/devshop-current/hooks/session-start.sh
[ -x "$start" ] || fail "no runtime/hooks/session-start.sh"

# new_project <name>: a project clone with one pushed commit and a bare remote; its CI is the
# devshop's two-tier template, so session start has nothing to say about it.
new_project() {
  git init -q --bare "$work/$1.git"
  git clone -q "$work/$1.git" "$work/$1" 2>/dev/null
  mkdir -p "$work/$1/.github/workflows"
  cp "$repo_root/runtime/templates/ci.yml" "$work/$1/.github/workflows/ci.yml"
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

# Session start runs the repo's declared setup (scripts/setup.sh, e.g. `npm ci`): silent when it
# works, a loud DEVSHOP: line when it fails; nothing when the repo declares none.
mkdir -p "$work/p/scripts"
# shellcheck disable=SC2016  # the fake setup.sh's source
printf '#!/usr/bin/env bash\necho ran >"$(git rev-parse --git-dir)/setup-ran"\n' >"$work/p/scripts/setup.sh"
chmod +x "$work/p/scripts/setup.sh"
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
{ [ -f "$work/p/.git/setup-ran" ] && [ -z "$out" ]; } || { echo "$out" >&2; fail "scripts/setup.sh didn't run silently"; }
printf '#!/usr/bin/env bash\necho "no network" >&2\nexit 7\n' >"$work/p/scripts/setup.sh"
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
grep -q "^DEVSHOP: the project's setup (scripts/setup.sh) failed (exit 7)" <<<"$out" || { echo "$out" >&2; fail "a failed setup wasn't reported"; }
rm -rf "$work/p/scripts"
echo "ok - session start runs the repo's scripts/setup.sh; a failure is a DEVSHOP: line"

# AC-3: session start checks the project's CI against the two-tier template: one DEVSHOP: line
# naming the template when there is no ci.yml, when it breaks a rule (named), or when the check
# can't run; nothing when it follows the template (the setup case above).
ci_line() { # ci_line <case> <grep -E pattern for its one DEVSHOP: line about CI>
  out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
  [ "$(grep -c '^DEVSHOP:.*templates/ci.yml' <<<"$out")" = 1 ] || { echo "$out" >&2; fail "AC-3: $1: want exactly one DEVSHOP: line about CI"; }
  grep -Eq "$2" <<<"$out" || { echo "$out" >&2; fail "AC-3: $1: the line doesn't match /$2/"; }
  echo "ok - AC-3: $1"
}
ci="$work/p/.github/workflows/ci.yml"
cp "$ci" "$work/ci.good"
rm "$ci"
# specs/project-contract.md AC-5: with neither the pin nor ci.yml, one line names the new-project skill.
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
[ "$(grep -c '^DEVSHOP:' <<<"$out")" = 1 ] || { echo "$out" >&2; fail "AC-5: neither pin nor ci.yml: want exactly one DEVSHOP: line"; }
grep -Eq "^DEVSHOP: no devshop files yet \(\.devshop-version, \.github/workflows/ci\.yml\): a new project is set up by /devshop:new-project$" <<<"$out" \
  || { echo "$out" >&2; fail "AC-5: the line doesn't name /devshop:new-project"; }
grep -Eq 'templates/ci\.yml|contract' <<<"$out" && { echo "$out" >&2; fail "AC-5: a new repo also hears about the CI template or the contract"; }
echo "ok - AC-5: a repo with neither the pin nor ci.yml gets one line naming /devshop:new-project"
sed '/^  slow:/,$d' "$work/ci.good" >"$ci"
ci_line "a ci.yml without the slow tier is reported, naming the rule" "^DEVSHOP: the project's CI doesn't follow the two tiers \(fast, slow\) of /opt/devshop-current/templates/ci\.yml: no job 'slow'$"
printf 'jobs: [unclosed\n' >"$ci"
ci_line "a ci.yml the check can't parse is reported as unchecked" "^DEVSHOP: couldn't check the project's CI against /opt/devshop-current/templates/ci\.yml \(exit 2\): .*can't parse"
cp "$work/ci.good" "$ci"
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
[ -z "$out" ] || { echo "$out" >&2; fail "AC-3: session start spoke up about a ci.yml that follows the template"; }
echo "ok - AC-3: a ci.yml that follows the template gets no line (and nothing about the contract without a pin)"

# specs/project-contract.md AC-5: in a pinned project, session start checks the project contract with
# the version's own copy (runtime/project-contract.txt here) and the stack homes' `supplies`. A fixture
# of its own: every required item of the real contract, built from this tree's manifest.
mkdir -p /opt/devshop-versions/stacks-test/stacks/cf /opt/devshop-versions/stacks-test/stacks/other
new_project c
c="$work/c"
mkdir -p "$c/scripts/ui" "$c/specs" "$c/.github"
grep -v '^#' "$repo_root/runtime/project-files.txt" | while read -r _ src dst optional; do
  [ -n "$src" ] && [ -z "$optional" ] || continue
  mkdir -p "$c/$(dirname "$dst")" && cp -p "$repo_root/$src" "$c/$dst"
done
echo v2.0.0 >"$c/.devshop-version"
echo "* @example-owner" >"$c/.github/CODEOWNERS"
touch "$c/specs/.gitkeep"
printf '#!/usr/bin/env bash\nexit 0\n' >"$c/scripts/setup.sh" && chmod +x "$c/scripts/setup.sh"
git -C "$c" add -A && git -C "$c" commit -qm "every required item"
contract_lines() { CLAUDE_PROJECT_DIR="$c" "$start" 2>&1 | grep -i 'contract' || true; }
out=$(contract_lines)
grep -q '^DEVSHOP:' <<<"$out" && { echo "$out" >&2; fail "AC-5: a project meeting the contract got a DEVSHOP: line"; }
grep -Eq '^contract: optional items this project doesn.t have: .*DESIGN\.md' <<<"$out" || { echo "$out" >&2; fail "AC-5: absent optional items aren't named on a plain line"; }
grep -q 'scripts/setup.sh' <<<"$out" && { echo "$out" >&2; fail "AC-5: a present optional item was named as absent"; }
[ "$(wc -l <<<"$out")" = 1 ] || { echo "$out" >&2; fail "AC-5: want one plain line about the contract"; }
echo "ok - AC-5: every required item present: no DEVSHOP: line, one plain line naming the absent optional items"
rm "$c/scripts/check-slow.sh" && chmod -x "$c/scripts/secret-scan.sh"
out=$(contract_lines)
[ "$(grep -c '^DEVSHOP:' <<<"$out")" = 1 ] || { echo "$out" >&2; fail "AC-5: want exactly one DEVSHOP: line about the contract"; }
grep -Eq "^DEVSHOP: the project doesn't meet the project contract: scripts/check-slow\.sh \(missing\); scripts/secret-scan\.sh \(is not executable" <<<"$out" \
  || { echo "$out" >&2; fail "AC-5: the line doesn't name each item and problem"; }
echo "ok - AC-5: a missing and a malformed required item are one DEVSHOP: line naming each"
git -C "$c" checkout -q -- scripts/check-slow.sh && chmod +x "$c/scripts/secret-scan.sh"
# Every optional item present: nothing at all about the contract.
for f in scripts/lint.sh scripts/lint-file.sh scripts/deploy.sh scripts/local-run.sh; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$c/$f" && chmod +x "$c/$f"
done
cp "$repo_root/runtime/templates/ui/tokens-check.mjs" "$repo_root/runtime/templates/ui/render-check.mjs" "$c/scripts/ui/"
mkdir -p "$c/docs" && for f in DESIGN.md ROADMAP.md FINDINGS.md docs/README.md; do echo "# $f" >"$c/$f"; done
out=$(contract_lines)
[ -z "$out" ] || { echo "$out" >&2; fail "AC-5: with every item present, session start still spoke about the contract"; }
echo "ok - AC-5: with every optional item present too, nothing about the contract"
# A stack home's supplies make its items required, when the stack applies; a home that doesn't apply
# changes nothing. A scratch version with two stack homes stands in for the runtime's.
rm /opt/devshop-current
v=/opt/devshop-versions/stacks-test
for d in hooks scripts templates project-contract.txt; do ln -s "$repo_root/runtime/$d" "$v/$d"; done
echo "# cf" >"$v/stacks/cf/README.md" && echo "wrangler.jsonc" >"$v/stacks/cf/detect" && printf 'scripts/local-run.sh\nDESIGN.md\n' >"$v/stacks/cf/supplies"
echo "# other" >"$v/stacks/other/README.md" && echo "other.toml" >"$v/stacks/other/detect" && echo "ROADMAP.md" >"$v/stacks/other/supplies"
ln -s "$v" /opt/devshop-current
rm "$c/scripts/local-run.sh" "$c/DESIGN.md" "$c/ROADMAP.md"
out=$(contract_lines)
grep -q '^DEVSHOP:' <<<"$out" && { echo "$out" >&2; fail "AC-5: a stack that doesn't apply made its items required"; }
echo "ok - AC-5: a stack home that doesn't apply changes nothing"
echo '{}' >"$c/wrangler.jsonc"
out=$(contract_lines)
grep -Eq "^DEVSHOP: the project doesn't meet the project contract: scripts/local-run\.sh \(missing \(a project on this stack has it\)\); DESIGN\.md \(missing" <<<"$out" \
  || { echo "$out" >&2; fail "AC-5: an applying stack's supplied items aren't required"; }
grep -q 'ROADMAP.md (missing' <<<"$out" && { echo "$out" >&2; fail "AC-5: the non-applying stack's item was required"; }
echo "ok - AC-5: an applying stack home's supplies are required, named as the stack's"
rm "$v/stacks/other/detect"
out=$(contract_lines)
grep -Eq "^DEVSHOP: couldn't check the project against the project contract \(exit 2\): the stack homes couldn't be read" <<<"$out" \
  || { echo "$out" >&2; fail "AC-5: a stack home that can't be judged isn't reported"; }
echo "ok - AC-5: stack-homes.sh exit 2 is one couldn't-check line"
echo "other.toml" >"$v/stacks/other/detect"
printf 'nope.txt\n' >"$v/stacks/cf/supplies"
out=$(contract_lines)
grep -Eq "^DEVSHOP: couldn't check the project against the project contract \(exit 2\): contract-check: .*not an optional item" <<<"$out" \
  || { echo "$out" >&2; fail "AC-5: a bad supplies file isn't reported"; }
echo "ok - AC-5: a supplies file naming a non-item is one couldn't-check line"
rm /opt/devshop-current && ln -s "$repo_root/runtime" /opt/devshop-current
rm "$c/wrangler.jsonc"

# The Bash guard fails closed, so a missing dcg blocks every Bash command: session start says so up
# front, when the installed plugin registers the guard. A plugin from before the guard: no line.
mkdir -p /opt/devshop-plugin/devshop/hooks
plugin_hooks=/opt/devshop-plugin/devshop/hooks/hooks.json
cp "$repo_root/install/plugin/devshop/hooks/hooks.json" "$plugin_hooks"
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
grep -q "^DEVSHOP: dcg is not installed .*every Bash command will be blocked" <<<"$out" || { echo "$out" >&2; fail "a missing dcg wasn't reported at session start"; }
out=$(CLAUDE_PROJECT_DIR="$work/not-git" "$start" 2>&1)
grep -q "^DEVSHOP: dcg is not installed" <<<"$out" || { echo "$out" >&2; fail "a missing dcg wasn't reported outside a git repo"; }
printf '#!/usr/bin/env bash\n' >"$work/dcg" && chmod +x "$work/dcg" && ln -s "$work/dcg" /opt/devshop-tools/bin/dcg
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
[ -z "$out" ] || { echo "$out" >&2; fail "session start spoke up with dcg installed"; }
rm /opt/devshop-tools/bin/dcg
jq 'del(.hooks.PreToolUse)' "$repo_root/install/plugin/devshop/hooks/hooks.json" >"$plugin_hooks"
out=$(CLAUDE_PROJECT_DIR="$work/p" "$start" 2>&1)
[ -z "$out" ] || { echo "$out" >&2; fail "a missing dcg was reported though the plugin registers no Bash guard"; }
rm -rf /opt/devshop-plugin
echo "ok - session start reports a missing dcg when the plugin's Bash guard would block every command"

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

# A new branch's lint base is where it leaves the remote, even without a refs/remotes/origin/HEAD
# (fresh cloud clones have none): an empty base would make history-wide checks scan everything.
git -C "$work/q" update-ref -d refs/remotes/origin/HEAD 2>/dev/null || true
main_tip=$(git -C "$work/q.git" rev-parse main)
git -C "$work/q" checkout -q -b topic
commit_file "$work/q" topic1.txt "one"
commit_file "$work/q" topic2.txt "two"
out=$(PUSH_REF=topic push q) && rc=0 || rc=$?
expect_pushed "a new branch pushes" "$out" "$rc"
[ "$(cat "$work/q/.git/lint-base")" = "$main_tip" ] || fail "new branch: lint.sh got base '$(cat "$work/q/.git/lint-base")', want where it leaves the remote ($main_tip)"
echo "ok - a new branch's lint base is where it leaves the remote (no origin/HEAD needed)"

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
