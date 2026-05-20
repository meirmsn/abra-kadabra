---
name: ak-spec
version: 2.2.0
description: |
  Convert the latest gstack plan into an implementation-ready spec.
  Run after /autoplan (and optionally /design-shotgun + /design-html) has locked
  in architecture, edge cases, and design direction.
  Use when asked to "write the spec", "create a spec", or "prepare for implementation". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Spec

Convert the latest gstack plan into an implementation-ready spec.

Run after `/autoplan` (and optionally `/design-shotgun` + `/design-html`) has locked
in architecture, edge cases, and design direction.

## Step 1: Check METRICS.md

- If `METRICS.md` does not exist AND this is the first feature (no `apps/`, `packages/` with code):
  - Read the gstack plan output
  - Draft an initial event taxonomy following the metrics principles in `kit/docs/guide/ § Metrics Lifecycle`
  - Present to user: "Here's the initial metrics taxonomy I derived from the plan — confirm, adjust, or add events before I continue"
  - **Stop and wait for confirmation** (new metric event definitions require review)
  - Write `METRICS.md` with confirmed events using the structure in `kit/docs/guide/ § Metrics Lifecycle`
- If `METRICS.md` does not exist AND this is NOT the first feature:
  - Error: "METRICS.md not found — create it before running /ak-spec. See kit/docs/guide/ new-project checklist."
  - Stop.
- If `METRICS.md` exists: continue.

## Step 1.5: Consult routing index

After Step 1 and before reading the gstack plan sources (Step 2), consult the
devshop routing index at `kit/docs/guide/README.md`. The index is keyed by
trigger signals — file-globs touched, keywords in the spec's tentative
Decisions, primitive imports — and points at the guide sections (`(file, anchor)`
tuples, skill invocations, or full-file pointers per spec D4) that govern those
patterns. The goal is to encode the matched gotchas as explicit Decisions in
the new spec, so the implementer reads a spec that already names the rule
instead of discovering it mid-task.

**Heuristic**: forgiving by design. The spec's `## Files` section is the
author's best guess at implementation surface — actual implementation often
touches different files. File-globs match better than exact paths, and
keyword matches against the Decisions block catch concept-touched-via-different-path
cases. Don't tighten the heuristic; false-positive guidance is cheap, missed
guidance is expensive.

```bash
# Resolve the latest gstack plan dir (same probe Step 2 uses, hoisted up).
GSTACK_PROJECT_DIR=$(ls -d .gstack/projects/*/ 2>/dev/null | head -1)
DESIGN_DOC=$(ls -t "$GSTACK_PROJECT_DIR"*-design-*.md 2>/dev/null | head -1)
TEST_PLAN=$(ls -t "$GSTACK_PROJECT_DIR"*-test-plan-*.md 2>/dev/null | head -1)

# Build the lookup corpus: file-glob tokens + keyword tokens drawn from the
# gstack plan. We're parsing prose, not structured fields, so be liberal —
# every plausible token that could match a routing-row trigger goes in.
ROUTING_INDEX="kit/docs/guide/README.md"
[ -f "$ROUTING_INDEX" ] || { echo "No routing index at $ROUTING_INDEX — fallback: read conventions.md directly."; }

# 1. File-globs the plan hints at (apps/web/**, supabase/migrations/**, etc.).
#    Pull from any code-fenced glob, any path-like literal.
GLOB_TOKENS=$(grep -oE '`(apps|packages|supabase|\.github|\.devcontainer|\.claude|\.husky|kit)/[A-Za-z0-9_./*-]+' \
  "$DESIGN_DOC" "$TEST_PLAN" 2>/dev/null | sort -u)

# 2. Keyword tokens — distinctive nouns/phrases the routing-row Notes name
#    (RLS, PostgREST, realtime, PWA, Zod, optimistic mutation, latency, etc.).
KEYWORD_TOKENS=$(grep -oE '\b(RLS|PostgREST|realtime|PWA|Zod|optimistic mutation|input zoom|CSP|edge function|migration|auth\.users|Realtime|standalone|iOS|WebKit|latency|skeleton|loading\.tsx|useEffect|Tier A|Tier B|Tier C)\b' \
  "$DESIGN_DOC" "$TEST_PLAN" 2>/dev/null | sort -u)

# 3. For each (glob, keyword) token, find routing rows whose Trigger column
#    references it. Routing rows are markdown table rows under the grouped
#    `### Data` / `### Auth + security` / etc. headers — match by row content.
echo "=== Routing rows triggered by this spec's surface ==="
for tok in $GLOB_TOKENS $KEYWORD_TOKENS; do
  grep -F "$tok" "$ROUTING_INDEX" | grep -E '^\|' || true
done | sort -u

# 4. Read the matched rows' `(file, anchor)` targets — the canonical guide
#    sections to inline-cite in the new spec's Decisions block.
```

**Encoding the matches as Decisions**: when a routing-row fires, add a row to
the new spec's `## Decisions` section with an explicit citation:

```markdown
### D<N>: <one-line decision>

**Decision:** <what to do>

**Rationale:** <why> (per `kit/docs/guide/<file>.md § <section>`)
```

The `per kit/docs/guide/<file>.md § <section>` citation is load-bearing — it's
the audit trail that lets a reviewer (or `/ak-pre-ship`) verify the spec
followed the routing-system contract.

**Baseline pairing**: the routing index is **additive on top of**
`kit/docs/guide/conventions.md`, not a replacement for it. Conventions.md
carries the cross-cutting non-negotiables (Test Presence, Non-Negotiables,
Bypass trailers, Project Docs Coverage, Backlog Routing, Confidence
Calibration) that fire on every PR regardless of topic — the spec author
should read it to know which baseline gotchas always apply, then layer the
routing-matched gotchas on top. The two layers are complementary, not
alternatives. **Pre-adoption projects** (whose `kit/docs/guide/README.md`
isn't yet a routing index) get the baseline only — equivalent to the
pre-routing behavior, with zero regression.

## Step 2: Discover and read the gstack plan sources

Find the gstack project dir and read all relevant plan artifacts. No pointer file required — artifacts are discovered directly by filename pattern:

```bash
# Single gstack project per repo
GSTACK_PROJECT_DIR=$(ls -d .gstack/projects/*/ 2>/dev/null | head -1)
[ -z "$GSTACK_PROJECT_DIR" ] && { echo "No gstack project found under .gstack/projects/. Run /office-hours + /autoplan first."; exit 1; }

# Newest design + test plan (gstack produces timestamped snapshots — latest by mtime)
DESIGN_DOC=$(ls -t "$GSTACK_PROJECT_DIR"*-design-*.md 2>/dev/null | head -1)
TEST_PLAN=$(ls -t "$GSTACK_PROJECT_DIR"*-test-plan-*.md 2>/dev/null | head -1)

# Required
[ -z "$DESIGN_DOC" ] && { echo "No design doc in $GSTACK_PROJECT_DIR — run /office-hours."; exit 1; }
[ -z "$TEST_PLAN" ]  && { echo "No test plan in $GSTACK_PROJECT_DIR — run /plan-eng-review."; exit 1; }

# Optional — present if /autoplan ran the CEO review and/or UI flows touched design-html
CEO_PLAN=$(ls -t "$GSTACK_PROJECT_DIR"ceo-plans/*.md 2>/dev/null | head -1)
DESIGN_HTML=$(ls -t "$GSTACK_PROJECT_DIR"design-html/*.html 2>/dev/null | head -1)
```

Read every source that's present:

```bash
cat "$DESIGN_DOC"
cat "$TEST_PLAN"
[ -n "$CEO_PLAN" ]    && cat "$CEO_PLAN"
[ -f DESIGN.md ]      && cat DESIGN.md                       # root-level design system (UI features)
[ -n "$DESIGN_HTML" ] && cat "$DESIGN_HTML"                  # UI reference from /design-html
[ -f PLAN.md ]        && cat PLAN.md                         # Active + Planned rows (this feature's Notes has scope pointer)
[ -f PRODUCT-ROADMAP.md ] && cat PRODUCT-ROADMAP.md          # detailed scope per section the PLAN.md row points at
```

The `PLAN.md` row for this feature (in `## Planned`) typically names the source section in `PRODUCT-ROADMAP.md` — follow that pointer for full scope detail. If there's no PLAN.md row yet for this feature, the run is kickstarting one.

## Step 3: Ensure feature branch

Derive the feature name from the gstack plan slug (`.gstack/projects/<slug>/`), then
make sure we're on a dedicated branch for it. Main/master is PR-only — a PreToolUse
hook blocks commits on main, but we should create the branch here, not wait for the
hook to trip later.

```bash
PLAN_SLUG=$(ls -1 .gstack/projects/ 2>/dev/null | head -1)
BRANCH=$(git branch --show-current)

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  # Not on a feature branch — create one from the plan slug.
  # Pick prefix from the plan's nature: feat for new functionality, fix for bug fixes.
  # Default to feat unless the plan name or content clearly indicates a bug fix.
  [ -z "$PLAN_SLUG" ] && { echo "No gstack plan found and not on a feature branch — ask the user for a feature name before continuing."; exit 1; }
  git checkout -b "feat/$PLAN_SLUG"    # or fix/<slug> if the plan is a bug fix
  FEATURE="$PLAN_SLUG"
else
  # Already on a feature branch — trust it.
  FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||;s|^docs/||;s|^chore/||')
fi

FEATURE_DIR="specs/$FEATURE"
```

## Step 4: Flip PLAN.md row from Planned → Active

`PLAN.md` is the single source of truth for planned + active features. `/ak-implement` resolves the active spec via `PLAN.md § Active`; `/ak-status` surfaces both sections; `/ak-build` Phase 4.0 removes the Active row and appends a full entry to `BUILD-LOG.md` on the feature branch before `/ship` pushes (Phase 5.6 is a verify-only fallback); `/ak-go-live` Step 2b sanity-checks that the close-out ran.

If `PLAN.md` doesn't exist, create it from `/devshop/template/PLAN.md`.

Find the row in `PLAN.md § Planned` whose Feature cell matches `$FEATURE`:

- **Row exists**: move it from `## Planned` to `## Active` with this format, preserving the Hook content:

  ```markdown
  | feat/$FEATURE | specs/$FEATURE/spec.md | <Hook from the Planned row> |
  ```

  Planned rows are sorted by Leverage descending and identified by Feature slug — no row numbers to renumber.

- **Row doesn't exist** (feature kickstarted without a prior Planned entry): add a new row directly to `## Active`. Ask the user for a one-line Notes pointer identifying the scope source (e.g. `PRODUCT-ROADMAP.md § v0 § Xa`, or a gstack plan section reference).

Multiple rows may live in `## Active` at once — parallel feature work is supported. Git log on PLAN.md captures the transition date and any rationale from the commit message.

## Step 5: Judge completeness

The plan is ready to implement directly if it specifies **all** of:

- Every user-facing behavior including error states
- Exact data model changes (schema diffs, not prose)
- API contracts (endpoints, inputs, outputs, auth requirements)
- Service dependencies
- Explicit out-of-scope items

**If complete**: write `$FEATURE_DIR/spec.md` noting the plan is the spec:

```
# Spec: <FEATURE>
The gstack plan is the spec. See .gstack/projects/<slug>/<plan-file>.md
```

**If gaps exist**: continue to Step 6.

## Step 6: Write the spec

Create `$FEATURE_DIR/` and write `$FEATURE_DIR/spec.md`. The first 3 lines
must be machine-parseable provenance so that `/ak-implement` can trace the full
context chain:

```
<!-- gstack-plan: .gstack/projects/<slug>/<plan-file>.md -->
<!-- generated-by: /devshop:spec -->
<!-- date: YYYY-MM-DD -->
```

Then fill only the gaps the gstack plan left — the missing detail only, not a rewrite:

- **`## Product update`** (REQUIRED — see below) — two named sub-sections `### Headline (user-facing)` and `### Detail (team-facing)` that carry the canonical product story for this PR. Single source-of-truth for the PR body's `## Product update` section, BUILD-LOG `Headline:` + `Summary:` fields, `/ak-build` Phase 7 ready-for-review comment, and `/ak-go-live` Step 6 deployed-to-prod comment. Authored here at Phase 0; verified against the diff at `/ak-build` Phase 6 Gate A.
- **`## Core user story`** (REQUIRED — see below) — 2–4 imperative verbs, one per line, describing the product's primary observable flow end-to-end. `/ak-pre-ship` Gate 9 (qa-walk) enforces that every verb in this section produces a verifiable artifact.
- User-facing behaviors not yet specified (happy path + all error states)
- **`## Render conditions`** (REQUIRED for any feature introducing or modifying a UI element with conditional visibility — see below). One row per element, every state combination resolved to `shown` / `hidden`. Default for an unmentioned combination is implicit `hidden`; never leave the matrix sparse.
- Data model changes (exact schema diffs)
- API contracts (endpoints, inputs, outputs, auth)
- Service dependencies
- Explicit out-of-scope items
- **Offline behavior**: every feature with remote data must declare: (a) online-only with error state, (b) read-only cache, (c) full offline with sync. Default to (a) unless explicitly upgraded.
- **Metrics** section — reference specific events from `METRICS.md` that this feature touches (existing events to instrument + new events to define)

Do not rewrite what the plan already said. If something is genuinely ambiguous after
reading the full plan, ask. Otherwise fill the gap from what the plan implies.
No decision Q&A — architecture decisions were made by `/autoplan`'s eng review.

### Core user story (required — Gate 9 enforces via artifact assertion)

Every spec MUST include a `## Core user story` section: **2–4 imperative verbs, one per
line, describing the product's primary observable flow end-to-end.** This is the
contract `/ak-pre-ship` Gate 9 uses to enforce thorough QA — for every verb, the
qa-walk must produce a verifiable artifact (screenshot, DOM assertion, or state
capture) proving the action completed. Missing / empty / unchanged artifact → Gate 9
`blocked`. No `pass` is possible without artifact proof per verb.

The rule addresses a specific failure mode: the lalista core-flows PR shipped with a
qa-walk trace reading "add-sheet **open+Escape**" — `/qa` opened the add-item sheet,
hit Escape, and moved on without completing the core flow. The gate emitted `pass`
because no assertion was broken. The Core user story + artifact requirement makes
"exercised to completion" a verifiable claim, not a narrative one.

**Format**: one `## Core user story` heading, then a numbered list of 2–4 bullets.
Each bullet is one short imperative sentence — the active verb is what gets
checked. Don't editorialize; the section is a contract, not prose.

**Good example** (grocery-list app feature):

```markdown
## Core user story

1. Sign in.
2. Tap FAB, type "milk", submit.
3. See "milk" appear in the list.
4. Tap the buy button on the row.
5. See the row fade out and disappear.
```

Five verbs (sign-in, add, see-added, mark-bought, see-removed). Each produces a
verifiable artifact the qa-walk harness can capture.

**Bad example** (evasive — passes the section but doesn't enforce anything):

```markdown
## Core user story

1. Users can add items to their list and mark them as bought when purchased.
```

One long hedging sentence. No discrete verbs. Don't write this.

**When the feature has no user-facing flow** (e.g., a migration-only PR, an
internal refactor, a docs-only change), the section body may be `N/A — <reason>`.
Example: `N/A — database migration only; no user flow added or modified.`
Gate 9 recognizes `N/A` and skips artifact assertion for that PR. Do NOT omit
the section; declare `N/A` explicitly so the gate knows you considered it.

**Artifact location** `/ak-pre-ship` Gate 9 expects: `specs/<feature>/qa-walk/verb-<N>-<slug>.{png,json}` where `<N>` is the 1-based step number and `<slug>` is a short
filesystem-safe label derived from the verb. Example: `verb-2-add-milk.png`. The
qa-walk harness captures these via the gstack `browse` daemon; see
`/devshop/.claude/skills/devshop/pre-ship/SKILL.md` Gate 9 for the capture contract.

### Render conditions (required when the feature touches conditional UI)

When the feature introduces a new UI element (button, row, sheet, banner, etc.) — or changes the visibility of an existing one — the spec MUST declare a `## Render conditions` section that resolves _every_ state combination to `shown` or `hidden`. This is the contract that prevents add-shown-when-it-shouldn't-be bugs (lalista PR 5 surfaced two: an add-new row visible inside a results sheet that was supposed to show only candidate options, and visible across an empty-list state combination the spec hadn't enumerated).

**Format**: a markdown table. Rows are UI elements; columns are the state combinations enumerated for the surface that contains them. Every cell is `shown` or `hidden` — no blanks, no "depends on …" prose. If a column genuinely doesn't apply (e.g., element doesn't exist on that surface), write `n/a`.

**Good example** (lalista add-item disambig sheet, post-PR-5):

```markdown
## Render conditions — disambig sheet rows

| Element               | empty utterance | 0 candidates + valid utterance | 1+ candidates | error from edge fn |
| --------------------- | --------------- | ------------------------------ | ------------- | ------------------ |
| Candidate option rows | n/a             | hidden                         | shown         | hidden             |
| `+ add as new` row    | hidden          | shown                          | hidden        | hidden             |
| Force-create button   | hidden          | shown                          | hidden        | hidden             |
| Error banner          | hidden          | hidden                         | hidden        | shown              |
```

Four rows × four states × explicit `shown` / `hidden` / `n/a` — the `add-new` row's "hidden when 1+ candidates" cell is the cell that fixed PR 5 Bug #2.

**How to enumerate state columns**: for each surface, list every distinct combination of (input-validity × backend-response × user-action) that produces a meaningfully different UI. Five rows is usually enough; if the surface has more than ~8, decompose by primary state (e.g., one matrix per route param value).

**Why this is mandatory for UI features**: the implementation will inevitably ship at least one `&&`-chain inside JSX whose visibility logic was implicit. If the spec didn't enumerate the matrix, neither did the implementation — the surface bug is downstream of a missing-spec-row, every time. Pre-ship `/qa` happens to catch some, not most. Filling the matrix at spec time is the cheap version of the same checking.

**When to skip**: backend-only PRs, schema-only migrations, refactors that don't change rendered output. If the diff doesn't add or change a `if (…)` / `&& <Element>` / `?:` inside JSX/TSX, the section may be omitted. When in doubt, write the matrix — it's a few minutes; missing one is hours of QA-discovered bugs.

### Product update (required — verified at `/ak-build` Phase 6 Gate A)

Every spec MUST include a `## Product update` section with two sub-sections — `### Headline (user-facing)` and `### Detail (team-facing)`. They carry the canonical product story for this PR. The same blurbs are routed downstream (PR body, BUILD-LOG, Phase 7 ready-for-review comment, `/ak-go-live` Step 6 deployed-to-prod comment, future CHANGELOG aggregation) verbatim — this section is the **single source of truth**, no surface composes its own copy.

The contract serves two distinct audiences, both grounded in the same atomic claims (the verbs + nouns the diff actually shipped):

- **`### Headline (user-facing)`** — 1–2 sentences for the end-user / prospect / changelog reader. Snappy, marketing-grade, **zero eng terms**: no state names, no enum names, no RPC names, no migration numbers, no component PascalCase, no route paths, no cross-PR references. Talks about what the user can now do in plain English.
- **`### Detail (team-facing)`** — 1–4 sentences for the future-me reader / cold reviewer / BUILD-LOG scanner. Light eng context allowed (state names, feature areas, internal nouns — but explained, not jargoned). Builds on Headline with the context the team needs to understand what actually shipped.

**Good example** (decide-state feature):

```markdown
## Product update

### Headline (user-facing)

Pick a path for every issue — get DIY instructions, see what a contractor would charge, set a reminder, or dismiss. Your decision is saved and revisable.

### Detail (team-facing)

After a card is diagnosed, the user can now commit to a path forward (DIY / Contractor / Monitor / Dismiss) and the card transitions to a `planned` state. Choosing Monitor sets a check-back cadence; choosing anything else flips the card to the chosen path with a "Change decision" link to re-open. The AI's cost estimates remain visible alongside any user override.
```

Same atomic claims (commit-to-path, transition-to-planned, change-decision link, cost-estimate visibility), two different verbalizations. Authoring cost is low because Detail flows naturally from Headline; verification cost is shared because both are checked against the same diff at Phase 6.

**Bad example — eng terms leaking into Headline**:

```markdown
### Headline (user-facing)

Adds the `card_state` machine with a `confirm_triage` RPC; users transition from `diagnosed` to `planned` via the new DecideCard component.
```

Six eng-vocabulary leaks (`card_state`, `confirm_triage`, `RPC`, `diagnosed`, `planned`, `DecideCard`) in one sentence. Phase 0 lint flags this; the operator's first edit pass usually strips them.

**Edge cases the contract handles**:

- **Pure infra PR with no user-visible change.** Headline reads `Infrastructure update — no user-visible change in this PR.` (literal, honest). Detail reads `<one-line eng what + why this PR matters internally>.` Same fields, infra-shape. Honest about the audience asymmetry rather than fabricating a marketing voice.
- **Hotfix PR.** Headline: `Fixes <user-visible symptom>.` Detail: `Fixes <symptom> in <user-flow> — root cause was <plain-English summary>.` Same shape, fix-flavored.
- **Multi-feature PR.** Headline names each in one short sentence (bullets allowed within the 1–2 sentence cap; cap may stretch to 3 for two-feature PRs). Detail expands per-feature.
- **Headline = Detail.** If a PR is small enough that the two blurbs would be word-for-word identical, collapse them under a single `### Headline + Detail (combined)` heading. Downstream surfaces route correctly (BUILD-LOG `Headline:` and `Summary:` repeat; deploy comment renders once).

**Why two blurbs instead of one**: a single blurb that tries to serve both audiences either ships eng-flavored copy in the changelog (loses the marketing audience) or ships marketing-flavored copy in the PR body (loses precision for reviewers). Two blurbs share atomic claims, so authoring cost is ~30 seconds at Phase 0 — and the cost of compromise is paid every time someone reads either surface.

**Authoring at Phase 0**: when `/ak-build` Phase 0 runs the spec-skeleton step, it surfaces both blurbs as the first named bullets of the Scope preview so the operator approves them alongside Decisions / Scope / Tracker. The spec agent's first draft tends to over-include eng terms in Headline — operator's first edit pass usually strips them. Same shape as how Decisions are handled today (AI drafts, operator approves or rewrites inline).

**Verification at Phase 6**: `/ak-build` Phase 6 Part D presents both blurbs side-by-side with the diff and asks the operator "does each blurb still describe what shipped?" Yes/edit per blurb. Phase 6 Gate B additionally runs an automated claim-vs-diff cross-check (parses Detail into atomic claims, grep-evidence in diff, flags audience-shape mismatch between Headline and Detail) as an assist for Gate A — warn-not-block. Together they prevent the Phase 0 blurb from silently drifting away from what actually shipped (a polish-loop fix adds a user-visible disclosure; the original blurb didn't call it out).

### Spec-time conventions and decision rows

Several conventions shape what the spec must contain or surface for user sign-off before `/ak-implement` runs. Full text + rationale: `kit/docs/guide/conventions.md`.

- **Confidence calibration** — classify spec items as proceed-autonomously vs stop-and-ask using the calibration list. The seven stop-and-ask categories — new DB columns/tables, auth flow changes, new third-party API integrations, performance-sensitive code paths, security-related logic, deletion of existing tests, new METRICS.md events — become **Decision rows** the user signs off on before `/ak-implement` runs. See `/devshop/CLAUDE.md § Confidence Calibration`.
- **Deploy boundaries** — if the spec includes a schema-mutating migration (rename, drop, NOT NULL without default, type change), the test plan MUST either (a) flag the migration as backwards-incompatible and gate `/ak-go-live` on the deploy-migrations workflow finishing before the app deploy, or (b) split into two PRs — additive PR with dual-shape code paths first, mutating PR after. Default to (b) for prod-impact migrations. Edge function changes need a slow-job E2E or an explicit deploy-verification step in the test plan. See `conventions.md § Deploy Boundaries`.
- **Screenshot paths** — when the spec references screenshot paths, use canonical locations only: `specs/<feature>/hero/` (durable PR-body shots), `specs/<feature>/screenshots/` (per-gate evidence), `specs/<feature>/qa-walk/` (per-verb artifacts proving each Core user story verb). Never invent new paths. See `conventions.md § Screenshot Routing`.
- **Slow-job content gates** — projects scaffolded from the post-2026-05-19 template ship the slow-job active from day one with per-step `hashFiles()` empty-state guards (Playwright steps gate on `apps/web/e2e/**/*.spec.ts`; type-drift + rollback gate on `supabase/migrations/*.sql`). The first integration test or Playwright spec a spec adds is gated by CI automatically — no Decision row, no skill-prose handoff. Pre-2026-05-19 projects (those with a still-commented `slow:` stub) DO need a Decision row capturing the activation + branch-protection update — surface that conditionally. See `conventions.md § Slow-Job Lifecycle`.
- **Testing layers** (T1) — every UI surface added or modified gets a Playwright E2E (375px + 1440px). Every API wrapper in `packages/core/src/api/*.ts` either has a dedicated E2E or is transitively covered (cite the covering spec in JSDoc). RLS-policied tables get an auth-boundary integration test. See `conventions.md § Non-Negotiables — Testing`.
- **Code structure** (T1) — when the spec proposes module boundaries, honor barrel-export discipline (no deep path imports across packages) and the file-header / JSDoc rules. See `conventions.md § Non-Negotiables — Code Structure`.

## Step 7: Handle new metrics

If the feature introduces new user actions not yet in `METRICS.md`:

- Propose new events following the metrics principles in `kit/docs/guide/ § Metrics Lifecycle`
- **Stop and ask for confirmation** before adding to `METRICS.md`
- Never auto-add events without review

## Step 8: Verify feature directory

Confirm `$FEATURE_DIR/spec.md` was written. No pointer file needed —
`/ak-build` and `/ak-implement` find the spec via `PLAN.md § Active`
(the row's Branch + Spec columns) or the feature directory path.

## Quality checklist

Every spec must have:

- [ ] **`## Product update` section — both `### Headline (user-facing)` and `### Detail (team-facing)` sub-sections (or `### Headline + Detail (combined)` when collapsed)**. Headline has zero eng vocabulary (no enum names, no RPC names, no migration numbers, no PascalCase component names, no route paths, no cross-PR references); Detail is team-facing with explained eng context. Both blurbs surface as named bullets in `/ak-build` Phase 0 Scope preview and are verified against the diff at Phase 6 Gate A.
- [ ] **`## Core user story` section — 2–4 imperative verbs OR `N/A — <reason>`** (Gate 9 enforces artifact coverage for each verb)
- [ ] All user-facing behaviors described (happy path + error states)
- [ ] **`## Render conditions` matrix — every state combination resolved to `shown` / `hidden` / `n/a` for every new or visibility-modified UI element** (omit if PR is pure backend / migration / refactor; see Render conditions section above)
- [ ] Data model changes explicit (exact schema diffs or "no changes")
- [ ] API contracts specified (endpoints, inputs, outputs, auth requirements)
- [ ] Out-of-scope items explicitly listed
- [ ] Offline behavior declared for any feature with remote data: (a) online-only with error state, (b) read-only cache, (c) full offline with sync. Default to (a) unless explicitly upgraded.
- [ ] Metrics section referencing events from `METRICS.md`
- [ ] Provenance header linking to gstack plan
- [ ] **Decision rows** capture every stop-and-ask item from Confidence Calibration (new schema, auth changes, new third-party APIs, perf-sensitive paths, security logic, test deletions, new metric events) for user sign-off before `/ak-implement` runs
- [ ] If the spec includes a **schema-mutating migration**, test plan flags it backwards-incompatible OR proposes a split-PR plan (Deploy Boundaries)
- [ ] If the project's `.github/workflows/ci.yml` still ships a commented-out `slow:` stub (pre-2026-05-19 scaffolds), a Decision row captures the slow-job activation landing in the same PR. Post-2026-05-19 scaffolds need no row — the active stub gates new content automatically.
- [ ] Screenshot paths reference canonical `specs/<feature>/{hero,screenshots,qa-walk}/` locations only
