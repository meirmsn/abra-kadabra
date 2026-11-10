#!/usr/bin/env python3
"""Fails a test that hard-codes how many items a collection holds (specs/parallel-safe-shared-files.md).

Usage: count-check.py --tests PATH [--tests PATH]... COLLECTION...
Parallel branches that each add an item to a collection (a page, a game, a route) conflict on every
test that states the collection's current count, and each new item breaks the older items' tests
(guidelines/parallel.md). A test takes the count from the collection instead.

COLLECTION is a directory (its entries, files and subdirectories, dot-entries skipped), a .json file
holding an array, or <file>.json#<key>, an array under that top-level key. One of fewer than 2 items
is too small to check: it passes and says so.
PATH is a file, or every file below a directory (node_modules and dot-directories skipped), as
spec-check.py --tests reads it.
A line fails when it asserts a collection's current count N as a number literal, in one of these
single-line forms: toHaveLength(N), toHaveCount(N), .length).toBe(N), .length).toEqual(N),
.length === N, .length == N, N === <x>.length, .count()).toBe(N), assert.equal(<x>.length, N),
assert.strictEqual(<x>.length, N), assert len(<x>) == N, N == len(<x>), assertEqual(len(<x>), N).
A line this misreads carries the marker "count-check: allow" in a comment, which the reviewer sees.
It is a heuristic over single lines: a count held in a constant, or an assertion over several lines,
is not seen.
Exit 0 = no line hard-codes a count; 1 = lines that do (listed as path:line); 2 = can't run (a missing
or unreadable collection or path, no test files, bad arguments).
"""
import json
import os
import re
import sys

ALLOW = "count-check: allow"
TOO_SMALL = 2
N = r"(?<![\w.])(\d+)(?![\w.])"
FORMS = [
    r"\btoHaveLength\(\s*" + N + r"\s*\)",
    r"\btoHaveCount\(\s*" + N + r"\s*\)",
    r"\.length\s*\)\s*\.toBe\(\s*" + N + r"\s*\)",
    r"\.length\s*\)\s*\.toEqual\(\s*" + N + r"\s*\)",
    r"\.length\s*===\s*" + N,
    r"\.length\s*==\s*" + N,
    N + r"\s*===\s*[\w$.\[\]()]+\.length\b",
    r"\.count\(\)\s*\)\s*\.toBe\(\s*" + N + r"\s*\)",
    r"\bassert\.equal\(\s*[^,]*\.length\s*,\s*" + N + r"\s*\)",
    r"\bassert\.strictEqual\(\s*[^,]*\.length\s*,\s*" + N + r"\s*\)",
    r"\bassert\s+len\(.*\)\s*==\s*" + N,
    N + r"\s*==\s*len\(",
    r"\bassertEqual\(\s*len\(.*\)\s*,\s*" + N + r"\s*\)",
]
PATTERNS = [re.compile(f) for f in FORMS]


class CantRun(Exception):
    pass


def count(collection):
    path, _, key = collection.partition("#")
    if not os.path.exists(path):
        raise CantRun(f"{collection}: no such collection")
    if os.path.isdir(path) and not key:
        return len([e for e in os.listdir(path) if not e.startswith(".")])
    if not path.endswith(".json") or os.path.isdir(path):
        raise CantRun(f"{collection}: not a directory or a .json file")
    try:
        with open(path, encoding="utf-8") as f:
            value = json.load(f)
    except (OSError, UnicodeDecodeError, ValueError) as e:
        raise CantRun(f"{collection}: doesn't parse as JSON ({e})")
    if key:
        value = value.get(key) if isinstance(value, dict) else None
    if not isinstance(value, list):
        raise CantRun(f"{collection}: not an array" + (f" under key '{key}'" if key else ""))
    return len(value)


def test_files(paths):
    files = []
    for p in paths:
        if os.path.isfile(p):
            files.append(p)
        elif os.path.isdir(p):
            for root, dirs, names in os.walk(p):
                dirs[:] = sorted(d for d in dirs if d != "node_modules" and not d.startswith("."))
                files += [os.path.join(root, n) for n in sorted(names)]
        else:
            raise CantRun(f"{p}: no such tests path")
    if not files:
        raise CantRun("no test files under " + ", ".join(paths))
    return files


def hard_coded(line, n):
    if ALLOW in line:
        return False
    return any(int(m.group(1)) == n for pat in PATTERNS for m in pat.finditer(line))


def main(argv):
    paths, collections = [], []
    args = iter(argv)
    for a in args:
        if a == "--tests":
            p = next(args, None)
            if p is None:
                raise CantRun("--tests needs a PATH")
            paths.append(p)
        elif a.startswith("-"):
            raise CantRun(f"unknown option {a}")
        else:
            collections.append(a)
    if not paths:
        raise CantRun("no --tests PATH given")
    if not collections:
        raise CantRun("no collection given")
    counts = {}
    for c in collections:
        n = count(c)
        if n < TOO_SMALL:
            print(f"{c}: {n} item(s), too small to check")
        else:
            counts[c] = n
    problems = []
    for f in test_files(paths):
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()
        except OSError as e:
            raise CantRun(f"{f}: can't read ({e})")
        for i, line in enumerate(lines, 1):
            for c, n in counts.items():
                if hard_coded(line, n):
                    problems.append(
                        f"{f}:{i}: asserts {n}, the current item count of {c}: take the count from "
                        f"the collection instead (guidelines/parallel.md), or, for a line this "
                        f"misreads, add the comment '{ALLOW}'"
                    )
    for p in problems:
        print(p)
    if problems:
        print(f"count-check: {len(problems)} line(s) hard-code a collection's count")
        return 1
    print(f"count-check: no hard-coded count of {len(collections)} collection(s)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except CantRun as e:
        print(f"count-check: can't run: {e}")
        sys.exit(0)
