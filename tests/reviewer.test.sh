#!/usr/bin/env bash
# Tests runtime/reviewer/review.sh with a stub `claude` (no model calls, so it runs in CI): the
# locked-down call, the outcome rule (decided by the script, never the model), rounds → ask-owner,
# the verdict file, and could-not-run for every bad input (fails closed, L-09, L-12). The real
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
lenses='[{"lens":"tests","applies":true,"note":"ok"}]'
# out <acceptance json array> [<findings json array>]
out() { echo "{\"acceptance\":$1,\"findings\":${2:-[]},\"lenses\":$lenses,\"summary\":\"s\"}"; }
all_met="[$(ac AC-1 true),$(ac AC-2 true)]"

reply "$work/pass.json" "$(out "$all_met")"
reply "$work/unmet.json" "$(out "[$(ac AC-1 true),$(ac AC-2 false)]")"
reply "$work/medium.json" "$(out "$all_met" "[$(finding medium)]")"
reply "$work/unsure.json" "$(out "$all_met" "[$(finding unsure)]")"
reply "$work/low.json" "$(out "$all_met" "[$(finding low),$(finding low)]")"
reply "$work/missing-ac.json" "$(out "[$(ac AC-1 true)]")"
reply "$work/extra-ac.json" "$(out "[$(ac AC-1 true),$(ac AC-2 true),$(ac AC-3 true)]")"
reply "$work/bad-severity.json" "$(out "$all_met" "[$(finding critical)]")"
reply "$work/no-structured.json" "null"
jq '.is_error=true' "$work/pass.json" >"$work/is-error.json"
echo "I think it passes." >"$work/garbage.json"
: >"$work/empty.json"

# A project repo: base has the spec, the branch adds the change.
new_project() {
  local r=$1
  new_repo "$r"
  mkdir -p "$r/specs" "$r/src"
  printf '# Spec\n\nAcceptance:\n1. AC-1: one.\n2. AC-2: two.\n' >"$r/specs/x.md"
  git -C "$r" add -A && git -C "$r" commit -qm "spec"
  git -C "$r" checkout -qb feat/x
  commit_file "$r" src/x.js "export const x = 1;"
}
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
    jq -e --arg o "$3" '.format=="devshop-review/1" and .outcome==$o' "$verdict" >/dev/null || ok=0
    [ -z "${4:-}" ] || jq -e "$4" "$verdict" >/dev/null || ok=0
  elif [ -n "${4:-}" ]; then ok=0
  fi
  [ "$ok" = 1 ] || { echo "line: $line" >&2; cat "$work/err" >&2; [ -f "$verdict" ] && cat "$verdict" >&2; fail "$1: expected exit $2 / $3, got exit $rc"; }
  echo "ok - $1"
}

# --- The call is locked down, and nothing from the environment changes it.
r="$work/p1"; new_project "$r"
ANTHROPIC_MODEL=other-model CLAUDE_CODE_SUBAGENT_MODEL=other run "$r" pass --base main --spec specs/x.md
expect "honest change passes" 0 pass \
  '.round==1 and .blocking==0 and .low==0 and .spec=="specs/x.md" and .branch=="feat/x" and .reviewer.session_id=="stub-session" and .reviewer.model=="claude-sonnet-5-5" and (.acceptance|length)==2 and .reason==""'
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
grep -qF "specs/x.md" <<<"$args" && grep -qF "AC-1, AC-2" <<<"$args" || fail "prompt lacks the spec or its items"
[ "$(cat "$STUB_LOG.cwd")" != "$r" ] || fail "claude ran in the real worktree, not a throwaway clone"
echo "ok - call is locked down (flags, pinned model/tools/settings, throwaway clone)"

# --- The outcome rule: unmet item or any non-low finding fails; low findings are listed only.
change "$r"; run "$r" unmet --base main --spec specs/x.md
expect "unmet acceptance item fails" 1 fail '.blocking==1'
change "$r"; run "$r" medium --base main --spec specs/x.md
expect "medium finding fails" 1 fail '.blocking==1'
r="$work/p2"; new_project "$r"
run "$r" unsure --base main --spec specs/x.md
expect "unsure finding counts as medium" 1 fail '.blocking==1'
r="$work/p3"; new_project "$r"
run "$r" low --base main --spec specs/x.md
expect "low findings pass, listed" 0 pass '.blocking==0 and .low==2 and (.findings|length)==2'

# --- Rounds: distinct failing commits since the last pass; the third asks the owner.
r="$work/rounds"; new_project "$r"
run "$r" unmet --base main --spec specs/x.md; expect "round 1 fails" 1 fail '.round==1'
run "$r" unmet --base main --spec specs/x.md; expect "re-run on the same commit is not a new round" 1 fail '.round==1'
change "$r"; run "$r" unmet --base main --spec specs/x.md; expect "round 2 fails" 1 fail '.round==2'
change "$r"; run "$r" garbage --base main --spec specs/x.md; expect "could-not-run is not a round" 2 could-not-run
change "$r"; run "$r" unmet --base main --spec specs/x.md; expect "round 3 asks the owner" 3 ask-owner '.round==3 and .blocking==1'
change "$r"; run "$r" pass --base main --spec specs/x.md; expect "a pass ends the streak" 0 pass '.round==4'
change "$r"; run "$r" unmet --base main --spec specs/x.md; expect "after a pass, rounds restart" 1 fail '.round==1'
[ "$(ls "$r/.git/devshop/reviews/feat__x" | grep -c "^[0-9]\{3\}-")" = 7 ] || fail "one verdict file per run expected"

# --- Could-not-run: anything other than a well-formed, complete verdict, and every bad input.
r="$work/cnr"; new_project "$r"
for bad in garbage empty no-structured is-error missing-ac extra-ac bad-severity; do
  run "$r" "$bad" --base main --spec specs/x.md
  expect "reply '$bad' is could-not-run" 2 could-not-run '.reason!="" and .blocking==0'
done
STUB_ACT=exit run "$r" pass --base main --spec specs/x.md
expect "claude exiting non-zero is could-not-run" 2 could-not-run '.reason|test("exit")'
STUB_ACT=touch-real run "$r" pass --base main --spec specs/x.md
expect "a changed real worktree is could-not-run" 2 could-not-run '.reason|test("worktree")'
rm -f "$r/stray.txt"
(export PATH="/usr/bin:/bin"; run "$r" pass --base main --spec specs/x.md
  expect "no claude on PATH is could-not-run" 2 could-not-run '.reason|test("claude")')
sed -i 's/^TIMEOUT=.*/TIMEOUT=1/' "$work/reviewer/review.sh"
STUB_ACT=sleep run "$r" pass --base main --spec specs/x.md
expect "a timed-out review is could-not-run" 2 could-not-run '.reason|test("timed out")'
cp "$repo_root/runtime/reviewer/review.sh" "$work/reviewer/review.sh"

echo dirt >"$r/untracked.txt"; run "$r" pass --base main --spec specs/x.md
expect "uncommitted changes are could-not-run" 2 could-not-run '.reason|test("uncommitted")'
rm "$r/untracked.txt"
run "$r" pass --base no-such-ref --spec specs/x.md; expect "unknown base is could-not-run" 2 could-not-run
run "$r" pass --base main --spec specs/nope.md; expect "spec missing at HEAD is could-not-run" 2 could-not-run
commit_file "$r" specs/empty.md "no items here"
run "$r" pass --base main --spec specs/empty.md; expect "spec without AC items is could-not-run" 2 could-not-run
run "$r" pass --spec specs/x.md; expect "missing --base is could-not-run" 2 could-not-run
run "$r" pass --base main; expect "missing --spec is could-not-run" 2 could-not-run
run "$r" pass --base main --spec specs/x.md --model opus; expect "an extra flag is refused" 2 could-not-run
run "$work" pass --base main --spec specs/x.md; expect "outside a git repo is could-not-run" 2 could-not-run
echo "all reviewer tests passed"
