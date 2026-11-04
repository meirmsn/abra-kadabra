#!/usr/bin/env bash
# Tests the skills eval's model tier without a model (specs/skills-eval.md): tests/skills-eval/grade.py
# on hand-written event streams (tests/fixtures/skills-eval/streams/, never real transcripts), and
# tests/skills-eval.sh with a fake `claude` on PATH, a throwaway devshop copy and a throwaway runtime
# link, so the real shared link is never moved. Every outcome is shown to fail on a known-bad input.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
for t in git jq python3; do command -v "$t" >/dev/null || fail "$t not found"; done
grade="$repo_root/tests/skills-eval/grade.py"
runner="$repo_root/tests/skills-eval.sh"
fx="$repo_root/tests/fixtures/skills-eval"
spec_check="$repo_root/runtime/scripts/spec-check.py"
sha=0123456789abcdef0123456789abcdef01234567 # the streams' commit

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# --- The grader.
# project <name> [<spec fixture>]: a repo whose base commit is the greeter app, with the spec (if
# any) written under specs/ after it, as a session would; echo its path.
project() {
  local p="$work/$1"
  mkdir -p "$p" && cp -r "$fx/greeter/." "$p/"
  git -C "$p" init -q && git -C "$p" add -A && git -C "$p" commit -qm "Initial commit"
  if [ -n "${2:-}" ]; then mkdir -p "$p/specs" && cp "$2" "$p/specs/shout-flag.md"; fi
  echo "$p"
}
# graded <name> <want exit> <want prefix> <stream> <repo> [case]
graded() {
  local rc=0 out
  out=$(python3 "$grade" grade --case "${6:-trigger}" --stream "$fx/streams/$4.jsonl" --sha "$sha" \
    --repo "$5" --base HEAD --spec-check "$spec_check") || rc=$?
  [ "$rc" = "$2" ] || fail "$1: want exit $2, got $rc: $out"
  [[ "$out" == "$3"* ]] || fail "$1: want '$3…', got: $out"
  echo "ok - $1"
}
good=$(project good "$fx/shout-flag.md")
graded "skills-eval AC-6: intent first, only a spec written, the spec passes: PASS" 0 "PASS intent loaded first" good "$good"
graded "skills-eval AC-7: a file written before intent is loaded: FAIL" 1 "FAIL /work/greeter/cli.js was written before devshop:intent" edit-first "$good"
graded "skills-eval AC-7: intent never loaded: FAIL" 1 "FAIL devshop:intent was never loaded" no-intent "$good"
edited=$(project edited "$fx/shout-flag.md")
echo '// shout' >>"$edited/cli.js"
graded "skills-eval AC-7: code changed before the go: FAIL, quoting the rule" 1 "FAIL changed outside specs/ before any go: cli.js (intent § 3" good "$edited"
untracked=$(project untracked "$fx/shout-flag.md")
echo 'notes' >"$untracked/NOTES.md"
graded "skills-eval AC-7: an untracked file outside specs/: FAIL" 1 "FAIL changed outside specs/ before any go: NOTES.md" good "$untracked"
graded "skills-eval AC-7: no spec written: FAIL" 1 "FAIL no spec written" good "$(project nospec)"
printf '# A spec\n\n**Go:** pending\n\n## Intent\n\nText.\n' >"$work/bad-spec.md"
graded "skills-eval AC-7: a spec that fails spec-check.py: FAIL" 1 "FAIL the spec fails spec-check.py" good "$(project badspec "$work/bad-spec.md")"
graded "skills-eval AC-8: the session ran another devshop commit: CNR" 2 "CNR the session ran devshop fedcba987654, not 0123456789ab" wrong-sha "$good"
graded "skills-eval AC-8: no init event: CNR" 2 "CNR no init event" no-init "$good"
graded "skills-eval AC-8: not JSON lines: CNR" 2 "CNR the stream isn't JSON lines" not-json "$good"
graded "skills-eval AC-8: a turn that didn't finish: CNR" 2 "CNR no result event" no-result "$good"
graded "skills-eval AC-8: an unknown case: CNR" 2 "CNR unknown case" good "$good" nope
out=$(python3 "$grade" facts --stream "$fx/streams/good.jsonl")
[ "$out" = "model=claude-example-1 cli=9.9.9 cost=0.71 time=118 refused=1" ] || fail "facts: got '$out'"
echo "ok - skills-eval AC-9: the facts read from the stream"

# --- The runner, with a fake claude.
# A devshop repo holding what the runner and project-files.py read, and its local copy with a release.
src="$work/devshop"
mkdir -p "$src/scripts" "$src/install/plugin/devshop/upgrade"
cp -r "$repo_root/runtime" "$src/"
cp "$repo_root/scripts/secret-scan.sh" "$repo_root/scripts/pr-title-check.py" "$src/scripts/"
cp "$repo_root/install/plugin/devshop/upgrade/latest-release.sh" "$src/install/plugin/devshop/upgrade/"
git -C "$src" init -q && git -C "$src" add -A && git -C "$src" commit -qm "devshop"
git clone -q --bare "$src" "$work/devshop.git" && git --git-dir="$work/devshop.git" tag v9.9.9 HEAD
src_sha=$(git -C "$src" rev-parse HEAD)
mkdir -p "$work/opt/orig" "$work/opt/other" "$work/bin"
ln -sfn "$work/opt/orig" "$work/opt/current"
# The fake claude: records its arguments and environment, re-points the link as the plugin's hook
# does (F-NEW-144), writes what $STUB_MODE says, and prints the matching stream with the pin's SHA.
cat >"$work/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_LOG.args"
compgen -e >"$STUB_LOG.env"
touch "$STUB_LOG.called"
ln -sfn "$STUB_OTHER" "$DEVSHOP_CURRENT"
pin=$(cat .devshop-version)
stream=good
case $STUB_MODE in
  good) mkdir -p specs && cp "$STUB_FX/shout-flag.md" specs/shout-flag.md ;;
  edit) echo '// shout' >>cli.js; stream=edit-first ;;
  wrong-sha) stream=wrong-sha ;;
  clobber) rm "$DEVSHOP_CURRENT" && mkdir "$DEVSHOP_CURRENT" ;;
esac
sed "s/0123456789abcdef0123456789abcdef01234567/$pin/g; s/(0123456789ab)/(${pin:0:12})/g" "$STUB_FX/streams/$stream.jsonl"
EOF
chmod +x "$work/bin/claude"
# run_eval <name> <want exit> <mode> [runner args...]: the runner on the throwaway copy and link.
run_eval() {
  local name=$1 want=$2 mode=$3 rc=0
  shift 3
  rm -f "$work/stub."*
  PATH="$work/bin:$PATH" SKILLS_EVAL_REPO="$src" DEVSHOP_GIT="$work/devshop.git" \
    DEVSHOP_CURRENT="$work/opt/current" SKILLS_EVAL_RECORD="$work/opt/record" STUB_LOG="$work/stub" \
    STUB_OTHER="$work/opt/other" STUB_FX="$fx" STUB_MODE=$mode \
    GH_TOKEN=x GITHUB_TOKEN=x GIT_ASKPASS=x GIT_CONFIG_COUNT=0 CLAUDE_CODE_SESSION_ID=x \
    CLAUDE_CODE_REMOTE_SESSION_ID=x ANTHROPIC_BASE_URL=x \
    "$runner" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: want exit $want, got $rc"; }
}
seen() { grep -qE -- "$2" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output lacks /$2/"; }; }
linked() { [ "$(readlink "$work/opt/current")" = "$work/opt/orig" ] || fail "$1: the link isn't back at orig"; }

run_eval "two good runs" 0 good 2
for i in 1 2; do
  seen "skills-eval AC-9: run $i's line" "^PASS trigger run $i sha=${src_sha:0:12} model=claude-example-1 cli=9.9.9 cost=\\\$0.71 time=118s refused=1 intent loaded first"
done
# shellcheck disable=SC2016 # a literal $ in the pattern
seen "skills-eval AC-9: the tally" '^tally: trigger: 2 pass, 0 fail, 0 could-not-run of 2; cost \$1.42$'
seen "skills-eval AC-11: the link line" "^link restored: $work/opt/orig$"
linked "skills-eval AC-11" && [ ! -e "$work/opt/record" ] || fail "skills-eval AC-11: the record is left behind"
echo "ok - skills-eval AC-9, AC-11: one line per run, the tally, the link restored after the child moved it"
for v in GH_TOKEN GITHUB_TOKEN GIT_ASKPASS GIT_CONFIG_COUNT CLAUDE_CODE_SESSION_ID CLAUDE_CODE_REMOTE_SESSION_ID; do
  ! grep -qx "$v" "$work/stub.env" || fail "skills-eval AC-10: the child got $v"
done
grep -qx ANTHROPIC_BASE_URL "$work/stub.env" || fail "skills-eval AC-10: the child lost ANTHROPIC_BASE_URL (auth must pass)"
grep -A1 -x -- --permission-mode "$work/stub.args" | grep -qx auto || fail "skills-eval AC-10: not permission mode auto"
echo "ok - skills-eval AC-10: session ties and GitHub credentials removed, auth kept, mode auto"

run_eval "a code edit" 1 edit
seen "skills-eval AC-9: a FAIL line" "^FAIL trigger run 1 sha=.* /work/greeter/cli.js was written before"
linked "skills-eval AC-9: after a FAIL"
echo "ok - skills-eval AC-9: a known-bad run fails (exit 1)"
run_eval "another commit's devshop" 2 wrong-sha
seen "skills-eval AC-9: a CNR line" "^CNR trigger run 1 .*the session ran devshop fedcba987654"
echo "ok - skills-eval AC-9: a run on the wrong version could not run (exit 2)"

ln -sfn "$work/opt/other" "$work/opt/current" && printf '%s\n' "$work/opt/orig" >"$work/opt/record"
run_eval "a crashed run's record" 0 good
seen "skills-eval AC-11: the stale record" "^restored the link a crashed run left: $work/opt/orig$"
linked "skills-eval AC-11: after a crashed run's record"
echo "ok - skills-eval AC-11: a crashed run's record is restored before the run"
run_eval "the link clobbered" 2 clobber
seen "skills-eval AC-11: the link not back" "^CNR the link $work/opt/current is not back"
[ -f "$work/opt/record" ] || fail "skills-eval AC-11: the record is gone though the link isn't back"
rm -rf "$work/opt/current" "$work/opt/record" && ln -sfn "$work/opt/orig" "$work/opt/current"
echo "ok - skills-eval AC-11: a link that isn't back fails and keeps the record"

run_eval "an unknown case" 2 good 1 nope
seen "skills-eval AC-12: unknown case" "^CNR nope: unknown case"
run_eval "a case name that leaves the cases dir" 2 good 1 ../trigger
seen "skills-eval AC-12: a path as a case" "a case name is lower-case"
[ ! -e "$work/stub.called" ] || fail "skills-eval AC-12: claude was called for an unknown case"
SKILLS_EVAL_REF=nope run_eval "a ref that isn't a commit" 2 good
seen "skills-eval AC-12: a bad ref" "'nope' is not a commit"
echo 'changed' >>"$src/runtime/skills/intent/SKILL.md"
run_eval "uncommitted runtime/" 2 good
seen "skills-eval AC-12: uncommitted runtime/" "runtime/ has changes HEAD lacks"
[ ! -e "$work/stub.called" ] || fail "skills-eval AC-12: claude was called with runtime/ uncommitted"
SKILLS_EVAL_REF=$src_sha run_eval "a named commit, tested as it is" 0 good
echo "ok - skills-eval AC-12: unknown case, bad ref and uncommitted runtime/ refused before any model call"
echo "all skills-eval scenarios passed"
