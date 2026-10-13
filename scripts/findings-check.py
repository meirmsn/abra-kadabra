#!/usr/bin/env python3
"""Findings ledger check (W10.6.13, W10.6.14): the mechanical rules of kit/notes/revamp/FINDINGS.md.

Usage: scripts/findings-check.py [--ids] [file]   (default file: kit/notes/revamp/FINDINGS.md)
  --ids: print every row's ID, live and closed, one per line in file order (no checks).

The file has three sections, in this order, each holding one table (text before the table is free):
  ## Fix queue   | ID | Finding | Action | Source | Impact | Risk | Cost | Leverage | Task | Seen |
  ## Watch list  | ID | Finding | Guess | Source | Impact | Seen | Score |
  ## Closed      | ID | Finding | Source | Outcome | Ref |
Grades are a glyph and a size: 🟢🟢 XS, 🟢 S, 🟡 M, 🔴 L, 🔴🔴 XL. Impact and Risk count 1-5; Cost
divides by 0.25 0.75 2.5 5 9.
  Leverage = Impact × Risk ÷ Cost (one decimal), shown with its band: 🔥 5 or more, 🟡 2 to under
  5, ⚪ under 2. Score = Impact × sightings.
Seen is dots toward 5 (●●○○○; past 5, ●●●●● and the count), then one sighting per session that hit
it, `YYYY-MM-DD · what happened`, separated by `<br>`.
The Fix queue is sorted by Leverage, the Watch list by Score, each highest first, ties by Impact.
The rule of 5: a Fix row with Impact XS or S needs 5 sightings; a Watch row with 5 must move to the
Fix queue or be closed. IDs (F-<AREA>-<n> or O-<n>) are unique across the file. Source is `devshop`
or a project's name. Only Ref may be empty; a live table may have no rows, Closed may not.
Exit 0 = clean; 1 = rule broken (each one listed); 2 = can't run (unreadable file, bad arguments).
"""
import os
import re
import sys

HEADERS = {
    "Fix queue": ["ID", "Finding", "Action", "Source", "Impact", "Risk", "Cost", "Leverage", "Task", "Seen"],
    "Watch list": ["ID", "Finding", "Guess", "Source", "Impact", "Seen", "Score"],
    "Closed": ["ID", "Finding", "Source", "Outcome", "Ref"],
}
SECTIONS = list(HEADERS)
MAY_BE_EMPTY = {"Ref"}
SIZE = {"XS": 1, "S": 2, "M": 3, "L": 4, "XL": 5}
GLYPH = {"XS": "🟢🟢", "S": "🟢", "M": "🟡", "L": "🔴", "XL": "🔴🔴"}
COST = {"XS": 0.25, "S": 0.75, "M": 2.5, "L": 5, "XL": 9}
LOW_IMPACT = {"XS", "S"}
FIVE = 5

ID = re.compile(r"F-[A-Z]+-\d+|O-\d+")
SECTION = re.compile(r"^## (.+?)\s*$")
SOURCE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
GRADE = re.compile(r"^(\S+) (XS|S|M|L|XL)$")
LEVERAGE = re.compile(r"^(🔥|🟡|⚪) (\d+(?:\.\d+)?)$")
SEEN = re.compile(r"^([●○]{5})(?: (\d+))? (.+)$")
SIGHTING = re.compile(r"^\d{4}-\d{2}-\d{2} · \S")
SEPARATOR = re.compile(r"^:?-{3,}:?$")
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
    """Return {section name: [(line number, line)]} for the three known sections."""
    found, order, current = {}, [], None
    for n, line in enumerate(lines, 1):
        m = SECTION.match(line)
        if m:
            current = m.group(1) if m.group(1) in SECTIONS else None
            if current in found:
                err(f"'## {current}' appears twice (line {n})")
                current = None
            elif current:
                found[current] = []
                order.append(current)
            continue
        if current:
            found[current].append((n, line))
    for name in SECTIONS:
        if name not in found:
            err(f"no '## {name}' section")
    if order != [s for s in SECTIONS if s in order]:
        err(f"sections must come in the order: {', '.join(SECTIONS)}")
    return found


def read_table(section, body):
    """Return the table's rows as [{column: cell}], checking its header, separator and shape."""
    lines = [(n, ln) for n, ln in body if ln.strip()]
    start = next((i for i, (_n, ln) in enumerate(lines) if ln.lstrip().startswith("|")), None)
    if start is None:
        err(f"{section}: no table")
        return []
    header = HEADERS[section]
    if cells(lines[start][1]) != header:
        err(f"{section}: header must be | {' | '.join(header)} |")
        return []
    sep = cells(lines[start + 1][1]) if start + 1 < len(lines) else None
    if not sep or len(sep) != len(header) or not all(SEPARATOR.match(c) for c in sep):
        err(f"{section}: the header needs a separator row")
        return []
    rows = []
    for n, line in lines[start + 2:]:
        row = cells(line)
        if row is None:
            err(f"{section}: unexpected line {n}: {line.strip()[:60]}")
            continue
        label = row[0] if row and ID.fullmatch(row[0]) else f"line {n}"
        if section == "Closed":
            label = f"Closed row {label}"
        if len(row) != len(header):
            err(f"{label}: {len(row)} cells, want {len(header)}")
            continue
        if not ID.fullmatch(row[0]):
            err(f"{section} line {n}: bad ID '{row[0]}'")
            continue
        rec = dict(zip(header, row))
        rec["_label"] = label
        for col in header:
            if not rec[col] and col not in MAY_BE_EMPTY:
                err(f"{label}: empty {col}")
        if rec["Source"] and not SOURCE.match(rec["Source"]):
            err(f"{label}: bad Source '{rec['Source']}': want 'devshop' or a project's name (lowercase)")
        rows.append(rec)
    if not rows and section == "Closed":
        err(f"{section}: no rows")  # a live list may be empty: every finding moved or closed
    return rows


def grade(label, col, cell):
    """Return the size of a 'glyph size' cell, or None."""
    m = GRADE.match(cell)
    if not m:
        err(f"{label}: bad {col} '{cell}': want a glyph and XS S M L XL, e.g. '🟡 M'")
        return None
    glyph, size = m.groups()
    if glyph != GLYPH[size]:
        err(f"{label}: {col} {size} needs {GLYPH[size]}")
    return size


def sightings(label, cell):
    """Return the number of sightings in a Seen cell, or None."""
    m = SEEN.match(cell)
    if not m:
        err(f"{label}: bad Seen '{cell[:40]}': want dots (●○○○○) then 'YYYY-MM-DD · what happened'")
        return None
    dots, count, rest = m.groups()
    items = [s.strip() for s in rest.split("<br>")]
    for s in items:
        if not SIGHTING.match(s):
            err(f"{label}: bad sighting '{s[:40]}': want 'YYYY-MM-DD · what happened'")
    n = len(items)
    want = "●" * min(n, FIVE) + "○" * (FIVE - min(n, FIVE))
    shown = dots + (f" {count}" if count else "")
    want_shown = want + (f" {n}" if n > FIVE else "")
    if shown != want_shown:
        err(f"{label}: Seen shows {shown} but has {n} sighting{'s' if n != 1 else ''} (want {want_shown})")
    return n


def band(lev):
    return "🔥" if lev >= 5 else "🟡" if lev >= 2 else "⚪"


def check_fix(rec):
    label = rec["_label"]
    impact, risk, cost = (grade(label, c, rec[c]) for c in ("Impact", "Risk", "Cost"))
    seen = sightings(label, rec["Seen"])
    m = LEVERAGE.match(rec["Leverage"])
    if not m:
        err(f"{label}: bad Leverage '{rec['Leverage']}': want its band and value, e.g. '🔥 6.4'")
        return None
    if None in (impact, risk, cost):
        return None
    want = round(SIZE[impact] * SIZE[risk] / COST[cost], 1)
    shown_band, value = m.groups()
    if abs(float(value) - want) > 0.05:
        err(f"{label}: Leverage {value} should be {want:g}")
    if shown_band != band(want):
        err(f"{label}: Leverage {value} needs {band(want)}")
    if seen is not None and impact in LOW_IMPACT and seen < FIVE:
        err(f"{label}: impact {impact} in the Fix queue needs {FIVE} sightings (has {seen}); keep it on the Watch list")
    return (want, SIZE[impact])


def check_watch(rec):
    label = rec["_label"]
    impact = grade(label, "Impact", rec["Impact"])
    seen = sightings(label, rec["Seen"])
    if impact is None or seen is None:
        return None
    if not rec["Score"].isdigit() or int(rec["Score"]) != SIZE[impact] * seen:
        err(f"{label}: Score {rec['Score']} should be {SIZE[impact] * seen} (Impact {impact} × {seen})")
    if seen >= FIVE:
        err(f"{label}: seen {seen} times: move it to the Fix queue or close it as held, with a reason")
    return (SIZE[impact] * seen, SIZE[impact])


def main(argv):
    args = argv[1:]
    ids_only = bool(args) and args[0] == "--ids"
    if ids_only:
        args = args[1:]
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
    for section, check in (("Fix queue", check_fix), ("Watch list", check_watch), ("Closed", None)):
        if section not in sections:
            continue
        keyed = []
        for rec in read_table(section, sections[section]):
            ids.append(rec["ID"])
            key = check(rec) if check else None
            if key is not None:
                keyed.append((key, rec["ID"]))
        for (a, ida), (b, idb) in zip(keyed, keyed[1:]):
            if b > a:
                err(f"{section} out of order: {idb} ranks above {ida}")

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
