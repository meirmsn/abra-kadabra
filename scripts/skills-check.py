#!/usr/bin/env python3
"""Shape check for the devshop's own skills, run by tests/skills-check.test.sh in CI (W10.6.1).

Usage: scripts/skills-check.py [RUNTIME_DIR] [--plugin-skills DIR]   (default: runtime/ beside this
script). DIR holds the install plugin's own skills (W10.4.8), loaded beside the runtime's in every
session; they are checked with them, as one set.
For every RUNTIME_DIR/skills/<name>/SKILL.md and DIR/<name>/SKILL.md:
  - frontmatter between '---' lines, with 'name: <name>' (the directory's name, which is what
    Claude Code lists) and a non-empty 'description:' on one line (so its words can be counted)
  - one page at most: MAX_LINES lines and MAX_WORDS words, frontmatter included
  - every /opt/devshop-current/<path> it names exists in RUNTIME_DIR, the files a session gets from
    the same pinned version (a skill never points at a script its version lacks)
  - every `devshop:<skill>` it hands over to is one of these skills (the plugin lists them so)
  - no plugin skill shares its name with a runtime skill
All the descriptions together stay within MAX_DESCRIPTION_WORDS: they are loaded into every
session, the devshop's share of the always-loaded budget (TARGET Shape 2, W10.6.16, W10.6.18).
Exit 0 = every skill has the shape; 1 = problems (listed); 2 = can't run (no runtime, no skills, a
missing plugin skills dir, bad arguments).
"""
import os
import re
import sys

MAX_LINES, MAX_WORDS = 60, 600
MAX_DESCRIPTION_WORDS = 200
PINNED = re.compile(r"/opt/devshop-current/([A-Za-z0-9._/-]*[A-Za-z0-9_/-])")
HANDOVER = re.compile(r"\bdevshop:([a-z][a-z0-9-]*)")


def check(path, name, runtime, names):
    problems = []
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.splitlines()
    fm = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not fm:
        return [f"{name}: no frontmatter ('---' lines around name and description)"], 0
    fields = dict(re.findall(r"^([a-z-]+):[ \t]*(.*)$", fm.group(1), re.M))
    if fields.get("name") != name:
        problems.append(f"{name}: frontmatter name is '{fields.get('name', '')}', want '{name}' (its directory)")
    description = fields.get("description", "").strip()
    if not description:
        problems.append(f"{name}: frontmatter has no description")
    elif re.search(r"^description:.*\n[ \t]", fm.group(1), re.M):
        problems.append(f"{name}: description must be one line, or its words can't be counted")
    if len(lines) > MAX_LINES:
        problems.append(f"{name}: {len(lines)} lines, one page is at most {MAX_LINES}")
    words = len(text.split())
    if words > MAX_WORDS:
        problems.append(f"{name}: {words} words, one page is at most {MAX_WORDS}")
    for rel in sorted(set(PINNED.findall(text))):
        if not os.path.exists(os.path.join(runtime, rel)):
            problems.append(f"{name}: names /opt/devshop-current/{rel}, which this runtime doesn't have")
    for target in sorted(set(HANDOVER.findall(text)) - set(names)):
        problems.append(f"{name}: hands over to devshop:{target}, which this runtime doesn't have")
    return problems, len(description.split())


def skill_dirs(skills):
    return sorted(d for d in os.listdir(skills) if os.path.isdir(os.path.join(skills, d)))


def main(argv):
    args, plugin = argv[1:], None
    if "--plugin-skills" in args:
        k = args.index("--plugin-skills")
        if k + 1 >= len(args):
            print("skills-check: --plugin-skills needs a directory", file=sys.stderr)
            return 2
        plugin = args[k + 1]
        del args[k:k + 2]
    if len(args) > 1:
        print(f"skills-check: unexpected arguments {args[1:]}", file=sys.stderr)
        return 2
    runtime = args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "runtime")
    skills = os.path.join(runtime, "skills")
    names = skill_dirs(skills) if os.path.isdir(skills) else []
    if not names:
        print(f"skills-check: no skills in {skills}", file=sys.stderr)
        return 2
    sets = [(skills, names)]
    if plugin is not None:
        if not os.path.isdir(plugin):
            print(f"skills-check: no plugin skills dir {plugin}", file=sys.stderr)
            return 2
        sets.append((plugin, skill_dirs(plugin)))
    every = [n for _, ns in sets for n in ns]
    problems, description_words = [], 0
    for name in sorted({n for n in every if every.count(n) > 1}):
        problems.append(f"{name}: a plugin skill shares its name with a runtime skill")
    for base, ns in sets:
        for name in ns:
            path = os.path.join(base, name, "SKILL.md")
            if not os.path.isfile(path):
                problems.append(f"{name}: no SKILL.md")
                continue
            found, words = check(path, name, runtime, every)
            problems += found
            description_words += words
    if description_words > MAX_DESCRIPTION_WORDS:
        problems.append(f"descriptions: {description_words} words, the always-loaded budget is {MAX_DESCRIPTION_WORDS}")
    for p in problems:
        print(f"skills-check: {p}")
    if not problems:
        print(f"skills-check: {len(every)} skills ({', '.join(every)}), descriptions {description_words} of {MAX_DESCRIPTION_WORDS} words")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
