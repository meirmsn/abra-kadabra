# Workflow: Idea to Deployed

The end-to-end devshop pipeline, from rough notes to production. Six steps wrap five skills (`/office-hours`, `/autoplan`, `/ak-spec`, `/ak-build`, `/ak-go-live`); the user gate sits between steps 5 and 6. This guide is operator-facing — for the in-feature implementation contracts the steps invoke, see the routing index at [`README.md`](./README.md).

## Contents

- [Pipeline at a Glance](#pipeline-at-a-glance)
- [Step 1: Write rough notes](#step-1-write-rough-notes)
- [Step 2: `/office-hours` (gstack)](#step-2-office-hours-gstack)
- [Step 3: `/autoplan` (gstack)](#step-3-autoplan-gstack)
- [Step 4: `/ak-build` (devshop skill) — autonomous pipeline](#step-4-ak-build-devshop-skill--autonomous-pipeline)
- [Step 5: You review the PR](#step-5-you-review-the-pr)
- [Step 6: `/ak-go-live` (devshop skill) — autonomous deploy](#step-6-ak-go-live-devshop-skill--autonomous-deploy)
- [Feature tracking: PLAN.md, BUILD-LOG.md, tasks.md](#feature-tracking-planmd-build-logmd-tasksmd)
- [Plan-level changes (rescope, reorder, drop)](#plan-level-changes-rescope-reorder-drop)
- [Workflow variants](#workflow-variants)
- [Structured Reflection](#structured-reflection)
- [Starting a New Project](#starting-a-new-project)
- [Build and Deploy Quick Reference](#build-and-deploy-quick-reference)
- [gstack Skill Map](#gstack-skill-map)
- [Devshop Skill Map](#devshop-skill-map)

## Pipeline at a Glance

```
┌─────────────────────────────────────────────────────────────────────────┐
│  IDEATION                                                               │
│                                                                         │
│    rough notes                                                          │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────────┐  interviews → product design doc                   │
│  │ /office-hours   │  (demand, urgency, scope)                          │
│  └─────────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PLANNING                                                               │
│                                                                         │
│  ┌─────────────────┐  runs sequentially:                                │
│  │ /autoplan       │  ├─ /plan-ceo-review                               │
│  │                 │  ├─ /plan-design-review                            │
│  │                 │  └─ /plan-eng-review                               │
│  └─────────────────┘  → .gstack/projects/<slug>/                        │
│                                                                         │
│  optional (UI-heavy): /design-shotgun → /design-html                    │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  /ak-build  — autonomous pipeline (one command)                         │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 0 · preview + decisions checkpoint                         │   │
│  │   reads roadmap / design / test-plan sources                     │   │
│  │   → 3-section preview: decisions / scope / tracker               │   │
│  │   user approves → writes specs/<name>/spec.md SKELETON           │   │
│  │     (provenance + Sources + Decisions — no Task order yet)       │   │
│  │   starts live TaskCreate tracker                                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 1 · /ak-spec                                               │   │
│  │   reads spec.md skeleton (Decisions preserved verbatim)          │   │
│  │   expands in place → full spec (In scope, Task order, Tests, …)  │   │
│  │   flips PLAN.md row Planned → Active                             │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 2 · /ak-implement                                          │   │
│  │   decompose → code + tests per task                              │   │
│  │   stuck protocol: try fix → /investigate → ask user              │   │
│  │   atomic commits, decisions logged in tasks.md                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 3 · /ak-pre-ship  (17 gates, re-run tests after each)      │   │
│  │   gate naming: (ak) = devshop-native; bare = wraps gstack skill  │   │
│  │   1.  docs-check (ak)                                            │   │
│  │   2.  metrics-check (ak)                                         │   │
│  │   2b. rls-coverage (ak)         (migrations + client API)        │   │
│  │   2c. slow-job-lifecycle (ak)   (integration/E2E threshold)      │   │
│  │   2d. fast-job-local (ak)       (Layer 1 of /preflight: lint +   │   │
│  │                                  typecheck + test:unit + build)  │   │
│  │   2e. changed-tests-local (ak)  (Layer 2 of /preflight: parse +  │   │
│  │                                  changed E2E + smoke set)        │   │
│  │   3.  responsive-theme (ak)     (UI)                             │   │
│  │   4.  simplify                  ──▶ test:unit                   │   │
│  │   5.  test-review (ak)                                           │   │
│  │   6.  review                    ──▶ test:unit                   │   │
│  │   7.  cso                       ──▶ test:unit                   │   │
│  │   8.  design-review             ──▶ test:unit  (UI)             │   │
│  │   8b. design-conformance (ak)   (DESIGN.md contract)             │   │
│  │   9.  qa                        (own fix loop)                   │   │
│  │   10. benchmark                 (UI)                             │   │
│  │   10b. preflight-final (ak)     (/preflight re-run: end-of-chain │   │
│  │                                  attestation across all gates)   │   │
│  │   11. convention (ak)                                            │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 4 · /ship                                                  │   │
│  │   merge base → tests → /review → bump VERSION → push → PR        │   │
│  │                                 → auto /document-release         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 5 · CI watch + PR bookkeeping                              │   │
│  │   5.1-5.2  watch CI via gh pr checks --watch                     │   │
│  │   5.3      green → tick PR checkboxes + preview URL              │   │
│  │   5.4-5.5  fail  → fix loop (max 3) → @mention if stuck          │   │
│  │   5.6      green → remove PLAN.md Active row + append BUILD-LOG  │   │
│  │   5.7      re-watch CI after the 5.6 push, then advance          │   │
│  │   5.8      post-pre-ship test-coverage re-audit (Sonnet subagent │   │
│  │            re-runs /ak-tests-review over <pre-ship-sha>..HEAD;    │   │
│  │            halts on high-severity findings, surfaces medium in   │   │
│  │            audit comment) — entry runs polish-loop CI sanity     │   │
│  │            check first via gh run list since pr.createdAt        │   │
│  │   5.9      visual evidence refresh (subagent re-captures Gate 4  │   │
│  │            + Gate 13 hero shots at HEAD, commits only on real    │   │
│  │            content change) — freshness-only, no halt path        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 6 · audit-trail PR comment + final checkbox sweep          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                    │                                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Phase 7 · notify: "@user PR ready" + terminal handoff            │   │
│  │   diff-type aware: runtime → /ak-go-live; docs-only → no deploy  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
       │
       ▼
   HUMAN REVIEW  (release notes + audit comment + preview URL)
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  /ak-go-live  — autonomous deploy (one command)                         │
│                                                                         │
│   1. pre-flight: CI ready + prod-health probe + migration sequencing    │
│   2. /land-and-deploy   merge → wait for deploy → prod health check     │
│   3. branch cleanup + PLAN.md/BUILD-LOG sanity check on main            │
│   4. /canary            ~15 min monitor; fail = stop + rollback SHA     │
│   5. rollback checkpoint (records SHA + Vercel ID + last migration)     │
│   6. structured reflection → CLAUDE.md / guide docs / TODOS / ROADMAP   │
│   7. notify: "@user deployed. Canary: pass/fail. Rollback SHA: xxx"     │
└─────────────────────────────────────────────────────────────────────────┘
```

Standalone skills (usable outside the pipeline): `/ak-status`, `/ak-handoff`, `/ak-spec`, `/ak-implement`, `/ak-pre-ship`, `/ak-tests-review`, `/ak-design-conformance`, `/ak-new-project`, `/ak-migrate-project`.

## Step 1: Write rough notes

Problem description + rough solution idea. Not a full spec — just enough to seed the conversation.

## Step 2: `/office-hours` (gstack)

Interviews you, challenges framing, produces a product design doc. Forces you to articulate demand, urgency, and scope.

## Step 3: `/autoplan` (gstack)

Runs CEO, design, and engineering review sequentially. Locks in architecture, edge cases, and decisions. Output: a gstack plan in `.gstack/projects/<slug>/`.

- **3b: `/design-shotgun`** (optional) — visual variants before spec. Use for UI-heavy features only. Approve one direction before proceeding.
- **3c: `/design-html`** (optional) — turns approved mockup into an HTML reference file. Claude builds React from this instead of interpreting a description.

## Step 4: `/ak-build` (devshop skill) — autonomous pipeline

One command after autoplan. Chains everything through PR creation, CI verification, and notification. Resumable if the session is interrupted.

**Phase 0: Preview + decisions checkpoint** — the one interactive beat before
token-heavy work. Reads the roadmap section, design doc, and test plan for this
feature; produces a 3-section preview (decisions / scope / hierarchical tracker
simulation) for user approval. On approval, writes `specs/<name>/spec.md` as a
skeleton — provenance header, Sources list, and a fully-populated Decisions
section — and commits it on the feature branch so the user's judgment calls
survive a crash. Starts a live `TaskCreate` tracker mirroring the preview's
hierarchy (phases as rows; sub-units — Phase 2 tasks, Phase 3 findings,
Phase 5 fix-loop attempts — prefix their parent phase as `<Phase X> /
<sub-unit>` since the harness's task list is flat). Finally,
emits a remote-control nudge ("type `/remote-control` now if you want
phone/watch monitoring") right before spawning the first subagent — the last
main-context beat before autonomous work begins. On resume paths that skip
Phase 0, the same nudge fires once from Step 0 at the equivalent timing.

For decision rows that turn on **"does X work in version Y of Z"** —
framework resolution order, library defaults, API edge-case semantics —
Phase 0 runs the empirical test BEFORE the user approves. 30 seconds of
"actually compile this and grep the output" beats committing implementation
code against an unverified hypothesis and discovering it was wrong
mid-Phase 2. Full triggering signals + per-layer verification recipes:
`/ak-build § 0.2.5 Empirical-verify load-bearing decisions before locking`.

**Phase 1: `/ak-spec`** — reads the Phase 0 skeleton and expands it in place
into a full spec (Core user story, In scope, Screens, Data model, API
contracts, Tests, Task order, Gotchas, Acceptance plan). Preserves the
skeleton's Decisions section verbatim — does NOT re-resolve. Creates the
feature branch (`feat/<slug>` or `fix/<slug>`) if currently on main
(inherited from Step 0 — Step 0 picks the prefix by counting existing
`feat/*` vs `feature/*` branches; greenfield projects default to `feat/`
to match the conventional-commit short form), and flips the `PLAN.md`
Planned row for this feature into `## Active`. The `## Task order` section is the discriminator
the resume check uses to tell "skeleton" from "complete spec." METRICS.md
confirmation only fires when the Phase 0 skeleton didn't cover events
(rare — only on manually-seeded feature branches).

**New (Phase 1-B landing — Core user story requirement)**: every spec
produced by `/ak-spec` MUST include a `## Core user story` section — 2-4
imperative verbs describing the product's primary flow end-to-end, OR the
literal body `N/A — <reason>` for non-user-facing PRs (migration-only,
internal refactor). Gate 9 enforces that every verb has a matching artifact
at `specs/<feature>/qa-walk/verb-<N>-<slug>.{png,json}` proving the action
completed — missing / empty artifact blocks Gate 9 with a per-verb
diagnostic. The `N/A — <reason>` rationale is itself adversarially reviewed
at pre-ship time (`coreUserStoryNaReason` check-type): interpretive prose
("no visible UI change", "cosmetic only") fails; verifiable file/path
claims ("diff is `supabase/migrations/**` only", "no `.tsx` files modified")
pass — bare `N/A` with no rationale auto-fails. See
`/devshop/.claude/skills/devshop/spec/SKILL.md § Core user story` for the
template + examples, and `/devshop/.claude/skills/devshop/pre-ship/SKILL.md
§ Gate 9` for the enforcement contract.

**Body-consistency check between /ship and Phase 6.** Each post-/ship
commit that lands while CI is green runs a body-consistency sub-step
(`/ak-build § 5.3.5`) that checks the post-/ship range for scope-drift
signals — new test files, replaced hero / qa-walk evidence, bundled CI
workflow changes, new runtime files. When a signal fires, the agent
reads the current PR body and edits any narrative claim the signals
invalidate (Summary scope, Evidence methodology, Test plan rows). Closes
the gap between Phase 5.3's checkbox-only refresh and Phase 6's full
sweep — without it, multi-commit polish loops silently drift the body
out of sync with what's been committed.

**Synthetic-harness substitution at Gate 9 is forbidden.** A degraded local
Supabase stack (auth schema errors, missing migrations, runner unreachable)
must surface as `blocked` with the bootstrap script's fix recipe — not be
worked around by mounting the component on an unrelated page or stubbing
its data path with fixtures. The full contract + the lalista PR 53 incident
that codified it lives at `/devshop/.claude/skills/devshop/pre-ship/SKILL.md
§ No synthetic-harness substitution`; deliberate operator opt-out for
low-risk diffs uses `git config devshop.requireHealthyLocalStack never`.

**Phase 2: `/ak-implement`** — reads spec, decomposes into tasks, implements with tests. Confirms active branch against `PLAN.md § Active`. Stuck protocol: try fix → `/investigate` → ask user. Logs judgment calls in `specs/<name>/tasks.md` § Decisions.

**Phase 3: `/ak-pre-ship`** — quality gates only (no shipping). A Phase 0 preflight runs first: verifies required tooling (Chromium for browser gates) and aborts the whole pre-ship with a `blocked` status if tooling is missing, so gates can't silently turn a missing tool into a cheerful "skipped". After preflight passes, 17 gates run in canonical order. Gate naming: `(ak)` marks devshop-native gates (either a devshop-owned check or a devshop-authored skill like `/ak-tests-review`); bare names wrap gstack skills invoked verbatim. The canonical source of truth for gate ordering + scope is `pre-ship/SKILL.md § Gates (canonical order + named IDs)`.

Gates 2d + 2e together are equivalent to the standalone `/preflight` skill — they form the front-of-chain fast-fail floor (lint/typecheck/unit/build + targeted integration/E2E) so 5 min of deterministic checks don't get hidden behind 25 min of LLM ceremony. Gate 10b is the same `/preflight` re-run at end-of-chain, catching cross-gate interaction breakage that per-gate `test:unit` checkpoints miss (each code-changing gate self-verifies its own edits via unit tests, but integration/E2E regressions and `/simplify`+`/review`+`/cso`+`/design-review`+`/qa` composition breakage only surface in the final attestation).

1. `docs-check` (ak)
2. `metrics-check` (ak)
   2b. `rls-coverage` (ak) — when `supabase/migrations/**` or client API touched; mechanical check that every RLS-enabled table written by client code has a matching `CREATE POLICY` for the operation in use (catches the silent-zero-row class lalista PR 5 hit)
   2c. `slow-job-lifecycle` (ak) — when `*.integration.test.ts` or `apps/web/e2e/*.spec.ts` files exist; verifies the slow-job CI is uncommented, has the right `if:` predicate + retry pattern, and that branch protection includes the `slow` context
   2d. `fast-job-local` (ak) — when `turbo.json` exists; runs `pnpm turbo run lint typecheck test:unit build` with per-step wallclock budgets (Layer 1 of `/preflight`). Mirrors CI's fast-job verbatim so deterministic failures (type errors, broken unit tests, lint regressions) surface here in ~1–3 min instead of after a CI round-trip
   2e. `changed-tests-local` (ak) — when diff includes `apps/**`, `packages/{core,ui}/**`, `*.integration.test.ts`, `apps/*/e2e/*.spec.ts`, or `supabase/{migrations,functions}/**`; cheap local checks: Playwright `--list` parse-check, changed E2E + integration specs (bounded wallclock), convention-based smoke set (`*-qa-walk.spec.ts`) (Layer 2 of `/preflight`)
3. `responsive-theme` (ak) — UI PRs only; captures 4-combo evidence screenshots
4. `simplify` → test:unit checkpoint
5. `test-review` (ak)
6. `review` → test:unit checkpoint
7. `cso` → test:unit checkpoint
8. `design-review` → test:unit checkpoint (UI PRs only)
   8b. `design-conformance` (ak) — DESIGN.md contract check (runs regardless of UI scope)
9. `qa` (has own fix loop)
10. `benchmark` — UI PRs only
    10b. `preflight-final` (ak) — when Gate 2d ran; re-invokes `/preflight` against the post-ceremony composed state. Catches integration/E2E regressions and cross-gate interaction breakage the per-gate `test:unit` checkpoints would miss
11. `convention` (ak)

After all gates pass, hero screenshots are captured to `specs/<name>/hero/` (committed) for the PR audit comment — see `FAQ.md § How are specs and pipeline artifacts organized?` for the hero vs evidence split.

Gate outcomes use four categories: `pass`, `findings (N) [fixed|pending]`, `n/a`, `blocked`. `/ak-build` refuses to advance to `/ship` on any `blocked` gate. **LLM-mediated gates (6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa`) cannot emit `n/a` — they use `blocked (n/a per scope: <reason>)` for scope exemptions instead, so the rationale is auditable.** See `pre-ship/SKILL.md § Outcome semantics § ` `n/a` ` is not legal for LLM-mediated gates` for the rule and `ak-build/SKILL.md § Phase 3 → Phase 4 handoff` for the orchestrator-side halt rung.

Every gate's report must also include a `## Dismissals` section (body `None` or a bulleted list of findings-with-rationale). Pre-ship aggregates these into a `## Router Summary` block at the top of `review.md` and — when any body is non-`None` — hands the rationales to an adversarial reviewer (`kit/scripts/adversarial-review.sh dismissalLog`) that rejects weak, generic, or out-of-scope justifications. Rejection fails the gate the same as any `findings (N) pending` outcome. The check-type also applies severity-weighted shims for structured-output gates like `/cso` (TENTATIVE findings auto-dismiss with a mechanical rationale, no LLM call). See `hooks.md § Dismissal Log` for the full gating rules, env-var escape hatches, and forward-compatibility with the Phase 4 Finding Router.

**Phase 4: `/ship`** (gstack) — merges base, runs tests + review (final verification), bumps VERSION, pushes, creates PR, auto-invokes `/document-release`. PR body is seeded per the checkbox conventions in `/devshop/.claude/skills/devshop/build/SKILL.md § PR body conventions` — image embeds use the private-repo-safe `https://github.com/<owner>/<repo>/raw/<branch>/<path>` form; checkboxes are left `[ ]` at creation and ticked incrementally at 5.3 and 6.

**Commit + PR subject/summary style (Phase 4 + `/ak-merge-devshop`).** Both surfaces enforce the same readability rule: commit subjects and PR titles **describe the observable change**, not the implementation detail. Lead with a verb when there's one verb-y change (`skip`, `add`, `fix`, `tighten`, `rename`); noun-lists are fine for multi-unit commits (`feat: invite link + member mgmt + audit feed`). No internal jargon ("polish", "soak findings", "Phase 2 expansion") — drop the meta-narrative and name the underlying user- or code-facing fact. Subjects ≤ 72 chars (err shorter). PR/squash **bodies** open with a one-sentence TL;DR + 3-7 bullets — each one a concrete user-meaningful unit. Bullets first; prose only when a non-obvious decision needs framing, kept to 1-2 sentences. Don't write a paragraph and then re-summarize it as bullets — pick one. Test: would a teammate scrolling `git log` two months from now know what shipped without opening the diff? Canonical rules: `kit/docs/guide/conventions.md § Commit + PR Text Style` (devshop-owned — survives `gstack` upgrades). Squash-specific shape: `.claude/skills/devshop/merge-devshop/SKILL.md § Subject style` + `§ Why bullet-led summary, not paragraphs`. The rules are intentionally NOT inlined into `gstack/ship/SKILL.md` (upstream-owned, would be clobbered on sync); when `/ship` is invoked from `/ak-build` Phase 4, the wrapper handoff carries the reminder.

**Phase 5: CI watch + PR bookkeeping** — watches CI via `gh pr checks --watch` (5.1–5.2). On failure: reads CI logs, reads local test/source code, makes informed fix, verifies locally if possible, pushes — max 3 fix cycles (5.4), escalates via PR @mention if stuck (5.5). On CI green: ticks the corresponding `## Test plan` / `### CI gates` PR-body checkboxes with attestations like `green on <sha>` and preview-deploy URLs (5.3), then closes out the feature's history on the feature branch — removes the Active row from `PLAN.md` and appends the ship entry to `BUILD-LOG.md` (5.6) so the history ships as part of this PR rather than a follow-up cleanup commit. The 5.6 push triggers a fresh CI run; 5.7 re-watches it before advancing.

After 5.7, two late gates close the post-pre-ship gap (commits that landed AFTER `/ak-pre-ship` Gate 5 audited the spec snapshot — `/ship` commits, the entire CI fix-loop, dogfood-driven polish iterations — would otherwise reach merge unaudited). **Phase 5.8** spawns a Sonnet subagent that invokes `/ak-check-docs-and-tests` (the audit-time orchestrator; runs `/ak-docs-review` + `/ak-tests-review` in sequence) over `<pre-ship-sha>..HEAD`. The range is computed from the latest `## Audit N` section's `<!-- audited-at: <SHA> -->` stamp in `review.md` — typically Audit 1, written by `/ak-pre-ship` Gate 5 against the spec snapshot. The orchestrator appends a new `## Audit 2` section to that same `review.md` (single-file model — appended `## Audit N` sections in the same review.md, no separate `test-review-followup.md`). High-severity findings halt; medium surface in the audit comment for reviewer eyes; low get mentioned without listing. 5.8's first move is a polish-loop CI sanity check — it enumerates every CI run since `pr.createdAt` via `gh run list` and halts if the latest is non-success (mechanical replacement for a load-bearing per-push-watch discipline). **Phase 5.9** spawns a refresh subagent that re-captures `/ak-pre-ship` Gate 4 + Gate 13 hero shots at HEAD, commits only when `git diff --cached` shows real changes — freshness-only, no halt path, the `### Evidence` block in Phase 6 reports `(refreshed)` / `(unchanged at HEAD)` / `(skipped via idempotence)`.

**Phase 6: Audit-trail PR comment** — posts the quality-gate results, implementation decisions, CI fix summary, and rendered hero screenshots (`https://github.com/<owner>/<repo>/raw/<branch>/specs/<feature>/hero/<screen>.png`). Does a final sweep (Fix D) cross-checking the PR-body checkbox state against on-disk evidence before Phase 7 declares ready-for-review.

**Phase 7: Notify** — detects diff type (runtime vs docs-only) and posts a ready-for-review comment tuned to the diff: runtime changes (`apps/**`, `packages/**`, `supabase/migrations/**`, `supabase/functions/**`) get a "run `/ak-go-live` next" hint; docs-only diffs explicitly say `/ak-go-live` is not needed. Prints the matching terminal handoff to the session's stdout so the user sees the next step without re-opening the PR.

## Step 5: You review the PR

- Release notes (from `/ship`) + audit trail comment (from `/ak-build`)
- CI green + Vercel preview URL
- You merge or request changes

## Step 6: `/ak-go-live` (devshop skill) — autonomous deploy

One command after you approve the PR.

1. **Pre-flight** — verifies the PR is ready (CI green, no merge conflicts), then runs three pre-merge probes:
   - **Production health probe** — curls the production URL from `CLAUDE.md § Deploy Configuration` to catch pre-existing prod failures the about-to-land deploy might mask. Splits HTTP `000` (firewall-IP-rotation — devcontainer connectivity issue, prod is probably fine) from real `4xx`/`5xx` responses (genuine pre-existing prod issue → operator question). Codified from lalista PR 26 (trailing-newline `NEXT_PUBLIC_SUPABASE_URL` → SSR 500) and PR 28 (Vercel edge-IP rotation false-positive).
   - **Migration sequencing pre-flight** — when the diff touches `supabase/migrations/**`, classifies each touched file as additive (CREATE / ADD COLUMN with default) vs mutating (DROP / RENAME / ALTER TYPE / SET NOT NULL without default). Honors `specs/<feature>/spec.md § Migration Sequencing` if pre-declared; otherwise applies the heuristic. Pauses on mutating migrations without an explicit deploy plan, since the parallel-deploy race (Vercel vs `deploy-migrations.yml`) creates a ~30–60s window where prod runs new code against the old schema.
   - **Pending tasks pre-flight surface** — reads the merging PR's body + the latest `## Pre-ship audit trail` and `## Ready for review` comments via `gh pr view`, parses every `[ ]` checkbox grouped by section, and prints a "Pending tasks before live" view annotated `[manual]` (operator-action needed) / `[deferred]` (PR-review concern, post-merge) / `[!]` (CI checkbox `/ak-build` Phase 5.3's auto-marker should have flipped — bookkeeping skipped). Blocks the merge via `AskUserQuestion` only when `## Out-of-band deploy items` has unchecked items (those are deploy prereqs by definition); other surfaces are non-blocking reminders. Operator picks "Done — proceed" / "Pause" / "Skip — accept the gap." Closes the gap where today the operator must mentally cross-reference the PR body and the audit comment at deploy time. Management API integration that converts `[manual]` items like email-template push and allow-list verify into `[auto]` — the automation core — is deferred to a separate PR; see `kit/ROADMAP.md § /ak-go-live post-merge prod-config sync (Arm B — automation core)`.
2. `/land-and-deploy` (gstack) — checks CI green, merges, waits for deploy, verifies prod health. The merge to main triggers three parallel auto-deploys: Vercel (Next.js app), `deploy-migrations.yml` if `supabase/migrations/**` changed, `deploy-functions.yml` if `supabase/functions/**` changed. See `guide/conventions.md § Deploy Boundaries` for the backwards-compatibility constraints that follow from the parallel-deploy race (especially for schema-mutating migrations). Auth-config changes still ship manually. **Pre-check at Step 2.0**: working tree must be clean before `gh pr merge` fires — `--squash --delete-branch` runs `git checkout <base>` inside the gh process, and a leftover uncommitted artifact (e.g., a stale Phase 5.8 audit section) makes the local checkout fail AFTER the GitHub-side merge + branch deletion already shipped (irrecoverable state if you weren't expecting it). Step 2.0 surfaces the dirty file via `AskUserQuestion` with commit / stash / abort options. Codified from home-os PR #26 (2026-05-16).
3. **Step 2.5 — Rewrite PR-body image URLs to merge SHA** — after `/land-and-deploy` returns merged but before branch cleanup, `/ak-go-live § Step 2.5` reads the merged PR's body, repoints every `https://github.com/<owner>/<repo>/raw/<feature-branch>/<path>` URL to the same path under `/raw/<merge-commit-SHA>/`, and writes the rewritten body back via `gh pr edit --body-file -`. The rewrite logic lives in a shared sourceable helper at `kit/scripts/lib/rewrite-pr-body-urls.sh` so the forward fix and the catch-up backfill use the same function — single source of truth, no behavior drift. Closes the "image embeds 404 the moment `--delete-branch` runs" gap; the per-PR conventions in `/ak-build § Image embeds — private-repo safe` ship the pre-merge form unchanged so this step has something to repoint. Skip semantics: null `mergeCommit.oid` (operator did a non-squash merge) → warn-and-continue; zero `/raw/<head-ref>/` matches (PR has no embeds) → silent attesting pass without `gh pr edit`. **Catch-up coverage for PRs that pre-date this step**: run `bash kit/scripts/backfill-pr-image-urls.sh --owner <owner> --repo <repo> [--dry-run|--accept-history-rewrite] [--limit N] [--since YYYY-MM-DD] [--skip-edited] [--bodies-only]`. Default mode is `--dry-run`; mutation requires explicit `--accept-history-rewrite`. Per-run JSONL audit log under `${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/<UTC-ts>.jsonl`; each row has a `target` field that's either `body` or `comment:<id>`. Skips PRs with no head-ref / no merge-SHA / zero matching URLs. The `--skip-edited` flag is opt-in conservatism — it additionally skips PRs whose body was edited >5min after merge, on the theory that the operator may have manually fixed URLs. Default is OFF because pipeline auto-edits (Phase 5.3 CI checkbox marks, audit comments) routinely trip the heuristic without ever touching image URLs — leaving conservatism on by default mis-suppresses the actual rewrite targets (codified after lalista PRs #60 / #61 were silently skipped on the conservative pass). The `--bodies-only` flag opts out of comment processing — by default the script ALSO rewrites issue comments authored by the gh-cli authenticated user (typically Phase 6 audit-trail comments that embed hero shots). Comments authored by other users (reviewers, bots) are skipped regardless via the `not-our-comment` audit reason — the gh API only allows editing your own comments. One-time per project — re-runs on already-rewritten bodies + comments are all-skip (idempotent).
4. **Branch cleanup + PLAN.md / BUILD-LOG sanity check** — locally `git branch -D` the merged feature branch and `git remote prune origin`. Verifies `/ak-build` Phase 5.6 already removed the Active row from PLAN.md and appended the entry to BUILD-LOG on the feature branch before merge. Surfaces (does NOT auto-fix) if the close-out was skipped — Claude can't commit to main, so missing close-outs need a human-initiated commit.
5. `/canary` (gstack) — ~15 min post-deploy monitoring. If fail: stops, notifies with rollback info (no auto-rollback). Same HTTP 000 vs 4xx/5xx split as Step 1 applies for canary failures.
6. **Rollback checkpoint** — records the current Vercel deployment ID, the latest migration filename, and the current Git SHA every time (even on success), so a future rollback has the coordinates pre-staged in the conversation rather than having to be reconstructed.
7. **Structured reflection** — routes learnings to committed files (CLAUDE.md, guide docs, backlogs). Two distinct categories, both required: 5a project-side (conventions, gotchas, troubleshooting, decision log) and 5b devshop-side generalization (skill amendments, template fixes, conventions). Either may be empty — explicit "nothing this session" beats fishing for noise. **PR-only main projects:** when branch protection blocks direct commits to main, open a small focused docs PR (e.g. `docs/<feature>-reflection`) with just the reflection commit; the overhead is acceptable and main's history stays clean.
8. **Notify** — PR comment: "@username deployed. Canary: pass/fail. Rollback SHA: xxx"

---

## Feature tracking: PLAN.md, BUILD-LOG.md, tasks.md

Three artifacts at three different grains:

- **`PLAN.md`** (at project root, forward-looking) — `## Active` and `## Planned` tables at the feature/PR grain. Source of truth for "what's being built right now, on what branch" and "what's next." Consumed by `/ak-implement` (resolves spec via Active row), `/ak-status` (surfaces both sections), `/ak-go-live` Step 2b (sanity check). Written by `/ak-spec` (flips Planned → Active) and `/ak-build` Phase 5.6 (removes Active row at ship).

- **`BUILD-LOG.md`** (at project root, backward-looking) — append-only shipped entries, no sections, most-recent first. One rich entry per merged PR with branch/PR number/spec path/summary/gate results. Written by `/ak-build` Phase 5.6 on the feature branch before merge, so the entry ships as part of the PR itself.

- **`specs/<name>/tasks.md`** (per-feature, live) — in-flight per-task status with commit SHAs. Written by `/ak-implement` as it progresses. Commit-level granularity — this is how you resume an in-progress feature across sessions.

Multiple rows may live in `PLAN.md § Active` at once — parallel feature work is supported, one row per live branch.

## Plan-level changes (rescope, reorder, drop)

The plan is a living doc. When scope shifts:

- **Reorder Planned**: edit `#` values; commit message captures why.
- **Drop a Planned row**: delete it; commit message is the audit record.
- **Defer "maybe later"**: move the entry from `PLAN.md` to `PRODUCT-ROADMAP.md` — explicit signal that it's not next.
- **Rename a feature**: edit the Feature cell; rename the spec folder if the feature is already Active.
- **History**: `git log --follow PLAN.md` shows the full evolution.

No `## Deprecated` section, no status column — git log is the audit trail.

---

## Workflow variants

The main pipeline diagram shows the idea-to-deployed flow. In practice five variants of that flow exist, differing in where you enter the pipeline:

| Variant                        | Entry point                  | Plan-time steps                                                                                                                          | PLAN.md handling                                                                                                           |
| ------------------------------ | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Idea → full app**            | Rough notes                  | `/office-hours` → `/autoplan` → seed PLAN.md with one Planned row per PR                                                                 | Planned rows initialized in build order; each `/ak-build` flips row → Active → (removed at ship, entry lands in BUILD-LOG) |
| **New feature (existing app)** | "Let's add X"                | Short `/office-hours` or skip → `/autoplan` scoped → add a Planned row                                                                   | `/ak-build` picks up the row and transitions it                                                                            |
| **Feature improvement**        | "Auth's error UX needs work" | `/autoplan` on the scoped improvement → add Planned row with a new spec folder name, Notes references the prior spec as `**Builds on**:` | Same transitions as a new feature; spec folder is new (original stays as a snapshot of what shipped)                       |
| **Bug fix**                    | Reported bug                 | `/investigate` for root cause → brief Planned row (Notes = "bug fix: X") → `/ak-build` on `fix/*` branch                                 | Row lives briefly; ships like any feature                                                                                  |
| **Urgent hotfix**              | Production incident          | Skip planning — branch, fix, PR, merge                                                                                                   | Optional: retroactive BUILD-LOG entry + PLAN.md row only if meaningful                                                     |

The pipeline machinery is the same across all five — only the pre-pipeline planning depth varies. `/ak-build` doesn't care whether the Planned row came from `/autoplan` or from a one-line edit.

Multiple features can be in flight at once — `/ak-build` and `/ak-implement` ask which one to resume if more than one line is active.

---

## Structured Reflection

After each feature ships, run structured reflection in two distinct categories. Both required; either can be empty (just say "nothing to capture this session" explicitly). The full prompt template lives in `/ak-go-live § Step 5` (5a + 5b); this is the workflow-level summary.

### Project-side (5a)

- What went well? What was surprisingly hard?
- New conventions, gotchas, calibration updates → project `CLAUDE.md`
- New troubleshooting entries → guide docs (troubleshooting section)
- Decision log entries → guide docs (decision log section)
- Did confidence calibration need adjustment? (New items for "proceed" or "stop and ask" in project `CLAUDE.md`)

Skip 5a entirely when the bug + commit message + spec docs already carry the context — don't add CLAUDE.md noise for self-evident lessons. The next time the same kind of issue hits, the symptom itself is the signal.

### Devshop-side generalization (5b)

Did the session surface anything that would generalize **beyond this project**? Categories in order of typical leverage:

- **Skill amendment** — `/ak-build`, `/ak-go-live`, `/ak-spec`, `/ak-implement`, `/ak-tests-review`, `/ak-pre-ship`. Operational rules belong in the skill where they fire (Tier 2), not just in conventions.md (Tier 3 — discoverable but not auto-loaded).
- **Template fix** — `template/` (or referenced from `/ak-new-project Step <N>`). Inherited by every new project on next setup.
- **New convention or extension** — `kit/docs/guide/conventions.md`. Pair with a skill amendment that fires the rule.
- **`/devshop/CLAUDE.md` Tier 1 entry** — for cross-cutting principles that need to be always-loaded regardless of which skill ran.
- **`kit/ROADMAP.md § v0 / v1`** — for work bigger than an inline edit, OR an audit/sweep that needs a focused session.

Most sessions produce zero devshop-generalizable lessons. That's fine — explicitly say "nothing this session" rather than fish for noise. The signal is high but the rate is low. The agent surfaces the question proactively (per `/devshop/CLAUDE.md § Implementation Approach`); the user picks which lessons to ship now vs file vs skip.

Lalista PR 26 (2026-04-26) is the calibration case study: 8 generalizations in a single session — firewall closure rule, trace.zip discipline, conventions audit + reviewer-reads-conventions ROADMAP entries, prod-curl probe, firewall-IP-rotation fallback, .trim() defense, CSP scheme handling, Realtime publication, WebKit hydration race, edge-runtime retry. All shipped to devshop within the session because the agent surfaced the prompt explicitly.

- Devshop friction or ideas → `kit/TODOS.md` (tactical) or `kit/ROADMAP.md` (strategic)

---

## Starting a New Project

Run `/ak-new-project` from any devcontainer (the devshop's own or an existing project's).

- **Phase A** creates a GitHub repo populated with the `template/` skeleton.
- **Phase B** runs inside the new project's container for interactive setup (accounts,
  credentials, scaffolding, integrations, security).

The skill tracks progress in `/devshop/kit/notes/projects/<name>.md` (not in
the project repo — keeps project history clean). See
`.claude/skills/devshop/new-project/SKILL.md` for the full step-by-step process.

**Project-specific firewall domains** (Step 6) go in `.devcontainer/firewall-extra-domains` — a `[scaffold-once]` overlay file seeded from the template and locked to `root:root 644` on every container start so only the operator (with `sudo nano`) can edit. Editing `init-firewall.sh` directly is a silent-revert trap: it's `[locked]` template-managed and reverts on every start. See `guide/architecture.md § File lifecycle § Hybrid lifecycle`.

To adopt the devshop on an existing project, run `/ak-migrate-project` (skeleton —
see `kit/ROADMAP.md`).

---

## Build and Deploy Quick Reference

- `/ak-build` — autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Say "build it" after autoplan.
- `/ak-go-live` — autonomous deploy: merge → deploy → canary → reflect → notify. Say "land it" after PR review.
- Individual skills (`/ak-spec`, `/ak-implement`, `/ak-pre-ship`) still work standalone.
- Test commands: `pnpm turbo run test:unit` (fast inner loop), `pnpm turbo run test` (full suite).

For the full pipeline detail, see Steps 1–6 above.

---

## gstack Skill Map

| Skill                  | When to use                            | What it expects           | What it produces                                                                                                     |
| ---------------------- | -------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `/office-hours`        | Start of any feature/project           | Your rough notes          | Product design doc                                                                                                   |
| `/autoplan`            | After office-hours                     | Product design doc        | Architecture plan with resolved decisions                                                                            |
| `/design-consultation` | New project or major visual change     | DESIGN.md + context       | Updated DESIGN.md                                                                                                    |
| `/design-shotgun`      | UI-heavy feature, before spec          | Approved design direction | Visual variant mockups                                                                                               |
| `/design-html`         | After approving a mockup               | Approved mockup           | HTML reference for Claude                                                                                            |
| `/simplify`            | After tests green, before review       | Working code              | Cleaner code (reuse, dead code removal)                                                                              |
| `/review`              | Every PR                               | Diff against base branch  | Staff engineer code review                                                                                           |
| `/cso`                 | Every PR (Pre-Ship Gate 7)             | Repo state                | Security audit (OWASP, STRIDE, secrets, CI/CD)                                                                       |
| `/qa`                  | Every PR                               | Running app               | Bug reports + fixes + regression tests                                                                               |
| `/design-review`       | Every PR touching UI                   | Running app               | Visual audit + fixes. **Note**: when mobile is added, must explicitly check for visual divergence between platforms. |
| `/benchmark`           | Every PR touching UI                   | Running app               | Core Web Vitals + load time regression check                                                                         |
| `/ship`                | After all quality gates pass           | Clean code + tests        | PR with release notes                                                                                                |
| `/land-and-deploy`     | After PR merge                         | Merged PR                 | Deploy verification                                                                                                  |
| `/canary`              | After deploy                           | Production URL            | ~15 min error/perf monitoring                                                                                        |
| `/investigate`         | When stuck 3x on same error; prod bugs | Error context             | Root cause analysis                                                                                                  |
| `/document-release`    | After ship                             | Shipped code              | Updated README/ARCHITECTURE/CONTRIBUTING/CLAUDE.md                                                                   |
| `/retro`               | Weekly or after milestone              | Commit history            | Retrospective with metrics                                                                                           |

## Devshop Skill Map

**Context-aware guideline routing** (added 2026-05-11). `/ak-spec` Step 1.5 and `/ak-implement` Step 1 consult the routing index at [`kit/docs/guide/README.md`](./README.md) — a table keyed by trigger signals (file-globs, Decisions keywords, primitive imports) that points at the guide sections governing each pattern. When a spec touches a routed surface (RLS, PostgREST, optimistic mutation, PWA, custom-domain swap, etc.), the matched gotcha is encoded as an explicit Decision in the new spec with a `per kit/docs/guide/<file>.md § <section>` citation. The canonical contract lives in the SKILL.md files for `/ak-spec` and `/ak-implement`; this paragraph is a discovery hook for operators reading the workflow guide.

**Two-layer read shape (refined 2026-05-11)**: routing matches are **additive on top of** `conventions.md`, not a replacement for it. Both skills read `conventions.md` as a baseline on every invocation — it carries the cross-cutting non-negotiables (Test Presence, Non-Negotiables, Bypass trailers, Project Docs Coverage, Backlog Routing, Confidence Calibration) that fire on every PR regardless of topic. The routing index then sharpens the read to topic-specific guidance for the patterns this particular change touches. The two layers are complementary, not alternatives. The earlier "fallback only on zero matches" framing silently dropped the baseline whenever routing matches DID fire — exact regression on the always-applicable rules; the post-refinement shape closes the gap.

**Pre-adoption projects** (whose `kit/docs/guide/README.md` isn't yet a routing index) get the baseline only — equivalent to the pre-routing behavior, with zero regression. The routing system is the precision improvement; the conventions.md baseline is the universal floor.

The skill files `.claude/skills/devshop/{new-project,tests-review,implement}/SKILL.md` cite `wrapper-boundaries.md` (the split from `conventions.md`) directly when prompting the implementer about LLM-boundary runtime validation or wrapper-API lifecycle events — the citations resolve under the post-split filesystem layout and reflect the canonical guide section names.

| Skill                      | When to use                                                | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| -------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/ak-build`                | After autoplan — "build it"                                | Autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Resumable.                                                                                                                                                                                                                                                                                                                                                                                                                |
| `/ak-go-live`              | After PR review — "land it"                                | Autonomous deploy: merge → deploy → canary → reflect → notify.                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `/ak-spec`                 | Standalone or inside /ak-build                             | Converts gstack plan to implementation-ready spec + METRICS.md                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `/ak-implement`            | Standalone or inside /ak-build                             | Implements tasks with tests, stuck protocol, decisions log                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `/ak-pre-ship`             | Standalone or inside /ak-build                             | Quality gates only (17 gates incl. rls-coverage, slow-job-lifecycle, fast-job-local, changed-tests-local, design-conformance, preflight-final). Does not ship.                                                                                                                                                                                                                                                                                                                                              |
| `/preflight`               | Iterate-fix loop, between commits, before `/ak-pre-ship`   | Cheap deterministic test gate (~5–10 min): Layer 1 = lint + typecheck + test:unit + build via turbo; Layer 2 = parse-check + changed E2E + changed integration + qa-walk smoke. Bundles `/ak-pre-ship` Gates 2d + 2e for standalone use; the same two scripts are re-invoked as Gate 10b (`preflight-final`) at end-of-chain.                                                                                                                                                                               |
| `/ak-design-conformance`   | Inside /ak-pre-ship Gate design-conformance                | Extracts normative claims from DESIGN.md, verifies each against implementation. Complements /design-review (different axes).                                                                                                                                                                                                                                                                                                                                                                                |
| `/ak-check-docs-and-tests` | Inside /ak-pre-ship Gate 5 (and PR-B: /ak-build Phase 5.8) | Audit-time docs + tests review orchestrator. Computes commit range from latest `<!-- audited-at: SHA -->` in `specs/<feature>/review.md`, invokes the two sub-skills sequentially, appends a `## Audit N` section. Idempotent on unchanged HEAD.                                                                                                                                                                                                                                                            |
| `/ak-docs-review`          | Inside /ak-check-docs-and-tests                            | Sub-skill: coverage + adequacy + cross-doc coherence + bypass-trailer audit of docs in a commit range. Repo-aware (devshop self-mode vs project mode). Replaces the per-commit `docsReviewed` adversarial check (removed in PR-C of the audit-time migration); the audit-time prompt is a four-section frame adapted from the historical per-commit version.                                                                                                                                                |
| `/ak-tests-review`         | Inside /ak-check-docs-and-tests (or standalone)            | Fresh-eyes coverage + quality audit of tests in a commit range. Section A (coverage of new behavior), Section B (test quality — 11 sub-sections incl. Test Assertion Depth, Skipped Tests Audit, Wrapper API design, Runtime validation at LLM/edge boundaries), Section C (bypass-trailer audit). Renamed from `/ak-test-review` in PR-A.                                                                                                                                                                  |
| `/ak-status`               | Start of any session                                       | One-paragraph orientation briefing (read-only)                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `/ak-handoff`              | When context is filling up                                 | Writes `.handoff/<name>.md` so a fresh session can continue this work. Detects session slug + permission mode, emits a one-line `claude -n <name>__continuation_<n> "..."` bootstrap command + `/rename` line for the current session. (`.handoff/` is gitignored in the project template.)                                                                                                                                                                                                                 |
| `/ak-new-project`          | New project setup                                          | Create repo (Phase A) + guided setup (Phase B). Single entry point.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `/ak-migrate-project`      | Adopt devshop on existing project                          | Skeleton — two tiers (lightweight, full). See ROADMAP.md.                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `/ak-merge-devshop`        | Land a devshop feature branch into main                    | Audit (`/ak-check-docs-and-tests`) + squash on the feature branch (`git rebase origin/main` → `git reset --soft origin/main` → `git commit -F` — format spec in the skill) + ff-merge main to the squash commit + push + delete feature branch local + remote. Squashing on the feature branch dodges `check-branch-not-main.sh` structurally, and ff-merge creates no new commit on main, so the skill is autonomous end-to-end. Idempotent across phases. Replaces the manual `git merge --ff-only` flow. |

> **Skill autocomplete**: The `name` field in SKILL.md frontmatter drives `/` autocomplete,
> not the directory or symlink name. When adding or renaming a skill, set `name: ak-<skill>`
> in the frontmatter to match the desired slash command.
>
> **Skill layout convention** (load-bearing — required for autocomplete discovery):
> a new devshop skill has TWO entries on disk —
>
> 1. Real content at `/devshop/.claude/skills/devshop/<short-name>/SKILL.md`
>    (no `ak-` prefix in the directory name).
> 2. Symlink at `/devshop/.claude/skills/ak-<short-name>` →
>    `devshop/<short-name>` (relative target, matches peer pattern).
>
> The sync script `kit/scripts/sync/create-devshop-symlinks.sh` walks
> `/devshop/.claude/skills/*` looking for **symlinks only** (`if [ -L ]`),
> then propagates each one to `/workspace/.claude/skills/`. Real
> directories at the top level of `/devshop/.claude/skills/` are
> silently ignored — a real-dir skill works in `/devshop` sessions
> but never reaches `/workspace`. After adding a new skill, run
> `bash kit/scripts/sync/create-devshop-symlinks.sh /workspace` (or
> restart the container) to populate the workspace-side symlink.
