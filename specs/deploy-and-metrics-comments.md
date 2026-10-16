# A merged PR follows its deploy, then says how the change went

**Go:** pending

## Intent

The owner (2026-10-16): "Every project's merged PR should tell me how its deploy is going and, once
it lands, how the change went":

1. "A deploy comment that follows the deploy, one comment edited in place: **Merged** (seconds
   after the merge, while the checks re-run on main) → **Deploying** → **Live in production** or
   **failed**. If the deploy never happens, it ends in a final state […], never stuck at 'checks
   running'."
2. "A metrics comment posted by the Claude session once the deploy comment reaches a final state,
   about five lines", with real numbers from the website's PR 7:

   > **How this change went** · request to live **27 min**
   >
   > - **Time:** 11 min Claude working · 13 min waiting on you · 3 min deploying
   > - **Your input:** 4 answers in chat · 1 PR comment · 1 approval
   > - **Cost:** $4.05 ($3.88 session + $0.17 reviewer)
   > - **Quality:** 2 pushes · 0 red CI runs · reviewer passed 2 of 2

Why each matters to them: request to live is speed; waiting on you grows when questions are too
many or too vague; your input measures autonomy ("a request, a go and an approval is the ideal");
cost lets them compare changes; quality separates clean work from retries.

The website built a deploy comment of its own (`scripts/deploy-comment.mjs`, its spec, the
`deploy` job, and a reviewed but unbuilt draft for part 1); "lift it into the devshop rather than
starting over". Then: "New projects get it from setup, not only on upgrade": the `ci.yml` template
gains the comment jobs and a marked slot for the project's own deploy step, and the setup docs say
how to fill it. The website reported (2026-10-16): "after the session squash-merges a PR it is
auto-unsubscribed, so the project's deploy comment never reaches it".

## Decisions

### Part 1: the deploy comment (CI)

- **Lifted from the website:** its `scripts/deploy-comment.mjs` becomes the devshop's
  `runtime/scripts/deploy-comment.mjs`, a `devshop`-owned file in `runtime/project-files.txt`
  (project path `scripts/deploy-comment.mjs`); the website's draft spec (branch
  `claude/laughing-galileo-7kitqq`) is the design for the states, its review's rules included. The
  deploy itself, the version, the rollback line and the domain check stay the project's; the script
  takes them as inputs (`env`), as the website's already does (owner, 2026-10-16)
- **The marker becomes `<!-- devshop-deploy -->`**, the same in every project. The website's
  existing `<!-- website-deploy -->` comments on already-merged PRs are left alone (Claude,
  2026-10-16)
- **One comment, a state line under the marker:** `<!-- state:<state> run:<run id>/<attempt> -->`.
  The states and headlines (Claude, from the website draft, 2026-10-16):

  | State        | Written by                                           | Headline                                                                                       |
  | ------------ | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
  | merged       | the `announce` job, when the run on `main` starts    | **Merged** · `<sha>` · checks running on `main`, then the deploy · link to the run             |
  | deploying    | the `deploy` job's first step, before the slot       | **Deploying** `<sha>` to production · link to the run                                          |
  | live         | the `deploy` job, after the slot succeeded           | **Live in production** · `<sha>` · `<url>` (then the website's lines: versions, domain, undo)  |
  | failed       | the `deploy` job, after the slot failed or timed out | the website's two texts: "may be live" (uploaded) or "production is unchanged" (not uploaded)  |
  | not-deployed | the `report` job                                     | **Not deployed** · `<sha>` · `<reason>`; production is unchanged · link to the run             |
  | superseded   | the `report` job                                     | **Not deployed on its own** · `<sha>` · it ships with `<newer sha>`'s deploy · link to the run |

  `live`, `failed`, `not-deployed` and `superseded` are the final states. A deploy comment with a
  marker and no state line counts as final.

- **Writes only move forward:** `merged` never replaces a comment of the same run that is already
  deploying or final; no state replaces a comment from a newer run id; a newer run id (a full
  re-run) starts over at merged; a re-run of failed jobs keeps its run id, so the `deploy` job's
  states replace a `not-deployed` of the same run (website draft's review, 2026-10-16)
- **The `report` job** needs `fast`, `slow` and `deploy`, runs
  `if: always() && github.event_name == 'push' && github.ref == 'refs/heads/main'`, and leaves a
  final comment, or a comment whose deploy succeeded, alone. Otherwise it writes: `superseded` when
  `fast` and `slow` succeeded, `deploy` was cancelled while the comment is still `merged`, and a
  newer run on `main` exists; else `not-deployed` with the reason from the results: "checks failed
  on `main`", "checks were cancelled or timed out", "the run was cancelled", or, the comment still
  `deploying`, "the deploy didn't finish; production may have changed" (website draft's review)
- **A slot for the project's deploy:** the template's `deploy` job (needs `fast` and `slow`,
  environment `production`, concurrency group `production`) has one step with `id: deploy` between
  clearly marked comment lines, which the project replaces with its own deploy. The slot's comment
  lists the outputs the comment reads, with the website's names so its `deploy.sh` needs no change:
  `url` (the live https URL), `version`, `previous_version`, `rollback` (the line that undoes it),
  `deployed` (`yes` once the new version was uploaded) and `site_url` / `site_smoke` (the domain
  check: `passed`, `failed` or `skipped`). As shipped, the slot only sets `none=yes`, and the
  comment then ends `not-deployed` with the reason "this project has no deploy step yet", so a new
  project's merged PR never claims a deploy that didn't happen (owner asked for the slot; the
  placeholder's behaviour is Claude's, 2026-10-16)
- **Setup docs:** the devshop has no separate project setup guide; a project starts from the
  template, so the slot's how-to lives in the template's comments, and `docs/README.md`'s CI entry
  says the template carries the deploy comment and the slot. The Cloudflare specifics (`wrangler`,
  versions, rollback) go to the Cloudflare stack home when W10.10.2 builds it (owner, 2026-10-16)
- **The comment jobs never touch the merge or the deploy:** `announce` and `report` are
  `continue-on-error` and so are the comment steps in `deploy`; they get the job's GitHub token
  only (`contents: read`, `pull-requests: write`, and `actions: read` for `report`, to find a newer
  run), never a deploy secret. `fast` and `slow` stay unchanged, with no job-level `if` or
  `continue-on-error`. The comment needs only Node's built-ins, which `ubuntu-24.04` runners have,
  so the comment jobs install nothing (Claude, 2026-10-16)
- **The merged PR may not be findable in the first seconds:** `merged` retries the lookup for up to
  30 seconds, then exits 0 quietly; the `deploying` step creates the comment then (website draft's
  review)
- Accepted gap: if `announce` is still running when `deploy` starts, both may create a comment; not
  guarded, since `deploy` waits for both tiers, minutes (website draft)

### Part 2: the metrics comment (the session)

- **The session reports, not CI:** CI can't see the request time, working and waiting time or the
  session's cost (owner, 2026-10-16)
- **The scripts compute, the model only passes values:** `runtime/scripts/change-metrics.py`
  computes every number from a transcript and a PR data file and renders the comment;
  `runtime/scripts/change-metrics.sh` gathers the PR data with `gh api`, waits for the deploy
  comment's final state, and posts. The model's only inputs are values it reads from tools that
  scripts can't call: the session's cost from `get_session` (owner: "The scripts compute the
  metrics, not the model")
- **Staying awake past the merge, tested on 2026-10-16:** `subscribe_pr_activity` on an
  already-merged PR is accepted, but neither a new comment nor its edit on that PR woke the session
  (both were the session's own, which may be filtered as echoes, so this doesn't show a bot's edit
  would be lost), and the deploy comment only ever changes by edits. A `send_later` check-in
  armed for 07:36:00 fired at 07:36:23 and reached the session, even mid-turn. So after the squash-merge, `devshop:pr` §5 arms a `send_later` check-in 5
  minutes later; at each check-in it runs `change-metrics.sh post`: deploy comment final → it
  posts; not final yet → re-arm 5 minutes later; 60 minutes after the merge with no final state, it
  posts with the deploy "unknown". It also re-subscribes, which costs nothing, but nothing relies on
  a PR event (owner: "Test which works on a merged PR. Don't assume.")
- **When the clock starts:** at the owner's message `devshop:intent` classified as a change, not at
  session start, since one session can carry several changes. `devshop:intent` § 1 runs
  `change-metrics.sh start --cost <usd from get_session>`, which records that message (the latest
  owner message in the transcript) and the session's cost at that moment. **This touches
  `devshop:intent`, outside the files the owner listed;** without it the session cost can only be
  "unknown" for a session's second change (see open questions) (Claude, 2026-10-16)
- **Where each number comes from** (owner's method, measured by hand on PR 7; definitions Claude's):
  - _Request to live:_ the start message to the deploy comment reaching a final state.
  - _Claude working:_ from each owner message or wake (a PR event, a check-in, a task notification)
    to the last assistant event before the next one, from the start to the merge.
  - _Waiting on you:_ each `AskUserQuestion` from its call to its answer, plus each idle gap before
    the merge that ended with the owner acting (a chat message, or a PR comment, review or approval
    by the owner). An idle gap that ended otherwise (CI, a check-in) is shown as "waiting on CI"
    only when it is 1 minute or more.
  - _Deploying:_ the merge to the final state.
  - _Your input:_ answers in chat are `AskUserQuestion` answers plus the owner's chat messages after
    the start message; PR comments are the owner's comments and non-approving reviews with text on
    the PR; approvals are their `APPROVED` reviews. The owner is any non-bot account other than the
    PR's author.
  - _Cost:_ session cost now minus at the start, plus the `$` in each reviewer comment's footer.
  - _Quality:_ pushes are distinct head commits that ran CI on the PR; red CI runs are those runs
    that concluded `failure`; reviewer "passed n of m" counts the reviewer's verdict comments.
    Lighthouse is left out: no project reports it anywhere a script can read.
- **A number that can't be measured shows "unknown",** never a guess, and never blocks or delays
  the merge or the deploy (owner)
- **A separate comment, marked `<!-- devshop-metrics -->`,** posted as the session's account (it
  can't edit the bot's deploy comment); one per PR, a second `post` does nothing. The headline
  names a final state other than live: "request to deploy failed", "request to not deployed",
  "request to superseded" (owner: "If the deploy failed, post anyway and say so in the headline")
- **The session gone** (the container reclaimed before the deploy ends): no metrics comment, an
  accepted gap; nothing is built for it (owner)
- **The test case is PR 7:** a fixture transcript and PR data built from that session's events and
  the PR's GitHub data, checked against the owner's hand-measured numbers. Where a definition here
  gives a different number than the hand count, the PR says which and why rather than tuning the
  definition to match (owner: "Reconstruct PR #7's numbers above as a test case if you can")

### How it reaches projects

- The PR body says what a project adapts on upgrade: copy `scripts/deploy-comment.mjs` (the upgrade
  does), wire the `announce`, `deploying`, live/failed and `report` steps from the template, and
  put its deploy in the slot. For the website: replace its own `scripts/deploy-comment.mjs` and its
  marker, move `deploy.sh` into the slot unchanged, and add the new jobs. The website changes only
  in its own session with `devshop:upgrade`, after this merges (owner)

## Acceptance items

- **AC-1** `deploy-comment.mjs merged` creates the comment in the merged state (headline from the
  table, state line with run id and attempt) when the PR has none, replaces one from an older run,
  leaves a same-run deploying or final comment unchanged, and retries the PR lookup for up to 30 s,
  then exits 0 without commenting
- **AC-2** `deploy-comment.mjs deploying` moves a merged comment to deploying, or creates it; the
  PR still has exactly one `<!-- devshop-deploy -->` comment
- **AC-3** `deployed` and `failed` write the website's live and failed texts (its AC-1 to AC-3: the
  commit, URL, versions, domain line, rollback line; "may be live" when uploaded, "production is
  unchanged" when not) over a merged or deploying comment and record a final state
- **AC-4** `deployed` with `NONE=yes` (the unfilled slot) writes not-deployed with "this project has
  no deploy step yet", never "Live in production"
- **AC-5** `report` maps the job results to the table: superseded (with the newer commit), each
  not-deployed reason, and nothing over a final comment, a comment with no state line, or a
  successful deploy
- **AC-6** No state replaces a comment from a newer run; only a comment by `github-actions[bot]`
  starting with `<!-- devshop-deploy -->` is ever edited
- **AC-7** Bad arguments or settings (no token, a malformed commit or run id, an unknown reason or
  state) exit 2 before calling GitHub; a GitHub API error exits 1
- **AC-8** The template `runtime/templates/ci.yml` passes `ci-tiers-check.py`; its `announce` job
  runs only for pushes to `main`, with no `needs`; `deploy` needs `fast` and `slow` and runs
  `deploying` before the slot step `deploy` and `deployed` / `failed` after it; `report` has the
  `if` of the Decisions; `announce` and `report` are `continue-on-error`, the comment steps too,
  with the permissions of the Decisions and no secret in any comment step's `env`; `fast` and
  `slow` are unchanged
- **AC-9** The template's slot is marked and its comment names the outputs the comment reads (`url`,
  `version`, `previous_version`, `rollback`, `deployed`, `site_url`, `site_smoke`) and how to fill
  it; `docs/README.md`'s CI entry mentions the deploy comment and the slot
- **AC-10** `runtime/project-files.txt` lists `runtime/scripts/deploy-comment.mjs` as `devshop`,
  project path `scripts/deploy-comment.mjs`, and `project-files.py check` passes on a project with
  an identical copy and reports one that differs
- **AC-11** `change-metrics.py` on the PR 7 fixture prints the comment of the Intent's shape, and
  each of its numbers either equals the owner's hand count or differs by a reason the PR states
- **AC-12** On sample transcripts, `change-metrics.py` counts working time from each owner message
  or wake to the last assistant event before the next one; `AskUserQuestion` time and idle gaps
  ended by the owner as waiting on you; gaps ended by CI or a check-in apart; starts the clock at
  the recorded start message, not at session start (a second change in one session counts only its
  own messages)
- **AC-13** It counts answers in chat (`AskUserQuestion` answers plus owner chat messages after the
  start, mid-turn ones included), the owner's PR comments and approvals, pushes, red CI runs and
  reviewer passes from the PR data, and sums the reviewer footers' `$`
- **AC-14** A number that can't be measured (no cost at the start, no deploy comment, an
  unreadable reviewer footer) shows "unknown", and the rest still render; a final state other than
  live is named in the headline
- **AC-15** `change-metrics.sh post` exits with "not final yet" (a distinct code) while the deploy
  comment isn't final, posts once when it is, and a second `post` on the same PR posts nothing;
  `start` records the latest owner message and the given cost; bad arguments exit 2
- **AC-16** `devshop:pr` §4–5 and `devshop:intent` § 1 say when to run `change-metrics.sh start`,
  that after the merge the session re-subscribes and arms `send_later` check-ins, what to do on
  "not final yet", and the 60-minute limit; `skills-check.py` passes — verified by review: read the
  two skills

## Out of scope

- Any change in the website before its own upgrade session
- Cloudflare specifics in the template (W10.10.2's stack home)
- Metrics when the session is gone before the deploy ends
- Lighthouse or other project quality numbers in the metrics comment
- A metrics comment for changes merged without a PR, or for PRs the session didn't open
- The canary (W10.10.5)
- Filing anything in `ROADMAP.md` or `FINDINGS.md` for this change
