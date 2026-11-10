#!/usr/bin/env python3
"""Prior-art check (spec specs/prior-art-registry.md): has Claude analysed this outside repo before,
and at which commit? Run it before analysing one; the procedure is in kit/notes/prior-art/README.md.

Usage: scripts/prior-art.py check URL [--index PATH]
  URL: an https:// URL, or (for tests) a file:// URL or a local path; any other form can't run.
  PATH: the index, default kit/notes/prior-art/README.md in this repo; its table under "## Index" has
  one row per repo: Repo | Commit (40-hex) | Commit date | Tag | Analysed | Verdict | Note (a link).
Prints one line on stdout and exits 0:
  PRIOR-ART: new <url>
  PRIOR-ART: seen <url> at <sha12>, current · <note path>
  PRIOR-ART: seen <url> at <sha12>; upstream is now <sha12> · <note path>
Upstream's head is `git ls-remote <url> HEAD`, without a prompt and within 30 s. URLs match when they
differ only in case, a trailing ".git" or a trailing "/". A renamed repo isn't followed: its new URL
is new until it has a row.
Exit 2 = can't run, with the reason (an unreadable remote or index, a malformed row): never "new".
"""
import os
import re
import subprocess
import sys

DEFAULT_INDEX = "kit/notes/prior-art/README.md"
COLUMNS = ["Repo", "Commit", "Commit date", "Tag", "Analysed", "Verdict", "Note"]
SHA = re.compile(r"^[0-9a-f]{40}$")
LINK = re.compile(r"^\[[^\]]+\]\(([^()\s]+)\)$")
TIMEOUT = 30


class CantRun(Exception):
    pass


def url_form(url):
    """The URL's form: 'remote' for https:// and file://, 'path' for a local path; else can't run."""
    m = re.match(r"^([A-Za-z][A-Za-z0-9+.-]*)://", url)
    if m:
        if m.group(1).lower() in ("https", "file"):
            return "remote"
    elif not re.match(r"^[^/]*:", url):  # scp-style host:path has a colon before any slash
        return "path"
    raise CantRun(f"{url}: only https:// URLs (or, for tests, file:// and local paths) can be checked")


def key(url):
    """Case, a trailing '/' and a trailing '.git' (in either order) don't change which repo it is."""
    k = url.lower().rstrip("/")
    if k.endswith(".git"):
        k = k[: -len(".git")].rstrip("/")
    return k


def cells(line):
    inner = line.strip()
    if not (inner.startswith("|") and inner.endswith("|")) or len(inner) < 2:
        return None
    return [c.strip() for c in inner[1:-1].split("|")]


def read_index(path):
    """Rows of the table under '## Index' as dicts; can't run on anything it can't parse."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError as e:
        raise CantRun(f"no index at {path}: {e.strerror}")
    try:
        at = next(i for i, l in enumerate(lines) if re.match(r"^##\s+Index\s*$", l))
    except StopIteration:
        raise CantRun(f"{path}: no index table (a '## Index' heading)")
    rest = lines[at + 1 :]
    while rest and not rest[0].strip().startswith(("|", "#")):  # prose before the table
        rest.pop(0)
        at += 1
    if len(rest) < 2 or cells(rest[0]) != COLUMNS or not all(re.match(r"^:?-+:?$", c) for c in cells(rest[1]) or ["x"]):
        raise CantRun(f"{path}: no index table under '## Index' with the columns {' | '.join(COLUMNS)}")
    rows, seen = [], {}
    for n, line in enumerate(rest[2:], start=at + 4):
        if not line.strip().startswith("|"):
            break
        c = cells(line)
        where = f"{path}:{n}"
        if c is None or len(c) != len(COLUMNS):
            raise CantRun(f"{where}: a row needs {len(COLUMNS)} cells ({' | '.join(COLUMNS)})")
        row = dict(zip(COLUMNS, c))
        for name, value in row.items():
            if not value:
                raise CantRun(f"{where}: the {name} cell is empty")
        repo, sha = row["Repo"].strip("`<>"), row["Commit"].strip("`")
        url_form(repo)
        if not SHA.match(sha):
            raise CantRun(f"{where}: the Commit cell must be a full 40-hex SHA, got {sha!r}")
        link = LINK.match(row["Note"])
        if not link:
            raise CantRun(f"{where}: the Note cell must be a Markdown link to the repo's note")
        k = key(repo)
        if k in seen:
            raise CantRun(f"{where}: two rows for the same repo ({seen[k]} and {repo})")
        seen[k] = repo
        rows.append({"key": k, "sha": sha, "note": os.path.normpath(os.path.join(os.path.dirname(path), link.group(1)))})
    return rows


def upstream_head(url):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_ASKPASS="true", SSH_ASKPASS="true")
    try:
        r = subprocess.run(["git", "ls-remote", "--", url, "HEAD"], capture_output=True, text=True,
                           timeout=TIMEOUT, env=env, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        raise CantRun(f"can't read {url}: git ls-remote took over {TIMEOUT} s")
    except OSError as e:
        raise CantRun(f"can't read {url}: git: {e.strerror}")
    if r.returncode != 0:
        raise CantRun(f"can't read {url}: {r.stderr.strip() or f'git ls-remote exit {r.returncode}'}")
    for line in r.stdout.splitlines():
        sha, _, ref = line.partition("\t")
        if ref == "HEAD" and SHA.match(sha):
            return sha
    raise CantRun(f"{url} has no HEAD (an empty repo, or no default branch)")


def main(argv):
    args = argv[1:]
    index = None
    if "--index" in args:
        i = args.index("--index")
        if i + 1 >= len(args):
            return usage()
        index = args[i + 1]
        del args[i : i + 2]
    if len(args) != 2 or args[0] != "check" or not args[1]:
        return usage()
    url = args[1]
    if index is None:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        index = os.path.relpath(os.path.join(root, DEFAULT_INDEX))
    try:
        rows = read_index(index)
        url_form(url)
        head = upstream_head(url)
    except CantRun as e:
        print(f"prior-art: {e}", file=sys.stderr)
        return 2
    row = next((r for r in rows if r["key"] == key(url)), None)
    if row is None:
        print(f"PRIOR-ART: new {url}")
    elif row["sha"] == head:
        print(f"PRIOR-ART: seen {url} at {row['sha'][:12]}, current · {row['note']}")
    else:
        print(f"PRIOR-ART: seen {url} at {row['sha'][:12]}; upstream is now {head[:12]} · {row['note']}")
    return 0


def usage():
    print("usage: prior-art.py check URL [--index PATH]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
