# A merged PR follows its deploy, then says how the change went

**Go:** "B. do (1) in this session", choosing the slot as a script, `scripts/deploy.sh` (owner, 2026-10-16)

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
- **The slot is a script, like the two tiers:** the template's `deploy` job runs
  `scripts/deploy.sh` when the project has one, after `scripts/setup.sh` (as `fast` and `slow` run
  `check-fast.sh` and `check-slow.sh`), so the job's steps are the same for every stack. The
  project's edits are the marked lines only: its tool installs (as in `fast` and `slow`) and the
  deploy step's `env` (its secrets and settings). `scripts/deploy.sh` writes the outputs the comment
  reads to `$GITHUB_OUTPUT`, with the website's names so its `deploy.sh` needs no change: `url` (the
  live https URL), `version`, `previous_version`, `rollback` (the line that undoes it), `deployed`
  (`yes` once the new version was uploaded) and `site_url` / `site_smoke` (the domain check:
  `passed`, `failed` or `skipped`). With no `scripts/deploy.sh`, the step writes `none=yes` and the
  comment ends not-deployed with "this project has no deploy step yet". The job keeps
  `environment: production` (the deploy's secrets live there); a project with no deploy script yet
  gets a GitHub deployment record that did nothing, accepted, since the comment says so. Rejected:
  a block of steps the project rewrites inside the template, which drifts per stack (owner chose
  the script, 2026-10-16)
- **Setup docs:** the template's comments are the contract (what `scripts/deploy.sh` must write, and
  the two places a project edits), and `docs/README.md`'s CI entry says so; how a new project is
  set up in general is a separate question, not this change. How to write `deploy.sh` for a stack
  goes in that stack home: the Cloudflare one when W10.10.2 builds it, not in this change (owner,
  2026-10-16)
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
  computes every number from the transcript and a PR data file, and renders the comment;
  `runtime/scripts/change-metrics.sh post --pr <n> --cost <usd>` gathers the PR data with `gh api`,
  checks the deploy comment's state, and posts. The model's only input is the one value scripts
  can't read: the session's cost now, from `get_session` (owner: "The scripts compute the metrics,
  not the model")
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
- **When the clock starts: the session's start,** its first owner message; no step records the
  start of a change. When the transcript shows this session merged an earlier PR, the clock starts
  at the first owner message after that merge instead, worked out from the transcript alone. The
  session's cost at the start is 0, or, after an earlier merge, the cost the session's metrics
  comment on that PR recorded in its marker line (`<!-- devshop-metrics cost:<usd> -->`), else
  "unknown". Rejected: a `start` step in `devshop:intent` recording the change's start and cost
  (owner: "can't you just use the session start time? i'm afraid of having one more moving part",
  2026-10-16)
- **Finding the transcript:** the `<session id>.jsonl` files under `~/.claude/projects/*/`, merged
  by entry uuid. Seen 2026-10-16: after a container restart the resumed session wrote a new file in
  another folder (the working directory had changed), holding every earlier entry plus the new ones.
  The session id is the one in the newest file's entries; no transcript found makes the session
  numbers "unknown". `post` never fails the step it runs in (Claude, 2026-10-16)
- **What counts in the transcript** (seen in a real one, 2026-10-16):
  - _An owner message:_ a `user` entry with `origin.kind` `human`, or a `queued_command` attachment
    whose `origin.kind` is `human` (a message sent mid-turn), deduplicated by text and time; a skill's text (`isMeta`), a tool
    result and a compaction summary are not.
  - _A wake:_ a `user` entry that starts a turn with `origin.kind` other than `human` (a check-in
    or PR event arrives as `task-notification`), or a `queued_command` with another origin (a
    notification or a subagent's hand-back, queued mid-turn).
  - _A turn's end:_ its last assistant entry, the one with `stop_reason` `end_turn`; a wake that
    arrives mid-turn ends no turn, so the time the session waits for a subagent inside a turn is
    working time (seen 2026-10-16 when the PR 7 fixture first gave 9 min 50 s by ending a span at
    each wake; Claude).
  - Subagents' own transcripts (`subagents/`) are not read; their time counts only while the main
    session waits for them.
- **Where each number comes from** (owner's method, measured by hand on PR 7; definitions Claude's):
  - _Request to live:_ the clock's start to the deploy comment's final state (`at`).
  - _Claude working:_ from each owner message or wake to the last assistant entry before the next
    one, less the time an `AskUserQuestion` waits for its answer, from the start until the deploy
    comment's final state, so the session's own work after the merge counts; overlapping spans
    counted once (owner chose "Include post-merge work", 2026-10-16, after the PR 7 rebuild gave 10.2
    min to the merge and 11.0 with it).
  - _Waiting on you:_ the time from the start to the merge that isn't Claude working: before the PR
    opens an idle session waits for the owner's reply, and while it is open the owner can approve at
    any time. PR 7: 13 min. Rejected: counting only the gaps the owner ended and showing the rest as
    "waiting on CI" (6 and 7 min on PR 7), which needs each gap's cause matched against GitHub's
    times; so the Time line has no "waiting on CI" (owner: "idk, whats simple and resonable?";
    Claude's pick, 2026-10-16)
  - _Deploying:_ the merge to the final state.
  - _Your input:_ answers in chat are the questions answered through `AskUserQuestion` plus the
    owner's chat messages after the first one (the go is one; owner chose "Questions + messages":
    6 on PR 7, 5 questions and 1 message, where the hand count said 4, 2026-10-16); PR comments are the owner's
    comments and reviews with text; approvals are their `APPROVED` reviews. The owner is the account
    that approved the PR, else every account that isn't a bot (`[bot]` or type `Bot`) or the PR's
    author.
  - _Cost:_ session cost (above) plus the reviewer's: each `REVIEW:` line `ship.sh` printed in the
    transcript names its verdict file, whose `reviewer.cost_usd` counts, failed rounds included;
    when a verdict file is gone, the `$` in the PR's reviewer comment footers stands in.
  - _Quality:_ pushes are the distinct head commits of the PR's `pull_request` runs of the `ci`
    workflow; red CI runs are those runs with any attempt concluded `failure` or `timed_out`;
    "reviewer passed n of m" counts the `REVIEW:` lines (m) and those with outcome `pass` (n).
    Lighthouse is left out: it is in CI logs, in a form each stack writes its own way (owner:
    "yes", 2026-10-16).
  - A time under 10 minutes shows minutes and seconds ("3 min 31 s"); longer ones are rounded to the
    nearest whole minute (owner chose "Show seconds under 10 min", 2026-10-16, after PR 7's deploy,
    3 min 31 s, rounded to 4 where the hand count said 3).
- **A number that can't be measured shows "unknown",** never a guess, and never blocks or delays
  the merge or the deploy (owner)
- **The headline names the outcome:** live: "request to live **27 min**"; failed: "**deploy
  failed** · request to failure **27 min**"; not-deployed: "**not deployed** (<reason>) · request
  to merge **24 min**"; superseded: "ships with `<sha>`'s deploy · request to merge **24 min**", the
  Time line then without "deploying" (owner: "If the deploy failed, post anyway and say so in the
  headline"; on these words: "i like that you put the reason", 2026-10-16)
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
  `scripts/deploy-comment.mjs`, and shows the seed template's new jobs, which the project copies
  into its `ci.yml`, filling the marked lines. For the website: its own `scripts/deploy-comment.mjs`
  and marker are replaced by the upgrade; its `scripts/deploy.sh` and `scripts/setup.sh` already
  fit; it fills `setup-node` into the tool installs and its Cloudflare settings into the deploy
  step's `env`, and drops its old comment steps. A project with no deploy keeps the copy and gets
  "no deploy step yet". The website changes only in its own session with `devshop:upgrade`, after
  this merges (owner)

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
- **AC-4** In a project with no `scripts/deploy.sh`, the template's deploy step writes `none=yes`, and
  `deployed` with `NONE=yes` writes not-deployed with "this project has
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
- **AC-9** The template's `deploy` job runs `scripts/setup.sh` and `scripts/deploy.sh` when present;
  its comments name the outputs `deploy.sh` writes (`url`, `version`, `previous_version`,
  `rollback`, `deployed`, `site_url`, `site_smoke`) and mark the only lines a project edits (tool
  installs, the deploy step's `env`); `docs/README.md`'s CI entry mentions the deploy comment and the
  `deploy.sh` contract — verified by review: read the template and the entry
- **AC-10** `runtime/project-files.txt` lists `runtime/scripts/deploy-comment.mjs` as `devshop`,
  project path `scripts/deploy-comment.mjs`, and `project-files.py check` passes on a project with
  an identical copy and reports one that differs
- **AC-11** `change-metrics.py` on the anonymised PR 7 fixture prints the Intent's comment with the
  owner's answers of 2026-10-16: 27 min; 11 min · 13 min · 3 min 31 s; 6 answers · 1 PR comment · 1
  approval; $4.05 ($3.88 + $0.17); 2 pushes · 0 red CI runs · passed 2 of 2
- **AC-12** On sample transcripts it counts working time from each owner message or wake to the last
  assistant entry before the next one, less `AskUserQuestion` waits, until the final state; waiting
  on you as the rest of the time to the merge; times under 10 minutes with seconds; a mid-turn owner message once, not
  three times; skill text and tool results not as owner messages; the clock from the session's
  first owner message, or, after an earlier merge in the session, from the first owner message after
  it; and two transcript files of one session (a restart) merged by uuid, each entry counted once
- **AC-13** It counts answers in chat, the owner's PR comments and approvals (not a third party's
  when the owner approved, never a bot's), pushes and red CI runs (a red first attempt later
  re-run green included), reviewer rounds and passes from the `REVIEW:` lines, and the reviewer's
  cost from the verdict files, falling back to the PR footers
- **AC-14** A number that can't be measured (no transcript, no cost, a missing verdict file and
  footer, a later change whose earlier metrics comment has no cost) shows "unknown" and the rest
  still render; the start cost is 0 for a session's first change, and the earlier comment's
  recorded cost after an earlier merge; the comment's marker line records the session's cost; each
  final state other than live gets its headline
- **AC-15** `change-metrics.sh post` exits 3 ("not final yet") while the deploy comment isn't final
  and less than 60 minutes have passed since the merge; after 60 minutes it posts with the deploy
  "unknown"; with no `announce` job in the project's `ci.yml` it posts at once; it posts once, and a
  second `post` on the same PR posts nothing; bad arguments exit 2
- **AC-16** `devshop:pr` §5, after the merge, arms `send_later` check-ins, runs `post` at each with
  the cost from `get_session`, re-arms on exit 3, and never holds the merge for any of it;
  `devshop:intent` is unchanged; `skills-check.py` passes — verified by review: read the skill

## Out of scope

- Any change in the website before its own upgrade session
- Cloudflare specifics in the template (W10.10.2's stack home)
- Metrics when the session is gone before the deploy ends, or for a PR merged outside the session
- Lighthouse or other project quality numbers in the metrics comment
- The canary (W10.10.5)
- Filing anything in `ROADMAP.md` or `FINDINGS.md` for this change
