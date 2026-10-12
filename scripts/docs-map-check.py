#!/usr/bin/env python3
"""Docs-map check run by CI (TARGET § Build 3): every doc is reachable from docs/README.md, and no
relative link in any doc is broken.

Usage: scripts/docs-map-check.py   (run from the repo to check)
  A doc is a Markdown file git knows of (tracked, or untracked and not ignored). Reachable = linked
  from docs/README.md, directly or through docs it links (a link to a directory counts as a link
  to its README.md). A relative link is broken when its file or directory is missing or outside
  the repo, or when its #anchor names no heading (or <a id/name>) in the target doc.
  External links (any scheme:) are not fetched.
Exit 0 = clean; 1 = unreachable docs or broken links; 2 = can't run (not a git repo, no docs map).
"""
import os
import re
import subprocess
import sys
from urllib.parse import unquote

MAP = "docs/README.md"

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
INLINE_CODE = re.compile(r"(`+).+?\1")
# [text](target) or ![alt](target); target may be <wrapped>; an optional "title" follows.
INLINE_LINK = re.compile(r"!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*(<[^>]*>|[^\s()]+(?:\([^\s()]*\)[^\s()]*)*)")
REF_DEF = re.compile(r"^ {0,3}\[[^\]]+\]:\s*(<[^>]*>|\S+)")
HEADING = re.compile(r"^ {0,3}#{1,6}\s+(.*?)\s*#*\s*$")
HTML_ANCHOR = re.compile(r"<a\s[^>]*(?:id|name)=\"([^\"]+)\"", re.I)
SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


def die(msg):
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(2)


def prose_lines(text, keep_code=False):
    """Yield (line number, line) outside fenced code blocks, with inline code removed."""
    fence = None
    for n, line in enumerate(text.splitlines(), 1):
        m = FENCE.match(line)
        if m:
            mark = m.group(1)
            if fence is None:
                fence = mark
            elif mark[0] == fence[0] and len(mark) >= len(fence):
                fence = None
            continue
        if fence is None:
            yield n, line if keep_code else INLINE_CODE.sub("", line)


def slug(heading):
    """GitHub's heading anchor: rendered text, lowercased, punctuation dropped, spaces to '-'."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", heading)  # links → their text
    text = re.sub(r"<[^>]+>", "", text)  # inline HTML tags (code spans keep their text)
    return re.sub(r"[^\w\- ]", "", text.lower()).replace(" ", "-")


def anchors(text):
    found, seen = set(), {}
    for _, line in prose_lines(text, keep_code=True):
        found.update(HTML_ANCHOR.findall(line))
        m = HEADING.match(line)
        if m:
            base = slug(m.group(1))
            n = seen.get(base, 0)
            seen[base] = n + 1
            found.add(base if n == 0 else f"{base}-{n}")
    return found


def links(text):
    for n, line in prose_lines(text):
        for m in INLINE_LINK.finditer(line):
            yield n, m.group(1)
        m = REF_DEF.match(line)
        if m:
            yield n, m.group(1)


def main():
    try:
        root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                              text=True, check=True).stdout.strip()
        listed = subprocess.run(["git", "ls-files", "-z", "--cached", "--others",
                                 "--exclude-standard", "--deduplicate"], cwd=root,
                                capture_output=True, text=True, check=True).stdout.split("\0")
    except (OSError, subprocess.CalledProcessError):
        die("not inside a git repository")
    docs = sorted(p for p in listed if p.endswith(".md") and os.path.isfile(os.path.join(root, p)))
    if MAP not in docs:
        die(f"no docs map at {MAP}")

    texts = {d: open(os.path.join(root, d), encoding="utf-8").read() for d in docs}
    anchor_cache = {}
    broken, edges = [], {d: set() for d in docs}

    for doc in docs:
        for n, raw in links(texts[doc]):
            target = raw[1:-1] if raw.startswith("<") else raw
            if SCHEME.match(target):
                continue
            path, _, frag = target.partition("#")
            path, frag = unquote(path), unquote(frag)
            if path:
                base = root if path.startswith("/") else os.path.join(root, os.path.dirname(doc))
                full = os.path.normpath(os.path.join(base, path.lstrip("/")))
            else:
                full = os.path.join(root, doc)
            rel = os.path.relpath(full, root)
            where = f"{doc}:{n}: {target}"
            if rel.startswith(".."):
                broken.append(f"{where} (outside the repo)")
                continue
            if not os.path.exists(full):
                broken.append(f"{where} (no such file or directory)")
                continue
            if os.path.isdir(full):
                rel = os.path.normpath(os.path.join(rel, "README.md"))
            if rel in texts:
                edges[doc].add(rel)
                if frag:
                    if rel not in anchor_cache:
                        anchor_cache[rel] = anchors(texts[rel])
                    if frag not in anchor_cache[rel]:
                        broken.append(f"{where} (no heading for #{frag} in {rel})")

    reached, todo = {MAP}, [MAP]
    while todo:
        for nxt in edges[todo.pop()] - reached:
            reached.add(nxt)
            todo.append(nxt)
    unreachable = [d for d in docs if d not in reached]

    for b in broken:
        print(f"broken link: {b}")
    for d in unreachable:
        print(f"not reachable from {MAP}: {d}")
    if broken or unreachable:
        print(f"docs-map-check: {len(broken)} broken links, {len(unreachable)} unreachable docs "
              f"(of {len(docs)})", file=sys.stderr)
        sys.exit(1)
    print(f"docs-map-check: {len(docs)} docs, all reachable from {MAP}, no broken links")


if __name__ == "__main__":
    main()
