# Review 3: M2's exit, and what M3 needs before lalista moves

_The M2 milestone review
([PROCESS § 5](PROCESS.md#milestone-review-each-m-exit--the-whole-picture-check)), 2026-10-20, with
the fresh adversarial review PROCESS asks for before M3. It changed nothing when written: every
cut, task and TARGET edit below is a decision for the owner (§ 9). The findings sort (§ 6) was
applied on the owner's answer the same day (§ 9, Outcome). Evidence: this repo at `424d75a`
(`v2.1.0`), its merged PRs' comments, a fresh-context reviewer given the goal rather than these
conclusions, and the checks in § 10. The website and lalista repos could not be attached this
session, so anything only they hold is marked **not read**._

## In one screen

- **M2 is mostly met, and the gaps are records, not failures.** The site is live on the owner's
  domain, seven website PRs merged through v2, the Cloudflare home exists, the reviewer judges UI in
  a browser. Not recorded anywhere: the Lighthouse bar on the _live_ site, the owner publishing the
  link, cost per change. Not met as written: the owner's touchpoints were not "decisions, go and
  approval only" (4 others on the first change). And the two M2 features that matter most for
  quality, the design review in build (R-5) and the reviewer's browser (R-6), have run only on
  scratch pages: the website is on `v2.1.0` (owner, 2026-10-20), but no website change records
  either yet.
- **The next step costs a wasted round:** the upgrade skill's own example PR title and the
  new-project skill's first-PR title both fail `v2.1.0`'s `pr-title-check.py` (exit 1). `ship.sh`
  catches it before the push; an upgrade PR that brings the check in fails it in CI. The website's
  next upgrade hits it.
- **M3 changes the risk and nothing is built for it.** M2 proved the loop on a static site with no
  data. lalista has a database, users, Vercel previews and v1-era secrets. Three gaps can hurt
  production or data: lalista's repo-scope secrets and rotation are deferred to M4 though M3
  resumes lalista (W0.6.2 is literally "before lalista resumes"); nothing keeps preview builds off
  production data; nothing enforces TARGET Ship 3's migration rules.
- **The process grew back.** Since REVIEW-2 (6 days): `runtime/` +78 % lines, tests 51 → 76
  files, specs 4 → 14, 27 devshop PRs against D-17's "about one a day"; the median devshop PR cost
  $12.58 and the owner's wait was 95 % of its elapsed time.
- **Proposal:** close M2 with one plain run on the website at `v2.1.x` (it is also the first live
  check of R-5, R-6 and R-13); fix the title bug first; make lalista's walls and a data-safety
  section in the Next.js + Supabase home M3's entry tasks; freeze the records machinery (owner,
  2026-10-20: no PR-a-day rule; the devshop does now only what blocks the next real step or
  protects production data).

## 1. M2's exit, criterion by criterion

[PLAN.md](PLAN.md)'s exit for M2, against what this repo records.

| Criterion                                        | Record                                                                                                                                                 | Status              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| The site is live on the owner's domain           | W10.10.1's record: PR 7's deploy comment ("Live in production", the version it replaced); LOG #80                                                      | met                 |
| ≥ 5 changes shipped through v2                   | Website PRs 2–7 (W10.10.1) and #10 (W10.10.5): 7 merged, 7 approvals, 5 gos. Later website PRs: not read                                               | met                 |
| …with touchpoints decisions, go, approval only   | First change: 7 approvals, 5 gos, 22 decisions and **4 others** (F-NEW-91, 97, 98, a quote); closed "by the owner's call". After PR 7: not read        | not met as written  |
| The Lighthouse bar holds on the live site        | The bar runs in the slow tier against the PR's preview (`runtime/stacks/cloudflare/README.md` § quality bar). No run against the live site is recorded | no record           |
| The Cloudflare home exists, fixture rules in it  | PR #144, `tests/cloudflare-stack.test.sh`                                                                                                              | met                 |
| The reviewer judges UI in a browser              | PR #146 on a scratch page (honest pass; font, padding and 375 px breaks each fail). No website record yet (it is on `v2.1.0`, owner)                   | met on scratch only |
| The owner publishes the link                     | Nothing records it                                                                                                                                     | no record           |
| (W10.10.1's done-when) cost per change, weekly % | Waived by the owner ("It's okay to close without the numbers")                                                                                         | waived              |

Also unrecorded: W10.10.8's "post-merge: the website's first UI change carries the PR's **Design
review:** line; it is recorded here". Nothing follows it.

## 2. The plain run on a real project

PROCESS § 5 asks to re-run the north-star; since D-17 that is a _plain run_ (TARGET § North-star):
the owner uses the devshop on a change they want, and four things are graded from GitHub and CI.
**It can't run from this session.** A plain run happens in the website's own session with the
owner, and attaching the website here was refused by the session's permission check. What exists
is the first change's record (W10.10.1), graded as D-17 grades it:

| Graded                                   | First change (PRs 2–7)                                                                    |
| ---------------------------------------- | ----------------------------------------------------------------------------------------- |
| The change is what was asked             | The owner merged each; no record of their judgement beyond the approval                   |
| A reviewer verdict for the merged head   | Not checked here (the website's PR comments are not read)                                 |
| Nothing wrong reached production         | Deploy comments "Live in production"; the canary exists since PR #10, after these changes |
| Touchpoints decisions, go, approval only | 4 other touchpoints, now findings                                                         |

**Proposed:** the M2 proof is one plain run on the website at `v2.1.x`: the upgrade to `v2.1.1`
(after the title fix, § 9 item 2), then a UI change the owner wants. It grades the four things, and
it is the first time three M2 features meet a real project: the design review in build (R-5), the
reviewer's browser (R-6) and the project contract at session start (R-13). Record, from GitHub: the
PR's **Design review:** line, the reviewer's browse result, the canary comment, a Lighthouse run
against the live domain, the "How this change went" comment (cost, times, rounds), and the owner's
touchpoints tagged go / decision / approval / friction. A devshop session records it here with the
website attached read-only, which needs the owner to allow `add_repo` for that session.

## 3. Assumptions M3 builds on

| Assumption                                                                                            | Status                                                                                                                                                                                                                                                                    | Before M3                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F-NEW-18: Vercel deploys agent-authored commits of a private repo                                     | Known false on Hobby (archive); the precondition was to be decided "when the website milestone ends" (D-17 item 5)                                                                                                                                                        | Owner's call now (§ 9 item 4); then test it with one agent-authored merge (new **A-28**)                                                                               |
| F-NEW-19: Supabase Free pauses after ~7 idle days                                                     | Known; same decision                                                                                                                                                                                                                                                      | Same call                                                                                                                                                              |
| **A-11** Supabase starts locally in a cloud session, fast enough per change                           | **Tested here today, blocked:** as root, `dockerd` starts in this environment and `supabase@2.48.3` runs, but `supabase start` fails pulling `supabase/postgres` (the image registry's CDN host gets a 403 from the network policy; Docker Hub fails too). Speed untested | The owner allows the registry hosts in lalista's environment; re-run the timing there. Without it, the reviewer's local run and CI-like tests in the session can't run |
| New **A-29**: preview builds can be kept off production data (Supabase branching or a second project) | Untested; nothing in `runtime/` mentions it                                                                                                                                                                                                                               | Read lalista's Vercel Preview env (owner, or attached read-only) for the production URL or ref; test the chosen isolation once                                         |
| **A-13** gstack runs here without forking                                                             | Partly: `/design-review` ran in R-5 with a labelled mitigation (F-NEW-101); `/design-shotgun` can't run in a cloud session (F-NEW-87); `/qa`, `/review` never run                                                                                                         | Accept partly validated; lalista's design direction uses the hand-built-variants route that worked on the website                                                      |
| **A-24** the agent identity is acceptable day to day                                                  | Trial ends 2026-10-25; D-17 item 8 already keeps it                                                                                                                                                                                                                       | Mark accepted (bookkeeping)                                                                                                                                            |
| **A-27** Workers + D1 deploy whatever the author, and don't pause                                     | Deploys of agent-authored merges shown on the website (PR 7, #10); idle pause untested                                                                                                                                                                                    | Matters only if lalista moves to Cloudflare                                                                                                                            |
| **A-15** a thin devshop delivers the chain                                                            | Decided at go/no-go (D-17); row still says `untested`                                                                                                                                                                                                                     | Mark validated by D-17 (bookkeeping)                                                                                                                                   |

## 4. Direction

**Does what we have still lead to TARGET?** For a static site, yes: the loop runs, the walls held,
approval ships, quality has numbers. For a real app, three TARGET items that M3 depends on have no
mechanism:

- **Safety 3, guardrail files called out:** nothing in `runtime/` lists changes to `.github/`,
  `.claude/`, `.devshop-version`, migrations or the devshop's copies in the PR. CI's checks run from
  the project's tree (`ci.yml` and `check-fast.sh` are seeds; `spec-check.py`, `contract-check.py`
  are copies), so a PR can weaken a check and go green on the weakened copy. With an owner who
  approves at direction level, "required CI" is a wall only for the PRs whose CI files are
  unchanged. That is the root cause; a call-out computed from `main` (a `pull_request_target` job
  the PR can't edit) is the smallest fix.
- **Ship 3, migrations:** in the deploy pipeline, expand/contract only, a restore point before a
  destructive step. None of it exists for any stack, and the backward-compatibility job waits for
  "the first destructive migration" with nothing to detect one.
- **Ship 5–6, watching production and rollback:** the canary and health check live in the website
  repo; no skill mentions rollback, revert or the next-day check. The Cloudflare home also says a
  broken `health` check on `main` blocks every PR until the owner removes it, which during an
  incident would block the revert PR too (not verified on a real incident).

**Is TARGET still right?** Mostly. Proposed edits for the owner (§ 9 item 7):

1. **Add data safety as its own Safety item:** previews never touch production data; migrations
   run only from a `production`-environment job ordered before the deploy; destructive steps need a
   named restore point. Today it is a sub-bullet of Ship 3 with no milestone.
2. **Ship 2 and Ship 5 are stale:** the pre-merge health check is no longer deferred (the website
   made it required); the canary is a CI job, not gstack's `/canary` in the session.
3. **Safety 7 (production-data grant) at M4 is too late or should be ruled out for M3:** M3 brings
   real data and real incidents. Recommended: rule it out for M3 explicitly (incidents are diagnosed
   from read-only observability), so nobody improvises a credential.
4. **Intent's "every change, however small, gets the `/spec` interview"** sits badly with "a
   one-line fix" and with 9–22 owner answers per website change; in practice it was skipped
   (F-NEW-78). Proposed: the interview for features; a one-paragraph spec and the go for fixes.
5. **Reach:** narrow to web and iOS until a project asks for more (Android, React Native, Electron
   and AWS have nothing heading toward them).

## 5. Metrics, re-baselined

Measured from REVIEW-2's commit (`f11428f`, 2026-10-14) to `424d75a`, and from the "How this change
went" comments on devshop PRs #131–#151 (18 of 20 merged PRs carry one).

| Measure                                  | REVIEW-2                 | Now                                                               |
| ---------------------------------------- | ------------------------ | ----------------------------------------------------------------- |
| Devshop PRs                              | ~80 in 7 days            | 27 merged 2026-10-15 to 2026-10-20 (18 on 10-16); target ~1 a day |
| `runtime/` lines                         | 3,933                    | 6,983 (+78 %)                                                     |
| Test files / specs                       | 51 / 4                   | 76 / 14                                                           |
| Revamp notes (words, all `.md`)          | 106,186                  | 113,093; LOG 33k                                                  |
| Skills over the 60-line warning          | —                        | `pr` 73, `intent` 72                                              |
| Open findings                            | 29 live (after the sort) | 31; 29 after this sort                                            |
| Cost per devshop PR (session + reviewer) | run 2: $14.28 builder    | median $12.58, total $276 over 17; reviewer $11 of it             |
| Request → live per devshop PR            | run 2: 8 h 34 min        | median 4 h 34 min (23 min to 56 h 46 min)                         |
| Claude working / waiting on the owner    | —                        | median 25 min / 214 min; waiting is 95 % of elapsed               |
| Review rounds per PR                     | `ship` ×7 on one PR      | median 4; 90 rounds, 72 passed                                    |
| Red CI runs                              | —                        | 3 in 52 pushes                                                    |
| Website: cost per change, weekly %       | —                        | **none recorded**                                                 |

Reading: the owner's wait dominates every change and the cost per devshop PR is about the cost of a
small feature, yet most of the six days' PRs were records machinery (releases 4, metrics fixes 5,
findings and roadmap 6, contract 2). PR #148's comment shows a negative session cost ($-1.11), a
metrics bug of the kind #140 fixed (new finding, § 6). The baseline for M3 is the website's next
change's comment, which does not exist yet.

## 6. The findings log, walked

All 31 rows checked against the code at `424d75a`. **None is closed by R-13**: PR #151 deleted the
rows it closed (F-NEW-103, 108, 116) and moved two into the Cloudflare home (107, 109); it partly
mitigates two that stay.

**Closed by the stack home (5): F-NEW-80, 81, 82, 89, 90.** The Cloudflare home carries each as a
rule (`runtime/stacks/cloudflare/README.md`, lines 246 and 253–266), so by the template's rule the
rows should be deleted. They are closed for Cloudflare only: 81 (`og:image` against the site under
test), 82 (fonts in the byte budget) and 90 (prove the blocked-fonts state) don't depend on the
stack and belong in `runtime/guidelines/ui.md` before lalista (W10.11.7 below, now their only
record). Deleted on the owner's answer (§ 9, Outcome).

**Still watching (26)**, with what M3 does to them:

| Hits every M3 change (9)                                                                                                                                                                                                                                                                                                                                                                                                                     | Hits M3 sometimes (7)          | Not M3 (10)                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------------ |
| **77** (med, **5 sightings**: `dispatch.sh` still falls back to `${CLAUDE_PROJECT_DIR:-.}`; on lalista a restart could run the default devshop, not the pin), **78** (med), **79** (med), **87** (med, browser part fixed), **88** (med), **91** (med), **92** (med; R-13 wrote the `<spec> AC-<n>` rule but `spec-check.py` reads no prefix, so a second spec's `AC-1` is still "named"), **101** (low, mitigation labelled), **102** (med) | 86, 94, 98, 106, 113, 114, 115 | 84, 85, 93, 96, 97, 99, 100, 111, 112, 117 |

Corrections found on the walk: F-NEW-85 overstates (the body check accepts an em dash, en dash or
hyphen after `none`; only "none yet:" and the template's silence remain); F-NEW-96's risk was
accepted by the owner, so `low` fits better than `med`; F-NEW-100 and 92 are partly mitigated by
R-13.

**For the owner, "roadmap or keep watching?":** F-NEW-77 (5 sightings, the only row at 3 or more)
and the open `med` rows 78, 79, 87, 88, 91, 92, 96, 102.

**New from this review** (F-NEW-119 to 121 written to `FINDINGS.md` on the owner's answer; F-NEW-118
is to be fixed by its own PR, W10.11.0, next, so it gets no row):

| Proposed row | Severity | What                                                                                                            |
| ------------ | -------- | --------------------------------------------------------------------------------------------------------------- |
| F-NEW-119    | med      | TARGET Safety 3 (guardrail files called out in the PR) has no mechanism; CI's checks run from the PR's own tree |
| F-NEW-120    | low      | `change-metrics` reported a negative session cost on PR #148 ($-1.11)                                           |
| F-NEW-121    | low      | The root README still says v2 "doesn't do anything for projects yet" and that no stack home ships               |

## 7. M3, detailed

Proposed as W10.11 for [W10-v2.md](workstreams/W10-v2.md) once the owner agrees the order (§ 9
item 8). Rolling wave: these are concrete with a done-when; M4 stays coarse. The rule from D-17
item 10 holds: the devshop changes only when lalista asks for it, except the entry tasks, which
exist because lalista is a real app with data.

**Entry (before the first lalista change):**

- **W10.11.0** Fix the template titles (F-NEW-118): the upgrade skill's and new-project's titles
  carry a Conventional Commit type; a test runs `pr-title-check.py` on both. _Done when:_ the
  website's upgrade PR passes its title check. Also unblocks § 2's plain run.
- **W10.11.1** `[owner]` lalista's walls (W0.6.2 and W0.5.3 pulled forward from M4; W0.6.2 says
  "before lalista resumes"): every CI secret in a `production` environment limited to `main`, none
  at repo scope; v1-era tokens rotated (Vercel, Supabase service role, Sentry); a ruleset, not a
  classic rule (F-NEW-114); squash only; the agent identity as a Write collaborator. _Done when:_
  the session checks from outside (repo secrets list empty, the safety table's refusals once).
- **W10.11.2** `[owner]` The platform and money call (F-NEW-18, 19; D-17 items 5 and 11): Vercel
  Pro, Action-based deploy, or a move to Cloudflare; Supabase paid or not, and whether point-in-time
  restore is part of it; plan headroom. Then A-28 tested with one agent-authored merge.
- **W10.11.3** Data safety in the Next.js + Supabase home, before any change that touches data:
  previews on their own database (A-29: Supabase branching or a second project; the session checks
  the Preview env holds no production URL or ref); migrations applied only by a `production`-env job
  ordered before the deploy; a fast-tier check that fails a new migration with `DROP`, `TRUNCATE`,
  `RENAME`, `ALTER … DROP` or an unbounded `UPDATE`/`DELETE` unless the spec names it and its
  restore point, shipped with a known-bad test (it is a project-facing check). Lessons L-58, L-59,
  L-62, L-68 and L-71 go in here.
- **W10.11.4** The guardrail call-out from `main` (F-NEW-119, Safety 3): a `pull_request_target`
  job that lists changed guardrail paths and devshop copies that differ from the pinned tag, in one
  comment. _Done when:_ a PR that weakens `check-fast.sh` gets the comment, from a job the PR can't
  edit (attack scenario).
- **W10.11.5** Spec→test namespacing (F-NEW-92): `spec-check.py` matches `<spec> AC-<n>`, so a
  second spec's items aren't named by the first's tests. Before lalista's second spec.
- **W10.11.6** lalista adopts v2: one PR placing the pinned files into the existing repo, v1's
  devshop files removed, both tiers green, the contract check passing. A-11 re-run in lalista's
  environment with the registry hosts allowed.

**The work:**

- **W10.11.7** The design baseline for React (W10.8.3's B or C), lalista's `DESIGN.md` by the
  route that worked on the website (hand-built variants published as a page, F-NEW-87), and F-NEW-81,
  82 and 90 into `ui.md`.
- **W10.11.8** The reviewer on a real app: runs the project's fast tier in its clone (F-NEW-23, 59,
  61); its local run against a local Supabase, or could-not-run said plainly, never a remote database.
- **W10.11.9** Watching production on a dynamic app: the canary and health check with an
  authenticated smoke step on a test account; a revert PR not blocked by a failing `health` check;
  the next-day check as a scheduled task; the incident drill (a planted production fault, the
  rollback the owner executes).
- **W10.11.10** Five features through v2, each a plain run with its record (cost per change and
  weekly % recorded this time); v1 retired for lalista.
- **W10.11.11** The Next.js + Supabase home written from what shipped, as R-3 was.

Rough effort: M3 ~15 agent-days stays; the entry tasks are about 4 of them, plus one owner sitting
for W10.11.1–2.

## 8. The fresh adversarial review

A fresh-context reviewer read the repo against the owner's goal, not against this review. Its
verdict: _"M2 proved the pipeline on a static site that holds no data. M3 changes the risk … none of
those risks has anything built against it yet. Meanwhile the devshop grew about 75 % in 6 days,
mostly in records machinery."_ Its findings, after I re-checked the ones marked verified:

| Sev  | Finding                                                                                                                                | Checked                                             | Where it went           |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ----------------------- |
| high | lalista's secrets and rotation are deferred to M4, but M3 resumes lalista; a branch workflow on `pull_request` sees repo-scope secrets | W0-groundwork lines 59, 67 read                     | W10.11.1, § 9 item 1    |
| high | Preview builds can reach production data; nothing covers preview databases                                                             | `runtime/` has no such rule; lalista's env not read | W10.11.3                |
| high | TARGET Ship 3's migration rules don't exist                                                                                            | grep of `runtime/`                                  | W10.11.3                |
| med  | CI's checks run from the PR's tree; Safety 3 is unbuilt, so "required CI" is a wall only when the CI files are unchanged               | `grep -ri guardrail runtime/` finds nothing         | W10.11.4, F-NEW-119     |
| med  | The reviewer on a real app needs the fast tier and a local database (A-11)                                                             | A-11 tested today: blocked by the network policy    | W10.11.6, 8             |
| med  | The spec→test check proves nothing for a second spec                                                                                   | `spec-check.py` docstring, "Known limit"            | W10.11.5                |
| med  | The upgrade and new-project titles fail the title check                                                                                | ran `pr-title-check.py` on both: exit 1             | W10.11.0                |
| med  | No skill watches production or prepares a rollback; a failing `health` check would block the revert PR                                 | grep of skills; incident not observed               | W10.11.9                |
| med  | Process grew back (+78 % runtime, 27 PRs in 6 days); two design reviews overlap (R-5's `/design-review` and R-6's browser lens)        | measured, § 5                                       | § 9 item 6              |
| low  | Merging `main` into an approved branch costs a re-approval and ~10 minutes a round                                                     | LOG #81                                             | already ruled (PR #141) |

Where I disagree: it proposes dropping one of the two design reviews. They do different jobs: the
build's `/design-review` lets the builder fix its own work before review; the reviewer's lens is the
independent check. Keep both until the website's plain run shows whether the second ever finds what
the first missed; then decide. It also proposes R-9 (the air-gapped reviewer) during M3; I'd keep it
after M4 and do W10.11.4 instead, which covers the bigger hole (a PR weakening CI) for a fraction
of the cost.

## 9. Decisions for the owner

**Outcome so far (owner, 2026-10-20, in chat):** item 2, yes: the title fix now, then the owner
cuts `v2.1.1`, the website upgrades, and a small website change is the plain run (item 5: M2
closes on that run; the website was already on `v2.1.0`). The gaps in § 1 need no devshop work:
Lighthouse on the live domain, the published link, cost per change and the touchpoints are all
recorded on that run. Item 3: the five rows closed by the Cloudflare home are deleted, F-NEW-119
to 121 logged (F-NEW-118 is the title fix itself); no more full walks of the log: a row is read
again when it is seen again or when the task it touches starts; F-NEW-77 still waits for the
owner. Item 6 changed: no PR-a-day rule; the devshop does now only what blocks the next real step
or protects production data, and the rest waits for evidence. A-11: the owner will allow the
registry hosts, in lalista's environment, when M3 starts. Items 1, 4, 7 and 8 are open.

Each with a recommendation, as put to the owner.

1. **lalista's walls before M3, not at M4** (W0.6.2, W0.5.3; you deferred them "until the end of
   the revamp", but W0.6.2's own condition is "before lalista resumes"). Recommended: yes, as
   W10.11.1, one sitting.
2. **Fix the title bug now** (W10.11.0, one small PR). Recommended: yes, before the website's
   upgrade PR.
3. **The findings sort** (applied, see Outcome; 85 and 96 left as they are, F-NEW-77 still open):
   delete F-NEW-80, 81, 82, 89, 90 (closed by the Cloudflare home); correct 85 and 96
   as in § 6; add F-NEW-119 to 121. Then "roadmap or keep watching?" on F-NEW-77 (5 sightings) and
   the `med` rows 78, 79, 87, 88, 91, 92, 96, 102. Recommended: roadmap 77 (root cause before
   lalista, where a wrong version matters), 92 (it is W10.11.5) and 102 (every cloud PR); keep
   watching the rest.
4. **The platform and money call** (F-NEW-18, 19), due "when the website milestone ends". No
   recommendation on money; note that a move to Cloudflare reuses the home and the canary but costs
   a migration off Vercel and Next.js's Workers adapter, while Vercel Pro keeps the app as it is.
5. **How M2 closes:** declare it met with § 1's gaps on record, or after one plain run on the
   website at `v2.1.x` (§ 2). Recommended: the plain run; it is the first real check of R-5, R-6
   and R-13, and it gives M3 its first cost-per-change number.
6. **Lean-out before M3:** freeze `change-metrics` (fix only F-NEW-120), no new devshop machinery
   unless lalista or the website asks for it, and hold devshop PRs to about one a day (D-17 item 10,
   not met this week). Recommended: yes. _Superseded by the owner: no PR-a-day rule (Outcome
   above)._
7. **TARGET edits** (§ 4: data safety as a Safety item; Ship 2 and 5 updated; Safety 7 ruled out
   for M3; the interview for features only; Reach narrowed). Recommended: yes, as one docs PR.
8. **M3's tasks and order** (§ 7, W10.11.0–11). Recommended: as listed; the entry tasks first.
9. **Housekeeping, no decision needed unless you object** (proposed, not done here): A-15 and A-24
   marked as D-17 decided them; A-28 and A-29 added; the root README's status lines updated (F-NEW-121).

## 10. What I checked, and what I couldn't

**Checked.** PLAN's exit criteria, PROCESS § 5, TARGET's north-star and Safety/Ship pillars,
ASSUMPTIONS, D-17, W10's M2 and M3 sections, W0's deferred tasks, LOG #70–#86. All 31 findings rows
against the code at `424d75a` (a helper read them; I re-checked the Cloudflare home's lines,
`spec-check.py`'s known limit, the body check's dash rule and `dispatch.sh`'s fallback). The two
template titles against `pr-title-check.py`. Size and PR counts with `git` between `f11428f` and
`424d75a`. The "How this change went" comments on PRs #131–#151 through the GitHub API. A-11: a
Docker daemon started as root in this session, `supabase start` with the CLI pinned at 2.48.3, the
image pull refused by the network policy (the proxy's status lists the refused host). This repo's
fast tier on the unchanged tree: 40 of 40 files passed.

**Couldn't.** The website and lalista repos: attaching them was refused by the session's
permission check, so their PRs after #10, their pins, Lighthouse on the live site, the canary's
later runs, lalista's secrets, protection and Vercel env are not read. No plain run (it needs the
owner in the website's session). Supabase's start-up time (the pull never finished). The owner's
own time beyond the "waiting on you" figures.
