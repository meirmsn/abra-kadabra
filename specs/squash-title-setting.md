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
- **Exit 2** (Claude's proposal, 2026-11-10): only an admin of the repo can change the setting and
  the agent has Write, so it is could-not-run, "stop and ask the owner", not a fail to fix and ship
  again (exit 1). Not exit 3: that is the reviewer's ask-owner verdict, and the pr skill treats 2
  and 3 alike. The message names the repo, each wrong field with the value GitHub reported, and the
  fix: Settings → General → Pull Requests, allow squash merging, its default commit message "Pull
  request title and description"
- **Where it runs** (Claude's proposal, 2026-11-10): right after the origin slug is parsed, so after
  the body and title checks (words that fail them are still exit 1 first) and before the open-PR
  lookup, the base fetch and `review.sh`. Nothing is pushed and no PR is created, updated or
  commented on
- **One read of the repo** (Claude's proposal, 2026-11-10): `ship.sh` reads `gh api repos/<slug>`
  once; the base fallback to `default_branch` uses the same response. A failed call, output that
  isn't JSON, or a missing or null field is could-not-run, never a pass. This is new: today that
  call's failure is ignored and it is made only when the base is unknown, so a run with `--base` or
  an open PR now also stops when the call fails
- **This repo is already set** (checked 2026-11-10 with `gh api`: `PR_TITLE`, `PR_BODY`)
- **Post-merge step, the owner's:** set the website repo's default squash message to "Pull request
  title and description"

## Acceptance items

- **AC-1** `ship.sh` exits 2 without calling `review.sh`, pushing, or making any `-X` call to
  GitHub when the repo reports `squash_merge_commit_title` other than `PR_TITLE` (GitHub's default
  `COMMIT_OR_PR_TITLE` included), and its output names that field and the value reported. Shown by
  `tests/ship.test.sh`
- **AC-2** The same holds when `squash_merge_commit_message` is other than `PR_BODY`
  (`COMMIT_MESSAGES`, `BLANK`). Shown by `tests/ship.test.sh`
- **AC-3** The same holds when either field is missing or null, when the `repos/<slug>` call alone
  fails, and when it prints something that isn't JSON. Shown by `tests/ship.test.sh`, whose stub
  `gh` gains those modes for that path and reports `PR_TITLE` and `PR_BODY` by default
- **AC-4** With `PR_TITLE` and `PR_BODY`, `ship.sh` behaves as before: every existing case in
  `tests/ship.test.sh` passes
- **AC-5** On a run that needs the default branch from GitHub (the single-branch clone: no
  `--base`, no open PR, no `origin/HEAD`), the stub's call log has exactly one `api repos/<slug>`
  line. Shown by `tests/ship.test.sh`
- **AC-6** `ship.sh`'s header comment (the exit 2 list included), `runtime/reviewer/README.md`
  § ship and the new-project steps' squash item say that `ship` checks the setting and stops with
  exit 2 when it is wrong; the two places that say projects have no `scripts/pr-title-check.py`
  (`ship.sh`'s comment above the title check, README § ship step 1) say projects have it too —
  verified by review: read the passages

## Out of scope

- Checking commit subjects, or the other merge settings (`allow_squash_merge`, merge commits and
  rebase merges, which `pr-assets.sh` checks before screenshots), unless the owner adds them
- Changing any repo's settings: only the owner can
- A CI check of the setting
- What happens after `ship`: the setting changed before the merge, or a merge that sets its own
  commit title
