#!/usr/bin/env python3
"""PR title check (spec specs/devshop-releases.md): the title, which becomes the squash commit's
subject on main, starts with a Conventional Commit type, because scripts/release.py computes the
next version from those subjects.

Usage: scripts/pr-title-check.py TITLE
  Form: <type>[(<scope>)][!]: <subject>, type one of TYPES; `!` marks a breaking change (a major
  release). At most 72 characters, not counting the " (#n)" GitHub appends on merge.
CI's fast job runs it on the PR's title and on the subject of each push to main; ship.sh runs it on
the title it sets.
Exit 0 = the title has the form; 1 = it doesn't (the reason is printed); 2 = no title given.
"""
import re
import sys

TYPES = ["feat", "fix", "perf", "revert", "docs", "test", "ci", "build", "refactor", "style", "chore"]
TITLE_MAX = 72
FORM = re.compile(r"^([A-Za-z]+)(\([^()\s][^()]*\))?(!)?: (.*)$")
PR_SUFFIX = re.compile(r" \(#\d+\)$")


def main(argv):
    if len(argv) != 2:
        print("usage: pr-title-check.py TITLE", file=sys.stderr)
        return 2
    title = argv[1]
    if not title:
        print("pr-title-check: no title given", file=sys.stderr)
        return 2
    problems = []
    if "\n" in title:
        problems.append("the title must be one line")
    bare = PR_SUFFIX.sub("", title)
    if len(bare) > TITLE_MAX:
        problems.append(f"{len(bare)} characters; at most {TITLE_MAX} (not counting a trailing ' (#n)')")
    m = FORM.match(bare)
    if not m:
        problems.append("no Conventional Commit type: start with '<type>: ', '<type>(<scope>): ' or "
                        f"'<type>!: ', type one of {', '.join(TYPES)}")
    else:
        if m.group(1) not in TYPES:
            problems.append(f"unknown type '{m.group(1)}': use one of {', '.join(TYPES)}")
        if not m.group(4).strip():
            problems.append("empty subject after the type")
    if problems:
        print(f"pr-title-check: {title!r}:")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"pr-title-check: ok: {title!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
