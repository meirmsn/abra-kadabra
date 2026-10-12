#!/usr/bin/env python3
"""Shape check for a spec written from runtime/templates/spec.md (TARGET § L3 Intent 2 and 6).

Usage: spec-check.py [--go] SPEC_FILE
Checks what can be checked without judgement; whether the spec says what the owner meant is the
spec review's job, and whether the change meets it is the reviewer's.
  - a "# <title>" line, then a **Go:** line: "pending", or the owner's go with its date (YYYY-MM-DD)
  - sections, in order: ## Intent, ## Decisions, ## Acceptance items, ## Core flow (optional),
    ## States (optional), ## Out of scope; none other, none empty
  - Acceptance items holds only items "- **AC-<n>** <what must be true>", numbered AC-1, AC-2, …
    in order; an item may end "verified by review: <the step to demonstrate>"
  - every AC-<n> named anywhere in the spec is one of those items (the reviewer reads every one)
  - States, when present, holds a table
  - no {{placeholder}} left (outside code)
  --go: the **Go:** line records the owner's go (not pending)
Exit 0 = the spec has the shape; 1 = problems (listed); 2 = can't run.
"""
import re
import sys

SECTIONS = ["Intent", "Decisions", "Acceptance items", "Core flow", "States", "Out of scope"]
OPTIONAL = {"Core flow", "States"}
COMMENT = re.compile(r"<!--.*?-->", re.S)
CODE = re.compile(r"^ {0,3}(`{3,}|~{3,}).*?^ {0,3}\1|(`+)[^`\n].*?\2", re.S | re.M)
HEADING = re.compile(r"^ {0,3}(#{1,6})\s+(.*?)\s*#*\s*$", re.M)
GO = re.compile(r"^\*\*Go:\*\*[ \t]*(.*)$", re.M)
DATE = re.compile(r"\b\d{4}-\d{2}-\d{2}\b")
ITEM = re.compile(r"^- \*\*AC-(\d+)\*\*[ \t]*(.*)$")
AC = re.compile(r"\bAC-(\d+)\b")
VBR = re.compile(r"verified by review\b(:\s*(\S.*))?", re.I)


def check(spec, need_go):
    problems = []
    for m in re.finditer(r"\{\{.*?\}\}", CODE.sub("", spec), re.S):
        problems.append(f"placeholder left: {m.group(0)[:60]}")
    text = COMMENT.sub("", spec)

    headings = list(HEADING.finditer(text))
    if not headings or len(headings[0].group(1)) != 1 or not headings[0].group(2):
        problems.append("title: the spec must open with one '# <title>' line")
    preamble = text[: headings[1].start()] if len(headings) > 1 else text
    go = GO.search(preamble)
    if not go:
        problems.append("Go: no '**Go:** pending' (or the owner's recorded go) line before the first section")
    elif need_go:
        if go.group(1).strip().lower() in ("", "pending"):
            problems.append("Go: still pending; --go needs the owner's go recorded on the **Go:** line")
        elif not DATE.search(go.group(1)):
            problems.append("Go: the recorded go has no date (YYYY-MM-DD)")

    body = {}
    order = []
    for i, h in enumerate(headings):
        if len(h.group(1)) != 2:
            continue
        end = next((n.start() for n in headings[i + 1:] if len(n.group(1)) <= 2), len(text))
        name = h.group(2)
        if name not in SECTIONS:
            problems.append(f"section '## {name}': not a spec section (want {', '.join(SECTIONS)})")
            continue
        order.append(name)
        body[name] = text[h.end():end].strip()
        if not body[name]:
            problems.append(f"section '## {name}': empty")
    for name in SECTIONS:
        if name not in order and name not in OPTIONAL:
            problems.append(f"section '## {name}': missing")
    if order != sorted(order, key=SECTIONS.index) or len(order) != len(set(order)):
        problems.append(f"sections out of order or repeated: {', '.join(order)} (want {', '.join(SECTIONS)})")

    items = []
    for line in body.get("Acceptance items", "").splitlines():
        if not line.strip() or line.startswith("  "):  # blank, or a continuation of the item above
            continue
        m = ITEM.match(line)
        if not m:
            problems.append(f"Acceptance items: '{line.strip()[:60]}' is not an item '- **AC-<n>** <text>'")
            continue
        n, what = int(m.group(1)), m.group(2).strip()
        items.append(n)
        if not what:
            problems.append(f"AC-{n}: no text on its line")
        v = VBR.search(what)
        if v and not v.group(2):
            problems.append(f"AC-{n}: 'verified by review' must name the step to demonstrate ('verified by review: <step>')")
    if not items and "Acceptance items" in body:
        problems.append("Acceptance items: no AC-<n> items")
    for want, got in enumerate(items, 1):
        if got != want:
            problems.append(f"Acceptance items: AC-{got} where AC-{want} should be (number them AC-1, AC-2, … in order)")
            break
    for n in sorted({int(x) for x in AC.findall(text)} - set(items)):
        problems.append(f"AC-{n} is named but is not an acceptance item")

    if "States" in body and not re.search(r"^\s*\|.*\|\s*$", body["States"], re.M):
        problems.append("States: no table (one row per state, one column per thing that shows or hides)")
    return problems


def main(argv):
    args = argv[1:]
    need_go = "--go" in args
    args = [a for a in args if a != "--go"]
    if len(args) != 1:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    try:
        with open(args[0], encoding="utf-8") as f:
            spec = f.read()
    except OSError as e:
        print(f"spec-check: can't read {args[0]}: {e}", file=sys.stderr)
        return 2
    problems = check(spec, need_go)
    for p in problems:
        print(f"spec-check: {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
