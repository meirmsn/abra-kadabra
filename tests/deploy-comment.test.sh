#!/usr/bin/env bash
# Tests runtime/scripts/deploy-comment.mjs (specs/deploy-and-metrics-comments.md, part 1) against a fake
# GitHub API on localhost that keeps the PR's comments, so each call sees what the previous one wrote.
# AC-1 to AC-7; AC-4's template half is tested in tests/ci-template-deploy.test.sh.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/runtime/scripts/deploy-comment.mjs"
command -v node >/dev/null || fail "node is not installed"

work=$(mktemp -d)
server_pid=
trap '[ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null; rm -rf "$work"' EXIT

sha=0123456789abcdef0123456789abcdef01234567
newer=fedcba9876543210fedcba9876543210fedcba98
prev=11111111-1111-4111-8111-111111111111

# The fake API. $work/state.json: {pulls, comments, runs, fail, hang}; comments change with POST, PATCH
# and DELETE. Each call is logged to $work/calls ("METHOD path").
cat >"$work/server.js" <<'EOF'
const fs = require("fs"), http = require("http");
const [dir, portFile] = process.argv.slice(2);
const file = `${dir}/state.json`;
const srv = http.createServer((q, r) => {
  let raw = "";
  q.on("data", (d) => (raw += d)).on("end", () => {
    const st = JSON.parse(fs.readFileSync(file, "utf8"));
    fs.appendFileSync(`${dir}/calls`, `${q.method} ${q.url}\n`);
    const send = (code, data) => { r.writeHead(code, { "content-type": "application/json" }); r.end(data === undefined ? "" : JSON.stringify(data)); };
    const save = () => fs.writeFileSync(file, JSON.stringify(st));
    if (st.hang) return; // never answers
    if (st.fail) return send(500, { message: "boom" });
    let m;
    if (q.method === "GET" && /\/commits\/[0-9a-f]+\/pulls$/.test(q.url)) {
      st.lookups = (st.lookups || 0) + 1; save();
      return send(200, st.lookups > (st.pullsAfter || 0) ? st.pulls : []);
    }
    if (q.method === "GET" && /\/issues\/\d+\/comments/.test(q.url)) return send(200, st.comments);
    if (q.method === "POST" && /\/issues\/\d+\/comments$/.test(q.url)) {
      const c = { id: 1000 + st.comments.length + (st.nextId = (st.nextId || 0) + 1), user: { login: "github-actions[bot]" }, body: JSON.parse(raw).body };
      st.comments.push(c); save(); return send(201, c);
    }
    if ((m = /\/issues\/comments\/(\d+)$/.exec(q.url))) {
      const c = st.comments.find((x) => x.id === Number(m[1]));
      if (!c) return send(404, {});
      if (q.method === "PATCH") { c.body = JSON.parse(raw).body; save(); return send(200, c); }
      if (q.method === "DELETE") { st.comments = st.comments.filter((x) => x !== c); save(); return send(204); }
    }
    if (q.method === "GET" && /\/actions\/runs\/\d+$/.test(q.url)) return send(200, { workflow_id: 9, run_number: 50 });
    if (q.method === "GET" && /\/actions\/workflows\/9\/runs/.test(q.url)) return send(200, { workflow_runs: st.runs || [] });
    send(404, {});
  });
});
srv.listen(0, "127.0.0.1", () => fs.writeFileSync(portFile, String(srv.address().port)));
EOF
echo '{"pulls":[],"comments":[]}' >"$work/state.json"
node "$work/server.js" "$work" "$work/port" &
server_pid=$!
for _ in $(seq 1 50); do [ -s "$work/port" ] && break; sleep 0.1; done
[ -s "$work/port" ] || fail "the fake API didn't start"
api="http://127.0.0.1:$(cat "$work/port")"

merged_pr='[{"number":5,"merged_at":"2026-10-15T00:00:00Z","base":{"ref":"main"},"merge_commit_sha":"'$sha'"}]'
# state <comments-json> [extra json fields]: reset the fake's state with the merged PR.
state() { printf '{"pulls":%s,"comments":%s%s}\n' "$merged_pr" "$1" "${2:+,$2}" >"$work/state.json"; }
# run <cmd> [VAR=value...]: the script with a good environment (attempt 1), overridable; sets $rc.
run() {
  local cmd=$1; shift
  : >"$work/calls"
  rc=0
  env -i PATH="$(dirname "$(command -v node)"):/usr/bin:/bin" GITHUB_TOKEN=fake GITHUB_REPOSITORY=o/r \
    GITHUB_API_URL="$api" DEPLOY_SHA=$sha RUN_ID=77 RUN_ATTEMPT=1 RUN_URL=https://example.com/runs/77 \
    URL=https://app.example.com VERSION=v-new PREVIOUS="$prev@100%" \
    ROLLBACK="roll back with \`tool rollback $prev\`" LOOKUP_TRIES=3 LOOKUP_WAIT_MS=10 API_TIMEOUT_MS=2000 \
    "$@" node "$script" "$cmd" >"$work/out.log" 2>&1 || rc=$?
}
show() { cat "$work/out.log" "$work/calls" "$work/state.json" >&2; }
# comments: the marker comments' bodies, one JSON string per line.
ncomments() { node -e 'const s=require(process.argv[1]);console.log(s.comments.filter(c=>c.body.startsWith("<!-- devshop-deploy -->")).length)' "$work/state.json"; }
body() { node -e 'const s=require(process.argv[1]);const c=s.comments.filter(c=>c.body.startsWith("<!-- devshop-deploy -->"));process.stdout.write(c.length?c[0].body:"")' "$work/state.json"; }
stateline() { body | sed -n 2p; }
has() { grep -qF -- "$1" <<<"$(body)" || { show; fail "$2: the comment lacks: $1"; }; }
expect_state() { # expect_state <state> <attempt> <label>
  [[ "$(stateline)" =~ ^\<\!--\ state:$1\ run:77/$2\ at:[0-9T:-]+Z\ --\>$ ]] || { show; fail "$3: want state $1 attempt $2, got: $(stateline)"; }
}
# A marker comment in a given state, as an earlier write left it.
c() { printf '{"id":%s,"user":{"login":"%s"},"body":"<!-- devshop-deploy -->\\n<!-- state:%s run:77/%s at:2026-10-15T00:00:00Z -->\\nold %s"}' "$1" "${4:-github-actions[bot]}" "$2" "$3" "$2"; }

# AC-1: merged creates the comment, with the state line; retries until the PR is findable.
state '[]' '"pullsAfter":2'
run merged
[ "$rc" = 0 ] || { show; fail "AC-1: merged exit $rc"; }
[ "$(ncomments)" = 1 ] || { show; fail "AC-1: want one comment"; }
expect_state merged 1 "AC-1"
has '**Merged** · `0123456` · checks running on `main`, then the deploy · [run](https://example.com/runs/77)' "AC-1"
[ "$(grep -c '/pulls$' "$work/calls")" = 3 ] || { show; fail "AC-1: want the lookup retried until found (3 tries)"; }
# AC-1: never findable: exits 0, comments nothing.
state '[]' '"pullsAfter":99'
run merged
[ "$rc" = 0 ] && [ "$(ncomments)" = 0 ] || { show; fail "AC-1: no merged PR should exit 0 without a comment"; }
grep -q "no merged PR's merge commit; no comment" "$work/out.log" || { show; fail "AC-1: no merged PR should say so"; }
[ "$(grep -c '/pulls$' "$work/calls")" = 3 ] || { show; fail "AC-1: want LOOKUP_TRIES lookups"; }
# AC-1: merged leaves a same-attempt deploying or final comment alone.
for s in deploying live failed not-deployed superseded; do
  state "[$(c 1 "$s" 1)]"
  run merged
  [ "$rc" = 0 ] && grep -q "old $s" <<<"$(body)" || { show; fail "AC-1: merged replaced a $s comment of the same attempt"; }
done
echo "ok: AC-1 merged creates the comment, retries the lookup, never moves back"

# AC-2: deploying moves merged forward; folds a duplicate into the oldest; leaves others' comments alone.
state "[$(c 1 merged 1)]"
run deploying
expect_state deploying 1 "AC-2"
has '**Deploying** `0123456` to production' "AC-2"
state '[]'
run deploying
[ "$(ncomments)" = 1 ] && expect_state deploying 1 "AC-2 (created)"
state "[$(c 5 merged 1),$(c 3 merged 1),$(c 4 live 1 someone-else)]"
run deploying
[ "$rc" = 0 ] || { show; fail "AC-2: exit $rc"; }
node -e 'const s=require(process.argv[1]);const ids=s.comments.map(c=>c.id).join(",");if(ids!=="3,4")throw new Error(ids)' "$work/state.json" \
  || { show; fail "AC-2: want the oldest bot comment (3) kept, the other (5) deleted, someone else's (4) untouched"; }
expect_state deploying 1 "AC-2 (oldest kept)"
grep -q 'old live' <<<"$(node -e 'console.log(require(process.argv[1]).comments.find(c=>c.id===4).body)' "$work/state.json")" \
  || fail "AC-2: someone else's comment was edited"
echo "ok: AC-2 deploying, one comment, others' comments untouched"

# AC-3: deployed and failed write the live and failed texts over merged/deploying, as a final state.
state "[$(c 1 deploying 1)]"
run deployed SITE_URL=https://www.example.com SITE_SMOKE=passed
expect_state live 1 "AC-3"
for want in '**Live in production** · `0123456` · https://app.example.com' '- New version: `v-new`' \
  "- Replaced: \`$prev@100%\`" '- Domain: https://www.example.com serves this build' "tool rollback $prev"; do
  has "$want" "AC-3 live"
done
state "[$(c 1 merged 1)]"
run failed DEPLOYED=yes
expect_state failed 1 "AC-3"
has 'failed its checks:** the new version may be live' "AC-3 may be live"
has "tool rollback $prev" "AC-3 may be live"
state "[$(c 1 deploying 1)]"
run failed DEPLOYED=
has 'failed;** production is unchanged' "AC-3 unchanged"
# AC-3: the website's first-version calls (no run id) still write the comment.
state '[]'
run deployed RUN_ID= RUN_ATTEMPT= RUN_URL=
[ "$rc" = 0 ] && [ "$(ncomments)" = 1 ] || { show; fail "AC-3: deployed with the old env should still comment"; }
has '**Live in production**' "AC-3 old env"
state '[]'
run failed RUN_ID= RUN_ATTEMPT=
[ "$rc" = 0 ] && grep -qF 'production is unchanged' <<<"$(body)" || { show; fail "AC-3: failed with the old env should still comment"; }
echo "ok: AC-3 live and failed texts, a final state, the old interface kept"

# AC-4: the unfilled slot (NONE=yes) ends not deployed, never live.
state "[$(c 1 deploying 1)]"
run deployed NONE=yes URL= VERSION=
expect_state not-deployed 1 "AC-4"
has 'this project has no deploy step yet; production is unchanged' "AC-4"
! grep -q 'Live in production' <<<"$(body)" || fail "AC-4: an unfilled slot claimed live"
echo "ok: AC-4 no deploy script, not deployed"

# AC-5: report gives every outcome its final state.
report_case() { # report_case <comments> <fast> <slow> <deploy> <want state> <want text> [extra state] [VAR=...]
  local cm=$1 f=$2 s=$3 d=$4 want=$5 text=$6 extra=${7:-}
  shift 7 2>/dev/null || shift $#
  state "$cm" "$extra"
  run report FAST="$f" SLOW="$s" DEPLOY="$d" "$@"
  [ "$rc" = 0 ] || { show; fail "AC-5 ($f/$s/$d): exit $rc"; }
  expect_state "$want" 1 "AC-5 ($f/$s/$d)"
  has "$text" "AC-5 ($f/$s/$d)"
}
report_case "[$(c 1 merged 1)]" failure skipped skipped not-deployed 'checks failed on `main`; production is unchanged'
report_case "[$(c 1 merged 1)]" success failure skipped not-deployed 'checks failed on `main`'
report_case "[$(c 1 merged 1)]" cancelled skipped skipped not-deployed 'checks were cancelled or timed out'
report_case "[$(c 1 merged 1)]" success cancelled skipped not-deployed 'checks were cancelled or timed out'
report_case "[$(c 1 merged 1)]" success success cancelled superseded \
  "**Not deployed on its own** · \`0123456\` · it ships with \`fedcba9\`'s deploy" \
  '"runs":[{"run_number":49,"head_sha":"'$sha'"},{"run_number":52,"head_sha":"'$newer'"},{"run_number":51,"head_sha":"'$sha'"}]'
report_case "[$(c 1 merged 1)]" success success cancelled not-deployed 'the run was cancelled' '"runs":[]'
report_case "[$(c 1 deploying 1)]" success success cancelled not-deployed "the deploy didn't finish; production may have changed"
report_case "[$(c 1 deploying 1)]" success success failure not-deployed "the deploy didn't finish; production may have changed"
report_case "[$(c 1 merged 1)]" success success failure not-deployed 'the deploy job failed before it started'
report_case "[$(c 1 deploying 1)]" success success success live '**Live in production** · `0123456` · https://app.example.com'
report_case "[$(c 1 deploying 1)]" success success success not-deployed 'this project has no deploy step yet' '' NONE=yes URL= VERSION=
# No comment at all: report creates it.
report_case '[]' failure skipped skipped not-deployed 'checks failed on `main`'
# A final comment of the same attempt, or one with no state line: left alone.
for s in live failed not-deployed superseded; do
  state "[$(c 1 "$s" 1)]"
  run report FAST=success SLOW=success DEPLOY=cancelled
  [ "$rc" = 0 ] && grep -q "old $s" <<<"$(body)" || { show; fail "AC-5: report replaced a final $s comment"; }
done
state '[{"id":1,"user":{"login":"github-actions[bot]"},"body":"<!-- devshop-deploy -->\nLive in production, an old comment"}]'
run report FAST=failure SLOW=skipped DEPLOY=skipped
grep -q 'an old comment' <<<"$(body)" || { show; fail "AC-5: report replaced a comment with no state line"; }
echo "ok: AC-5 report ends every outcome in a final state"

# AC-6: a higher attempt replaces a final state; a lower attempt changes nothing.
state "[$(c 1 failed 1)]"
run deploying RUN_ATTEMPT=2
expect_state deploying 2 "AC-6 (re-run)"
run deployed RUN_ATTEMPT=2
expect_state live 2 "AC-6 (failed, re-run, live)"
run report FAST=success SLOW=success DEPLOY=failure RUN_ATTEMPT=1
expect_state live 2 "AC-6 (a lower attempt must not write)"
run merged RUN_ATTEMPT=1
expect_state live 2 "AC-6 (a lower attempt must not write)"
# Only github-actions[bot]'s marker comments: a look-alike by anyone else is never edited.
state "[$(c 1 merged 1 someone-else)]"
run deploying
node -e 'const s=require(process.argv[1]);const o=s.comments.find(c=>c.id===1);if(!o.body.includes("old merged"))throw 1;if(s.comments.length!==2)throw 2' "$work/state.json" \
  || { show; fail "AC-6: someone else's look-alike comment was edited, or no comment of our own was created"; }
echo "ok: AC-6 forward-only per attempt; only the bot's comments"

# AC-7: bad arguments or settings exit 2 before any call; API errors and timeouts exit 1.
state "[$(c 1 merged 1)]"
for bad in "nonsense" "deployed GITHUB_TOKEN=" "deployed DEPLOY_SHA=abc" "merged RUN_ID=x1" "merged RUN_ATTEMPT=" \
  "merged RUN_URL=http://insecure.example.com" "deployed URL=" "deployed VERSION=" "deployed SITE_URL=https://x.example.com/path" \
  "report FAST=green SLOW=success DEPLOY=success" "report FAST=success SLOW=success" "deployed GITHUB_REPOSITORY=nope"; do
  read -r -a args <<<"$bad"
  run "${args[@]}"
  [ "$rc" = 2 ] || { show; fail "AC-7: '$bad' should exit 2, got $rc"; }
  [ ! -s "$work/calls" ] || { show; fail "AC-7: '$bad' called GitHub"; }
done
state '[]' '"fail":true'
run deploying
[ "$rc" = 1 ] || { show; fail "AC-7: an API error should exit 1, got $rc"; }
state '[]' '"hang":true'
start=$(date +%s)
run deploying API_TIMEOUT_MS=500
[ "$rc" = 1 ] && grep -q 'no answer in 500 ms' "$work/out.log" || { show; fail "AC-7: a hanging API should exit 1 on the timeout, got $rc"; }
[ $(($(date +%s) - start)) -lt 10 ] || fail "AC-7: the timeout didn't cut the call short"
echo "ok: AC-7 bad settings exit 2 without calling GitHub; API errors and timeouts exit 1"

echo "PASS: deploy-comment.mjs"
