#!/usr/bin/env python3
"""The devshop's reviewer hook (W10.6.7): the independent reviewer runs by itself, so the builder
never chooses whether it does. Contract: kit/notes/revamp/workstreams/W10-v2.md § W10.6.7.

  review-hook.py gate   PreToolUse: before a PR create, a push to a branch with an open PR, or an
                        edit of the PR's title or body, run ../reviewer/review.sh on the committed
                        HEAD with the PR's words. Only a pass lets the call through (exit 0); every
                        other result blocks it (exit 2, the reason on stderr for Claude).
  review-hook.py post   PostToolUse: put that pass on the PR as the comment pr-comment.sh renders,
                        if the PR's head is the reviewed commit and its words are the reviewed ones;
                        words that differ are reviewed again as posted, and that verdict is posted.

Input: Claude Code's hook JSON on stdin. Feedback, not a wall: an agent that controls its session
can skip all of this. The walls are GitHub's rules, required CI and the owner's approval.
"""
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.parse

HERE = os.path.dirname(os.path.realpath(__file__))
REVIEWER = os.path.join(os.path.dirname(HERE), "reviewer")
REVIEW, RENDER, WORDS = (os.path.join(REVIEWER, f) for f in ("review.sh", "pr-comment.sh", "pr-words.sh"))
OUTCOME = {0: "pass", 1: "fail", 2: "could-not-run", 3: "ask-owner"}
GITHUB_TOOL = re.compile(r"^mcp__.*github.*__([a-z_]+)$")
PR_TOOLS = ("create_pull_request", "update_pull_request")  # reviewed; hooks.json names the same tools
REMOTE_COMMIT = ("push_files", "create_or_update_file", "delete_file", "update_pull_request_branch")
HEAD_WAIT = 10  # seconds the post waits for GitHub to show the pushed head
REVIEW_TIMEOUT = 1100  # seconds; review.sh stops itself at 900
OWNER = "Stop and tell the owner what happened, with the line above; don't retry until they decide."


class Block(Exception):
    """Stops the call: the message goes to Claude."""


def cnr(why):
    raise Block(f"devshop reviewer hook: could not run: {why}\n{OWNER}")


def run(argv, cwd=None, data=None, timeout=120):
    try:
        return subprocess.run(argv, cwd=cwd, input=data, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as e:
        cnr(f"{argv[0]}: {e}")


def git(top, *args):
    p = run(["git", *args], cwd=top)
    return p.stdout.strip() if p.returncode == 0 else None


# --- Which calls are ours, read from the tool call.

def classify(data):
    """None if the call isn't reviewed; else a dict with kind create|edit|push|remote-commit."""
    if not isinstance(data, dict) or not isinstance(data.get("tool_input"), dict):
        cnr("the hook input is not a tool call")
    tool, inp = data.get("tool_name", ""), data["tool_input"]
    cwd = data.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    m = GITHUB_TOOL.match(tool)
    if m and m.group(1) == "create_pull_request":
        return {"kind": "create", "cwd": cwd, "slug": f"{inp.get('owner')}/{inp.get('repo')}",
                "title": inp.get("title"), "body": inp.get("body") or "",
                "base": inp.get("base"), "head": inp.get("head")}
    if m and m.group(1) == "update_pull_request":
        if "title" not in inp and "body" not in inp:
            return None
        return {"kind": "edit", "cwd": cwd, "slug": f"{inp.get('owner')}/{inp.get('repo')}",
                "number": inp.get("pullNumber"), "title": inp.get("title"), "body": inp.get("body"),
                "base": inp.get("base")}
    if m and m.group(1) in REMOTE_COMMIT:
        return {"kind": "remote-commit", "slug": f"{inp.get('owner')}/{inp.get('repo')}", "tool": m.group(1),
                "owner": inp.get("owner"), "branch": inp.get("branch")}
    if tool == "Bash":
        return classify_bash(str(inp.get("command", "")), cwd)
    return None


HEREDOC = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
REVIEWED_COMMAND = re.compile(r"(^|[;&|(])\s*(gh\s+pr\s+(create|edit)|git\s+(\S+\s+)*?push)\b", re.M)


def strip_heredocs(command):
    """The command without its heredoc bodies: they are data, not commands, and their quotes needn't balance."""
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


PUNCT = set(";&|()<>\n")


def segments(command):
    """The simple commands in a Bash command line, as word lists (split at ; && || | & ( ) and newlines).
    Redirections (2>&1, >file, &>/dev/null, <in) are dropped with their target and fd number."""
    lex = shlex.shlex(command, posix=True, punctuation_chars="".join(sorted(PUNCT)))
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = ""
    words = list(lex)  # ValueError on an unclosed quote
    out, seg, target = [], [], False
    for w in words:
        operator = bool(w) and set(w) <= PUNCT
        if target and not operator:
            target = False
            continue
        target = False
        if operator and ("<" in w or ">" in w):
            if seg and seg[-1].isdigit():
                seg.pop()
            target = True
        elif operator:
            if seg:
                out.append(seg)
            seg = []
        else:
            seg.append(w)
    if seg:
        out.append(seg)
    return out


GIT_OTHER_REPO = ("--git-dir", "--work-tree", "--namespace")
CHANGES_DIR = ("cd", "pushd", "popd")


def operation(seg):
    """('push', args, dir) | ('create', args, None) | ('edit', args, None) | None for one simple command."""
    i = 0
    while i < len(seg) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[i]) or seg[i] in ("command", "exec", "env", "time")):
        i += 1
    w = seg[i:]
    if not w:
        return None
    prog = os.path.basename(w[0])
    if prog == "git":
        j, cdir, other_repo = 1, None, False
        while j < len(w) and w[j].startswith("-"):
            opt = w[j].split("=", 1)[0]
            other_repo = other_repo or opt in GIT_OTHER_REPO
            if w[j] in ("-C", "-c", *GIT_OTHER_REPO) and j + 1 < len(w):
                cdir = w[j + 1] if w[j] == "-C" else cdir
                j += 2
            else:
                j += 1
        if j < len(w) and w[j] == "push":
            if other_repo:
                cnr("git --git-dir/--work-tree/--namespace push: push from the worktree, or use git -C <dir>")
            return ("push", w[j + 1:], cdir)
    if prog == "gh" and w[1:3] in (["pr", "create"], ["pr", "edit"]):
        return (w[2], w[3:], None)
    return None


def classify_bash(command, cwd):
    command = strip_heredocs(command)
    try:
        segs = segments(command)
        ops = [o for o in map(operation, segs) if o]
    except ValueError as e:
        if REVIEWED_COMMAND.search(command):
            cnr(f"can't split the command into words ({e})")
        return None
    if not ops:
        return None
    if len(ops) > 1:
        cnr("this command pushes, creates or edits a PR more than once; run them as separate calls")
    if ops and any(seg[0] in CHANGES_DIR for seg in segs):
        cnr("this command changes directory and pushes, creates or edits a PR; run them as separate calls "
            "(or use git -C <dir>)")
    kind, args, cdir = ops[0]
    cwd = os.path.join(cwd, cdir) if cdir else cwd
    if kind == "push":
        return parse_push(args, cwd)
    return parse_gh(kind, args, cwd)


GH_VALUE = {"-t": "title", "--title": "title", "-b": "body", "--body": "body", "-F": "body-file",
            "--body-file": "body-file", "-B": "base", "--base": "base", "-H": "head", "--head": "head",
            "-R": "repo", "--repo": "repo", "-a": "x", "--assignee": "x", "-l": "x", "--label": "x",
            "-m": "x", "--milestone": "x", "-p": "x", "--project": "x", "-r": "x", "--reviewer": "x",
            "--add-assignee": "x", "--remove-assignee": "x", "--add-label": "x", "--remove-label": "x",
            "--add-project": "x", "--remove-project": "x", "--add-reviewer": "x", "--remove-reviewer": "x",
            "--remove-milestone": "flag", "-d": "flag", "--draft": "flag", "--no-maintainer-edit": "flag",
            "-T": "unknowable", "--template": "unknowable", "--recover": "unknowable", "-f": "unknowable",
            "--fill": "unknowable", "--fill-first": "unknowable", "--fill-verbose": "unknowable",
            "-w": "unknowable", "--web": "unknowable", "-e": "unknowable", "--editor": "unknowable",
            "--dry-run": "unknowable"}


# What the shell may expand inside a word: any "$" ($(…), ${…}, $VAR, and an unquoted $(…) that the
# splitter leaves as a bare "$") or a backtick. Quoting is gone once the command is split, so a
# single-quoted '$5' is refused too: such words go in a --body-file.
SHELL_EXPANSION = re.compile(r"[$`]")


def parse_gh(kind, args, cwd):
    """gh pr create / gh pr edit: the words, base, head and repo it names."""
    got, pos, i = {}, [], 0
    while i < len(args):
        a, val = args[i], None
        if a.startswith("--") and "=" in a:
            a, val = a.split("=", 1)
        elif re.match(r"^-[A-Za-z].+", a) and a[:2] in GH_VALUE:
            a, val = a[:2], a[2:]
        if not a.startswith("-") or a == "-":
            pos.append(a)
            i += 1
            continue
        what = GH_VALUE.get(a)
        if what is None:
            cnr(f"gh pr {kind}: unknown flag {a}")
        if what == "unknowable":
            cnr(f"gh pr {kind} {a}: the hook can't know the PR's words; pass --title and --body or --body-file")
        if what == "flag":
            i += 1
            continue
        if val is None:
            if i + 1 >= len(args):
                cnr(f"gh pr {kind}: {a} needs a value")
            val, i = args[i + 1], i + 2
        else:
            i += 1
        if SHELL_EXPANSION.search(val):
            cnr(f"gh pr {kind} {a}: the shell expands this value, so the hook can't know it; "
                "write the body to a file and pass --body-file, with a plain --title")
        got[what] = val
    if "body-file" in got:
        if got["body-file"] == "-":
            cnr(f"gh pr {kind} --body-file -: the hook can't read stdin; use a file")
        try:
            with open(os.path.join(cwd, got["body-file"]), encoding="utf-8") as f:
                got["body"] = f.read()
        except OSError as e:
            cnr(f"can't read the body file: {e}")
    if kind == "create":
        if pos:
            cnr(f"gh pr create: unexpected argument {pos[0]}")
        return {"kind": "create", "cwd": cwd, "slug": got.get("repo"), "title": got.get("title"),
                "body": got.get("body", ""), "base": got.get("base"), "head": got.get("head"), "gh": True}
    if "title" not in got and "body" not in got:
        return None
    if len(pos) > 1:
        cnr(f"gh pr edit: unexpected argument {pos[1]}")
    sel = pos[0] if pos else None
    m = re.match(r"^(?:https://\S+/pull/)?(\d+)$", sel or "")
    return {"kind": "edit", "cwd": cwd, "slug": got.get("repo"), "number": int(m.group(1)) if m else None,
            "branch": None if (m or sel is None) else sel, "title": got.get("title"), "body": got.get("body"),
            "base": got.get("base")}


GIT_PUSH_VALUE = {"--repo", "-o", "--push-option", "--receive-pack", "--exec"}
GIT_PUSH_REFUSED = {"--all", "--branches", "--mirror", "--delete", "-d", "--prune"}


def parse_push(args, cwd):
    pos, i = [], 0
    while i < len(args):
        a = args[i]
        if a.split("=", 1)[0] in GIT_PUSH_REFUSED:
            cnr(f"git push {a}: push the branch by name")
        if a in GIT_PUSH_VALUE:
            i += 2
            continue
        if not a.startswith("-"):
            pos.append(a)
        i += 1
    remote = pos[0] if pos else "origin"
    if remote != "origin":
        cnr(f"git push {remote}: the hook reviews pushes to origin only")
    targets = []
    for spec in pos[1:]:
        src, _, dst = spec.lstrip("+").partition(":")
        targets.append((src, dst or src))
    return {"kind": "push", "cwd": cwd, "targets": targets}


# --- The worktree and GitHub.

def worktree(cwd):
    top = git(cwd, "rev-parse", "--show-toplevel") if os.path.isdir(cwd) else None
    if not top:
        cnr(f"{cwd} is not a git worktree")
    branch = git(top, "symbolic-ref", "--short", "-q", "HEAD")
    url = git(top, "remote", "get-url", "origin") or ""
    m = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?/?$", url)
    if not m:
        cnr("origin is not a GitHub-style <owner>/<repo> remote")
    return top, branch, f"{m.group(1)}/{m.group(2)}", git(top, "rev-parse", "HEAD")


def gh_json(path):
    p = run(["gh", "api", path])
    if p.returncode != 0:
        cnr(f"gh api {path} failed: {(p.stderr or p.stdout).strip()[:300]}")
    try:
        return json.loads(p.stdout)
    except ValueError:
        cnr(f"gh api {path} returned no JSON")


def open_pr(slug, branch):
    head = urllib.parse.quote(f"{slug.split('/')[0]}:{branch}", safe=":/")  # a ref name may hold & # = ?
    prs = gh_json(f"repos/{slug}/pulls?head={head}&state=open")
    return prs[0] if isinstance(prs, list) and prs else None


def canonical(title, body):
    p = run([WORDS], data=json.dumps({"title": title, "body": body}))
    if p.returncode != 0:
        cnr(f"pr-words.sh: {p.stderr.strip()}")
    return p.stdout


def sha256(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def pending_path(top, branch):
    common = git(top, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return os.path.join(common, "devshop", "reviews", branch.replace("/", "__"), "pending.json")


# --- The review.

def review(top, base, words):
    """Runs review.sh; returns (outcome, verdict path, REVIEW line). Blocks if it can't trust the result."""
    if git(top, "fetch", "-q", "origin", base) is None:
        cnr(f"can't fetch the base branch {base} from origin")
    fd, path = tempfile.mkstemp(prefix="devshop-pr-words.", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(words)
        p = run([REVIEW, "--base", f"origin/{base}", "--pr", path], cwd=top, timeout=REVIEW_TIMEOUT)
    finally:
        os.unlink(path)
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("REVIEW: ")]
    if len(lines) != 1:
        cnr(f"review.sh printed {len(lines)} REVIEW: lines (exit {p.returncode}); stderr: {p.stderr.strip()[-300:]}")
    m = re.match(r"^REVIEW: (\S+) · .* · (\S+)$", lines[0])
    if not m or OUTCOME.get(p.returncode) != m.group(1):
        cnr(f"review.sh exit {p.returncode} doesn't match its line: {lines[0]}")
    return m.group(1), m.group(2), lines[0], p.stderr


def explain(outcome, vpath, line, stderr, after=False):
    """The message for Claude about a review that isn't a pass (after=True: the call already went through)."""
    try:
        with open(vpath, encoding="utf-8") as f:
            v = json.load(f)
    except (OSError, ValueError):
        v = {}
    items = []
    if outcome in ("fail", "ask-owner"):
        items = [f"- unmet {a.get('item')}: {a.get('evidence')}" for a in v.get("acceptance", []) if not a.get("met")]
        items += [f"- {x.get('severity')} · {x.get('lens')}{' · ' + x['file'] if x.get('file') else ''}: "
                  f"{x.get('what')} — fix: {x.get('fix')}" for x in v.get("findings", []) if x.get("severity") != "low"]
    if outcome == "fail" and after:
        return "\n".join([line, "The independent review failed. Blocking findings:", *items,
                          "Fix them, commit, and push (the push is reviewed again by itself)."])
    if outcome == "fail":
        return "\n".join([line, "The independent review failed, so the call was blocked. Blocking findings:", *items,
                          "Fix them, commit, and make the same call again (the review runs again by itself)."])
    reason = v.get("reason") or stderr.strip()[-300:]
    if items:
        items = ["Blocking findings:", *items]
    return "\n".join([line, f"Reason: {reason}" if reason else "", *items, OWNER]).replace("\n\n", "\n")


# --- gate

def gate(call):
    if call["kind"] == "remote-commit":
        if call["tool"] == "update_pull_request_branch":
            raise Block("Updating a PR's branch on GitHub makes a commit no review sees. Merge the base locally, "
                        "commit, and `git push` instead (the push is reviewed).")
        if call.get("branch") and open_pr(call["slug"], call["branch"]):
            raise Block(f"Branch {call['branch']} has an open PR, and a commit made on GitHub is never reviewed. "
                        "Commit locally and `git push` instead (the push is reviewed).")
        return 0
    top, branch, slug, head = worktree(call["cwd"])
    if branch:  # a pass recorded for an earlier call that then failed must not reach this call's post
        try:
            os.unlink(pending_path(top, branch))
        except FileNotFoundError:
            pass
    if call["kind"] == "push":
        return gate_push(call, top, branch, slug, head)
    if not branch:
        cnr("HEAD is detached; check out the PR's branch")
    if call.get("slug") and call["slug"] != slug:
        cnr(f"the call targets {call['slug']}, but this worktree's origin is {slug}")
    if call["kind"] == "create":
        if not isinstance(call.get("title"), str) or not call["title"].strip():
            cnr("the PR has no title")
        if call.get("head") and call["head"].split(":")[-1] != branch:
            cnr(f"the PR's head {call['head']} is not the current branch {branch}")
        remote = (git(top, "ls-remote", "origin", f"refs/heads/{branch}") or "").split("\t")[0]
        if remote != head:
            raise Block(f"Push the branch first: origin's {branch} is {remote[:12] or 'missing'}, HEAD is {head[:12]}. "
                        "The review is for the PR's head commit, so the PR is created after the push.")
        base = call.get("base") or default_branch(top, slug)
        words = canonical(call["title"], call.get("body") or "")
        number = None
    else:  # edit
        pr = gh_json(f"repos/{slug}/pulls/{call['number']}") if call.get("number") else open_pr(slug, call.get("branch") or branch)
        if not pr:
            cnr("no open PR to edit for this branch")
        if pr["head"]["ref"] != branch or pr["head"]["sha"] != head:
            cnr(f"the PR's head ({pr['head']['ref']} at {pr['head']['sha'][:12]}) is not this worktree's HEAD; check it out first")
        base = call.get("base") or pr["base"]["ref"]
        title = call["title"] if call.get("title") is not None else pr["title"]
        words = canonical(title, call["body"] if call.get("body") is not None else pr.get("body"))
        number = pr["number"]
    return decide(top, branch, head, base, words, number, call["kind"])


def gate_push(call, top, branch, slug, head):
    targets = call["targets"] or ([("HEAD", branch)] if branch else [])
    reviewed = []
    for src, dst in targets:
        dst = branch if dst == "HEAD" else re.sub(r"^refs/heads/", "", dst)
        pr = open_pr(slug, dst)
        if not pr:
            continue
        if dst != branch or src not in ("HEAD", branch, f"refs/heads/{branch}"):
            cnr(f"this push updates {dst}, which has an open PR, from {src}; check it out and push HEAD")
        reviewed.append(pr)
    if not reviewed:
        return 0
    pr = reviewed[0]
    return decide(top, branch, head, pr["base"]["ref"], canonical(pr["title"], pr.get("body")), pr["number"], "push")


def default_branch(top, slug):
    ref = git(top, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
    if ref and ref.startswith("origin/"):
        return ref[len("origin/"):]
    return gh_json(f"repos/{slug}").get("default_branch") or cnr("can't tell the default branch")


def decide(top, branch, head, base, words, number, kind):
    outcome, vpath, line, stderr = review(top, base, words)
    if outcome != "pass":
        raise Block(explain(outcome, vpath, line, stderr))
    path = pending_path(top, branch)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"kind": kind, "commit": head, "verdict": vpath, "words": sha256(words), "base": base, "number": number}, f)
    print(line)
    return 0


# --- post

def post(call):
    if call["kind"] not in ("create", "edit", "push"):
        return 0
    top, branch, slug, head = worktree(call["cwd"])
    if not branch:
        return 0
    path = pending_path(top, branch)
    try:
        with open(path, encoding="utf-8") as f:
            pend = json.load(f)
        if pend.get("kind") != call["kind"]:
            raise ValueError("recorded for another kind of call")
    except (OSError, ValueError):
        if call["kind"] == "push":
            return 0  # a push to a branch with no open PR is not reviewed
        raise Block("devshop reviewer hook: no passing review is recorded for this call, so no verdict was posted; "
                    "the PR's review-verdict check will show it missing. Tell the owner.")
    pr = gh_json(f"repos/{slug}/pulls/{pend['number']}") if pend.get("number") else open_pr(slug, branch)
    if not pr:
        raise Block(f"devshop reviewer hook: no open PR for {branch}, so the verdict was not posted.")
    for _ in range(HEAD_WAIT):  # GitHub can show the old head for a moment after a push
        if pr["head"]["sha"] == pend["commit"]:
            break
        time.sleep(1)
        pr = gh_json(f"repos/{slug}/pulls/{pr['number']}")
    if pr["head"]["sha"] != pend["commit"]:
        raise Block(f"devshop reviewer hook: the PR's head is {pr['head']['sha'][:12]}, the reviewed commit "
                    f"{pend['commit'][:12]}; the verdict was not posted. Did the call fail?")
    words = canonical(pr["title"], pr.get("body"))
    outcome, vpath, line, stderr = "pass", pend["verdict"], "", ""
    if sha256(words) != pend["words"]:
        outcome, vpath, line, stderr = review(top, pr["base"]["ref"], words)
        if vpath == "-":
            raise Block(explain(outcome, vpath, line, stderr, after=True))
    rendered = run([RENDER, vpath])
    if rendered.returncode != 0:
        cnr(f"pr-comment.sh: {rendered.stderr.strip()}")
    p = run(["gh", "api", "-X", "POST", f"repos/{slug}/issues/{pr['number']}/comments", "--input", "-"],
            data=json.dumps({"body": rendered.stdout}))
    if p.returncode != 0:
        raise Block(f"devshop reviewer hook: the verdict was not posted: {(p.stderr or p.stdout).strip()[:300]}")
    os.unlink(path)
    if outcome != "pass":
        raise Block("The PR's words on GitHub differ from the reviewed ones, so they were reviewed again as posted:\n"
                    + explain(outcome, vpath, line, stderr, after=True))
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("gate", "post"):
        print("usage: review-hook.py gate|post < hook input", file=sys.stderr)
        return 2
    try:
        try:
            data = json.load(sys.stdin)
        except ValueError:
            cnr("the hook input is not JSON")
        call = classify(data)
        if call is None:
            return 0
        return gate(call) if sys.argv[1] == "gate" else post(call)
    except Block as b:
        print(str(b), file=sys.stderr)
        return 2
    except Exception as e:  # a bug here must block, never pass
        print(f"devshop reviewer hook: could not run: {type(e).__name__}: {e}\n{OWNER}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
