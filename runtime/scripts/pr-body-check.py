#!/usr/bin/env python3
"""Shape check for a PR body written from runtime/templates/pr-body.md (TARGET § L3 Review).

Usage: pr-body-check.py BODY_FILE [TITLE]
Checks what can be checked without judgement; whether the words are true is the reviewer's job.
  - title (if given): one line, 72 characters at most
  - first line: a one-line summary (plain text, at most 120 characters, then a blank line)
  - then the summary paragraph: one plain paragraph of 2–3 sentences, before the **Preview:** line
  - a **Preview:** line before the first section, holding a link or "none — <reason>"
  - sections, in order: ## Announcement (optional), ## What you should know, ## Evidence, none
    other, none empty; each holds its labelled lines (see REQUIRED)
  - the Announcement has no developer words: code, AC ids, routes, file names, status codes
  - **Screenshots:** holds at least one image, or says "no UI change"
  - then the engineering details, collapsed: <details><summary>Engineering details</summary> …
    </details>; anything after that (a footer) has no heading
  - no {{placeholder}} left; images are absolute https URLs; GitHub file links are pinned to a
    commit SHA, never a branch (L-30); no image on raw.githubusercontent.com (a private repo's
    viewers get 404); an image from github.com/<o>/<r>/raw/ is linked to itself, [![alt](url)](url), so
    a tap opens it where the mobile app can't show it. Text in code (fences, inline) is quoted, not
    checked for these.
Exit 0 = the body has the shape; 1 = problems (listed); 2 = can't run.
"""
import re
import sys

SECTIONS = ["Announcement", "What you should know", "Evidence"]
OPTIONAL = {"Announcement"}
REQUIRED = {
    "What you should know": ["Behaviour change", "Decisions", "Changed after the go",
                             "Tests deleted or loosened", "Manual steps for you"],
    "Evidence": ["Screenshots", "Reviewer", "CI", "Low findings"],
}
SUMMARY_MAX, TITLE_MAX = 120, 72
COMMENT = re.compile(r"<!--.*?-->", re.S)
# Fences, and inline code, which (as in Markdown) never crosses a blank line: a stray backtick can't
# pair with one paragraphs later and hide what lies between from the checks.
CODE = re.compile(r"^ {0,3}(`{3,}|~{3,}).*?^ {0,3}\1|(`+)[^`\n](?:(?!\n[ \t]*\n).)*?\2", re.S | re.M)
HEADING = re.compile(r"^ {0,3}(#{1,2})\s+(.*?)\s*#*\s*$", re.M)
DETAILS = re.compile(r"<details>\s*<summary>\s*Engineering details\s*</summary>(.*?)</details>", re.S | re.I)
PREVIEW = re.compile(r"^\*\*Preview:\*\*\s*(.*)$", re.M)
LINK = re.compile(r"\[[^\]]+\]\(https?://[^)\s]+\)")
IMAGE = re.compile(r"!\[[^\]]*\]\(\s*<?([^)\s>]+)|<img\s[^>]*src=[\"']([^\"']+)", re.I)
GITHUB_FILE = re.compile(
    r"https?://(?:github\.com/[^/\s]+/[^/\s]+/(?:blob|raw)|raw\.githubusercontent\.com/[^/\s]+/[^/\s]+)/([^/\s)]+)/")
SHA = re.compile(r"^[0-9a-f]{40}$")
# An image linked to itself: [![alt](url)](url). A private repo's github.com/<o>/<r>/raw/ image doesn't
# load in the GitHub mobile app, so it must be a link the viewer can tap to open it (F-NEW-49).
LINKED_IMAGE = re.compile(r"\[!\[[^\]]*\]\(\s*<?([^)\s>]+)>?\s*\)\]\(\s*<?([^)\s>]+)>?\s*\)")
REPO_IMAGE = re.compile(r"^https://github\.com/[^/]+/[^/]+/raw/")
# A sentence ends at . ! or ? (closing quotes or brackets allowed) before a capital, a digit or the
# end, so "e.g. the bus" is one sentence.
SENTENCE_END = re.compile(r"[.!?]+[\"'”’)]*(?=\s+[A-Z0-9\"“‘(]|\s*$)")
SENTENCES = (2, 3)
# Words for developers, not for the person who uses the app (W10.6.9d): code, acceptance item ids,
# routes, file names, HTTP status codes.
DEV_WORDS = re.compile(
    r"`|\bAC-\d+\b|(?<![\w/.:])/[a-z0-9_:-]+(?:/[\w:.-]*)*|\b[\w-]+\.(?:md|py|sh|js|mjs|ts|tsx|jsx|json|"
    r"ya?ml|toml|sql|css|html?|lock)\b|\bHTTP\b|\bstatus code\b|\b404\b|"
    r"\b[45]\d\d\s+(?:error|page|status|response|code)\b|\b(?:error|status|code)\s+[45]\d\d\b", re.I)


def label_present(text, label):
    return re.search(r"^\s*[-*]?\s*\*\*" + re.escape(label) + r":\*\*\s*\S", text, re.M)


def item(content, label):
    """The text of a labelled list item: from its label to the next labelled item."""
    m = re.search(r"^\s*[-*]?\s*\*\*" + re.escape(label) + r":\*\*", content, re.M)
    nxt = re.search(r"^\s*[-*]?\s*\*\*[^*\n]+:\*\*", content[m.end():], re.M)
    return content[m.end():m.end() + nxt.start()] if nxt else content[m.end():]


def check_paragraph(rest):
    """The summary paragraph: the one plain paragraph between the summary and the **Preview:** line."""
    blocks, cur = [], []
    for line in rest:
        if PREVIEW.match(line) or HEADING.match(line):
            break
        if line.strip():
            cur.append(line.strip())
        elif cur:
            blocks.append(cur)
            cur = []
    if cur:
        blocks.append(cur)
    if not blocks:
        return ["no summary paragraph: 2–3 sentences under the one-line summary, saying what changed and why it matters"]
    problems = []
    if len(blocks) > 1:
        problems.append(f"the summary paragraph must be one paragraph before the **Preview:** line, found {len(blocks)}")
    para = " ".join(blocks[0])
    if re.match(r"^([#>|<!*+-]|\d+\.)", para):
        problems.append(f"the summary paragraph must be plain prose, not markup: {para[:60]}")
    n = len(SENTENCE_END.findall(para))
    if not SENTENCES[0] <= n <= SENTENCES[1]:
        problems.append(f"summary paragraph: {n} sentence{'s' if n != 1 else ''}, want {SENTENCES[0]}–{SENTENCES[1]}")
    return problems


def check(body, title):
    problems = []
    if title is not None:
        if "\n" in title or not title.strip():
            problems.append("title: must be one non-empty line")
        elif len(title) > TITLE_MAX:
            problems.append(f"title: {len(title)} characters, at most {TITLE_MAX}")

    for m in re.finditer(r"\{\{.*?\}\}", CODE.sub("", body), re.S):
        problems.append(f"placeholder left: {m.group(0)[:60]}")

    text = COMMENT.sub("", body)
    lines = text.splitlines()
    first = next((i for i, line in enumerate(lines) if line.strip()), None)
    if first is None:
        return problems + ["body is empty"]
    summary = lines[first].strip()
    if re.match(r"^([#>|<!*+-]|\d+\.)", summary):
        problems.append(f"first line must be a plain one-line summary, not markup: {summary[:60]}")
    if len(summary) > SUMMARY_MAX:
        problems.append(f"summary: {len(summary)} characters, at most {SUMMARY_MAX}")
    if first + 1 < len(lines) and lines[first + 1].strip():
        problems.append("summary must be one line, followed by a blank line")
    else:
        problems += check_paragraph(lines[first + 1:])

    details = DETAILS.search(text)
    before_details = text[:details.start()] if details else text
    headings = [(len(m.group(1)), m.group(2), m.start(), m.end()) for m in HEADING.finditer(before_details)]
    top = headings[0][2] if headings else len(before_details)

    preview = [m for m in PREVIEW.finditer(text)]
    if not preview:
        problems.append("no **Preview:** line")
    elif preview[0].start() > top:
        problems.append("the **Preview:** line must come before the first section")
    elif not (LINK.search(preview[0].group(1)) or re.match(r"none\s+[—–-]\s*\S", preview[0].group(1))):
        problems.append("**Preview:** needs a link (the deploy platform's PR comment) or 'none — <reason>'")

    names = [h[1] for h in headings]
    for level, name, *_ in headings:
        if level == 1 or name not in SECTIONS:
            problems.append(f"unexpected heading: {'#' * level} {name}")
    known = [n for n in names if n in SECTIONS]
    if known != sorted(known, key=SECTIONS.index) or len(set(known)) != len(known):
        problems.append(f"sections out of order or repeated: {known}; want {SECTIONS} (Announcement optional)")
    for name in SECTIONS:
        if name not in known and name not in OPTIONAL:
            problems.append(f"missing section: ## {name}")

    for i, (level, name, start, end) in enumerate(headings):
        stop = headings[i + 1][2] if i + 1 < len(headings) else len(before_details)
        content = before_details[end:stop]
        if not content.strip():
            problems.append(f"empty section: ## {name}")
        for label in REQUIRED.get(name, []):
            if not label_present(content, label):
                problems.append(f"## {name}: no **{label}:** line")
        if name == "Announcement":
            words = sorted({m.group(0) for m in DEV_WORDS.finditer(content)})
            if words:
                problems.append("Announcement: developer words, write it for the person who uses the app: "
                                + ", ".join(words))
        if name == "Evidence" and label_present(content, "Screenshots"):
            shots = item(content, "Screenshots")
            if not IMAGE.search(CODE.sub("", shots)) and not re.match(r"\s*no UI change\b", shots, re.I):
                problems.append("**Screenshots:** needs at least one image on the PR (one per core-flow step and "
                                "state-table state), or 'no UI change'")

    if not details:
        problems.append("no collapsed <details><summary>Engineering details</summary> … </details>")
    else:
        if not details.group(1).strip():
            problems.append("engineering details are empty")
        if HEADING.search(text[details.end():]):
            problems.append("a heading after the engineering details")

    prose = CODE.sub("", text)  # quoted in code, an image or link is an example, not evidence
    linked = {m.group(1) for m in LINKED_IMAGE.finditer(prose) if m.group(1) == m.group(2)}
    for m in IMAGE.finditer(prose):
        url = m.group(1) or m.group(2)
        if not url.startswith("https://"):
            problems.append(f"image is not an absolute https URL (upload it, or link it by commit): {url}")
        elif REPO_IMAGE.match(url) and url not in linked:
            problems.append(f"image from the repo without a link to itself, which the GitHub mobile app can't show "
                            f"inline; link it to itself, [![alt](url)](url), as pr-assets.sh prints: {url}")
        elif url.startswith("https://raw.githubusercontent.com/"):
            problems.append(f"image on raw.githubusercontent.com, which a private repo's viewers get as 404; "
                            f"use https://github.com/<owner>/<repo>/raw/<sha>/<path>: {url}")
    for m in GITHUB_FILE.finditer(prose):
        if not SHA.match(m.group(1)):
            problems.append(f"GitHub file linked by '{m.group(1)}', not a commit SHA (L-30): {m.group(0)}")
    return problems


def main():
    if len(sys.argv) not in (2, 3):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    try:
        body = open(sys.argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"FAIL: can't read {sys.argv[1]}: {e}", file=sys.stderr)
        sys.exit(2)
    problems = check(body, sys.argv[2] if len(sys.argv) == 3 else None)
    for p in problems:
        print(f"pr-body: {p}")
    if problems:
        sys.exit(1)
    print("pr-body: shape ok")


if __name__ == "__main__":
    main()
