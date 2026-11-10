# Ship refuses a repo whose squash merge isn't titled by the PR

**Go:** pending

## Intent

The owner, 2026-11-10: "What happened: [the website]'s devshop v4.0.0 upgrade passed ship.sh with
a 69-char PR title, but its single commit's subject was 77 chars. The squash-merge used the commit
subject, so main's ci.yml `fast` job failed pr-title-check.py ("77 characters; at most 72") and the
deploy never ran. Where: reviewer/ship.sh checks only --title; a one-commit PR's squash subject
defaults to the commit's own subject." Asked which fix to spec, the owner chose "A: check repo
setting": `ship.sh` refuses unless the repo's squash merge is titled by the PR and described by its
body.

The root cause is the repo's merge setting: under GitHub's default (`COMMIT_OR_PR_TITLE`) a
one-commit PR's squash commit takes the commit's subject, not the reviewed title. The new-project
steps (`runtime/templates/new-project-steps.md` Part 1, step 2) already ask the owner for
`squash_merge_commit_title` `PR_TITLE` and `squash_merge_commit_message` `PR_BODY`, but nothing
checks it after set-up, so a repo without it ships until a merge breaks `main`.

## Decisions

- **ship.sh checks the setting, not the commit subjects** (owner, 2026-11-10, "A: check repo
  setting"): with the setting right, the squash commit is the reviewed title and body whatever the
  commits say. Rejected: running `pr-title-check.py` on each commit subject (a mitigation that
  refuses subjects that never reach `main`); reworded skills alone (feedback that can be missed)
- **Exit 2, before the review** (Claude's proposal, 2026-11-10): only someone with admin on the repo
  can change the setting, and the agent has Write, so it is could-not-run ("ask the owner"), not a
  fail to fix and ship again. It runs before `review.sh`, so no review is spent on a PR that would
  land wrong. The message names the repo, each wrong field with the value GitHub reported, and
  where to change it (Settings → General → Pull Requests, default commit message "Pull request
  title and description")
- **Read from the same `gh api repos/<slug>` call** (Claude's proposal, 2026-11-10): `ship.sh` reads
  the repo once; the base fallback to `default_branch` uses the same response. A failed call, output
  that isn't JSON, or a missing or null field is could-not-run, never a pass
- **Post-merge step, the owner's:** set the website repo's default squash message to "Pull request
  title and description"; and this repo's, if its next `ship` reports it

## Acceptance items

- **AC-1** `ship.sh` exits 2 before calling `review.sh`, pushing or touching any PR when the repo
  reports `squash_merge_commit_title` other than `PR_TITLE` (GitHub's default `COMMIT_OR_PR_TITLE`
  included), and its output names that field and the value reported. Shown by `tests/ship.test.sh`
- **AC-2** The same holds when `squash_merge_commit_message` is other than `PR_BODY`
  (`COMMIT_MESSAGES`, `BLANK`). Shown by `tests/ship.test.sh`
- **AC-3** The same holds when either field is missing or null, when `gh api repos/<slug>` fails,
  and when it prints something that isn't JSON. Shown by `tests/ship.test.sh`
- **AC-4** With `PR_TITLE` and `PR_BODY`, `ship.sh` behaves as before: every existing case in
  `tests/ship.test.sh` passes, with the stub repo reporting those values
- **AC-5** The repo is read once per run: `gh api repos/<slug>` appears once in the stub's call log
  on a run that also needs the default branch (no `--base`, no open PR, no `origin/HEAD`). Shown
  by `tests/ship.test.sh`
- **AC-6** `ship.sh`'s header comment, `runtime/reviewer/README.md` § ship and the new-project steps'
  squash item say that `ship` checks the setting and stops with exit 2 when it is wrong —
  verified by review: read the three passages

## Out of scope

- Checking commit subjects, or the other merge settings (`allow_squash_merge`, merge commits and
  rebase merges: `pr-assets.sh` checks those two before screenshots)
- Changing any repo's settings: only the owner can
- A CI check of the setting: CI's token reads the same response, but a wall here is the owner's
  call, not this change's
