#!/usr/bin/env bash
# Tests the review guard (W10.6.7): runtime/hooks/review-guard.py, the plugin's PreToolUse hook. It
# reviews nothing; it refuses the ways of putting a change on a PR other than ship.sh (gh pr create,
# gh pr edit of the words, a git push while the branch has an open PR, the GitHub tools that create,
# edit or commit), and lets everything else through. Stub `gh` (a fake PR store in $GH_DIR), a
# local bare repo as origin. No network.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v jq >/dev/null || fail "jq not found"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
ok() { echo "ok - $1"; }
guard="$repo_root/runtime/hooks/review-guard.py"

# --- A stub gh: GET repos/<slug>/pulls?head=<owner>:<branch>&state=open over $GH_DIR/prs.
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_DIR/calls"
[ ! -f "$GH_DIR/fail" ] || { echo "HTTP 502: bad gateway" >&2; exit 1; }
path=$2
case "$1 $path" in
  "api repos/example/app/pulls?"*)
    q=$(python3 -c 'import sys, urllib.parse as u; q = u.parse_qs(sys.argv[1].split("?", 1)[1]); print(q.get("state", [""])[0], q.get("head", [""])[0])' "$path")
    [[ "$q" == "open example:"* ]] || { echo "stub gh: unexpected query $path" >&2; exit 1; }
    b=${q#open example:}
    cat "$GH_DIR"/prs/*.json 2>/dev/null | jq -s --arg b "$b" '[.[] | select(.state == "open" and .head.ref == $b)]' ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$work/bin/gh"

# --- The project: a feature branch on a bare origin named like a GitHub repo.
git init -q --bare "$work/remote/example/app.git"
new_repo "$work/p"
git -C "$work/p" remote add origin "$work/remote/example/app.git"
git -C "$work/p" push -q origin main
git -C "$work/p" checkout -qb feat/x

reset_state() { rm -rf "$work/gh"; mkdir -p "$work/gh/prs"; : >"$work/gh/calls"; }
open_pr() { jq -n --arg b "${1:-feat/x}" '{number: 5, state: "open", head: {ref: $b}}' >"$work/gh/prs/5.json"; }
# run_guard <tool name> <tool input json> [PATH]: as Claude Code runs it; sets rc and err.
run_guard() {
  local input
  input=$(jq -nc --arg t "$1" --argjson i "$2" --arg cwd "$work/p" '{tool_name: $t, tool_input: $i, cwd: $cwd}')
  rc=0
  (cd "$work/p" && PATH=${3:-"$work/bin:$PATH"} GH_DIR="$work/gh" "$guard" <<<"$input") >/dev/null 2>"$work/err" || rc=$?
  err=$(cat "$work/err")
}
bash_call() { jq -nc --arg c "$1" '{command: $c}'; }
refused() { [ "$rc" = 2 ] || fail "$1: want exit 2 (refused), got $rc: $err"; grep -q "ship" <<<"$err" || fail "$1: doesn't point to ship: $err"; }
allowed() { [ "$rc" = 0 ] || fail "$1: want exit 0 (allowed), got $rc: $err"; [ -z "$err" ] || fail "$1: allowed, but said: $err"; }

# --- The plugin registers the guard on the right tools, with one list of GitHub tools everywhere.
hooks_json="$repo_root/install/plugin/devshop/hooks/hooks.json"
pre=$(jq -er '.hooks.PreToolUse[0].matcher' "$hooks_json") || fail "the plugin registers no PreToolUse hook"
for t in Bash mcp__github__create_pull_request mcp__github__update_pull_request mcp__github__update_pull_request_branch \
  mcp__github__push_files mcp__github__create_or_update_file mcp__github__delete_file; do
  grep -Eqx "$pre" <<<"$t" || fail "PreToolUse matcher '$pre' misses $t"
done
for t in Read mcp__github__get_file_contents mcp__github__list_pull_requests mcp__github__add_issue_comment; do
  ! grep -Eqx "$pre" <<<"$t" || fail "PreToolUse matcher catches $t"
done
! jq -e '[.hooks.PostToolUse[]?.hooks[].command] | any(test("review"))' "$hooks_json" >/dev/null || fail "a review hook is still registered after the call"
pre_cmd=$(jq -er '.hooks.PreToolUse[0].hooks[0].command' "$hooks_json")
[[ "$pre_cmd" == *"/opt/devshop-current/hooks/review-guard.py"* ]] || fail "the PreToolUse command doesn't run the pinned guard: $pre_cmd"
guard_tools=$(python3 -B -c 'import importlib.util as u, sys
s = u.spec_from_file_location("guard", sys.argv[1]); m = u.module_from_spec(s); s.loader.exec_module(m)
print("\n".join(sorted(m.GITHUB_TOOLS)))' "$guard")
matcher_tools=$(sed -E 's/.*__\(([^)]*)\)$/\1/' <<<"$pre" | tr '|' '\n' | sort)
fallback_tools=$(grep -oE "grep -Eq '[^']*'" <<<"$pre_cmd" | sed -E "s/^grep -Eq '(.*)'$/\1/" | tr '|' '\n' | grep -E '^[a-z_]+$' | sort)
{ [ -n "$guard_tools" ] && [ "$guard_tools" = "$matcher_tools" ] && [ "$guard_tools" = "$fallback_tools" ]; } \
  || fail "tool lists differ: guard [$(tr '\n' ' ' <<<"$guard_tools")] matcher [$(tr '\n' ' ' <<<"$matcher_tools")] fallback [$(tr '\n' ' ' <<<"$fallback_tools")]"
ok "the plugin registers the guard before the call only, and the guard, matcher and fallback name the same GitHub tools"
missing_cmd=${pre_cmd//\/opt\/devshop-current\/hooks\/review-guard.py/$work/nope/review-guard.py}
for input in "$(jq -nc '{tool_name: "Bash", tool_input: {command: "gh pr create -t x -b y"}}')" \
  "$(jq -nc '{tool_name: "Bash", tool_input: {command: "git push origin feat/x"}}')" \
  "$(jq -nc '{tool_name: "mcp__github__create_pull_request", tool_input: {title: "t"}}')" \
  "$(jq -nc '{tool_name: "mcp__github__update_pull_request_branch", tool_input: {pullNumber: 5}}')"; do
  rc=0; bash -c "$missing_cmd" <<<"$input" >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || fail "a missing guard let through: $input (exit $rc)"
done
rc=0; bash -c "$missing_cmd" <<<'{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' >/dev/null 2>&1 || rc=$?
[ "$rc" = 0 ] || fail "a missing guard refused an unrelated call (exit $rc)"
ok "a missing guard: the fallback refuses the same calls by name, and only those"

# --- Everything else passes, without a GitHub call.
reset_state; open_pr
for c in "ls -la" "git status" "echo 'gh pr create'" "git log --grep push" "gh pr view 5" "gh pr edit 5 --add-label bug" \
  "git commit -m 'Explain why we git push later'" "/opt/devshop-current/reviewer/ship.sh --title 'Add x' --body-file b.md" \
  "cat >notes.md <<'EOF'
there's no git push here, and gh pr create neither
EOF"; do
  run_guard Bash "$(bash_call "$c")"; allowed "unrelated: $c"
done
run_guard Read '{"file_path": "/etc/hosts"}'; allowed "Read"
run_guard mcp__github__update_pull_request '{"owner":"example","repo":"app","pullNumber":5,"state":"closed"}'; allowed "closing a PR"
[ ! -s "$work/gh/calls" ] || fail "an unrelated call asked GitHub: $(cat "$work/gh/calls")"
ok "unrelated calls, ship itself, quoted text and heredoc bodies pass silently, with no GitHub call"

# --- PR create and words edits: refused, however written.
reset_state
for c in "gh pr create -t x -b y" "gh pr create --fill" "git push && gh pr create -t x -b y" "cd sub; gh pr create" \
  "gh pr create -t x -b y >out.txt 2>&1" "if true; then gh pr create -t x -b y; fi" "for i in 1; do gh pr create; done" \
  "{ gh pr create; }" "! gh pr create" "GH_DEBUG=1 gh pr create" "gh pr edit 5 --title y" "gh pr edit 5 --body=z" \
  "gh pr edit -F b.md" "gh pr edit 5 -B release" "gh -R example/app pr create -t x -b y" "gh --repo=example/app pr edit 5 -t y" \
  "gh pr edit 5 -tTitle" "gh pr edit 5 -bBody" "cat <<EOF
text
EOF
gh pr create -t x -b y" "echo 'unclosed
gh pr create -t x"; do
  run_guard Bash "$(bash_call "$c")"; refused "gh: $c"
done
run_guard mcp__github__create_pull_request '{"owner":"example","repo":"app","title":"t","body":"b","head":"feat/x","base":"main"}'; refused "MCP create"
for i in '{"title":"t"}' '{"body":"b"}' '{"base":"release"}'; do
  run_guard mcp__github__update_pull_request "$(jq -c '. + {owner: "example", repo: "app", pullNumber: 5}' <<<"$i")"; refused "MCP edit $i"
done
run_guard mcp__github__update_pull_request_branch '{"owner":"example","repo":"app","pullNumber":5}'; refused "update_pull_request_branch"
ok "gh pr create, gh pr edit of the words, and the GitHub tools that create or edit are refused: use ship"

# --- git push: refused while the branch has an open PR, allowed before.
reset_state
for c in "git push" "git push -u origin feat/x" "git push origin feat/x 2>&1 | tail -3"; do
  run_guard Bash "$(bash_call "$c")"; allowed "push with no open PR: $c"
done
open_pr
for c in "git push" "git push -u origin feat/x" "git push origin HEAD 2>&1" "git add -A && git push" "git -C $work/p push" \
  "git -c core.x=y push" "if true; then git push; fi" "cat >n.md <<'EOF'
it's text
EOF
git push origin feat/x"; do
  run_guard Bash "$(bash_call "$c")"; refused "push to an open PR: $c"
done
touch "$work/gh/fail"; run_guard Bash "$(bash_call "git push")"; refused "push when gh fails"; rm -f "$work/gh/fail"
mkdir -p "$work/nogh"; for t in git jq python3 env bash; do ln -sf "$(command -v "$t")" "$work/nogh/$t"; done
run_guard Bash "$(bash_call "git push")" "$work/nogh"; refused "push with no gh"
git -C "$work/p" checkout -qb 'feat/y&x=1'
reset_state; open_pr 'feat/y&x=1'
run_guard Bash "$(bash_call "git push")"; refused "push from a branch with & in its name, which has an open PR"
git -C "$work/p" checkout -q feat/x
ok "a push is refused while the branch has an open PR, or when that can't be checked; before the PR it passes"

# --- Commits made on GitHub: refused on a branch with an open PR.
reset_state; open_pr
for t in push_files create_or_update_file delete_file; do
  run_guard "mcp__github__$t" '{"owner":"example","repo":"app","branch":"feat/x","path":"a","content":"x","message":"m","files":[]}'
  refused "$t on a branch with an open PR"
  run_guard "mcp__github__$t" '{"owner":"example","repo":"app","branch":"other","path":"a","content":"x","message":"m","files":[]}'
  allowed "$t on a branch with no PR"
done
ok "commits made on GitHub to a branch with an open PR are refused; elsewhere they pass"

# --- Input the guard can't read is refused.
run_guard Bash '"not an object"'; [ "$rc" = 2 ] || fail "malformed input: exit $rc"
rc=0; "$guard" <<<"not json" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "not JSON: exit $rc"
input=$(jq -nc '{tool_name: "Bash", tool_input: {command: "git push"}, cwd: 5}')
rc=0; (cd "$work/p" && PATH="$work/bin:$PATH" GH_DIR="$work/gh" "$guard" <<<"$input") >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "an error inside the guard let the call through (exit $rc)"
ok "input the guard can't read, or that breaks the check, is refused"

echo "all review guard tests passed"
