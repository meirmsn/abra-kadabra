#!/usr/bin/env bash
# tier: slow
# The mutant run for the two checks of specs/parallel-safe-shared-files.md: each mutation below is
# applied to a temporary copy of the check, the check's own test runs against it (through its
# COUNT_CHECK or TABLE_ROWS_CHECK override), and that test must fail: the mutant is killed. A
# mutation whose text is no longer in the check fails too, so the list follows the code.
# parallel-safe-shared-files AC-9 (count-check.py) and AC-13 (table-rows-check.py).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$repo_root" "$work" <<'PY'
import json, os, re, subprocess, sys

root, work = sys.argv[1], sys.argv[2]


def form_mutants(src):
    start = src.index("FORMS = [\n") + len("FORMS = [\n")
    lines = src[start : src.index("]\nPATTERNS")].splitlines(keepends=True)
    return [(f"drop form {l.strip()[:40]}", l, "") for l in lines]


def cant_run_mutants(src):
    out = []
    for m in re.finditer(r"^( *)raise CantRun\((.*)$", src, re.M):
        func = src[: m.start()].rsplit("\ndef ", 1)[1].split("(", 1)[0]
        new = {"count": "return 0", "test_files": "return []", "main": "return 0"}[func]
        out.append((f"exit 2 becomes a pass in {func}: {m.group(2)[:40]}", m.group(0), m.group(1) + new))
    return out


count_src = open(f"{root}/runtime/scripts/count-check.py").read()
rows_src = open(f"{root}/scripts/table-rows-check.py").read()
suites = [
    ("parallel-safe-shared-files AC-9", "runtime/scripts/count-check.py", "tests/count-check.test.sh", "COUNT_CHECK", count_src,
     form_mutants(count_src) + [
         ("the count off by one (+1)", "int(m.group(1)) == n", "int(m.group(1)) == n + 1"),
         ("the count off by one (-1)", "int(m.group(1)) == n", "int(m.group(1)) == n - 1"),
         ("too small below 3", "TOO_SMALL = 2", "TOO_SMALL = 3"),
         ("too small below 1", "TOO_SMALL = 2", "TOO_SMALL = 1"),
         ("the allow marker ignored", "if ALLOW in line:", "if False:"),
     ] + cant_run_mutants(count_src) + [
         ("the last exit 2 becomes 0", "sys.exit(2)", "sys.exit(0)"),
     ]),
    ("parallel-safe-shared-files AC-13", "scripts/table-rows-check.py", "tests/table-rows-check.test.sh", "TABLE_ROWS_CHECK", rows_src, [
        ("spaces before a pipe ignored", 'r" {2,}\\||\\| {2,}"', 'r"\\| {2,}"'),
        ("spaces after a pipe ignored", 'r" {2,}\\||\\| {2,}"', 'r" {2,}\\|"'),
        ("three spaces, not two", 'r" {2,}\\||\\| {2,}"', 'r" {3,}\\||\\| {3,}"'),
        ("no row is a row", 'if l.startswith("|")]', 'if l.startswith("||")]'),
        ("no table passes", 'cant.append(f"{f}: no table")', "pass"),
        ("unreadable passes", "cant.append(f\"{f}: can't read ({e})\")", "pass"),
        ("no file passes", "        return 2\n    problems", "        return 0\n    problems"),
        ("can't run returns 0", "    if cant:\n        return 2", "    if cant:\n        return 0"),
        ("findings pass", "return 1 if problems else 0", "return 0"),
        ("only the first file", "for f in files:", "for f in files[:1]:"),
    ]),
]
failed = 0
for name, check, test, env, src, mutants in suites:
    killed = 0
    for i, (what, old, new) in enumerate(mutants, 1):
        if src.count(old) != 1:
            print(f"FAIL: {name}: mutant '{what}': its text is not once in {check}")
            failed += 1
            continue
        path = os.path.join(work, f"mutant-{os.path.basename(check)}-{i}.py")
        open(path, "w").write(src.replace(old, new, 1))
        r = subprocess.run(["bash", f"{root}/{test}"], env={**os.environ, env: path}, capture_output=True)
        if r.returncode == 0:
            print(f"FAIL: {name}: mutant '{what}' of {check} survived {test}")
            failed += 1
        else:
            killed += 1
    mark = "ok" if killed == len(mutants) else "FAIL"
    print(f"{mark} - {name}: {killed} of {len(mutants)} mutants of {check} killed by {test}")
sys.exit(1 if failed else 0)
PY
