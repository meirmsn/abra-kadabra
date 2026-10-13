---
name: build
description: Build an approved change (its spec has the owner's "go") or a bug fix (its failing test). One agent writes code, tests and docs together, then opens the PR from the devshop's template.
---

# Build

From an approved spec, or a bug fix's failing test (TARGET § L3 Build). The mechanical steps are the
scripts named here; run them, never retype them as shell.

## 1. Before writing

- A change needs its recorded "go":
  `/opt/devshop-current/scripts/spec-check.py --go specs/<change>.md` passes. Else back to `intent`.
- One branch per change, cut from a freshly fetched default branch.
- **You are the only writer.** Helpers (subagents) only read, e.g. to search a large codebase. They
  never edit, commit or push.

## 2. Load what applies, nothing else

- **The project:** its `CLAUDE.md` and the docs its map (`docs/README.md`) links for what you touch.
- **Stack homes:** run `/opt/devshop-current/scripts/stack-homes.sh <project root>` and read each
  file it prints. Its `STACKS:` line goes in the PR's engineering details.
- **Disciplines:** for each discipline the change touches (frontend, backend, data, UI,
  security…), the guideline in `/opt/devshop-current/guidelines/` if this version has one. A UI in a
  project with no baseline yet starts from `/opt/devshop-current/templates/ui/`.
- On conflict the project wins; say so in the PR.
- **CI:** none yet? Start from `/opt/devshop-current/templates/ci.yml`; declare
  `scripts/check-fast.sh` (unit) and `scripts/check-slow.sh` (end to end).

## 3. Code, tests and docs together

- A bug fix starts with its failing test: run it and see it fail.
- Find what's related with things that can't drift: tests that mirror the source tree, the test
  runner's related-tests mode, coverage of the changed lines, a search of the docs for changed names
  and paths.
- Review the tests **and** docs around what you touch: edit those whose behaviour changed, remove
  those for behaviour the spec removed, add what's new. Their end state describes the new behaviour.
- Each acceptance item ends up named (`AC-<n>`) in the test that proves it, unless the spec marks it
  "verified by review".
- Run the new and affected tests and the fast checks as you go; the full suite runs in CI.
- Root cause over band-aid: a mitigation is labelled as one, with the root cause named beside it.
- Fix loops: real logs before a second attempt, each retry fresh with what was tried; then ask.
- Something the spec didn't foresee is a spec change: raise it with the owner (`intent`, step 5).
- Small, logical commits; subjects describe the observable change.

## 4. The PR

- Write the body from `/opt/devshop-current/templates/pr-body.md`. Claim only what you have just
  read from the real signal (CI, the preview comment).
- Run `/opt/devshop-current/scripts/pr-body-check.py <body file> "<title>"` until it passes, before
  the PR goes ready.
- Ship it: `/opt/devshop-current/reviewer/ship.sh --title "<title>" --body-file <body file>`. It
  runs the independent reviewer in the VM, and only on a pass pushes, creates or updates the PR
  (ready, not a draft) with those exact words, and posts the verdict (TARGET Verify 2, W10.6.7). It
  is the only way to a PR: `gh pr create` and pushes to a PR's branch are refused. Exit 1: fix the
  findings, commit, ship again. Exit 2 or 3: stop and ask the owner.
- Keep per-round detail out of the body (it goes stale with the next fix); ship again after any
  change to code or words.
- Then tell the owner in chat: the PR link and its one-line summary.
