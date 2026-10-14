#!/usr/bin/env python3
"""A project's copies of devshop files against a devshop version (W10.4.7, L-49).

The version's runtime/project-files.txt lists each file the devshop places in a project, one per
line: `<owner> <devshop path> <project path>` (`#` starts a comment). Owner `devshop`: the project
keeps an identical copy, executable bit included. Owner `seed`: a starting point the project adapts
and owns; never compared, never written. Versions are read from a devshop git dir (the session's
local copy, /opt/devshop.git), so no network.

Usage:
  project-files.py check --devshop-git D --version V --project P
      Exit 0 = every devshop copy matches V; 1 = drift, one `<path>: <problem>` line each;
      3 = V has no manifest (older than W10.4.7), nothing to check.
  project-files.py plan --devshop-git D --from OLD --to NEW --project P
      Each devshop copy's diff to NEW, each seed template's change OLD..NEW with its commits, and
      the entries NEW's manifest dropped (never deleted). Changes nothing. Exit 0.
  project-files.py apply --devshop-git D --version V --project P --file <project path>
      Writes V's content and mode for one devshop file. Refuses seeds, unlisted paths, symlinks
      and paths whose directory leaves the project. Exit 0.
Exit 2 = can't run (bad arguments, no git, unknown version, bad manifest, refused apply).
"""
import difflib
import os
import subprocess
import sys

MANIFEST = "runtime/project-files.txt"
OWNERS = ("devshop", "seed")
USAGE = ("usage: project-files.py check --devshop-git D --version V --project P | "
         "plan --devshop-git D --from OLD --to NEW --project P | "
         "apply --devshop-git D --version V --project P --file PATH")
NEEDS = {"check": ("devshop-git", "version", "project"),
         "plan": ("devshop-git", "from", "to", "project"),
         "apply": ("devshop-git", "version", "project", "file")}


class CantRun(Exception):
    pass


class NoManifest(Exception):
    pass


def git(gitdir, *args):
    try:
        r = subprocess.run(["git", "--git-dir", gitdir, *args], capture_output=True)
    except OSError as e:
        raise CantRun(f"can't run git: {e}")
    return r


def resolve(gitdir, version):
    if not version or version.startswith("-"):
        raise CantRun(f"'{version}' is not a devshop version (a commit SHA)")
    r = git(gitdir, "rev-parse", "-q", "--verify", f"{version}^{{commit}}")
    if r.returncode != 0:
        raise CantRun(f"version '{version}' is not in the devshop copy {gitdir}; it refreshes when "
                      "the environment's cache rebuilds: rebuild the environment, then retry")
    return r.stdout.decode().strip()


def blob(gitdir, sha, path):
    """(bytes, mode) of path at sha, or None when the version lacks it."""
    r = git(gitdir, "ls-tree", sha, "--", path)
    fields = r.stdout.decode().split()
    if r.returncode != 0 or len(fields) < 4 or fields[1] != "blob":
        return None
    data = git(gitdir, "cat-file", "blob", fields[2])
    if data.returncode != 0:
        raise CantRun(f"can't read {path} at {sha[:12]}")
    return data.stdout, fields[0]


def safe_rel(path):
    parts = path.split("/")  # an absolute path starts with an empty part
    return ".." not in parts and "" not in parts and "." not in parts


def manifest(gitdir, sha):
    """[(owner, source, project path)] of the version's manifest; NoManifest when it has none."""
    found = blob(gitdir, sha, MANIFEST)
    if found is None:
        raise NoManifest(f"version {sha[:12]} has no {MANIFEST} (older than W10.4.7): nothing to check")
    entries, seen = [], set()
    for n, line in enumerate(found[0].decode("utf-8", "replace").splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        where = f"{MANIFEST}:{n} at {sha[:12]}"
        if len(fields) != 3:
            raise CantRun(f"{where}: want 3 fields (owner, devshop path, project path), got {len(fields)}")
        owner, src, dst = fields
        if owner not in OWNERS:
            raise CantRun(f"{where}: unknown owner '{owner}' (want {' or '.join(OWNERS)})")
        for p in (src, dst):
            if not safe_rel(p):
                raise CantRun(f"{where}: path '{p}' must be relative and stay inside its repo")
        if dst in seen:
            raise CantRun(f"{where}: project path '{dst}' is listed twice")
        seen.add(dst)
        if blob(gitdir, sha, src) is None:
            raise CantRun(f"{where}: version {sha[:12]} lacks '{src}'")
        entries.append((owner, src, dst))
    if not entries:
        raise CantRun(f"{MANIFEST} at {sha[:12]} has no entries")
    return entries


def index_mode(project, path):
    r = subprocess.run(["git", "-C", project, "ls-files", "-s", "--", path], capture_output=True)
    fields = r.stdout.decode().split()
    return fields[0] if r.returncode == 0 and fields else None


def problems(gitdir, sha, project, src, dst):
    """What differs between the project's copy and the version's file ([] when identical)."""
    data, mode = blob(gitdir, sha, src)
    full = os.path.join(project, dst)
    if os.path.islink(full):
        return [f"is a symlink, want a copy of {src} at {sha[:12]}"]
    if not os.path.lexists(full):
        return [f"missing (a copy of {src} at {sha[:12]})"]
    if not os.path.isfile(full):
        return [f"not a regular file, want a copy of {src} at {sha[:12]}"]
    found = []
    with open(full, "rb") as f:
        if f.read() != data:
            found.append(f"differs from {src} at {sha[:12]}")
    want_x = mode == "100755"
    if bool(os.stat(full).st_mode & 0o100) != want_x:
        found.append("executable" + (" bit missing on disk" if want_x else " on disk, want not executable"))
    committed = index_mode(project, dst)
    if committed and committed != mode:
        found.append(f"committed with mode {committed}, want {mode}")
    return found


def check(a):
    sha = resolve(a["devshop-git"], a["version"])
    drift = []
    for owner, src, dst in manifest(a["devshop-git"], sha):
        if owner == "devshop":
            drift += [f"{dst}: {p}" for p in problems(a["devshop-git"], sha, a["project"], src, dst)]
    for line in drift:
        print(line)
    return 1 if drift else 0


def text(data):
    return data.decode("utf-8", "replace").splitlines(keepends=True)


def plan(a):
    gd, project = a["devshop-git"], a["project"]
    new = resolve(gd, a["to"])
    old = resolve(gd, a["from"])
    entries = manifest(gd, new)
    print(f"project-files plan: {old[:12]} -> {new[:12]}")
    for owner, src, dst in entries:
        if owner == "devshop":
            found = problems(gd, new, project, src, dst)
            print(f"== {dst} (devshop, from {src}): {'; '.join(found) if found else 'same as the new version'}")
            full = os.path.join(project, dst)
            mine = open(full, "rb").read() if os.path.isfile(full) and not os.path.islink(full) else b""
            sys.stdout.writelines(difflib.unified_diff(text(mine), text(blob(gd, new, src)[0]),
                                                       f"project/{dst}", f"{new[:12]}/{src}"))
        else:
            before, after = blob(gd, old, src), blob(gd, new, src)
            has = os.path.lexists(os.path.join(project, dst))
            if before is not None and before[0] == after[0]:
                print(f"== {dst} (seed, from {src}): template unchanged")
                continue
            what = "new template" if before is None else "template changed"
            print(f"== {dst} (seed, from {src}): {what}; the project {'has' if has else 'lacks'} {dst}; "
                  "confirm a project diff, never the template's")
            log = git(gd, "log", "--format=   %h %s", f"{old}..{new}", "--", src)
            sys.stdout.write(log.stdout.decode())
            sys.stdout.writelines(difflib.unified_diff(text(before[0] if before else b""), text(after[0]),
                                                       f"{old[:12]}/{src}", f"{new[:12]}/{src}"))
    try:
        dropped = [e for e in manifest(gd, old) if e[2] not in {d for _, _, d in entries}]
        for owner, src, dst in dropped:
            print(f"== {dst} ({owner}): removed from the manifest since {old[:12]}; the project "
                  f"keeps it (never deleted): decide whether to delete it")
    except NoManifest:
        print(f"== {old[:12]} has no manifest: removals can't be listed")
    except CantRun as e:
        print(f"== {old[:12]}'s manifest can't be read, so removals can't be listed: {e}")
    return 0


def apply(a):
    gd, dst = a["devshop-git"], a["file"]
    sha = resolve(gd, a["version"])
    entry = [e for e in manifest(gd, sha) if e[2] == dst]
    if not entry:
        raise CantRun(f"'{dst}' is not in {MANIFEST} at {sha[:12]}")
    owner, src, _ = entry[0]
    if owner != "devshop":
        raise CantRun(f"'{dst}' is a seed: the project owns it; edit it by hand after the owner confirms")
    project = os.path.realpath(a["project"])
    full = os.path.join(project, dst)
    parent = os.path.dirname(full)
    real_parent = os.path.realpath(parent)
    if real_parent != project and not real_parent.startswith(project + os.sep):
        raise CantRun(f"'{dst}': its directory leaves the project")
    if os.path.islink(full):
        raise CantRun(f"'{dst}' is a symlink; refusing to write through it")
    if os.path.lexists(full) and not os.path.isfile(full):
        raise CantRun(f"'{dst}' is not a regular file")
    data, mode = blob(gd, sha, src)
    os.makedirs(parent, exist_ok=True)
    tmp = f"{full}.project-files.tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o755 if mode == "100755" else 0o644)
    os.replace(tmp, full)
    print(f"{dst}: written from {src} at {sha[:12]} (mode {mode})")
    return 0


def parse(argv):
    if not argv or argv[0] not in NEEDS:
        raise CantRun(USAGE)
    cmd, args, rest = argv[0], {}, argv[1:]
    while rest:
        if not rest[0].startswith("--") or len(rest) < 2 or rest[0][2:] not in NEEDS[cmd]:
            raise CantRun(f"unexpected '{rest[0]}' ({USAGE})")
        args[rest[0][2:]] = rest[1]
        rest = rest[2:]
    missing = [k for k in NEEDS[cmd] if k not in args]
    if missing:
        raise CantRun(f"missing --{', --'.join(missing)} ({USAGE})")
    if not os.path.isdir(args["devshop-git"]):
        raise CantRun(f"no devshop git dir at {args['devshop-git']}")
    if not os.path.isdir(args["project"]):
        raise CantRun(f"no project at {args['project']}")
    return cmd, args


def main(argv):
    try:
        cmd, args = parse(argv)
        return {"check": check, "plan": plan, "apply": apply}[cmd](args)
    except NoManifest as e:
        print(f"project-files: {e}", file=sys.stderr)
        return 3 if argv[0] == "check" else 2
    except (CantRun, OSError) as e:
        print(f"project-files: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
