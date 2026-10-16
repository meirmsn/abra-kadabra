#!/usr/bin/env bash
# Tests runtime/scripts/change-metrics.py and change-metrics.sh (specs/deploy-and-metrics-comments.md,
# part 2): AC-11 on the anonymised PR 7 fixture (tests/fixtures/change-metrics-pr7, rebuilt from that
# session's events and the PR's GitHub data), AC-12 to AC-14 on a made-up session, AC-15 through
# change-metrics.sh with a fake gh.
# shellcheck disable=SC2016  # dollar amounts and Markdown backticks in expected text, python sources
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
py="$repo_root/runtime/scripts/change-metrics.py"
sh="$repo_root/runtime/scripts/change-metrics.sh"
template="$repo_root/runtime/templates/ci.yml"
fixture="$repo_root/tests/fixtures/change-metrics-pr7"
for t in python3 jq git; do command -v "$t" >/dev/null || fail "$t is not installed"; done
python3 -c 'import yaml' 2>/dev/null || fail "PyYAML is not installed"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# same <label> <want file> <got file>
same() { diff -u "$2" "$3" >&2 || fail "$1: the comment differs (above: - want, + got)"; }

# AC-11: PR 7, the owner's numbers with their answers of 2026-10-16.
cat >"$work/pr7.want" <<'EOF'
<!-- devshop-metrics cost:3.8759 -->
**How this change went** · request to live **27 min**

- **Time:** 11 min Claude working · 13 min waiting on you · 3 min 31 s deploying
- **Your input:** 6 answers in chat · 1 PR comment · 1 approval
- **Cost:** $4.05 ($3.88 session + $0.17 reviewer)
- **Quality:** 2 pushes · 0 red CI runs · reviewer passed 2 of 2
EOF
python3 "$py" render --pr-data "$fixture/pr.json" --cost 3.8759 --ci "$template" --now 2026-01-05T03:08:00Z \
  --projects "$fixture/projects" >"$work/pr7.got" || fail "AC-11: render failed"
same "AC-11 (PR 7)" "$work/pr7.want" "$work/pr7.got"
echo "ok: AC-11 PR 7's numbers"

# --- A made-up session: an earlier change (merged PR 3), then this one (PR 9), resumed after a restart. ---
mkdir -p "$work/verdicts"
echo '{"reviewer":{"cost_usd":0.10}}' >"$work/verdicts/v1.json"
echo '{"reviewer":{"cost_usd":0.20}}' >"$work/verdicts/v2.json"
python3 - "$work" <<'EOF'
import json, os, sys
w = sys.argv[1]
S = "aaaaaaaa-0000-4000-8000-000000000001"
E, n = [], [0]
def add(e, t):
    n[0] += 1
    e.update(timestamp=f"2026-01-01T{t}Z", sessionId=S)
    if e.get("type") != "queue-operation":
        e["uuid"] = f"00000000-0000-4000-8000-{n[0]:012d}"
    E.append(e)
def owner(t, text): add({"type": "user", "origin": {"kind": "human"}, "message": {"content": text}}, t)
def wake(t): add({"type": "user", "origin": {"kind": "task-notification"}, "message": {"content": "<task-notification/>"}}, t)
def asst(t, end=False, tool=None):
    c = [{"type": "text", "text": "."}] + ([{"type": "tool_use", **tool}] if tool else [])
    add({"type": "assistant", "message": {"content": c, "stop_reason": "end_turn" if end else "tool_use"}}, t)
def result(t, tid, text): add({"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": text}]}}, t)
# The earlier change, merged as PR 3.
owner("09:00:00", "an earlier request")
asst("09:29:00", tool={"id": "m3", "name": "mcp__github__merge_pull_request", "input": {"pullNumber": 3}})
result("09:30:00", "m3", "merged")
asst("09:30:10", end=True)
# This change.
owner("10:00:00", "the request")
asst("10:00:05", tool={"id": "q1", "name": "AskUserQuestion", "input": {"questions": [{"q": 1}, {"q": 2}]}})
result("10:02:05", "q1", "answers")
add({"type": "user", "isMeta": True, "message": {"content": "Base directory for this skill: owner-looking text"}}, "10:02:10")
asst("10:03:00", tool={"id": "b1", "name": "Bash", "input": {"command": "ls"}})
add({"type": "queue-operation", "operation": "enqueue", "content": "a note sent mid-turn"}, "10:03:30")
add({"type": "attachment", "attachment": {"type": "queued_command", "prompt": "a note sent mid-turn", "origin": {"kind": "human"}}}, "10:03:30")
add({"type": "attachment", "attachment": {"type": "queued_command", "prompt": "<task-notification/>", "origin": {"kind": "task-notification"}}}, "10:03:35")
add({"type": "attachment", "attachment": {"type": "queued_command", "prompt": "[Subagent hand-back]", "origin": {"kind": "peer"}}}, "10:03:36")
add({"type": "queue-operation", "operation": "remove", "content": "a note sent mid-turn"}, "10:03:31")
result("10:03:40", "b1", "files")
asst("10:04:00", end=True)
wake("10:10:00")
asst("10:10:30", end=True)
owner("10:20:00", "go")
asst("10:21:00", tool={"id": "s1", "name": "Bash", "input": {"command": "ship.sh"}})
result("10:22:00", "s1", f"REVIEW: fail · round 1 · 1 blocking, 0 low · abc · {w}/verdicts/v1.json")
asst("10:22:30", tool={"id": "s2", "name": "Bash", "input": {"command": "ship.sh"}})
result("10:25:00", "s2", f"REVIEW: pass · round 2 · 0 blocking, 0 low · def · {w}/verdicts/v2.json\nSHIPPED: PR #9")
asst("10:25:30", end=True)
first = len(E)
wake("10:39:00")
asst("10:39:59", tool={"id": "m9", "name": "mcp__github__merge_pull_request", "input": {"pullNumber": 9}})
result("10:40:00", "m9", "merged")
asst("10:40:30", end=True)
owner("10:50:00", "a message after the merge")
asst("10:50:10", end=True)
# A container restart: the resumed session's file in another folder holds every entry; the old one
# stops before the merge.
for d, es in (("-old-dir", E[:first]), ("-new-dir", E)):
    os.makedirs(f"{w}/home/.claude/projects/{d}", exist_ok=True)
    with open(f"{w}/home/.claude/projects/{d}/{S}.jsonl", "w") as fh:
        fh.writelines(json.dumps(e) + "\n" for e in es)
bot, agent = {"login": "github-actions[bot]", "type": "Bot"}, {"login": "agent-example", "type": "User"}
own, other = {"login": "owner-example", "type": "User"}, {"login": "someone-else", "type": "User"}
deploy = lambda st, at, text: {"id": 99, "user": bot, "created_at": "2026-01-01T10:40:05Z", "body": f"<!-- devshop-deploy -->\n<!-- state:{st} run:5/1 at:2026-01-01T{at}Z -->\n{text}"}
data = {
    "pr": {"number": 9, "user": agent, "created_at": "2026-01-01T10:25:00Z", "merged_at": "2026-01-01T10:40:00Z", "head": {"ref": "b"}},
    "comments": [
        {"id": 1, "user": own, "created_at": "2026-01-01T10:30:00Z", "body": "please change x"},
        {"id": 2, "user": other, "created_at": "2026-01-01T10:31:00Z", "body": "drive-by"},
        {"id": 3, "user": bot, "created_at": "2026-01-01T10:26:00Z", "body": "<!-- devshop-preview -->"},
        {"id": 4, "user": own, "created_at": "2026-01-01T10:55:00Z", "body": "after the merge"},
        deploy("live", "10:45:00", "**Live in production** · `0123456` · https://app.example.com"),
    ],
    "reviews": [
        {"user": own, "state": "APPROVED", "body": "", "submitted_at": "2026-01-01T10:38:00Z"},
        {"user": other, "state": "COMMENTED", "body": "looks odd", "submitted_at": "2026-01-01T10:32:00Z"},
        {"user": {"login": "lint[bot]", "type": "Bot"}, "state": "APPROVED", "body": "", "submitted_at": "2026-01-01T10:33:00Z"},
    ],
    "review_comments": [{"user": own, "created_at": "2026-01-01T10:30:30Z"}],
    "runs": [
        {"id": 1, "head_sha": "a" * 40, "conclusion": "failure", "attempts": []},
        {"id": 2, "head_sha": "b" * 40, "conclusion": "success", "attempts": ["failure"]},
        {"id": 3, "head_sha": "c" * 40, "conclusion": "success", "attempts": []},
    ],
}
json.dump(data, open(f"{w}/pr9.json", "w"))
for name, st, at, text in (
    ("failed", "failed", "10:45:00", "**Production deploy of `0123456` failed;** production is unchanged."),
    ("notdeployed", "not-deployed", "10:44:00", "**Not deployed** · `0123456` · checks failed on `main`; production is unchanged · [run](https://example.com/r)"),
    ("superseded", "superseded", "10:44:00", "**Not deployed on its own** · `0123456` · it ships with `fedcba9`'s deploy · [run](https://example.com/r)"),
    ("merged", "merged", "10:40:05", "**Merged** · `0123456` · checks running"),
):
    d = json.loads(json.dumps(data)); d["comments"][-1] = deploy(st, at, text)
    json.dump(d, open(f"{w}/pr9-{name}.json", "w"))
d = json.loads(json.dumps(data)); d["comments"] = d["comments"][:-1]
json.dump(d, open(f"{w}/pr9-nocomment.json", "w"))
EOF
# render <data> [args...]: into $work/got; sets $rc.
render() {
  local data=$1; shift
  rc=0
  python3 "$py" render --pr-data "$work/$data" --ci "$template" --now 2026-01-01T10:46:00Z \
    --projects "$work/home/.claude/projects" "$@" >"$work/got" 2>"$work/err" || rc=$?
}
cat >"$work/pr9.want" <<'EOF'
<!-- devshop-metrics cost:10.5000 -->
**How this change went** · request to live **45 min**

- **Time:** 9 min 30 s Claude working · 31 min waiting on you · 5 min deploying
- **Your input:** 4 answers in chat · 2 PR comments · 1 approval
- **Cost:** $6.55 ($6.25 session + $0.30 reviewer)
- **Quality:** 3 pushes · 2 red CI runs · reviewer passed 1 of 2
EOF
render pr9.json --cost 10.50 --prev-cost 4.25
[ "$rc" = 0 ] || { cat "$work/err" >&2; fail "AC-12: render exit $rc"; }
same "AC-12/AC-13 (the made-up session)" "$work/pr9.want" "$work/got"
echo "ok: AC-12 working and waiting time, the clock after the earlier merge, one count per message across a restart"
echo "ok: AC-13 answers, the owner's comments and approval only, pushes, red runs with earlier attempts, reviewer rounds and cost"
# AC-12: the clock starts after the session's earlier merge, which previous-pr names.
[ "$(python3 "$py" previous-pr --pr 9 --projects "$work/home/.claude/projects")" = 3 ] || fail "AC-12: previous-pr should name PR 3"
[ -z "$(python3 "$py" previous-pr --pr 3 --projects "$work/home/.claude/projects")" ] || fail "AC-12: nothing was merged before PR 3"

# AC-13: with the verdict files gone, the reviewer's cost comes from the PR's footers; with neither, unknown.
mv "$work/verdicts" "$work/verdicts.gone"
python3 - "$work" <<'EOF'
import json, sys
w = sys.argv[1]
d = json.load(open(f"{w}/pr9.json"))
d["comments"].append({"id": 50, "user": {"login": "agent-example", "type": "User"}, "created_at": "2026-01-01T10:25:01Z",
  "body": '<!-- devshop-review {"format":"devshop-review/2","commit":"' + "d" * 40 + '","outcome":"pass","round":2} -->\n<sub>Independent reviewer · devshop x · m · session s · $0.4</sub>'})
json.dump(d, open(f"{w}/pr9-footer.json", "w"))
EOF
render pr9-footer.json --cost 10.50 --prev-cost 4.25
grep -qF -- '- **Cost:** $6.65 ($6.25 session + $0.40 reviewer)' "$work/got" || { cat "$work/got" >&2; fail "AC-13: the footer's cost should stand in"; }
render pr9.json --cost 10.50 --prev-cost 4.25
grep -qF -- '- **Cost:** unknown ($6.25 session + unknown reviewer)' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no verdict file and no footer should be unknown"; }
mv "$work/verdicts.gone" "$work/verdicts"
echo "ok: AC-13 the reviewer's cost from the PR's footers when the verdict files are gone"

# AC-14: unknowns, and each outcome's headline.
render pr9.json --cost unknown
grep -qF -- '- **Cost:** unknown (unknown session + $0.30 reviewer)' "$work/got" || { cat "$work/got" >&2; fail "AC-14: an unknown cost"; }
head -1 "$work/got" | grep -qxF '<!-- devshop-metrics cost:unknown -->' || fail "AC-14: the marker should record an unknown cost"
render pr9.json --cost 10.50 --prev-cost unknown
grep -qF -- '($6.25' "$work/got" && fail "AC-14: an unknown start cost must not give a session cost"
grep -qF -- 'unknown session' "$work/got" || { cat "$work/got" >&2; fail "AC-14: an unknown start cost"; }
render pr9.json --cost 2.00
grep -qF -- '($2.00 session' "$work/got" || { cat "$work/got" >&2; fail "AC-14: a session's first change starts at 0"; }
rc=0
python3 "$py" render --pr-data "$work/pr9.json" --cost 1 --ci "$template" --now 2026-01-01T10:46:00Z --projects "$work/none" >"$work/got" || rc=$?
[ "$rc" = 0 ] || fail "AC-14: no transcript should still render"
grep -qF -- '- **Time:** unknown Claude working · unknown waiting on you · 5 min deploying' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no transcript"; }
grep -qF -- 'unknown answers in chat · 2 PR comments' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no transcript, input"; }
grep -qF -- 'request to live **unknown**' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no transcript, headline"; }
grep -qF -- '- **Cost:** unknown ($1.00 session + unknown reviewer)' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no transcript and no footers: the reviewer's cost is unknown"; }
grep -qF -- '2 red CI runs · reviewer unknown' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no transcript and no footers: the reviewer's rounds are unknown"; }
# A transcript read from the start with no REVIEW: line: no reviewer ran, $0.00.
mkdir -p "$work/plain/p"
printf '%s\n' '{"type":"user","uuid":"u1","timestamp":"2026-01-01T10:00:00Z","origin":{"kind":"human"},"message":{"content":"the request"}}' \
  '{"type":"assistant","uuid":"u2","timestamp":"2026-01-01T10:01:00Z","message":{"content":[],"stop_reason":"end_turn"}}' >"$work/plain/p/s.jsonl"
python3 "$py" render --pr-data "$work/pr9.json" --cost 1 --ci "$template" --now 2026-01-01T10:46:00Z --projects "$work/plain" >"$work/got" \
  || fail "AC-14: render with a plain transcript failed"
grep -qF -- '- **Cost:** $1.00 ($1.00 session + $0.00 reviewer)' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no REVIEW: line in a transcript means no reviewer ran"; }
grep -qF -- '2 red CI runs · no reviewer rounds' "$work/got" || { cat "$work/got" >&2; fail "AC-14: no reviewer rounds"; }
# headline <data> <want headline> <deploying shown: yes|no>
headline() {
  render "$1" --cost 1
  [ "$rc" = 0 ] || { cat "$work/err" >&2; fail "AC-14 ($1): exit $rc"; }
  sed -n 2p "$work/got" | grep -qxF -- "**How this change went** · $2" || { cat "$work/got" >&2; fail "AC-14 ($1): headline"; }
  if [ "$3" = yes ]; then grep -q 'deploying$' "$work/got"; else ! grep -q 'deploying' "$work/got"; fi \
    || { cat "$work/got" >&2; fail "AC-14 ($1): deploying shown should be $3"; }
}
headline pr9-failed.json '**deploy failed** · request to failure **45 min**' yes
headline pr9-notdeployed.json '**not deployed** (checks failed on `main`) · request to merge **40 min**' no
headline pr9-superseded.json "ships with \`fedcba9\`'s deploy · request to merge **40 min**" no
echo "ok: AC-14 unknowns render as unknown; each outcome has its headline"

# AC-15 (the waiting half, in render): not final within the hour exits 3; after it, posts with the deploy unknown.
render pr9-merged.json --cost 1
[ "$rc" = 3 ] || fail "AC-15: a deploy comment still merged within the hour should exit 3, got $rc"
render pr9-nocomment.json --cost 1
[ "$rc" = 3 ] || fail "AC-15: no deploy comment yet, with an announce job, should exit 3, got $rc"
rc=0
python3 "$py" render --pr-data "$work/pr9-merged.json" --cost 1 --ci "$template" --now 2026-01-01T11:41:00Z \
  --projects "$work/home/.claude/projects" >"$work/got" || rc=$?
{ [ "$rc" = 0 ] && grep -qF 'deploy unknown (no final state an hour after the merge) · request to merge **40 min**' "$work/got"; } \
  || { cat "$work/got" >&2; fail "AC-15: after an hour it should post with the deploy unknown"; }
grep -qF -- 'waiting on you · unknown deploying' "$work/got" || { cat "$work/got" >&2; fail "AC-15: after an hour the Time line shows deploying unknown"; }
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[2])); d["jobs"].pop("announce"); yaml.safe_dump(d, open(sys.argv[1],"w"))' "$work/noannounce.yml" "$template"
rc=0
python3 "$py" render --pr-data "$work/pr9-nocomment.json" --cost 1 --ci "$work/noannounce.yml" --now 2026-01-01T10:41:00Z \
  --projects "$work/home/.claude/projects" >"$work/got" || rc=$?
{ [ "$rc" = 0 ] && grep -qF 'no deploy comment · request to merge **40 min**' "$work/got"; } || { cat "$work/got" >&2; fail "AC-15: no announce job should post at once"; }
for bad in "--cost abc" "--cost -1" "--cost 1 --now yesterday" "--cost 1 --prev-cost x"; do
  read -r -a args <<<"$bad"
  render pr9.json "${args[@]}"
  [ "$rc" = 2 ] || fail "AC-15: render $bad should exit 2, got $rc"
done
echo '{"pr":{"number":9}}' >"$work/unmerged.json"
render unmerged.json --cost 1
[ "$rc" = 2 ] || fail "AC-15: an unmerged PR should exit 2, got $rc"

# AC-15 (change-metrics.sh): a fake gh serves the PR from $GH_DIR and records what is posted.
mkdir -p "$work/bin" "$work/gh" "$work/proj/.github/workflows"
cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env python3
import json, os, re, sys
d = os.environ["GH_DIR"]
args = [a for a in sys.argv[1:] if a not in ("api", "--paginate")]
method = "GET"
if "-X" in args:
    i = args.index("-X"); method = args[i + 1]; del args[i:i + 2]
if "--input" in args:
    i = args.index("--input"); del args[i:i + 2]
path = args[0].split("?")[0]
open(f"{d}/calls", "a").write(f"{method} {args[0]}\n")
if os.path.exists(f"{d}/fail"):
    sys.exit("HTTP 500")
data = json.load(open(f"{d}/pr.json"))
if method == "POST":
    open(f"{d}/posted", "a").write(json.load(sys.stdin)["body"] + "\n---\n")
    print("{}"); sys.exit()
routes = [
    (r"pulls/(\d+)$", lambda m: data["pr"]),
    (r"issues/9/comments$", lambda m: data["comments"]),
    (r"issues/3/comments$", lambda m: [{"user": {"login": "someone-else"}, "body": "<!-- devshop-metrics cost:99.0000 -->\nplanted"},
                                       {"user": {"login": "agent-example"}, "body": "<!-- devshop-metrics cost:4.2500 -->\n**How this change went**"}]),
    (r"pulls/\d+/reviews$", lambda m: data["reviews"]),
    (r"pulls/\d+/comments$", lambda m: data["review_comments"]),
    (r"workflows/ci.yml/runs$", lambda m: {"workflow_runs": [dict(r, run_attempt=len(r["attempts"]) + 1) for r in data["runs"]]}),
    (r"runs/(\d+)/attempts/(\d+)$", lambda m: {"conclusion": next(r for r in data["runs"] if r["id"] == int(m.group(1)))["attempts"][int(m.group(2)) - 1]}),
]
for pat, f in routes:
    m = re.search(pat, path)
    if m:
        print(json.dumps(f(m))); sys.exit()
sys.exit(f"fake gh: no route for {path}")
EOF
chmod +x "$work/bin/gh"
git -C "$work/proj" init -q
git -C "$work/proj" remote add origin https://github.com/o/r.git
# Two merge commits: one whose ci.yml announces (the template), a later one whose doesn't.
git -C "$work/proj" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); d["jobs"].pop("announce"); yaml.safe_dump(d, open(sys.argv[2],"w"))' \
  "$template" "$work/proj/.github/workflows/ci.yml"
git -C "$work/proj" add -A && git -C "$work/proj" -c user.name=t -c user.email=t@example.com commit -qm "no announce"
quiet_merge=$(git -C "$work/proj" rev-parse HEAD)
cp "$template" "$work/proj/.github/workflows/ci.yml"
git -C "$work/proj" add -A && git -C "$work/proj" -c user.name=t -c user.email=t@example.com commit -qm "announce"
announce_merge=$(git -C "$work/proj" rev-parse HEAD)
merge=$announce_merge
# post <data file> [args...]: change-metrics.sh post in the project (the PR merged as $merge); sets $rc,
# output in $work/out.
post() {
  jq --arg m "$merge" '.pr.merge_commit_sha = $m' "$work/$1" >"$work/gh/pr.json"; shift
  rm -f "$work/gh/posted" "$work/gh/calls"
  rc=0
  (cd "$work/proj" && HOME="$work/home" GH_DIR="$work/gh" CHANGE_METRICS_NOW=2026-01-01T10:46:00Z PATH="$work/bin:$PATH" "$sh" post "$@") >"$work/out" 2>&1 || rc=$?
}
post pr9-merged.json --pr 9 --cost 10.50
[ "$rc" = 3 ] && [ ! -e "$work/gh/posted" ] || { cat "$work/out" >&2; fail "AC-15: not final yet should exit 3 and post nothing, got $rc"; }
post pr9.json --pr 9 --cost 10.50
[ "$rc" = 0 ] || { cat "$work/out" >&2; fail "AC-15: post exit $rc"; }
printf '%s\n---\n' "$(cat "$work/pr9.want")" >"$work/posted.want"
same "AC-15 (posted, with the earlier PR's recorded cost and the runs' attempts from gh)" "$work/posted.want" "$work/gh/posted"
grep -q '^POSTED: PR #9 · \*\*How this change went\*\*' "$work/out" || { cat "$work/out" >&2; fail "AC-15: post should say POSTED"; }
python3 - "$work" <<'EOF'
import json, sys
w = sys.argv[1]
d = json.load(open(f"{w}/pr9.json")); d["comments"].append({"id": 70, "user": {"login": "agent-example", "type": "User"}, "body": "<!-- devshop-metrics cost:10.5000 -->\nx"})
json.dump(d, open(f"{w}/pr9-posted.json", "w"))
EOF
# A look-alike by anyone but the PR's author (the session's account) doesn't stop the post.
python3 - "$work" <<'PYEOF'
import json, sys
w = sys.argv[1]
d = json.load(open(f"{w}/pr9.json")); d["comments"].append({"id": 71, "user": {"login": "someone-else", "type": "User"}, "body": "<!-- devshop-metrics cost:1.0000 -->\nplanted"})
json.dump(d, open(f"{w}/pr9-planted.json", "w"))
PYEOF
post pr9-planted.json --pr 9 --cost 10.50
{ [ "$rc" = 0 ] && [ -s "$work/gh/posted" ]; } || { cat "$work/out" >&2; fail "AC-15: someone else's look-alike comment stopped the post"; }
same "AC-15 (a planted marker on the earlier PR is ignored)" "$work/posted.want" "$work/gh/posted"
post pr9-posted.json --pr 9 --cost 10.50
{ [ "$rc" = 0 ] && [ ! -e "$work/gh/posted" ] && grep -q 'already has its metrics comment' "$work/out"; } \
  || { cat "$work/out" >&2; fail "AC-15: a second post should post nothing"; }
for bad in "" "--pr x --cost 1" "--pr 9" "--pr 9 --cost nope" "--pr 9 --cost 1 --extra"; do
  read -r -a args <<<"$bad"
  post pr9.json "${args[@]}"
  [ "$rc" = 2 ] && [ ! -e "$work/gh/calls" ] || { cat "$work/out" >&2; fail "AC-15: post '$bad' should exit 2 without calling GitHub, got $rc"; }
done
touch "$work/gh/fail"
post pr9.json --pr 9 --cost 1
{ [ "$rc" = 2 ] && grep -q 'gh api .* failed' "$work/out"; } || { cat "$work/out" >&2; fail "AC-15: gh failing should exit 2, got $rc"; }
rm "$work/gh/fail"
echo "ok: AC-15 post waits (exit 3), posts once, refuses bad arguments"

# --- specs/devshop-deploy-comment.md ---
# devshop-deploy AC-1: the rounds come from the branch's numbered verdict files in the window, plus the
# transcript's REVIEW: lines (here v1 fail and v2 pass, $0.30), each once.
vd="$work/vdir"
mkdir -p "$vd"
verdict() { # verdict <file> <outcome> <created> <cost> [branch]
  printf '{"outcome":"%s","created":"2026-01-01T%sZ","branch":"%s","reviewer":{"cost_usd":%s}}\n' "$2" "$3" "${5:-b}" "$4" >"$vd/$1"
}
verdict 001-aaa.json fail 10:21:00 0.01
verdict 002-bbb.json pass 10:24:00 0.02
verdict 003-ccc.json could-not-run 10:24:30 null
verdict 004-ddd.json ask-owner 10:26:00 0.04
verdict 005-eee.json pass 09:59:00 1.00
verdict 006-fff.json pass 10:41:30 1.00
verdict 007-ggg.json pass 10:30:00 1.00 other-branch
ln -s 002-bbb.json "$vd/latest.json"
ln -s "$work/verdicts/v2.json" "$vd/008-v2.json" # the same round the transcript names: counted once
render pr9.json --cost 10.50 --prev-cost 4.25 --verdicts "$vd"
[ "$rc" = 0 ] || { cat "$work/err" >&2; fail "devshop-deploy AC-1: exit $rc"; }
grep -qF -- '- **Cost:** $6.62 ($6.25 session + $0.37 reviewer)' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: the rounds' cost"; }
grep -qF -- 'reviewer passed 2 of 5' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: want 5 rounds (fail, pass, ask-owner from the files; v1 fail, v2 pass), 2 passed"; }
# A file in the window that can't be read makes the cost unknown.
printf 'not json' >"$vd/009-hhh.json"
touch -d 2026-01-01T10:30:00Z "$vd/009-hhh.json"
render pr9.json --cost 10.50 --prev-cost 4.25 --verdicts "$vd"
grep -qF -- '($6.25 session + unknown reviewer)' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: an unreadable file should make the cost unknown"; }
rm "$vd/009-hhh.json"
# So does one in the window whose time can't be read; a file with no branch isn't this branch's.
printf '{"outcome":"pass","created":"soon","branch":"b","reviewer":{"cost_usd":1}}\n' >"$vd/010-jjj.json"
touch -d 2026-01-01T10:30:00Z "$vd/010-jjj.json"
render pr9.json --cost 10.50 --prev-cost 4.25 --verdicts "$vd"
grep -qF -- '+ unknown reviewer)' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: an unreadable time should make the cost unknown"; }
rm "$vd/010-jjj.json"
printf '{"outcome":"pass","created":"2026-01-01T10:30:00Z","reviewer":{"cost_usd":1}}\n' >"$vd/011-kkk.json"
render pr9.json --cost 10.50 --prev-cost 4.25 --verdicts "$vd"
grep -qF -- 'reviewer passed 2 of 5' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: a file with no branch must not count"; }
rm "$vd/011-kkk.json"
# No clock start: the directory isn't used (it may hold another change's rounds).
rc=0
python3 "$py" render --pr-data "$work/pr9.json" --cost 1 --ci "$template" --now 2026-01-01T10:46:00Z --projects "$work/none" \
  --verdicts "$vd" >"$work/got" || rc=$?
grep -qF -- 'reviewer unknown' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-1: with no start the files must not count"; }
echo "ok: devshop-deploy AC-1 every reviewer round, once, from the verdict files and the transcript"

# devshop-deploy AC-2: no deploy comment awaited: posted at once, Claude working ends at the merge (the
# owner's message at 10:50 and its turn after the merge don't count).
rc=0
python3 "$py" render --pr-data "$work/pr9-nocomment.json" --cost 1 --ci "$work/noannounce.yml" --now 2026-01-01T11:30:00Z \
  --projects "$work/home/.claude/projects" >"$work/got" || rc=$?
grep -qF -- '- **Time:** 9 min Claude working · 31 min waiting on you' "$work/got" || { cat "$work/got" >&2; fail "devshop-deploy AC-2: working should end at the merge"; }

# devshop-deploy AC-2/AC-3 (change-metrics.sh): the merge commit's ci.yml decides, though today's
# announces; the verdict directory is the checkout's, for the PR's branch.
merge=$quiet_merge
post pr9-nocomment.json --pr 9 --cost 10.50
{ [ "$rc" = 0 ] && grep -qF 'no deploy comment · request to merge **40 min**' "$work/gh/posted"; } \
  || { cat "$work/out" "$work/gh/posted" >&2; fail "devshop-deploy AC-2: a merge commit without announce should post at once"; }
merge=$announce_merge
mkdir -p "$work/proj/.git/devshop/reviews/b"
printf '{"outcome":"pass","created":"2026-01-01T10:30:00Z","branch":"b","reviewer":{"cost_usd":0.05}}\n' \
  >"$work/proj/.git/devshop/reviews/b/001-iii.json"
post pr9.json --pr 9 --cost 10.50
grep -qF -- 'reviewer passed 2 of 3' "$work/gh/posted" || { cat "$work/out" "$work/gh/posted" >&2; fail "devshop-deploy AC-3: the checkout's verdict file should count"; }
echo "ok: devshop-deploy AC-2, AC-3 the merge commit's ci.yml decides; the checkout's verdicts count"

echo "PASS: change-metrics"
