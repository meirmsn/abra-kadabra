#!/usr/bin/env bash
# Tests runtime/reviewer/review.sh with a stub `claude` (no model calls, so it runs in CI): the
# locked-down call, the outcome rule (decided by the script, never the model), rounds → ask-owner,
# the verdict file, the spec found from the diff (none → the PR's words or the commits; two or more →
# could-not-run), the PR's words (--pr) reaching the reviewer, and could-not-run for every bad input
# (fails closed, L-09, L-12). The real
# model on the planted and honest fixtures is tests/reviewer-live.sh (run in a session, not CI).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v jq >/dev/null || fail "jq not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# The harness runs a copy of the pinned reviewer directory; tests change only the copy (Verify 3).
cp -r "$repo_root/runtime/reviewer" "$work/reviewer"
reviewer="$work/reviewer/review.sh"

# Stub claude: records its arguments and cwd, checks it was given the change, then prints the
# reply in $STUB (a file holding claude's JSON output) or acts per $STUB_ACT.
mkdir -p "$work/bin"
cat >"$work/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_LOG.args"; pwd >"$STUB_LOG.cwd"
git diff --quiet base head 2>/dev/null; [ $? = 1 ] || { echo "stub: no base..head diff here" >&2; exit 9; }
case "${STUB_ACT:-}" in
  exit) echo "boom" >&2; exit 1 ;;
  sleep) sleep 30 ;;
  touch-real) echo x >"$REAL_REPO/stray.txt" ;;
esac
cat "$STUB"
EOF
chmod +x "$work/bin/claude"
export PATH="$work/bin:$PATH" STUB_LOG="$work/stub"

# reply <file> <structured_output json>: claude's --output-format json shape around it.
reply() {
  jq -n --argjson s "$2" '{type:"result",is_error:false,session_id:"stub-session",total_cost_usd:0.01,structured_output:$s}' >"$1"
}
ac() { jq -n --arg i "$1" --argjson m "$2" '{item:$i,met:$m,evidence:"test/slugify.test.js"}'; }
finding() { jq -n --arg s "$1" '{severity:$s,lens:"code",item:"",file:"src/slugify.js",what:"x",fix:"y"}'; }
# The pr lens row says whether the reply checked the PR's words (Review 5); it must match --pr.
lenses='[{"lens":"tests","applies":true,"note":"ok"},{"lens":"pr","applies":false,"note":"no PR words"}]'
lenses_pr='[{"lens":"tests","applies":true,"note":"ok"},{"lens":"pr","applies":true,"note":"checked"}]'
# out <acceptance json array> [<findings json array>] [<lenses json array>]
out() { echo "{\"acceptance\":$1,\"findings\":${2:-[]},\"lenses\":${3:-$lenses},\"summary\":\"s\"}"; }
all_met="[$(ac AC-1 true),$(ac AC-2 true)]"

reply "$work/pass.json" "$(out "$all_met")"
reply "$work/unmet.json" "$(out "[$(ac AC-1 true),$(ac AC-2 false)]")"
reply "$work/medium.json" "$(out "$all_met" "[$(finding medium)]")"
reply "$work/medium-other.json" "$(out "$all_met" "[$(jq -n '{severity:"medium",lens:"code",item:"",file:"src/other.js",what:"x",fix:"y"}')]")"
reply "$work/unsure.json" "$(out "$all_met" "[$(finding unsure)]")"
reply "$work/low.json" "$(out "$all_met" "[$(finding low),$(finding low)]")"
reply "$work/missing-ac.json" "$(out "[$(ac AC-1 true)]")"
reply "$work/extra-ac.json" "$(out "[$(ac AC-1 true),$(ac AC-2 true),$(ac AC-3 true)]")"
reply "$work/bad-severity.json" "$(out "$all_met" "[$(finding critical)]")"
reply "$work/no-structured.json" "null"
jq '.is_error=true' "$work/pass.json" >"$work/is-error.json"
echo "I think it passes." >"$work/garbage.json"
: >"$work/empty.json"
# Replies for changes with no spec, and for runs given the PR's words.
reply "$work/nospec-pass.json" "$(out "[]")"
reply "$work/nospec-high.json" "$(out "[]" "[$(jq -n '{severity:"high",lens:"intent",item:"",file:"src/x.js",what:"a feature without a spec",fix:"write the spec"}')]")"
reply "$work/pr-pass.json" "$(out "$all_met" "[]" "$lenses_pr")"
reply "$work/pr-nospec-pass.json" "$(out "[]" "[]" "$lenses_pr")"
reply "$work/pr-mismatch.json" "$(out "$all_met" "[$(jq -n '{severity:"medium",lens:"pr",item:"",file:"",what:"the body claims a test the diff lacks",fix:"fix the body"}')]" "$lenses_pr")"
reply "$work/two-pr-lens.json" "$(out "$all_met" "[]" '[{"lens":"pr","applies":true,"note":"x"},{"lens":"pr","applies":false,"note":"y"}]')"
reply "$work/no-pr-lens.json" "$(out "$all_met" "[]" '[{"lens":"tests","applies":true,"note":"ok"}]')"

spec_text='# Spec\n\nAcceptance:\n1. AC-1: one.\n2. AC-2: two.\n'
# new_project <repo> [<spec path>|-]: base is main; the branch adds the spec (default specs/x.md,
# "-" for none) and the change.
new_project() {
  local r=$1 spec=${2:-specs/x.md}
  new_repo "$r"
  mkdir -p "$r/specs" "$r/src"
  git -C "$r" checkout -qb feat/x
  if [ "$spec" != - ]; then
    mkdir -p "$r/$(dirname "$spec")"; printf %b "$spec_text" >"$r/$spec"
    git -C "$r" add -A && git -C "$r" commit -qm "spec"
  fi
  commit_file "$r" src/x.js "export const x = 1;"
}
# pr_words <file> <title> <body>: the --pr file a hook would write.
pr_words() { jq -n --arg t "$2" --arg b "$3" '{title:$t,body:$b}' >"$1"; }
# change <repo>: one more commit on the branch.
change() { commit_file "$1" src/x.js "export const x = $RANDOM$RANDOM;"; }

# run <repo> <reply> [args...]: run the reviewer from the repo, set $rc, $line and $verdict.
run() {
  local r=$1; export STUB=$work/$2.json REAL_REPO=$1; shift 2
  rc=0
  line=$(cd "$r" && "$reviewer" "$@" 2>"$work/err") || rc=$?
  verdict=$(echo "$line" | sed -n 's/.* · \([^ ]*\)$/\1/p')
}
# expect <name> <exit code> <outcome> [jq condition on the verdict]
expect() {
  local ok=1
  [ "$rc" = "$2" ] || ok=0
  [[ "$line" == "REVIEW: $3 · "* ]] || ok=0
  if [ -n "$verdict" ] && [ -f "$verdict" ]; then
    jq -e --arg o "$3" '.format=="devshop-review/2" and .outcome==$o' "$verdict" >/dev/null || ok=0
    [ -z "${4:-}" ] || jq -e "$4" "$verdict" >/dev/null || ok=0
  elif [ -n "${4:-}" ]; then ok=0
  fi
  [ "$ok" = 1 ] || { echo "line: $line" >&2; cat "$work/err" >&2; [ -f "$verdict" ] && cat "$verdict" >&2; fail "$1: expected exit $2 / $3, got exit $rc"; }
  echo "ok - $1"
}

# --- The call is locked down, and nothing from the environment changes it.
r="$work/p1"; new_project "$r"
ANTHROPIC_MODEL=other-model CLAUDE_CODE_SUBAGENT_MODEL=other run "$r" pass --base main
expect "honest change passes" 0 pass \
  '.round==1 and .blocking==0 and .low==0 and .spec=="specs/x.md" and .intent=="spec" and .pr==null and .branch=="feat/x" and .reviewer.session_id=="stub-session" and .reviewer.model=="claude-sonnet-5-5" and (.acceptance|length)==2 and .reason==""'
[ "$(jq -r .commit "$verdict")" = "$(git -C "$r" rev-parse HEAD)" ] || fail "verdict not tied to HEAD"
[ "$(jq -r .base "$verdict")" = "$(git -C "$r" rev-parse main)" ] || fail "verdict base is not the merge-base"
[[ "$line" =~ ^REVIEW:\ pass\ ·\ round\ 1\ ·\ 0\ blocking,\ 0\ low\ ·\ [0-9a-f]{12}\ ·\ /.+\.json$ ]] || fail "stdout line format: $line"
case "$verdict" in "$r/.git/devshop/reviews/feat__x/001-"*.json) ;; *) fail "verdict path: $verdict" ;; esac
[ "$(readlink -f "$r/.git/devshop/reviews/feat__x/latest.json")" = "$(readlink -f "$verdict")" ] || fail "latest.json"
[ -z "$(git -C "$r" status --porcelain)" ] || fail "the review dirtied the worktree"
args=$(cat "$STUB_LOG.args")
for want in -p --restricted --safe-mode --strict-mcp-config --no-session-persistence --disable-slash-commands; do
  grep -qxF -- "$want" <<<"$args" || fail "claude called without $want"
done
grep -A1 -xF -- --tools <<<"$args" | tail -1 | grep -qxF "Read,Grep,Glob,Bash" || fail "tools not pinned"
grep -A1 -xF -- --permission-mode <<<"$args" | tail -1 | grep -qxF dontAsk || fail "permission mode not dontAsk"
grep -A1 -xF -- --model <<<"$args" | tail -1 | grep -qxF claude-sonnet-5-5 || fail "model not pinned (env leaked?)"
grep -A1 -xF -- --settings <<<"$args" | tail -1 | grep -qxF "$work/reviewer/settings.json" || fail "settings not the pinned file"
grep -qF "specs/x.md" <<<"$args" || fail "prompt lacks the spec path"
grep -qF "AC-1, AC-2" <<<"$args" || fail "prompt lacks the spec's items"
grep -qF "No PR words were given. Report the \`pr\` lens with \`applies: false\`." <<<"$args" || fail "prompt lacks the no-PR-words line"
[ "$(cat "$STUB_LOG.cwd")" != "$r" ] || fail "claude ran in the real worktree, not a throwaway clone"
echo "ok - call is locked down (flags, pinned model/tools/settings, throwaway clone)"


# --- The outcome rule: unmet item or any non-low finding fails; low findings are listed only.
change "$r"; run "$r" unmet --base main
expect "unmet acceptance item fails" 1 fail '.blocking==1'
change "$r"; run "$r" medium --base main
expect "medium finding fails" 1 fail '.blocking==1'
r="$work/p2"; new_project "$r"
run "$r" unsure --base main
expect "unsure finding counts as medium" 1 fail '.blocking==1'
r="$work/p3"; new_project "$r"
run "$r" low --base main
expect "low findings pass, listed" 0 pass '.blocking==0 and .low==2 and (.findings|length)==2'

# --- Rounds: distinct failing commits since the last pass; the third asks the owner.
r="$work/rounds"; new_project "$r"
run "$r" unmet --base main; expect "round 1 fails" 1 fail '.round==1'
run "$r" unmet --base main; expect "re-run on the same commit is not a new round" 1 fail '.round==1'
change "$r"; run "$r" unmet --base main; expect "round 2 fails" 1 fail '.round==2'
change "$r"; run "$r" garbage --base main; expect "could-not-run is not a round" 2 could-not-run
change "$r"; run "$r" unmet --base main; expect "round 3 asks the owner" 3 ask-owner '.round==3 and .blocking==1'
change "$r"; run "$r" pass --base main; expect "a pass ends the streak" 0 pass '.round==4'
change "$r"; run "$r" unmet --base main; expect "after a pass, rounds restart" 1 fail '.round==1'

# A round counts only repeats of the previous failing commit's blocking items (W10.6.7, owner
# 2026-10-13): a new issue starts again at round 1; the 6th failing commit since a pass asks anyway.
rn="$work/rounds-new"; new_project "$rn"
run "$rn" medium --base main; expect "a finding: round 1" 1 fail '.round==1'
change "$rn"; run "$rn" medium --base main; expect "the same finding again: round 2" 1 fail '.round==2'
change "$rn"; run "$rn" medium-other --base main; expect "a new finding (another file): round 1" 1 fail '.round==1'
change "$rn"; run "$rn" garbage --base main; expect "could-not-run in between" 2 could-not-run
change "$rn"; run "$rn" unmet --base main; expect "an unmet item after a finding: round 1" 1 fail '.round==1'
change "$rn"; run "$rn" unmet --base main; expect "the same unmet item again: round 2" 1 fail '.round==2'
change "$rn"; run "$rn" medium --base main; expect "the 6th failing commit asks the owner, new issue or not" 3 ask-owner '.round==1'
change "$rn"; run "$rn" pass --base main; expect "a pass after the cap" 0 pass
change "$rn"; run "$rn" medium --base main; expect "after a pass, the cap restarts" 1 fail '.round==1'
[ "$(find "$r/.git/devshop/reviews/feat__x" -name '[0-9][0-9][0-9]-*.json' | wc -l)" = 7 ] || fail "one verdict file per run expected"

# --- Could-not-run: anything other than a well-formed, complete verdict, and every bad input.
r="$work/cnr"; new_project "$r"
for bad in garbage empty no-structured is-error missing-ac extra-ac bad-severity; do
  run "$r" "$bad" --base main
  expect "reply '$bad' is could-not-run" 2 could-not-run '.reason!="" and .blocking==0'
done
STUB_ACT="exit" run "$r" pass --base main
expect "claude exiting non-zero is could-not-run" 2 could-not-run '.reason|test("exit")'
STUB_ACT=touch-real run "$r" pass --base main
expect "a changed real worktree is could-not-run" 2 could-not-run '.reason|test("worktree")'
rm -f "$r/stray.txt"
(export PATH="/usr/bin:/bin"; run "$r" pass --base main
  expect "no claude on PATH is could-not-run" 2 could-not-run '.reason|test("claude")')
sed -i 's/^TIMEOUT=.*/TIMEOUT=1/' "$work/reviewer/review.sh"
STUB_ACT="sleep" run "$r" pass --base main
expect "a timed-out review is could-not-run" 2 could-not-run '.reason|test("timed out")'
cp "$repo_root/runtime/reviewer/review.sh" "$work/reviewer/review.sh"

echo dirt >"$r/untracked.txt"; run "$r" pass --base main
expect "uncommitted changes are could-not-run" 2 could-not-run '.reason|test("uncommitted")'
rm "$r/untracked.txt"
run "$r" pass --base no-such-ref; expect "unknown base is could-not-run" 2 could-not-run
run "$r" pass; expect "missing --base is could-not-run" 2 could-not-run
run "$r" pass --base main --spec specs/x.md; expect "--spec is no longer accepted" 2 could-not-run
grep -qF "unknown argument '--spec'" "$work/err" || fail "--spec not refused as an unknown argument"
run "$r" pass --base main --pr; expect "--pr without a value is could-not-run" 2 could-not-run
run "$r" pass --base main --model opus; expect "an extra flag is refused" 2 could-not-run
run "$work" pass --base main; expect "outside a git repo is could-not-run" 2 could-not-run

# --- The spec is found from the diff: the one specs/**.md the branch adds, changes or renames.
r="$work/s-amp"; new_project "$r" 'specs/a&b.md'
run "$r" pass --base main; expect "a spec path with & is found" 0 pass '.spec=="specs/a&b.md"'
grep -qF 'specs/a&b.md' "$STUB_LOG.args" || fail "spec path with & mangled in the prompt"
echo "ok - spec path reaches the prompt verbatim"
r="$work/s-nested"; new_project "$r" specs/area/y.md
run "$r" pass --base main; expect "a spec in a subfolder of specs/ is found" 0 pass '.spec=="specs/area/y.md"'
r="$work/s-two"; new_project "$r"
commit_file "$r" specs/other.md "AC-1: other."
run "$r" pass --base main; expect "two specs in the diff are could-not-run" 2 could-not-run '.reason|test("specs/other.md") and test("specs/x.md")'
r="$work/s-changed"; new_project "$r" -
mkdir -p "$r/specs"; git -C "$r" checkout -q main; printf %b "$spec_text" >"$r/specs/x.md"
git -C "$r" add -A && git -C "$r" commit -qm "spec on main"; git -C "$r" checkout -q feat/x
git -C "$r" merge -q --no-edit main
run "$r" nospec-pass --base main; expect "a spec only on the base is not the change's spec" 0 pass '.spec=="" and .intent=="commits"'
printf %b "$spec_text" "3. AC-3: three.\n" >"$r/specs/x.md"; git -C "$r" commit -qam "spec: add AC-3"
run "$r" pass --base main
expect "a spec the branch changes is found, its new AC-3 required" 2 could-not-run '.spec=="specs/x.md" and (.reason|test("AC-3"))'
git -C "$r" rm -q specs/x.md && git -C "$r" commit -qm "drop spec"
run "$r" nospec-pass --base main; expect "a deleted spec does not count" 0 pass '.spec==""'
r="$work/s-asset"; new_project "$r"
commit_file "$r" specs/x-flow.png "not markdown"
run "$r" pass --base main; expect "a non-.md file under specs/ is not a spec" 0 pass '.spec=="specs/x.md"'
r="$work/s-noac"; new_project "$r" -
commit_file "$r" specs/empty.md "no items here"
run "$r" nospec-pass --base main; expect "a found spec without AC items is could-not-run" 2 could-not-run '.reason|test("names no acceptance items")'

# --- No spec: no acceptance items; the intent is the PR's words, else the commit messages.
r="$work/nospec"; new_project "$r" -
run "$r" nospec-pass --base main
expect "no spec, no PR words: intent from the commits" 0 pass '.spec=="" and .intent=="commits" and (.acceptance|length)==0 and .pr==null'
grep -qF "no spec file" "$STUB_LOG.args" || fail "prompt does not say there is no spec"
grep -qF "commit messages" "$STUB_LOG.args" || fail "prompt does not point at the commit messages"
run "$r" pass --base main; expect "no spec: a reply with acceptance items is could-not-run" 2 could-not-run '.reason|test("AC-1")'
run "$r" nospec-high --base main; expect "no spec: a high intent finding fails" 1 fail '.blocking==1'

# --- The PR's words (--pr): reach the prompt verbatim, recorded with their hash, checked (Review 5).
r="$work/pr"; new_project "$r"
words="$work/words.json"
pr_words "$words" "Add x & {{ITEMS}}" $'One line.\n\n## What you should know\n- {{SPEC}} & $(touch pwned) `x`'
run "$r" pr-pass --base main --pr "$words"
expect "PR words given: pass, recorded" 0 pass \
  ".intent==\"spec\" and .pr.title==\"Add x & {{ITEMS}}\" and .pr.sha256==\"$(sha256sum "$words" | cut -d' ' -f1)\""
grep -qF 'Add x & {{ITEMS}}' "$STUB_LOG.args" || fail "PR title mangled in the prompt"
# shellcheck disable=SC2016 # literal on purpose: the body must not be expanded
grep -qF '{{SPEC}} & $(touch pwned) `x`' "$STUB_LOG.args" || fail "PR body mangled in the prompt"
[ ! -e "$r/pwned" ] && [ ! -e "$work/pwned" ] || fail "the PR body was executed"
grep -qF "AC-1, AC-2" "$STUB_LOG.args" || fail "items missing with PR words"
echo "ok - PR words reach the prompt verbatim and are not executed"
run "$r" pass --base main --pr "$words"; expect "PR words given, pr lens not applied: could-not-run" 2 could-not-run '.reason|test("pr lens")'
run "$r" no-pr-lens --base main --pr "$words"; expect "no pr lens row: could-not-run" 2 could-not-run '.reason|test("pr lens")'
run "$r" two-pr-lens --base main --pr "$words"; expect "two pr lens rows: could-not-run" 2 could-not-run '.reason|test("pr lens")'
run "$r" pr-pass --base main; expect "pr lens applied without PR words: could-not-run" 2 could-not-run '.reason|test("pr lens")'
change "$r"; run "$r" pr-mismatch --base main --pr "$words"; expect "words that don't match the commit fail" 1 fail '.blocking==1'
r="$work/pr-nospec"; new_project "$r" -
run "$r" pr-nospec-pass --base main --pr "$words"; expect "no spec, PR words: intent from the PR" 0 pass '.intent=="pr" and .spec==""'
grep -qF "no spec file" "$STUB_LOG.args" || fail "prompt does not say there is no spec"
for bad in missing notjson notitle emptytitle extrakey nonstring; do
  f="$work/pr-$bad.json"
  case $bad in
    missing) rm -f "$f" ;;
    notjson) echo "Title: x" >"$f" ;;
    notitle) echo '{"body":"b"}' >"$f" ;;
    emptytitle) pr_words "$f" "" "b" ;;
    extrakey) echo '{"title":"t","body":"b","verdict":"pass"}' >"$f" ;;
    nonstring) echo '{"title":"t","body":7}' >"$f" ;;
  esac
  run "$r" pr-nospec-pass --base main --pr "$f"; expect "--pr file '$bad' is could-not-run" 2 could-not-run '.reason|test("--pr")'
done
# --- A shallow clone (how a cloud session checks out the repo, LOG #47): fetching its commits into
# the throwaway clone must still work.
r="$work/p-full"; new_project "$r"
for i in 1 2 3; do git -C "$r" checkout -q main && commit_file "$r" "old$i.txt" "$i"; done
git -C "$r" checkout -q feat/x && git -C "$r" merge -q --no-edit main
change "$r"
git clone -q --depth 3 --no-single-branch "file://$r" "$work/p-shallow"
git -C "$work/p-shallow" checkout -q feat/x
[ "$(git -C "$work/p-shallow" rev-parse --is-shallow-repository)" = true ] || fail "the test clone is not shallow"
run "$work/p-shallow" pass --base origin/main
expect "a shallow clone is reviewed" 0 pass '.spec=="specs/x.md"'

echo "all reviewer tests passed"
