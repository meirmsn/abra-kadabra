# Review 2: from two failed runs to a devshop that ships real apps

_A whole-picture review against [TARGET.md](TARGET.md) and a proposal for the owner to decide on,
2026-10-14 (W10.7.1, [PROCESS § 5](PROCESS.md#milestone-review-each-m-exit--the-whole-picture-check)).
It changes nothing: every cut, deferral and milestone below is a decision for the owner (§ 4).
Evidence: the notes, the shipped code in `runtime/` and `install/`, the two run-2 transcripts
(builder and coordinator), the fixture repo read-only, and the checks in § 5._

## In one screen

- **The thin loop works.** Twice, a fresh session took a pitch to production through spec, build,
  independent review, PR, approval and deploy; the walls refused every attempt that reached GitHub;
  the harness graded 7 of 7 planted defects across the two runs; run 2 reached a green PR in 54
  minutes. By D-16's own rule (a gap blocks only if it lets a wrong change reach production or
  makes the run untrustworthy), **run 2 passed**. The M1 exit as written is stricter than D-16 and
  grades the harness, not the devshop.
- **Nothing yet measures what the owner wants:** slick, reliable, performant apps. The nine pillars
  and the north-star grade process conformance; the only quality item (the UI baseline) came from
  the owner noticing a bare page. The reviewer has no browser and cannot run the project's tests.
- **The process now produces more process than product.** About 80 devshop PRs in a week, 77k
  words of notes, 190 findings with a graded ledger and its own linter, a harness that needs fixing
  before every run. Of run 2's nine new findings, three are about the exam itself, two about the
  cloud environment, and four about skill wording and PR layout; none is about the app.
- **Proposal:** declare M1 met; retire the per-run exam (plants, probes, decoy, idea pool) and the
  graded ledger; fix three environment items the owner already asked for; then build the owner's
  own website on Cloudflare as the first real project, with a measurable quality bar, and move to
  lalista once that holds. Stop iterating on the fixture after one plain run.

## 1. Diagnosis: what blocks "good apps with me at the direction level"

Ranked by evidence, not by how many findings mention them.

### 1. The system grades its own machinery, not the apps it makes

The north-star scenario has nine steps; six of them test the devshop's harness (plants by type,
probe PRs, a decoy stack home, an idea pool, a planted production fault, the ledger flow). Run 2
"failed" on: a plant that could not be applied (harness, F-NEW-67), a plant type the owner chose
not to run (F-NEW-66), prompt injection the coordinator never attempted, a canary nobody but the
owner can see (F-NEW-75), and the builder applying the owner's PR comment instead of asking first
(F-NEW-70). Not one of these let a wrong change reach production or made the run's result
untrustworthy, which is D-16's test. Meanwhile nothing in the exit asks whether the feature was
good. The spec for "tag items" is about 150 lines with SQL and a route table; the PR is +1,109
lines over 26 files; the page it produced is clean but plain. No step, lens or check says whether
the owner would show it to someone.

**Cause:** TARGET's north-star was rewritten on 2026-10-12 to "exercise all nine pillars" and
hardened after an adversarial review, so the yardstick measures coverage of the plan. A plan
reviewed for completeness grows; one reviewed for the owner's goal shrinks.

### 2. The quality bar is undefined, so "slick, reliable, performant" cannot fail

The reviewer reviews by reading: "There is no browser yet, so the design and QA lenses review by
reading" (reviewer README, Limits), and on fixture PR 26 it wrote "npm test fails here because
vitest isn't installed (exit 127), so I read the tests instead of running them." The spec→test
check (`spec-check.py --tests`) matches names, not behaviour (F-NEW-49). The UI baseline exists
(tokens, render check at three widths, two themes) and caught a 5 px overflow in run 2: that is
the one place a quality rule bit, and it was added only after the owner saw a bare page. There is
no performance budget, no accessibility check beyond contrast and tap size, and gstack's own
quality tools (`/design-review`, `/qa`, `/review`, `/cso`, `/benchmark`) are installed by the
bootstrap and used by no skill: the skills call gstack only for `/spec`.

**Cause:** TARGET L1 says "using gstack" and Verify lists "design and QA for UI" as lenses, but
the walking skeleton was built to prove the loop and the walls, and quality was left for stack
homes "at M2". The fixture, an HTML-string Worker with three rows, cannot exercise it anyway.

### 3. The owner is the bottleneck in the wrong places

Run 2's ten owner touchpoints: three genuine product decisions, one go, one approval, three
scripted, two friction. The wall-clock was 8 h 34 min of which 6.5 h was the PR waiting for the
owner's approval and then a separate "merge" message. Inside the builder session, the spec took
19 minutes and 13 questions over three rounds; about seven were product choices (who may write,
seeded tags or a form, counts on the links) and the rest confirmations of the builder's own
proposals, answered "1. a 2. no 3. yes 4. cool 5. yes". The owner overrode the builder's cheaper
recommendation once (a form instead of seeded tags), which is the direction-level input the goal
describes, and the spec absorbed it with no size warning beyond "about half a day".

Around the run the owner also moved a mis-placed tag, opened a reset PR by hand (no `gh` on their
machine), ran the harness Action twice, pasted its logs into the coordinator, moved the
coordinator out of auto mode for the safety probes, and checked production and the canary in a
dashboard because nobody else can reach them (F-NEW-63, F-NEW-75). The owner's own messages in
the coordinator session are the record: "how do i run the harness picker"; "fatal: no tag
message?"; "gh: command not found" (pasted from their machine); "where do i get the summary/info
you need from the apply-plants? i see 4 boxes, is there a way to get you the full log?"; "shoot
it asked me: … Is this a feature run to exercise the devshop on the fixture"; "it didn't merge, i
had to type 'merge' in chat."; "i moved the session out of auto mode into accept edits is that
what you need". At 07:50 the owner asked the coordinator to "keep monitoring and even replying on
the session while i sleep? so that you can do the whole run 2"; it could not, and the builder's PR
then waited six and a half hours.

**Cause:** two design choices put the owner on the critical path. The harness is owner-held and
owner-triggered by design (so the builder can't see it), which makes the owner the test operator.
And observability (TARGET Safety 6, Ship 5) is specified as tokens and allowlists the owner sets
per environment, with nothing built to use them, so "Claude watches production" cannot start.
F-NEW-42 ("merge" prompt) is the builder being cautious against TARGET Review 8, a one-line skill
fix.

### 4. The process generates its own work

Numbers from the repo: PRs opened in the devshop repo 2026-10-08 to 2026-10-14: about 80. Words in
the revamp notes: about 77k (LOG alone 30k, in a week). Findings: 190, in a ledger with Impact,
Risk, Cost, Leverage, Score, sighting dots and a rule of five, checked by a 45-case linter with 30
mutants killed. Skills capped at 60 lines by a CI failure, so adding the rule F-NEW-70 asks for
means cutting another. A day on design-first spec review (27 replay runs, dropped, F-NEW-65). A
hook built, dogfooded through six rounds of parser gaps, then redesigned (LOG #48). The fixture,
"public-safe and tiny", carries 239 lines of app and about 1,200 lines of scripts and workflow
plus 12 shell test files for the harness (reset, preview, traffic, deploy). Findings about the
findings system exist (F-NEW-53: parallel sessions take the same numbers). In the builder session,
`ship.sh` ran seven times for one PR; four runs changed only the body's words, and each re-ran the
independent reviewer on an unchanged commit. The body's shape check accepted a false sentence
("Preview: none — this repo has no preview deploy on PRs"; the fixture deploys one per PR) and
rejected the true one that had the link and a reason, costing a round. Whether a sentence is true
is not something a sentence counter can check; the owner can.

**Cause:** "every check is proven to fail" and "mechanical steps live in tested scripts" are the
right rules for walls (the secret scan, CI tiers, the spec→test check). Applied to paperwork (the
ledger's glyphs, the PR body's sentence count, the skills' word budget) they make each small rule
cost a script, a test and mutants, and each run produces a record (166 lines for run 2) whose
findings seed the next week. The habit of filing everything noticed, graded, keeps the queue
full regardless of whether anything in it blocks the goal.

### 5. The reviewer is proven on its own plants, and on nothing else

Recall went from 0.33 to 1.0 after rules were written for the five plant types (A-12: "not held out
across types"), and the harness has since graded 12 of 12 plants over `live-1`, `ns-1` and `ns-2`.
That is real and worth keeping, and in run 2 its first-round findings were substantive, not
plants: a state-table row with no test, and an inline script the UI guideline's "control
contract" had tempted the builder into that no spec item asked for. But the plants are the only
measured evidence; nothing says how it does on defects that aren't plants, and two flips
(F-NEW-40, F-NEW-64) show severity calls move between runs. Per review it costs about $0.25 and a
minute, which is cheap enough to keep in every ship.

### 6. The fixture has done its job

Three features have shipped on it (categories, a restyle, tags). It proved the walls (two safety
tables, every GitHub refusal verbatim), the install and pin, the reviewer in `ship`, the PR shape,
CI in two tiers, and the UI baseline. What it cannot prove: a real stack (there is no stack home;
`STACKS: none` every run), real data, real users, real traffic, or whether the owner likes the
result. Every further fixture run costs the owner a set-up hour and yields harness findings.

### Symptoms and their causes

| Findings                                                                       | One cause                                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| F-NEW-63, F-NEW-75, F-NEW-42, F-NEW-48                                         | Production is unobservable from anywhere but the owner's dashboard: no host allowlist, no read token, no CI record after the deploy's own smoke check                                                                                                                                                                                |
| F-NEW-68, F-NEW-71, F-NEW-55, F-NEW-74                                         | Cloud-session quirks taken at face value. `gh auth status` reports the token invalid while `gh api` works as the agent (checked in this session; `ship` opened fixture PR 26 with `gh api` twelve minutes after the builder declared `gh` broken, F-NEW-68); clones are shallow and tagless; auto mode refuses probe-shaped commands |
| F-NEW-66, F-NEW-67, F-NEW-39, F-NEW-30, F-NEW-72, F-NEW-35, F-NEW-74           | The exam: plants that rewrite the builder's tests depend on the builder's test style; set-up is a hand-run ritual; the fixture's history tells the builder it is a fixture                                                                                                                                                           |
| F-NEW-69, F-NEW-70, F-NEW-60, F-NEW-41                                         | Skill wording, under a cap that forbids adding a line                                                                                                                                                                                                                                                                                |
| F-NEW-57, F-NEW-58, F-NEW-61, F-NEW-59, F-NEW-64, F-NEW-65, F-NEW-49, F-NEW-38 | Reviewer engineering: real limits, none of which failed a run                                                                                                                                                                                                                                                                        |
| F-NEW-73, F-NEW-50                                                             | PR presentation on a private repo; one template change, one platform limit                                                                                                                                                                                                                                                           |
| F-NEW-44                                                                       | A TARGET requirement (previous version's tests against the new schema) sized L for an app with no data                                                                                                                                                                                                                               |
| F-NEW-53, F-NEW-62                                                             | The devshop's own development process                                                                                                                                                                                                                                                                                                |

## 2. What matters and what is noise

### The Fix queue and Watch list, sorted

**Must fix to reach the goal** (5):

| ID       | Why, and the smallest fix                                                                                                                                                                                                                                                    |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-NEW-63 | The builder must see what it ships. Allow the project's preview and production hosts in its environment (owner, minutes). Do it for every project environment from now on, as a set-up rule in the stack home, not a finding.                                                |
| F-NEW-75 | Production health after a deploy must be a record the agent can't edit. The deploy job already smoke-checks the live app twice from CI; extend it to read the traffic Worker's last rounds with a read-only token. Build it in the real project's deploy, not the fixture's. |
| F-NEW-42 | The agent merges on approval (TARGET Review 8); the "merge" message is friction on every change. One line in the `pr` skill. The pre-merge health check stays deferred until a project has real traffic.                                                                     |
| F-NEW-73 | The PR is what the owner judges on a phone. A table per state (label, light, dark) in the template and the shape check: one small PR.                                                                                                                                        |
| F-NEW-70 | A question in a comment is a question. One line in the `pr` skill: a comment that changes a decision or item is answered with the options and waits. Needs room: see the skill cap under § 4.                                                                                |

**Fold into something bigger** (9):

| ID                           | Into                                                                                                                                                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-NEW-58, F-NEW-57           | "The reviewer changes only with its eval": make the W10.6.5 spike's `run.sh` the documented regression check, run by hand before any reviewer PR (the task is W10.6.17; the CLI pin rides along when a flip is ever traced to it). |
| F-NEW-68, F-NEW-71, F-NEW-55 | "Cloud-session facts" in one short note the skills point at: `gh auth status` lies, clones are shallow and tagless, tags are fetched on demand. `pr-assets.sh` is unchanged; the builder never ran it.                             |
| F-NEW-61, F-NEW-59, F-NEW-23 | "The reviewer runs the project's fast tier in its clone" when the first real app arrives (M3 below): reading tests is not enough for a real test suite.                                                                            |
| F-NEW-44                     | The Cloudflare and Supabase stack homes' migration rule (expand/contract, append-only), with the CI job only when a project ships its first destructive migration.                                                                 |
| F-NEW-49                     | The same stack-home test convention: tests named by spec and item.                                                                                                                                                                 |
| F-NEW-41                     | The Intent step's quality, judged on the real project: how many questions the code could have answered.                                                                                                                            |

**Stop tracking** (10): F-NEW-66, F-NEW-67, F-NEW-72, F-NEW-74, F-NEW-35 (the exam's own bugs;
retired with it, § 2 below); F-NEW-53, F-NEW-62 (the devshop's development process); F-NEW-69
(harmless while `ship` runs the checks); F-NEW-60 (the owner already moved the item; one sentence in
the spec template's comment if it recurs); F-NEW-65 (a real blind spot with no fix that tested
better than nothing; the owner's "what is the source of the problem?" at the go is the fix, and
it costs no code).

**Accept as a known limit** (5): F-NEW-50 (GitHub's mobile app and private images), F-NEW-38
(stale verdict: the owner reads the verdict for the head before approving, and `ship` posts one per
push), F-NEW-64 (severity flips exist; the eval shows 0 outcome flips in 100 on fixed inputs),
F-NEW-48 (the canary skipping rounds matters when a canary must catch faults, on a real app with
real traffic, where it will be rebuilt anyway), F-NEW-47 (two refusals come from the proxy and a
repo setting; both are outside the agent's reach, which is the point).

### Is the process earning its cost?

- **North-star grading:** earned its cost twice: it is the only end-to-end proof and it caught
  real things (no screenshots on the PR, the merge prompt, a builder that notices a foreign
  commit). As a nine-step exam re-run with plants and probes at every milestone it is the main
  source of rabbit holes. **Simplify:** a milestone's proof is a _plain run_: the owner uses the
  devshop on a real change with no harness, and four things are graded from GitHub and CI: the
  change is what was asked (the owner's judgement), a reviewer verdict exists for the merged head,
  nothing wrong reached production (the deploy's smoke check and the next day), and the owner's
  touchpoints were decisions, go and approval only.
- **The findings ledger:** the match-first habit is right. The grading (five sizes, two formulas,
  dots, a rule of five, a linter with mutants) is not: it costs more to maintain than it decides,
  it makes every noticed thing a row, and the Fix queue's top rows this week were the owner's own
  three requests, which needed no formula. **Simplify:** a flat list, one line per finding, no
  grades; `findings-check.py` and its test deleted; findings move to GitHub issues (TARGET Shape 8)
  when the first real project needs the cross-repo flow, not before.
- **Check-every-check (proven to fail, mutants):** keep for walls and for anything a project's CI
  runs (secret scan, spec→test, CI tiers, the UI checks). Stop for prose linters (`pr-body-check.py`
  sentence counting and word lists, `skills-check.py` budgets, `findings-check.py`): a wrong PR body
  reaches the owner, who sends it back; that is the check.
- **Harness plants:** they proved the reviewer and the harness grades them without a human. That
  job is done. Each further run needs the harness fixed first (F-NEW-66, F-NEW-67). **Simplify:**
  the plant eval becomes the reviewer's regression check, run when the reviewer's files change,
  never as part of a milestone.

## 3. The path

The smallest sequence from today to a real, non-trivial app for a real project. Each milestone
ends on something observable, not a checklist.

**M1, close it now (this week; about an hour of the owner, a day of agent time).** Declared met on
the two runs under D-16's rule. The close-out: the three environment items (hosts allowed in the
fixture environment; merge on approval; the screenshot table), then one _plain run_ on the
fixture: a small change the owner wants, no harness, no plants, no probes, no coordinator. **Done
when** that change is in production with the owner's touchpoints being decisions, the go and the
approval only, and the deploy's smoke check green on `main`.

**M2, the first real website (next; two to three weeks of calendar).** The owner's own website on
Cloudflare, a new repo scaffolded by the devshop, which is where the Cloudflare stack home is
written (TARGET Reach 4 already says so). "Slick and performant" gets a deterministic bar in the
slow tier: a Lighthouse run against the preview with thresholds (performance, accessibility, best
practices, SEO), plus the existing render check. The build skill tries gstack's `/design-review`
on the preview for UI changes, and its value is judged by whether the owner's look-and-feel
comments on PRs drop. **Done when** the site is live on the owner's domain, at least five changes
have shipped through v2 with no friction touchpoints, the Lighthouse bar holds on the live site,
and the owner publishes the link.

**M3, the first real app (lalista web).** Precondition: the owner's money call on Vercel and
Supabase (F-NEW-18, F-NEW-19) or a move to Cloudflare. The Next.js + Supabase + Vercel stack home
grows while lalista moves; the reviewer gets a browser and runs the project's fast tier in its
clone; the canary becomes a CI job with a read-only token; the next-day check is a scheduled task.
**Done when** lalista's next five features ship through v2 only, v1 is retired for it, no change
caused a production incident, and touchpoints per change are decisions, go and approval.

**M4, iOS and the Mac.** As planned, after M3. Not detailed until M3 is done.

**When to stop iterating on the fixture:** after the plain run in M1. The fixture stays as the
reviewer's eval bed (its plants and specs) and as a scratch project; it gets no more features, no
more baselines and no more harness fixes.

## 4. Decisions for the owner

Each with a recommendation.

1. **Declare M1 met now, no run 3 with the harness.** Recommended: yes. Run 2 passed D-16's rule;
   what remains is environment set-up and skill wording, which the plain run checks.
2. **Retire the per-milestone exam.** Drop from the north-star: plants per run, the safety probe
   PRs per run (the walls are GitHub settings; re-verify them once with the existing table when a
   repo's protection changes), the decoy stack home, the idea pool, steps 7–9 as graded steps, the
   planted production fault and the rollback drill (rebuilt as a real incident drill on lalista at
   M3). Keep: the plain run. Recommended: yes.
3. **Flatten the findings ledger and delete its linter.** Recommended: yes. Keep match-first; no
   grades, no dots, no formulas.
4. **The skill cap goes back to a warning** (TARGET Shape 2 as first agreed; F-NEW-54 reversed).
   Recommended: yes. Two run-2 findings need one line each and the cap forbids it.
5. **First real project: the owner's website on Cloudflare, then lalista.** Recommended: the
   website first. It is the stack the fixture already proved, it costs no new plan, and "slick"
   is the whole point of a personal site. Decide lalista's paid plans when M2 is done.
6. **Approval ships, no "merge" message.** Recommended: yes, as TARGET Review 8 already says.
   The pre-merge production health check stays deferred (F-NEW-42) until real traffic exists.
7. **Observability per project environment: hosts allowed and a read-only token, from the
   stack home's set-up list.** Recommended: hosts now for the fixture (minutes), the token and the
   canary job with the website at M2, not on the fixture.
8. **Keep the agent identity after the trial ends on 2026-10-25.** Recommended: keep it. The
   enforced owner approval is the one wall that makes "I review and approve every PR" true; the
   split profile credit is cosmetic.
9. **Adopt a measurable quality bar for web output.** Recommended: Lighthouse thresholds in the
   slow tier from M2, the reviewer with a browser at M3. Without a bar, "slick" is whatever the
   builder produces.
10. **Devshop work only when a real project needs it.** Recommended: from M2, a devshop PR needs a
    change the website or lalista asked for, or a plain-run miss; about one devshop PR a day instead
    of about twelve. TARGET Shape 8 already says "grows only from proven findings".
11. **Money and headroom.** The run-2 builder cost $14.28 on Opus for a small feature (the "go"
    turn alone was 25 minutes of wall-clock and 77 tool turns), and a seven-day rate-limit warning
    at 78 % appeared during the merge. Recommended: keep Opus for the builder and Sonnet for the
    reviewer, stop the words-only reviewer re-runs (a body edit with no code change needs the shape
    check, not a review), and decide on plan headroom when the website pilot starts rather than
    now.

TARGET, pillar by pillar, with what to keep, cut and defer, is in the appendix.

## 5. What I checked, and what I couldn't

**Checked.** Every note the brief lists, including the run records, LOG #53, #68 and #69, the
whole Fix queue and Watch list, and the Closed ledger's IDs. The shipped code: the four skills, the
upgrade skill, `ship.sh`, `review.sh`, the reviewer prompt and allowlist, the hooks, the dispatcher,
the templates, the stack-home and guideline layouts. The two run-2 transcripts, read whole by two
helper sessions (the builder's 07:40 to 16:23 across 15 pages with its per-turn cost records; the
coordinator's from the owner's first set-up message to the hand-off prompt) and reported back
with quotes and times, which § 1 cites. The fixture repo,
cloned read-only: its layout, `src/index.js`, PR 26's title, body and comments as GitHub holds
them, and its screenshots. In this session: `gh api` works as the agent identity while
`gh auth status` reports the token invalid; this repo's fast test tier passes on the unchanged
tree (30 files); PR counts from the GitHub API.

**Couldn't.** The harness repo (private to the owner): its plants, picker and grading are known
only from the records. The fixture's preview and production (the session's network policy blocks
them, as the builder's did). Branch protection and environment settings (the agent can't read
them; taken from the owner's reports). The Cloudflare dashboard and the canary rounds. The
reviewer's behaviour on defects that aren't plants: no data exists. lalista's current state and
its Vercel and Supabase plans. The owner's own time spent, beyond what the transcripts show. I did
not re-run the reviewer eval or any north-star step.

## Appendix: TARGET, pillar by pillar

| Pillar       | Keep                                                                                             | Cut                                                                                                                            | Defer                                                                                           |
| ------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Intent       | kind up front; `/spec`; one spec per change with `AC-<n>`; the go; changes after the go recorded | the independent reviewer's "spec mode" (the read-only helper does the job; W10.6.20 showed prompts don't buy design judgement) | `/office-hours` as a rule (keep as an offer)                                                    |
| Build        | one writer; stack homes loaded by detection; code, tests and docs together                       | the decoy stack home and its test                                                                                              | the backward-compatibility CI job until a destructive migration exists                          |
| Verify       | the reviewer in `ship`; three outcomes; three rounds then ask                                    | the reviewer eval at every milestone (run when the reviewer changes); the stale-verdict check                                  | a browser and running the project's tests, at M3                                                |
| Review       | the body shape; screenshots on the PR; approval ships                                            | sentence counting and word lists in the shape check (the owner is the check)                                                   | mobile inline images (platform limit)                                                           |
| Ship         | merge only by PR on green; deploy from `main`; the deploy's own smoke check                      | the planted production fault and rollback drill per run; the pre-merge health check until real traffic                         | canary job, next-day task and the incident drill, at M2–M3 on a real project                    |
| Safety       | the walls; the agent identity; no production secrets in reach; secret scan required              | the probe PRs per run (once per protection change instead); the prompt-injection step as a graded item                         | the production-data grant (M4)                                                                  |
| Environments | one environment per project; pins; `.devshop-version`                                            | "local services in their own containers" and timed start-up (local D1 in the session is fine)                                  | the Mac (M4)                                                                                    |
| Reach        | one home per stack, added when a real project needs it                                           | "every stack home proven by scaffolding a fresh project in the devshop's CI" (L-46) until two homes exist                      |                                                                                                 |
| Shape        | lean; pins; the guided upgrade; the always-loaded budget                                         | the graded ledger and its linter; the one-page cap as a CI failure; mutants for prose linters                                  | SemVer and release-please (SHA pins work); the ledger as GitHub issues until a project needs it |
