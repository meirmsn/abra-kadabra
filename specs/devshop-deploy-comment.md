# The devshop's own PRs follow their release, and the reviewer's rounds are all counted

**Go:** pending

## Intent

After `specs/deploy-and-metrics-comments.md` merged (PR 129), the metrics comment for that PR,
dry-run before posting, said "reviewer passed 2 of 7": the reviewer ran 8 rounds and passed 3. The
script counts the rounds whose `REVIEW:` line reached the transcript, and one round's line never
did. The devshop's own PRs also get no deploy comment, since only the project template has the
jobs. The owner (2026-10-16):

> - do the fix of count
> - make this work for the devshop
> - to confirm: you do then post in the pr the metrics (as an edit to the deploy comment) not only
>   keep them in the session right

## Decisions

- **The metrics are posted on the PR, as their own comment under the deploy comment,** not as an
  edit of it: the deploy comment is written by GitHub's CI bot, and the session's account can't edit
  another account's comment; CI, which could, can't see the session's times or cost (decided in
  `specs/deploy-and-metrics-comments.md`; asked of the owner again, 2026-10-16, since their words
  said "as an edit")
- **The reviewer's rounds come from its verdict files,** which `review.sh` writes for every round
  to `<git common dir>/devshop/reviews/<branch, / as __>/NNN-<commit>.json`, each with `branch`,
  `created`, `outcome` and `reviewer.cost_usd`. The rounds of a change are the union, by path, of:
  - the numbered files (`[0-9][0-9][0-9]-*.json`; `latest.json` is a link to the newest and is
    skipped) in the PR's branch directory created from the clock's start to a minute after the merge
    (the reviewer's clock and GitHub's can differ by seconds), and
  - the files the transcript's `REVIEW:` lines name in that window (a round run from another
    checkout).

  A `could-not-run` file is no round (the reviewer didn't review); `ask-owner` is a round that didn't
  pass. A counted file that can't be read, or has no cost, makes the reviewer's cost unknown. With no
  clock start the files aren't used (the branch's directory may hold another change's rounds); with
  no round found at all, the PR's verdict footers stand in, as before. The directory is
  `git rev-parse --git-common-dir` (as `review.sh` finds it, worktrees included) and the PR's
  `head.ref`. Rejected: the transcript's lines alone, which miss a round whose output the session
  didn't read in full (owner: "do the fix of count", 2026-10-16; details Claude's, from the spec
  review)

- **Whether a PR has a deploy comment to wait for is decided by its merge commit's `ci.yml`**
  (`git show <merge commit>:.github/workflows/ci.yml` has an `announce` job), not today's: PR 129
  merged before the devshop had the jobs, and gets "no deploy comment". With no deploy comment,
  Claude working ends at the merge, not at the post, so a comment posted later counts no later work
  (Claude, 2026-10-16, found checking PR 129 by hand and in the spec review)
- **The devshop's release is its deploy:** for the devshop, a merge is live once `fast` and `slow`
  pass on `main`; projects get it when they pin it. Its `ci.yml` gains the template's `announce`,
  `deploy` and `report` jobs, calling `runtime/scripts/deploy-comment.mjs`, with the template's
  main-only `if`s, `needs`, `continue-on-error`, timeouts, permissions and `production` concurrency
  group; its `deploy` job has no environment, no secret and no setup step (nothing is deployed or
  installed). Its header comment describes them (owner: "make this work for the devshop",
  2026-10-16)
- **The devshop's `scripts/deploy.sh`** deploys nothing. From `BUILD_SHA`, `BEFORE`
  (`github.event.before`), `GITHUB_SERVER_URL` and `GITHUB_REPOSITORY` it writes `deployed=yes`
  first (`main` already has the commit), then `version` (the commit, 12 characters),
  `previous_version` (`BEFORE`, 12 characters; `unknown` when all zeros, a first push), `url` (the
  commit's page, built at run time, so no repository name is in the repo) and `rollback`
  ("revert `<sha>`", a squash merge's one commit). A missing input exits 2, so the comment says the
  deploy failed and may be live, which is true (Claude, 2026-10-16, from the spec review)
- **The headline stays "Live in production"** for the devshop too: its production is `main`, the
  version projects pin. Rejected: a setting for other words ("Released on `main`"), one more moving
  part (Claude, 2026-10-16, asked of the owner)
- **PR 129 gets its metrics comment first,** once this merges, with the session's cost read at its
  merge ($25.75, `get_session` at 15:32), so its marker records it; then this change's PR gets its
  own, whose session cost starts there (Claude, 2026-10-16, from the spec review)

## Acceptance items

- **AC-1** `change-metrics.py` counts the reviewer's rounds, passes and cost from the numbered
  verdict files of the PR's branch directory in the window, plus the files the transcript's
  `REVIEW:` lines name, each once; `latest.json`, `could-not-run` files, files outside the window and
  another branch's files are left out; `ask-owner` counts as a round not passed; an unreadable file
  makes the cost unknown; with no clock start no file is used; with no round found the PR's footers
  stand in; PR 7's fixture still gives its comment
- **AC-2** Whether a deploy comment is awaited follows the `ci.yml` given for the merge commit; with
  none awaited, the comment says "no deploy comment" and Claude working ends at the merge
- **AC-3** `change-metrics.sh post` passes the verdict directory (the git common directory and the
  PR's `head.ref`) and the merge commit's `ci.yml`
- **AC-4** The devshop's `.github/workflows/ci.yml` has `announce`, `deploy` and `report` with the
  template's `if`s, `needs`, `continue-on-error`, timeouts, permissions and concurrency, calling
  `runtime/scripts/deploy-comment.mjs`, `deploy` with no environment and no setup step; `fast` and
  `slow` unchanged; `ci-tiers-check.py` passes. `tests/ci-template-deploy.test.sh` checks both files,
  each with its own script path and environment, and fails on a known-bad copy of each
- **AC-5** The devshop's `scripts/deploy.sh` writes `deployed=yes`, `version`, `previous_version`
  (`unknown` for an all-zero `BEFORE`), `url` and `rollback` from its four inputs, with no secret,
  and exits 2 when an input is missing
- **AC-6** After the merge: PR 129's metrics comment says "no deploy comment" and "reviewer passed 3
  of 8", posted first; this change's PR shows its deploy comment reaching "Live in production", then
  its metrics comment — verified by review: the two PRs' comments

## Out of scope

- Different headline words for the devshop
- Telling projects of a new devshop version, or when sessions pick it up
- Changing how the reviewer stores its verdicts
