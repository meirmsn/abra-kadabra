#!/usr/bin/env python3
"""Grades one run of a skills-eval case from its stream and its repo (specs/skills-eval.md).

Usage:
  grade.py grade --case CASE --stream FILE --sha SHA --repo DIR --base REV --spec-check FILE
      Prints one line, "PASS|FAIL|CNR <reason>", and exits 0, 1 or 2 to match.
  grade.py facts --stream FILE
      Prints "model=<id> cli=<version> cost=<usd> time=<s> refused=<n>" from the stream (a field it
      can't read is "?"). Exit 0, or 2 when the stream isn't JSON lines.

FILE is a `claude -p --output-format stream-json --verbose` stream, every turn's appended in order.
Could-not-run (CNR) before any grading: a stream that isn't JSON lines, no init event, a session
whose devshop line doesn't name SHA (it ran another version), no devshop:intent among its skills, or
a turn that didn't end in success. Never a pass.

Cases, each check quoting the skill line it tests:
  trigger  intent: "Every request starts here": devshop:intent is loaded before any Write, Edit,
           MultiEdit or NotebookEdit call. intent § 3: "nothing is built before the "go"": the repo
           changed only under specs/ against REV, untracked files included. intent § 3: "Run
           spec-check.py ... until it passes": a spec was written there and passes --spec-check.
"""
import json
import re
import subprocess
import sys

WRITES = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
DEVSHOP_LINE = re.compile(r"DEVSHOP: using \S+ \(([0-9a-f]{12})\)")


def events(path):
    with open(path, encoding="utf-8") as f:
        lines = [line for line in f if line.strip()]
    if not lines:
        raise ValueError("the stream is empty")
    out = []
    for n, line in enumerate(lines, 1):
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            raise ValueError(f"the stream isn't JSON lines (line {n})")
    return out


def tool_uses(evs):
    for e in evs:
        if e.get("type") == "assistant":
            for c in (e.get("message") or {}).get("content") or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    yield c


def precheck(evs, sha):
    """None, or the could-not-run reason."""
    inits = [e for e in evs if e.get("type") == "system" and e.get("subtype") == "init"]
    if not inits:
        return "no init event: the session didn't start"
    starts = [str(e.get("output", "")) + str(e.get("stdout", "")) for e in evs
              if e.get("type") == "system" and e.get("hook_event") == "SessionStart"
              and e.get("subtype") == "hook_response"]
    ran = {m for s in starts for m in DEVSHOP_LINE.findall(s)}
    if not ran:
        return "no DEVSHOP line at session start: the devshop's hook didn't run"
    if ran != {sha[:12]}:
        return f"the session ran devshop {', '.join(sorted(ran))}, not {sha[:12]}"
    if "devshop:intent" not in (inits[0].get("skills") or []):
        return "devshop:intent isn't among the session's skills"
    results = [e for e in evs if e.get("type") == "result"]
    if not results:
        return "no result event: the turn didn't finish"
    bad = [r.get("subtype") for r in results if r.get("subtype") != "success" or r.get("is_error")]
    if bad:
        return f"a turn ended {bad[0]}"
    return None


def changed(repo, base):
    def git(*a):
        return subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True, check=True).stdout.split("\n")
    files = git("diff", "--name-only", base) + git("ls-files", "--others", "--exclude-standard")
    return sorted({f for f in files if f})


def trigger(evs, repo, base, spec_check):
    first_write = first_intent = None
    for i, t in enumerate(tool_uses(evs)):
        if t.get("name") == "Skill" and (t.get("input") or {}).get("skill") == "devshop:intent" and first_intent is None:
            first_intent = i
        if t.get("name") in WRITES and first_write is None:
            first_write = (i, (t.get("input") or {}).get("file_path", "?"))
    if first_intent is None:
        return 1, 'devshop:intent was never loaded (intent: "Every request starts here")'
    if first_write is not None and first_write[0] < first_intent:
        return 1, f'{first_write[1]} was written before devshop:intent was loaded (intent: "Every request starts here")'
    files = changed(repo, base)
    outside = [f for f in files if not f.startswith("specs/")]
    if outside:
        return 1, f'changed outside specs/ before any go: {", ".join(outside)} (intent § 3: "nothing is built before the go")'
    specs = [f for f in files if f.endswith(".md")]
    if not specs:
        return 1, "no spec written under specs/ (intent § 3: fill the template into specs/<change>.md)"
    r = subprocess.run([spec_check, *specs], cwd=repo, capture_output=True, text=True)
    if r.returncode != 0:
        why = " ".join((r.stdout + r.stderr).split())[:200]
        return 1, f"the spec fails spec-check.py: {why} (intent § 3: run it until it passes)"
    return 0, f"intent loaded first; only {', '.join(specs)} written; spec-check passes"


CASES = {"trigger": trigger}


def opts(argv, names):
    got = {}
    while argv:
        k = argv.pop(0)
        if not k.startswith("--") or k[2:] not in names or not argv:
            raise ValueError(f"bad argument '{k}'")
        got[k[2:]] = argv.pop(0)
    missing = [n for n in names if n not in got]
    if missing:
        raise ValueError(f"missing --{missing[0]}")
    return got


def main(argv):
    if not argv or argv[0] not in ("grade", "facts"):
        print("CNR usage: grade.py grade|facts ...")
        return 2
    try:
        if argv[0] == "facts":
            o = opts(argv[1:], ["stream"])
            evs = events(o["stream"])
            init = next((e for e in evs if e.get("type") == "system" and e.get("subtype") == "init"), {})
            results = [e for e in evs if e.get("type") == "result"]
            cost = sum(float(r.get("total_cost_usd") or 0) for r in results)
            secs = sum(int(r.get("duration_ms") or 0) for r in results) / 1000
            refused = sum(len(r.get("permission_denials") or []) for r in results)
            print(f"model={init.get('model', '?')} cli={init.get('claude_code_version', '?')} "
                  f"cost={cost:.2f} time={secs:.0f} refused={refused if results else '?'}")
            return 0
        o = opts(argv[1:], ["case", "stream", "sha", "repo", "base", "spec-check"])
        if o["case"] not in CASES:
            print(f"CNR unknown case '{o['case']}'")
            return 2
        evs = events(o["stream"])
    except (OSError, ValueError) as e:
        print(f"CNR {e}")
        return 2
    why = precheck(evs, o["sha"])
    if why:
        print(f"CNR {why}")
        return 2
    try:
        rc, reason = CASES[o["case"]](evs, o["repo"], o["base"], o["spec-check"])
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"CNR couldn't read the repo: {e}")
        return 2
    print(f"{'PASS' if rc == 0 else 'FAIL'} {reason}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
