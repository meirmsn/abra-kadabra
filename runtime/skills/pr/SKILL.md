---
name: pr
description: Open or update the PR for a change `devshop:build` built: the template's body, screenshots, `ship.sh` through the reviewer, then tell the owner.
---

# PR

The PR is what the owner judges, on a phone (TARGET § L3 Review). The mechanical steps are the
scripts named here; run them, never retype them as shell. Code changes, in any round, are built
under `devshop:build` § 3; this skill only puts them on the PR.

## 1. The body

- Write it from `/opt/devshop-current/templates/pr-body.md`: the summary, a 2–3 sentence paragraph
  on what changed and why it matters, the Announcement in the app user's words (guidance: `ship.sh`
  checks the shape, the owner the words). Claim only what you
  have just read from the real signal (CI, the preview).
- From the build: the `STACKS:` line goes in the engineering details; a conflict where the project
  won is said; **Changed after the go** lists the owner's answers recorded in the spec.
- **Screenshots go on the PR, never only in chat:** for a UI change, one per core-flow step and
  state-table state at the final commit, light and dark;
  `/opt/devshop-current/scripts/pr-assets.sh <image>...` adds them to the branch without changing
  a file and prints the image lines for the template's table (a row per step or state: label,
  light, dark); exit 2: ask the owner. After a new commit, take and add them again.
- Keep per-round detail out of the body.

## 2. Through the reviewer

- Run `/opt/devshop-current/reviewer/ship.sh --title "<title>" --body-file <body file>`. It checks
  the words have the template's shape, then only on the independent reviewer's pass does it push,
  create or update the PR (ready) with those exact words and post the verdict; it is the only way to
  a PR.
- Exit 1: fix what it lists, the words here, code under `devshop:build` § 3 (a spec change:
  `devshop:intent` step 5); commit, and run `ship.sh` again. Exit 2 or 3: ask the owner.
- Run it again after any change to code or words.

## 3. Low findings

- The reviewer's `low` findings don't block. Don't fix them in this PR unless one is clear, quick
  and important. List each under **Low findings** with what you did; that list is their record.
- One about the devshop itself goes to the owner at the end of the session only if it blocked this
  task or will block the next change; otherwise the list above is enough.

## 4. Tell the owner, then watch the PR

- Once the PR is ready, in chat: its link and its one-line summary.
- Subscribe the session to the PR's activity (`subscribe_pr_activity`). Its events (reviews,
  comments, CI) wake the session; end the turn, never poll.

## 5. Approval ships, comments are answered (TARGET Review 7–8)

- The owner's approval of the PR's current head, with every required check green on it: squash-merge
  (GitHub's merge tool, method `squash`) without asking for a "merge" message, then say in chat that
  it merged. Checks still running: merge on their green event. Hold only when the approval or the
  chat says to wait, or for a concrete reason: say it and ask. A push after approval needs a new one.
- A comment that would change a decision or acceptance item, a question included ("Could the list
  be sorted…?"), is a question to the owner: answer it on the PR with the options and what each
  changes, and build nothing until they pick (`devshop:intent` § 5 records it). Other asks: build
  under `devshop:build` § 3, then this skill again.
