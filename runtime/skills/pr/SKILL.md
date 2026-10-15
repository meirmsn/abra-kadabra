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
  on what changed and why it matters, the Announcement in the app user's words. Claim only what you
  have just read from the real signal (CI, the preview).
- From the build: the `STACKS:` line goes in the engineering details; a conflict where the project
  won is said; **Changed after the go** lists the owner's answers recorded in the spec.
- **Screenshots go on the PR, never only in chat:** for a UI change, one per core-flow step and
  state-table state at the final commit; `/opt/devshop-current/scripts/pr-assets.sh <image>...`
  adds them to the branch without changing a file and prints the lines for **Screenshots:**; exit
  2: ask the owner. After a new commit, take and add them again.
- Keep per-round detail out of the body.

## 2. Through the reviewer

- Run `/opt/devshop-current/reviewer/ship.sh --title "<title>" --body-file <body file>`. It checks
  the words have the template's shape, then only on the independent reviewer's pass does it push,
  create or update the PR (ready) with those exact words and post the verdict; it is the only way to
  a PR.
- Exit 1: fix what it lists, the words here, code under `devshop:build` § 3 (a spec change:
  `devshop:intent` step 5); commit, and run `ship.sh` again. Exit 2 or 3: ask the owner.
- Run it again after any change to code or words. With only the words changed, it reviews the
  words alone (W10.9.7).

## 3. Low findings

- The reviewer's `low` findings don't block. Don't fix them in this PR unless one is clear, quick
  and important. List each under **Low findings** with what you did.
- One about the devshop itself is a finding for the devshop's ledger: tell the owner at the end of
  the session.

## 4. Tell the owner

- Once the PR is ready, in chat: its link and its one-line summary.
