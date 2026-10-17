---
name: build
description: Build an approved change (its spec has the owner's "go") or a bug fix (its failing test): code, tests and docs together, then hand over to `devshop:pr`.
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
- **Disciplines:** each one touched (frontend, backend, data, UI, security…): its guideline in
  `/opt/devshop-current/guidelines/` if any; a UI with no baseline: `/opt/devshop-current/templates/ui/`.
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
- A change to what a page renders: once its tests pass, gstack's `/design-review` on a local run,
  as `/opt/devshop-current/guidelines/ui.md` § Design review says.
- Noticed something the change doesn't need? Fix it only when the task needs it or it sits in
  lines you already edit. Otherwise log it, don't fix it: a row in the project's `FINDINGS.md`
  (from `/opt/devshop-current/templates/findings.md`, which has the rules), or a sighting on the
  row it matches. One about the devshop is kept for the hand-over block (`devshop:pr` § 3), never
  written in the project.
- Root cause over band-aid: a mitigation is labelled as one, with the root cause named beside it.
- Fix loops: real logs before a second attempt, each retry fresh with what was tried; then ask.
- Something the spec didn't foresee is a spec change: raise it with the owner (`intent`, step 5).
- Small, logical commits; subjects describe the observable change.

## 4. Hand over

- Built, and the new and affected tests and fast checks pass: invoke `devshop:pr` to open the PR.
- A later round (a reviewer fail, an owner comment) is built here under § 3, then `devshop:pr` again.
