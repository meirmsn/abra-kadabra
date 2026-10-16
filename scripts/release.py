#!/usr/bin/env python3
"""Devshop releases (spec specs/devshop-releases.md; D-10): SemVer tags from v2.0.0, the bump
computed from the Conventional Commit subjects on main since the last release.

Usage (from the repo root):
  scripts/release.py next
      Print the next version and its release notes. Exit 1 when nothing since the last release bumps
      the version.
  scripts/release.py prepare
      For the release PR, in a session, on a fresh branch from main: write the next version to
      VERSION and its notes to the top of CHANGELOG.md (replacing the section of a version that was
      never tagged). Exit 1 when there is nothing to release; 2 when the tree has uncommitted changes.
  scripts/release.py tag-plan --notes-file PATH
      For CI on a push to main (.github/workflows/release.yml): when VERSION names a version with no
      tag yet, print `tag=v<version>` and `sha=<commit>` (the commit that last changed VERSION) and
      write its notes to PATH; otherwise print nothing. Exit 2, so nothing is tagged, when VERSION is
      malformed, its tag is on another commit, it isn't above every release, or the version or notes
      differ from what the history up to that commit's parent gives (main moved after `prepare`: make
      another release PR, whose `prepare` regenerates the section).

Releases are tags vX.Y.Z with X >= 2 (v1's tags and v1-final never count). The subjects are main's
first-parent subjects since the newest release reachable from the commit (since v1-final for the
first release, which is always v2.0.0). A `!` before the colon makes a major release; else a `feat`
a minor one; else a `fix`, `perf` or `revert` a patch; anything else releases nothing. A shallow
clone, or one with neither a release tag nor v1-final, can't run (exit 2): either would silently
shorten the history.
Exit 0 = done; 1 = nothing to release; 2 = can't run or refused.
"""
import datetime
import os
import re
import subprocess
import sys

TYPES = {"feat", "fix", "perf", "revert", "docs", "test", "ci", "build", "refactor", "style", "chore"}
SUBJECT = re.compile(r"^([a-z]+)(\([^()\s][^()]*\))?(!)?: (.+)$")
RELEASE_COMMIT = re.compile(r"^chore\(release\): v\d+\.\d+\.\d+")
TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
VERSION_TEXT = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
SECTION = re.compile(r"^## v(\d+\.\d+\.\d+) \(.*\)$", re.M)
FIRST_BASE = "v1-final"
GROUPS = ["Breaking changes", "Features", "Fixes", "Other changes"]
CHANGELOG_HEAD = (
    "# Changelog\n\nEvery devshop release, newest first. A project pins one in `.devshop-version`; "
    "a major release needs a migration. How releases are cut: "
    "[specs/devshop-releases.md](specs/devshop-releases.md).\n"
)


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
    """(group, text) for a subject; group None for a release PR's own commit."""
    if RELEASE_COMMIT.match(subject):
        return None, subject
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
        if g:
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


def changelog_sections(text):
    """{version string: section body} of a CHANGELOG.md."""
    heads = list(SECTION.finditer(text))
    out = {}
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        out[m.group(1)] = text[m.end():end].strip()
    return out


def read_version(text):
    m = VERSION_TEXT.match(text.strip())
    if not m:
        raise Refused(f"VERSION holds {text.strip()!r}, not X.Y.Z")
    return tuple(int(x) for x in m.groups())


def cmd_next():
    version, notes = compute("HEAD")
    if version is None:
        print("nothing to release: no feat, fix, perf, revert or breaking change since the last release")
        if notes:
            print(f"\n{notes}")
        return 1
    print(f"v{fmt(version)}\n\n{notes}")
    return 0


def cmd_prepare():
    if git("status", "--porcelain").strip():
        raise Refused("the working tree has uncommitted changes: prepare runs on a fresh branch from main")
    version, notes = compute("HEAD")
    if version is None:
        print("nothing to release: no feat, fix, perf, revert or breaking change since the last release")
        return 1
    text = open("CHANGELOG.md").read() if os.path.exists("CHANGELOG.md") else CHANGELOG_HEAD
    # A version that was prepared but never tagged (CI refused it): its section is replaced.
    tagged = {fmt(v) for v in releases()}
    for m in reversed(list(SECTION.finditer(text))):
        if m.group(1) not in tagged:
            nxt = SECTION.search(text, m.end())
            text = text[:m.start()] + text[nxt.start() if nxt else len(text):]
    first = SECTION.search(text)
    at = first.start() if first else len(text)
    head = text[:at].rstrip("\n") + "\n\n"
    date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    section = f"## v{fmt(version)} ({date})\n\n{notes}\n"
    rest = text[at:]
    new = head + section + ("\n" + rest if rest else "")
    with open("CHANGELOG.md", "w") as f:
        f.write(new)
    with open("VERSION", "w") as f:
        f.write(fmt(version) + "\n")
    print(f"prepared v{fmt(version)}: VERSION and CHANGELOG.md; open the PR titled 'chore(release): v{fmt(version)}'")
    return 0


def cmd_tag_plan(notes_file):
    if not os.path.exists("VERSION"):
        print("tag-plan: no VERSION file, nothing to release", file=sys.stderr)
        return 0
    version = read_version(open("VERSION").read())
    tag = f"v{fmt(version)}"
    commit = git("log", "-1", "--first-parent", "--format=%H", "--", "VERSION").strip()
    tagged_at = git("rev-parse", "-q", "--verify", f"refs/tags/{tag}^{{commit}}", check=False).strip()
    if tagged_at:
        if tagged_at == commit:
            print(f"tag-plan: {tag} is already tagged on {commit[:12]}, nothing to do", file=sys.stderr)
            return 0
        raise Refused(f"{tag} is tagged on {tagged_at[:12]}, not on {commit[:12]}, the commit that set VERSION")
    above = [v for v in releases() if v >= version]
    if above:
        raise Refused(f"VERSION {fmt(version)} isn't above the existing release v{fmt(max(above))}")
    sections = changelog_sections(open("CHANGELOG.md").read() if os.path.exists("CHANGELOG.md") else "")
    if fmt(version) not in sections:
        raise Refused(f"CHANGELOG.md has no section for v{fmt(version)}")
    parent = git("rev-parse", "-q", "--verify", f"{commit}^1", check=False).strip()
    if not parent:
        raise Refused(f"the commit that set VERSION ({commit[:12]}) has no parent")
    want, notes = compute(parent)
    if want != version:
        raise Refused(f"VERSION says {fmt(version)}, but the history up to {parent[:12]} gives "
                      f"{'nothing to release' if want is None else fmt(want)}: make another release PR "
                      "(scripts/release.py prepare regenerates the section)")
    if sections[fmt(version)] != notes:
        raise Refused(f"CHANGELOG.md's v{fmt(version)} section differs from the notes the history up to "
                      f"{parent[:12]} gives (main moved after prepare?): make another release PR")
    with open(notes_file, "w") as f:
        f.write(notes + "\n")
    print(f"tag={tag}\nsha={commit}")
    print(f"tag-plan: tag {tag} on {commit[:12]}", file=sys.stderr)
    return 0


def main(argv):
    try:
        if argv[1:] == ["next"]:
            return cmd_next()
        if argv[1:] == ["prepare"]:
            return cmd_prepare()
        if len(argv) == 4 and argv[1] == "tag-plan" and argv[2] == "--notes-file" and argv[3]:
            return cmd_tag_plan(argv[3])
        print("usage: release.py next | prepare | tag-plan --notes-file PATH", file=sys.stderr)
        return 2
    except Refused as e:
        print(f"release: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"release: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
