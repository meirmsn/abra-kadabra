#!/usr/bin/env python3
"""The devshop's review guard (W10.6.7): a PreToolUse hook that keeps changes reaching a PR through
`ship` only. ship.sh reviews HEAD with the PR's words and pushes them together; this guard reviews
nothing. It refuses the other ways of putting a change on a PR and lets everything else through:

  - Bash: `gh pr create`; `gh pr edit` with a title, body or base; `git push` while the current
    branch has an open PR (or when that can't be checked).
  - GitHub tools: create_pull_request; update_pull_request with a title, body or base;
    update_pull_request_branch; push_files, create_or_update_file, delete_file on a branch with an
    open PR.

Exit 0 allows the call; exit 2 refuses it, the reason on stderr for Claude. Contract:
kit/notes/revamp/workstreams/W10-v2.md § W10.6.7. Feedback, not a wall: a wrapped push (bash -c, a
script, gh api) is not seen. The walls are GitHub's rules, required CI and the owner's approval.
"""
import json
import os
import re
import shlex
import subprocess
import sys
import urllib.parse

SHIP = "/opt/devshop-current/reviewer/ship.sh --title <title> --body-file <file>"
# The GitHub tools the guard handles; hooks.json's matcher and fallback name the same ones.
GITHUB_TOOLS = ("create_pull_request", "update_pull_request", "update_pull_request_branch",
                "push_files", "create_or_update_file", "delete_file")
GITHUB_TOOL = re.compile(r"^mcp__.*github.*__([a-z_]+)$")
WORDS_FIELDS = ("title", "body", "base")
GH_EDIT_WORDS = {"-t", "--title", "-b", "--body", "-F", "--body-file", "-B", "--base"}
# Words that can stand before the command in a simple command: assignments are matched separately.
PREFIXES = {"command", "exec", "env", "time", "nice", "then", "do", "else", "elif", "if", "while",
            "until", "{", "!", "nohup"}
HEREDOC = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
NAMED = re.compile(r"\bgh\s+pr\s+(create|edit)\b|\bgit\b[^\n;&|]*\bpush\b")
PUNCT = set(";&|()\n")


class Refuse(Exception):
    """Refuses the call: the message goes to Claude."""


def refuse(why):
    raise Refuse(f"devshop review guard: {why}\nChanges reach a PR through ship, which reviews them first: {SHIP}")


def strip_heredocs(command):
    """The command without its heredoc bodies: they are data, not commands."""
    out, pending = [], []
    for line in command.split("\n"):
        if pending:
            dash, word = pending[0]
            if (line.lstrip("\t") if dash else line) == word:
                pending.pop(0)
            continue
        out.append(line)
        pending = [(m.group(1) == "-", m.group(3)) for m in HEREDOC.finditer(line)]
    return "\n".join(out)


def segments(command):
    """The simple commands in a command line, as word lists (redirections stay as words: the guard
    never reads a command's arguments beyond its name, so they can't change its answer)."""
    lex = shlex.shlex(command, posix=True, punctuation_chars="".join(sorted(PUNCT)))
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = ""
    out, seg = [], []
    for w in lex:  # ValueError on an unclosed quote
        if w and set(w) <= PUNCT:
            if seg:
                out.append(seg)
            seg = []
        else:
            seg.append(w)
    if seg:
        out.append(seg)
    return out


def edits_words(arg):
    """Whether a gh pr edit argument sets the title, body or base: --title=x, -t x, or glued -tx."""
    return arg.split("=", 1)[0] in GH_EDIT_WORDS or (not arg.startswith("--") and arg[:2] in GH_EDIT_WORDS)


def command_words(seg):
    i = 0
    while i < len(seg) and (seg[i] in PREFIXES or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[i])):
        i += 1
    return seg[i:]


def check_bash(command, cwd):
    command = strip_heredocs(command)
    try:
        segs = segments(command)
    except ValueError:
        if NAMED.search(command):
            refuse("this command can't be split into words, and it names gh pr create/edit or git push")
        return
    for seg in segs:
        w = command_words(seg)
        if not w:
            continue
        prog = os.path.basename(w[0])
        if prog == "gh":
            k = 1  # gh's global flags may come first: gh -R owner/repo pr create
            while k < len(w) and w[k].startswith("-"):
                k += 2 if w[k] in ("-R", "--repo") else 1
            if w[k:k + 2] == ["pr", "create"]:
                refuse("gh pr create is refused")
            if w[k:k + 2] == ["pr", "edit"] and any(edits_words(a) for a in w[k + 2:]):
                refuse("gh pr edit of the title, body or base is refused")
        if prog == "git":
            j, cdir = 1, cwd
            while j < len(w) and w[j].startswith("-"):
                if w[j] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace") and j + 1 < len(w):
                    cdir = os.path.join(cdir, w[j + 1]) if w[j] == "-C" else cdir
                    j += 2
                else:
                    j += 1
            if j < len(w) and w[j] == "push":
                check_push(cdir)


def git(cwd, *args):
    try:
        p = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return p.stdout.strip() if p.returncode == 0 else None


def open_pr(slug, branch):
    head = urllib.parse.quote(f"{slug.split('/')[0]}:{branch}", safe=":/")  # a ref name may hold & # = ?
    try:
        p = subprocess.run(["gh", "api", f"repos/{slug}/pulls?head={head}&state=open"],
                           capture_output=True, text=True, timeout=60)
        prs = json.loads(p.stdout) if p.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, ValueError):
        prs = None
    if not isinstance(prs, list):
        refuse(f"can't check whether {branch} has an open PR (gh failed), so a push or commit to it is refused")
    return bool(prs)


def check_push(cwd):
    branch = git(cwd, "symbolic-ref", "--short", "-q", "HEAD")
    if not branch:
        return  # detached or not a repo: nothing a PR tracks
    m = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?/?$", git(cwd, "remote", "get-url", "origin") or "")
    if not m:
        return  # no GitHub-style origin
    if open_pr(f"{m.group(1)}/{m.group(2)}", branch):
        refuse(f"git push to {branch}, which has an open PR, is refused")


def check_github(tool, inp):
    slug = f"{inp.get('owner')}/{inp.get('repo')}"
    if tool == "create_pull_request":
        refuse("creating a PR with the GitHub tool is refused")
    if tool == "update_pull_request" and any(k in inp for k in WORDS_FIELDS):
        refuse("editing a PR's title, body or base with the GitHub tool is refused")
    if tool == "update_pull_request_branch":
        refuse("updating a PR's branch on GitHub makes a commit no review sees; merge the base locally and ship")
    if tool in ("push_files", "create_or_update_file", "delete_file") and inp.get("branch") \
            and open_pr(slug, inp["branch"]):
        refuse(f"a commit made on GitHub to {inp['branch']}, which has an open PR, is never reviewed; commit locally and ship")


def main():
    try:
        try:
            data = json.load(sys.stdin)
        except ValueError:
            refuse("the hook input is not JSON")
        if not isinstance(data, dict) or not isinstance(data.get("tool_input"), dict):
            refuse("the hook input is not a tool call")
        tool, inp = data.get("tool_name", ""), data["tool_input"]
        m = GITHUB_TOOL.match(tool)
        if m and m.group(1) in GITHUB_TOOLS:
            check_github(m.group(1), inp)
        elif tool == "Bash":
            check_bash(str(inp.get("command", "")), data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
        return 0
    except Refuse as r:
        print(str(r), file=sys.stderr)
        return 2
    except Exception as e:  # a bug here must refuse, never pass
        print(f"devshop review guard: could not check this call: {type(e).__name__}: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
