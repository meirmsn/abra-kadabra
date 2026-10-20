#!/usr/bin/env python3
"""The project contract check (spec specs/project-contract.md): what this project must provide.

The contract, scripts/project-contract.txt, lists each item the tooling relies on finding in the
project: its path, owner (devshop, seed, project), when (required, optional), check (file,
executable, directory, version-pin), what it must do and who relies on it. This script checks the
project against it. Python's standard library only, so a plain clone runs it with nothing installed.

Usage: contract-check.py [--contract FILE] [--project DIR] [--supplies FILE]... [--list]
  --contract  the contract (default scripts/project-contract.txt under the project)
  --project   the project's root (default: the current directory)
  --supplies  a stack home's list of optional items its projects carry, one per line: those are
              required for this run (repeatable)
  --list      print every item with its owner, when, must and for, and check nothing
Stdout: `<item>: <problem>` for each required item missing or failing its check and each optional
item present but failing it; `absent (optional): <item>` for each optional item not there.
Exit 0 = no problems (absent optional items are not problems); 1 = problems; 2 = can't run (no
contract or supplies file, one that can't be parsed, a supplies line that isn't an optional item,
no project, bad arguments), the reason on stderr.
Feedback, not a wall: CI's fast tier runs it (scripts/check-fast.sh) and the devshop's session
start; required CI and the owner's approval are the walls.
"""
import os
import re
import shutil
import subprocess
import sys

KEYS = ("item", "owner", "when", "check", "must", "for")
OWNERS = ("devshop", "seed", "project")
WHENS = ("required", "optional")
CHECKS = ("file", "executable", "directory", "version-pin")
DEFAULT_CONTRACT = "scripts/project-contract.txt"
USAGE = "usage: contract-check.py [--contract FILE] [--project DIR] [--supplies FILE]... [--list]"
PIN = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)|[0-9a-f]{40}")
# A path into the devshop, which the contract must never name: the project runs with no devshop.
DEVSHOP_PATH = re.compile(r"(^|[^A-Za-z0-9_-])(runtime|install|kit)/|/opt/")


class CantRun(Exception):
    pass


def read(path, what):
    """The file's lines as text: UTF-8, LF only, no BOM."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        raise CantRun(f"can't read the {what} {path}: {e}")
    if data.startswith(b"\xef\xbb\xbf"):
        raise CantRun(f"{what} {path}: starts with a BOM; want plain UTF-8")
    if b"\r" in data:
        raise CantRun(f"{what} {path}: has CR line ends; want LF")
    try:
        return data.decode("utf-8").split("\n")
    except UnicodeDecodeError as e:
        raise CantRun(f"{what} {path}: not UTF-8: {e}")


def git_spelled(path):
    """A relative path as git spells it: no leading /, no empty, `.` or `..` part."""
    parts = path.rstrip("/").split("/")
    return bool(path) and not path.startswith("/") and all(p not in ("", ".", "..") for p in parts)


def parse(data, where):
    """The contract's items, [{key: value}], from its bytes (or lines); CantRun when it isn't one."""
    if isinstance(data, bytes):
        if data.startswith(b"\xef\xbb\xbf"):
            raise CantRun(f"{where}: starts with a BOM; want plain UTF-8")
        if b"\r" in data:
            raise CantRun(f"{where}: has CR line ends; want LF")
        data = data.decode("utf-8").split("\n")
    items, block, start, seen = [], {}, 0, set()

    def close(n):
        if not block:
            return
        missing = [k for k in KEYS if k not in block]
        if missing:
            raise CantRun(f"{where}:{start}: the item is missing {', '.join(missing)}")
        item = block["item"]
        if item in seen:
            raise CantRun(f"{where}:{start}: item '{item}' is listed twice")
        seen.add(item)
        items.append(dict(block))
        block.clear()

    for n, line in enumerate(data, 1):
        if line.startswith("#"):
            continue
        if not line.strip():
            close(n)
            continue
        if not block:
            start = n
        m = re.fullmatch(r"([a-z]+):\s*(\S.*?)\s*", line)
        if not m:
            raise CantRun(f"{where}:{n}: want `key: value`, got {line.strip()!r}")
        key, value = m.group(1), m.group(2)
        if key not in KEYS:
            raise CantRun(f"{where}:{n}: unknown key '{key}' (want {', '.join(KEYS)})")
        if key in block:
            raise CantRun(f"{where}:{n}: '{key}' given twice in one item")
        if DEVSHOP_PATH.search(value):
            raise CantRun(f"{where}:{n}: names a devshop path; the contract names files in the project only")
        if key == "owner" and value not in OWNERS:
            raise CantRun(f"{where}:{n}: unknown owner '{value}' (want {', '.join(OWNERS)})")
        if key == "when" and value not in WHENS:
            raise CantRun(f"{where}:{n}: unknown when '{value}' (want {', '.join(WHENS)})")
        if key == "check" and value not in CHECKS:
            raise CantRun(f"{where}:{n}: unknown check '{value}' (want {', '.join(CHECKS)})")
        if key == "item" and not git_spelled(value):
            raise CantRun(f"{where}:{n}: item path '{value}' must be relative, as git spells it, inside the project")
        block[key] = value
    close(len(data))
    if not items:
        raise CantRun(f"{where}: no items")
    for it in items:
        is_dir = it["item"].endswith("/")
        if is_dir != (it["check"] == "directory"):
            raise CantRun(f"{where}: item '{it['item']}': a trailing / and `check: directory` go together")
    return items


def supplied(paths, items):
    """The optional items the --supplies files name; CantRun on a line that isn't one."""
    optional = {it["item"] for it in items if it["when"] == "optional"}
    found = set()
    for path in paths:
        for n, line in enumerate(read(path, "supplies file"), 1):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if line not in optional:
                raise CantRun(f"{path}:{n}: '{line}' is not an optional item of the contract")
            found.add(line)
    return found


def committed_mode(project, item):
    """The mode git tracks for the item, or None (no git, not a repo, untracked)."""
    if not shutil.which("git"):
        return None
    try:
        r = subprocess.run(["git", "-C", project, "ls-files", "-s", "--", item],
                           capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    fields = r.stdout.split()
    return fields[0] if r.returncode == 0 and fields else None


def problems(project, it):
    """What is wrong with the item in the project ([] when it holds); None when it is absent."""
    item, check = it["item"], it["check"]
    full = os.path.join(project, item.rstrip("/"))
    if not os.path.lexists(full):
        return None
    if os.path.islink(full):
        return [f"is a symlink; want a {'directory' if check == 'directory' else 'regular file'} of its own"]
    if check == "directory":
        return [] if os.path.isdir(full) else ["is not a directory"]
    if not os.path.isfile(full):
        return ["is not a regular file"]
    with open(full, "rb") as f:
        data = f.read()
    if not data.strip():
        return ["is empty"]
    found = []
    if check == "version-pin":
        tokens = data.decode("utf-8", "replace").split()
        if len(tokens) != 1 or not PIN.fullmatch(tokens[0]):
            found.append(f"{data.decode('utf-8', 'replace').strip()!r} is not a devshop version "
                         "(one release tag vX.Y.Z, or one 40-hex commit)")
    if check == "executable":
        if not os.stat(full).st_mode & 0o100:
            found.append("is not executable (chmod +x)")
        mode = committed_mode(project, item)
        if mode is not None and mode != "100755":
            found.append(f"is committed with mode {mode}, want 100755 (git update-index --chmod=+x)")
    return found


def run(a):
    items = parse(read(a["contract"], "contract"), a["contract"])
    required_by_stack = supplied(a["supplies"], items)
    if a["list"]:
        for it in items:
            when = it["when"] if it["item"] not in required_by_stack else "required (stack)"
            print(f"{it['item']}  {it['owner']}  {when}")
            print(f"  must: {it['must']}")
            print(f"  for: {it['for']}")
        return 0
    bad = 0
    for it in items:
        required = it["when"] == "required" or it["item"] in required_by_stack
        found = problems(a["project"], it)
        if found is None:
            if required:
                why = "missing" + (" (a project on this stack has it)" if it["item"] in required_by_stack else "")
                print(f"{it['item']}: {why}; {it['must']}")
                bad += 1
            else:
                print(f"absent (optional): {it['item']}")
            continue
        for p in found:
            print(f"{it['item']}: {p}")
            bad += 1
    return 1 if bad else 0


def parse_args(argv):
    a = {"contract": None, "project": os.getcwd(), "supplies": [], "list": False}
    rest = list(argv)
    while rest:
        flag = rest.pop(0)
        if flag == "--list":
            a["list"] = True
        elif flag in ("--contract", "--project", "--supplies"):
            if not rest or rest[0].startswith("--"):
                raise CantRun(f"{flag} needs a value ({USAGE})")
            value = rest.pop(0)
            if flag == "--supplies":
                a["supplies"].append(value)
            else:
                a[flag[2:]] = value
        else:
            raise CantRun(f"unexpected '{flag}' ({USAGE})")
    if not os.path.isdir(a["project"]):
        raise CantRun(f"no project directory at {a['project']}")
    if a["contract"] is None:
        a["contract"] = os.path.join(a["project"], DEFAULT_CONTRACT)
    return a


def main(argv):
    try:
        return run(parse_args(argv))
    except CantRun as e:
        print(f"contract-check: {e}", file=sys.stderr)
        return 2
    except OSError as e:
        print(f"contract-check: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
