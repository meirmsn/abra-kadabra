#!/usr/bin/env python3
"""Devshop releases (spec specs/devshop-releases.md; D-10): SemVer tags from v2.0.0, the bump
computed from the Conventional Commit subjects on main since the last release.

Usage (from the repo root):
  scripts/release.py next
      Print the next version and its release notes. Exit 1 when nothing since the last release bumps
      the version.
  scripts/release.py plan --notes-file PATH
      For the release button (.github/workflows/release.yml), on main: print `tag=v<version>` and
      `sha=<HEAD>` and write the notes to PATH. Exit 1 when there is nothing to release (main's head
      already released included); 2 when that tag already exists elsewhere.

Releases are tags vX.Y.Z with X >= 2 (v1's tags and v1-final never count). The subjects are main's
first-parent subjects since the newest release reachable from the commit (since v1-final for the
first release, which is always v2.0.0). A `!` before the colon makes a major release; else a `feat`
a minor one; else a `fix`, `perf` or `revert` a patch; anything else releases nothing. A shallow
clone, or one with neither a release tag nor v1-final, can't run (exit 2): either would silently
shorten the history.
Exit 0 = done; 1 = nothing to release; 2 = can't run or refused.
"""
import re
import subprocess
import sys

TYPES = {"feat", "fix", "perf", "revert", "docs", "test", "ci", "build", "refactor", "style", "chore"}
SUBJECT = re.compile(r"^([a-z]+)(\([^()\s][^()]*\))?(!)?: (.+)$")
TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
FIRST_BASE = "v1-final"
GROUPS = ["Breaking changes", "Features", "Fixes", "Other changes"]

class Refused(Exception):
    pass


def git(*args, check=True):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise Refused(f"git {' '.join(args)} failed: {r.stderr.strip()}")
    return r.stdout


def releases(merged_into=None):
    """{version tuple: tag name} for the release tags (reachable from merged_into, if given)."""
    args = ["tag", "-l", "v*"] + (["--merged", merged_into] if merged_into else [])
    out = {}
    for name in git(*args).split():
        m = TAG.match(name)
        if m and int(m.group(1)) >= 2:
            out[tuple(int(x) for x in m.groups())] = name
    return out


def fmt(v):
    return f"{v[0]}.{v[1]}.{v[2]}"


def classify(subject):
    """(group, text) for a subject."""
    m = SUBJECT.match(subject)
    if not m or m.group(1) not in TYPES:
        return "Other changes", subject
    text = m.group(4)
    if m.group(3):
        return "Breaking changes", text
    if m.group(1) == "feat":
        return "Features", text
    if m.group(1) in ("fix", "perf", "revert"):
        return "Fixes", text
    return "Other changes", text


def compute(at):
    """(version tuple or None, notes) for a release cut at commit `at`."""
    if git("rev-parse", "--is-shallow-repository").strip() == "true":
        raise Refused("this clone is shallow, so the history since the last release is cut short: "
                      "run `git fetch --unshallow --tags origin` first")
    rel = releases(merged_into=at)
    if rel:
        last = max(rel)
        base = rel[last]
    else:
        if not git("rev-parse", "-q", "--verify", f"refs/tags/{FIRST_BASE}^{{commit}}", check=False).strip():
            raise Refused(f"no release tag and no {FIRST_BASE} tag here (a clone without tags?): "
                          "run `git fetch --tags origin` first")
        last, base = None, FIRST_BASE
    subjects = git("log", "--first-parent", "--reverse", "--format=%s", f"{base}..{at}").splitlines()
    groups = {g: [] for g in GROUPS}
    for s in subjects:
        g, text = classify(s)
        groups[g].append(text)
    notes = "\n\n".join(f"### {g}\n\n" + "\n".join(f"- {t}" for t in groups[g]) for g in GROUPS if groups[g])
    if last is None:
        return (2, 0, 0), notes
    if groups["Breaking changes"]:
        return (last[0] + 1, 0, 0), notes
    if groups["Features"]:
        return (last[0], last[1] + 1, 0), notes
    if groups["Fixes"]:
        return (last[0], last[1], last[2] + 1), notes
    return None, notes


def cmd_next():
    version, notes = compute("HEAD")
    if version is None:
        print("nothing to release: no feat, fix, perf, revert or breaking change since the last release")
        if notes:
            print(f"\n{notes}")
        return 1
    print(f"v{fmt(version)}\n\n{notes}")
    return 0


def cmd_plan(notes_file):
    version, notes = compute("HEAD")
    if version is None:
        print("release: nothing to release: no feat, fix, perf, revert or breaking change on main since "
              "the last release", file=sys.stderr)
        return 1
    tag = f"v{fmt(version)}"
    if git("rev-parse", "-q", "--verify", f"refs/tags/{tag}", check=False).strip():
        raise Refused(f"{tag} already exists, on a commit main doesn't reach: look at it before releasing")
    sha = git("rev-parse", "HEAD").strip()
    with open(notes_file, "w") as f:
        f.write(notes + "\n")
    print(f"tag={tag}\nsha={sha}")
    print(f"release: {tag} on {sha[:12]}\n\n{notes}", file=sys.stderr)
    return 0


def main(argv):
    try:
        if argv[1:] == ["next"]:
            return cmd_next()
        if len(argv) == 4 and argv[1] == "plan" and argv[2] == "--notes-file" and argv[3]:
            return cmd_plan(argv[3])
        print("usage: release.py next | plan --notes-file PATH", file=sys.stderr)
        return 2
    except Refused as e:
        print(f"release: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"release: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
