#!/usr/bin/env python3
"""Shape check for the devshop's own skills, run by tests/skills-check.test.sh in CI (W10.6.1).

Usage: scripts/skills-check.py [RUNTIME_DIR]   (default: runtime/ beside this script)
For every RUNTIME_DIR/skills/<name>/SKILL.md:
  - frontmatter between '---' lines, with 'name: <name>' (the directory's name, which is what
    Claude Code lists) and a non-empty 'description:'
  - one page at most: MAX_LINES lines and MAX_WORDS words, frontmatter included
  - every /opt/devshop-current/<path> it names exists in RUNTIME_DIR, the files a session gets from
    the same pinned version (a skill never points at a script its version lacks)
Exit 0 = every skill has the shape; 1 = problems (listed); 2 = can't run (no runtime, no skills).
"""
import os
import re
import sys

MAX_LINES, MAX_WORDS = 60, 600
PINNED = re.compile(r"/opt/devshop-current/([A-Za-z0-9._/-]*[A-Za-z0-9_/-])")


def check(path, name, runtime):
    problems = []
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines()
    fm = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not fm:
        return [f"{name}: no frontmatter ('---' lines around name and description)"]
    fields = dict(re.findall(r"^([a-z-]+):[ \t]*(.*)$", fm.group(1), re.M))
    if fields.get("name") != name:
        problems.append(f"{name}: frontmatter name is '{fields.get('name', '')}', want '{name}' (its directory)")
    if not fields.get("description", "").strip():
        problems.append(f"{name}: frontmatter has no description")
    if len(lines) > MAX_LINES:
        problems.append(f"{name}: {len(lines)} lines, one page is at most {MAX_LINES}")
    words = len(text.split())
    if words > MAX_WORDS:
        problems.append(f"{name}: {words} words, one page is at most {MAX_WORDS}")
    for rel in sorted(set(PINNED.findall(text))):
        if not os.path.exists(os.path.join(runtime, rel)):
            problems.append(f"{name}: names /opt/devshop-current/{rel}, which this runtime doesn't have")
    return problems


def main(argv):
    runtime = argv[1] if len(argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "runtime")
    skills = os.path.join(runtime, "skills")
    names = sorted(d for d in os.listdir(skills) if os.path.isdir(os.path.join(skills, d))) if os.path.isdir(skills) else []
    if not names:
        print(f"skills-check: no skills in {skills}", file=sys.stderr)
        return 2
    problems = []
    for name in names:
        path = os.path.join(skills, name, "SKILL.md")
        if not os.path.isfile(path):
            problems.append(f"{name}: no SKILL.md")
            continue
        problems += check(path, name, runtime)
    for p in problems:
        print(f"skills-check: {p}")
    if not problems:
        print(f"skills-check: {len(names)} skills ({', '.join(names)})")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
