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

On the third: the metrics are posted on the PR, as their own comment under the deploy comment,
since the session's account can't edit the CI bot's comment (decided in
`specs/deploy-and-metrics-comments.md`); this change keeps that.

## Decisions

- **The reviewer's rounds come from its verdict files:** `review.sh` writes one per round, failed
  and words-only rounds included, to `<git common dir>/devshop/reviews/<branch, / as __>/`, each with
  `branch`, `created`, `outcome` and `reviewer.cost_usd`. `change-metrics.sh` passes that directory;
  the rounds are the files for the PR's branch created between the clock's start and the merge. The
  transcript's `REVIEW:` lines are the fallback when the directory is missing (another checkout),
  then the PR's verdict footers. Rejected: the transcript's lines alone, which miss a round whose
  output the session didn't read in full (owner: "do the fix of count", 2026-10-16)
- **With no deploy comment, Claude working ends at the merge,** not when the comment is posted: a
  comment posted later (PR 129's, after this change) must not count later work. Found while checking
  PR 129's numbers by hand (Claude, 2026-10-16)
- **The devshop's release is its deploy:** for the devshop, a merge is live when `fast` and `slow`
  pass on `main`; projects get it when they pin it. Its `ci.yml` gains the template's `announce`,
  `deploy` and `report` jobs, calling `runtime/scripts/deploy-comment.mjs`; its `scripts/deploy.sh`
  deploys nothing and writes what the comment reads: `version` (the commit, 12 characters),
  `previous_version` (the previous tip of `main`), `url` (the commit's page, built at run time from
  GitHub's variables, so no repository name is in the repo), `rollback` ("revert the merge commit
  `<sha>`") and `deployed=yes`. No environment and no secret: nothing is deployed (owner: "make this
  work for the devshop", 2026-10-16)
- **The headline stays "Live in production"** for the devshop too: its production is `main`, the
  version projects pin. Rejected: a setting for other words ("Released on `main`"), one more moving
  part (Claude, 2026-10-16, asked of the owner)
- **PR 129 gets its metrics comment** once this merges, from the fixed script, with the session's
  cost as read at its merge ($25.75, `get_session` at 15:32): it has no deploy comment, as it merged
  before the devshop had the jobs (owner: "do the fix of count", 2026-10-16)

## Acceptance items

- **AC-1** `change-metrics.py` counts the reviewer's rounds, passes and cost from the verdict files
  of the PR's branch created between the clock's start and the merge (a failed round included; a
  file for another branch, or from before the start or after the merge, left out); without the
  directory it falls back to the transcript's `REVIEW:` lines, then the PR's footers; PR 7's
  fixture still gives its comment
- **AC-2** With no deploy comment, Claude working ends at the merge: work after it doesn't count
- **AC-3** `change-metrics.sh post` passes the checkout's verdict directory for the PR's branch
- **AC-4** The devshop's `.github/workflows/ci.yml` has `announce`, `deploy` and `report` in the
  template's shape (the checks of `tests/ci-template-deploy.test.sh` pass on it, environment aside),
  calling `runtime/scripts/deploy-comment.mjs`; `fast` and `slow` are unchanged and
  `ci-tiers-check.py` passes
- **AC-5** The devshop's `scripts/deploy.sh` writes `url`, `version`, `previous_version`, `rollback`
  and `deployed=yes` from GitHub's variables, uses no secret, and fails with exit 2 when they are
  missing
- **AC-6** After the merge, this change's PR shows its deploy comment reaching Live in production,
  then the session's metrics comment; PR 129 gets its metrics comment with the reviewer passing 3 of
  8 — verified by review: the two PRs' comments

## Out of scope

- Different headline words for the devshop
- Telling projects of a new devshop version, or when sessions pick it up
- Changing how the reviewer stores its verdicts
