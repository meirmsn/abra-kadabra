#!/usr/bin/env python3
"""Shape check for a spec written from runtime/templates/spec.md (TARGET § L3 Intent 2 and 6).

Usage: spec-check.py [--go] [--tests PATH]... SPEC...
SPEC is a spec file, or a directory whose *.md files (below it too) are specs; a directory with none
passes and says so. Checks what can be checked without judgement; whether the spec says what the
owner meant is the spec review's job, and whether the change meets it is the reviewer's.
  - a "# <title>" line, then a **Go:** line: "pending", or the owner's go with its date (YYYY-MM-DD)
  - sections, in order: ## Intent, ## Decisions, ## Acceptance items, ## Core flow (optional),
    ## States (optional), ## Out of scope; none other, none empty
  - Acceptance items holds only items "- **AC-<n>** <what must be true>", numbered AC-1, AC-2, …
    in order; an item may end "verified by review: <the step to demonstrate>" (an item goes on over
    its indented continuation lines)
  - every AC-<n> named anywhere in the spec is one of those items (the reviewer reads every one)
  - States, when present, holds a table
  - no two specs share a file name (a test's "<spec> AC-<n>" names one spec's item)
  - no {{placeholder}} left (outside code)
  --go: the **Go:** line records the owner's go (not pending)
  --tests PATH: the acceptance→test check (TARGET Verify; project CI runs it). Every AC-<n> not
    marked "verified by review" is named as "<spec> AC-<n>", the spec's file name without ".md"
    and one space before it (specs/cart.md's AC-2: "cart AC-2"), in a file under one of the PATHs
    (a file, or every file below a directory; node_modules and dot-directories skipped). AC numbers
    are per spec, so a bare AC-2, or another spec's, names nothing (F-NEW-92). It reads names, not
    tests: whether the test proves the item is the reviewer's job. A PATH that doesn't exist, or no
    files under the PATHs, can't run.
Exit 0 = every spec has the shape (and its tests); 1 = problems (listed); 2 = can't run (a missing
or unreadable spec or test path, bad arguments).
"""
import os
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


def check(spec, need_go, tests=None, spec_id=""):
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

    items = []  # [number, its text with continuation lines, its line's text]
    for line in body.get("Acceptance items", "").splitlines():
        if not line.strip():
            continue
        if line.startswith("  "):  # a continuation of the item above
            if items:
                items[-1][1] += " " + line.strip()
            continue
        m = ITEM.match(line)
        if not m:
            problems.append(f"Acceptance items: '{line.strip()[:60]}' is not an item '- **AC-<n>** <text>'")
            continue
        items.append([int(m.group(1)), m.group(2).strip(), m.group(2).strip()])
    reviewed = set()
    for n, what, first in items:
        if not first:
            problems.append(f"AC-{n}: no text on its line")
        v = VBR.search(what)
        if v:
            reviewed.add(n)
            if not v.group(2):
                problems.append(f"AC-{n}: 'verified by review' must name the step to demonstrate ('verified by review: <step>')")
    items = [n for n, _, _ in items]
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
    if tests is not None:
        for n in sorted(set(items) - reviewed):
            if not re.search(rf"(?<![\w./-]){re.escape(spec_id)} AC-{n}(?!\d)", tests):
                problems.append(f"AC-{n}: no test names it (put '{spec_id} AC-{n}' in the name of the test that proves it, or mark the item 'verified by review: <step>')")
    return problems


class CantRun(Exception):
    pass


def raise_cant_run(e):
    raise CantRun(f"can't read {e.filename}: {e.strerror}")


def walk(path, want):
    """The files at path: itself, or those below it (node_modules and dot-directories skipped)."""
    if os.path.isfile(path):
        return [path]
    if not os.path.isdir(path):
        raise CantRun(f"no such file or directory: {path}")
    found = []
    for root, dirs, files in os.walk(path, onerror=raise_cant_run):
        dirs[:] = sorted(d for d in dirs if d != "node_modules" and not d.startswith("."))
        found += [os.path.join(root, f) for f in sorted(files) if want(f)]
    return found


def read(path, errors):
    try:
        with open(path, encoding="utf-8", errors=errors) as f:
            return f.read()
    except (OSError, UnicodeDecodeError) as e:
        raise CantRun(f"can't read {path}: {e}")


def spec_name(path):
    """The name a test puts before AC-<n>: the spec's file name without .md."""
    return os.path.splitext(os.path.basename(path))[0]


def main(argv):
    args, need_go, test_paths = argv[1:], False, []
    specs = []
    while args:
        a = args.pop(0)
        if a == "--go":
            need_go = True
        elif a == "--tests":
            if not args:
                specs = []
                break
            test_paths.append(args.pop(0))
        else:
            specs.append(a)
    if not specs:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    try:
        tests = None
        if test_paths:
            files = [f for p in test_paths for f in walk(p, lambda f: not f.startswith("."))]
            if not files:
                raise CantRun(f"no test files under {', '.join(test_paths)}")
            tests = "\n".join(read(f, "replace") for f in files)
        found = []
        for p in specs:
            if os.path.isdir(p):
                mds = walk(p, lambda f: f.endswith(".md"))
                if not mds:
                    print(f"spec-check: no specs in {p}")
                found += mds
            elif os.path.exists(p):
                found.append(p)
            else:
                raise CantRun(f"can't read {p}: no such file")
        seen = set()  # a spec passed twice, or by two paths, is one spec
        found = [p for p in found if not (os.path.realpath(p) in seen or seen.add(os.path.realpath(p)))]
        problems = []
        by_name = {}
        for p in found:
            by_name.setdefault(spec_name(p), []).append(p)
        for n, ps in sorted(by_name.items()):
            if len(ps) > 1:
                problems.append(f"{', '.join(ps)}: specs with the same file name; a test's '{n} AC-<n>' would name each one's items")
        problems += [f"{p}: {x}" for p in found for x in check(read(p, "strict"), need_go, tests, spec_name(p))]
    except CantRun as e:
        print(f"spec-check: {e}", file=sys.stderr)
        return 2
    for p in problems:
        print(f"spec-check: {p}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
