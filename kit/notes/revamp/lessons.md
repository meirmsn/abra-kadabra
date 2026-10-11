# Lessons from v1

What earned its place in v1 and carries into v2 (W10.3.1). Each lesson is written as a
**v2 requirement**, followed by the incident or recurrence that earned it, its source in v1,
its [TARGET](TARGET.md) pillar, and whether it holds for any stack or only one.

- **Bar.** A lesson is carried only if the practice **caught a real problem** or the trap
  **kept recurring** (two or more bites, or a friction-log count of 2 or more), or the single
  incident was **nasty**: it reached users or production, or failed silently with no error and took
  real time to diagnose (owner call, 2026-10-11, PR 47). A rule written after one mild incident that
  never fired again goes under [Considered, not carried](#considered-not-carried).
  Lessons tied to v1 machinery that v2 drops (devcontainer firewall, virtiofs, husky, `/devshop`
  bind mounts, sudo-locked files, the `ak-*` pipeline) keep only their principle, when one survives.
- **Sources.** All paths are as of tag `v1-final` (v1 files are unchanged on `main` since). `§` names
  a section heading. "PR n" without an owner refers to the project named next to it (lalista,
  home-os); devshop commits are short SHAs. Git history in the cloud clone is shallow, so most
  citations point at the incident notes v1 wrote down, not the original commits.
- **FINDINGS** ids are cited where a lesson matches a row, to speed up W10.3.3.
- **Out of scope:** home-os's own repo (W10.3.2). The mild single-incident project rules below are
  marked ↻ "re-check in W10.3.2". If home-os shows a second bite, they move up.
- **This file follows L-01.** Incidents are described by project name and shape, never by URL,
  project ref, team slug, org id, handle or email.

Contents: [Seed](#seed-requirement) · [Intent](#intent) · [Build](#build) · [Verify](#verify) ·
[Review](#review) · [Ship](#ship) · [Safety](#safety) · [Environments](#environments) ·
[Reach](#reach) · [Shape](#shape) · [By stack](#by-stack) · [Not carried](#considered-not-carried) ·
[Coverage](#sources-and-coverage)

---

## Seed requirement

### L-01 · The devshop never holds project or personal identifiers

**Rule.** The devshop holds no project identifiers: no production or preview URLs, Supabase project
refs, Vercel team slugs, Sentry org or ingest ids, project `owner/repo` slugs, or anything similar.
Nor does it hold personal identifiers: no GitHub handles, account names or email addresses of the
owner or anyone else. A project's name, plus enough context to explain why a change exists, is fine.
Project config lives in the project (see L-47). Repo locations come from the configured git remote,
never from a hard-coded account. Tests use synthetic values (reserved names such as `example.com`,
made-up identities). A deterministic CI scan over the devshop rejects identifier-shaped strings.

**Why.** Owner requirement (2026-10-11, LOG #14; personal identifiers added in the PR 47 review).
v1 broke it in several places:

- `kit/scripts/lib/extract-prod-url.sh:13,16` quotes a home-os production hostname in its header
  comment, as the input that failed and the output it corrupted. `kit/tests/extract-prod-url.bats:26–34`
  uses the same hostname as fixture input and expected output, while its own header calls the
  fixtures "synthetic". An invented host would have exercised exactly the same parse shapes.
- The incident notes in `.claude/skills/devshop/go-live/SKILL.md` § Step 1.5 (lines 173–174)
  hold home-os's production hostname. The canary note (line 498) holds lalista's.
- `.claude/skills/devshop/new-project/SKILL.md:1366` uses the owner's real Vercel team slug in a
  redirect-allow-list "e.g.".
- Roadmap and tracker notes: `kit/notes/roadmap/lalista-launch.md:221` and `kit/TODOS.md:241`
  (production URL), `kit/notes/roadmap/qa-options.md:17` (hosted Supabase URL, which embeds the
  project ref), `kit/notes/projects/lalista.md:45` (production URL, plus per-project config kept in
  the devshop). `kit/ROADMAP.md` itself only uses placeholders (checked).
- A project `owner/repo` slug in a comment (`kit/scripts/preship/slow-job-lifecycle-check.sh:173`).
- Personal: the owner's handle and email are the "real identity" in a test
  (`kit/tests/guard-fixture-identity.bats:39–40`), where any made-up identity tests the same thing.
  The owner's handle is hard-coded in a push URL (`.claude/commands/ak-clean-branches.md:20`) to get
  around the old devcontainer's SSH remote, where the configured remote would do.
- The history scan (W0.7.1) found lalista's Supabase ref three times, Vercel URLs with the team
  slug, and a Sentry ingest id.

Root cause: v1 had no structured project config, so devshop code parsed project prose (L-47). The
"worked incident" habit then pasted the failing line, identifier included, into code, tests and
skills.

Pillar **Shape** (also Safety) · Scope **any** · FINDINGS F-VER-06 (project state in devshop notes)

---

## Intent

### L-02 · Size the change visibly at intake; never silently scope down

**Rule.** v2 decides how much process a change gets (fix, feature, app) visibly at intake, by a
written rule or by asking the owner. The agent never quietly drops the spec, the record or the
review because the change "felt small".

**Why.** During home-os PRs 40/41, the build skill "silently hand-rolled a direct implementation"
and dropped the spec, BUILD-LOG and PLAN tracking with no signal to the owner (`BUILD-LOG.md` §
ak-build-no-silent-scope-down). The pressure came from v1's one-size 19-gate pipeline: only 44 of
128 spec dirs ever got a `spec.md`.

Pillar **Intent** · Scope **any** · FINDINGS F-PIPE-13, F-PIPE-14

### L-03 · Prove "X behaves like Y" with a one-minute experiment before locking it

**Rule.** When a spec decision or a doc claim depends on how a tool or version behaves, v2 runs
the cheapest experiment first: compile a fixture, apply the SQL in a transaction, run the
command. Only then does the decision get locked. A wrong claim that was cheap to check counts as
a high-severity finding.

**Why.** It recurred across projects and tools:

- lalista PR 53 locked "override Tailwind v4 `--container-*` tokens". A direct compile later
  proved v4.2 ignores the override, which forced a revert inside the same PR.
- home-os PR 15 split `ALTER TYPE ADD VALUE` into its own file "assuming the per-file transaction
  wrapping was the gotcha. It wasn't".
- An audit found a doc's claim about how a DCG rule matches `--force`; a 30-second `dcg test`
  disproved it.

Sources: `.claude/skills/devshop/build/SKILL.md` § 0.2.5, `kit/docs/guide/migrations.md` §
Postgres enum extension, `kit/docs/guide/tailwind.md`, `docs-review/SKILL.md` § Section B — Adequacy.

Pillar **Intent** · Scope **any**

---

## Build

### L-04 · Fix the root cause, and label honestly which kind of fix it is

**Rule.** v2's builder prefers a fix that removes the trigger over one that treats the symptom. It
labels any detect-and-repair proposal as a mitigation and names the root cause beside it. It
deletes guards the root fix makes moot, and spends no build time against a root cause that
hasn't been confirmed.

**Why.** In worktree shared-config corruption (2026-06-02), the first plan was three bandaids.
The owner asked "bandaid or root cause?", and the fix that came out of that question made the
whole bug class impossible. The init-firewall hang fix went onto the plan twice and was demoted
twice because it aimed at the wrong layer.

Sources: `kit/docs/guide/conventions.md` § Root-cause over bandaid, `CLAUDE.md` § Implementation
Approach, `kit/FRICTION-LOG.md` § `init-firewall.sh` re-run mid-session hangs.

Pillar **Build** · Scope **any**

### L-05 · Mechanical steps live in tested scripts, never as shell snippets in prose

**Rule.** v2 puts every mechanical step (parsing, classification, gating) in a versioned script
with a shebang and tests, called with explicit arguments. Skills and docs call scripts. They never
embed bash for the model to retype into whatever shell it happens to have.

**Why.** It recurred at least 4 times:

- Unquoted `$STRING` loops don't word-split in zsh. Two independent builds silently produced an
  empty gate roster (friction count 2), and two merge incidents gave an exit 127 and a silent
  false pass.
- Two go-live call sites carried identical inline `sed` pipelines, so one parse bug broke both.
- go-live's Headline extractor was always empty and nobody noticed.

Sources: `kit/FRICTION-LOG.md` § zsh doesn't word-split, `merge-devshop/SKILL.md` § 1.0, the
`extract-prod-url.sh` header.

Pillar **Build** · Scope **any** · FINDINGS F-PIPE-01, F-PIPE-02, F-PIPE-11

### L-06 · Fix loops are evidence-first, bounded, and fresh-context

**Rule.** When a CI job fails a second time, v2 pulls the real artifacts (trace, logs,
`test-results/`) before attempting another fix. CI uploads the directory that actually holds them.
Each retry runs in a fresh context that reads an "already tried" log. After a fixed number of rounds
the loop escalates to the owner (TARGET: three).

**Why.** It recurred at least 4 times:

- lalista's slow-job stabilisation spent ~30 min on 4 blind retries because the trace was
  unreachable.
- home-os PR 28 ran a 6-attempt, ~2.5 h loop chasing "PostgREST cache staleness" when the real
  cause was a migration with no rollback marker.
- home-os PR 36 took 5 CI cycles; lalista PR 49 took 4.
- The CI template uploaded `playwright-report/`, which is empty under `reporter: 'github'`.

Sources: `build/SKILL.md` § 5.4, `BUILD-LOG.md` § ci-rollback-explain-marker-loud, `kit/docs/guide/ops.md`
§ Where Things Happen, `kit/docs/CHANGELOG.md` v1.20.0.

Pillar **Build** · Scope **any**

### L-07 · Validate untrusted responses at one wrapper seam

**Rule.** v2 treats model output, edge-function and third-party responses as untrusted input. It
parses them against a schema inside the API wrapper, not in components. On failure it reports with
a scrubbed excerpt and throws a typed error, never an `as` cast and never a half-valid write. A
shape accepted at two boundaries, such as LLM output and a user PATCH, shares one validator.

**Why.** This came up in 4 PRs across 2 projects: home-os PRs 19, 26 and 27 (the last shares one
validator between LLM output and user PATCH), and lalista PR 6. A model forced to use a tool can
still refuse.

Sources: `kit/docs/guide/llm-trust-boundaries.md` § Pattern 1, § Pattern 3,
`kit/docs/guide/wrapper-boundaries.md` § Runtime Validation.

Pillar **Build** · Scope **any**

### L-08 · Run the affected tests in-session; leave the full suite to CI

**Rule.** v2's builder runs the new and affected tests while it works (none for docs-only
changes). The full suite runs once, in CI (L-15). The builder doesn't re-run everything as a ritual
checkpoint.

**Why.** A single devshop build ran the full ~1,645-test suite 10+ times (~12 min each), 3–4 of
them after docs-only tasks. This happened on every devshop build, and the owner asked why the
pipeline was slow.

Sources: `kit/FRICTION-LOG.md` § `/ak-build` + `/ak-merge-devshop` re-run the full bats suite.
Matches TARGET Build.

Pillar **Build** · Scope **any**

### L-65 · Wrappers around event sources pass errors and status through, not just data

**Rule.** A v2 wrapper around a realtime channel, WebSocket, SSE stream or emitter exposes an
error and status callback to its callers, so the UI's failure state has a way to fire.

**Why.** Nasty single incident: lalista PR 27. `subscribeToList` dropped `CHANNEL_ERROR` and
`TIMED_OUT`, so real WebSocket failures in production never showed the sync-error banner. Users
weren't told their list had stopped syncing, and only a near-impossible synchronous throw could
trigger the banner.

Sources: `kit/docs/guide/wrapper-boundaries.md` § Worked example: subscribeToList,
`tests-review/SKILL.md` § Wrapper API design — lifecycle events not just data.

Pillar **Build** · Scope **any** (instance: Supabase Realtime)

### L-66 · Auth error paths report to error monitoring before they redirect

**Rule.** v2's server-side auth handlers (OAuth, PKCE, magic-link callbacks, sign-in actions)
capture the error to error monitoring, with a route and stage tag, before redirecting the user with
a coarse reason. The reviewer flags an auth call whose error branch only redirects.

**Why.** Nasty single incident: home-os PR 19 (2026-05-15). The first production invitee's sign-in
failed (a Safari Private Browsing PKCE failure). The callback redirected with
`error=callback_failed` and recorded nothing, so the failure left zero telemetry and took about an
hour to diagnose. The framework's documented pattern only redirects.

Source: `kit/TODOS.md` ("Convention: any server-side auth-callback handler must
`Sentry.captureException` on error").

Pillar **Build** · Scope **any** (instance: Next.js + Supabase)

---

## Verify

### L-09 · Three outcomes: pass, fail, could-not-run, where could-not-run never passes

**Rule.** Every v2 check (CI step, reviewer lens, deploy probe) reports pass, fail or could-not-run.
Missing tools, an unhealthy environment, empty tool output, swallowed stderr, a 403 from an API and
an unmatched glob all count as could-not-run, which blocks "done" like a failure. "Not applicable"
is accepted only as a verifiable path fact ("diff touches only `docs/**`"), never as a judgement or
"matches the earlier PR's precedent". Before browser or QA checks, v2 checks environment health
(dev server reachable, services up, memory, free ports) and reports a sick environment as
could-not-run.

**Why.** This is v1's most-recurring failure class (10+ bites):

- home-os PR 15 shipped past `blocked` with sign-in placeholder screenshots instead of the
  feature.
- home-os PRs 27 and 28 self-advanced past 4 sandbox-blocked gates "per precedent".
- lalista PR 65 pre-classified QA as `n/a`, and lalista PR 10 reported a QA pass that never ran.
- A missing Chromium turned into a cheerful "skipped" (CHANGELOG v1.9.0).
- home-os PR 36 had OOM plus zombie ports, which gave silent skips and 5 CI cycles.
- The go-live prod probe skipped itself silently on home-os PRs 39 and 44 (parser returned
  empty), and on PR 9 (empty URL slot).
- `sudo cat … 2>/dev/null` read a populated file as empty.
- The slow-job check read a 403 as "job missing".
- `/ak-spec`'s glob never matched in any version, hidden by `2>/dev/null`.

Sources: `build/SKILL.md` § Phase 3 → Phase 4 handoff, `pre-ship/SKILL.md` § n/a is not legal
for LLM-mediated gates, `kit/docs/guide/conventions.md` § Local environment health check,
`go-live/SKILL.md` § Step 1.5, `kit/FRICTION-LOG.md` § `/ak-spec` silently drops.

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-03, F-PIPE-05, F-PIPE-06 (v1's encoding halted every
non-UI PR, so v2 needs the path-fact form), F-VER-04, F-HOOK-06, F-GS-06

### L-10 · No stand-ins for real verification

**Rule.** v2 never lets the builder swap a live check for a stand-in (component mounted on an
unrelated page, stubbed API, fixtures, a quiet fallback to hosted services) and report it as
verified. A degraded environment is could-not-run (L-09), and the fix is to repair it.

**Why.** lalista PR 53: the local stack was down, so the agent mounted the success toast on the
marketing page and reported QA `pass`. The owner caught it from the screenshots. Earlier, a broken
docker-in-docker shape "silently routed" QA to the admin API against the hosted production project.

Sources: `pre-ship/SKILL.md` § No synthetic-harness substitution, `kit/docs/guide/ops.md` § Dev
Container (compose isolation).

Pillar **Verify** · Scope **any**

### L-11 · Prove every gate can fail

**Rule.** Every v2 hard check ships with a test that feeds it a known-bad input (a planted secret,
a failing test, a FAIL verdict, garbled output) and asserts that it goes red. A missing tool, a
timeout or unparseable output blocks; it never passes. Scripts run under strict mode with an
explicit shell. Rare paths get the same test, or are removed.

**Why.** At least 6 gates were silently inert:

- gitleaks ran with zero effective rules and reported "no leaks" on real tokens (reproduced).
- Hooks failed silently on dash (v1.34.0), and husky ran them with `sh` (v1.10.0).
- The drift guard had an "empty-literal false-pass" that only a corrupt-the-seed experiment
  exposed.
- Several hooks failed open on a missing `jq` or `dcg` or on a timeout.
- The advisor bypass failed open on a missing `-x`.

Sources: `kit/docs/CHANGELOG.md`, `BUILD-LOG.md` § bats-drift-guards, `kit/docs/guide/hooks.md`
§ 3. Husky pre-push.

Pillar **Verify** · Scope **any** · FINDINGS F-SEC-20, F-HOOK-01, F-HOOK-06, F-SEC-09

### L-12 · The reviewer's verdict is structured, fails closed, is stable, and is tested unmocked

**Rule.** v2's independent reviewer returns a schema-validated verdict, and anything else (empty,
garbled, unknown type) is FAIL. Identical input never flips between pass and fail. At least one
test drives the real reviewer path rather than a mock. The prompt judges the change itself and
never gets placeholder "reason" text it can latch onto.

**Why.**

- The push-to-main reviewer path was "100% broken" (a missing `case` arm) and survived
  invisibly because the pre-push tests mocked the reviewer.
- The verdict parser failed open on output that didn't start with `FAIL`.
- home-os PR 44: the same title and body got PASS, then FAIL, minutes apart.
- The reviewer wrote "all three dimensions pass" and returned FAIL over a "no reason given"
  placeholder.

Sources: `BUILD-LOG.md` § pushtomain-dispatch-arm, `kit/docs/guide/hooks.md` § Dual-surface
check-types. (W10.1.4 has since shown 40/40 stable verdicts for the locked-down v2 shape.)

Pillar **Verify** · Scope **any** · FINDINGS F-REV-01, F-REV-02, F-TEST-03

### L-13 · Verdicts come from machine signals, never from the model reading logs

**Rule.** v2 decides pass/fail from an exit code, a parsed count or the required-check status,
never by an agent reading output. That applies to CI watchers too: read the run's conclusion for
the exact SHA, not the watcher's exit code.

**Why.**

- In merge `bebda21`, one `not ok` was buried in ~1,500 TAP lines. The green tail was read as a
  pass, and `main` "landed red and stayed red".
- lalista PR 65: `gh run watch --exit-status` returned 0 on two runs whose conclusion was
  `failure`. Only the owner looking at the Actions UI caught it.

Sources: `merge-devshop/SKILL.md` § Phase 2.5, `build/SKILL.md` § 5.2.

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-11

### L-14 · Checks run against the tree being merged, in its real execution context

**Rule.** v2 checks and tests resolve every path from the checkout under test, never from a fixed
install location. Tests that run extracted shell keep the script's real options (`set -euo
pipefail`, IFS) and assert a sentinel, so "exited cleanly" can be told apart from "died silently".

**Why.**

- A wiring test read `$DEVSHOP/kit/scripts` (the main checkout) instead of the worktree. The gate
  said 1626/0 green while the change turned `main` red the moment it merged. The same root cause
  false-blocked commits in two more sessions (friction score 8).
- A test ran a firewall snippet without `pipefail`. Its 15 tests passed, the regression shipped,
  and it broke a project rebuild.

Sources: `kit/FRICTION-LOG.md` § `$DEVSHOP`-hardcoded reads are worktree-blind,
`kit/docs/guide/conventions.md` § Kit Testing.

Pillar **Verify** · Scope **any** · FINDINGS F-HOOK-08, F-TEST-01, F-TEST-05

### L-15 · The full suite plus deterministic checks is a required CI check on every PR

**Rule.** v2 runs the whole test suite and the deterministic checks as a required GitHub check
on each PR. A local, affected-only or hook-only run never stands in for it.

**Why.** `main` went red at least 7 times because only an affected subset ran locally (`1d343bf`,
`c6be31e`, `c3450fa`, `bebda21`, `ca4bc76`, among others). Reds already on `main` then blocked
unrelated builds, and two releases existed only to unbreak `main` (v1.30.0, v1.32.0).

Sources: `BUILD-LOG.md` § bats-drift-guards, § hygiene-threedot-polish, § template-csp-img-src.

Pillar **Verify** · Scope **any** · FINDINGS F-TEST-01, F-NEW-15

### L-16 · Tests assert behaviour, not source or doc text

**Rule.** v2 tests run the code and assert outputs, exit codes or rendered results. They never
`grep` for sentences in skills, docs or source. Whether prose is right is the reviewer's job.

**Why.**

- "grep-based bats test drift" is the top-scoring friction family (count 5, score 15). Docs
  were updated while the asserting test was missed (red `main`), and an edit wrapped a grepped
  literal across a line break.
- A `loadExemptions()` test only grepped the regex literal, so an always-empty implementation
  passed.
- Nine SQL lints never ran against any Postgres.
- v1 has ~1,070 prose-pinning assertions.

Sources: `BUILD-LOG.md` § bats-drift-guards, `kit/TODOS.md` (advisor-probe behaviour/live-Postgres
entries).

Pillar **Verify** · Scope **any** · FINDINGS F-TEST-03

### L-17 · Coverage is judged on behaviour, and tests that quietly run nothing fail

**Rule.** v2's reviewer checks that every behaviour change (new prop, new branch, changed rule) has a
test asserting it; a test file sitting next to the changed file is not enough. CI rejects
committed `.only`, requires every hard skip to point at a live tracker entry, and requires each
conditional skip to run in at least one CI job.

**Why.**

- lalista PR 43 added an `onEdit` callback whose paired test file covered nothing new.
- A sign-up no-enumeration change switched UI paths while the tests still pinned the old
  behaviour.
- lalista PR 27's audit found a skip pointing at a tracker section that had moved.

Sources: `build/SKILL.md` § Phase 5.8, `tests-review/SKILL.md` § Skipped tests audit.

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-12

### L-18 · An independent, fresh-context verifier exercises the change

**Rule.** v2's verification is done by an agent that has none of the builder's context. It reads the
spec and the diff and actually runs the change. The builder's own tests never stand alone.

**Why.** Over ~10 devshop features (2026-05-17 → 05-27), "test the changes" kept finding real bugs
the builder and its tests had missed: 7 stale cross-refs, wrong file modes, a parser that didn't
match the real input format, incomplete docs, dead branches. This is the evidence behind TARGET
Verify.

Source: `build/devshop-mode.md` § Phase 2.5.

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-12

### L-19 · Check the change against the intent; never rewrite the intent to fit the diff

**Rule.** v2's reviewer compares the finished diff with the agreed spec and its user-facing summary.
When they disagree, either the change is fixed or the owner is asked. The summary or acceptance list
is never edited to describe what got built.

**Why.** v1's Phase 6 rewrote the Headline "to still describe what shipped", edits flowed back into
`spec.md`, and 0 of 72 acceptance boxes were ever ticked. Nothing checked spec conformance at all.

Sources: `kit/docs/guide/workflow.md` § Step 4 (Phase 6).

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-12

### L-20 · The core user story is proven step by step

**Rule.** For a UI change, the v2 spec states the primary flow as 2–4 imperative steps (or "none" with a
path-fact reason). Verification produces evidence per step that the action completed, such as a
changed screenshot or captured state, across the user states that matter, not only the admin
happy path.

**Why.**

- lalista's core-flows PR passed QA on a trace reading "add-sheet open+Escape": the flow was
  never completed.
- lalista PR 10's QA walked only the admin-API happy path while unconfirmed sign-up bounced
  silently.
- The fix shipped as v1.11.0 and v1.16.0.

Sources: `spec/SKILL.md` § Core user story, `pre-ship/SKILL.md` § Core user story artifact assertion,
`kit/ROADMAP.md` § Auth UX conventions.

Pillar **Verify** (contract written at Intent) · Scope **any with a UI**

### L-21 · Findings block. Nothing ships "proceed but record"

**Rule.** In v2, every reviewer finding at medium severity or above is fixed or escalated to the owner
before the PR is presented. A skipped piece of evidence is accepted only with a real error output
or a blocker the reviewer can check, never with a plausible-sounding rationale.

**Why.**

- A merge advanced "silently" past `medium=2`. Both findings (a missing doc entry and a test guard
  the spec promised) shipped unfixed and were found only after merge.
- home-os PR 19 deferred screenshots over a "ws() interop" blocker that the repo's own E2E seeding
  disproved in 30 s.
- Visual-evidence drift ran across 3 consecutive home-os PRs.

Sources: `merge-devshop/SKILL.md` § 1.1, `kit/FRICTION-LOG.md` § `/ak-pre-ship` + Phase 5.9
visual-evidence deferrals.

Pillar **Verify** · Scope **any** · FINDINGS F-REV-03, F-REV-04, F-REV-05, F-HOOK-09

### L-22 · Diff-scoped checks use the merge-base delta (`base...head`)

**Rule.** v2's reviewer and any check that asks "what did this change touch" compute the scope
with three dots, from the merge-base, or after a rebase onto current `main`. A two-dot diff is never
used.

**Why.** It happened 3 times:

- An audit reported that a 3-file change "reverts" two skills; it was a two-dot artifact and
  wasted an audit cycle.
- The propagation precompute flagged a file only `main` had touched (fixed in `b174a11`).
- A phantom propagation flag on diverged squashes (v1.37.0).

Sources: `BUILD-LOG.md` § ak-merge-rebase-before-audit, § hygiene-threedot-polish.

Pillar **Verify** · Scope **any**

### L-23 · Renamed or removed names are swept from the docs in the same PR

**Rule.** v2 catches references to renamed, moved or deleted scripts, sections, skills and checks
deterministically in CI where it can (link and anchor resolution), and in the reviewer's docs lens
otherwise. A doc that claims a safety property is re-verified when that property changes.

**Why.** It recurred at least 6 times:

- 12 dangling cross-references across 8 files.
- 7 stale references after a rename.
- 3 scripts shipped without their rows.
- "Three stale false-safety-net doc claims", one of which load-bearingly justified a security
  property.

Sources: `BUILD-LOG.md` § ak-build-phase6-pr-surface, § lint-staged-rename-symlink, §
merge-devshop-worktree-hooks, § docsReviewed reviewer detects rename/move/delete drift.

Pillar **Verify** · Scope **any** · FINDINGS F-DOC-02, F-DOC-03, F-DOC-04

### L-24 · Local or CI green is not production green for config- and privilege-dependent behaviour

**Rule.** v2 treats the local stack as a different environment from production. A change whose
behaviour depends on roles, grants, server settings or engine version gets written to be
environment-independent, plus a read-only check after deploy (Ship).

**Why.** home-os had three separate bugs that were green locally and on preview, then failed in production:

- a prod-only `42501` (permission denied) from missing default grants;
- an ambiguous plpgsql OUT parameter that made "every 'Read this for me' click" return 500;
- `ALTER TYPE ADD VALUE` failing silently while the type-drift gate passed.

The Supabase recipes are L-58.

Source: `kit/docs/guide/migrations.md` § Supabase Cloud GRANT posture, § plpgsql OUT-parameter
column collisions, § Postgres enum extension.

Pillar **Verify** · Scope **any** (instances: Supabase)

### L-25 · Review results are durable, recorded per lens

**Rule.** v2's reviewer saves each lens's verdict durably (a commit, PR comment or check run) as
soon as it finishes. A crash loses at most one lens, and a resume picks up from there. A lens with
no recorded result counts as not run.

**Why.**

- home-os decide-state: a single pre-ship agent died after ~2 h and 207 tool calls, and the gates
  it had finished were hard to recover.
- home-os PR 26: an audit section was written but never committed, and was lost at
  squash-merge.
- home-os PR 10: an uncommitted audit blocked branch cleanup and was discarded.

Sources: `build/SKILL.md` § Phase 3 (per-gate sinks) + § 5.8.3, `check-docs-and-tests/SKILL.md` §
Step 5.

Pillar **Verify** · Scope **any** · FINDINGS F-PIPE-11

### L-26 · CI triggers and skip filters are right, tested, and default to running

**Rule.** v2's CI template runs pre-merge checks on `pull_request` and runs `push` only on `main`.
A docs-only skip uses native path filters or a classifier with a test, including root-level
`*.md`. It defaults to "run" on an empty or unknown diff and is confirmed on the first docs-only PR.

**Why.**

- `branches-ignore: [main]` on `push` doubled CI on every PR push (home-os PR 15).
- A `**/*.md` pattern in a bash `case` silently missed root `CLAUDE.md`, so a docs-only PR ran
  the full slow job (lalista PR 63).

Sources: `kit/docs/guide/ops.md` § Where Things Happen, `kit/docs/guide/conventions.md` § Skip-on-docs-only
filter.

Pillar **Verify** · Scope **any** (GitHub Actions)

### L-27 · The template's CI ships with every job on, guarded for empty projects

**Rule.** v2's stack templates ship the full CI, including integration and E2E, switched on from the
first commit. Steps that need content (migrations, specs) skip themselves when no such files
exist. Coverage never waits on a later PR remembering to switch a job on.

**Why.** home-os PRs 9, 10 and 15 each crossed the "first integration test" threshold without
switching the job on. Each time the gap shipped as "infra carry-over", because the agent couldn't
push workflows.

Source: `kit/docs/guide/conventions.md` § Slow-Job Lifecycle.

Pillar **Verify** · Scope **any** · FINDINGS F-NEW-16

---

## Review

### L-28 · Claim only verified state, read at write time

**Rule.** Before v2 writes "CI green", "preview up", "deployed", "task done" or "edit landed" in a PR,
comment, commit or log, it reads the canonical signal for the current HEAD at that moment: the
run conclusion for that SHA, the deploy platform's status, the staged diff, the repo's workflows.
It re-checks after every push. A checklist, a subagent's report or an earlier green run is not
evidence.

**Why.** It happened at least 6 times:

- lalista PR 18: ready-for-review comments cited an earlier green run, the latest run failed, and
  a public retraction was needed. A curl to the preview was blocked while the platform showed
  "Ready".
- lalista PR 43: 4 silent reds piled up across polish pushes.
- A commit subject claimed a fix that the formatter had reverted to a zero diff.
- home-os PR 19's body asked for a manual `db push` that a workflow already does.
- A subagent marked tasks "done" before committing.

Sources: `kit/docs/guide/conventions.md` § Verify state before public assertion, `build/SKILL.md` §
5.8.1, `kit/FRICTION-LOG.md` § Audit reviewers flag prettier/eslint-owned formatting, `BUILD-LOG.md`
§ implement-resume-reconcile.

Pillar **Review** · Scope **any** · FINDINGS F-PIPE-12

### L-29 · The PR description matches the final HEAD, checked once when the work is done

**Rule.** When v2 marks a PR ready, the reviewer checks that the title, body and screenshots
describe the final HEAD, and regenerates screenshots at that SHA. It is one check at done time,
not a per-push gate that asks for the same justification on every push.

**Why.**

- lalista PR 53: after the PR opened, a new E2E spec, replaced screenshots and a bundled CI fix all
  landed, the body went stale, and the owner asked "isn't the PR description stale?".
- Claude was seen pushing commits without updating the title or body.
- The per-push gate cost home-os PR 9 two identical bypass reasons.

Sources: `build/SKILL.md` § 5.3.5, § Phase 5.9, `kit/ROADMAP.md` § PR-description staleness check.

Pillar **Review** · Scope **any**

### L-30 · PR evidence is linked by commit SHA

**Rule.** v2 embeds screenshots and video by commit SHA or as uploaded assets, never by branch
path, so the evidence survives branch deletion.

**Why.** Branch-path images returned 404 as soon as the branch was deleted. lalista's backfill
rewrote 17 surfaces (73 URLs), and some PRs were still skipped by an over-cautious heuristic.

Sources: `BUILD-LOG.md` § pr-body-img-merge-sha-survival, `kit/docs/guide/workflow.md` § Step 6.

Pillar **Review** · Scope **any**

### L-31 · PR text describes the observable change, product story first

**Rule.** v2 PR titles and commit subjects describe the observable change (≤ 72 chars, no internal
jargon). Bodies open with the one-line summary and the user-facing announcement, then go down to
engineering detail.

**Why.**

- The bad→good table in conventions comes from real commits.
- home-os PR 27's engineering-first summary worked for reviewers, but after deploy the owner had
  to re-derive "what went live, product-wise?".

Already agreed in TARGET Review; this lesson records the evidence.

Sources: `kit/docs/guide/conventions.md` § Commit + PR Text Style, `build/SKILL.md` § Hero shots.

Pillar **Review** · Scope **any** · FINDINGS F-PIPE-01, F-PIPE-04

---

## Ship

### L-32 · Land only through GitHub, with green required checks on the exact merged SHA

**Rule.** v2 merges only through a GitHub PR, with required checks passing on the commit being
merged and the branch up to date with its base (or a merge queue). No local squash or local test
run stands in for that, and no check may test one tree and land another.

**Why.** Local merges went wrong at least 4 times:

- HEAD flipped to a parallel WIP branch mid-merge, and the fast-forward "landed on the WIP branch".
- In `1d343bf`, a red suite was fast-forwarded to `main` because the gate never pinned which
  commit it tested.
- A soft reset re-anchored when `origin/main` moved and staged phantom deletions of another
  feature.
- The merge skill could squash the wrong branch.

Sources: `merge-devshop/SKILL.md` § Phase 3, § Phase 2.5, `BUILD-LOG.md` §
merge-devshop-phase25-tree-pin, `kit/FRICTION-LOG.md` § Phase 2 soft-reset silently re-anchors, §
`/ak-merge-devshop` ignores `--branch`.

Pillar **Ship** · Scope **any** · FINDINGS F-SEC-07, F-PIPE-16

### L-33 · Probe production before merge and after deploy; "can't reach" is not "down"

**Rule.** v2's ship step checks production health before merging, so a deploy can't mask an
existing failure, and again after the deploy (canary). A real 4xx/5xx goes to the owner. A
connection failure on the agent's side (HTTP 000) counts as could-not-run, not as a production
incident.

**Why.**

- lalista PR 26: production `/` had returned 500 "since project setup", hidden because every flow
  started at sign-in. Only the pre-merge probe found it.
- lalista PR 28 and home-os PR 43 misclassified failures to connect.
- The probe was fixed at least 4 times (v1.21.0, v1.32.0, v1.36.0, v1.37.0).

Sources: `go-live/SKILL.md` § Step 1.5, `kit/docs/guide/workflow.md` § Step 6.

Pillar **Ship** · Scope **any**

### L-34 · List every manual deploy step in the PR, derived from the real deploy config

**Rule.** A v2 PR lists every deploy step the merge doesn't carry (dashboard-only settings, hosted
auth config, email templates, redirect allow-lists, domains). It derives what is automatic from
the repo's actual workflows, so the list is neither missing items nor padded with false ones. The
change isn't "live" until the listed steps are done and checked in production.

**Why.**

- Email templates don't deploy from the repo; "this trap caught lalista at chapter 1l ship time",
  and those pastes are "the recurring set".
- home-os PR 19's body told the owner to run a migration push by hand that a workflow already ran.
- v1 needed a blocking pre-merge check for unticked items.

Sources: `kit/ROADMAP.md` § /setup-email skill, § /ak-go-live post-merge prod-config sync (Arm B),
`kit/docs/guide/ops.md` § Out-of-band dashboard surfaces, `kit/TODOS.md`, `BUILD-LOG.md` §
ak-go-live-arm-a-preflight.

Pillar **Ship** · Scope **any** (instances: Supabase, Vercel; see L-61)

### L-35 · Every ship asks "what generalises?", and the answers go into one counted ledger

**Rule.** v2's ship step always asks what generalises beyond this project. Each answer goes into one
devshop ledger that deduplicates and counts sessions. An item is promoted into a rule or a stack
home only when its count or impact earns it and its root cause is confirmed. That is how "grows
only from proven lessons" works, and it is also this file's bar.

**Why.**

- lalista PR 26 produced 8 generalisations in one reflection; without the prompt "only 0–1 would
  have surfaced".
- The friction log's count gate pulled two premature commitments back to "observation".
- A near-duplicate entry "silently splits the count signal".

Sources: `go-live/SKILL.md` § 5b, `kit/FRICTION-LOG.md` § How to use it, `record-friction-log/SKILL.md`
§ Step 2.

Pillar **Ship** · Scope **any** · FINDINGS F-PIPE-17, F-NEW-04 (the ledger lives in the devshop,
never in a project)

### L-67 · The first production use of a critical flow gets a real-account smoke test

**Rule.** When a deploy is the first time a critical flow (sign-in, invite, payment) runs in
production, v2's ship step runs or requests an end-to-end check with a real account before it
reports the deploy healthy. An anonymous probe returning a redirect is not evidence that the flow
works.

**Why.** Nasty single incident: home-os PR 19. Go-live reported "deployed" because anonymous `/`
returned a redirect. The first invitee's sign-in failed 30 minutes later and looked like a deploy
regression. Auth lands in one of a project's first few PRs, and then nobody signs in on production
until the first real user.

Source: `kit/TODOS.md` ("`/ak-go-live` Step 1.7 … doesn't fire on first-prod-deploy").

Pillar **Ship** · Scope **any**

---

## Safety

### L-36 · A guardrail the agent can reach is feedback, not defence

**Rule.** v2 relies only on controls outside the session for anything that must hold: GitHub
rules, required CI, credential scope, protected environments. Hooks and permission rules inside
the session are helpful feedback, and docs must never present them as a boundary. Workflow checks
sit where every actor passes, not in session hooks that also fire inside subagents with no
authority to act on them.

**Why.** It recurred at least 7 times:

- Absolute-path deny rules never fired.
- Root-owned guard scripts went back to agent-owned after git operations, and the agent edited
  them freely.
- Commits in linked worktrees ran zero hooks.
- A gate wired only on the squash path was skipped by a direct-to-main commit that reached a
  release.
- Three PostToolUse nudges fired inside subagents, which ignored them or acted out of scope.
- In cloud sessions no git hooks run at all.

Sources: `kit/TODOS.md` (deny-rule and lock-erosion entries), `kit/FRICTION-LOG.md` § Pre-commit
hooks don't fire in linked worktrees, § PROPAGATION.md disposition-tag filter,
`kit/docs/guide/security.md` § Known Gaps, `kit/docs/guide/hooks.md` § Why workflow nudges live at
the git layer.

Pillar **Safety** · Scope **any** · FINDINGS F-SEC-01, F-SEC-04, F-SEC-13, F-SEC-19, F-HOOK-03,
F-HOOK-04, F-NEW-08, F-NEW-15, F-DOC-04

### L-37 · CI and deploy config change only with owner approval that GitHub enforces

**Rule.** In v2, `.github/workflows/**` and other CI and deploy config can be changed only with owner
approval enforced by GitHub (CODEOWNERS plus a required review, or a path rule). CI is where the
hard gates and secrets live.

**Why.** v1's protection was an accident: the devcontainer token lacked `workflow` scope. That
guard really was load-bearing; it blocked three home-os PRs from editing CI. The cloud agent's
credentials can push workflows (A-07), and CI passes repo secrets to same-repo PRs.

Sources: `CLAUDE.md` § Known Footguns ("Workflow push requires human"), `kit/docs/guide/conventions.md`
§ Slow-Job Lifecycle.

Pillar **Safety** · Scope **any** · FINDINGS F-NEW-16, F-NEW-12

### L-38 · No production credentials in CI; test clients refuse anything not local

**Rule.** v2 CI talks only to local or sandbox backends with sandbox keys. Production-only variables
have distinct names, and production credentials sit behind protected deploy environments. Test
and admin clients refuse any endpoint not on an allowlist of local hosts. It is an allowlist, not a
deny pattern for one vendor domain.

**Why.**

- A CI credential collision was caught at the gate and fixed by renaming to prod-specific
  variables.
- Projects created before 2026-04-25 mixed prod and local credentials and needed a migration.
- The v1 guard matched only `*.supabase.co`, so custom domains slip through.
- PR CI can read repo secrets.

Sources: `BUILD-LOG.md` § keepalive-supabase-ping, `kit/docs/guide/security.md` § CI Credential
Isolation, `CLAUDE.md` § Known Footguns.

Pillar **Safety** · Scope **any** (instance: Supabase) · FINDINGS F-TPL-06, F-NEW-12, F-SEC-08

### L-39 · Local dev, QA and preview never write to production by default

**Rule.** v2 projects point local dev, browser QA and test runs at a local or ephemeral backend by
default. Production telemetry keys stay out of local env. Pointing anything at production is an
explicit, visible opt-in.

**Why.**

- home-os PR 15: a Playwright form submit during screenshot capture created a real user on the
  production project.
- An earlier lalista QA walk wrote a household to the hosted project and cleaned up only the user.
- Hosted sign-ups are rate-limited (~30 min cooldown), which blocked QA.

Sources: `new-project/SKILL.md` § Step 13b, `kit/notes/roadmap/qa-options.md`, `pre-ship/SKILL.md` §
Tooling checks.

Pillar **Safety** · Scope **any** (instance: Supabase) · FINDINGS F-TPL-06

### L-40 · Secret scanning is a required CI check, with a config proven to detect, over every ref

**Rule.** v2 runs secret scanning in required CI, never only in local hooks. Its config is tested
against canary secrets (L-11), and history scans cover PR refs, not just branches.

**Why.**

- Worktree hooks silently didn't fire, so a merge-time scan was bolted on, and its fast-forward
  fallback then bypassed it.
- The shipped config had zero effective rules everywhere it ran.
- W0.7.1 found that squash merges hide most history in `refs/pull/*/head`: lalista went from 93 to
  567 commits once those were included.

Sources: `BUILD-LOG.md` § merge-devshop-worktree-hooks, `workstreams/W0-groundwork.md` (W0.7.1).

Pillar **Safety** · Scope **any** · FINDINGS F-SEC-20, F-NEW-15

### L-41 · Automation never touches state it doesn't own

**Rule.** v2 never discards, resets, stashes away or overwrites work the agent didn't author; WIP
is parked on a throwaway branch commit. Tests run in temporary repos with an isolated `HOME` and
git config, and CI rejects commits authored by a fixture identity.

**Why.**

- An operator stash vanished during a merge and was recovered from dangling commits.
- The orchestrator's gap on home-os PR 10 led to the rule "never `git stash` / `git restore`".
- A test override committed fixture commits onto the real HEAD.
- 19 commits in history were authored by the test fixture identity (v1.38.0).

Sources: `CLAUDE.md` § Known Footguns, `kit/FRICTION-LOG.md` § Operator stashes vanish silently, §
`$DEVSHOP`-hardcoded reads, `BUILD-LOG.md` § pipeline-correctness.

Pillar **Safety** · Scope **any** · FINDINGS F-HOOK-07, F-TEST-04

---

## Environments

### L-42 · One task, one isolated checkout, cut from fresh `origin/main`

**Rule.** Every v2 session or parallel task gets its own clone or worktree on its own branch,
created from a freshly fetched `origin/main`. Sessions never share a working tree, HEAD or git
config. Tools take explicit paths and SHAs, never the ambient working directory.

**Why.** It recurred at least 5 times:

- A parallel session moved a shared HEAD mid-merge and deleted a branch ref.
- `core.worktree`/`core.bare` were injected into a shared config twice.
- A worktree cut from a WIP branch inherited a stray commit (calibration-and-task-phases).
- A branch-checkout race made an unrelated home-os PR squash a spec skeleton onto `main`.
- A cwd reset broke an audit until it was driven by absolute paths.

Cloud sessions remove the shared mount, but the base-branch rule still applies (and on the Mac).

Sources: `kit/TODOS.md` (worktree HEAD-race), `BUILD-LOG.md` § worktree-shared-config-corruption,
`CLAUDE.md` § Two repos, two commit flows, `kit/ROADMAP.md` § Project-worktree setup support,
`merge-devshop/SKILL.md` § 1.1.

Pillar **Environments** · Scope **any** · FINDINGS F-VER-06

### L-43 · Setup runs non-interactively, fails loudly, and can't block its own repair

**Rule.** v2's environment setup (cloud setup script, Mac bootstrap) never waits on a prompt, stops
with a named error when a step fails, and is ordered so one broken step can't stop the step that
would fix it.

**Why.**

- A pipefail-killed firewall step, chained with `&&`, stopped init from ever pulling the fixed
  template, which deadlocked lalista's rebuild.
- pnpm's purge prompt hung rebuilds indefinitely until `CI=true`.
- A missing `.env` key aborted init under `set -e` with no message.

The firewall mechanism is dropped; the principle applies to v2's setup script.

Sources: `kit/docs/guide/ops.md` § Dev Container (pipefail-safe pipelines, recovery from a
deadlocked rebuild), § Known Footguns, § Troubleshooting.

Pillar **Environments** · Scope **any** · FINDINGS F-INFRA-07

### L-44 · Long-running servers start detached and are waited on

**Rule.** v2's run instructions start dev servers detached from the tool call, from the right
directory, and wait for the ready line before the first request.

**Why.** The agent harness kills background jobs when a Bash call exits. That showed up as
unexplained `ERR_CONNECTION_REFUSED` across QA, design-review and benchmark runs until the pattern
was settled during home-os PR 15. This is harness behaviour, not specific to the devcontainer.

Source: `kit/docs/guide/conventions.md` § Long-running processes in the Claude Code harness.

Pillar **Environments** · Scope **any**

### L-45 · Pin every toolchain input to one exact version everywhere; upgrade on purpose

**Rule.** v2 pins CLIs and runtimes (Node, pnpm, Supabase CLI, Playwright) to one version shared
by CI, cloud sessions and the Mac. It pins CI actions by SHA and images by digest. Upgrades happen
deliberately, on a schedule, with a smoke check of the behaviours known to change.

**Why.**

- Supabase CLI changes broke projects silently at least 4 times: the realtime publication
  stopped auto-including tables; Inbucket→Mailpit kept the env name but changed the API (timeouts
  in both projects); a bare `/verify` path returned 404; generated types disagreed with the
  database.
- Node and pnpm drift across container, template and CI.
- Vendored gstack sat ~110 releases behind while a fixed upstream bug caused a destructive rebuild.

Sources: `kit/docs/guide/supabase-ssr-boilerplate.md` § Pattern 4, § Pattern 9, `kit/TODOS.md` (base
image digest), `kit/ROADMAP.md` § gstack vendored upgrade.

Pillar **Environments** · Scope **any** · FINDINGS F-INFRA-05, F-SEC-18, F-GS-01

---

## Reach

### L-46 · Each stack home is proven by scaffolding a fresh project and running its CI

**Rule.** For each v2 stack home, the devshop's own CI creates a fresh project from it and requires
that project's CI to be green.

**Why.** Fresh scaffolds kept breaking: "7 fresh-scaffold gaps" (v1.30.0), "18 home-os-surfaced
onboarding papercuts" (v1.33.0), and post-audit fixes (v1.23.2). The analysis still found the CI of a
fresh project failing (`next lint` gone in Next 16; E2E specs for routes that don't exist).

Source: `kit/docs/CHANGELOG.md`.

Pillar **Reach** · Scope **any** (first: web) · FINDINGS F-TPL-01, F-TPL-02

---

## Shape

### L-47 · Project facts are structured config in the project, never parsed from prose

**Rule.** A v2 project declares its deploy facts (production URL, deploy surfaces, stack) in a small
machine-readable file in its own repo. Devshop tooling reads that file, never regex-parses
`CLAUDE.md`, and never keeps a copy (L-01).

**Why.**

- `extract-prod-url.sh` grew five tolerated shapes after real misses on home-os PRs 39 and 44.
- An audit then found two more parse bugs (an uppercase scheme, greedy line selection).
- Every miss meant the production probe was skipped silently.
- The fix was released 3 times (v1.32.0, v1.36.0, v1.37.0).

Sources: `kit/scripts/lib/extract-prod-url.sh` (header), `specs/go-live-prod-url-extraction/review.md`
§ Audit 1, `kit/docs/CHANGELOG.md`.

Pillar **Shape** · Scope **any**

### L-48 · Always-loaded context holds only silent-failure traps, under a hard budget

**Rule.** v2 keeps an always-loaded entry only if forgetting it causes silent wrong work. Each entry is a
symptom, a first action and a pointer, under a size budget checked in CI (TARGET Shape). Anything
the toolchain catches loudly, and any skill-specific procedure, lives elsewhere.

**Why.**

- home-os's CLAUDE.md reached 79k characters and was cut to 7.5k once the rule was applied.
- The devshop's grew back by ~41% within weeks of its trim, and a later prune under-delivered.
- An operational directive was put in CLAUDE.md, and the classification gate approved it.

Sources: `kit/docs/guide/claude-md.md` § The inclusion rule, `BUILD-LOG.md` § claude-md-hygiene, §
claude-md-regrowth-prune, § skill-operational-claude-md-routing.

Pillar **Shape** · Scope **any** · FINDINGS F-DOC-01, F-DOC-05 (keep the budget, drop the LLM gate)

### L-49 · Upgrades are pinned and diff-first, and every change states its project impact

**Rule.** Each file v2 places in a project has one owner. Devshop-owned files are pinned and not
edited in the project. Project-owned files are seeded once and never overwritten or deleted. The
guided upgrade shows a diff, deletions included. Every devshop change declares whether projects
must act (automatic, manual, conditional), and the upgrade shows only the steps that need action.

**Why.** It recurred at least 6 times:

- A new hook never reached existing projects because the propagation list was hard-coded.
- Sync deleted `.env` and replaced files wholesale; projects that added a gitignore line lost it on
  the first sync.
- rsync skipped same-size changes.
- Propagation logs became walls of no-op entries.
- An untagged block silently dropped a real migration step.

Sources: `BUILD-LOG.md` § manifest-driven file lifecycle, § supabase-port-series-and-sync-safety, §
sync-show-first-confirm, § propagation-skip-noop, `kit/docs/guide/architecture.md` § Propagating
build tooling updates, `kit/docs/guide/conventions.md` § Existing-Project Migration Block.

Pillar **Shape** · Scope **any** · FINDINGS F-VER-01, F-VER-03, F-VER-05

### L-50 · A project works completely without the devshop, and CI proves it

**Rule.** A v2 project builds, tests, commits and runs CI from a plain clone with no devshop
present. Its committed files contain no devshop paths, no devshop-only hooks and no devshop sample
content. Values that identify the project (such as the local DB `project_id`) are set at scaffold
time, because a sync can't take them back later.

**Why.**

- lalista PR 25 had to strip the `/devshop/...` cross-references that had piled up.
- The template's commit hook still aborts without `/devshop`, and the devcontainer won't start
  without a sibling checkout.
- Seed entries removed from the template still needed manual removal in both projects.
- lalista's local stack is named after its container directory because `project_id` was never set.

Sources: `new-project/SKILL.md` § Step 12.6, `kit/docs/guide/architecture.md` § Public contributors,
`kit/TODOS.md`.

Pillar **Shape** · Scope **any** · FINDINGS F-HOOK-02, F-TPL-07, F-DOC-07, F-VER-06

### L-51 · A fix to shared tooling goes back to the stack home as part of the same work

**Rule.** When a project fixes something its stack home owns (CI workflow, lint config, gitignore),
v2 sends the fix upstream to the devshop as an explicit step of that same work. The fix doesn't
stay stranded in one project, and the next upgrade doesn't undo it.

**Why.**

- home-os PR 15's CI fixes sat in two projects for about a month before reaching the template.
- `specs/*/screenshots/` was missing from the template, so projects added it locally and lost it
  on their first sync.

Sources: `kit/docs/guide/conventions.md` § Template propagation nudge, § Screenshot Routing.

Pillar **Shape** · Scope **any** · FINDINGS F-VER-03

### L-52 · Upstream tools are used unmodified and pinned; the devshop composes its own outputs

**Rule.** v2 never edits vendored upstream tools (gstack). It fixes them upstream or wraps them from
outside, pins the version (L-45), and composes its own PR title and body, handing them to upstream
tools word for word.

**Why.**

- A gstack upgrade silently wiped local edits (home-os PR 15 D3/D4, reverted in `dc18aa3`), and a
  sync clobbered `/ship` edits.
- Letting `/ship` compose the body produced a flat test plan without the required structure
  (PR 34).

Sources: `CLAUDE.md` § gstack, `build/SKILL.md` § 4.2.

Pillar **Shape** · Scope **any** · FINDINGS F-GS-01, F-GS-03, F-GS-08

### L-53 · The PR that ships a fix closes its tracker entries and rewrites "until X" docs

**Rule.** The v2 PR that ships a fix closes its tracker entries (all of them, not just the "active"
table). It rewrites docs that described the old limitation in present tense and removes every
cross-reference to them.

**Why.** It recurred at least 4 times:

- A leftover "without this, `gh run download` fails" line outlived its fix by a month, and a
  session skipped pulling CI artifacts that were waiting.
- sudo scoping shipped around 2026-04-10, but its tracker stayed open until June.
- Two CLAUDE.md trackers stayed open after shipping.
- A `PLAN.md § Planned` row was orphaned.

Sources: `kit/docs/guide/conventions.md` § Closing TODO / ROADMAP entries, `kit/FRICTION-LOG.md` §
A shipped feature's PLAN.md § Planned row, `BUILD-LOG.md` § claude-md-regrowth-prune.

Pillar **Shape** · Scope **any**

### L-54 · Process artifacts stay out of the project repo

**Rule.** v2 keeps pipeline scaffolding (gate logs, per-gate shards, review stubs) out of project
trees. Only artifacts that serve the product or its reviewers are tracked.

**Why.**

- home-os tracked ~7.8 MB of specs (115 screenshots) that nothing reads, cleaned up in PR 34.
- Orphan review stubs were left by docs-only merges.
- `specs/` was 54% of the tracked files.

Sources: `kit/ROADMAP.md` § Gitignore specs/ in project repos, `BUILD-LOG.md` §
ak-check-docs-orphan-stubs.

Pillar **Shape** · Scope **any** · FINDINGS F-DOC-06

---

## By stack

Lessons that hold for one stack only. They seed that stack's home (TARGET Reach) and are loaded
only when a task touches the stack. No Vercel-only lesson met the bar: L-69 covers env values set in
Vercel, and the other Vercel-related bites are covered by L-28 (read preview status from the
platform), L-34 (dashboard-only settings) and L-33 (the production probe).

### Web (any framework)

#### L-55 · Mobile E2E on WebKit: install WebKit, wait for hydration, type into controlled inputs

**Rule.** When Playwright uses iPhone device profiles, v2's web CI installs WebKit. Specs reach
forms through a click chain or an explicit hydration wait rather than `goto` followed by `fill`, and
use `pressSequentially` plus `toHaveValue` for React-controlled inputs.

**Why.**

- A Chromium-only install failed every `[mobile]` spec at launch (home-os PR 15).
- A fill 30 ms before the click raced hydration, so no auth call fired (lalista PR 26).
- `fill` resolved before React state synced and the form submitted empty, reproduced over 3 WebKit
  runs while Chromium passed (lalista PR 43).

Sources: `kit/docs/guide/supabase-ssr-boilerplate.md` § Pattern 5, `kit/docs/guide/conventions.md` §
Playwright + controlled inputs on WebKit, `kit/docs/guide/ops.md` § Where Things Happen.

Pillar **Verify** · Scope **web** · FINDINGS F-TPL-03

#### L-56 · Every interactive surface gets a latency-feedback tier in the spec, judged on a real network

**Rule.** v2's web home carries the feedback tiers: A1 optimistic, A2 optimistic + retry + banner, B
threshold spinner, C route loading, D CSS-only. Specs map each interactive surface to one. Tier C
also covers client-side fetches inside a page, and the route skeleton matches the in-page skeleton.
Loading behaviour is judged on a throttled connection or a real device. For A2 surfaces,
verification forces the network call to fail and asserts that the retry or undo affordance is
clickable (Playwright `click({trial:true})`), not just visible.

**Why.** It recurred 4 times in lalista:

- The framework was soaked in PR 49.
- In PR 61, a settings page fetched in `useEffect` and "sat empty after `loading.tsx` cleared" on a
  real iPhone, invisible locally at < 50 ms.
- Two mismatched skeletons gave a visible "snap".
- In PR 49 an overlay covered the Undo button while the failure banner showed. The happy-path QA walk
  couldn't see it; slow-job CI caught it only after merge.

It has been seen in one project only; re-check in W10.3.2.

Sources: `kit/docs/guide/latency-feedback.md`, `pre-ship/SKILL.md` § Fault-injection sub-step.

Pillar **Build** · Scope **web**

#### L-72 · Every interactive control has a full state contract: looks tappable, reacts at once, shows work, restores on failure

**Rule.** Owner requirement for every v2 UI. Each button, link or other control:

1. **Looks tappable.** It has a clear affordance, so a control never reads as plain text.
2. **Responds to hover** (where there is hover) with a slight change.
3. **Shows the press immediately**, within one frame, with a clear pressed state. On touch there is
   no tap delay (`touch-action: manipulation`), and the pressed state comes from one global,
   low-specificity rule that components inherit, with an opt-out.
4. **Shows that work is in progress** once the action outlasts a threshold, typically a backend
   round-trip. The control disables at once ("I heard you"); a spinner or processing state appears
   only after the threshold (v1 used 250 ms), so fast actions don't flicker.
5. **Restores on failure** where that applies: optimistic changes roll back, the control becomes
   usable again, and the error is shown (L-56 tiers A1/A2/B).

The reviewer's design lens checks each new control against these five states.

**Why.** Owner requirement (2026-10-11, PR 47 review). The v1 evidence:

- lalista's polish bundle (2026-05-13): without a press cue on iOS PWAs, users assumed the app had
  frozen, or tapped twice. A global `:active` scale + brightness rule fixed it but never reached
  the template.
- lalista PR 49 built the threshold spinner and rollback tiers (L-56), and its Undo failure path
  was blocked by an overlay.

Sources: `kit/TODOS.md` ("Port the `tap-feedback` press-state contract"),
`kit/docs/guide/latency-feedback.md` § Decision rule.

Pillar **Build** · Scope **web** (the contract applies to any UI, native included; the CSS mechanism
is web)

### Next.js

#### L-57 · Build CSP sources from the configured backend origin, for every scheme

**Rule.** v2's Next.js home derives CSP `connect-src` (http→ws, https→wss), `img-src` and
`media-src` from one trimmed backend origin, and tests both the local (http) and production
(https) shapes. A bare `https:` token is not enough.

**Why.**

- `^https://` was a no-op on the local `http://` URL, so the realtime WebSocket was silently
  CSP-blocked (lalista PR 26).
- Storage images rendered blank until a later fix added `img-src` (template-csp-img-src). A missed
  origin "fails silently (blank `<img>`)".

Sources: `kit/docs/guide/supabase-ssr-boilerplate.md` § Pattern 2, `kit/docs/guide/conventions.md` §
CSP, `BUILD-LOG.md` § template-csp-img-src.

Pillar **Build** · Scope **Next.js** (+ Supabase)

#### L-69 · Env values are trimmed and validated where they are read, and checked when they are set

**Rule.** v2's Next.js home trims and validates every `NEXT_PUBLIC_*` and server env value at its
read site, with a unit test that feeds in whitespace-contaminated values. Setting a value (in
Vercel or in setup) checks its shape (no whitespace or newline, URL form), so a bad paste fails at
setup, not in production.

**Why.** Nasty single incident: lalista PR 26. A pasted trailing newline in the backend URL setting
had been there "since project setup". Production `/` returned 500 on the server-side `getUser()`,
and the `%0A` leaked into the CSP header too. It went unnoticed because every flow started at
sign-in, until the pre-merge probe (L-33) found it.

Sources: `kit/docs/guide/supabase-ssr-boilerplate.md` § Pattern 1, `go-live/SKILL.md` § Step 1.5.

Pillar **Build** · Scope **Next.js + Vercel**

#### L-70 · Auth middleware never gates public assets, and email changes are checked in a real mail client

**Rule.** v2's Next.js home ships a middleware matcher that excludes public static assets, with a
check that flags any file under `public/` the matcher would send to the login page. Any change to
transactional email (templates, logos, links) needs evidence from a real sent email opened in a
real client; browser rendering of the template is not enough.

**Why.** Two email-asset bites in lalista:

- PR 45 (2026-05-05): the matcher sent Gmail's image proxy the login page, so the logos in
  confirmation and recovery emails showed as broken for ~24 h in production. The framework's
  default matcher example has the same gap.
- PR 43: branded templates passed code and browser review, and the broken inline logo went unseen
  until a cutover smoke test.

Source: `kit/TODOS.md` ("Pre-ship gate: middleware-matcher public-asset coverage check",
"Email-template visual-QA gate / convention").

Pillar **Verify** · Scope **Next.js** (email check: web)

### Supabase

#### L-58 · Migrations are written for production's shape

**Rule.** v2's Supabase home requires:

- an explicit `GRANT` in every `CREATE TABLE` migration;
- table-qualified columns in `returns table (...)` plpgsql;
- enum changes by rename→recreate→recast→drop, never `ALTER TYPE … ADD VALUE`, with dependent
  functions dropped and recreated;
- a test that INSERTs any new enum value.

A read-only check after deploy confirms grants on new tables (L-24).

**Why.** Three home-os production-only failures:

- a prod-only `42501`;
- `42702` returning 500 on every triage click;
- `22P02` from an enum value that "applied" but wasn't there.

The enum trap bit twice (PR 15, and migration 011 where `drop type` failed on 3 RPCs). Supabase
requires explicit grants on new tables from 2026-10-30.

Source: `kit/docs/guide/migrations.md` (sections as in L-24, plus § Upcoming: explicit GRANTs required).

Pillar **Build** · Scope **Supabase**

#### L-59 · Every migration has a CI-tested rollback or an explicit noop

**Rule.** In v2's Supabase home, every migration declares a rollback block (an explicit `noop`
only when there is nothing to undo). CI round-trips each one against real Postgres (rollback,
then forward again) and fails on a missing or malformed block instead of skipping it. Owner call
(2026-10-11, PR 47): keep rollbacks, and test them.

**Why.** 4 home-os PRs:

- PRs 26 and 27 had rollback bugs invisible to forward-only resets, found ~10 min into CI.
- PR 28: a migration with no marker was skipped silently and caused the 6-attempt, ~2.5 h loop.
- PR 35: prose inside a rollback block was a SQL syntax error.

The four cross-migration FK patterns each "surfaced by a real rollback failure".

Sources: `BUILD-LOG.md` § ak-pre-ship-migration-rollback-gate, § ci-rollback-explain-marker-loud, §
rollback-prose-lint, `kit/docs/guide/migrations.md` § Cross-migration FK rollback patterns.

Pillar **Verify** · Scope **Supabase** · FINDINGS F-STACK-01

#### L-60 · Check `error` before `data` on every PostgREST call

**Rule.** v2's Supabase home requires every query to check `error` before using `data`, through a
throwing helper or an inline check. Generated types are not a safety net.

**Why.** lalista PR 49 hit it twice: a typo'd column and an unmapped FK each showed up as a generic
null dereference in Playwright, with the real error swallowed. It was called lalista's "most-hit
gotcha class".

Sources: `kit/docs/guide/database-queries.md`, `BUILD-LOG.md` § postgrest-null-and-tier-a2-retry-docs.

Pillar **Build** · Scope **Supabase**

#### L-61 · Hosted config that doesn't deploy with the merge is an explicit deploy item

**Rule.** v2's Supabase home lists every deploy surface: app, migrations, functions, auth config,
email templates, redirect allow-list, asset reachability. `config.toml` auth settings apply only
locally, so a change to any surface that doesn't auto-deploy becomes a required deploy item (L-34)
and is checked in production. It is never assumed live.

**Why.** It recurs at every ship: email templates, the allow-list and asset reachability are "the
recurring set" of manual pastes (lalista chapter 1l). Go-live had to block on them.

Sources: `kit/ROADMAP.md` § /ak-go-live post-merge prod-config sync (Arm B), `go-live/SKILL.md` §
Step 1.7.

Pillar **Ship** · Scope **Supabase**

#### L-62 · CI runs against a fresh local stack that it retries, with test helpers that refuse hosted

**Rule.** v2's Supabase CI starts a fresh local stack inside the runner with the published sandbox
keys, and retries the start and health check. Admin and anon test helpers refuse non-local URLs
(L-38). The template carries the slow-job fixes earned in both projects.

**Why.** The slow-job template holds "seven battle-earned fixes" from the lalista and home-os
rollouts:

- an edge-runtime cold-start retry (lalista PR 26);
- job-level `env:` shadowing `$GITHUB_ENV`;
- quote-stripping of `supabase status -o env`;
- and more.

`auth.admin.listUsers()` returned 500 intermittently in CI.

Sources: `kit/docs/guide/ops.md` § Where Things Happen, `kit/docs/guide/supabase-ssr-boilerplate.md` §
Pattern 3.

Pillar **Verify** · Scope **Supabase**

#### L-63 · Realtime tables are added to the publication explicitly, and realtime failure is tested with a real socket close

**Rule.** v2's Supabase home requires a migration that adds each realtime table to the publication,
and a two-session E2E proving events arrive. Failure UI is tested with `routeWebSocket(… ws.close())`
installed **before** navigation, never with an HTTP 503 fulfil. The "socket dies mid-session" case
is a manual smoke test.

**Why.**

- The CLI's publication stopped including the table, and subscribers "stay connected but never
  receive" (lalista PR 26).
- The 503 shape was swallowed by the client's retry, and the test stayed skipped for a PR cycle
  (lalista PR 26/27).
- `routeWebSocket` installed after the first subscribe tests nothing: the client reuses one socket,
  and the spec failed deterministically on two CI runs (lalista PR 65).

Sources: `kit/docs/guide/supabase-ssr-boilerplate.md` § Pattern 4, § Pattern 6, `tests-review/SKILL.md`
§ routeWebSocket after initial subscribe is a dead test.

Pillar **Verify** · Scope **Supabase**

#### L-64 · Auth changes are verified across a user-state matrix and both confirmation modes

**Rule.** v2 verifies auth-touching changes across these states, set up through the admin API:

- unconfirmed sign-up;
- wrong password;
- rate-limited sign-up;
- sign-up with an existing email;
- session expiry mid-flow.

The local stack auto-confirms while production confirms, so sign-up code also gets a unit test for
production's no-enumeration shape (`identities: []`, null session).

**Why.**

- Signing up with an already-confirmed email fell into a misleading "check your email" state
  (lalista `31b5637`, `e1ceb9c`).
- lalista PR 10's QA walked only the admin happy path while unconfirmed sign-up bounced silently.
- Two guides recorded the same local-vs-production split.

Sources: `pre-ship/SKILL.md` § User-state matrix, `kit/docs/guide/conventions.md` § Supabase auth E2E
patterns, `kit/docs/guide/testing.md` § Pattern 2.

Pillar **Verify** · Scope **Supabase**

#### L-68 · Every client write has an RLS policy for that operation, checked in CI

**Rule.** v2's Supabase home checks deterministically in CI that every client-side
insert/update/delete/upsert on an RLS-enabled table has a matching `CREATE POLICY` for that
operation.

**Why.** Nasty single incident: lalista PR 5. The items table had RLS on but no insert policy, so
writes returned success while storing nothing. Unit tests and the security review both missed it.

Source: `pre-ship/SKILL.md` § Gate rls-coverage.

Pillar **Verify** · Scope **Supabase** · FINDINGS F-STACK-01

#### L-71 · Auth defaults are hardened at project setup and read back

**Rule.** v2's Supabase setup sets the auth `site_url` to production, a minimal redirect
allow-list (production plus localhost, no wildcards by default) and a password minimum of at least 8. It reads the values back for the owner to confirm.

**Why.** Nasty single incident: lalista (2026-04-20). With the free-tier default `site_url` of
localhost, "every email-based auth flow … silently breaks" when the link comes from a real inbox.
The minimal allow-list fixed it.

Source: `new-project/SKILL.md` § Step 17b: Harden Supabase auth defaults.

Pillar **Environments** · Scope **Supabase**

---

## Considered, not carried

One line each: rule — source — reason.

**Dropped with v1's machinery** (where a principle survives, it is carried in the lesson named)

- Firewall IP rotation, ipset refresh, artifact-host allowlist, HTTP-000 Mode A/B/C — `CLAUDE.md` §
  Known Footguns, `go-live/SKILL.md` § Step 1.5 — devcontainer firewall dropped. The principle is in L-33 and L-09.
- Virtiofs phantom rebase and corrupted index, `checkStat` retry — `CLAUDE.md` § Known Footguns,
  `kit/FRICTION-LOG.md` § Interrupted `git commit` on virtiofs — the macOS bind mount is gone.
- Husky/lint-staged hooks, clean-tree and stash guards, `dirtyTreeReason`, branch-not-main hook,
  `$CLAUDECODE` guard — `kit/docs/guide/hooks.md` § Commit Flow — replaced by GitHub enforcement. Principle in L-36 and L-41.
- Root-owned locked files, `sudo install` recipe, deny-glob tuning, memory-write hook —
  `kit/docs/guide/security.md` § Authoring locked files — in-session locks erode. Principle in L-36.
- `/devshop` bind mount, symlinked kit, `exec bash` forwarders, `[ -e ]` symlink tests, worktree
  `pnpm install` step — `kit/docs/guide/architecture.md` § Known gotchas — v2 uses a pinned install.
  Principle in L-42 and L-50.
- Only `~/.claude` persists; set opt-outs via `containerEnv` — `CLAUDE.md` § Known Footguns — a
  devcontainer volume detail. The cloud setup script is declarative.
- Compose-isolated local Supabase, socket relay, port-offset registry, Docker Desktop hardening —
  `kit/docs/guide/local-supabase-compose-isolation.md`, `macos-host-setup.md`, `ops.md` "Port rebinding" —
  cloud sessions are per-session. The Mac setup is re-derived at L3 Environments.
- Browse binary and Chromium cache autoheal, `capture-screenshot.sh`, gstack state split-brain —
  `kit/docs/guide/ops.md` § Troubleshooting — vendored-gstack and devcontainer wrappers.
- ntfy push with debounce — `kit/docs/guide/notifications.md` — the cloud app pushes natively.
- Local squash-merge, worktree teardown, rename detection, bypass trailers through squash —
  `merge-devshop/SKILL.md` — merges happen on GitHub (L-32).
- `release.sh`, PROPAGATION.md generation, disposition-tag regex — `release-devshop/SKILL.md`,
  `kit/FRICTION-LOG.md` § PROPAGATION.md disposition-tag filter — release tooling is replaced. Principle in L-49.
- Gitleaks compensating gate at squash time — `merge-devshop/SKILL.md` § Phase 2 — scanning moves to CI (L-40).
- Clean tree before `gh pr merge --delete-branch` — `go-live/SKILL.md` § Step 2.0 — the owner merges on GitHub.
- Fine-grained PAT lacks Checks, so watch through the Actions API — `build/SKILL.md` § 5.2 — a
  credential quirk. The real lesson is L-13.

**Bypass and gate machinery v2 removes** (TARGET Verify: no "skip with a reason")

- 11 reason-review types (`blockedGateOverride`, `dismissalLog`, `localTestSkipReason`,
  `prTextHygieneReason`, `coreUserStoryNaReason` …), dismissal log, `[bypass-revisit]` —
  `kit/docs/guide/hooks.md`, `conventions.md` § Bypass trailers — bypasses are deleted. Lessons in L-09, L-12 and L-21.
- Mandatory `blocked (n/a per scope)` encoding — `pre-ship/SKILL.md` — it halted every non-UI PR
  (F-PIPE-06). L-09 uses path facts instead.
- File-pairing test-presence and docs-coverage hooks — `conventions.md` § Test Presence — replaced
  by behaviour coverage (L-17).
- CLAUDE.md LLM classification gate, write-time doc router — `claude-md.md` § Enforcement — too much
  machinery (F-DOC-05). The budget is kept (L-48).
- Per-check model routing, convention inlining map — `hooks.md` § Per-check-type model routing —
  there is a single v2 reviewer.
- Run the full 19-gate pipeline unconditionally — `build/SKILL.md` § Non-negotiable — replaced by
  sizing at intake (L-02).
- Headline forbidden-vocabulary lint — `build/SKILL.md` § 0.2.6 — the implementation was buggy
  (F-PIPE-01/04) and the reviewer judges tone.
- `# pins:` annotations for prose-grep tests — `conventions.md` § Kit Testing — patches a style L-16 forbids.
- Persona-axis gates, Finding Router, reviewer phases 5/6, self-correcting auto-actions —
  `kit/ROADMAP.md` — unbuilt, no incident.

**One mild incident, never fired again** (project rules marked ↻ get re-checked in W10.3.2)

- ↻ Spec renders a shown/hidden table for conditional UI (lalista PR 5, two bugs in one PR) — `spec/SKILL.md` § Render conditions — a visible UI glitch, caught before release.
- ↻ Auth redirects from the request Host header (home-os PR 15) — `supabase-ssr-boilerplate.md` § Pattern 10 — hit local and CI runs only (`127.0.0.1` vs `localhost`), not users.
- ↻ Page-level `getUser()` before RLS queries, since the layout guard races (home-os triage route) — § Pattern 11 — a 404 instead of the login page on a cold load.
- ↻ Shared primitives don't bake in sizes callers override (lalista `LoadingArea`) — `latency-feedback.md` — cosmetic.
- Stack guidance always loads the baseline on top of routed sections (one regression, 2026-05-11)
  — `kit/docs/guide/workflow.md` § Devshop Skill Map — input to the Reach L3 design, not a lesson.
- Owner's manual-review list holds only judgement calls (lalista PR 27) — `build/SKILL.md` § What
  belongs in "Manual review" — TARGET Review already implies it.
- Preview readiness from the platform, not curl (lalista PR 18) — `build/SKILL.md` § Phase 6 — folded into L-28.
- Fold bookkeeping into the ship push to save a CI cycle — `build/SKILL.md` § 4.0 — a cost tweak with no incident.
- Feature-keyed `/tmp` commit-message files — `check-docs-and-tests/SKILL.md` § Step 5 — v2 has no inter-skill relays.
- Spec-dir name collides with a shipped feature — `kit/FRICTION-LOG.md` § `/ak-build` Step 0 — v1 resume mechanics.
- DCG blocks destructive strings inside heredocs — `kit/FRICTION-LOG.md` § DCG blocks — tool-specific.
- `git ls-remote` with a token URL garbles output — `kit/FRICTION-LOG.md` — v2 uses its own identity through `gh`.
- `verification.log` swallowed by `*.log` gitignore — `kit/FRICTION-LOG.md` § Phase 2.5 — per-feature gate artifacts are dropped (L-54).
- Operator stash vanish root cause — `kit/FRICTION-LOG.md` — count 1, cause unknown. The prevention is folded into L-41.

**No incident behind it** (reasoned rules; candidates for stack homes if v2 hits them)

- Stop-and-ask category list — `CLAUDE.md` § Confidence Calibration — re-derive at L3 Intent.
- Non-negotiables with no recorded bite (responsive 375–2560, light/dark, 3-line file headers,
  metrics per feature, TS-source packages, no ESLint formatting) — `CLAUDE.md` § Non-Negotiables —
  re-decide at L3 Build/Ship.
- RLS-bypass least-privilege ladder, DB hardening SQL (`search_path`, `(select auth.uid())`, FK
  indexes), two-user RLS test, type-drift check — `security.md`, `conventions.md` § Non-Negotiables —
  Supabase home candidates. Prefer the upstream advisor over a custom probe.
- Migration sequencing pre-flight (expand/contract vs a parallel deploy) — `go-live/SKILL.md` §
  Step 1.6, `kit/ROADMAP.md` § Migration sequencing — the roadmap entry itself asks whether it ever fired.
- `ON DELETE` on `auth.users` FKs, PostgREST two-query hydration, seed.sql gotrue columns,
  load-bearing SQL sentinels, DB-constraint backstops — `migrations.md`, `database-queries.md`.
- Date handling as `YYYY-MM-DD` strings — `date-handling.md` — implementation notes.
- Tailwind v4 `@source` and arbitrary sizing values — `tailwind.md` — verified once, no bite.
- PWA rules and a service-worker baseline — `ops.md` § PWA, `kit/ROADMAP.md`.
- Vercel 4096-byte env cap, `vercel env add` quirk — `ops.md`, `new-project/SKILL.md` — recipes, not rules.
- Pre-migration `pg_dump`, rollback checkpoint recording — `ops.md` § When Things Go Wrong — TARGET Ship already has "revert ready".
- JIT DB password for prod migrations — `kit/ROADMAP.md` — "no incident forcing it", and superseded by no prod secrets.
- Playwright video recording — `kit/ROADMAP.md` — not needed in > 78 PRs.
- Keepalive pings against auto-pause — `BUILD-LOG.md` § keepalive-supabase-ping — no bite recorded.
- Routing every discovery to one of 5 trackers — `CLAUDE.md` § TODO Protocol — v2 tracker design is
  D-15. The ledger rule is L-35.
- Subagent drift instrumentation — `kit/FRICTION-LOG.md` — no data was ever collected.

---

## Sources and coverage

| Source (at `v1-final`)                                                                                    | Read           | Yielded                                                                                                                                                                                                                    |
| --------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/docs/guide/` — all 19 guides + README                                                                | in full        | L-03 L-04 L-06 L-07 L-09–L-12 L-14 L-19 L-23 L-24 L-26 L-27 L-31 L-33 L-34 L-36 L-38 L-43–L-45 L-48–L-51 L-53 L-55–L-60 L-62–L-65 L-69; no lessons from `macos-host-setup`, `notifications`, `date-handling` (not carried) |
| `CLAUDE.md` — Known Footguns (15), Non-Negotiables, Implementation Approach, TODO/close-out, text style   | in full        | carried: 6 footguns, as principle (L-28 L-36 L-37 L-38 L-41 L-52); 9 dropped as mechanism (listed above)                                                                                                                   |
| `kit/FRICTION-LOG.md` — 26 entries                                                                        | in full        | L-04 L-05 L-08 L-14 L-21 L-28 L-32 L-35 L-36 L-41 L-53; the rest not carried                                                                                                                                               |
| `kit/TODOS.md`                                                                                            | in full        | L-16 L-34 L-36 L-42 L-45 L-50 L-66 L-67 L-70 L-72                                                                                                                                                                          |
| `kit/ROADMAP.md`                                                                                          | in full        | L-20 L-29 L-34 L-42 L-45 L-54 L-61; most entries are unbuilt ideas (not carried). Identifiers: placeholders only                                                                                                           |
| `kit/docs/CHANGELOG.md`                                                                                   | in full        | L-09 L-11 L-15 L-20 L-33 L-41 L-46 L-47                                                                                                                                                                                    |
| `BUILD-LOG.md` (`template/BUILD-LOG.md` is an empty stub)                                                 | in full        | L-02 L-06 L-11 L-12 L-15 L-16 L-22 L-23 L-28 L-30 L-32 L-38 L-40–L-42 L-48 L-49 L-53 L-54 L-57 L-59 L-60                                                                                                                   |
| `.claude/skills/devshop/**` (17 skills), `.claude/commands/**` — incident notes only; `gstack/**` skipped | grep + context | L-01 L-03 L-05 L-06 L-09 L-10 L-12 L-13 L-17–L-22 L-25 L-28–L-33 L-35 L-39 L-42 L-47 L-50 L-52 L-63 L-64 L-68 L-69 L-71                                                                                                    |
| Code cited by skills (`extract-prod-url.sh` + bats, `slow-job-lifecycle-check.sh`, notes)                 | targeted       | L-01 L-47                                                                                                                                                                                                                  |

**Size check.** This file is ~11k words (72 lessons plus the not-carried list), mined from ~90k
words of v1 skills, ~70k words of guides and ~64k words of trackers, changelog and logs. The by-stack lessons
are the seed for the stack homes (M2). Nothing here is loaded at runtime.
