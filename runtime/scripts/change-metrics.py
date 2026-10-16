#!/usr/bin/env python3
"""How a change went: the metrics comment the session posts on its merged PR once the PR's deploy comment
reaches a final state (specs/deploy-and-metrics-comments.md, part 2). Computes every number; the model
passes only the session's cost, which no script can read. change-metrics.sh gathers the PR data and posts.

Usage:
  change-metrics.py render --pr-data FILE --cost USD|unknown [--prev-cost USD|unknown] [--ci FILE]
                           [--now ISO] [--projects DIR] [--session ID]
  change-metrics.py previous-pr --pr N [--projects DIR] [--session ID]
render prints the comment. Exit 0 = printed; 3 = not yet: the deploy comment isn't final and less than
60 minutes have passed since the merge; 2 = can't run (bad arguments, an unreadable PR data file, a PR
not merged). previous-pr prints the number of the PR this session merged before PR N, or nothing.

Sources:
  - The transcript: every <session>.jsonl under --projects (default ~/.claude/projects), merged by entry
    uuid (a restarted container resumes the session into a new file holding the old entries); the
    session is --session, else the newest transcript's. None found: the session's numbers are unknown.
  - --pr-data, written by change-metrics.sh: {"pr": the PR, "comments", "reviews", "review_comments",
    "runs": the PR's pull_request runs of the ci workflow, each with "attempts" (earlier attempts'
    conclusions)}.
  - --ci, the project's workflow: without an `announce` job the project has no deploy comment, and the
    comment is posted at once.
In the transcript an owner message is a user entry with origin.kind "human", or a queued_command
attachment (sent mid-turn); a wake is a user entry with another origin (a check-in or PR event, a
subagent's hand-back). Claude works from each of them to the last assistant entry before the next, less
the time an AskUserQuestion waits for its answer.
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

DEPLOY_MARK = "<!-- devshop-deploy -->"
METRICS_MARK = "<!-- devshop-metrics"
FINAL = ("live", "failed", "not-deployed", "superseded")
GIVE_UP = timedelta(minutes=60)
REVIEW = re.compile(r"^REVIEW: ([a-z-]+) · round (\d+) · .* · (\S+)$", re.M)
FOOTER_COST = re.compile(r"· \$([0-9.]+)</sub>")


class CantRun(Exception):
    pass


def ts(s):
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)


# --- the transcript ---


def transcript(projects, session):
    files = glob.glob(os.path.join(projects, "*", "*.jsonl"))
    if not session:
        if not files:
            return []
        session = os.path.splitext(os.path.basename(max(files, key=os.path.getmtime)))[0]
    seen, entries = set(), []
    for f in sorted(p for p in files if os.path.basename(p) == f"{session}.jsonl"):
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                try:
                    e = json.loads(line)
                except ValueError:
                    continue
                key = e.get("uuid") or (e.get("type"), e.get("timestamp"), e.get("operation"))
                if key in seen or not e.get("timestamp"):
                    continue
                seen.add(key)
                entries.append(e)
    entries.sort(key=lambda e: e["timestamp"])
    return entries


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(c.get("text", "") if isinstance(c, dict) else str(c) for c in content)
    return ""


class Session:
    """What the metrics need from a transcript."""

    def __init__(self, entries):
        self.owner = []  # (time, text) of owner messages, deduplicated
        self.wakes = []
        self.assistant = []
        self.turn_ends, self.has_stop = [], False
        self.asks = []  # (call time, answer time, questions answered)
        self.reviews = []  # (time, outcome, verdict path)
        self.merges = []  # (time, PR number) the session merged
        calls, merge_calls = {}, {}
        for e in entries:
            t, kind = ts(e["timestamp"]), e.get("type")
            if kind == "assistant":
                self.assistant.append(t)
                stop = (e.get("message") or {}).get("stop_reason")
                self.has_stop = self.has_stop or bool(stop)
                if stop == "end_turn":
                    self.turn_ends.append(t)
                for c in (e.get("message") or {}).get("content") or []:
                    if not isinstance(c, dict) or c.get("type") != "tool_use":
                        continue
                    name, inp = c.get("name", ""), c.get("input") or {}
                    if name == "AskUserQuestion":
                        calls[c.get("id")] = (t, len(inp.get("questions") or []) or 1)
                    n = merged_pr(name, inp)
                    if n:
                        merge_calls[c.get("id")] = n
            elif kind == "attachment" and (e.get("attachment") or {}).get("type") == "queued_command":
                # Sent mid-turn: the owner's when its origin is human; else a wake (a subagent's
                # hand-back or a notification, queued the same way).
                if ((e["attachment"].get("origin") or {}).get("kind")) == "human":
                    self.add_owner(t, str(e["attachment"].get("prompt", "")))
                else:
                    self.wakes.append(t)
            elif kind == "user" and not e.get("isMeta"):
                content = (e.get("message") or {}).get("content")
                origin = (e.get("origin") or {}).get("kind")
                if origin == "human":
                    self.add_owner(t, text_of(content))
                elif origin:
                    self.wakes.append(t)
                for c in content if isinstance(content, list) else []:
                    if not isinstance(c, dict) or c.get("type") != "tool_result":
                        continue
                    if c.get("tool_use_id") in calls and not c.get("is_error"):
                        call_t, n = calls.pop(c["tool_use_id"])
                        self.asks.append((call_t, t, n))
                    if c.get("tool_use_id") in merge_calls and not c.get("is_error"):
                        self.merges.append((t, merge_calls.pop(c["tool_use_id"])))
                    for m in REVIEW.finditer(text_of(c.get("content"))):
                        self.reviews.append((t, m.group(1), m.group(3)))

    def add_owner(self, t, text):
        if any(abs((t - u).total_seconds()) < 10 and text == x for u, x in self.owner):
            return
        self.owner.append((t, text))

    def earlier_merges(self, pr):
        """(time, PR) of the other PRs this session merged before it merged `pr` (all, if it hasn't)."""
        mine = [t for t, n in self.merges if n == pr]
        cut = min(mine) if mine else None
        return [(t, n) for t, n in self.merges if n != pr and (cut is None or t < cut)]

    def start(self, pr):
        """The clock's start: the first owner message, or the first after this session's last earlier merge."""
        after = max((t for t, _ in self.earlier_merges(pr)), default=None)
        firsts = [t for t, _ in self.owner if after is None or t > after]
        return min(firsts) if firsts else None

    def working(self, start, end):
        """Seconds Claude worked between start and end: all of it but the idle time, from the end of a
        turn (its last assistant entry, stop_reason end_turn) to the next owner message or wake, and
        the time an AskUserQuestion waits for its answer. A wake that arrives mid-turn (a subagent's
        hand-back while the session waits for it) ends no turn. A transcript without stop reasons
        counts the last assistant entry before each owner message or wake as a turn's end."""
        starts = sorted(set([t for t, _ in self.owner] + self.wakes))
        ends = self.turn_ends
        if not self.has_stop:
            ends = [max(a) for s in starts if (a := [x for x in self.assistant if x < s])]
        far = end + timedelta(days=1)
        idle = [(te, next((s for s in starts if s > te), far)) for te in ends]
        holes = union(idle + [(a, b) for a, b, _ in self.asks])
        return measure(subtract([(start, end)], holes)) if end > start else 0.0


def merged_pr(name, inp):
    """The PR number a tool call merges, or None."""
    if name.endswith("merge_pull_request"):
        try:
            return int(inp.get("pullNumber") or inp.get("pull_number"))
        except (TypeError, ValueError):
            return None
    if name == "Bash":
        m = re.search(r"gh pr merge (\d+)|pulls/(\d+)/merge", str(inp.get("command", "")))
        if m:
            return int(m.group(1) or m.group(2))
    return None


def union(spans):
    out = []
    for a, b in sorted(spans):
        if out and a <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], b))
        else:
            out.append((a, b))
    return out


def subtract(spans, holes):
    out = []
    for a, b in spans:
        cur = a
        for h0, h1 in holes:
            if h1 <= cur or h0 >= b:
                continue
            if h0 > cur:
                out.append((cur, h0))
            cur = max(cur, h1)
        if cur < b:
            out.append((cur, b))
    return out


def measure(spans):
    return sum((b - a).total_seconds() for a, b in spans)


# --- the PR ---


def deploy_state(comments):
    """(state, time, comment body) of the PR's deploy comment, or None."""
    mine = [c for c in comments if (c.get("user") or {}).get("login") == "github-actions[bot]" and (c.get("body") or "").startswith(DEPLOY_MARK)]
    if not mine:
        return None
    c = min(mine, key=lambda c: c.get("id", 0))
    lines = c["body"].split("\n")
    m = re.match(r"^<!-- state:([a-z-]+) run:\d+/\d+ at:(\S+) -->$", lines[1] if len(lines) > 1 else "")
    if not m:  # no state line: final, written before state lines existed
        return ("live", ts(c.get("updated_at") or c.get("created_at")), c["body"])
    return (m.group(1), ts(m.group(2)), c["body"])


def is_bot(user):
    return (user or {}).get("type") == "Bot" or (user or {}).get("login", "").endswith("[bot]")


def owners(pr, reviews, comments):
    author = (pr.get("user") or {}).get("login")
    approvers = {r["user"]["login"] for r in reviews if r.get("state") == "APPROVED" and not is_bot(r.get("user")) and r["user"].get("login") != author}
    if approvers:
        return approvers
    people = [x.get("user") for x in reviews + comments]
    return {u["login"] for u in people if u and not is_bot(u) and u.get("login") != author}


def reviewer_from_pr(comments):
    """(outcomes, costs) from the reviewer's verdict comments on the PR (ship.sh posts only passes)."""
    outcomes, costs = [], []
    for c in comments:
        body = c.get("body") or ""
        m = re.match(r"<!-- devshop-review (\{.*?\}) -->", body)
        if not m:
            continue
        try:
            outcomes.append(json.loads(m.group(1)).get("outcome"))
        except ValueError:
            outcomes.append(None)
        f = FOOTER_COST.search(body)
        costs.append(float(f.group(1)) if f else None)
    return outcomes, costs


# --- rendering ---


def dur(seconds):
    if seconds is None:
        return "unknown"
    seconds = max(0, round(seconds))
    if seconds < 600:
        m, s = divmod(seconds, 60)
        return f"{m} min {s} s" if m and s else f"{m} min" if m else f"{s} s"
    return f"{round(seconds / 60)} min"


def n_of(n, one, many):
    return f"{n} {one if n == 1 else many}"


def money(x):
    return "unknown" if x is None else f"${x:.2f}"


def render(a):
    try:
        with open(a.pr_data, encoding="utf-8") as fh:
            data = json.load(fh)
        pr = data["pr"]
    except (OSError, ValueError, KeyError) as e:
        raise CantRun(f"can't read the PR data {a.pr_data}: {e}")
    cost = parse_cost(a.cost, "--cost")
    prev_cost = parse_cost(a.prev_cost, "--prev-cost") if a.prev_cost is not None else 0.0
    merged = ts(pr.get("merged_at"))
    if not merged:
        raise CantRun(f"PR #{pr.get('number')} isn't merged")
    now = ts(a.now) if a.now else datetime.now(timezone.utc)
    comments, reviews = data.get("comments") or [], data.get("reviews") or []

    has_deploy_comment = announces(a.ci)
    dep = deploy_state(comments)
    if has_deploy_comment and not (dep and dep[0] in FINAL):
        if now - merged < GIVE_UP:
            return 3, f"not final yet: the deploy comment is {dep[0] if dep else 'not posted'}"
        state, end = "unknown", now
    elif has_deploy_comment:
        state, end = dep[0], dep[1]
    else:
        state, end = "none", now

    entries = transcript(a.projects, a.session)
    sess = Session(entries)
    start = sess.start(pr.get("number"))
    if start and start > merged:
        start = None
    working = sess.working(start, end) if start else None
    waiting = (merged - start).total_seconds() - sess.working(start, merged) if start else None

    def span(x, y):
        return (y - x).total_seconds() if x and y else None

    # Headline
    total = span(start, end) if state in ("live", "failed") else span(start, merged)
    body = dep[2] if dep else ""
    if state == "live":
        head = f"request to live **{dur(total)}**"
    elif state == "failed":
        head = f"**deploy failed** · request to failure **{dur(total)}**"
    elif state == "not-deployed":
        m = re.search(r"\*\*Not deployed\*\* · `\w+` · (.*?); production is unchanged", body)
        head = f"**not deployed** ({m.group(1) if m else 'reason unknown'}) · request to merge **{dur(total)}**"
    elif state == "superseded":
        m = re.search(r"it ships with (`\w+`)'s deploy", body)
        head = f"ships with {m.group(1) if m else 'a newer commit'}'s deploy · request to merge **{dur(total)}**"
    elif state == "unknown":
        head = f"deploy unknown (no final state an hour after the merge) · request to merge **{dur(total)}**"
    else:
        head = f"no deploy comment · request to merge **{dur(total)}**"

    time_parts = [f"{dur(working)} Claude working", f"{dur(waiting)} waiting on you"]
    if state in ("live", "failed"):
        time_parts.append(f"{dur(span(merged, end))} deploying")
    elif state == "unknown":
        time_parts.append("unknown deploying")

    # Your input
    who = owners(pr, reviews, comments)
    if start:
        answers = sum(n for _, t, n in sess.asks if start <= t <= merged) + sum(1 for t, _ in sess.owner if start < t <= merged)
        answers_txt = n_of(answers, "answer in chat", "answers in chat")
    else:
        answers_txt = "unknown answers in chat"
    before = lambda x, k: (ts(x.get(k)) or merged) <= merged  # noqa: E731
    pr_comments = sum(1 for c in comments if (c.get("user") or {}).get("login") in who and before(c, "created_at"))
    pr_comments += sum(1 for c in data.get("review_comments") or [] if (c.get("user") or {}).get("login") in who and before(c, "created_at"))
    pr_comments += sum(1 for r in reviews if r["user"].get("login") in who and r.get("state") != "APPROVED" and (r.get("body") or "").strip() and before(r, "submitted_at"))
    approvals = sum(1 for r in reviews if r["user"].get("login") in who and r.get("state") == "APPROVED")

    # Cost
    session_cost = cost - prev_cost if cost is not None and prev_cost is not None else None
    rounds = [(o, p) for t, o, p in sess.reviews if start and start <= t <= merged]
    reviewer = None
    if rounds:
        costs = [verdict_cost(p) for _, p in rounds]
        reviewer = sum(costs) if all(c is not None for c in costs) else None
    pr_outcomes, pr_costs = reviewer_from_pr(comments)
    if reviewer is None and pr_costs and all(c is not None for c in pr_costs):
        reviewer = sum(pr_costs)
    if not rounds and pr_outcomes:
        rounds = [(o, None) for o in pr_outcomes]
    # No rounds: none ran when the transcript was read from the start; otherwise unknown.
    measured = bool(start)
    if not rounds and measured:
        reviewer = 0.0
    # The total is the sum of the parts as shown, so the line adds up.
    total_cost = round(session_cost, 2) + round(reviewer, 2) if session_cost is not None and reviewer is not None else None

    # Quality
    runs = data.get("runs")
    if runs is None:
        pushes_txt, red_txt = "unknown pushes", "unknown red CI runs"
    else:
        pushes_txt = n_of(len({r.get("head_sha") for r in runs}), "push", "pushes")
        red = sum(1 for r in runs if any(c in ("failure", "timed_out") for c in [r.get("conclusion")] + list(r.get("attempts") or [])))
        red_txt = n_of(red, "red CI run", "red CI runs")
    passed = sum(1 for o, _ in rounds if o == "pass")
    if rounds:
        review_txt = f"reviewer passed {passed} of {len(rounds)}"
    else:
        review_txt = "no reviewer rounds" if measured else "reviewer unknown"

    lines = [
        f"{METRICS_MARK} cost:{'unknown' if cost is None else f'{cost:.4f}'} -->",
        f"**How this change went** · {head}",
        "",
        f"- **Time:** {' · '.join(time_parts)}",
        f"- **Your input:** {answers_txt} · {n_of(pr_comments, 'PR comment', 'PR comments')} · {n_of(approvals, 'approval', 'approvals')}",
        f"- **Cost:** {money(total_cost)} ({money(session_cost)} session + {money(reviewer)} reviewer)",
        f"- **Quality:** {pushes_txt} · {red_txt} · {review_txt}",
    ]
    return 0, "\n".join(lines)


def verdict_cost(path):
    try:
        with open(path, encoding="utf-8") as fh:
            c = json.load(fh).get("reviewer", {}).get("cost_usd")
        return float(c) if c is not None else None
    except (OSError, ValueError, TypeError, AttributeError):
        return None


def announces(ci):
    if not ci or not os.path.exists(ci):
        return False
    try:
        import yaml
    except ImportError:
        raise CantRun("PyYAML is not installed")
    try:
        with open(ci, encoding="utf-8") as fh:
            jobs = (yaml.safe_load(fh) or {}).get("jobs") or {}
    except (OSError, yaml.YAMLError) as e:
        raise CantRun(f"can't read {ci}: {e}")
    return "announce" in jobs


def parse_cost(v, flag):
    if v == "unknown":
        return None
    try:
        x = float(v)
    except (TypeError, ValueError):
        raise CantRun(f"{flag} is not a cost in USD or 'unknown': {v}")
    if x < 0:
        raise CantRun(f"{flag} is negative: {v}")
    return x


def main(argv):
    p = argparse.ArgumentParser(prog="change-metrics.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("render")
    r.add_argument("--pr-data", required=True)
    r.add_argument("--cost", required=True)
    r.add_argument("--prev-cost")
    r.add_argument("--ci")
    r.add_argument("--now")
    q = sub.add_parser("previous-pr")
    q.add_argument("--pr", type=int, required=True)
    for s in (r, q):
        s.add_argument("--projects", default=os.path.expanduser("~/.claude/projects"))
        s.add_argument("--session")
    try:
        a = p.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    try:
        if a.cmd == "previous-pr":
            sess = Session(transcript(a.projects, a.session))
            earlier = sess.earlier_merges(a.pr)
            if earlier:
                print(max(earlier)[1])
            return 0
        if a.now:
            try:
                ts(a.now)
            except ValueError:
                raise CantRun(f"--now is not a time: {a.now}")
        code, out = render(a)
    except CantRun as e:
        print(f"change-metrics: {e}", file=sys.stderr)
        return 2
    print(out, file=sys.stdout if code == 0 else sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
