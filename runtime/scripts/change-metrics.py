#!/usr/bin/env python3
"""How a change went: the metrics comment the session posts on its merged PR once the PR's deploy comment
reaches a final state (specs/deploy-and-metrics-comments.md, part 2; the models and the token split:
specs/metrics-model-and-tokens.md). Computes every number; the model passes only the session's cost, which
no script can read. change-metrics.sh gathers the PR data and posts.

Usage:
  change-metrics.py render --pr-data FILE --cost USD|unknown [--prev-cost USD|unknown]
                           [--prev-posted ISO|unknown] [--ci FILE] [--verdicts DIR]
                           [--now ISO] [--projects DIR] [--session ID]
  change-metrics.py previous-pr --pr N [--merged TIME] [--projects DIR] [--session ID]
render prints the comment. Exit 0 = printed; 3 = not yet: the deploy comment isn't final and less than
60 minutes have passed since the merge; 2 = can't run (bad arguments, an unreadable PR data file, a PR
not merged). previous-pr prints the number of the PR this session merged before PR N, or nothing; --merged is PR N's
merge time, which places a PR the owner merged.

Sources:
  - The transcript: every <session>.jsonl under --projects (default ~/.claude/projects), merged by entry
    uuid (a restarted container resumes the session into a new file holding the old entries); the
    session is --session, else the newest transcript's. None found: the session's numbers are unknown.
    The tokens and models also read the session's subagents, <session>/subagents/agent-*.jsonl, whose
    user entries are no owner messages or wakes. One API message is one assistant entry per content
    block, each repeating its message.id and usage: counted once per id.
  - --prev-posted, the time of the session's previous metrics comment: the tokens and the turns cover
    the session since then (the window --cost minus --prev-cost covers), or the whole session without
    it; "unknown" makes the Tokens line unknown.
  - --pr-data, written by change-metrics.sh: {"pr": the PR, "comments", "reviews", "review_comments",
    "runs": the branch's pull_request runs of the ci workflow (those from the PR's opening to its merge
    count), each with "attempts" (earlier attempts'
    conclusions)}.
  - --verdicts, the reviewer's verdict files for the PR's branch (<git common dir>/devshop/reviews/
    <branch, / as __>), one per round: the rounds and their cost, with the transcript's REVIEW: lines.
  - --ci, the project's workflow as of the merge commit: without an `announce` job the project has no deploy comment, and the
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
FOOTER_MODEL = re.compile(r"Independent reviewer · devshop [^·]* · ([^·]+?) · session ")
USAGE = ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")


class CantRun(Exception):
    pass


def ts(s):
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(timezone.utc)


# --- the transcript ---


def session_id(projects, session):
    """The session: --session, else the newest transcript's; None when there is none."""
    if session:
        return session
    files = glob.glob(os.path.join(projects, "*", "*.jsonl"))
    if not files:
        return None
    return os.path.splitext(os.path.basename(max(files, key=os.path.getmtime)))[0]


def transcript(projects, session):
    """The session's own entries, merged by uuid across its files."""
    session = session_id(projects, session)
    if not session:
        return []
    return read_entries(glob.glob(os.path.join(projects, "*", f"{session}.jsonl")))


def subagents(projects, session):
    """The entries of the session's subagents' transcripts (usage and models only are read from them)."""
    session = session_id(projects, session)
    if not session:
        return []
    return read_entries(glob.glob(os.path.join(projects, "*", session, "subagents", "agent-*.jsonl")))


def read_entries(files):
    seen, entries = set(), []
    for f in sorted(files):
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

    def earlier_merges(self, pr, merged=None):
        """(time, PR) of the other PRs this session merged before `pr` merged: before the session merged
        it, else before `merged` (the PR's merge time: the owner merged it), else all."""
        mine = [t for t, n in self.merges if n == pr]
        cut = min(mine) if mine else merged
        return [(t, n) for t, n in self.merges if n != pr and (cut is None or t < cut)]

    def start(self, pr, merged=None):
        """The clock's start: the first owner message, or the first after this session's last earlier
        merge; with no owner message after that merge (before this PR's), the merge itself: the session
        started this change on its own (specs/metrics-clock-after-merge.md)."""
        after = max((t for t, _ in self.earlier_merges(pr, merged)), default=None)
        firsts = [t for t, _ in self.owner if (after is None or t > after) and (merged is None or t <= merged)]
        return min(firsts) if firsts else after

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


class Usage:
    """The API messages of the assistant entries given (the session's and its subagents'), one per
    message.id (an entry with none is its own message): (time of the first entry, model, counts or None),
    counts being (input, output, cache writes, cache reads)."""

    def __init__(self, entries):
        self.messages, seen = [], set()
        for e in sorted(entries, key=lambda e: e["timestamp"]):
            if e.get("type") != "assistant":
                continue
            m = e.get("message") or {}
            key = m.get("id") or ("entry", e.get("uuid"), e["timestamp"])
            if key in seen:
                continue
            seen.add(key)
            u = m.get("usage")
            counts = None
            if isinstance(u, dict):
                try:
                    counts = tuple(int(u.get(k) or 0) for k in USAGE)
                except (TypeError, ValueError):
                    counts = None
            model = m.get("model")
            self.messages.append((ts(e["timestamp"]), model if isinstance(model, str) and model else None, counts))

    def window(self, start, end):
        return [x for x in self.messages if (start is None or x[0] > start) and x[0] <= end]


def models_of(messages):
    out = []
    for _, model, _ in messages:
        if model and model not in out:
            out.append(model)
    return out


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
    """(outcomes, costs, models) from the reviewer's verdict comments on the PR (ship.sh posts only
    passes); the model is the footer's third field."""
    outcomes, costs, models = [], [], []
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
        f = FOOTER_MODEL.search(body)
        models.append(f.group(1).strip() if f else None)
    return outcomes, costs, models


# --- rendering ---


def dur(seconds):
    if seconds is None:
        return "unknown"
    seconds = max(0, round(seconds))
    if seconds < 600:
        m, s = divmod(seconds, 60)
        return f"{m} min {s} s" if m and s else f"{m} min" if m else f"{s} s"
    minutes = round(seconds / 60)
    if minutes < 60:
        return f"{minutes} min"
    h, m = divmod(minutes, 60)  # an hour or more: hours and minutes (specs/metrics-hours.md)
    return f"{h} h {m} min" if m else f"{h} h"


def n_of(n, one, many):
    return f"{n} {one if n == 1 else many}"


def money(x):
    return "unknown" if x is None else f"${x:.2f}"


def count(n):
    """A token count: plain under 1,000; thousands from there ("36k"); millions with one decimal from
    999,500 ("1M", "3.2M"); half-up throughout (specs/metrics-model-and-tokens.md)."""
    if n is None:
        return "unknown"
    if n < 1000:
        return str(n)
    k = (n + 500) // 1000
    if k < 1000:
        return f"{k}k"
    whole, tenth = divmod((n + 50000) // 100000, 10)
    return f"{whole}.{tenth}M" if tenth else f"{whole}M"


def on(models):
    return " on " + (", ".join(models) if models else "an unknown model")


def render(a):
    try:
        with open(a.pr_data, encoding="utf-8") as fh:
            data = json.load(fh)
        pr = data["pr"]
    except (OSError, ValueError, KeyError) as e:
        raise CantRun(f"can't read the PR data {a.pr_data}: {e}")
    cost = parse_cost(a.cost, "--cost")
    prev_cost = parse_cost(a.prev_cost, "--prev-cost") if a.prev_cost is not None else 0.0
    prev_posted = None  # the tokens' window starts at the session's start
    if a.prev_posted == "unknown":
        prev_posted = "unknown"
    elif a.prev_posted is not None:
        try:
            prev_posted = ts(a.prev_posted)
        except ValueError:
            raise CantRun(f"--prev-posted is not a time or 'unknown': {a.prev_posted}")
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
        state, end = "none", merged  # posted at once, or later: work after the merge is not this change's

    entries = transcript(a.projects, a.session)
    sess = Session(entries)
    usage = Usage(entries + subagents(a.projects, a.session))
    start = sess.start(pr.get("number"), merged)
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

    # Tokens: the session since its previous metrics comment, the window the cost difference covers
    # (specs/metrics-model-and-tokens.md).
    win_start = None if prev_posted in (None, "unknown") else prev_posted
    messages = usage.window(win_start, now)
    session_models = models_of(messages)  # with no window start, the whole session's: names, not counts
    if not entries or prev_posted == "unknown":
        tokens_txt = "unknown"
    else:
        with_usage = [c for _, _, c in messages if c]
        if with_usage:
            sums = [sum(c[i] for c in with_usage) for i in range(4)]
            counts_txt = f"{count(sums[0])} input · {count(sums[1])} output · {count(sums[2])} cache writes · {count(sums[3])} cache reads"
        else:
            counts_txt = "unknown tokens"
        turns = [t for t, _ in sess.owner if (win_start is None or t > win_start) and t <= now]
        wakes = [t for t in sess.wakes if (win_start is None or t > win_start) and t <= now]
        at_merge = [c for t, _, c in usage.messages if c and t <= merged]
        context = count(sum(at_merge[-1][i] for i in (0, 2, 3))) if at_merge else "unknown"
        earlier = sess.earlier_merges(pr.get("number"), merged)
        if win_start is None:
            window_txt = "the whole session"
        elif earlier:
            window_txt = f"the session since its comment on PR #{max(earlier)[1]}"
        else:
            window_txt = "the session since its previous comment"
        tokens_txt = " · ".join([counts_txt, f"{n_of(len(turns) + len(wakes), 'turn', 'turns')} ({n_of(len(wakes), 'wake-up', 'wake-ups')})",
                                 f"{context} context at merge", window_txt])

    # Cost
    session_cost = cost - prev_cost if cost is not None and prev_cost is not None else None
    rounds, corrupt = review_rounds(a.verdicts, (pr.get("head") or {}).get("ref"), sess, start, merged)
    reviewer = None
    if rounds and not corrupt:
        costs = [c for _, c, _ in rounds]
        reviewer = sum(costs) if all(c is not None for c in costs) else None
    pr_outcomes, pr_costs, pr_models = reviewer_from_pr(comments)
    if reviewer is None and not corrupt and pr_costs and all(c is not None for c in pr_costs):
        reviewer = sum(pr_costs)  # a round's verdict file is gone: the PR's footers stand in
    if not rounds and pr_outcomes:
        rounds = [(o, None, m) for o, m in zip(pr_outcomes, pr_models)]
    # The reviewer's models: the verdict files' when any names one, else the footers'.
    reviewer_models = []
    for m in [m for _, _, m in rounds if m] or [m for m in pr_models if m]:
        if m not in reviewer_models:
            reviewer_models.append(m)
    # No rounds: none ran when the transcript was read from the start; otherwise unknown.
    measured = bool(start)
    if not rounds and measured and not corrupt:
        reviewer = 0.0
    # The total is the sum of the parts as shown, so the line adds up.
    total_cost = round(session_cost, 2) + round(reviewer, 2) if session_cost is not None and reviewer is not None else None

    # Quality
    runs = data.get("runs")
    if runs is not None:
        # The branch's runs from the PR's opening to its merge: a session can reuse a branch name for
        # its next PR, and a merged PR's runs no longer name it.
        opened = ts(pr.get("created_at"))
        lo = opened - timedelta(minutes=1) if opened else None
        runs = [r for r in runs if not r.get("created_at") or ((lo is None or ts(r["created_at"]) >= lo) and ts(r["created_at"]) <= merged)]
    if runs is None:
        pushes_txt, red_txt = "unknown pushes", "unknown red CI runs"
    else:
        pushes_txt = n_of(len({r.get("head_sha") for r in runs}), "push", "pushes")
        red = sum(1 for r in runs if any(c in ("failure", "timed_out") for c in [r.get("conclusion")] + list(r.get("attempts") or [])))
        red_txt = n_of(red, "red CI run", "red CI runs")
    passed = sum(1 for o, _, _ in rounds if o == "pass")
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
        f"- **Cost:** {money(total_cost)} ({money(session_cost)} session{on(session_models)} + {money(reviewer)} reviewer{on(reviewer_models) if rounds and reviewer is not None else ''})",
        f"- **Tokens:** {tokens_txt}",
        f"- **Quality:** {pushes_txt} · {red_txt} · {review_txt}",
    ]
    return 0, "\n".join(lines)


def read_verdict(path):
    """The verdict file's JSON object, or None when it is missing or can't be read."""
    try:
        with open(path, encoding="utf-8") as fh:
            v = json.load(fh)
        return v if isinstance(v, dict) else None
    except (OSError, ValueError):
        return None


def review_rounds(vdir, branch, sess, start, merged):
    """([(outcome, cost or None, model or None)], corrupt) for the reviewer's rounds of this change: the numbered
    verdict files in the branch's directory created from the start to a minute after the merge, plus the
    files the transcript's REVIEW: lines name in that window, each once. A could-not-run file is no
    round. corrupt: a file in the window that can't be read, which makes the cost unknown."""
    if not start:
        return [], False  # the directory may hold another change's rounds
    hi = merged + timedelta(minutes=1)
    found, corrupt = {}, False
    for path in sorted(glob.glob(os.path.join(vdir, "[0-9][0-9][0-9]-*.json"))) if vdir else []:
        v = read_verdict(path)
        try:
            when = ts(v.get("created")) if v else None
        except (ValueError, TypeError, AttributeError):
            when = None
        if when is None:  # unreadable, or no readable time: in the window by its file time, it's unknown
            mtime = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc)
            corrupt = corrupt or start <= mtime <= hi
            continue
        if start <= when <= hi and v.get("branch") == branch:
            found[os.path.realpath(path)] = v
    for t, outcome, path in sess.reviews:
        if start <= t <= hi and os.path.realpath(path) not in found:
            v = read_verdict(path) or {}
            v.setdefault("outcome", outcome)
            found[os.path.realpath(path)] = v
    rounds = []
    for v in found.values():
        if v.get("outcome") == "could-not-run":
            continue
        who = v.get("reviewer")
        c = who.get("cost_usd") if isinstance(who, dict) else None
        m = who.get("model") if isinstance(who, dict) else None
        rounds.append((v.get("outcome"), float(c) if isinstance(c, (int, float)) else None, m if isinstance(m, str) and m else None))
    return rounds, corrupt


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
    r.add_argument("--prev-posted")
    r.add_argument("--ci")
    r.add_argument("--verdicts")
    r.add_argument("--now")
    q = sub.add_parser("previous-pr")
    q.add_argument("--pr", type=int, required=True)
    q.add_argument("--merged")
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
            merged = None
            if a.merged:
                try:
                    merged = ts(a.merged)
                except ValueError:
                    raise CantRun(f"--merged is not a time: {a.merged}")
            earlier = sess.earlier_merges(a.pr, merged)
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
