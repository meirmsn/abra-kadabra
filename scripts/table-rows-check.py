#!/usr/bin/env python3
"""Compact-row check for the record tables (specs/parallel-safe-shared-files.md AC-13).

Usage: scripts/table-rows-check.py FILE...   (lint runs it on FINDINGS.md and ROADMAP.md)
A formatter pads each column of a Markdown table to its longest cell, so one row with a longer cell
rewrites every row, and parallel branches that each add a row conflict on all of them. The record
tables are kept out of the formatter (.prettierignore) and written compact: "| a | b |", one space
beside each pipe. A table row is a line that starts with "|"; it fails when two or more spaces sit
beside a pipe.
Exit 0 = every row compact; 1 = padded rows (listed as path:line); 2 = can't run (no FILE, a file
that can't be read, a file with no table).
"""
import re
import sys

PADDED = re.compile(r" {2,}\||\| {2,}")


def main(files):
    if not files:
        print("usage: table-rows-check.py FILE...")
        return 2
    problems, cant = [], []
    for f in files:
        try:
            with open(f, encoding="utf-8") as fh:
                lines = fh.read().splitlines()
        except (OSError, UnicodeDecodeError) as e:
            cant.append(f"{f}: can't read ({e})")
            continue
        rows = [(i, l) for i, l in enumerate(lines, 1) if l.startswith("|")]
        if not rows:
            cant.append(f"{f}: no table")
            continue
        problems += [f"{f}:{i}: a padded table row; write it compact, one space beside each pipe" for i, l in rows if PADDED.search(l)]
    for p in problems + cant:
        print(p)
    if cant:
        return 2
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
