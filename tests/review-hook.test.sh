#!/usr/bin/env bash
# Tests the reviewer hook (W10.6.7): runtime/hooks/review-hook.py, run by the plugin's PreToolUse
# (`gate`) and PostToolUse (`post`) hooks. The gate runs the independent reviewer before a PR is
# created, before a push to a branch with an open PR, and before an edit of the PR's words; only a
# pass lets the call through. The post mode puts the verdict on the PR as a comment, re-reviewing the
# words if GitHub's copy differs from the reviewed one. Runs a copy of runtime/ with a stub
# review.sh (driven by $STUB/modes) and a stub `gh` (a fake PR store in $GH_DIR), against a local
# bare repo as origin. No network, no model.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v jq >/dev/null || fail "jq not found"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
ok() { echo "ok - $1"; }

# --- A copy of the runtime, with a stub review.sh in place of the real one.
mkdir -p "$work/dev"
cp -R "$repo_root/runtime/hooks" "$repo_root/runtime/reviewer" "$work/dev/"
hook="$work/dev/hooks/review-hook.py"
cat >"$work/dev/reviewer/review.sh" <<'EOF'
#!/usr/bin/env bash
# Stub reviewer: logs its arguments and the --pr file; acts out line n of $STUB/modes on call n
# (the last line after that): pass | fail | could-not-run | ask-owner | noline | twolines | mismatch | crash.
echo "$*" >>"$STUB/calls"
n=$(wc -l <"$STUB/calls")
pr=""
while [ $# -gt 0 ]; do case $1 in --pr) pr=$2; shift 2 ;; *) shift ;; esac; done
[ -z "$pr" ] || cp "$pr" "$STUB/words.$n"
mode=$(sed -n "${n}p" "$STUB/modes"); [ -n "$mode" ] || mode=$(tail -1 "$STUB/modes")
head=$(git rev-parse HEAD)
dir="$(git rev-parse --path-format=absolute --git-common-dir)/devshop/reviews/stub"
mkdir -p "$dir"; v="$dir/$n-${head:0:12}.json"
case $mode in
  pass) rc=0 ;; fail | mismatch) rc=1 ;; could-not-run) rc=2 ;; ask-owner) rc=3 ;;
  noline) echo "all good, trust me"; exit 0 ;;
  crash) echo "boom" >&2; exit 5 ;;
  twolines) rc=0 ;;
esac
outcome=$mode; case $mode in twolines | mismatch) outcome=pass ;; esac
sha=null; [ -z "$pr" ] || sha="\"$(sha256sum "$pr" | cut -c1-64)\""
findings='[]'; [ "$outcome" != fail ] && [ "$outcome" != ask-owner ] || findings='[{"severity":"high","lens":"tests","item":"","file":"src/x.js","what":"AC-2 has no test","fix":"add a test for AC-2"}]'
reason=""; [ "$outcome" != could-not-run ] || reason="two spec files"
jq -n --arg o "$outcome" --arg c "$head" --argjson f "$findings" --argjson sha "$sha" --arg r "$reason" '{
  format: "devshop-review/2", outcome: $o, round: 1, commit: $c, base: $c, branch: "feat/x", spec: "",
  intent: "pr", pr: (if $sha == null then null else {title: "t", sha256: $sha} end),
  reviewer: {devshop: "test", model: "stub", session_id: "s-1", cost_usd: 0},
  acceptance: [], findings: $f, blocking: ($f | length), low: 0,
  lenses: [{lens: "pr", applies: true, note: ""}], reason: $r, created: "2026-10-12T00:00:00Z"}' >"$v"
echo "REVIEW: $outcome · round 1 · $(jq .blocking "$v") blocking, 0 low · ${head:0:12} · $v"
[ "$mode" != twolines ] || echo "REVIEW: pass · round 1 · 0 blocking, 0 low · ${head:0:12} · $v"
exit $rc
EOF
chmod +x "$work/dev/reviewer/review.sh"

# --- A stub gh: GET repos/<slug>/pulls?head=<owner>:<branch>&state=open, GET repos/<slug>/pulls/<n>
# and POST repos/<slug>/issues/<n>/comments (--input -), over a store of PR files in $GH_DIR/prs.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_DIR/calls"
[ ! -f "$GH_DIR/fail" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }
[ ! -f "$GH_DIR/fail-post" ] || [[ "$*" != *"-X POST"* ]] || { echo "HTTP 403: comments refused" >&2; exit 1; }
[ "$1" = api ] || { echo "stub gh: only api" >&2; exit 1; }
shift; method=GET path=""
while [ $# -gt 0 ]; do case $1 in -X) method=$2; shift 2 ;; --input) shift 2 ;; *) path=$1; shift ;; esac; done
case "$method $path" in
  "GET repos/example/app/pulls?"*)
    # Parse the query as GitHub does: split on "&", then decode each value.
    q=$(python3 -c 'import sys, urllib.parse as u; q = u.parse_qs(sys.argv[1].split("?", 1)[1]); print(q.get("state", [""])[0], q.get("head", [""])[0])' "$path")
    [[ "$q" == "open example:"* ]] || { echo "stub gh: unexpected query $path" >&2; exit 1; }
    b=${q#open example:}
    cat "$GH_DIR"/prs/*.json 2>/dev/null | jq -s --arg b "$b" '[.[] | select(.state == "open" and .head.ref == $b)]' ;;
  "GET repos/example/app/pulls/"*) cat "$GH_DIR/prs/${path##*/}.json" ;;
  "POST repos/example/app/issues/"*"/comments")
    n=${path#repos/example/app/issues/}; n=${n%/comments}
    jq -c . >>"$GH_DIR/comments.$n"; echo '{"id": 1}' ;;
  *) echo "stub gh: unexpected $method $path" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"

# --- The project: main and a feature branch, pushed to a bare origin named like a GitHub repo.
git init -q --bare "$work/remote/example/app.git"
new_repo "$work/p"
git -C "$work/p" remote add origin "$work/remote/example/app.git"
git -C "$work/p" push -q origin main
git -C "$work/p" remote set-head origin main
git -C "$work/p" push -q origin main:release
git -C "$work/p" checkout -qb feat/x
commit_file "$work/p" x.txt "the change"
git -C "$work/p" push -q origin feat/x
head_sha() { git -C "$work/p" rev-parse HEAD; }

# reset_state [modes...]: fresh stub logs, no PRs, no comments, no pending verdict.
reset_state() {
  rm -rf "$work/stub" "$work/gh" "$work/p/.git/devshop"
  mkdir -p "$work/stub" "$work/gh/prs"
  printf '%s\n' "${@:-pass}" >"$work/stub/modes"
  : >"$work/stub/calls"; : >"$work/gh/calls"
}
# open_pr <n> <title> <body> [<head sha>]: the fake GitHub now has open PR n on feat/x.
open_pr() {
  jq -n --argjson n "$1" --arg t "$2" --arg b "$3" --arg s "${4:-$(head_sha)}" \
    '{number: $n, state: "open", title: $t, body: $b, head: {ref: "feat/x", sha: $s}, base: {ref: "main"}}' \
    >"$work/gh/prs/$1.json"
}
# run_hook <gate|post> <tool name> <tool input json> [PATH]: as Claude Code runs it; sets rc, err.
run_hook() {
  local input
  input=$(jq -nc --arg t "$2" --argjson i "$3" --arg cwd "$work/p" '{tool_name: $t, tool_input: $i, cwd: $cwd}')
  rc=0
  (cd "$work/p" && PATH=${4:-"$work/bin:$PATH"} STUB="$work/stub" GH_DIR="$work/gh" "$hook" "$1" <<<"$input") \
    >"$work/out" 2>"$work/err" || rc=$?
  err=$(cat "$work/err")
}
bash_call() { jq -nc --arg c "$1" '{command: $c}'; }
mcp_create() { jq -nc --arg t "$1" --arg b "$2" --arg h "${3:-feat/x}" '{owner: "example", repo: "app", title: $t, body: $b, head: $h, base: "main"}'; }
words_sha() { jq -nc --arg t "$1" --arg b "$2" '{title: $t, body: $b}' | "$repo_root/runtime/reviewer/pr-words.sh" | sha256sum | cut -c1-64; }
reviews() { wc -l <"$work/stub/calls" | tr -d ' '; }
posted() { [ -f "$work/gh/comments.$1" ] && wc -l <"$work/gh/comments.$1" | tr -d ' ' || echo 0; }
marker() { jq -r '.body | split("\n")[0]' "$work/gh/comments.$1" | sed -n "${2:-1}p" | sed -E 's/^<!-- devshop-review (.*) -->$/\1/'; }
blocked() { [ "$rc" = 2 ] || fail "$1: want exit 2 (blocked), got $rc: $err"; }
allowed() { [ "$rc" = 0 ] || fail "$1: want exit 0 (allowed), got $rc: $err"; }
MCP=mcp__github__create_pull_request

# --- The plugin registers the hook on the right tools, with room for a review's 15 minutes.
hooks_json="$repo_root/install/plugin/devshop/hooks/hooks.json"
pre=$(jq -er '.hooks.PreToolUse[0].matcher' "$hooks_json") || fail "the plugin registers no PreToolUse hook"
post=$(jq -er '.hooks.PostToolUse[] | select(.hooks[0].command | contains("review-hook")) | .matcher' "$hooks_json") \
  || fail "the plugin registers no PostToolUse review hook"
for t in Bash mcp__github__create_pull_request mcp__github__update_pull_request mcp__github__push_files \
  mcp__github__create_or_update_file mcp__github__delete_file mcp__github__update_pull_request_branch; do
  grep -Eqx "$pre" <<<"$t" || fail "PreToolUse matcher '$pre' misses $t"
done
for t in Bash mcp__github__create_pull_request mcp__github__update_pull_request; do
  grep -Eqx "$post" <<<"$t" || fail "PostToolUse matcher '$post' misses $t"
done
for t in Read mcp__github__get_file_contents mcp__github__list_pull_requests; do
  ! grep -Eqx "$pre" <<<"$t" || fail "PreToolUse matcher catches $t"
done
jq -e '[.hooks.PreToolUse[0].hooks[0].timeout, (.hooks.PostToolUse[] | select(.hooks[0].command | contains("review-hook")) | .hooks[0].timeout)] | all(. > 900)' \
  "$hooks_json" >/dev/null || fail "hook timeouts must exceed review.sh's 900 s"
ok "the plugin registers the gate and the post hook on the right tools, with a long timeout"

# The registered gate command when the pinned hook is missing: blocks calls it would review, not others.
pre_cmd=$(jq -er '.hooks.PreToolUse[0].hooks[0].command' "$hooks_json")
[[ "$pre_cmd" == *"/opt/devshop-current/hooks/review-hook.py"* ]] || fail "gate command doesn't run the pinned hook: $pre_cmd"
missing_cmd=${pre_cmd//\/opt\/devshop-current\/hooks\/review-hook.py/$work/nope/review-hook.py}
for input in "$(jq -nc '{tool_name: "Bash", tool_input: {command: "gh pr create -t x -b y"}}')" \
  "$(jq -nc '{tool_name: "Bash", tool_input: {command: "git push origin feat/x"}}')" \
  "$(jq -nc --argjson i "$(mcp_create t b)" '{tool_name: "mcp__github__create_pull_request", tool_input: $i}')"; do
  rc=0; bash -c "$missing_cmd" <<<"$input" >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || fail "missing hook let through: $input (exit $rc)"
done
rc=0; bash -c "$missing_cmd" <<<'{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "missing hook blocked an unrelated call (exit $rc)"
ok "a missing hook blocks every call it would review, and only those"

# --- Calls that aren't ours pass untouched, without a review or a GitHub call.
reset_state pass
for c in "ls -la" "git status" "echo 'gh pr create'" "git log --grep push" "gh pr view 5"; do
  run_hook gate Bash "$(bash_call "$c")"; allowed "unrelated: $c"
done
run_hook gate Read '{"file_path": "/etc/hosts"}'; allowed "Read"
# Heredoc bodies are text, not commands: quotes in them don't need to balance (LOG #47: "there's").
run_hook gate Bash "$(bash_call "cat >>notes.md <<'EOF'
there's no git push here, and gh pr create neither
EOF
python3 - <<EOF
print(\"it's fine\")
EOF")"; allowed "heredoc bodies with an apostrophe and the words git push"
run_hook gate Bash "$(bash_call "cat <<-EOF >x
	git push origin feat/x
	EOF")"; allowed "a <<- heredoc body"
[ "$(reviews)" = 0 ] && [ ! -s "$work/gh/calls" ] || fail "an unrelated call ran a review or gh"
ok "unrelated calls pass silently, with no review and no GitHub call, heredoc bodies included"
reset_state pass; open_pr 5 "Add x" "b" "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook gate Bash "$(bash_call "cat >n.md <<'EOF'
it's text
EOF
git push origin feat/x")"; allowed "a push after a heredoc"
[ "$(reviews)" = 1 ] || fail "a push after a heredoc was not reviewed"
reset_state pass; open_pr 5 "Add x" "b" "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook gate Bash "$(bash_call "cat <<-EOF >x
	it's text
	EOF
git push origin feat/x")"; allowed "a push after a <<- heredoc"
[ "$(reviews)" = 1 ] || fail "a push after a <<- heredoc was not reviewed"
reset_state pass; open_pr 5 "Add x" "b"
run_hook gate Bash "$(bash_call "echo 'unclosed
git push origin feat/x")"; blocked "a push the hook can't split from an unclosed quote"
ok "a push after a heredoc is still reviewed, and a push it can't split is blocked"

# --- 1. PR create with a failing review: blocked, findings returned, no verdict pending, nothing posted.
reset_state fail
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"
blocked "create with a failing review"
grep -q "^REVIEW: fail" <<<"$err" || fail "the REVIEW: line is not returned: $err"
{ grep -qF "AC-2 has no test" <<<"$err" && grep -qF "add a test for AC-2" <<<"$err"; } || fail "the finding and its fix are not returned: $err"
grep -qi "commit" <<<"$err" || fail "the block doesn't say to fix, commit and retry: $err"
[ ! -e "$work/p/.git/devshop/reviews/feat__x/pending.json" ] || fail "a failing review left a pending verdict"
! grep -q "POST" "$work/gh/calls" || fail "a failing create posted something"
ok "a create with a failing review is blocked with its findings, and nothing is posted"

# --- 2. PR create with a passing review: allowed; the reviewed words are the call's; the verdict lands.
reset_state pass
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.
Second line with \"quotes\" and ünïcode.")"
allowed "create with a passing review"
grep -qx -- "--base origin/main --pr .*" "$work/stub/calls" || fail "review.sh call: $(cat "$work/stub/calls")"
[ "$(cat "$work/stub/words.1")" = "$(jq -nc --arg t "Add x" --arg b "Adds x.
Second line with \"quotes\" and ünïcode." '{title: $t, body: $b}')" ] || fail "--pr file: $(cat "$work/stub/words.1")"
ok "the review gets the call's title and body, verbatim, and the PR's base"
open_pr 5 "Add x" "Adds x.
Second line with \"quotes\" and ünïcode."
run_hook post $MCP "$(mcp_create "Add x" "Adds x.
Second line with \"quotes\" and ünïcode.")"
allowed "post after create"
[ "$(posted 5)" = 1 ] || fail "want 1 comment on PR 5, got $(posted 5)"
m=$(marker 5)
[ "$(jq -r .commit <<<"$m")" = "$(head_sha)" ] && [ "$(jq -r .outcome <<<"$m")" = pass ] || fail "marker: $m"
[ "$(jq -r .words <<<"$m")" = "$(words_sha "Add x" "Adds x.
Second line with \"quotes\" and ünïcode.")" ] || fail "marker words hash: $m"
[ "$(reviews)" = 1 ] || fail "unchanged words were reviewed again"
[ ! -e "$work/p/.git/devshop/reviews/feat__x/pending.json" ] || fail "the pending verdict was not cleared"
jq -s '[.[] | {body}]' "$work/gh/comments.5" >"$work/list.json"
"$repo_root/runtime/reviewer/verdict-check.sh" --head "$(head_sha)" --comments "$work/list.json" \
  --words "$(words_sha "Add x" "Adds x.
Second line with \"quotes\" and ünïcode.")" >/dev/null || fail "verdict-check doesn't accept the posted comment"
ok "after the create, the verdict comment lands on the PR and the review-verdict check accepts it"

# --- gh pr create: words from --title/--body-file; flags in every form; base from --base.
reset_state pass
printf 'Body from a file.\n' >"$work/body.md"
run_hook gate Bash "$(bash_call "gh pr create --title='Add x' -F $work/body.md -Bmain --head feat/x")"
allowed "gh pr create with a passing review"
[ "$(cat "$work/stub/words.1")" = "$(jq -nc '{title: "Add x", body: "Body from a file.\n"}')" ] || fail "gh words: $(cat "$work/stub/words.1")"
reset_state pass
run_hook gate Bash "$(bash_call "gh pr create -t 'Add x' -b 'Short body'")"
allowed "gh pr create, short flags"
[ "$(jq -r .body "$work/stub/words.1")" = "Short body" ] || fail "gh -b: $(cat "$work/stub/words.1")"
grep -qx -- "--base origin/main --pr .*" "$work/stub/calls" || fail "default base: $(cat "$work/stub/calls")"
ok "gh pr create: words from its flags or body file, base from --base or origin's default branch"
for c in "gh pr create --fill" "gh pr create -t x --web" "gh pr create -b body-only" "gh pr create -t x -F -" \
  "gh pr create -t x -b y --template t.md" "gh pr create -t x -b y --frobnicate" "gh pr create -t x -b y --head other" \
  "gh pr create -t x -b y -R someone/else" "gh pr create -t 'unclosed"; do
  reset_state pass
  run_hook gate Bash "$(bash_call "$c")"
  blocked "words or target the gate can't know: $c"
  [ "$(reviews)" = 0 ] || fail "$c: reviewed anyway"
done
reset_state pass
run_hook gate $MCP "$(mcp_create "Add x" "b" "someone:other")"; blocked "MCP create for another branch"
run_hook gate $MCP "$(jq -nc '{owner: "someone", repo: "else", title: "t", body: "b", head: "feat/x", base: "main"}')"
blocked "MCP create in another repo"
for c in "gh pr create --fill" "gh pr create -t x --web" "gh pr create -t x -b y -T t.md"; do
  reset_state pass; run_hook gate Bash "$(bash_call "$c")"
  grep -qF "can't know the PR's words" <<<"$err" || fail "$c: doesn't say why: $err"
done
reset_state pass; run_hook gate Bash "$(bash_call "gh pr create -t x -F -")"
grep -qF "stdin" <<<"$err" || fail "--body-file -: doesn't say why: $err"
reset_state pass; run_hook gate Bash "$(bash_call "gh pr create -t x --frobnicate yes -b y")"; blocked "unknown flag with a value"
grep -qF "unknown flag --frobnicate" <<<"$err" || fail "unknown flag: $err"
reset_state pass; run_hook gate $MCP "$(mcp_create " " "b")"; blocked "MCP create with a blank title"
[ "$(reviews)" = 0 ] || fail "a blank title was reviewed"
ok "a create whose words, branch or repo the gate can't tie to this worktree is blocked as could-not-run"
# Words the shell would expand can't be known by the hook (the reviewer's finding, LOG #47).
for c in "gh pr create -t x --body \"\$(cat <<'EOF'
The real body.
EOF
)\"" "gh pr create -t x --body \"\$(cat $work/body.md)\"" "gh pr create -t \"\$TITLE\" -b y" \
  "gh pr create -t x -b \"see \${NOTE}\"" "gh pr create -t x -b \"\`cat f\`\"" "gh pr edit 5 --body \"\$(cat f)\"" \
  "gh pr create -t x --body \$(cat f)" "gh pr create -t x -b 'Costs \$5'"; do
  reset_state pass; open_pr 5 "Add x" "b"
  run_hook gate Bash "$(bash_call "$c")"; blocked "shell-expanded words: $c"
  grep -qF -- "--body-file" <<<"$err" || fail "$c: doesn't say to use --body-file: $err"
  [ "$(reviews)" = 0 ] || fail "$c: reviewed words the shell would change"
done
reset_state pass; run_hook gate Bash "$(bash_call "gh pr create -t 'Costs 5 USD' -b 'Plain words.'")"; allowed "plain quoted words"
ok "words the shell would expand (\$(…), backticks, \$VAR) are blocked: use --body-file"
reset_state pass
run_hook gate $MCP "$(jq -nc '{owner: "example", repo: "app", title: "t", body: "b", head: "feat/x", base: "release"}')"
allowed "create on another base"
grep -qx -- "--base origin/release --pr .*" "$work/stub/calls" || fail "base not passed: $(cat "$work/stub/calls")"
ok "the review's base is the PR's base"

# A create before the branch's HEAD is on origin: blocked, so the verdict is for the PR's head.
reset_state pass
commit_file "$work/p" y.txt "not pushed yet"
run_hook gate $MCP "$(mcp_create "Add x" "b")"; blocked "create with HEAD not pushed"
grep -qi "push" <<<"$err" || fail "the block doesn't say to push first: $err"
[ "$(reviews)" = 0 ] || fail "reviewed a commit the PR wouldn't have"
git -C "$work/p" push -q origin feat/x
ok "a create whose HEAD isn't on origin is blocked: push first"

# More than one reviewed operation in one Bash call: could-not-run.
reset_state pass
run_hook gate Bash "$(bash_call "git push origin feat/x && gh pr create -t x -b y")"; blocked "push and create in one call"
grep -q "separate" <<<"$err" || fail "doesn't say to run them separately: $err"
for c in "cd $work/p && gh pr create -t x -b y" "cd $work/p; git push origin feat/x" "pushd $work/p && git push"; do
  reset_state pass; open_pr 5 "Add x" "b"
  run_hook gate Bash "$(bash_call "$c")"; blocked "a cd before a reviewed operation: $c"
  grep -q "separate" <<<"$err" || fail "$c: doesn't say to run them separately: $err"
done
reset_state pass; run_hook gate Bash "$(bash_call "cd $work/p && ls")"; allowed "a cd with nothing reviewed"
for c in "git --git-dir $work/p/.git push origin feat/x" "git --work-tree=$work/p push" "git --namespace n push"; do
  reset_state pass; open_pr 5 "Add x" "b"
  run_hook gate Bash "$(bash_call "$c")"; blocked "a push with git-dir options: $c"
  grep -q "git -C" <<<"$err" || fail "$c: doesn't say to use git -C: $err"
done
ok "a push and a create in one Bash call, or after a cd, are blocked: run them separately; --git-dir pushes are refused"

# --- 3. A push to a branch with an open PR is reviewed against the PR's current words.
reset_state fail
open_pr 5 "Add x" "PR body on GitHub" "$(git -C "$work/p" rev-parse HEAD~1)"
commit_file "$work/p" z.txt "a fix"
run_hook gate Bash "$(bash_call "git push origin feat/x")"
blocked "push with a failing review"
[ "$(cat "$work/stub/words.1")" = "$(jq -nc '{title: "Add x", body: "PR body on GitHub"}')" ] || fail "push words: $(cat "$work/stub/words.1")"
grep -q "^REVIEW: fail" <<<"$err" || fail "push block without the REVIEW: line: $err"
ok "a push to an open PR is reviewed with the PR's words, and a fail blocks it"
for c in "git push" "git push -u origin feat/x" "git push origin HEAD" "git -C $work/p push --force-with-lease origin HEAD:refs/heads/feat/x" \
  "git add -A; git push"; do
  reset_state pass; open_pr 5 "Add x" "b" "$(git -C "$work/p" rev-parse HEAD~1)"
  run_hook gate Bash "$(bash_call "$c")"; allowed "push form: $c"
  [ "$(reviews)" = 1 ] || fail "push form not reviewed: $c"
done
ok "every common form of pushing the current branch is reviewed"
reset_state pass
open_pr 5 "Add x" "PR body on GitHub" "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; allowed "push with a passing review"
git -C "$work/p" push -q origin feat/x
open_pr 5 "Add x" "PR body on GitHub"
run_hook post Bash "$(bash_call "git push origin feat/x")"; allowed "post after push"
[ "$(posted 5)" = 1 ] && [ "$(jq -r .commit <<<"$(marker 5)")" = "$(head_sha)" ] || fail "no verdict for the pushed head"
ok "a passing push goes through, and its verdict lands on the PR for the new head"
for c in "git push --all" "git push --delete origin feat/x" "git push upstream feat/x" "git push origin main:feat/x"; do
  reset_state pass; open_pr 5 "Add x" "b"
  run_hook gate Bash "$(bash_call "$c")"; blocked "push the gate can't tie to HEAD: $c"
done
ok "pushes of other refs, remotes or many branches are blocked as could-not-run"

# A push to a branch with no open PR: not reviewed.
reset_state fail
run_hook gate Bash "$(bash_call "git push -u origin feat/x")"; allowed "push with no open PR"
[ "$(reviews)" = 0 ] || fail "a push with no open PR was reviewed"
run_hook post Bash "$(bash_call "git push -u origin feat/x")"; allowed "post for push with no PR"
ok "a push to a branch with no open PR is not reviewed"

# A branch name with query characters still finds its open PR (the reviewer's security low, LOG #47).
reset_state pass
git -C "$work/p" checkout -qb 'feat/y&state=closed'
commit_file "$work/p" amp.txt "on an odd branch"
jq -n --arg s "$(head_sha)" '{number: 6, state: "open", title: "Odd", body: "b", head: {ref: "feat/y&state=closed", sha: $s}, base: {ref: "main"}}' >"$work/gh/prs/6.json"
run_hook gate Bash "$(bash_call "git push origin HEAD")"; allowed "push from a branch with & in its name"
[ "$(reviews)" = 1 ] || fail "a branch name with & hid its open PR, so the push went unreviewed"
git -C "$work/p" checkout -q feat/x
ok "a branch name with query characters is encoded, so its open PR is found"

# A pass whose call then failed (the create errored, so no PR) must not be posted by a later call
# (the reviewer's finding on this PR's first create through the hook, LOG #47).
reset_state pass
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "create passes, then the create itself fails"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; allowed "a later push with no open PR"
run_hook post Bash "$(bash_call "git push origin feat/x")"; allowed "post after that push"
[ -z "$err" ] || fail "a stale pass from a failed create surfaced on a later push: $err"
reset_state pass
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "create passes, then the create itself fails"
open_pr 5 "Add x" "Adds x."
run_hook post Bash "$(bash_call "git push origin feat/x")"; allowed "post for a push that recorded no pass"
[ "$(posted 5)" = 0 ] || fail "a push posted a pass recorded for another call"
reset_state pass; open_pr 5 "Add x" "b" "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; allowed "a push passes, then git rejects it"
jq '.state = "closed"' "$work/gh/prs/5.json" >"$work/closed.json" && mv "$work/closed.json" "$work/gh/prs/5.json"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; allowed "the next push, after the PR was closed"
run_hook post Bash "$(bash_call "git push origin feat/x")"; allowed "post after that push"
[ -z "$err" ] || fail "a stale pass from a rejected push surfaced on the next push: $err"
ok "a recorded pass is used only by the post for the same kind of call, and the next gate clears it"

# --- 4. Every result other than a clean pass blocks.
for mode in could-not-run ask-owner; do
  reset_state $mode
  run_hook gate $MCP "$(mcp_create "Add x" "b")"; blocked "exit for $mode"
  grep -q "^REVIEW: $mode" <<<"$err" || fail "$mode: no REVIEW: line: $err"
  grep -qi "owner" <<<"$err" || fail "$mode doesn't escalate to the owner: $err"
done
grep -qF "AC-2 has no test" <<<"$(reset_state ask-owner; run_hook gate $MCP "$(mcp_create "Add x" "b")"; echo "$err")" \
  || fail "ask-owner doesn't return its findings"
grep -qF "two spec files" <<<"$(reset_state could-not-run; run_hook gate $MCP "$(mcp_create "Add x" "b")"; echo "$err")" \
  || fail "could-not-run doesn't return its reason"
ok "could-not-run (exit 2) and ask-owner (exit 3) block and escalate to the owner, ask-owner with its findings"
for mode in noline twolines mismatch crash; do
  reset_state $mode
  run_hook gate $MCP "$(mcp_create "Add x" "b")"; blocked "review.sh $mode"
  grep -qi "owner" <<<"$err" || fail "$mode doesn't escalate: $err"
done
ok "no REVIEW: line, two of them, an exit that disagrees with the line, or a crash all block"
reset_state pass
chmod -x "$work/dev/reviewer/review.sh"
run_hook gate $MCP "$(mcp_create "Add x" "b")"; blocked "review.sh not executable"
mv "$work/dev/reviewer/review.sh" "$work/review.sh.off"
run_hook gate $MCP "$(mcp_create "Add x" "b")"; blocked "review.sh missing"
grep -q "review.sh" <<<"$err" || fail "missing review.sh not named: $err"
mv "$work/review.sh.off" "$work/dev/reviewer/review.sh"; chmod +x "$work/dev/reviewer/review.sh"
ok "a missing or non-executable review.sh blocks"
reset_state pass; touch "$work/gh/fail"; open_pr 5 "Add x" "b"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; blocked "gh failing on the PR lookup"
reset_state pass
mkdir -p "$work/nogh"; for t in git jq python3 env bash sha256sum cut sed tail wc cp mkdir; do ln -sf "$(command -v "$t")" "$work/nogh/$t"; done
run_hook gate Bash "$(bash_call "git push origin feat/x")" "$work/nogh"; blocked "no gh"
run_hook gate Bash '"not an object"'; blocked "malformed tool input"
reset_state pass; echo '{"number": 5, "state": "open", "title": "t", "head": {"ref": "feat/x"}}' >"$work/gh/prs/5.json"
run_hook gate Bash "$(bash_call "git push origin feat/x")"; blocked "a PR record the hook doesn't expect"
grep -q "could not run" <<<"$err" || fail "an unexpected error doesn't say so: $err"
ok "a failing or missing gh, or a malformed input, blocks"

# --- 5. Words that differ from the reviewed ones are caught (W10.6.6's carried-over gap).
# 5a. GitHub's copy gained a footer after the review: the posted words are reviewed again, and
#     that verdict, for those words, is the one posted.
reset_state pass pass
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "create"
open_pr 5 "Add x" "Adds x.

---
_footer added by the server_"
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "post with a changed body, re-review passes"
[ "$(reviews)" = 2 ] || fail "the changed words were not reviewed again"
[ "$(jq -r .body "$work/stub/words.2")" = "Adds x.

---
_footer added by the server_" ] || fail "the re-review didn't get GitHub's words: $(cat "$work/stub/words.2")"
[ "$(posted 5)" = 1 ] || fail "want exactly the re-review's verdict posted, got $(posted 5)"
[ "$(jq -r .words <<<"$(marker 5)")" = "$(words_sha "Add x" "Adds x.

---
_footer added by the server_")" ] || fail "the posted verdict is not for the posted words: $(marker 5)"
ok "a body changed after the review is reviewed again as posted, and that verdict is posted"
reset_state pass fail
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "create"
open_pr 5 "Add x" "Adds x. Also fixes the login bug."
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post with a changed body, re-review fails"
[ "$(posted 5)" = 1 ] && [ "$(jq -r .outcome <<<"$(marker 5)")" = fail ] || fail "the failing re-review was not posted"
grep -q "^REVIEW: fail" <<<"$err" || fail "the failing re-review is not returned to Claude: $err"
ok "a changed body that fails its re-review is posted as a fail and returned to Claude"
# 5b. An edit of the words is reviewed before it runs.
reset_state fail
open_pr 5 "Add x" "Adds x."
run_hook gate mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"body":"Adds x and y."}'
blocked "MCP edit with a failing review"
[ "$(cat "$work/stub/words.1")" = "$(jq -nc '{title: "Add x", body: "Adds x and y."}')" ] || fail "edit words: $(cat "$work/stub/words.1")"
reset_state fail; open_pr 5 "Add x" "Adds x."
run_hook gate Bash "$(bash_call "gh pr edit 5 --title 'Add x and y'")"; blocked "gh pr edit with a failing review"
[ "$(jq -r .title "$work/stub/words.1")" = "Add x and y" ] || fail "gh edit words: $(cat "$work/stub/words.1")"
reset_state pass; open_pr 5 "Add x" "Adds x." "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook gate mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"body":"new"}'
blocked "edit while the PR's head is not HEAD"; [ "$(reviews)" = 0 ] || fail "reviewed an edit against the wrong commit"
reset_state fail; open_pr 5 "Add x" "Adds x."
run_hook gate Bash "$(bash_call "gh pr edit 5 --add-label bug")"; allowed "gh pr edit not touching the words"
run_hook gate mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"state":"closed"}'
allowed "MCP edit not touching the words"
[ "$(reviews)" = 0 ] || fail "an edit that doesn't touch the words was reviewed"
reset_state pass; open_pr 5 "Add x" "Adds x."
run_hook gate mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"body":"Adds x, better."}'
allowed "MCP edit with a passing review"
open_pr 5 "Add x" "Adds x, better."
run_hook post mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"body":"Adds x, better."}'
allowed "post after edit"
[ "$(jq -r .words <<<"$(marker 5)")" = "$(words_sha "Add x" "Adds x, better.")" ] || fail "edit verdict words: $(marker 5)"
ok "an edit of the title or body is reviewed first, and its verdict carries the new words"
# 5c. Words edited by anyone after the verdict: the review-verdict check reads the comment as stale.
jq -s '[.[] | {body}]' "$work/gh/comments.5" >"$work/list.json"
rc=0; line=$("$repo_root/runtime/reviewer/verdict-check.sh" --head "$(head_sha)" --comments "$work/list.json" \
  --words "$(words_sha "Add x" "Adds x, edited in the browser.")") || rc=$?
[ "$rc" = 1 ] && [[ "$line" == "VERDICT: stale"* ]] || fail "words edited after the verdict: $rc $line"
ok "words edited after the verdict make the review-verdict check stale"

# --- MCP tools that commit on the remote: blocked on a branch with an open PR.
reset_state pass; open_pr 5 "Add x" "b"
for t in push_files create_or_update_file delete_file; do
  run_hook gate "mcp__github__$t" '{"owner":"example","repo":"app","branch":"feat/x","path":"a","content":"x","message":"m","files":[]}'
  blocked "$t on a branch with an open PR"
  grep -q "git push" <<<"$err" || fail "$t: doesn't say to commit locally and git push: $err"
  run_hook gate "mcp__github__$t" '{"owner":"example","repo":"app","branch":"other","path":"a","content":"x","message":"m","files":[]}'
  allowed "$t on a branch with no PR"
done
run_hook gate mcp__github__update_pull_request_branch '{"owner":"example","repo":"app","pullNumber":5}'
blocked "update_pull_request_branch"
grep -q "git push" <<<"$err" || fail "update_pull_request_branch: doesn't say to merge locally and git push: $err"
[ "$(reviews)" = 0 ] || fail "remote-commit tools ran a review"
ok "remote commits to a branch with an open PR are blocked; elsewhere they pass"

# --- The post hook says so when it can't post, instead of passing silently.
reset_state pass
run_hook gate $MCP "$(mcp_create "Add x" "Adds x.")"; allowed "create"
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post with no PR found"
grep -qi "not posted" <<<"$err" || fail "no PR: $err"
open_pr 5 "Add x" "Adds x." "$(git -C "$work/p" rev-parse HEAD~1)"
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post with the PR at another head"
[ "$(posted 5)" = 0 ] || fail "a verdict was posted for a commit that isn't the PR's head"
open_pr 5 "Add x" "Adds x."; touch "$work/gh/fail"
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post with gh failing"
rm -f "$work/gh/fail"; touch "$work/gh/fail-post"
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post with the comment refused"
grep -qF "not posted" <<<"$err" || fail "refused comment: $err"
reset_state pass; open_pr 5 "Add x" "Adds x."
run_hook post $MCP "$(mcp_create "Add x" "Adds x.")"; blocked "post after a create with no recorded pass"
[ "$(posted 5)" = 0 ] || fail "posted with no recorded pass"
ok "a verdict that can't be posted (no PR, other head, gh failing, no recorded pass) is reported, never silent"

echo "all reviewer hook tests passed"
