# Devshop Plan Gaps & Holes

Identified during plan review (2026-04-05) before Phase 0a implementation.
Reviewed 2026-04-13 after devshop separation. Resolution status annotated per gap.

---

## 1. No dependency vulnerability scanning until Phase 2

Dependabot is deferred to Phase 2. gitleaks catches secrets, not CVEs in npm packages.
Phases 0 and 1 ship with zero automated detection of known vulnerabilities in the
dependency tree. A compromised transitive dependency goes unnoticed.

**Recommendation**: Move Dependabot to Phase 0a. Single YAML file, zero cost.

> **Status (2026-04-13): FIXED.** Added `.github/dependabot.yml` to project repo.

## 2. No staging environment — migrations hit production untested against real data

Local `supabase start` and CI both run migrations against fresh DBs from seed.sql.
Neither tests against production data shapes. Data-dependent migration failures
(NOT NULL on columns with legacy nulls, table locks on large tables) only surface
in production.

`-- ROLLBACK` and `pg_dump` are recovery, not prevention.

**Recommendation**: Add a step to `/post-merge` that restores the latest pg_dump into
a temporary local Supabase and runs the new migration against it before deploying.
Or at minimum, make every migration a "stop and ask" item with human review against
production schema.

> **Status (2026-04-13): ROADMAP v1.** Added "Staging migration validation" to devshop ROADMAP. Migrations are already "stop and ask" per CLAUDE.md confidence calibration.

## 3. No data validation library — "never trust client input" without tooling

No Zod, Yup, or equivalent specified. Without one: every API wrapper hand-rolls
validation, validation logic doesn't compose, runtime validation drifts from
TypeScript types, "invalid input" tests have no schema to test against.

**Recommendation**: Add Zod to `packages/core`. Define validation schemas alongside
API wrappers. `/implement` uses them at all external input boundaries.

> **Status (2026-04-13): PROJECT DECISION.** Routed to project TODOS.md § Architecture decisions. Decide during Phase 1c implementation.

## 4. No state management architecture for a realtime collaborative app

Shared household list with Supabase Realtime. Multiple concurrent users. Plan
specifies Realtime channels but doesn't address:

- Client reconciliation of Realtime events vs local state (optimistic updates?)
- Subscription lifecycle (mount/unmount/reconnect)
- Auth state vs list state relationship
- UI during gap between optimistic update and Realtime confirmation

Without this, `/implement` makes ad-hoc decisions that create subtle bugs ("my list
shows an item my wife deleted 30 seconds ago").

**Recommendation**: Pick a strategy and document in spec:
(a) Realtime as sole source of truth (no optimistic updates — simpler, feels laggy)
(b) React Query + Realtime invalidation (optimistic + reconciliation)
(c) Raw useState + Realtime (simplest, fine for small lists in v1)

> **Status (2026-04-13): PROJECT DECISION.** Routed to project TODOS.md § Architecture decisions. Decide during Phase 1e spec.

## 5. No i18n architecture for a bilingual app

"Voice-first bilingual grocery list" — edge function handles bilingual NLP, but the
web UI has zero i18n consideration. Are UI strings English-only? Spanish? Both?
Language selectable or auto-detected? Where do translations live?

**Recommendation**: Make an explicit decision. If bilingual UI is v1, add next-intl.
If deferred, document in PRODUCT-ROADMAP.md.

> **Status (2026-04-13): PROJECT DECISION.** Added "Bilingual UI (i18n)" to PRODUCT-ROADMAP.md v+.

## 6. Pre-ship pipeline too heavy for every PR

`/pre-ship` chains 11 steps. Several involve browsing a running app (QA, design-review,
benchmark). Realistically 30-60+ minutes per PR. For a one-line bug fix. For a docs
update. Tiered pipeline deferred to `.devshop/ROADMAP.md` v1, but friction will kill
discipline — the first skip establishes that the process is optional.

**Recommendation**: Implement minimal tiers in v0:

- `/pre-ship --light` (docs/config/styling): lint + tests + /review + /ship
- `/pre-ship` (default features): full pipeline
- `/pre-ship --full` (schema/auth/security): everything
  Three if-statements in the skill prompt, not sophisticated auto-detection.

> **Status (2026-04-13): ROADMAP v1.** Already captured as "Tiered pre-ship pipeline" in devshop ROADMAP. The minimal 3-if approach is noted there as an option.

## 7. Single-agent `/implement` will hit context walls during Phase 1

Phase 1 has 8 sub-phases (1a-1h), each with multiple tasks. Reference docs alone
consume significant context. By task 15, earlier decisions are compressed/lost.
Resume pattern (new session reads TASKS.md) loses nuanced decision context.

**Recommendation**: Break Phase 1 into separate `/implement` runs per sub-phase,
each with its own SPEC.md and TASKS.md. Don't run all of Phase 1 as one invocation.

> **Status (2026-04-13): ROADMAP v1.** Already captured as "Subagent architecture for /implement" in devshop ROADMAP. The practical workaround (break into sub-phase runs) is operational guidance, not a code change.

## 8. No local dev workflow documentation

How to start the dev server, what env vars are needed, local vs remote Supabase,
which port, how to access — none of this is documented. Basic DX that new sessions
and the resume pattern rely on.

**Recommendation**: Add "Local Development" section to `.devshop/GUIDE.md` with exact
commands and env var requirements.

> **Status (2026-04-13): RESOLVED.** GUIDE.md § Local Development (line 703) documents both DinD and non-DinD workflows with exact commands.

## 9. Public mirror complexity disproportionate to value

mirror-sync.sh, test-mirror-sync.sh (8 test cases), check-devshop-commit-msg.sh
(PreToolUse hook), public-mirror.yml, ---devshop--- dividers, [private] annotations,
CLAUDE.md section stripping, post-push leak verification.

Every commit has cognitive overhead. Every new file needs classification. The hook
can block commits on formatting.

**Question to revisit**: Does the portfolio value justify this ongoing cost? If the
primary motivation is "nice to have," consider deferring to v1 or just making the
repo public with devshop files included (they're process docs, not secrets).

> **Status (2026-04-13): RESOLVED BY SEPARATION.** The devshop separation architecture eliminates mirror entirely. Project repo is clean and publishable by design — no mirror-sync, no devshop-commit-msg hook, no section stripping, no `---devshop---` dividers.

## 10. No accessibility testing automation

"Accessible (keyboard nav, labels, contrast)" stated as a principle, but no
automated enforcement: no axe-core in Playwright, no eslint-plugin-jsx-a11y,
no Lighthouse CI. Manual checks will be forgotten by screen three.

**Recommendation**: Add eslint-plugin-jsx-a11y to ESLint config (Phase 0a).
Add @axe-core/playwright to E2E tests (Phase 1e). Low cost, high value.

> **Status (2026-04-13): PARTIALLY RESOLVED.** ESLint part already active — `eslint-plugin-jsx-a11y` bundled via `eslint-config-next/core-web-vitals`. Runtime part (axe-core/Playwright) added to devshop ROADMAP v1 as "Accessibility testing in E2E".

## 11. No structured logging — blind spot between crash and analytics

Sentry catches crashes. PostHog tracks user actions. Gap: application-level
operational logging. When a user reports "my item didn't appear," you need edge
function logs, query timing, auth flow steps. Supabase has logging but it's not
structured or correlated with user-facing issues.

**Recommendation**: At minimum document as known limitation. Consider structured
console.log in edge functions with a standard format. Revisit after first production
debugging session reveals what's actually needed.

> **Status (2026-04-13): ROADMAP v+.** Added "Structured logging for edge functions" to devshop ROADMAP v+. Revisit after first production debugging session.

---

## Minor gaps (from initial review)

- ~~`.gitignore` entry for `.devshop/template-remote` referenced but never explicitly created~~ — **RESOLVED BY SEPARATION.** No template-remote in new architecture.
- ~~Minor inconsistency: Step 9 mentions `<!-- synced-from -->` markers but Step 3 uses heading-based injection for CLAUDE.md sync~~ — **RESOLVED BY SEPARATION.** Sync mechanism replaced by symlink injection.
- ~~`check-file-headers.sh` created but never called by anything (not pre-commit, not /pre-ship script)~~ — **FIXED.** Wired into pre-ship Gate 11 convention check (runs with branch arg in pre-ship mode).
- ~~`PRODUCTION_URL` repository variable not listed in "Required Repository Variables" section~~ — **RESOLVED.** Already in GUIDE.md init checklist (line 420).
- Branch protection listed in "Prerequisites" but must happen after first PR lands — **STILL VALID.** Operational sequencing note, not a code gap.
