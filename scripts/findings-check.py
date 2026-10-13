#!/usr/bin/env python3
"""Findings ledger check (W10.6.13): the mechanical rules of kit/notes/revamp/FINDINGS.md.

Usage: scripts/findings-check.py [--ids] [file]   (default file: kit/notes/revamp/FINDINGS.md)
  --ids: print every entry's ID, live and closed, one per line in file order (no checks).

The file has three sections, in this order: `## Fix queue`, `## Watch list`, `## Closed`. Text before
the first is free. A live entry is `### <ID> · <title>` followed by `- **Field:** value` lines (an
indented line continues the field above):
  Fix queue:  Source, Grades (Impact · Risk · Cost · Leverage), Observation, Action, Task, Seen (n)
  Watch list: Source, Grades (Impact · Score), Observation, Guess, Seen (n)
Seen (n) is followed by exactly n lines `  - YYYY-MM-DD · <what happened>` (one per session that hit
it; a line indented four spaces continues the sighting above).
Grades use XS S M L XL. Impact and Risk count 1-5; Cost divides by 0.25 0.75 2.5 5 9.
  Leverage = Impact × Risk ÷ Cost (one decimal)    Score = Impact × n
The Fix queue is sorted by Leverage, the Watch list by Score, each highest first, ties by Impact.
The rule of 5: a Fix entry with Impact XS or S needs n >= 5; a Watch entry with n >= 5 must be
moved to the Fix queue or closed. Closed is one table: | ID | Finding | Source | Outcome | Ref |.
IDs (F-<AREA>-<n> or O-<n>) are unique across the file. Source is `devshop` or a project's name.
Exit 0 = clean; 1 = rule broken (each one listed); 2 = can't run (unreadable file, bad arguments).
"""
import os
import re
import sys

SECTIONS = ["Fix queue", "Watch list", "Closed"]
FIELDS = {
    "Fix queue": ["Source", "Grades", "Observation", "Action", "Task", "Seen"],
    "Watch list": ["Source", "Grades", "Observation", "Guess", "Seen"],
}
SIZE = {"XS": 1, "S": 2, "M": 3, "L": 4, "XL": 5}
COST = {"XS": 0.25, "S": 0.75, "M": 2.5, "L": 5, "XL": 9}
CLOSED_HEADER = ["ID", "Finding", "Source", "Outcome", "Ref"]
LOW_IMPACT = {"XS", "S"}
FIVE = 5

ID = r"(?:F-[A-Z]+-\d+|O-\d+)"
SECTION = re.compile(r"^## (.+?)\s*$")
ENTRY = re.compile(rf"^### ({ID}) · (\S.*)$")
FIELD = re.compile(r"^- \*\*([A-Za-z]+)(?: \((\d+)\))?:\*\*(.*)$")
SEEN_LINE = re.compile(r"^  - \d{4}-\d{2}-\d{2} · \S")
SOURCE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
GRADE = r"(XS|S|M|L|XL)"
NUM = r"(\d+(?:\.\d+)?)"
FIX_GRADES = re.compile(rf"^Impact {GRADE} · Risk {GRADE} · Cost {GRADE} · Leverage {NUM}$")
WATCH_GRADES = re.compile(rf"^Impact {GRADE} · Score (\d+)$")
CELL_SPLIT = re.compile(r"(?<!\\)\|")

errors = []


def err(msg):
    errors.append(msg)


def cells(line):
    parts = CELL_SPLIT.split(line.strip())
    if len(parts) < 2 or parts[0] != "" or parts[-1] != "":
        return None
    return [c.strip() for c in parts[1:-1]]


def split_sections(lines):
    """Return {section name: [(line number, line)]} for the three known sections, in file order."""
    found, order, current = {}, [], None
    for n, line in enumerate(lines, 1):
        m = SECTION.match(line)
        if m:
            name = m.group(1)
            current = name if name in SECTIONS else None
            if current:
                if current in found:
                    err(f"'## {current}' appears twice (line {n})")
                    current = None
                    continue
                found[current] = []
                order.append(current)
            continue
        if current:
            found[current].append((n, line))
    for name in SECTIONS:
        if name not in found:
            err(f"no '## {name}' section")
    if [s for s in order] != [s for s in SECTIONS if s in order]:
        err(f"sections must come in the order: {', '.join(SECTIONS)}")
    return found


def parse_entries(section, body):
    """Return [(id, line number, {field: (count, value, [continuation lines])})]."""
    entries, cur, field = [], None, None
    for n, line in body:
        if not line.strip():
            continue
        if line.startswith("### "):
            m = ENTRY.match(line)
            if not m:
                err(f"{section}: bad entry heading (line {n}): want '### <ID> · <title>'")
                cur, field = None, None
                continue
            cur = (m.group(1), n, {})
            entries.append(cur)
            field = None
            continue
        if cur is None:
            continue  # free text before the first entry
        m = FIELD.match(line)
        if m:
            name, count, value = m.group(1), m.group(2), m.group(3).strip()
            if name in cur[2]:
                err(f"{cur[0]}: field {name} twice")
            cur[2][name] = (count, value, [])
            field = name
            continue
        if line.startswith("  ") and field:
            cur[2][field][2].append(line)
            continue
        err(f"{cur[0]}: unexpected line {n}: {line.strip()[:60]}")
    return entries


def check_entry(section, eid, fields):
    """Check one live entry; return its sort key or None."""
    want = FIELDS[section]
    for name in fields:
        if name not in want:
            err(f"{eid}: unknown field {name}" + (" (want 'Seen (n)')" if name == "Seen" else ""))
    for name in want:
        if name not in fields:
            err(f"{eid}: missing field {name}")
    for name, (count, value, more) in fields.items():
        if name in want and name != "Seen" and not value and not more:
            err(f"{eid}: empty field {name}")
    if "Source" in fields and not SOURCE.match(fields["Source"][1]):
        err(f"{eid}: bad Source '{fields['Source'][1]}': want 'devshop' or a project's name (lowercase)")

    seen = None
    if "Seen" in fields:
        count, value, more = fields["Seen"]
        if count is None:
            err(f"{eid}: unknown field Seen (want 'Seen (n)')")
        else:
            if value:
                err(f"{eid}: Seen ({count}) puts its lines below it, one per sighting")
            seen = 0
            for ln in more:
                if SEEN_LINE.match(ln):
                    seen += 1
                elif ln.startswith("    ") and seen:
                    continue  # a long sighting wrapped onto the next line
                else:
                    err(f"{eid}: bad Seen line '{ln.strip()[:60]}': want '  - YYYY-MM-DD · what happened'")
            if int(count) != seen:
                err(f"{eid}: Seen ({count}) but {seen} line{'s' if seen != 1 else ''}")
            if seen == 0:
                err(f"{eid}: Seen needs at least one line")

    if "Grades" not in fields:
        return None
    grades = fields["Grades"][1]
    if section == "Fix queue":
        m = FIX_GRADES.match(grades)
        if not m:
            err(f"{eid}: bad Grades '{grades}': want 'Impact <g> · Risk <g> · Cost <g> · Leverage <n>', g in XS S M L XL")
            return None
        impact, risk, cost, lev = m.groups()
        want_lev = round(SIZE[impact] * SIZE[risk] / COST[cost], 1)
        if abs(float(lev) - want_lev) > 0.05:
            err(f"{eid}: Leverage {lev} should be {want_lev:g}")
        if seen is not None and impact in LOW_IMPACT and seen < FIVE:
            err(f"{eid}: impact {impact} in the Fix queue needs {FIVE} sightings (has {seen}); keep it on the Watch list")
        return (want_lev, SIZE[impact])
    m = WATCH_GRADES.match(grades)
    if not m:
        err(f"{eid}: bad Grades '{grades}': want 'Impact <g> · Score <n>', g in XS S M L XL")
        return None
    impact, score = m.groups()
    if seen is not None:
        if int(score) != SIZE[impact] * seen:
            err(f"{eid}: Score {score} should be {SIZE[impact] * seen} (Impact {impact} × {seen})")
        if seen >= FIVE:
            err(f"{eid}: seen {seen} times: move it to the Fix queue or close it as held, with a reason")
    return (SIZE[impact] * (seen or 0), SIZE[impact])


def check_closed(body, ids):
    rows = [(n, line) for n, line in body if line.strip()]
    if not rows:
        err("Closed: no table")
        return
    header = cells(rows[0][1])
    if header != CLOSED_HEADER:
        err(f"Closed: header must be | {' | '.join(CLOSED_HEADER)} |")
        return
    sep = cells(rows[1][1]) if len(rows) > 1 else None
    if not sep or not all(re.fullmatch(r":?-{3,}:?", c) for c in sep) or len(sep) != len(CLOSED_HEADER):
        err("Closed: the header needs a separator row")
        return
    if len(rows) == 2:
        err("Closed: no rows")
    for n, line in rows[2:]:
        row = cells(line)
        if row is None:
            err(f"Closed: unexpected line {n}: {line.strip()[:60]}")
            continue
        label = row[0] if row and re.fullmatch(ID, row[0]) else f"line {n}"
        if len(row) != len(CLOSED_HEADER):
            err(f"Closed row {label}: {len(row)} cells, want {len(CLOSED_HEADER)}")
            continue
        rid, finding, source, outcome, _ref = row
        if not re.fullmatch(ID, rid):
            err(f"Closed row {label}: bad ID '{rid}'")
            continue
        if not finding:
            err(f"Closed row {rid}: empty Finding")
        if not outcome:
            err(f"Closed row {rid}: empty Outcome")
        if not SOURCE.match(source):
            err(f"Closed row {rid}: bad Source '{source}'")
        ids.append(rid)


def main(argv):
    ids_only = False
    args = argv[1:]
    if args and args[0] == "--ids":
        ids_only, args = True, args[1:]
    if len(args) > 1 or (args and args[0].startswith("-")):
        print(__doc__, file=sys.stderr)
        return 2
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    path = args[0] if args else os.path.join(root, "kit/notes/revamp/FINDINGS.md")
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except (OSError, UnicodeDecodeError) as e:
        print(f"FAIL: can't read {path}: {e}", file=sys.stderr)
        return 2

    sections = split_sections(lines)
    ids = []
    for section in ("Fix queue", "Watch list"):
        keys = []
        for eid, _n, fields in parse_entries(section, sections.get(section, [])):
            ids.append(eid)
            key = check_entry(section, eid, fields)
            if key is not None:
                keys.append((key, eid))
        for (a, ida), (b, idb) in zip(keys, keys[1:]):
            if b > a:
                err(f"{section} out of order: {idb} ranks above {ida}")
    if "Closed" in sections:
        check_closed(sections["Closed"], ids)

    if ids_only:
        print("\n".join(ids))
        return 0
    seen_ids = set()
    for i in ids:
        if i in seen_ids:
            err(f"{i}: ID appears twice")
        seen_ids.add(i)
    if errors:
        for e in errors:
            print(f"FAIL: {e}")
        print(f"{len(errors)} problem{'s' if len(errors) != 1 else ''} in {path}")
        return 1
    print(f"ok: {path} ({len(ids)} findings)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
