"""W10.6.8 re-run: replays a recorded plant (results/p-*.plants.json, harness d382e2e, seed 1) on a
worktree, without the harness (this session has no access to it, LOG #46). Runs 1-5 used the same
records, so the replay gives the same plants. Each edit is checked against the record's `before`
text and the script stops if it doesn't match, so a replay never plants something else.

  usage: python3 -I replay-plants.py <worktree> <plants.json>

Per type, as the harness at d382e2e did it (from its records and the verdicts that describe them):
  loosened-test, reworded-acceptance, false-verified: line `line` of `file`, `before` -> `after`
    (indentation kept)
  skipped-state-row: the test starting at line `line` removed through its closing `});`; the blank
    line around it stays, as the old harness left it
  untested-acceptance: the `<item>: ` prefix removed from the one test title in `file` naming it
"""
import json
import re
import sys


def die(msg):
    sys.exit(f"replay-plants: {msg}")


def replay(root, p):
    path = f"{root}/{p['file']}"
    lines = open(path).read().split("\n")
    t = p["type"]
    if t in ("loosened-test", "reworded-acceptance", "false-verified", "skipped-state-row"):
        i = p["line"] - 1
        if i >= len(lines) or lines[i].strip() != p["before"].strip():
            die(f"{p['file']}:{p['line']} is not the recorded line: {p['before']!r}")
        indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
        if t != "skipped-state-row":
            lines[i] = indent + p["after"].strip()
        else:
            end = next((j for j in range(i + 1, len(lines)) if lines[j] == indent + "});"), None)
            if end is None:
                die(f"no closing '}});' for the test at {p['file']}:{p['line']}")
            del lines[i : end + 1]
    elif t == "untested-acceptance":
        pat = re.compile(r"""(\b(?:it|test)\(\s*["'`])""" + re.escape(p["item"]) + r":\s*")
        hits = [j for j, line in enumerate(lines) if pat.search(line)]
        if len(hits) != 1:
            die(f"want exactly one test title starting '{p['item']}:' in {p['file']}, found {len(hits)}")
        lines[hits[0]] = pat.sub(r"\1", lines[hits[0]])
        if any(re.search(r"\b" + re.escape(p["item"]) + r"\b", line) for line in lines):
            die(f"{p['file']} still names {p['item']} after the replay")
    else:
        die(f"unknown plant type {t!r}")
    open(path, "w").write("\n".join(lines))


def main():
    if len(sys.argv) != 3:
        die("usage: replay-plants.py <worktree> <plants.json>")
    for p in json.load(open(sys.argv[2]))["plants"]:
        replay(sys.argv[1], p)


main()
