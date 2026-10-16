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
  `runtime/scripts/deploy-comment.mjs` (mode 755, like the website's), a `devshop`-owned file in
  `runtime/project-files.txt` (project path `scripts/deploy-comment.mjs`); the website's draft spec
  (branch `claude/laughing-galileo-7kitqq`) is the design for the states, its review's rules
  included, corrected below where it got GitHub's re-runs wrong. The deploy itself, the version, the
  rollback line and the domain check stay the project's; the script takes them as inputs (`env`),
  as the website's already does (owner, 2026-10-16)
- **The marker becomes `<!-- devshop-deploy -->`**, the same in every project. The website's
  existing `<!-- website-deploy -->` comments on already-merged PRs are left alone (Claude,
  2026-10-16)
- **One comment, a state line under the marker:**
  `<!-- state:<state> run:<run id>/<attempt> at:<UTC time> -->`; `at` is when the state was
  written, so the metrics read the final state's time from it, not from the comment's edit time
  (which a later canary edit would move). The states and headlines (Claude, from the website draft,
  2026-10-16):

  | State        | Written by                                                     | Headline                                                                                       |
  | ------------ | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
  | merged       | the `announce` job, when the run on `main` starts              | **Merged** · `<sha>` · checks running on `main`, then the deploy · link to the run             |
  | deploying    | the `deploy` job, after checkout and before the slot           | **Deploying** `<sha>` to production · link to the run                                          |
  | live         | the `deploy` job after the slot succeeded, or `report` (below) | **Live in production** · `<sha>` · `<url>` (then the website's lines: versions, domain, undo)  |
  | failed       | the `deploy` job, after the slot failed or timed out           | the website's two texts: "may be live" (uploaded) or "production is unchanged" (not uploaded)  |
  | not-deployed | the `report` job; or `deploy` when the slot is unfilled        | **Not deployed** · `<sha>` · `<reason>`; production is unchanged · link to the run             |
  | superseded   | the `report` job                                               | **Not deployed on its own** · `<sha>` · it ships with `<newer sha>`'s deploy · link to the run |

  `live`, `failed`, `not-deployed` and `superseded` are the final states. A marker comment with no
  state line (the website's old ones) counts as final.

- **Writes only move forward, per attempt:** a merged PR has one merge commit, so one run on `main`;
  GitHub keeps the run id on every re-run and raises only the attempt. A write from a higher attempt
  replaces any state (a re-run that fixes a failed deploy ends live); within the same attempt a
  state never replaces a later one (`merged` never overwrites deploying or a final state); a lower
  attempt never writes. Rejected: the website draft's "a newer run id starts over", since re-runs
  keep the id (Claude, from the spec review, 2026-10-16)
- **One comment even when writers race:** before writing, the script lists the PR's marker comments
  by `github-actions[bot]`, edits the oldest and deletes any others. A new project's trivial tiers
  can finish within `announce`'s retry window, so two writers creating at once is a real case, not
  an accepted gap (Claude, from the spec review, 2026-10-16)
- **The `report` job** needs `fast`, `slow` and `deploy`, runs
  `if: always() && github.event_name == 'push' && github.ref == 'refs/heads/main'`, and ends every
  run in a final state, creating the comment if there is none (with the same lookup retry):
  - a final comment of this attempt: left alone;
  - `deploy` succeeded but the comment isn't final (its write failed): writes live from `deploy`'s
    job outputs (the slot's outputs, passed through);
  - `fast` and `slow` succeeded, `deploy` cancelled while the comment is still merged, and a newer
    run on `main` exists: superseded, naming that run's commit;
  - otherwise not-deployed, with the reason: "checks failed on `main`" (`fast` or `slow` failed),
    "checks were cancelled or timed out" (`fast` or `slow` cancelled), "the run was cancelled"
    (`deploy` cancelled, no newer run), "the deploy didn't finish; production may have changed"
    (`deploy` failed or cancelled while the comment is still deploying)

  (website draft's review, completed by this spec's review, 2026-10-16)

- **The `deploy` job** runs only for pushes to `main` (job-level
  `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`, allowed because only `fast`
  and `slow` are barred from one), needs `fast` and `slow`, has concurrency group `production`
  without cancelling, and exposes the slot's outputs as job `outputs` for `report` (Claude, from the
  spec review, 2026-10-16)
- **A slot for the project's deploy:** a block of steps between clearly marked comment lines in the
  `deploy` job, after checkout and the `deploying` step, which the project replaces with its own
  (setup, install, deploy); the block's last step has `id: deploy`. The slot's comment lists the
  outputs the comment reads, with the website's names so its `deploy.sh` needs no change: `url` (the
  live https URL), `version`, `previous_version`, `rollback` (the line that undoes it), `deployed`
  (`yes` once the new version was uploaded) and `site_url` / `site_smoke` (the domain check:
  `passed`, `failed` or `skipped`). Its `environment: production` line is part of the slot, left as
  a comment until the project fills it: a job with an environment records a production deployment
  on GitHub, which an empty slot must not. As shipped, the slot's one step sets `none=yes`, and the
  comment ends not-deployed with "this project has no deploy step yet" (owner asked for the slot;
  the placeholder's behaviour is Claude's, 2026-10-16)
- **Setup docs:** the devshop has no project setup guide; a project starts from the template, so the
  slot's how-to lives in the template's comments, and `docs/README.md`'s CI entry says the template
  carries the deploy comment and the slot. The Cloudflare specifics (`wrangler`, versions,
  rollback) go to the Cloudflare stack home when W10.10.2 builds it (where: Claude, 2026-10-16,
  asked of the owner; Cloudflare: owner, 2026-10-16)
- **The comment never blocks or delays the merge or the deploy:** `announce` and `report` are
  `continue-on-error`, and so are the comment steps in `deploy`; each comment step and job has
  `timeout-minutes: 1` (`report`: 2, for its retry), and every GitHub call in the script times out
  after 10 seconds, so a slow GitHub API can't hold the deploy. They get the job's GitHub token only
  (`contents: read`, `pull-requests: write`, and `actions: read` for `report`, to find a newer run),
  never a deploy secret. `fast` and `slow` stay unchanged. The script needs only Node's built-ins,
  which `ubuntu-24.04` runners have, so `announce` and `report` install nothing (Claude, from the
  spec review, 2026-10-16)
- **The merged PR may not be findable in the first seconds:** `merged` retries the lookup for up to
  30 seconds, then exits 0 quietly; the interval and limit are settings, so the tests run fast
  (website draft's review)
- **The old interface keeps working:** `deployed` and `failed` with the website's current `env` (no
  run id) still write the comment, so an upgraded copy of the script doesn't break a project's
  existing calls before its `ci.yml` is rewired (Claude, from the spec review, 2026-10-16)

### Part 2: the metrics comment (the session)

- **The session reports, not CI:** CI can't see the request time, working and waiting time or the
  session's cost (owner, 2026-10-16)
- **The scripts compute, the model only passes values:** `runtime/scripts/change-metrics.py`
  computes every number from the transcript, the change's record and a PR data file, and renders
  the comment; `runtime/scripts/change-metrics.sh` has `start`, `post` and `pr-data` (which gathers
  the PR data with `gh api`). The model's only inputs are values scripts can't read: the session's
  cost from `get_session` (owner: "The scripts compute the metrics, not the model")
- **Staying awake past the merge, tested on 2026-10-16:** `subscribe_pr_activity` on an
  already-merged PR is accepted, but neither a new comment nor its edit on that PR woke the session
  within 3 minutes (both were the session's own, which may be filtered as echoes, so this doesn't
  prove a bot's edit would be lost); the deploy comment only ever changes by edits. A `send_later`
  check-in armed for 07:36:00 fired at 07:36:23 and reached the session while it was working; the
  one armed for 07:51:00 into the idle session fired at 07:51:22 and started a new turn (a `user`
  entry with `origin.kind` `task-notification`). So after the
  squash-merge, `devshop:pr` §5 arms a `send_later` check-in 5 minutes later, and at each check-in
  runs `change-metrics.sh post`: deploy comment final → it posts; not final → re-arm 5 minutes
  later; the script itself says "give up" once 60 minutes have passed since `merged_at`, and then
  posts with the deploy shown as "unknown". No re-subscribe: nothing would rely on it, and its
  events would wake the session for nothing (owner: "Test which works on a merged PR. Don't
  assume."; the choice: Claude, 2026-10-16)
- **A project with no deploy comment** (its `ci.yml` has no `announce` job, such as the devshop
  itself, or the website before it upgrades): `post` doesn't wait; it posts right after the merge
  with "no deploy comment", so no session is held awake for an hour (Claude, from the spec review,
  2026-10-16)
- **When the clock starts:** at the owner's message `devshop:intent` classified as a change, not at
  session start, since one session can carry several changes. `devshop:intent` § 1 runs
  `change-metrics.sh start --cost <usd or "none">`, which records that message (the latest owner
  message in the transcript) and the session's cost then. **This adds one line to
  `devshop:intent`, outside the files the owner listed** (Claude, 2026-10-16, asked of the owner)
- **The change's record:** `start` writes `~/.claude/devshop/changes/<id>.json` (the start message's
  uuid and time, the transcript's path, the cost); `post --pr <n>` matches the record to the PR by
  the PR's branch, written into the record by `devshop:pr` §4 (`change-metrics.sh link --pr <n>`).
  The transcript is the `.jsonl` under `~/.claude/projects/` that holds the start message. A missing
  record or transcript (a container replaced, a change that skipped `start`) makes the session
  numbers "unknown"; `start`, `link` and `post` never fail the step they run in (Claude, from the
  spec review, 2026-10-16)
- **Session cost:** `get_session`'s `external_metadata.usage.cost_usd` now minus at the start. The
  field is absent in a session's first minutes (seen 2026-10-16: absent at 07:34, $3.96 at 07:46),
  which is when a first change starts; when it is absent and the start message is the session's
  first owner message, the start cost is 0 (Claude, from the spec review, 2026-10-16)
- **What counts in the transcript** (seen in a real one, 2026-10-16):
  - _An owner message:_ a `user` entry with `origin.kind` `human`, or a `queued_command` attachment
    (a message sent mid-turn), deduplicated by text and time; a skill's text (`isMeta`), a tool
    result and a compaction summary are not.
  - _A wake:_ a `user` entry that starts a turn with `origin.kind` other than `human` (a check-in
    or PR event arrives as `task-notification`), or a notification queued mid-turn.
  - Subagents' own transcripts (`subagents/`) are not read; their time counts only while the main
    session waits for them.
- **Where each number comes from** (owner's method, measured by hand on PR 7; definitions Claude's):
  - _Request to live:_ the start message to the deploy comment's final state (`at`).
  - _Claude working:_ from each owner message or wake to the last assistant entry before the next
    one, from the start to the merge; overlapping spans counted once.
  - _Waiting on you:_ each `AskUserQuestion` from its call to its answer, plus each idle gap before
    the merge that ended with the owner acting: their chat message, or a wake within 2 minutes after
    their PR comment, review or approval in the PR data.
  - _Waiting on CI:_ the other idle gaps before the merge, shown in the Time line only when 1 minute
    or more, so the Time line adds up to the total.
  - _Deploying:_ the merge to the final state.
  - _Your input:_ answers in chat are the questions answered through `AskUserQuestion` plus the
    owner's chat messages after the start message (the go is one); PR comments are the owner's
    comments and reviews with text; approvals are their `APPROVED` reviews. The owner is the account
    that approved the PR, else every account that isn't a bot (`[bot]` or type `Bot`) or the PR's
    author.
  - _Cost:_ session cost (above) plus the reviewer's: each `REVIEW:` line `ship.sh` printed in the
    transcript names its verdict file, whose `reviewer.cost_usd` counts, failed rounds included;
    when a verdict file is gone, the `$` in the PR's reviewer comment footers stands in.
  - _Quality:_ pushes are the distinct head commits of the PR's `pull_request` runs of the `ci`
    workflow; red CI runs are those runs with any attempt concluded `failure` or `timed_out`;
    "reviewer passed n of m" counts the `REVIEW:` lines (m) and those with outcome `pass` (n).
    Lighthouse is left out: it is in CI logs, in a form each stack writes its own way (Claude,
    2026-10-16, asked of the owner).
  - Minutes are rounded to the nearest whole minute.
- **A number that can't be measured shows "unknown",** never a guess, and never blocks or delays
  the merge or the deploy (owner)
- **The headline names the outcome:** live: "request to live **27 min**"; failed: "**deploy
  failed** · request to failure **27 min**"; not-deployed: "**not deployed** (<reason>) · request
  to merge **24 min**"; superseded: "ships with `<sha>`'s deploy · request to merge **24 min**", the
  Time line then without "deploying" (owner: "If the deploy failed, post anyway and say so in the
  headline"; words Claude's)
- **A separate comment, marked `<!-- devshop-metrics -->`,** posted as the session's account (it
  can't edit the bot's deploy comment); one per PR, a second `post` does nothing (owner)
- **The session gone** (the container reclaimed before the deploy ends), or a PR the owner merged
  themselves while the session wasn't watching: no metrics comment, an accepted gap; nothing is
  built for it (owner)
- **Test data holds no identifiers:** the PR 7 test case is a fixture rebuilt from that session's
  events and the PR's GitHub data, anonymised (made-up logins, `example.com`, fake ids, times kept
  relative). The transcript parsing is tested on a real local transcript's entry shapes, also
  anonymised, since PR 7's session is readable here only through `list_events`, in another shape
  (CLAUDE.md's identifier rule; Claude, from the spec review, 2026-10-16)
- **The PR 7 numbers are pinned:** the test expects the owner's numbers. If a definition here can't
  give one of them, the build stops and the difference goes to the owner before the definition or
  the expected number changes (owner: "Reconstruct PR #7's numbers above as a test case if you
  can")

### How it reaches projects

- The PR body says what a project adapts on upgrade: `devshop:upgrade` replaces
  `scripts/deploy-comment.mjs`; the project wires `announce`, the `deploying`, live and failed
  steps and `report` from the template, and moves its deploy into the slot. For the website: replace
  its own `scripts/deploy-comment.mjs` and its marker (the upgrade does), move `deploy.sh`'s steps
  into the slot unchanged, and add the new jobs. A project with no deploy keeps the copy and needs
  nothing else. The website changes only in its own session with `devshop:upgrade`, after this
  merges (owner)

## Acceptance items

- **AC-1** `deploy-comment.mjs merged` creates the comment in the merged state (headline from the
  table; state line with run id, attempt and time) when the PR has none, leaves a deploying or final
  comment of the same attempt unchanged, and retries the PR lookup up to its limit, then exits 0
  without commenting
- **AC-2** `deploying` moves a merged comment to deploying, or creates it; when two marker comments
  by `github-actions[bot]` exist, it edits the oldest and deletes the other; a comment by anyone
  else is never edited or deleted
- **AC-3** `deployed` and `failed` write the website's live and failed texts (the commit, URL,
  versions, domain line, rollback line; "may be live" when uploaded, "production is unchanged" when
  not) over a merged or deploying comment and record a final state; with the website's old `env`
  (no run id) they still write the comment
- **AC-4** `deployed` with `NONE=yes` (the unfilled slot) writes not-deployed with "this project has
  no deploy step yet", never "Live in production"
- **AC-5** `report` gives every combination of `fast`, `slow` and `deploy` results its row in the
  Decisions: superseded (with the newer commit), each not-deployed reason, live from `deploy`'s
  outputs when `deploy` succeeded but the comment isn't final, nothing over a final comment of the
  same attempt, and a new comment when there is none
- **AC-6** A write from a higher attempt replaces a final state (failed, then re-run, then live); a
  write from a lower attempt changes nothing
- **AC-7** Bad arguments or settings (no token, a malformed commit or run id, an unknown reason or
  state) exit 2 before calling GitHub; a GitHub API error, or no answer within the timeout, exits 1
- **AC-8** The template `runtime/templates/ci.yml` passes `ci-tiers-check.py`; `announce` runs only
  for pushes to `main`, with no `needs`; `deploy` has the job-level `if` of the Decisions, needs
  `fast` and `slow`, runs `deploying` after checkout and before the slot, `deployed` / `failed` after
  it, and exposes the slot's outputs; `report` has the `if` of the Decisions; `announce`, `report`
  and every comment step are `continue-on-error` with a `timeout-minutes`; permissions as in the
  Decisions; no secret in any comment step's `env`; `fast` and `slow` unchanged — verified by
  review: read the template, and run `ci-tiers-check.py` on it
- **AC-9** The template's slot is marked; its comment names the outputs the comment reads (`url`,
  `version`, `previous_version`, `rollback`, `deployed`, `site_url`, `site_smoke`), keeps
  `environment: production` commented until filled, and says how to fill it; `docs/README.md`'s CI
  entry mentions the deploy comment and the slot
- **AC-10** `runtime/project-files.txt` lists `runtime/scripts/deploy-comment.mjs` as `devshop`,
  project path `scripts/deploy-comment.mjs`, and `project-files.py check` passes on a project with
  an identical copy and reports one that differs
- **AC-11** `change-metrics.py` on the anonymised PR 7 fixture prints exactly the Intent's comment:
  27 min; 11 · 13 · 3 min; 4 answers · 1 PR comment · 1 approval; $4.05 ($3.88 + $0.17); 2 pushes
  · 0 red CI runs · passed 2 of 2
- **AC-12** On sample transcripts it counts working time from each owner message or wake to the last
  assistant entry before the next one; `AskUserQuestion` time and gaps the owner ended as waiting on
  you; other gaps as waiting on CI, shown only from 1 minute; a mid-turn owner message once, not
  three times; skill text and tool results not as owner messages; and a second change in one
  session only from its own start message
- **AC-13** It counts answers in chat, the owner's PR comments and approvals (not a third party's
  when the owner approved, never a bot's), pushes and red CI runs (a red first attempt later
  re-run green included), reviewer rounds and passes from the `REVIEW:` lines, and the reviewer's
  cost from the verdict files, falling back to the PR footers
- **AC-14** A number that can't be measured (no start record, no cost, a missing verdict file and
  footer) shows "unknown" and the rest still render; a start cost that was absent counts 0 only when
  the start is the session's first owner message; each final state other than live gets its
  headline
- **AC-15** `change-metrics.sh post` exits 3 ("not final yet") while the deploy comment isn't final
  and less than 60 minutes have passed since the merge; after 60 minutes it posts with the deploy
  "unknown"; with no `announce` job in the project's `ci.yml` it posts at once; it posts once, and a
  second `post` on the same PR posts nothing; `start` records the latest owner message and the cost;
  a missing record or transcript gives "unknown" numbers, not a failure; bad arguments exit 2
- **AC-16** `devshop:intent` § 1 runs `start` for a change; `devshop:pr` §4 runs `link` and §5,
  after the merge, arms `send_later` check-ins, runs `post` at each, re-arms on exit 3, and never
  holds the merge for any of it; `skills-check.py` passes — verified by review: read the two skills

## Out of scope

- Any change in the website before its own upgrade session
- Cloudflare specifics in the template (W10.10.2's stack home)
- Metrics when the session is gone before the deploy ends, or for a PR merged outside the session
- Lighthouse or other project quality numbers in the metrics comment
- The canary (W10.10.5)
- Filing anything in `ROADMAP.md` or `FINDINGS.md` for this change
