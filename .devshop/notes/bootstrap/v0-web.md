# Dev-Shop Setup Plan

> **Status**: Historical build plan (construction record for the lalista devshop).
> Living docs are the source of truth: `.devshop/GUIDE.md`, `.devshop/CLAUDE.md`, `.devshop/FAQ.md`, skill files.
>
> **Content only in this file** (not migrated to living docs):
>
> - Phase 1 steps (1a-1h) — lalista Swift → React migration pattern
> - Detailed CI YAML examples for slow job (lines ~1065-1100)
> - METRICS.md initial event taxonomy for lalista (lines ~1690-1715)
> - Auth flow architecture with household onboarding (lines ~1860-1869)
> - Verification checklists for Phase 0a/0b/1 (historical)
> - Files to Create/Modify table (lines ~2018-2073)
>
> Sections marked with `⚠️ NOT IN LIVING DOCS` contain content not found elsewhere.
> All other sections have been migrated. Search for the marker to find gaps.
>
> **Original scope**: Web devshop + lalista web app. Native/mobile in `v+-native.md`.

---

## What This Is

A plan to build a professional one-person dev shop — from scratch to a repeatable system that goes from spec doc to deployed, tested, observable app with minimal manual intervention.

**Guinea pig project**: "lalista" — a voice-first bilingual grocery list app. Currently built in Swift/SwiftUI + Supabase; being migrated to React (Next.js web app first, native mobile later). The migration validates the dev-shop machinery while producing a real app.

**End state after this plan**:

- Web app on Vercel (Next.js)
- Shared business logic in a Turborepo monorepo (packages designed platform-agnostic for future mobile)
- Full CI/CD pipeline (GitHub Actions)
- Error monitoring (Sentry), analytics + feature flags (PostHog)
- Automated test-fix loop (Claude Code handles it in interactive session)
- Release approval workflow (PR review → merge → deploy)
- Dev-shop layer portable to future projects via template repo + sync scripts

**Future** (see `.devshop/notes/bootstrap/v+-native.md`):

- iOS app via Expo + EAS
- Siri integration, Mac app, Android

---

## User Profile (Context for All Decisions)

- **Dev skill**: TypeScript + Python pattern-matcher. Can extend existing code fluently, builds new things slower using standard frameworks + AI. Can code-review and debug. Has shipped apps with Supabase + Edge Functions.
- **AI tools**: Claude Code CLI as primary tool. The key frustration: manually feeding test output back to Claude after failures. The dev-shop solves this.
- **Environment**: Mac + VS Code + devcontainers exclusively. Likes to keep Mac isolated. This Claude Code session IS running inside the devcontainer.
- **Budget**: Free tiers preferred. Small paid things OK ($5/mo VPS, $99/yr Apple Dev account).
- **Surfaces**: Web first. iOS + Mac + Android later via Expo (same monorepo — see `.devshop/notes/bootstrap/v+-native.md`).
- **Autonomy preference**: Claude runs autonomously, stopping only when stuck (same error 3x), drifting, or facing a low-confidence decision (schema changes, auth, security, new integrations). Log completed tasks clearly. Never ship code without tests. Never break existing tests.

---

## Current Repo State

- **GitHub repo**: Exists, called "lalista" — rename to `lalista-dev` (private). The public mirror will be `lalista`. See "Repo Naming Convention" below.
- **Branch**: `main` is the single branch, clean state
- **Existing stack**:
  - `ios/` — Swift/SwiftUI app (iOS 17+, SwiftUI, Supabase iOS SDK, SnapshotTesting)
  - `supabase/migrations/` — 7 SQL migration files (PostgreSQL 17, RLS, pg_trgm)
  - `supabase/functions/add-item/` — TypeScript/Deno edge function (Claude NLP, fuzzy matching, store routing)
  - `package.json` — placeholder only, no deps
  - `DESIGN.md` — complete design system (keep; extend for web)
  - `TODOS.md` — open items (most will be resolved by migration; see notes below)
  - `.devcontainer/` — Node 20 devcontainer with egress firewall
  - `.claude/` — Claude Code config + gstack skills (gstack is the AI lifecycle toolkit)
- **No CI/CD exists yet**
- **Supabase**: Remote project already live (dev environment). No local Docker-based Supabase.

### What to Do with the Swift App (`ios/`)

Rename to `ios-archive/` in Phase 1 step 1a (keep for reference during porting to web). Delete after all screens are ported.

### Open TODOS to Carry Forward

- `posted-by-someone`: UI bug — shows "by someone" instead of username. Carry into Phase 1 (needs user profile in Supabase Auth).
- `redeploy-add-item-without-no-verify-jwt`: Blocked on Supabase fixing ES256 support. Carry to new TODOS.md; do not implement now. Mitigated by `getUser()` server-side validation added in Phase 1f.
- All other items (threshold tuning, VoiceOver audit, disambiguation polish): Post-v0. Migrate to new TODOS.md after Phase 1.

---

## Tooling Already in the Devcontainer

Pre-installed (from `Dockerfile`):

- Node 20 (base image)
- `npm` (global installs), `bun` (fast JS runtime — used by gstack)
- `git`, `gh` (GitHub CLI), `jq`
- Supabase CLI (`supabase`)
- Claude Code CLI (`claude`)
- Oh My Zsh, fzf, git-delta
- `pnpm` — monorepo package manager
- DCG (Destructive Command Guard) — safety hook for Claude Code
- gitleaks ��� secret scanning

**Missing — must add to `devcontainer.json`**:

- Docker-in-Docker feature — required for `supabase start` (spins up ~10 Docker containers for local Postgres, Auth, Realtime, etc.). Uses an isolated Docker daemon inside the devcontainer rather than mounting the host Docker socket. This preserves the firewall as a real security boundary — the host Docker is untouched, and all containers run inside the devcontainer's isolated daemon.

**Resource requirements**: DinD + Supabase local stack requires **16GB RAM minimum** (recommend 32GB). On macOS this means 3 layers of virtualization (macOS → Docker Desktop VM → devcontainer → DinD → Supabase containers). If hardware is constrained, skip `supabase start` locally and use `pnpm turbo run test:unit` for the fast inner loop — integration tests run in CI regardless. See "Testing Lifecycle" in .devshop/GUIDE.md.

---

## Firewall Constraint (Critical)

The devcontainer has an egress firewall (`init-firewall.sh`) that only allows outbound traffic to an explicit allowlist. This is a **real security boundary** — it constrains what Claude Code and any code running in the container can reach over the network. Combined with Docker-in-Docker (no host socket access), the container is genuinely sandboxed.

Current allowed domains include: `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `api.supabase.com`, GitHub IPs, VS Code servers.

**Missing domains — must add to `init-firewall.sh` before Phase 0**:

Devshop-level (same for all projects):

- `vercel.com` + `api.vercel.com` — Vercel CLI (initial project link)
- `cdn.jsdelivr.net` — used by some npm package install scripts
- `objects.githubusercontent.com` — binary downloads from GitHub releases
- `fonts.googleapis.com` + `fonts.gstatic.com` — Next.js `next/font` downloads fonts at build time (`fonts.google.com` is the website, not the CDN)

Project-specific (added per-project during Phase 0b setup — mark with `# === PROJECT-SPECIFIC DOMAINS ===` comment in the firewall script):

- `<ref>.supabase.co` — your specific Supabase project URL (used by `supabase gen types` and the JS client)
- `o<org-id>.ingest.sentry.io` — your specific Sentry ingest endpoint (the SDK doesn't send to `sentry.io` directly)
- `us.i.posthog.com` or `eu.i.posthog.com` — PostHog ingest endpoint (depends on region; the SDK doesn't send to `posthog.com`)
- `registry-1.docker.io` + `auth.docker.io` + `production.cloudflare.docker.com` — Docker Hub (if using `supabase start` or other Docker Hub images for integration tests)

**IP rotation risk**: CDN domains like `fonts.gstatic.com` rotate IPs. The firewall resolves IPs at container start — if a build fails on a network error for an allowed domain hours later, restart the container to re-resolve.

Note: GitHub Actions CI/CD runs on GitHub's servers, not in the devcontainer — Vercel deploys triggered by CI don't need the firewall updated. But `vercel login` and initial setup run inside the container and do need these domains.

---

## Accounts to Set Up Before Phase 0

All **[HUMAN]** steps — the user must complete these before code execution:

| Service             | Action                                                                                                                                           | Cost                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| **Vercel**          | Create account at vercel.com, install Vercel GitHub App, create personal access token at `vercel.com/account/tokens`                             | Free                |
| **Sentry**          | Create account at sentry.io, create "lalista" project (React)                                                                                    | Free (5k errors/mo) |
| **PostHog**         | Create account at posthog.com, create "lalista" project                                                                                          | Free (1M events/mo) |
| **Supabase**        | Create personal access token at `supabase.com/dashboard/account/tokens` (project already exists)                                                 | Free                |
| **Apple Developer** | Enroll at developer.apple.com — required for Sign in with Apple on web (Service ID + domain verification). Start early, approval takes 1-2 days. | $99/yr              |

---

## Architecture Decisions (With Rationale)

### Why Turborepo + pnpm?

Turborepo provides fast, incremental builds across monorepo packages with free remote caching. pnpm is faster than npm for monorepos (hard-links, no duplication). Both are standard, well-maintained, and free. The monorepo structure (`apps/web`, `packages/core`, `packages/ui`) is designed to support future mobile apps without migration.

### Why Next.js 15 (App Router)?

Best-in-class React framework. Zero-config Vercel deployment. SSR + SSG + good SEO out of the box. App Router is the current standard (Pages Router is legacy).

### Why Vitest (web)?

Faster and TS-native for Next.js. Single test runner for the web-first phase.

### Why Playwright (web E2E)?

Best-in-class web E2E tool, runs in GitHub Actions. Covers visual regression via screenshot comparison.

### Why NOT Storybook/Chromatic?

Too much overhead for a solo dev. Playwright screenshot comparison covers visual regression without a separate tool or service.

### Platform-agnostic shared packages

`packages/core` and `packages/ui` must NOT contain Next.js-specific imports. They export pure TypeScript — framework-agnostic logic and design tokens. This ensures future mobile apps can import them without modification. Each consuming app (`apps/web`, future `apps/mobile`) handles its own framework integration.

---

## Dev-Shop Architecture

### gstack + Claude Code Division of Labor

gstack (already installed in `.claude/skills/gstack/`) provides the full lifecycle except implementation. Claude Code fills the gap.

```
SPEC PHASE       → gstack: /office-hours → /autoplan (CEO + design + eng review)
DESIGN SPEC      → gstack: /design-consultation → produces DESIGN.md
DESIGN EXPLORE   → gstack: /design-shotgun (optional — visual variants before spec, UI-heavy features only)
DESIGN PROTOTYPE → gstack: /design-html (optional — turns approved mockup into HTML reference for Claude)
IMPLEMENTATION   → Claude Code: autonomous loop (write code + tests, fix failures)
SIMPLIFY         → gstack: /simplify (after tests green, before review — every PR)
CODE REVIEW      → gstack: /review (staff engineer perspective)
SECURITY AUDIT   → gstack: /cso (every PR; infra baseline at Phase 0 completion)
QA               → gstack: /qa (finds bugs, fixes, adds regression tests)
DESIGN QA        → gstack: /design-review (every PR touching UI — visual audit + fixes)
PERF AUDIT       → gstack: /benchmark (every PR — Core Web Vitals + load time regression)
SHIP             → gstack: /ship (creates PR, runs tests, coverage audit)
DEPLOY           → gstack: /land-and-deploy (merge → wait for CI → verify prod)
MONITORING       → gstack: /canary (post-deploy error/perf watch loop)
DEBUGGING        → gstack: /investigate (Claude runs autonomously when stuck 3x; user triggers for prod bugs)
DOCS             → gstack: /document-release (keeps docs in sync after ship)
RETRO            → gstack: /retro
```

**What this means**: The dev-shop is already ~70% assembled via gstack. What this plan builds is:

1. Repo + CI/CD infrastructure (the foundation gstack runs on)
2. The Claude Code implementation loop conventions (spec → code → tests)
3. The glue (CLAUDE.md, .devshop/GUIDE.md conventions) that makes handoffs clean

### The Full Workflow (Idea → Deployed)

```
1.  You write rough notes          → problem description + rough solution idea (not a full spec)
2.  /office-hours (gstack)        → interviews you, challenges framing, produces product design doc
3.  /autoplan (gstack)            → eng/CEO/design review; locks in architecture, edge cases, decisions
3b. /design-shotgun (optional)    → visual variants if feature is UI-heavy; approve one direction
3c. /design-html (optional)       → HTML reference from approved mockup; Claude builds React from this
4.  /spec (custom command)        → converts gstack plan into implementation-ready spec in specs/
5.  /implement (custom command)   → implements: write code + tests, run, fix failures, loop until green
                                    if stuck 3x: runs /investigate autonomously before pinging you
6.  /pre-ship (custom command)    → chains: docs check → metrics check → responsive+theme check (if UI)
                                    → /simplify → /test-review → /review → /cso → /qa
                                    → /design-review (if UI) → /benchmark (if UI) → /ship
                                    pauses between steps if findings; auto-advances on clean passes
7.  CI (auto)                     → lint + typecheck + tests + build + gitleaks
8.  Vercel (auto)                 → preview deploy URL appears in PR
9.  You review PR                 → release notes + test results + preview URL
10. You merge
11. /post-merge (custom command)  → chains: /land-and-deploy → /canary → structured reflection
```

### `/spec` Command (Step 4)

A custom devshop skill defined in `.claude/skills/devshop/spec/SKILL.md`. Run it after `/autoplan` has locked in architecture and resolved decisions:

```
/spec
```

The command first checks if `METRICS.md` exists. If not (first feature on a new project), it reads the gstack autoplan output and drafts the initial event taxonomy — deriving events from the user actions, data flows, and key decisions in the plan. It presents the draft to the user for review ("Here's the initial metrics taxonomy I derived from the plan — confirm, adjust, or add events before I continue"). This is a "stop and ask" item per the confidence calibration (new metric event definitions require review). Once confirmed, it writes `METRICS.md`.

Then it reads the gstack plan output and judges whether it's already detailed enough for Claude Code to implement from directly. Criteria: does it specify all user-facing behaviors including error states, exact data model changes, API contracts, and out-of-scope items?

- **If yes**: outputs a one-liner confirming the gstack plan is the spec, and Claude Code should read it directly. No spec file written.
- **If no**: writes `specs/<feature-name>.md` filling the gaps — the missing detail only, not a full rewrite:
  - User-facing behaviors not yet specified (happy path + error states)
  - Data model changes (exact schema diffs)
  - API contracts (endpoints, inputs, outputs, auth requirements)
  - Service dependencies
  - Explicit out-of-scope items
  - **Metrics** section — references specific events from `METRICS.md` that this feature touches (existing events to instrument + new events to define). If the feature introduces a new user action not in `METRICS.md`, adds the event definition to `METRICS.md` first, then references it.

If `METRICS.md` exists but the feature introduces new user actions not yet in the taxonomy, `/spec` proposes the new events and asks for confirmation before adding them to `METRICS.md`.

Then writes `SPEC.md` as a pointer: `# Active spec\nSee specs/<feature-name>.md`

`SPEC.md` is the stable entry point — Claude Code and gstack skills always read it first. **SPEC.md is branch-aware**: each feature branch has its own `SPEC.md` pointing to its own spec. The `main` branch typically has no `SPEC.md` (or it's empty after merge). This supports clean context switching — if a hotfix interrupts a feature, switch branches and each branch retains its own spec context. `/implement` reads `SPEC.md` from the current branch.

The spec itself lives in `specs/` from day one, accumulating as a permanent record. `specs/` files are merged to `main` with the feature — they're the permanent record. Preserves the full traceability chain (bug → code → spec → plan) for future debugging and `/investigate` sessions.

The spec file must begin with machine-parseable provenance so `/implement` can trace back to the gstack plan:

```
<!-- gstack-plan: .gstack/projects/<slug>/<plan-file>.md -->
<!-- generated-by: /spec -->
<!-- date: YYYY-MM-DD -->
```

**Guard**: if `METRICS.md` is missing and this is not the first feature (i.e., the project has existing code), error with: "METRICS.md not found — create it before running /spec. See .devshop/GUIDE.md new-project checklist."

Asks only if something is genuinely ambiguous after reading the plan. No decision Q&A — that was done by `/autoplan`'s eng review.

### Step 5: Implementation — How to Run It

From the repo root in the devcontainer:

```
/implement
```

The `/implement` skill (`.claude/skills/devshop/implement/SKILL.md`) handles the full loop:
reads SPEC.md → traces the gstack plan → checks TASKS.md (new vs resume) → implements
each task sequentially → verifies completion → moves to next task →
prints completion summary and handoff to `/pre-ship`.
If TASKS.md doesn't exist, create it by breaking the spec into tasks (using the TASKS.md format defined below). If it exists, resume from the first non-done task.

**v0: Single-agent implementation.** The `/implement` agent reads the full spec and implements tasks sequentially in a single context. With 1M context, this is sufficient for the lalista web migration and likely for most single-feature implementations. Subagent architecture (orchestrator spawning per-task subagents to preserve context) is deferred to .devshop/ROADMAP.md v1 — add it when context pressure is actually observed, not preemptively.

Before starting implementation, the agent reads `.devshop/GUIDE.md § Shared Conventions` for the testing philosophy, backlog routing guide, and metrics lifecycle. These are referenced, not duplicated in the skill prompt.

**Hats** — the agent wears a primary hat per task based on what it touches:

- **Frontend** (components, pages, styles): "Does this feel right?" Visual fidelity to DESIGN.md. Every screen needs loading, empty, and error states — not just the happy path. Every route has an `error.tsx` boundary; components that do async work (data fetching, realtime) have their own error boundary with retry affordance. Accessible by default (keyboard nav, labels, contrast). Mobile-first: build for 375px, then scale up — test at 375px before moving on. Use theme tokens from `tokens.ts`, never hardcoded colors. Verify both light and dark themes. Would you be embarrassed showing this to someone on their phone?
- **Backend/Data** (migrations, RLS, edge functions, API wrappers): "Can this corrupt data or leak it?" Correctness first, then performance. Never trust client input. RLS boundary tests for every table with policies. Auth validation at every edge function entry. Idempotent where possible. Would this survive a malicious user?
- **Product/PM** (scope decisions, edge cases, UX tradeoffs): "Would a real user hit this?" Not every error needs a custom screen. Not every edge case needs handling in v1. If you're spending more than 5 minutes on an edge case, check if it's in the spec — if not, add it to TODOS.md as `[discovered]` and move on. Does this solve the stated problem without gold-plating?

A single task can involve multiple hats (e.g., a form component is frontend + product), but the primary hat sets the quality bar.

**Clarification escalation** — when the agent hits ambiguity that blocks progress, it triages using the confidence calibration list in CLAUDE.md:

- Can answer from spec/plan/existing context → makes the call, notes in commit message
- Falls under "stop and ask" (schema changes, auth, security, new integrations, new metric definitions) → stops and asks user
- User escalation format: which task, what the ambiguity is, options considered, agent's lean (if any)

**TASKS.md format** — Claude uses this structure per task:

```markdown
## Task: [name]

**Hat**: FE | BE | Data | PM
**Depends on**: [task names or "none"]
**Blocks**: [task names or "none"]
**Done when**: [concrete, testable criterion — tests pass, endpoint returns X, etc.]
**Risk**: low | medium | high
**Status**: todo | in_progress | done | blocked
```

**Resume pattern** — when a session is interrupted, start a new session with:

```
claude "use a sub-agent to read TASKS.md and recent git log,
then tell me in one paragraph: which tasks are done, which is next,
what context I need to continue"
```

Sub-agent reads the file; main session gets a short summary — no context pollution.

### Step 6: Pre-Ship — How to Run It

```
/pre-ship
```

The `/pre-ship` skill (`.claude/skills/devshop/pre-ship/SKILL.md`) chains the quality gates:

1. Devshop docs consistency check — if PR touches `.devshop/` or reference docs (`.devshop/OVERVIEW.md`, `.devshop/GUIDE.md`), verify both are in sync
2. **Metrics check** — if the PR touches user-facing code (components, API wrappers, edge functions), verify it has corresponding `posthog.capture()` calls. Cross-reference against `METRICS.md`: are all events for this feature instrumented? If no metrics found in a user-facing PR, pause and ask — don't auto-advance.
3. **Responsive + theme check** (only if PR touches UI files) — verify the app at: 375px light, 375px dark, 1440px light, 1440px dark. Check for: overflow/scroll issues, unreadable text, untappable buttons (min 44px touch target), hardcoded colors not using theme tokens, broken layouts. Pause if any issues found.
4. `/simplify` — code quality pass
5. `/test-review` — dedicated test quality review (reads tests alongside code with no implementation context; flags weak assertions, missing error/edge paths, untested auth boundaries)
6. `/review` — staff engineer code review
7. `/cso` — security audit
8. `/qa` — QA pass (catches any simplify regressions)
9. `/design-review` — visual audit (only if PR touches UI files)
10. `/benchmark` — performance regression check (only if PR touches UI files)
11. `/ship` — creates PR with release notes

**Behavior**: after each step, if the step produced findings (review flagged issues, QA found bugs, CSO flagged a vulnerability), pause and show findings. If a step passes clean, auto-advance to the next step. This way you don't watch six green checkmarks scroll by, but you DO see and address problems.

### Step 11: Post-Merge

```
/post-merge
```

The `/post-merge` skill (`.claude/skills/devshop/post-merge/SKILL.md`) chains:

1. `/land-and-deploy` — merge → wait for CI → verify prod is healthy
2. `/canary` — post-deploy monitoring for ~15 min
3. **Rollback checkpoint** — record in the PR comment: Vercel deployment ID (`vercel ls --meta`), current migration version (latest file in `supabase/migrations/`), and git SHA. If canary fails, this is where you revert to (see "When Things Go Wrong" in .devshop/GUIDE.md).
4. Structured reflection — routes learnings to durable, committed locations:
   - New conventions, gotchas, calibration updates → `CLAUDE.md`
   - Troubleshooting entries → `.devshop/GUIDE.md` (Troubleshooting section)
   - Decision log entries → `.devshop/GUIDE.md` (Decision Log section)
   - Devshop friction → `.devshop/TODOS.md` (tactical) or `.devshop/ROADMAP.md` (strategic) per the backlog routing guide

### Confidence Calibration (Lives in CLAUDE.md, Evolves Over Time)

```
PROCEED AUTONOMOUSLY:
- UI components + their tests
- Extending existing API endpoints
- Bug fixes with clear root cause + confirming test
- Styling / design token changes
- Documentation updates
- Adding new Supabase queries (no schema changes)
- Instrumenting metrics for events already defined in METRICS.md

STOP AND ASK (before implementing):
- New database columns/tables (migrations are hard to reverse; must verify locally via `supabase start` before pushing — there is no staging database, only local + CI verification)
- Auth flow changes
- New third-party API integrations not yet in codebase
- Performance-sensitive code paths
- Security-related logic — stop before writing, get human sign-off on approach; /cso still runs after
- Anything requiring deletion of existing tests
- New metric event definitions (add to METRICS.md requires review)
```

### Non-Negotiables (Enforced by Pre-Commit Hooks + CI)

- **No code without tests** — tests written alongside, never after
- **No code that breaks existing tests** — full test suite runs before marking done
- **No code without metrics** — every user-facing feature must have corresponding events in `METRICS.md`, instrumented in the same PR
- **Testing philosophy** (lives in `.devshop/GUIDE.md § Shared Conventions` — `/implement` references it, not copies):
  - Assert on **specific values**, not existence. `toBeDefined()` and `toBeTruthy()` are banned for return value assertions — assert the actual expected value.
  - Every API wrapper needs at least one test with **invalid input** (malformed data, missing fields) and one with **unauthorized access** (wrong user, expired token).
  - Test the **contract**, not the implementation. If you refactor internals, tests should still pass. If you change behavior, tests should break.
  - For UI: test user-visible outcomes, not internal state. "Button is disabled when form is empty" not "setDisabled was called."
  - For data: test **boundary conditions** — empty lists, single item, maximum length inputs, concurrent modifications where applicable.
- **Testing layers**:
  - Unit tests: mock external dependencies. For pure business logic only — validation, transforms, calculations with no DB dependency.
  - Integration tests: must hit a real local database instance (local Docker via Docker-in-Docker). Never mock the DB layer for tests that exercise queries, access control, or data integrity. For Supabase projects: `supabase start`. For other stacks: Docker Compose service.
  - Every project must include a `seed.sql` (or equivalent) that creates the minimum test fixtures needed to run integration tests in CI.
  - CI must include a step that regenerates types from the schema and fails if the committed types have drifted.
  - **Auth boundary tests (RLS)**: every table with Row Level Security policies must have at least one integration test that authenticates as User A, creates data, then authenticates as User B and verifies the data is **not** visible. RLS bugs are silent data leaks — unit tests that mock the DB can never catch them. This is not optional.
- **E2E tests are required for every user-facing flow** — written alongside the feature, never after. The CI job must land in the same PR as the tests. Playwright must run each E2E test at both mobile (375px) and desktop (1440px) viewports — configure as Playwright projects in `playwright.config.ts`. Both must pass.
- **CI enforcement lands in the same PR as the code it tests** — when a new testing layer is added (integration tests, E2E tests), the CI configuration to run those tests is part of the same PR. No gap between "tests exist" and "CI runs them."
- **Edge functions always validate auth server-side** — call `supabase.auth.getUser()` to verify the token against the auth server, even if the gateway does JWT verification. Defense in depth.
- **Per task**: `pnpm turbo run test:unit` green → metrics instrumented → `pnpm turbo run lint` (fix errors) → commit (lint-staged runs prettier automatically). Full `test` (unit + integration) is verified by CI — see "Testing Lifecycle" in .devshop/GUIDE.md.
- **Every PR**: `/pre-ship` (runs simplify → review → cso → qa → design-review → benchmark → ship)
- **Pre-commit**: husky + lint-staged → ESLint + Prettier + gitleaks secret scan on every commit, no bypass
- **CI mirrors runtime dependencies**: if the app connects to a database, message queue, or any stateful service at runtime, CI must start that service locally and run integration tests against it. Never skip integration tests in CI because "they work locally." Never hit a shared remote environment from CI. For Supabase projects: add `supabase start` + `seed.sql` load before tests, a type drift check step (`supabase gen types` → diff against committed types → fail if different), and mask `SUPABASE_SERVICE_ROLE_KEY` with `::add-mask::` in CI.
- **CI gate**: PR merge blocked if any check fails
- **Secrets in CI**: when adding a new service integration, wiring its secrets into `ci.yml` is part of the same PR — never a follow-up
- **Third-party binaries**: any binary downloaded during Docker build must be pinned to a specific version and verified with a checksum. Never use "latest" for binary installs. When upgrading, update both the version and the checksum in the same commit.
- **Shared packages export TypeScript source directly** — no build step. Set `"main": "src/index.ts"` in the package's `package.json`. Each consuming app is responsible for transpiling it (Next.js: `transpilePackages`; future Expo/Metro: native). Every package must have a `src/index.ts` barrel export — no deep path imports across package boundaries.
- **Web apps must be PWA-installable** — every web app ships with: `manifest.json` (app name, icons, theme color, `display: standalone`), Apple-specific meta tags (`apple-mobile-web-app-capable`, `apple-touch-icon`, status bar style). Users should be able to "Add to Home Screen" on iOS/Android. Service worker caching (`@serwist/next`) is deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable to avoid stale-data bugs during active development. Placeholder icons at scaffold time; replaced with real branding during design system migration.
- **Responsive from day one** — every web app must work (not just render — all interactive elements usable) from iPhone SE (375px) to large desktop (2560px). Mobile-first: build for 375px, scale up. `packages/ui/src/tokens.ts` defines breakpoints as the single source of truth; `tailwind.config.js` reads them. No hardcoded pixel widths in components. Playwright E2E runs at mobile (375px) and desktop (1440px) viewports — both must pass. Snapshot tests include mobile + desktop variants.
- **Light/dark theme required** — every web app supports both themes from launch. `packages/ui/src/tokens.ts` defines semantic theme tokens (e.g., `colors.background`, `colors.text`, not `colors.cream`). Tailwind config maps them to CSS custom properties. Theme follows `prefers-color-scheme` by default with an optional user toggle. No hardcoded colors in components — always use theme tokens. Snapshot tests include both themes. `/pre-ship` verifies the app at both themes before shipping.
- **Migration rollback convention**: every new migration file must end with a `-- ROLLBACK` comment block containing the SQL to reverse the migration. Not executed automatically — copy-paste ready for emergencies. `/pre-ship` verifies the block exists. CI validates the rollback SQL is syntactically valid by parsing it against the local Supabase Postgres (in the slow job, after `supabase start`). Example:
  ```sql
  -- ROLLBACK
  -- ALTER TABLE list_entries DROP COLUMN priority;
  ```
- **Simplest solution**: default to boring, standard, well-understood approach
- **Documentation**: every `.ts`/`.tsx` file has a 3-line header (`What` / `Why` / `Does NOT`); every exported function has a 1-2 sentence JSDoc. Written by Claude alongside the code, enforced by pre-commit + ESLint. Short on purpose — short docs stay accurate. `Does NOT` can be `N/A` when there's no meaningful scope boundary to state.

---

## Backlog Routing Guide

Four files track deferred work. Two questions decide where something goes:

1. **Who cares?** A user of the app → project row. A developer using the devshop → devshop row.
2. **When?** Fix/do soon → TODO. Build eventually → ROADMAP.

|             | Tactical (bugs, friction, small fixes) | Strategic (features, capabilities) |
| ----------- | -------------------------------------- | ---------------------------------- |
| **Project** | `TODOS.md`                             | `PRODUCT-ROADMAP.md`               |
| **Devshop** | `.devshop/TODOS.md`                    | `.devshop/ROADMAP.md`              |

### Version tags

TODO items can be scheduled into versions defined in their corresponding ROADMAP file:

```markdown
- [ ] Fix sync script conflict handling [v0.2]
- [ ] PWA service worker caching [v2]
```

ROADMAP files define what each version means (scope, theme, rough ordering). TODOs reference them.

### No cross-references between project and devshop rows

Project files (`TODOS.md`, `PRODUCT-ROADMAP.md`) never reference devshop files. They're self-contained — clean for the public mirror, clean conceptually. If a devshop limitation causes a product deferral, the product file states the deferral in product terms ("offline deferred — caching strategy TBD"). The devshop file independently tracks its own improvement.

Devshop files may include optional project context ("discovered during lalista auth implementation") since they're private, but it's context, not a dependency link.

### Examples

| Discovery                                      | File                  | Why                                                                                            |
| ---------------------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------- |
| "Add to Home Screen" broken on Android         | `TODOS.md`            | Project bug, fix soon                                                                          |
| Service worker caching for offline             | `PRODUCT-ROADMAP.md`  | Product feature, later                                                                         |
| Sync script can't handle merge conflicts       | `.devshop/TODOS.md`   | Devshop friction, fix soon                                                                     |
| `/implement` should support parallel subagents | `.devshop/ROADMAP.md` | Devshop capability, later                                                                      |
| Native/mobile devshop support                  | `.devshop/ROADMAP.md` | Major devshop capability (see `.devshop/notes/bootstrap/v+-native.md` for the build blueprint) |
| `check-file-headers.sh` slow on large diffs    | `.devshop/TODOS.md`   | Devshop friction                                                                               |

### When routing happens

- **`/implement` subagents**: route discoveries using the two questions above. Project bugs/features → project files. Devshop friction → devshop files.
- **`/pre-ship`**: flags items that appear to be in the wrong file.
- **`/post-merge` structured reflection**: explicitly asks "any devshop friction?" and routes answers to `.devshop/TODOS.md` or `.devshop/ROADMAP.md`.
- **During devshop construction (this plan)**: when the plan says "v0: simple" with a better future version, the v0 goes in `.devshop/TODOS.md` with a version tag. Major capability additions go in `.devshop/ROADMAP.md`.

---

## Repository Structure (Target After Phase 0)

```
lalista/
├── .devshop/
│   ├── scripts/
│   │   ├── sync-to-template.sh     ← push dev-shop changes to abra-kadabra repo
│   │   ├── sync-from-template.sh   ← pull dev-shop updates into this project
│   │   ├── release.sh              ← bump version + tag (for direct template edits)
│   │   ├── mirror-sync.sh          ← commit-by-commit mirror to public repo
│   │   └── check-devshop-commit-msg.sh  ← PreToolUse hook: enforce ---devshop--- divider
│   ├── CLAUDE.md                   ← source for devshop section of root CLAUDE.md
│   └── version                     ← current dev-shop version (e.g. "0.1.0")
├── specs/                           ← one file per feature, permanent record
│   └── <feature-name>.md
├── SPEC.md                          ← pointer to active spec in specs/ (or absent)
├── apps/
│   └── web/                        ← Next.js 15 (App Router)
│       ├── app/                    ← pages + layouts
│       ├── components/             ← page-level components
│       ├── vercel.json             ← monorepo-aware build config
│       └── package.json
├── packages/
│   ├── core/                       ← shared TypeScript logic (framework-agnostic)
│   │   ├── src/
│   │   │   ├── supabase.ts         ← typed Supabase client factory
│   │   │   ├── supabase.types.ts   ← generated from supabase gen types
│   │   │   ├── api/                ← typed wrappers for edge functions
│   │   │   └── models/             ← shared data models + validation
│   │   └── package.json
│   └── ui/                         ← shared design tokens + web components
│       ├── src/
│       │   └── tokens.ts           ← design tokens as JS constants (single source of truth)
│       ├── tailwind.config.js      ← web (Next.js/PostCSS), imports from tokens.ts
│       └── package.json
├── supabase/                        ← EXISTING: keep as-is
│   ├── migrations/                  ← 7 migration files — keep all
│   └── functions/
│       └── add-item/                ← Deno/TypeScript edge function
├── ios-archive/                     ← renamed from ios/ (reference during Phase 1)
├── .github/
│   └── workflows/
│       ├── ci.yml                   ← lint + typecheck + test + build + gitleaks (on every PR)
│       └── public-mirror.yml        ← strip devshop files + push to public repo (on push to main)
├── .devcontainer/
│   ├── Dockerfile                   ← updated: DinD feature, no host socket
│   ├── devcontainer.json            ← updated: DinD feature, write-deny for Claude
│   └── init-firewall.sh             ← updated: add vercel.com + cdn.jsdelivr.net + fonts
├── .claude/
│   ├── settings.json                ← EXISTING: updated with DCG hook + write-deny rules
│   └── skills/
│       └── devshop/                 ← custom devshop skills
│           ├── spec/SKILL.md
│           ├── implement/SKILL.md
│           ├── test-review/SKILL.md
│           ├── pre-ship/SKILL.md
│           ├── post-merge/SKILL.md
│           ├── status/SKILL.md
│           └── init/SKILL.md
├── .gitleaks.toml                   ← gitleaks allowlist for known-safe public keys
├── .dcg.toml                        ← DCG project-level config
├── turbo.json                       ← Turborepo pipeline config
├── pnpm-workspace.yaml              ← packages: ["apps/*", "packages/*"]
├── package.json                     ← root: workspaces, husky, lint-staged
├─��� tsconfig.base.json               ← shared TypeScript baseline for all packages
├── eslint.config.mjs                ← flat config (migrated from .eslintrc.json in Phase 0a)
├── .prettierrc                      ← EXISTING: keep
├── .editorconfig                    ← EXISTING: keep
├── .devshop/OVERVIEW.md               ← bird's eye view (~60-80 lines)
├── .devshop/GUIDE.md                       ← full operational reference (living doc, grows over time)
├── .devshop/notes/bootstrap/v0-web.md  ← build blueprint: web devshop (this file; historical after Phase 0)
├── .devshop/notes/bootstrap/v+-native.md           ← build blueprint: native capability (deferred)
├── .devshop/TODOS.md                  ← devshop tactical backlog (friction, bugs, small fixes)
├── .devshop/ROADMAP.md               ← devshop strategic backlog (capabilities, major improvements)
├── PRODUCT-ROADMAP.md               ← project strategic backlog (features users would want)
├── TODOS.md                         ← project tactical backlog (bugs, minor fixes, blocked items)
├── METRICS.md                       ← event taxonomy + feature flags (project-specific)
├── DESIGN.md                        ← EXISTING: extend with web token mapping
└── CLAUDE.md                        ← EXISTING: devshop section + lalista section
```

---

## Dev-Shop Portability

**Principle**: Files are either the dev-shop layer (same across all projects) or the project layer (project-specific).

```
Dev-shop layer (templated — same for all projects, enumerated in .devshop/manifest.txt):
  .devshop/             ← includes .devshop/CLAUDE.md, manifest.txt, sync scripts
  .devcontainer/        ← includes DinD feature, firewall with devshop domains
  .claude/settings.json
  .claude/skills/devshop/  ← /spec, /implement, /pre-ship, /post-merge, /status
  .github/workflows/
  .gitleaks.toml        ← gitleaks allowlist for known-safe public keys
  .dcg.toml
  turbo.json
  pnpm-workspace.yaml
  tsconfig.base.json
  eslint.config.mjs
  .devshop/OVERVIEW.md   ← bird's eye view (reference)
  .devshop/GUIDE.md            ← full operational reference (living doc)
  .devshop/TODOS.md       ← devshop tactical backlog (template ships empty)
  .devshop/ROADMAP.md    ← devshop strategic backlog (template ships with standard items)
  (.devshop/notes/bootstrap/ are NOT synced — build blueprints are project-specific history)

Project layer (project-specific — unique per project):
  apps/
  packages/
  supabase/
  specs/      ← one file per feature, permanent record
  SPEC.md     ← pointer to active spec in specs/
  CLAUDE.md   ← devshop section (synced from .devshop/CLAUDE.md) + project section
  DESIGN.md
  METRICS.md  ← event taxonomy + feature flags
  README.md
  TODOS.md             ← project tactical backlog
  PRODUCT-ROADMAP.md   ← project strategic backlog
```

**abra-kadabra repo**: After Phase 0b is complete and validated, create a GitHub Template Repository called `abra-kadabra` containing only the dev-shop layer files.

**Repo naming convention**: the private development repo uses a `-dev` suffix; the public mirror gets the clean name. Example: `lalista-dev` (private, has devshop) → `lalista` (public mirror). The private repo is where all development happens. The public repo is a read-only mirror managed by the GitHub Action.

**Starting a new project**:

1. GitHub → "Use this template" → name the repo `<project>-dev` and mark it **private**
2. Create an empty **public** repo called `<project>` (the mirror target)
3. Delete `apps/`, `packages/`, `supabase/`, `DESIGN.md`, `README.md`, `METRICS.md`
4. Run `/office-hours` + `/autoplan` to generate specs
5. Run `/devshop:init` — guided walkthrough that reads the "Starting a New Project" checklist from `.devshop/GUIDE.md`, steps through each item sequentially, asks for input at `[HUMAN]` steps, runs automatable steps itself, and tracks progress (includes mirror deploy key setup)
6. Start Phase 0b equivalent for the new project

**Propagating dev-shop improvements**:

```bash
# After improving a dev-shop file in project A:
.devshop/scripts/sync-to-template.sh    # creates PR on abra-kadabra

# In project B, to get the latest dev-shop:
.devshop/scripts/sync-from-template.sh  # diffs + applies changes; you review
```

No git submodules, no npm packages. Git-native. You review the diff before applying.

**gstack** (`.claude/skills/gstack/`) is NOT part of the devshop template. It's a 1.6GB vendored git repo with its own version management. Each project installs it independently during Phase 0b and upgrades via `/gstack-upgrade`. The template does not bundle or sync gstack — only the devshop's custom skills (`.claude/skills/devshop/`) are synced.

---

## Stack Summary

| Layer             | Tool                               | Why                                                            |
| ----------------- | ---------------------------------- | -------------------------------------------------------------- |
| Web app           | Next.js 15 (App Router)            | Best React framework, zero-config Vercel                       |
| Monorepo          | Turborepo + pnpm                   | Fast incremental builds, workspace support                     |
| Shared logic      | `packages/core`                    | Supabase client, types, API wrappers (framework-agnostic)      |
| Shared UI         | `packages/ui` + shared tokens      | Tailwind (web) + tokens.ts (platform-agnostic source of truth) |
| Backend           | Supabase (existing)                | Keep — schema + functions already solid                        |
| Auth              | Supabase Auth + Sign in with Apple | Port from Swift; already implemented                           |
| Web hosting       | Vercel (free tier)                 | Zero-config Next.js, preview URLs on PRs                       |
| Errors            | Sentry (free: 5k errors/mo)        | Crash reports before users tell you                            |
| Analytics + flags | PostHog (free: 1M events/mo)       | Usage analytics + feature flags                                |
| Web unit tests    | Vitest                             | Fast, TS-native                                                |
| Web E2E           | Playwright                         | Best-in-class, GitHub Actions ready                            |
| CI/CD             | GitHub Actions (free tier)         | Tests + builds + deploys                                       |
| Secrets           | GitHub Secrets + Vercel env vars   | Managed; no .env in CI                                         |
| DB migrations     | Supabase CLI (existing)            | Keep existing workflow                                         |
| Lint/format       | ESLint + Prettier (existing)       | Pre-commit via husky + lint-staged                             |

**Deferred to native phase**: Expo, React Native, EAS, Jest (mobile), Maestro, mobile Sentry/PostHog — see `.devshop/notes/bootstrap/v+-native.md`.

---

## CI/CD Pipeline

### Branch Strategy

```
main        → production (branch protection: requires PR + CI green before merge)
feature/*   → short-lived feature branches (delete after merge)
fix/*       → bug fix branches
```

No `develop` branch — too much overhead for a solo dev.

### GitHub Actions Workflows

**`ci.yml`** — triggers on every PR. Evolves as testing layers are added:

Phase 0b (initial):

```
pnpm install (cached via pnpm store)
→ gitleaks scan (PR diff)
→ ESLint + Prettier check (all packages)
→ TypeScript check: tsc --noEmit (all packages)
→ Unit tests: Vitest (web + core)
→ Build check: Next.js build (verifies nothing is broken)
```

Phase 1c (when Supabase integration lands — same PR):

```
+ supabase start (Docker-in-Docker service)
+ seed.sql load
+ Integration tests (against local Supabase)
+ Type drift check (supabase gen types → diff committed types → fail if different)
```

Phase 1g (when E2E tests land — same PR):

```
+ Playwright E2E (against local Supabase-backed app)
```

Vercel preview deploy is handled automatically by the Vercel GitHub integration (no workflow needed).

### Required GitHub Secrets

Add these at: repo → Settings → Secrets and variables → Actions:

- `SUPABASE_URL` — Supabase project settings → API → URL
- `SUPABASE_ANON_KEY` — Supabase project settings → API → anon key
- `SUPABASE_SERVICE_ROLE_KEY` — Supabase project settings → API → service_role key
- `ANTHROPIC_API_KEY` — for edge function integration tests
- `SENTRY_DSN` — Sentry project settings → Client Keys
- `SENTRY_AUTH_TOKEN` — Sentry org settings → Auth Tokens (for source map uploads in CI)
- `NEXT_PUBLIC_POSTHOG_KEY` — PostHog project settings → Project API key
- `MIRROR_DEPLOY_KEY` — SSH private key for pushing to public mirror repo (see Phase 0b prerequisites)

### Required Repository Variables

Add at: repo → Settings → Secrets and variables → Actions → Variables:

- `PUBLIC_MIRROR_REPO` — `owner/repo` of the public mirror target (e.g. `username/lalista`)

### Env Var Naming Convention

Each framework requires a specific prefix for client-accessible vars. GitHub Secrets use the base name; each surface adds its own prefix:

| Secret (base name)        | Next.js (Vercel)                |
| ------------------------- | ------------------------------- |
| `SUPABASE_URL`            | `NEXT_PUBLIC_SUPABASE_URL`      |
| `SUPABASE_ANON_KEY`       | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| `SENTRY_DSN`              | `NEXT_PUBLIC_SENTRY_DSN`        |
| `NEXT_PUBLIC_POSTHOG_KEY` | `NEXT_PUBLIC_POSTHOG_KEY`       |

`packages/core` does **not** read env vars directly — it exports a typed `createClient(config: CoreConfig)` factory. Each app reads its own prefixed vars and passes them in. This keeps `packages/core` framework-agnostic.

### Release Approval Workflow

```
Feature complete → /pre-ship runs quality gates → creates PR with release notes
CI runs automatically (lint + test + build + gitleaks)
Vercel preview URL appears in PR
You review PR: release notes + test results + preview URL
You merge → web deploys
```

---

## Observability

### Sentry

- Web: `@sentry/nextjs` in `apps/web`
- Catches: uncaught exceptions, promise rejections, React error boundaries
- Configure source map upload in CI (`SENTRY_AUTH_TOKEN`) for readable stack traces
- Alert: email on first occurrence of a new error in production

### PostHog

- Web: `posthog-js` in `apps/web`
- Track key flows defined in `METRICS.md`: item added, item bought, store routed, sign in, sign out, disambiguation shown
- Feature flags: wrap any experimental feature — deploy safely, roll back without a release
- Free tier: 1M events/month — more than sufficient for early stage

### METRICS.md

Project-level source of truth for what to measure. Structure:

```markdown
# Metrics

## Events

| Event      | When it fires     | Key properties                           | Why we care           |
| ---------- | ----------------- | ---------------------------------------- | --------------------- |
| item_added | add-item succeeds | store, was_disambiguated, input_language | Core action frequency |
| ...        | ...               | ...                                      | ...                   |

## Feature Flags

| Flag | Controls | Default |
| ---- | -------- | ------- |
| ...  | ...      | ...     |
```

Convention: `/spec` includes a "Metrics" section referencing events from this file. `/implement` instruments them alongside code. New events must be added to `METRICS.md` before implementation.

---

## Design System (Preserve from DESIGN.md)

The existing `DESIGN.md` defines the complete design system. Must be preserved and extended (not replaced) for web.

Key tokens:

- **Fonts**: Fraunces (display/brand moments) + Plus Jakarta Sans (body/UI)
- **Primary accent**: `#D4603A` terracotta
- **Background**: `#FDFAF6` warm off-white cream
- **Dark mode background**: `#1A1208` warm dark chocolate (not cold gray)
- **Spacing**: 8px base grid
- **Voice**: warm, quick, bilingual-native

When migrating to web:

- Shared: `packages/ui/src/tokens.ts` — all design tokens as typed JS constants (colors, fonts, spacing). This is the single source of truth for all platforms (web now, mobile later).
- Web: `packages/ui/tailwind.config.js` — standard Tailwind config, imports tokens from `tokens.ts`, used by Next.js via PostCSS. Web components use Tailwind classes (`className="bg-terracotta"`).
- `tokens.ts` must be framework-agnostic — no Tailwind utilities, no React imports. Just typed constants. This ensures future mobile apps can import it directly.

---

## Implementation Phases

---

### Phase 0a: Build the Devshop

_Pure template work — no project-specific content. Run once. Result committed alongside lalista, then synced to `abra-kadabra` after Phase 0b validation. No accounts, no secrets, no project names._

#### Steps (Claude executes in order)

**Step 1: Update Dockerfile + devcontainer.json**

Add Docker-in-Docker feature to `devcontainer.json` — this provides an isolated Docker daemon inside the devcontainer for `supabase start`, without mounting the host Docker socket:

```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {}
}
```

Do NOT add a Docker socket mount. The host Docker must remain inaccessible from the container.

Ensure `VERCEL_TOKEN` and `SUPABASE_ACCESS_TOKEN` from `.devcontainer/.env` are available inside the container. If `.env` is already loaded via `runArgs` or `env-file`, no change needed. Otherwise add them to `containerEnv` or `remoteEnv` in `devcontainer.json` (referencing the `.env` file, not hardcoding values).

**Audit existing Dockerfile binary installs**: The Dockerfile already has version-pinned installs for git-delta, supabase-cli, DCG, and gitleaks with SHA256 checksum verification via `checksums.sha256`. Verify this is complete — every binary install must be pinned via `devcontainer.json` build args and checksum-verified. Do not re-add what already exists. The only Dockerfile change needed is the Docker-in-Docker feature above. Similarly, pnpm is already installed — verify it's present, do not re-add.

Note: After editing devcontainer.json, the devcontainer must be rebuilt. **[HUMAN]** Rebuild the devcontainer (VS Code: "Dev Containers: Rebuild Container") before proceeding. Both the devcontainer.json and firewall changes (Step 2) take effect after this single rebuild.

**Sequencing**: Claude edits Step 1 (devcontainer.json) + Step 2 (firewall) + Steps 3, 6, 7, 7b, 8, 9, 10 (all steps that don't require `pnpm` to be installed) before the rebuild. Step 4 (Turborepo monorepo init), Step 5 `pnpm` commands, and anything requiring `pnpm install` runs after the rebuild. This maximizes work done in one session with a single pause for the human rebuild.

**Step 2: Update firewall**

In `init-firewall.sh`, add the devshop-level domains to the domain list:

```
"vercel.com" \
"api.vercel.com" \
"cdn.jsdelivr.net" \
"objects.githubusercontent.com" \
"fonts.googleapis.com" \
"fonts.gstatic.com" \
```

Also add a clearly labeled project-specific section at the bottom of the domain list:

```bash
# === PROJECT-SPECIFIC DOMAINS (edit per project) ===
# See .devshop/notes/bootstrap/v0-web.md "Firewall Constraint" section for which domains to add.
# "<ref>.supabase.co" \
# "o<org-id>.ingest.sentry.io" \
# "us.i.posthog.com" \
# Supabase local dev (if using supabase start):
# "ghcr.io" \
# Docker Hub (if using Docker Hub images):
# "registry-1.docker.io" \
# "auth.docker.io" \
# "production.cloudflare.docker.com" \
```

Note: `init-firewall.sh` is `COPY`d into the image at build time, so this change also requires the container rebuild triggered by Step 1. Complete both Step 1 and Step 2 before rebuilding — one rebuild covers both.

**Step 3: Create `.devshop/` portability layer**

- `.devshop/version` — content: `0.1.0`. Semver-light:
  - **Patch** (0.1.0 → 0.1.1): bug fixes, doc updates, tweaks to existing scripts/skills
  - **Minor** (0.1.0 → 0.2.0): new skill, new CI step, new convention
  - **Major** (0.x → 1.0): breaking change to sync format, manifest structure, or skill interface

  **How the version gets bumped** — depends on where the change originates:
  - **From a project repo**: `sync-to-template.sh` bumps the version automatically before syncing. It guesses patch/minor/major based on what changed (new files in manifest = minor, modified existing = patch). If unsure, prompts the user to confirm.
  - **From the template repo directly**: run `.devshop/scripts/release.sh` — reads the current version, shows changes since the last version tag, suggests a bump level, asks for confirmation, bumps `.devshop/version`, commits, and tags (`devshop-v0.2.0`). Projects pull the new version via `sync-from-template.sh`.

- `.devshop/template-remote` — runtime config file read by the sync scripts. **Gitignored** (contains your GitHub username — `.gitignore` has the entry). Leave blank for now; **[HUMAN]** fills in the repo URL after Phase 0b validation. The new-project checklist in `.devshop/GUIDE.md` prompts for this.
- `.devshop/template-remote.example` — committed placeholder so new users know the format: `https://github.com/<org>/<template-repo>`
- `.devshop/scripts/sync-to-template.sh` — **v0: simple automated copy** guided by `manifest.txt`. Reads the remote URL from `.devshop/template-remote` (exits with clear error if file is missing or empty), reads `.devshop/manifest.txt`, copies all listed files to a local clone of the template repo, commits, and pushes. On initial seed (empty remote): pushes directly. On subsequent runs: pushes to a branch and creates a PR via `gh pr create`.
  v0: simple copy. See .devshop/TODOS.md for v1 improvements.
- `.devshop/scripts/sync-from-template.sh` — **v0: simple automated copy** in the other direction. Reads the remote URL (same guard), reads `manifest.txt`, copies template files into the project, shows `git diff` of what changed so the user can review before committing.
  Additionally: reads `.devshop/CLAUDE.md` and injects its content into root `CLAUDE.md` by replacing everything between the `## Devshop Conventions` heading and the next `## ` heading. If the existing content differs from what's being injected, shows the diff and asks for confirmation before overwriting. If root `CLAUDE.md` has no `## Devshop Conventions` heading, warns and skips.
  See .devshop/TODOS.md for v1 improvements to the rest of the sync flow.
- **Sync script contract**:
  - PRs created via `gh pr create` (requires `gh` auth — already available in devcontainer)
  - On conflict: abort with error. User resolves manually. No auto-merge.
- `.devshop/CLAUDE.md` — the source file for the `## Devshop Conventions` section of root `CLAUDE.md`. `sync-from-template.sh` injects this content into root `CLAUDE.md` by finding the `## Devshop Conventions` heading and replacing up to the next `## ` heading. No special markers — uses the heading structure that Claude already parses naturally. Edits to devshop conventions go here, not in root `CLAUDE.md` directly.
- `.devshop/manifest.txt` — one path/glob per line listing all dev-shop layer files. Serves two purposes: (1) the sync scripts read it to determine which files to copy between projects and the template, and (2) the public mirror Action reads `[private]` annotations to determine which paths to strip. Lines marked `[private]` are devshop internals stripped from the public mirror; unmarked lines are devshop-layer files that are fine for public repos (CI, linting, etc.). Sync scripts ignore annotations (strip trailing tags when reading paths). Does NOT include build blueprints (`.devshop/notes/bootstrap/`) — those are project-specific construction history, handled separately by the mirror Action. Example contents:
  ```
  .devshop/                    [private]
  .claude/skills/devshop/      [private]
  .devshop/OVERVIEW.md          [private]
  .devshop/GUIDE.md                   [private]
  .devshop/TODOS.md              [private]
  .devshop/ROADMAP.md           [private]
  .dcg.toml                    [private]
  .devcontainer/
  .husky/
  .claude/settings.json
  .github/workflows/
  .gitleaks.toml
  turbo.json
  pnpm-workspace.yaml
  tsconfig.base.json
  eslint.config.mjs
  ```

**Step 4: Convert to Turborepo monorepo**

- `pnpm-workspace.yaml`:
  ```yaml
  packages:
    - 'apps/*'
    - 'packages/*'
  ```
- `turbo.json` with pipeline: `lint`, `typecheck`, `test:unit`, `test`, `build` (each depending on `^build` where appropriate). `test:unit` runs only `*.test.ts` (excludes `*.integration.test.ts`); `test` runs all tests. Vitest config in each package filters by the `VITEST_INTEGRATION` env var or uses separate config files — implementation detail resolved at build time.
- Root `package.json`: add scripts for `lint`, `test`, `build` via turbo, devDependencies for turbo + husky + lint-staged. Do NOT add a `"workspaces"` field — pnpm ignores it entirely and uses `pnpm-workspace.yaml` only.
- **`tsconfig.base.json`** at repo root — shared TypeScript baseline that every package and app extends:
  ```json
  {
    "compilerOptions": {
      "strict": true,
      "esModuleInterop": true,
      "skipLibCheck": true,
      "moduleResolution": "bundler",
      "resolveJsonModule": true,
      "isolatedModules": true,
      "jsx": "preserve",
      "incremental": true,
      "noUncheckedIndexedAccess": true
    }
  }
  ```
  Each `packages/*` and `apps/*` package has its own `tsconfig.json` that begins with `"extends": "../../tsconfig.base.json"` (adjust path depth as needed). This ensures consistent strictness and shared compiler options across the entire monorepo. Without this, `pnpm turbo run typecheck` will produce inconsistent results across packages.

**Shared package consumption pattern**: Packages under `packages/` export TypeScript source directly — no build step, no compiled output. Set `"main": "src/index.ts"` in each package's `package.json`. Each consuming app handles transpilation: Next.js requires `transpilePackages: ['@<project>/core', '@<project>/ui']` in `next.config.js`. Every package must have a `src/index.ts` barrel export — never import from deep paths across package boundaries (e.g. `@lalista/core/src/api/items` is wrong; `@lalista/core` is correct).

**Step 4b: Migrate ESLint to flat config**

The existing root `.eslintrc.json` is minimal and no existing TS/JS code depends on it. Next.js 15 defaults to flat config (`eslint.config.mjs`). Set the whole monorepo on flat config now to avoid fighting the tooling forever.

- Delete `.eslintrc.json`
- Create root `eslint.config.mjs` (`.mjs` not `.js` — keeps root `package.json` free of `"type": "module"`):

  ```js
  import js from '@eslint/js';
  import tseslint from 'typescript-eslint';

  export default tseslint.config(
    js.configs.recommended,
    ...tseslint.configs.recommended,
    {
      rules: {
        // Code quality rules only — Prettier owns all formatting
        '@typescript-eslint/no-unused-vars': [
          'error',
          { argsIgnorePattern: '^_' },
        ],
        '@typescript-eslint/no-explicit-any': 'warn',
      },
    },
    {
      ignores: ['**/node_modules/**', '**/.next/**', '**/dist/**'],
    }
  );
  ```

- Add root dev dependencies: `pnpm add -D -w @eslint/js typescript-eslint`
- Each app that needs framework-specific rules adds its own `eslint.config.mjs` that spreads the root config:
  ```js
  // apps/web/eslint.config.mjs
  import rootConfig from '../../eslint.config.mjs';
  import nextPlugin from '@next/eslint-plugin-next';
  export default [...rootConfig, nextPlugin.configs['core-web-vitals']];
  ```
- When `pnpm create next-app` generates an `eslint.config.mjs` in `apps/web`, **delete it** and replace with the pattern above.

**Step 5: Set up pre-commit hooks**

_Pre-rebuild (create config files only — no pnpm commands yet):_

Create `.husky/pre-commit` (only two lines — `check-devshop-docs.sh` is added later in Phase 0b Step 6, after scaffold commits land):

```sh
pnpm exec lint-staged
gitleaks protect --staged --redact
```

Create `.gitleaks.toml` at the repo root — ships with the devshop template to prevent false-positive rot. Without this, gitleaks default rules flag Supabase anon keys, PostHog public keys, Sentry DSNs, and Expo project IDs (all intentionally client-side values, not secrets). The first false positive leads to `--no-verify` which permanently neuters the scanner.

```toml
[allowlist]
description = "Known-safe public client keys (not secrets)"
paths = [
  '''\.env\.example$''',
]
regexTarget = "match"
regexes = [
  # Supabase anon key (public, embedded in client JS — not a secret)
  '''SUPABASE_ANON_KEY''',
  # PostHog public project key (designed to be client-side)
  '''POSTHOG_KEY''',
  # Sentry DSN (public, used in client error reporting)
  '''SENTRY_DSN''',
]
```

The new-project checklist in `.devshop/GUIDE.md` includes: "Update `.gitleaks.toml` allowlist with your project's specific public key patterns before the first commit with real config values."

Add lint-staged config to root `package.json`:

```json
"lint-staged": {
  "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,css}": ["prettier --write"]
}
```

Also create `.devshop/scripts/check-file-headers.sh` — checks that every staged `.ts`/`.tsx` file **under `src/` or `app/` directories** contains `// What:` in its first 5 lines. Exits 1 with the offending filename if missing. Config files (`*.config.*`, `*.d.ts`, root-level scripts) are excluded by only checking source directories — no growing exclusion list.

Also create `.devshop/scripts/check-devshop-docs.sh` — if `.devshop/OVERVIEW.md` or `.devshop/GUIDE.md` is staged, prints a reminder to update the other (not a hard block). Only checks the reference pair — build blueprints (`.devshop/notes/bootstrap/`) are independent:

```
⚠ DEVSHOP reference doc changed — verify both are in sync:
  .devshop/OVERVIEW.md  (bird's eye)
  .devshop/GUIDE.md           (full reference)
```

Also add `"prepare": "husky"` to the `scripts` section of root `package.json` — this is what `husky init` would do, but we skip `husky init` to avoid it overwriting the custom `.husky/pre-commit` file created above.

_Post-rebuild (run after container is rebuilt with pnpm installed):_

```bash
cd /workspace
pnpm install          # initialize workspace, create lockfile
pnpm add -D -w husky lint-staged
```

The `prepare` script runs automatically after `pnpm install`, setting up the git hooks. No need for `pnpm exec husky init` — the `.husky/pre-commit` file and `prepare` script are already in place.

**Do not wire up `check-devshop-docs.sh` or `eslint-plugin-jsdoc` yet.** These are added in Phase 0b Step 6, after the initial scaffold commits land. `check-file-headers.sh` is created but never wired into pre-commit — file header enforcement is handled by `/pre-ship` convention check instead (see Issue 7 rationale: mechanical enforcement produces mechanical documentation).

**Step 6: Create GitHub Actions**

`.github/workflows/ci.yml` — **split into fast and slow jobs** to conserve GitHub Actions free tier (2000 min/month):

**Fast job** (runs on every push to PR branches — ~3-4 min):

```yaml
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches-ignore: [main]
jobs:
  fast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: pnpm/action-setup@v3
        with: { version: latest }
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - run: pnpm turbo run lint typecheck test:unit build
      - name: Mirror sync tests
        run: bash .devshop/scripts/test-mirror-sync.sh
    env:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
      SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
      NEXT_PUBLIC_POSTHOG_KEY: ${{ secrets.NEXT_PUBLIC_POSTHOG_KEY }}
      SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
      SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
```

> ⚠️ NOT IN LIVING DOCS — the YAML structure and env vars below are reference
> examples for when the slow job is built. Triggers and principles are in
> ROADMAP.md § v+ "CI slow job expansion".

**Slow job** (runs only on PR to main — ~10-15 min, added in Phase 1c/1g):

```yaml
slow:
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-latest
  needs: fast
  # Phase 1c: supabase start + integration tests + type drift check
  # Phase 1g: Playwright E2E
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs (Turbo's built-in remote caching or local `.turbo`), Playwright browsers (Phase 1g). Cache keys use lockfile hash.

Note: `ci.yml` will be updated in Phase 1c (add Supabase service + integration tests + type drift check to slow job) and Phase 1g (add Playwright E2E to slow job). Each update is part of the same PR that adds the code being tested. Branch protection requires both `fast` and `slow` jobs to pass before merge.

**Phase 1c CI additions** (key decisions — exact YAML written at implementation time):

- Use `supabase/setup-cli` GitHub Action for Supabase CLI installation
- `supabase start` to spin up local stack (GitHub Actions has native Docker — no DinD needed)
- Load `seed.sql` via `psql` against the local Supabase Postgres
- Type drift check: `supabase gen types typescript` → `git diff --exit-code packages/core/src/supabase.types.ts` → fail if different
- Mask service role key: `echo "::add-mask::$SUPABASE_SERVICE_ROLE_KEY"`
- **Implementation note**: verify which Supabase env vars (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_URL`, etc.) are actually needed for `supabase start` + `supabase gen types` in CI. Wire only what's confirmed into `ci.yml` in this PR.
- **Rollback SQL syntax validation**: for each new migration file in the PR, extract the `-- ROLLBACK` block and parse it against the local Supabase Postgres (e.g., `EXPLAIN` or `DO $$ BEGIN ... END $$` wrapper that parses without executing). Fail if syntax is invalid. This catches typos in rollback SQL before it's needed in an emergency.

**Phase 1g CI additions** (key decisions — exact YAML written at implementation time):

- Install browsers: `npx playwright install --with-deps chromium` (or use system Chromium if CDN is blocked)
- Start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run both viewport projects: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging

**Step 7: Write devshop documentation hierarchy**

The devshop has three types of documentation, all under `.devshop/`. Reference docs are living and kept in sync. Backlogs grow independently. Build blueprints are one-time construction guides.

#### Reference docs (living — update together in the same commit)

**`.devshop/OVERVIEW.md`** — already exists. Verify it matches the spec below and update if needed (do not rewrite from scratch). Bird's eye view, ~60-80 lines, ~1k tokens. Title: `# Abra-Kadabra Dev Shop — Overview`.

```markdown
<!-- Editorial: one line per concept. If it takes more than one line to explain,
     it belongs in .devshop/GUIDE.md. This file should stay under 80 lines / ~1k tokens. -->
```

Contents:

- One paragraph: what the devshop is and who it's for
- The 11-step workflow (one line per step), plus `/devshop:status` (session orientation — run at start of any new session)
- File map — one line per key file/folder, grouped by concern:
  ```
  Docs: .devshop/GUIDE.md (reference) · DESIGN.md (visual) · METRICS.md (analytics) · SPEC.md (active spec) · CLAUDE.md (agent config) · PRODUCT-ROADMAP.md (deferred items)
  Apps: apps/web/ (Next.js)
  Shared: packages/core/ (business logic, Supabase client, API wrappers) · packages/ui/ (design tokens, components)
  Backend: supabase/migrations/ (schema) · supabase/functions/ (edge functions)
  CI/CD: .github/workflows/ci.yml · apps/web/vercel.json
  Devshop: .devshop/ (scripts, conventions source) · .claude/skills/devshop/ (spec, implement, pre-ship, post-merge, status)
  Backlogs: TODOS.md (project tactical) · PRODUCT-ROADMAP.md (project strategic) · .devshop/TODOS.md (devshop tactical) · .devshop/ROADMAP.md (devshop strategic)
  Config: turbo.json · pnpm-workspace.yaml · tsconfig.base.json · eslint.config.mjs · .dcg.toml · .gitleaks.toml
  ```
- Key conventions summary (5-6 bullets — the non-negotiables in one sentence each, including: "Every user-facing feature must have metrics — `/spec` creates and proposes events, `/pre-ship` validates instrumentation")
- Glossary: abra-kadabra (brand) vs devshop (code), key skill names, key file names
- Pointer: "See .devshop/GUIDE.md for full reference, .devshop/notes/bootstrap/v0-web.md for construction details"

**`.devshop/GUIDE.md`** — already exists. Verify it matches the spec below and update if needed (do not rewrite from scratch). Full operational reference, living doc, ~300-400 lines initially — grows over time. Title: `# Abra-Kadabra Dev Shop`.

```markdown
<!-- Editorial: enough detail to act on — exact file paths, exact commands, specific gotchas.
     If it's a one-time build instruction, it belongs in .devshop/notes/bootstrap/v0-web.md, not here.
     If it's a one-line orientation fact, it belongs in .devshop/OVERVIEW.md.
     This file is the living reference — update it when code structure changes.
     Target: under 500 lines. If a section grows past ~30 lines, consider whether the
     detail belongs in a .devshop/DETAILS.md (see "When to split" below). -->
```

Contents:

- The full idea-to-deployed workflow (the 11-step diagram from this plan) with what each step does and key flags/gotchas
- **"Where Things Happen"** section — organized by concern, with exact file paths (grows as code is added — `/implement` updates it when introducing new paths)
- gstack skill map (when to use which skill, what it expects, what it produces) — include a note under `/design-review`: must explicitly check for visual divergence between platforms when mobile is added
- **§ Shared Conventions** — the single source of truth for conventions referenced by multiple skills. Skills point here, not copy. Contains:
  - **Testing philosophy**: assert specific values (not existence), test contracts (not implementation), invalid input + unauthorized access tests for every API, boundary conditions for data, RLS boundary tests for every table with policies. Full detail from the Non-Negotiables section.
  - **Backlog routing guide**: the 2x2 matrix (who cares? × when?), version tag convention, no-cross-reference rule between project and devshop rows.
  - **Metrics lifecycle**: `/spec` creates/proposes events → `/implement` instruments → `/pre-ship` validates. New events are always "stop and ask."
  - **Metrics principles** (for drafting/updating `METRICS.md`): the 7 principles from Step 10 (every event answers a question, track outcomes not clicks, etc.)
  - **Spec quality checklist**: every behavior described, error states explicit, out-of-scope listed, offline behavior declared, metrics section required.
- TASKS.md task format + resume pattern
- Structured reflection prompt (step 11 post-merge) — routes learnings to CLAUDE.md, .devshop/GUIDE.md, and backlog files (not memory files)
- How to start a new project (Phase 0b checklist) — must include:
  - "Install gstack: `git clone https://github.com/garrytan/gstack.git .claude/skills/gstack && cd .claude/skills/gstack && ./setup`. Upgrade later via `/gstack-upgrade`. gstack is per-project, not part of template sync."
  - "Add `VERCEL_TOKEN` and `SUPABASE_ACCESS_TOKEN` to `.devcontainer/.env`"
  - "After adding `@sentry/nextjs`: run the Sentry wizard (`npx @sentry/wizard@latest -i nextjs`), create `global-error.tsx`, verify test error in dashboard"
  - "After adding `posthog-js`: create PostHogProvider client component, wrap root layout, verify test event in dashboard"
  - "Create `seed.sql` with minimum test fixtures (including two users in different households for RLS boundary tests) before writing integration tests"
  - "When implementing auth: add Next.js middleware for route protection in the same PR — never ship auth without protected routes"
  - "Configure PWA: update `manifest.json` with project name, theme color, and branded icons. Verify 'Add to Home Screen' works on iOS Safari and Android Chrome."
  - "Fill in theme tokens in `tokens.ts` with project colors (light + dark). Verify all components use theme tokens, not hardcoded colors."
  - "Run `supabase link --project-ref <ref>` before first `supabase start`"
- How to propagate dev-shop improvements (sync scripts, `.devshop/manifest.txt`)
- **"When Things Go Wrong"** section — rollback runbook:
  - **Vercel rollback**: `vercel rollback` to revert to previous deployment. Find the deployment ID in the rollback checkpoint (PR comment from `/post-merge`).
  - **Migration rollback**: find the `-- ROLLBACK` comment block at the bottom of the offending migration file. Copy-paste and run via `psql` or Supabase SQL editor. Test on a non-production environment first if possible.
  - **Canary failure**: if `/canary` detects issues, immediately run `vercel rollback`. Then investigate root cause on the branch — do not push forward.
  - **Data recovery**: free-tier Supabase has no point-in-time recovery. Pre-migration `pg_dump` is automated (Phase 1c). For weekly backups beyond deploys, see `.devshop/ROADMAP.md` v1.
- **Service quotas** — direct links to each service's usage dashboard: Supabase (database, auth, edge function invocations), Sentry (error quota), PostHog (event quota), GitHub Actions (minutes), Vercel (bandwidth, serverless invocations). Check monthly or when approaching a launch.
- **Local dev without DinD** — first-class documented workflow: run `pnpm turbo run test:unit` for the fast inner loop when DinD is unavailable or hardware-constrained (< 16GB RAM). Integration tests run in CI. This is a legitimate workflow, not a degraded experience.
- **Expected CI minutes** — document monthly budget (~260 min/month for 10 PRs: 20 fast jobs × 4 min + 10 slow jobs × 15 min + 10 mirror runs × 3 min). Track if it creeps up as the test suite grows. GitHub Actions free tier: 2000 min/month.
- Troubleshooting section (starts empty — grows as issues are encountered)
- Decision log (short entries: "chose X over Y because Z, date" — extracted from reviews and retros)

#### When to split: `.devshop/DETAILS.md`

Start with two reference docs. When either signal below fires, extract detailed sections from `.devshop/GUIDE.md` into a new `.devshop/DETAILS.md`:

1. **Size signal**: `.devshop/GUIDE.md` exceeds ~500 lines. At that point, sections like "Where Things Happen" (full path listings), Troubleshooting (growing list of issues), and Decision Log (accumulated entries) are candidates to move.
2. **Context signal**: Claude regularly needs to read `.devshop/GUIDE.md` for a task but only uses ~30% of it. The unused 70% is wasting context window. Split the frequently-used operational content (workflow, skill map, checklists) from the deep reference content (full path map, troubleshooting, decision log).

When splitting:

- `.devshop/GUIDE.md` keeps: workflow, skill map, conventions, checklists — the stuff needed for every task
- `.devshop/DETAILS.md` gets: "Where Things Happen" (full paths), Troubleshooting, Decision Log — deep reference consulted when needed
- `.devshop/OVERVIEW.md` unchanged — it already points to `.devshop/GUIDE.md`
- `.devshop/GUIDE.md` adds pointers: "See .devshop/DETAILS.md for full file paths, troubleshooting, and decision log"
- Update `CLAUDE.md` context loading section to include `.devshop/DETAILS.md`
- Update `check-devshop-docs.sh` to include the new file in the sync reminder

Do not create `.devshop/DETAILS.md` preemptively. YAGNI — create it only when a signal fires.

#### Backlogs (living — grow independently, no sync enforcement)

**`.devshop/TODOS.md`** — devshop tactical backlog. Friction, bugs, small fixes discovered during use. Items can have version tags (e.g., `[v0.2]`) referencing versions defined in `.devshop/ROADMAP.md`. Already exists — restructure during Phase 0a: move strategic/capability items to `.devshop/ROADMAP.md`, keep tactical items here.

**`.devshop/ROADMAP.md`** — devshop strategic backlog. Capabilities and major improvements. Defines version milestones that `.devshop/TODOS.md` items can reference. Create during Phase 0a with the strategic items extracted from `.devshop/TODOS.md`'s current v+ section, plus a one-liner for native/mobile support pointing to `.devshop/notes/bootstrap/v+-native.md`.

**`PRODUCT-ROADMAP.md`** — project strategic backlog (template ships with standard deferred items like service worker caching). Already exists — verify consistency.

**`TODOS.md`** — project tactical backlog. Bugs, minor fixes, blocked items for the current project. Never references devshop files.

See the "Backlog Routing Guide" section above for the full routing rules.

#### Build blueprints (one-time — become historical after execution)

`.devshop/notes/bootstrap/v0-web.md` and `.devshop/notes/bootstrap/v+-native.md` are construction docs. They're synced to the template but independent of the reference docs — no sync enforcement between blueprints and reference docs.

All three types are dev-shop layer (synced to template). Build blueprints become historical after execution — they're only read when bootstrapping a new devshop or modifying infrastructure.

**Step 7b: Configure DCG (Destructive Command Guard)** — DCG is installed in the Dockerfile (Step 1). It replaces the homegrown `safety-hook.sh`. It reads tool input JSON from stdin correctly, blocks 49+ destructive patterns including heredoc/inline-script scanning, and is fail-open (never blocks on parse error or timeout).

Create `.dcg.toml` at the repo root (DCG's project-level config — highest priority in its lookup chain, version-controlled as part of the dev shop layer, no Dockerfile change or symlink needed):

```toml
[packs]
enabled = [
  "core.git",
  "core.filesystem",
  "database.postgresql",
]

[agents.claude-code]
trust_level = "high"
additional_allowlist = ["pnpm *", "turbo *", "supabase gen types*"]
```

No custom shell script needed. DCG handles stdin parsing and blocking natively. DCG reads `.dcg.toml` automatically from the working directory — no env var or flag required.

**Step 8: Update `.claude/settings.json`** — read the existing file first, then audit and update:

- **Read the file first.** `defaultMode: "acceptEdits"` and a bash allowlist are already set — do not overwrite them.
- **Audit `allow` against the full devshop workflow**: check that every command Claude needs to run autonomously (pnpm, turbo, git, mkdir, cp, mv, chmod, dcg, safe supabase subcommands) is covered. Add any missing entries. Destructive commands (supabase db reset, db push, functions deploy) must NOT be in the allowlist — they should prompt.
- **Keep `deny` as-is** — existing secret/credential file protections are correct.
- **Add write-deny rules for devcontainer files and settings.json itself** — Claude can read but not modify:
  ```json
  "Edit(**/.devcontainer/*)",
  "Write(**/.devcontainer/*)",
  "Edit(**/.claude/settings.json)",
  "Write(**/.claude/settings.json)",
  "Edit(**/init-firewall.sh)",
  "Write(**/init-firewall.sh)"
  ```
- **[HUMAN] Lock security-critical files with root ownership** — the deny rules block Edit/Write tools, but Claude could bypass them via Bash (`sed -i`, `echo >`). Root ownership closes this loophole:
  ```bash
  sudo chown root:root .claude/settings.json .devcontainer/devcontainer.json .devcontainer/init-firewall.sh
  sudo chmod 644 .claude/settings.json .devcontainer/devcontainer.json .devcontainer/init-firewall.sh
  ```
  After this, Claude (running as `node`) can read these files but cannot write by any means. To edit: `sudo nano <file>`.
- **Add the `hooks.PreToolUse` section** (this is the only structural addition if the rest is already correct):
  ```json
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "dcg" },
        { "type": "command", "command": "bash .devshop/scripts/check-devshop-commit-msg.sh" }
      ]
    }]
  }
  ```
  The `check-devshop-commit-msg.sh` hook reads the tool input JSON from stdin (same pattern as DCG), exits early for non-`git commit` commands, and blocks if devshop paths are staged but the commit message has no `---devshop---` divider. See Step 11 for details.

**Step 9: Update root `CLAUDE.md`** — single file with clearly marked sections:

```markdown
# CLAUDE.md

## Devshop Conventions

[Synced from .devshop/CLAUDE.md by sync-from-template.sh — edit .devshop/CLAUDE.md, not here]

## Project: lalista

[Project-specific context here]
```

The devshop conventions section is **lean — behavioral directives and pointers, not detailed conventions**. Detailed conventions live in `.devshop/GUIDE.md § Shared Conventions` (one source of truth, referenced by skills). CLAUDE.md contains:

- **Context loading** — tells Claude which docs to read for which task:

  ```
  Reference docs (living):
  - Always loaded: CLAUDE.md (you're reading it)
  - For orientation: .devshop/OVERVIEW.md
  - When implementing features: .devshop/GUIDE.md + SPEC.md + METRICS.md + DESIGN.md

  Build blueprints (historical after execution):
  - When bootstrapping or modifying devshop: .devshop/notes/bootstrap/v0-web.md
  - When adding native/mobile: .devshop/notes/bootstrap/v+-native.md
  ```

- Dev-shop philosophy (fast via Claude, stable via process)
- **Implementation approach**: Default to simple. Pick the boring solution. Tried-and-true over clever. Readable and debuggable over optimal. No fancy patterns unless the simple one genuinely can't do the job.
- **Non-negotiables** — one-line summaries only, with pointer to detail:
  - No code without tests — written alongside, never after.
  - No code that breaks existing tests — full suite before marking done.
  - No code without metrics — every user-facing feature has events in `METRICS.md`.
  - Responsive from day one — 375px to 2560px, mobile-first.
  - Light/dark theme required — both from launch, theme tokens only.
  - Edge functions always validate auth server-side via `getUser()`.
  - Pre-commit: ESLint + Prettier + gitleaks, no bypass.
  - Shared packages export TypeScript source directly — no build step.
  - For full detail on testing philosophy, metrics lifecycle, and backlog routing: see `.devshop/GUIDE.md § Shared Conventions`.
- **Known footguns**:
  - Firewall IP rotation: if a build fails on a network error for an allowed domain, restart the container to re-resolve CDN IPs.
- **Documentation convention**:
  - Every `.ts`/`.tsx` file starts with a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Write on non-trivial files; `/pre-ship` convention check verifies.
  - Every exported function has a 1-2 sentence JSDoc. Internal/private: no doc required.
- **Confidence calibration** (proceed autonomously vs stop and ask) — full list here (this is purely Claude behavioral):
  - PROCEED: UI components + tests, extending existing APIs, bug fixes, styling, docs, new queries (no schema changes), instrumenting existing metrics.
  - STOP AND ASK: new DB columns/tables, auth flow changes, new third-party integrations, performance-sensitive code, security logic, deleting existing tests, new metric event definitions.
- **TODO protocol**:
  - **Blocker** → stop, add to `TODOS.md` `[blocked]`, mark task blocked, ping user
  - **Out-of-scope** → route per backlog guide in `.devshop/GUIDE.md § Shared Conventions`, skip, continue
  - **Minor < 5 min** → fix in current commit, note in message
  - **Minor > 5 min** → add to `TODOS.md` `[minor]`, continue
- **Naming convention**: `abra-kadabra` = brand name (repo, doc titles). `devshop` = code references (`.devshop/`, `.claude/skills/devshop/`, `/devshop:*` skills).
- **Devshop documentation structure**: reference docs (.devshop/OVERVIEW.md + .devshop/GUIDE.md, update together), backlogs (.devshop/TODOS.md + .devshop/ROADMAP.md, grow independently), build blueprints (.devshop/notes/bootstrap/, historical after execution).
- **Commit message convention: public mirror** — `---devshop---` divider in body separates public from private context. Devshop-only commits: no divider needed. Mixed commits: project above, devshop below. Project-only: no divider. PreToolUse hook enforces on mixed commits.
- Implementation loop: `/implement`. Test commands: `pnpm turbo run test`.

The project section contains lalista-specific context (current repo state, Supabase project details, etc.).

The sync-to-template script extracts the devshop section (between the `<!-- synced-from -->` markers). The sync-from-template script replaces it.

**Step 10: Create devshop skill files**

Create `.claude/skills/devshop/spec/SKILL.md` — the `/devshop:spec` skill as described in the "/spec Command" section above. Must include the offline behavior checklist item (every feature with remote data must declare: online-only with error state, read-only cache, or full offline with sync — default to online-only). Must reference (not duplicate) metrics principles and spec quality checklist from `.devshop/GUIDE.md § Shared Conventions`.

Create `.claude/skills/devshop/implement/SKILL.md` — the `/devshop:implement` skill as described in the "Step 5: Implementation" section above. v0 is single-agent (no subagents). Must include: the per-task test command (`pnpm turbo run test:unit` — integration tests are the CI slow job's responsibility), and a note that `noUncheckedIndexedAccess: true` is enabled in `tsconfig.base.json` — array/object index access returns `T | undefined`, handle explicitly (no `!` assertions unless the check is genuinely impossible). Must reference (not duplicate) shared conventions from `.devshop/GUIDE.md § Shared Conventions`: testing philosophy, backlog routing guide, metrics lifecycle.

Create `.claude/skills/devshop/test-review/SKILL.md` — the `/devshop:test-review` skill. Reads tests alongside the code they test with **no implementation context** (fresh eyes). References testing philosophy from `.devshop/GUIDE.md § Shared Conventions`. Flags: weak assertions (`toBeDefined`, `toBeTruthy` on return values), missing error/invalid input test cases, missing unauthorized access tests, untested auth boundaries (RLS), tests that test implementation details instead of contracts. Reports findings and suggests specific improvements. Does not auto-fix — pauses for review.

Create `.claude/skills/devshop/pre-ship/SKILL.md` — the `/devshop:pre-ship` skill as described in the "Step 6: Pre-Ship" section above (includes `/test-review` between `/simplify` and `/review`). Must flag any backlog items that appear to be in the wrong file per the routing guide in `.devshop/GUIDE.md § Shared Conventions`. Must verify every new migration file has a `-- ROLLBACK` comment block — pause if missing. Must run a **convention check**: verify file headers exist on non-trivial files (>1 export or >50 lines), JSDoc on exports, metrics instrumentation on user-facing code.

Create `.claude/skills/devshop/post-merge/SKILL.md` — the `/devshop:post-merge` skill as described in the "Step 11: Post-Merge" section above.

Create `.claude/skills/devshop/status/SKILL.md` — the `/devshop:status` skill. Reads TASKS.md, SPEC.md, recent git log (last 10 commits), current branch, uncommitted changes, and any in-progress `/pre-ship` or `/post-merge` state. Outputs a one-paragraph briefing: what phase you're in (implementing, pre-ship, between features), what's done, what's next, and any blockers. Use at the start of any new session to get oriented. Does not modify any files.

Create `.claude/skills/devshop/init/SKILL.md` — the `/devshop:init` skill. A guided walkthrough, not an automation wizard.

**How it works**:

1. **Version freshness check** (first step, before the checklist): Check `devcontainer.json` build args and `checksums.sha256` for binary versions (git-delta, supabase-cli, DCG, gitleaks). Compare against latest releases. If newer versions are available, confirm with user whether to upgrade. Guide user to the release page for each binary to obtain the new checksum.
2. Reads the "Starting a New Project" checklist from `.devshop/GUIDE.md` (the `- [ ]` items).
3. Walks through items sequentially. For each item:
   - **`[HUMAN]` items**: shows what the user needs to do, waits for confirmation ("done" / answer), then marks `- [x]` in `.devshop/GUIDE.md`.
   - **Automated items**: runs the command/action itself, verifies success, then marks `- [x]`.
   - **On failure**: stops, shows the error, asks the user how to proceed (retry / skip / abort).
4. On resume (some items already `- [x]`): skips completed items, shows summary of progress ("7/20 done, next: Scaffold packages"), continues from the first unchecked item.
5. After all items pass: resets checkboxes back to `- [ ]` (the file is a reusable template, not a one-time log).

**Step 11: Public mirror infrastructure**

The private repo contains both project code and devshop internals. A GitHub Action mirrors to a public repo on every push to main, stripping devshop files and cleaning commit messages. This lets project development be visible in real-time while keeping devshop tooling private.

**Approach: commit-by-commit mirror (no history rewriting, no force-push).** Instead of `git filter-repo` (which rewrites SHAs and requires force-push, breaking anyone who cloned the public repo), the mirror action replays each new commit on main as a filtered commit on the public repo. The public repo has its own stable history that grows normally — `git pull` always works.

**How commits are handled:**

- **Project-only commit**: files copied as-is, commit message used as-is. Appears in public repo.
- **Mixed commit**: devshop files excluded from copy. Commit message stripped below `---devshop---`. Appears in public repo with project changes and clean message.
- **Devshop-only commit**: no project files changed → skip (no empty commit created).
- **CLAUDE.md**: the `## Devshop Conventions` section is stripped from the copy (everything from that heading to the next `## ` heading or EOF).

Include this explanation as a comment block at the top of `public-mirror.yml`.

**Step 11a: Create `.devshop/scripts/check-devshop-commit-msg.sh`**

A PreToolUse hook script that enforces the `---devshop---` commit message convention for mixed commits. Reads tool input JSON from stdin (same pattern as DCG):

1. Extracts the `command` field from JSON. If not `git commit*`, exits with `{}` (allow).
2. Runs `git diff --cached --name-only` to get staged files.
3. Classifies staged files as devshop paths (`.devshop/*`, `.claude/skills/devshop/*`, `.dcg.toml`) or project paths (everything else).
4. If no devshop paths → `{}` (allow). Project-only commit.
5. If ALL paths are devshop → `{}` (allow). Devshop-only commit.
6. If BOTH devshop and project paths are staged (mixed commit): extracts the commit message from the `-m` argument. If `---devshop---` is missing from the body → block: "Mixed commit (devshop + project files) — add a `---devshop---` section in the body to separate devshop context from the public commit message."
7. Otherwise → `{}` (allow).

This catches the obvious 90% case (devshop file paths). The remaining 10% (devshop-motivated changes to shared files like `turbo.json`) is handled by the CLAUDE.md convention — Claude semantically knows when a change is devshop-related and adds the divider proactively. The hook is a safety net, not a perfect classifier.

**Step 11b: Create `.devshop/scripts/mirror-sync.sh`**

The core mirror logic, used by the GitHub Action. Takes the private repo path and public repo clone path as arguments. For each new commit since the last mirrored SHA:

1. Checks out the commit's tree in the private repo
2. Builds the private paths list from `.devshop/manifest.txt` `[private]` annotations + hardcoded `.devshop/notes/bootstrap/` + `notes/` + `.claude/` + `.gstack/`
3. Copies all non-private files to the public repo working directory via `rsync --delete --exclude-from=<private-paths>`
4. Strips the `## Devshop Conventions` section from `CLAUDE.md` in the public copy (sed or Python — find heading, delete to next `## ` or EOF)
5. Strips the commit message below `---devshop---` (if present)
6. Stages all changes in the public repo. If `git diff --cached` is empty (devshop-only commit), skip
7. Commits with the cleaned message and the original author/date
8. After all commits are replayed, does a normal `git push` (not force-push)

**Tracking last mirrored SHA**: the public repo stores a `.mirror-sha` file containing the SHA of the last private repo commit that was mirrored. The script reads this to know where to start replaying from. On first run (file doesn't exist), all commits on main are replayed (or squashed into an initial commit if the pre-devshop history is messy — see first-run behavior below).

**First-run behavior**: if the public repo is empty, squash all current content into a single "Initial commit" rather than replaying pre-devshop history (which contains commit messages referencing devshop files). Set `.mirror-sha` to the current HEAD. Subsequent runs replay incrementally.

**Step 11b-test: Create `.devshop/scripts/test-mirror-sync.sh`**

Test harness for the mirror script. Creates two temp git repos, makes various commit types, runs `mirror-sync.sh`, and asserts correctness. This runs in CI alongside the fast job. Test cases:

1. **Project-only commit**: files and message appear in public repo unchanged
2. **Devshop-only commit**: skipped — no commit in public repo
3. **Mixed commit**: devshop files excluded, message stripped below `---devshop---`
4. **CLAUDE.md stripping**: `## Devshop Conventions` section removed from public copy, other sections preserved
5. **Private manifest paths**: files marked `[private]` in `manifest.txt` never appear in public repo
6. **Hardcoded private paths**: `.devshop/notes/bootstrap/`, `notes/`, `.claude/`, `.gstack/` never appear
7. **First-run squash**: empty public repo gets a single "Initial commit"
8. **Incremental replay**: only new commits since `.mirror-sha` are processed

Each test case: set up repos → run `mirror-sync.sh` → assert (file presence/absence, commit message content, commit count). Exit 1 on first failure with clear diagnostic.

**Step 11c: Create `.github/workflows/public-mirror.yml`**

```yaml
name: Public Mirror
on:
  push:
    branches: [main]

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Full history for commit replay

      - name: Clone public repo
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.MIRROR_DEPLOY_KEY }}" > ~/.ssh/mirror_key
          chmod 600 ~/.ssh/mirror_key
          ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
          export GIT_SSH_COMMAND="ssh -i ~/.ssh/mirror_key"
          PUBLIC_URL="git@github.com:${{ vars.PUBLIC_MIRROR_REPO }}.git"

          if git ls-remote --heads "$PUBLIC_URL" main | grep -q main; then
            git clone "$PUBLIC_URL" /tmp/public-mirror
          else
            mkdir /tmp/public-mirror && cd /tmp/public-mirror && git init && git checkout -b main
          fi

      - name: Run mirror sync
        run: bash .devshop/scripts/mirror-sync.sh . /tmp/public-mirror

      - name: Push to public repo
        run: |
          export GIT_SSH_COMMAND="ssh -i ~/.ssh/mirror_key"
          PUBLIC_URL="git@github.com:${{ vars.PUBLIC_MIRROR_REPO }}.git"
          cd /tmp/public-mirror
          git remote add public "$PUBLIC_URL" 2>/dev/null || git remote set-url public "$PUBLIC_URL"
          git push public main

      - name: Post-push verification
        run: |
          # Verify no private files leaked to public repo
          cd /tmp/public-mirror
          LEAKED=""
          for path in .devshop .dcg.toml notes .claude .gstack; do
            [ -e "$path" ] && LEAKED="$LEAKED $path"
          done
          # Check CLAUDE.md has no devshop section
          if [ -f CLAUDE.md ] && grep -q "## Devshop Conventions" CLAUDE.md; then
            LEAKED="$LEAKED CLAUDE.md(devshop-section)"
          fi
          # Check no ---devshop--- in any commit message
          if git log --format=%B | grep -q "^---devshop---"; then
            LEAKED="$LEAKED commit-messages(devshop-divider)"
          fi
          if [ -n "$LEAKED" ]; then
            echo "::error::Private content leaked to public mirror:$LEAKED"
            exit 1
          fi
```

Key decisions:

- **No force-push**: public repo has stable SHAs. Anyone who cloned it can `git pull` normally.
- **Commit-by-commit replay**: preserves individual commit history in the public repo (each private commit that touches project files becomes one public commit).
- **`.mirror-sha` tracking**: simple, self-contained — no external state, no tags on the private repo.
- **First-run squash**: pre-devshop history is messy. Start the public repo clean, then replay incrementally.
- **No `git filter-repo` dependency**: pure bash + git. No `pip install` needed.
- **Deploy key (not PAT)**: scoped to the single public repo with write access.
- **`.devshop/notes/bootstrap/`, `notes/`, `.claude/`, `.gstack/` hardcoded**: these are not in the manifest (project-specific or tool-specific, not template-synced) but are still private. `.claude/` contains Claude Code config and skills (including the 1.6GB gstack vendor). `.gstack/` contains gstack project data (plans, sessions).

**Step 11d: Add `---devshop---` convention to `.devshop/CLAUDE.md`**

This is covered in Step 9 above (the commit message convention is part of the devshop conventions section of CLAUDE.md).

#### Phase 0a Checkpoint (devshop is built)

- [ ] `pnpm install` succeeds from repo root (monorepo structure valid)
- [ ] Pre-commit hook blocks a commit with unlinted code
- [ ] Pre-commit hook blocks a commit containing a secret pattern (test with a fake API key string)
- [ ] gitleaks does NOT false-positive on Supabase anon key or PostHog public key (`.gitleaks.toml` allowlist works)
- [ ] Safety hook blocks `git reset --hard` when attempted in a Claude Code session
- [ ] `docker ps` works inside devcontainer (Docker-in-Docker is functional)
- [ ] `.github/workflows/ci.yml` exists, is valid YAML, includes gitleaks step, and maps all required secrets
- [ ] All Dockerfile binary installs are version-pinned via `devcontainer.json` build args and SHA256 checksum-verified via `checksums.sha256` (git-delta, supabase-cli, DCG, gitleaks)
- [ ] `.devshop/OVERVIEW.md` exists (bird's eye, ~60-80 lines)
- [ ] `.devshop/GUIDE.md` exists (full operational reference with workflow + new-project checklist)
- [ ] All seven devshop skill files exist (spec, implement, test-review, pre-ship, post-merge, status, init)
- [ ] `.devshop/TODOS.md` exists (devshop tactical backlog)
- [ ] `.devshop/ROADMAP.md` exists (devshop strategic backlog)
- [ ] `PRODUCT-ROADMAP.md` exists (project strategic backlog template)
- [ ] Claude cannot write to `.devcontainer/` files (write-deny rules enforced)
- [ ] Security-critical files are root-owned: `.claude/settings.json`, `.devcontainer/devcontainer.json`, `.devcontainer/init-firewall.sh` (`ls -la` shows `root root` and `644` permissions)
- [ ] `.github/workflows/public-mirror.yml` exists and is valid YAML
- [ ] `.devshop/manifest.txt` has `[private]` annotations on all devshop-internal paths
- [ ] Mirror scripts exist: `mirror-sync.sh`, `test-mirror-sync.sh`, `check-devshop-commit-msg.sh`
- [ ] `test-mirror-sync.sh` passes (all 8 test cases green)
- [ ] PreToolUse hook for `---devshop---` commit message enforcement is registered in `.claude/settings.json`
- [ ] CLAUDE.md includes `---devshop---` commit message convention

---

### Phase 0b: Initialize New Project

> **Historical**: The generic, reusable version of this process now lives in:
>
> - **Skill**: `/devshop:init` (`.claude/skills/devshop/init/SKILL.md`) — full step detail
> - **Checklist**: `.devshop/GUIDE.md` § "Starting a New Project" — compact summary with checkboxes
>
> The content below is the lalista-specific execution record. For new projects, run `/devshop:init` instead.

<details>
<summary>Lalista-specific execution record (Phase 0b)</summary>

_Run this for every new project — lalista is the first. This is the repeatable checklist documented in `.devshop/GUIDE.md` under "Starting a new project."_

#### Prerequisites (Human actions — complete before any code)

- **[HUMAN]** Create Vercel account at vercel.com, install the Vercel GitHub App (one-time — enables auto-deploy on push and preview URLs on PRs), import the lalista GitHub repo (set root directory to `apps/web`)
- **[HUMAN]** Add `VERCEL_TOKEN` to `.devcontainer/.env` (created in the "Accounts to Set Up" table above). This allows non-interactive Vercel CLI usage inside the devcontainer and survives container rebuilds.
- **[HUMAN]** Create Sentry account at sentry.io, create "lalista" project (React)
- **[HUMAN]** Create PostHog account at posthog.com, create "lalista" project
- **[HUMAN]** Enroll in Apple Developer Program at developer.apple.com ($99/yr) — start this now, approval takes 1-2 days. Required for Sign in with Apple on web (Phase 1d): create a Service ID and register your domain once approved.
- **[HUMAN]** Add all GitHub Secrets listed above to the repo (including `MIRROR_DEPLOY_KEY`)
- **[HUMAN]** Rename the existing GitHub repo from `lalista` to `lalista-dev` and mark it private (Settings → General → Repository name + Danger Zone → Change visibility). Update your local remote: `git remote set-url origin git@github.com:username/lalista-dev.git`
- **[HUMAN]** Set up the public mirror repo:
  1. Create a public GitHub repo called `lalista` (the clean name). Must be completely empty (no README, no .gitignore, no license). The mirror Action pushes the initial content.
  2. Generate an SSH deploy key pair: `ssh-keygen -t ed25519 -f mirror_key -C "public-mirror-deploy-key" -N ""`
  3. Add the PUBLIC key (`mirror_key.pub`) as a deploy key on the PUBLIC repo (`lalista`): repo Settings → Deploy keys → Add deploy key (check "Allow write access")
  4. Add the PRIVATE key (`mirror_key` contents) as a secret on the PRIVATE repo (`lalista-dev`): Settings → Secrets → Actions → `MIRROR_DEPLOY_KEY`
  5. Add a repository variable on the PRIVATE repo: Settings → Variables → Actions → `PUBLIC_MIRROR_REPO` = `username/lalista`
  6. Delete the key files: `rm mirror_key mirror_key.pub`
- Configure branch protection on `main` — **must be done AFTER the first PR has been pushed and CI has run at least once**. GitHub can only require a status check that has already produced a result. If protection is enabled before CI has ever run against `main`, GitHub won't recognize `"ci"` as a valid check name and protection silently does nothing. Sequence: push first PR → verify CI produces a green `ci` check → then enable protection:
  ```bash
  gh api repos/{owner}/{repo}/branches/main/protection \
    --method PUT \
    --field 'required_status_checks={"strict":true,"contexts":["ci"]}' \
    --field enforce_admins=true \
    --field required_pull_request_reviews=null \
    --field restrictions=null
  ```
- Vercel env vars are set via CLI in Phase 0b Step 3b (after `vercel link`), not in the dashboard. Build config is in `apps/web/vercel.json` — do not override install/build commands in the dashboard.

Note: `apps/web/vercel.json` must be created during scaffolding (Phase 0b Step 3) with monorepo-aware install and build commands:

```json
{
  "installCommand": "cd ../.. && pnpm install",
  "buildCommand": "cd ../.. && pnpm turbo run build --filter apps/web"
}
```

Without this, Vercel runs `pnpm install` from `apps/web/` with no awareness of workspace packages, and `@<project>/core` / `@<project>/ui` imports fail during build.

- **[HUMAN]** Add credentials to `.devcontainer/.env` (already gitignored, read-protected by `.claude/settings.json`):

  ```
  # Vercel
  VERCEL_TOKEN=<personal-access-token>

  # Supabase
  SUPABASE_URL=https://<project-ref>.supabase.co
  SUPABASE_ANON_KEY=<anon-key>
  SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
  SUPABASE_ACCESS_TOKEN=<personal-access-token>

  # Sentry
  SENTRY_DSN=https://<key>@o<org-id>.ingest.sentry.io/<project-id>
  SENTRY_AUTH_TOKEN=<auth-token>

  # PostHog
  NEXT_PUBLIC_POSTHOG_KEY=<project-api-key>
  ```

  Where to find each:
  - Vercel: `vercel.com/account/tokens`
  - Supabase URL + anon key + service role key: Project Settings → API
  - Supabase access token: `supabase.com/dashboard/account/tokens`
  - Sentry DSN: Project Settings → Client Keys. Auth token: Org Settings → Auth Tokens.
  - PostHog: Project Settings → Project API key

  `SUPABASE_SERVICE_ROLE_KEY` is required for `supabase gen types`. `SUPABASE_ACCESS_TOKEN` is required for `supabase link`. Step 3b pipes the Supabase/Sentry/PostHog vars to Vercel automatically — no need to enter them twice.

#### Steps (Claude executes in order)

**Step 0: Install gstack**

gstack is a per-project vendored dependency — not part of the devshop template sync. Each project installs and upgrades independently via `/gstack-upgrade`.

```bash
git clone https://github.com/garrytan/gstack.git .claude/skills/gstack
cd .claude/skills/gstack && ./setup
```

Note: if `./setup` fails due to the virtiofs mount (see memory: "gstack Setup — virtiofs Build Workaround"), build from `/tmp` with absolute source paths. The devshop workflow depends on gstack — all lifecycle skills (`/office-hours`, `/autoplan`, `/review`, `/qa`, `/ship`, etc.) are gstack skills.

**Step 1: Scaffold `packages/core`**

- `src/supabase.types.ts` — run `supabase gen types typescript --project-id <ref>` to generate (uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from `.devcontainer/.env`)
- `src/supabase.ts` — typed Supabase client factory (`createClient(config: CoreConfig)` — framework-agnostic, does NOT read env vars directly)
- `src/models/` — shared TypeScript types (Item, Store, Household, ListEntry, etc. matching the DB schema)
- `src/api/items.ts`, `stores.ts`, `addItem.ts`, `auth.ts` — typed wrappers (stubs with TODOs for Phase 1)
- `vitest.config.ts` + one passing smoke test
- `package.json` with correct name (`@lalista/core`), `"main": "src/index.ts"`, `@supabase/supabase-js` as a dependency, TypeScript config

**Step 2: Scaffold `packages/ui`**

- `src/tokens.ts` — all design tokens as typed constants — single source of truth. Must be framework-agnostic: no Tailwind utilities, no React imports. Just typed constants. Includes:
  - **Colors**: semantic theme tokens (`background`, `text`, `accent`, `border`, etc.) with `light` and `dark` variants. Project fills in actual values during design system migration; scaffold provides sensible defaults (white/black/blue).
  - **Breakpoints**: `{ sm: 375, md: 768, lg: 1024, xl: 1440, '2xl': 2560 }` — iPhone SE to large desktop.
  - **Spacing**: 8px base grid scale.
  - **Fonts**: placeholder font stack; project replaces during design system migration.
- `tailwind.config.js` — standard Tailwind config for Next.js (PostCSS pipeline), imports breakpoints + colors + spacing from `tokens.ts`. Maps theme tokens to CSS custom properties (e.g., `--color-background`) so components use `bg-[var(--color-background)]` or equivalent Tailwind theme classes. Dark mode via `darkMode: 'class'` — supports both `prefers-color-scheme` auto-detection (JS reads OS preference and sets the class on `<html>`) and an optional user toggle.
- One base component (`Button`) as proof-of-concept — web variant uses Tailwind classes with theme tokens (not hardcoded colors), responsive padding.
- `package.json` with name `@lalista/ui`, `"main": "src/index.ts"`

**Step 3: Scaffold `apps/web`**

```bash
cd /workspace
pnpm create next-app apps/web --typescript --tailwind --app --no-src-dir --import-alias "@/*" --no-git
```

Then:

- Configure Tailwind to use `@lalista/ui/tailwind.config.js` as the base config (PostCSS pipeline)
- Add `transpilePackages: ['@lalista/core', '@lalista/ui']` to `next.config.js`
- Add `@lalista/core` and `@lalista/ui` as workspace deps: `pnpm add @lalista/core @lalista/ui --filter apps/web`
- Add Sentry: `pnpm add @sentry/nextjs --filter apps/web`, then run `npx @sentry/wizard@latest -i nextjs` to generate the required config files (`sentry.client.config.ts`, `sentry.server.config.ts`, `instrumentation.ts`, `next.config.js` wrapping with `withSentryConfig`). Create `apps/web/app/global-error.tsx` (Next.js App Router error boundary — catches uncaught errors and reports to Sentry with a graceful fallback UI). Verify by triggering a test error and confirming it appears in the Sentry dashboard.
- Add PostHog: `pnpm add posthog-js --filter apps/web`. Create `apps/web/app/providers.tsx` as a client component that initializes PostHog (`posthog.init()` with `NEXT_PUBLIC_POSTHOG_KEY` — must run client-side only). Wrap the root layout (`app/layout.tsx`) with `PostHogProvider`. Fire a test `$pageview` event and verify it appears in the PostHog dashboard.
- PWA setup (manifest + meta tags only — service worker deferred to `PRODUCT-ROADMAP.md`): Create `public/manifest.json` (app name, placeholder icon, theme color from design tokens, `"display": "standalone"`). Add PWA meta tags to `app/layout.tsx`: `<link rel="manifest" href="/manifest.json">`, `<meta name="apple-mobile-web-app-capable" content="yes">`, `<meta name="apple-mobile-web-app-status-bar-style" content="default">`, `<link rel="apple-touch-icon" href="/icon-192.png">`. Do NOT add `@serwist/next` or service worker yet — caching during active development causes confusing stale-data bugs. The service worker is added after core screens are stable (see `PRODUCT-ROADMAP.md`). Placeholder icons (solid color square) are replaced with real branding during Phase 1b design system migration.
- **Security headers**: Add `headers()` to `next.config.js` with production-safe defaults:
  - `Content-Security-Policy`: strict default-src, script-src, style-src, connect-src (allow Supabase, Sentry, PostHog endpoints). Start strict, loosen as needed.
  - `Strict-Transport-Security`: `max-age=63072000; includeSubDomains; preload`
  - `X-Frame-Options`: `DENY`
  - `X-Content-Type-Options`: `nosniff`
  - `Referrer-Policy`: `strict-origin-when-cross-origin`
  - `Permissions-Policy`: disable camera, microphone, geolocation unless needed
    Document CORS expectations for Supabase edge functions in .devshop/GUIDE.md (Supabase handles CORS at the gateway — verify default policy is origin-restricted, not `*`).
- Create `apps/web/vercel.json` for monorepo-aware builds (see Phase 0b prerequisites for contents)
- Remove default Next.js placeholder content (page.tsx, globals.css reset)
- Add placeholder home page that imports and uses a `@lalista/ui` Button component (validates workspace linking)
- Delete the generated `eslint.config.mjs` and replace with the root-extending pattern from Phase 0a Step 4b

**Step 3b: Link Vercel project and set env vars via CLI**

First, add the Vercel CLI as a project devDependency (not global — Vercel is a hosting choice, not a devshop fundamental):

```bash
pnpm add -D -w vercel
```

Run inside the devcontainer (uses `VERCEL_TOKEN` from `.devcontainer/.env`):

```bash
pnpm exec vercel link --yes --project lalista --token $VERCEL_TOKEN

# Pipe values from .devcontainer/.env — no interactive prompts
echo "$SUPABASE_URL" | pnpm exec vercel env add NEXT_PUBLIC_SUPABASE_URL production preview development --token $VERCEL_TOKEN
echo "$SUPABASE_ANON_KEY" | pnpm exec vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production preview development --token $VERCEL_TOKEN
echo "$NEXT_PUBLIC_POSTHOG_KEY" | pnpm exec vercel env add NEXT_PUBLIC_POSTHOG_KEY production preview development --token $VERCEL_TOKEN
echo "$SENTRY_DSN" | pnpm exec vercel env add NEXT_PUBLIC_SENTRY_DSN production preview development --token $VERCEL_TOKEN
echo "$SENTRY_AUTH_TOKEN" | pnpm exec vercel env add SENTRY_AUTH_TOKEN production preview --token $VERCEL_TOKEN
```

Values are read from `.devcontainer/.env` (already loaded into the container environment). The user enters them once in `.env`; this step syncs them to Vercel automatically.

**Step 4: Create `METRICS.md`**

> ⚠️ NOT IN LIVING DOCS — the lalista-specific event taxonomy below (item_added,
> item_bought, etc.) is a project example. The METRICS.md structure and metrics
> principles are in GUIDE.md § Metrics Lifecycle.

Create the project-level metrics source of truth:

```markdown
# Metrics

## Events

| Event                | When it fires                  | Key properties                           | Why we care           |
| -------------------- | ------------------------------ | ---------------------------------------- | --------------------- |
| item_added           | add-item edge fn succeeds      | store, was_disambiguated, input_language | Core action frequency |
| item_bought          | mark_item_bought RPC succeeds  | time_on_list_seconds                     | Purchase velocity     |
| disambiguation_shown | edge fn returns candidates     | candidate_count, final_selection         | NLP quality signal    |
| auth_signed_in       | auth session created           | method (apple, email)                    | Auth funnel           |
| auth_signed_out      | sign out completed             | session_duration_seconds                 | Session patterns      |
| store_routed         | purchase_history routing fires | store_name, confidence_score             | Routing accuracy      |
| error_displayed      | user-visible error shown       | error_type, screen                       | Error frequency       |

## Feature Flags

| Flag | Controls | Default |
| ---- | -------- | ------- |
```

This is a starting point — updated as features are implemented. `/spec` references it; `/implement` instruments it.

**Step 5: Run `/setup-deploy`**

Run the gstack `/setup-deploy` skill to configure `/land-and-deploy` with the Vercel production URL and health check endpoints. Must be done after Vercel is linked (Step 3) and before the first use of `/land-and-deploy`.

**Step 6: Enable documentation enforcement hooks**

All scaffold commits from Steps 1–3 are now landed. Enable the documentation hooks that were intentionally deferred:

1. Wire up the deferred pre-commit hook — update `.husky/pre-commit` to add:
   ```sh
   bash .devshop/scripts/check-devshop-docs.sh
   ```
   Note: `check-file-headers.sh` is NOT wired into pre-commit. File header enforcement is handled by `/pre-ship` convention check instead — mechanical pre-commit enforcement produces mechanical documentation. `/pre-ship` judges which files benefit from headers (non-trivial: >1 export or >50 lines) and flags missing ones.
2. Add `eslint-plugin-jsdoc` as a root dev dependency:
   ```bash
   pnpm add -D -w eslint-plugin-jsdoc
   ```
3. Configure `jsdoc/require-jsdoc` in root `eslint.config.mjs` for exported functions only. Must cover both function declarations and arrow function exports — arrow functions need explicit `contexts` since `require-jsdoc` doesn't catch them by default:
   ```js
   {
     plugins: { jsdoc },
     rules: {
       'jsdoc/require-jsdoc': ['warn', {
         require: { FunctionDeclaration: true },
         contexts: ['ExportNamedDeclaration > VariableDeclaration > VariableDeclarator > ArrowFunctionExpression'],
         checkConstructors: false,
       }],
     },
   }
   ```

From this point forward, every exported function must have a JSDoc comment (ESLint enforces via lint-staged and CI). File headers (`// What:` / `// Why:` / `// Does NOT:`) are a convention checked by `/pre-ship`, not a pre-commit gate.

**Step 7: Seed `abra-kadabra` template**

- **[HUMAN]** On GitHub: create new repo called `abra-kadabra`, check "Template repository"
- **[HUMAN]** Fill in `.devshop/template-remote` with your template repo URL (e.g. `https://github.com/<org>/<template-repo>`). This file is gitignored — each clone sets it locally. The sync scripts won't work until this is set.
- Run `sync-to-template.sh` — detects the remote is empty and performs the initial seed automatically. No manual file copying.
- Note: root `CLAUDE.md` is project-specific and is NOT copied — new projects write their own. `.devshop/CLAUDE.md` is copied as the source for the devshop conventions section.

**Step 8: `/cso` baseline infra audit**

- Run `/cso` (gstack) against the repo for a baseline infrastructure security audit (CI/CD config, secrets setup, firewall, `.claude/settings.json`, Docker-in-Docker isolation)

**Step 9: Keepalive cron + service alerts**

1. Create `.github/workflows/keepalive.yml` — a scheduled GitHub Action that pings the production URL weekly. Prevents Supabase free tier from pausing after 1 week of inactivity (paused = silent production outage until manually resumed).

   ```yaml
   name: Keepalive
   on:
     schedule:
       - cron: '0 9 * * 1' # Every Monday at 9am UTC
   jobs:
     ping:
       runs-on: ubuntu-latest
       steps:
         - name: Ping production
           run: |
             STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${{ vars.PRODUCTION_URL }}")
             if [ "$STATUS" != "200" ]; then
               echo "::warning::Production returned $STATUS"
             fi
   ```

   Add `PRODUCTION_URL` as a repository variable (e.g., `https://lalista.vercel.app`).

2. **[HUMAN]** Set up quota alerts in each service's dashboard (native, free, no infrastructure):
   - Sentry: Settings → Alerts → Spike Protection (auto-enabled) + quota alert at 80%
   - PostHog: Settings → Billing → usage alerts
   - Vercel: Settings → Usage → email notifications
   - GitHub Actions: monitor via monthly `/retro` (no native alert)

Add these to the `/devshop:init` checklist in .devshop/GUIDE.md under the new-project setup.

#### Phase 0b Checkpoint (project is initialized)

- [ ] `pnpm turbo run test` passes (placeholder tests in packages/core)
- [ ] `pnpm turbo run build` succeeds (web app builds without errors)
- [ ] Push a PR → GitHub Actions CI runs → green (including gitleaks)
- [ ] Vercel preview URL appears in PR comments automatically
- [ ] Merge to main → Vercel production deploys
- [ ] Trigger a test Sentry error from web → appears in Sentry dashboard
- [ ] PostHog dashboard receives a test event from web
- [ ] `METRICS.md` exists with initial event taxonomy
- [ ] `abra-kadabra` repo created on GitHub and seeded via `sync-to-template.sh`
- [ ] Public mirror repo receives filtered commits after merge to main
- [ ] Public mirror has no `.devshop/`, `.dcg.toml` files (verified by post-push step in mirror Action)
- [ ] Public mirror `CLAUDE.md` has no `## Devshop Conventions` section
- [ ] A devshop-only commit on main does not appear in the public mirror
- [ ] Commit messages in the public mirror have no `---devshop---` sections
- [ ] `/cso` baseline audit passes

</details>

---

### Phase 1: Migrate lalista to React (Web)

> Migrated to `PRODUCT-ROADMAP.md` § v0. Original detail preserved below for reference.

> **Project-specific migration plan** — not devshop machinery. This is what
> `/office-hours` + `/autoplan` + `/build` should produce for a specific project.
> Reusable patterns discovered here have been extracted to `.devshop/GUIDE.md`
> conventions and `.devshop/CLAUDE.md` non-negotiables. A future `/devshop:migrate`
> skill (see `.devshop/ROADMAP.md` v+) may parametrize this process.

_Guinea pig — every step validates the dev-shop machinery. All steps here are lalista-specific and do not belong in `abra-kadabra`._

**Goal**: Web app is a full replacement for the core flows of the Swift app. All core flows work: sign in, add item, view list, mark bought, settings. All tests green. CI passing.

#### 1a: Archive the Swift app

```bash
git mv ios ios-archive
git commit -m "archive: rename ios/ to ios-archive/ (reference during React migration)"
```

#### 1b: Design system migration (web)

1. Port DESIGN.md tokens → `packages/ui/src/tokens.ts` (typed JS constants — framework-agnostic)
2. Configure `packages/ui/tailwind.config.js` to reference tokens from `tokens.ts`
3. Load fonts on web: use `next/font/google` in `app/layout.tsx` for Fraunces + Plus Jakarta Sans (self-hosted at build time, no runtime Google requests)
4. Build base components: `Button`, `Text`, `Card`, `Input`, `Divider` — with lalista styling. Web variants use Tailwind classes.
5. Replace PWA placeholder icons with branded icons (generate from DESIGN.md's terracotta/cream palette — sizes: 192x192, 512x512, plus apple-touch-icon). Update `manifest.json` theme color and background color to match design tokens.
6. Tests: snapshot tests for each component in light + dark mode (Vitest)

#### 1c: Supabase integration in `packages/core`

1. Run `supabase gen types typescript` → save to `src/supabase.types.ts`
2. Build `src/supabase.ts` — typed Supabase client factory (framework-agnostic: takes config, returns typed client)
3. Build typed API wrappers:
   - `src/api/items.ts` — list_entries read + delete. **Do not write direct insert/update for mark-bought** — use the `mark_item_bought` RPC: `supabase.rpc('mark_item_bought', { entry_id })`. The schema comment is explicit: "Written atomically by mark_item_bought() — never directly by the client." Direct writes will be blocked by RLS (purchase_history has no client insert policy).
   - `src/api/stores.ts` — store list
   - `src/api/addItem.ts` — typed wrapper for add-item edge function. **Must handle the disambiguation response**: the edge function returns either a resolved item or a list of candidates when confidence is below threshold. The caller must check `response.status` and surface the disambiguation UI when candidates are returned — not just assume the item was added.
   - `src/api/auth.ts` — sign in, sign out, get session, subscribe to auth changes
   - `src/api/realtime.ts` — Supabase Realtime channel subscription for `list_entries` filtered by `household_id`. **Decision: use Supabase Realtime channels.** This is a shared household list — multiple users can add/remove items simultaneously (matches the Swift app's behavior). Without realtime, the list goes stale until manual refresh. Polling was considered but rejected — it adds latency and doesn't match user expectations for a shared list.
4. Unit tests (Vitest) for all API functions — mock the Supabase client for unit tests; integration tests hit `supabase start` (see testing non-negotiables)
5. **Create `supabase/seed.sql`** — minimum test fixtures for integration tests and CI: at least one household, two users in different households (required for RLS boundary tests — User A's data must be invisible to User B), one store, and a few list entries. Reference the existing migrations to match the schema exactly. This file is loaded by `supabase start` automatically and by CI before running integration tests.
6. **Run `supabase link --project-ref <ref>`** inside the devcontainer (uses `SUPABASE_ACCESS_TOKEN` from `.devcontainer/.env`). Then verify `supabase start` works (spins up local Postgres, Auth, etc. via Docker-in-Docker). If image pulls fail on network errors, add `ghcr.io` to the firewall (GitHub Container Registry — may already be covered by GitHub IP ranges).
7. **Update `ci.yml` in this PR**: add Supabase service container, `seed.sql` load, integration test step, type drift check (`supabase gen types` → diff committed types → fail if different). CI enforcement lands in the same PR as the code it tests. **Implementation note**: verify which Supabase env vars are actually needed for `supabase start` + `supabase gen types` in CI (e.g., does `supabase start` need `SUPABASE_ACCESS_TOKEN`?). Wire only what's confirmed.
8. **Automated `pg_dump` before migration deploys**: add a step to the deploy flow (wired into `/post-merge` via `/land-and-deploy`) that runs `pg_dump` against production before applying any new migrations. Store the dump as a GitHub Actions artifact (retained 30 days) or push to a private gist. This is cheap insurance — free-tier Supabase has no point-in-time recovery, and rollback SQL is untested until you need it in a panic. Must be in place before real user data exists.

Reference: `ios-archive/ios/Sources/Services/` for the exact API call patterns already implemented in Swift.

#### 1d: Auth (web)

**Prerequisite**: Apple Developer account must be approved before implementing Apple sign-in. If still pending, implement email/password first and add Apple sign-in once the account is active — do not implement as a stub.

1. **Web**: Supabase Auth form (email + password + Sign in with Apple button). Requires Apple Service ID and domain verification in Apple Developer portal.
2. Persist session via Supabase's built-in session storage, auto-refresh, redirect to list on auth
3. Sign-out flow
4. **Household onboarding flow** (required — without this, new users see a blank list with no way forward): after first sign-in, check if the user belongs to a household (`household_members` query). If not: show a "Create household" / "Join household" screen. Create: inserts into `households` + `household_members` with role `owner`. Join: invite flow (out of scope for v1 — show a placeholder "Ask a family member to add you" message and block on this). Do not redirect to the list view until the user has a household.
5. **Route protection middleware**: create `apps/web/middleware.ts` using `@supabase/ssr` to check session on every request. Redirect unauthenticated users to `/sign-in`. Redirect authenticated users without a household to `/onboarding`. Allow `/sign-in` and `/onboarding` without redirect loops. This must ship in the same PR as auth — never ship auth without protected routes.
6. Tests: unit tests for auth state transitions + household check logic

#### 1e: Core screens (web)

**Before building screens**: install Playwright for E2E tests (devshop non-negotiable — E2E tests are written alongside features, never after):

```bash
pnpm add -D @playwright/test --filter apps/web
npx playwright install chromium
```

Create `apps/web/playwright.config.ts` with two projects: mobile (375px viewport) and desktop (1440px viewport). Both must pass. If Playwright can't download Chromium due to the firewall, use the system Chromium (`sudo apt-get install -y chromium` + `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`).

For each screen: implement → write tests (unit + E2E) → instrument metrics → mark done. Do not move to next screen until tests pass.

1. **Sign-in screen**: email/password form + Apple sign-in button
2. **Household onboarding screen**: create household (name input) or "ask a family member to add you" placeholder — shown after sign-in if user has no household (see 1d)
3. **List view**: items grouped by store, item rows with buy button (calls `mark_item_bought` RPC — not a direct table write), loading/empty/error states. Subscribes to Realtime channel for live updates.
4. **Add item flow**: text input + submit + **disambiguation sheet** — when the edge function returns candidates instead of a resolved item, show a bottom sheet listing the candidates for the user to pick from. Reference: `ios-archive/ios/Sources/Views/List/DisambiguationSheet.swift`. This is a first-class flow, not an edge case — it fires whenever NLP confidence is below threshold.
5. **Offline strategy: online-only for v1.** The Swift app had full offline (SwiftData, 24h TTL, trigram matching). The web app is a new product with different expectations — v1 is online-only with graceful error states when network is unavailable. No caching layer, no persistence, no React Query `persistQueryClient`. This keeps the data layer simple and avoids cache-vs-realtime conflicts. Offline support (read-only cache or full offline with sync) is deferred to `PRODUCT-ROADMAP.md`. The data layer should not be designed around caching — add it later if needed.
6. **Theme auto-detection E2E test**: one Playwright test that emulates `prefers-color-scheme: dark` via `page.emulateMedia({ colorScheme: 'dark' })` and asserts the `<html>` element has the correct dark mode class. Covers the JS mechanism that reads OS preference and sets the class. `/pre-ship` visual checks (responsive+theme check at 4 viewport/theme combos + `/design-review`) provide the rendering verification on top of this.
7. **Item detail**: item name, store, brand, edit, delete
8. **Settings screen**: sign out, household name
9. **Sync error banner**: shown when Supabase is unreachable

Reference for layout/behavior: `ios-archive/ios/Sources/Views/` (Swift code shows what each screen should do)

Design reference: `DESIGN.md` — all colors, fonts, spacing must match

#### 1f: Edge function connection

1. Verify `add-item` edge function works with the React web client (same remote Supabase project)
2. **Add `getUser()` auth validation** inside the edge function — defense in depth against the `--no-verify-jwt` gap:
   ```typescript
   const authHeader = req.headers.get('Authorization');
   const token = authHeader?.replace('Bearer ', '');
   const {
     data: { user },
     error,
   } = await supabase.auth.getUser(token);
   if (error || !user) {
     return new Response(JSON.stringify({ error: 'Unauthorized' }), {
       status: 401,
       headers: { 'Content-Type': 'application/json' },
     });
   }
   ```
   This validates the token against the Supabase Auth server, not just the JWT signature. Cost: one extra round-trip (~10-20ms). This is a devshop convention — all edge functions validate auth server-side.
3. If Supabase has resolved ES256 JWT gap: redeploy without `--no-verify-jwt` (see TODOS.md)

#### 1g: Testing pass

1. `packages/core`: unit tests (Vitest) — all API wrappers, all models
2. `apps/web`: component tests (React Testing Library + Vitest) for all screens; Playwright E2E for happy path (sign in → add item → see in list → mark bought)
3. **Update `ci.yml` in this PR**: add Playwright E2E step (see Phase 1g CI key decisions in the CI/CD Pipeline section above). CI enforcement lands in the same PR as the tests.
4. All tests pass: `pnpm turbo run test`

#### 1h: Carry-forward items

1. Fix "posted by someone" bug (needs user profile — display name in Supabase Auth metadata)
2. Update `TODOS.md` — carry forward `redeploy-add-item-without-no-verify-jwt` and post-v0 items; close resolved ones. Add: "Rate limit add-item edge function — auth required but no per-user throttle. Low risk for now (few users), revisit when traffic grows."
3. Update `README.md` with new setup instructions
4. Run `/document-release` (gstack) to sync all docs

Note: `ios-archive/` is kept for now — it's still useful as reference for the native migration later. Delete it when native development begins and all screens are ported.

#### Phase 1 Checkpoint

- [ ] Web app on Vercel: sign in → create household (new user) → add item → disambiguation sheet appears when NLP is ambiguous → see item in list → mark bought
- [ ] List updates in real time when a second session adds an item (or offline strategy is documented)
- [ ] Dark mode works
- [ ] Error states handled gracefully (network down, Supabase unreachable)
- [ ] `pnpm turbo run test` passes: all unit + component + integration tests green
- [ ] Playwright web E2E passes in CI
- [ ] CI includes: gitleaks + lint + typecheck + Supabase integration tests + type drift check + Playwright E2E + build
- [ ] Sentry catches an error from the web app
- [ ] PostHog receives events from the web app matching `METRICS.md` taxonomy
- [ ] A broken test blocks PR merge (verify by intentionally breaking one)
- [ ] Edge function validates auth server-side via `getUser()`

---

### Phase 2: Advanced Web Dev-Shop Features

> **Moved to `.devshop/ROADMAP.md`** — these are devshop improvements, tracked in
> the devshop strategic backlog:
>
> - Changesets, Dependabot → v1
> - Visual regression → v+

_Original content preserved below for reference._

#### 2a: Developer tooling improvements

1. **Changesets**: `pnpm add -D -w @changesets/cli` + `.changeset/config.json` — automated changelogs in PRs
2. **Dependabot**: create `.github/dependabot.yml` — weekly PRs for npm security updates
3. **Visual regression**: add Playwright screenshot comparison for key screens
   - Store baseline screenshots in `tests/screenshots/`
   - CI step: compare current vs baseline, fail if diff > threshold

#### Phase 2 Checkpoint

- [ ] Dependabot creates its first automated PR
- [ ] Changeset workflow produces a changelog entry
- [ ] Playwright visual regression catches an intentional style change

---

## Verification Checklist (Full System)

> ⚠️ NOT IN LIVING DOCS — historical checklists for lalista construction.
> Init skill has its own verification checklist for new projects.

After Phase 0:

- [ ] `pnpm turbo run test` passes from root
- [ ] PR → CI green (including gitleaks) → Vercel preview URL in PR
- [ ] Merge to main → Vercel production deploys
- [ ] Sentry test error appears in dashboard
- [ ] PostHog test event appears in dashboard
- [ ] Docker-in-Docker works (`docker ps` inside devcontainer)
- [ ] Claude cannot write to devcontainer files

After Phase 1:

- [ ] Web: sign in + add item + view list + mark bought
- [ ] All unit + integration + E2E tests passing in CI
- [ ] A failing test blocks PR merge
- [ ] Pre-commit hook prevents committing unformatted code or secrets
- [ ] Edge function validates auth server-side
- [ ] METRICS.md events are instrumented in the web app

---

## Key Reference Files in This Repo

For the implementing agent — these contain critical content to preserve or reference:

| File                                              | Why it matters                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------- |
| `/workspace/DESIGN.md`                            | Complete design system — ALL styling decisions must reference this        |
| `/workspace/TODOS.md`                             | Open items to carry forward or close during migration                     |
| `/workspace/METRICS.md`                           | Event taxonomy — ALL metrics instrumentation must reference this          |
| `/workspace/supabase/migrations/`                 | 7 SQL files defining the full DB schema — do not modify                   |
| `/workspace/supabase/functions/add-item/index.ts` | The edge function — add auth validation, otherwise don't modify           |
| `/workspace/ios-archive/ios/Sources/Views/`       | Reference for screen layouts during React port                            |
| `/workspace/ios-archive/ios/Sources/Services/`    | Reference for API call patterns during port                               |
| `/workspace/.devcontainer/init-firewall.sh`       | Must update with new domains before Phase 0 network calls work            |
| `/workspace/CLAUDE.md`                            | Single source of truth for Claude — devshop conventions + project context |

---

## Files to Create / Modify

> ⚠️ NOT IN LIVING DOCS — historical file reference table from construction time.

> ⚠️ NOT IN LIVING DOCS — historical implementation tracker from construction time.

| File                                           | Action                                                                                | Phase |
| ---------------------------------------------- | ------------------------------------------------------------------------------------- | ----- |
| `.devcontainer/Dockerfile`                     | Modify: add checksum verification to existing installs                                | 0a    |
| `.devcontainer/devcontainer.json`              | Modify: add DinD feature, DCG/gitleaks build args                                     | 0a    |
| `.devcontainer/init-firewall.sh`               | Modify: add devshop domains + project-specific section                                | 0a    |
| `.gitleaks.toml`                               | Create: gitleaks allowlist for known-safe public client keys                          | 0a    |
| `.dcg.toml`                                    | Create: DCG project-level config                                                      | 0a    |
| `.devshop/version`                             | Create: `0.1.0`                                                                       | 0a    |
| `.devshop/manifest.txt`                        | Create: list of dev-shop layer files for sync scripts                                 | 0a    |
| `.devshop/CLAUDE.md`                           | Create: source for devshop section of root CLAUDE.md                                  | 0a    |
| `.devshop/scripts/sync-to-template.sh`         | Create: sync + auto-bump version                                                      | 0a    |
| `.devshop/scripts/sync-from-template.sh`       | Create                                                                                | 0a    |
| `.devshop/scripts/release.sh`                  | Create: bump version + tag (for direct template repo edits)                           | 0a    |
| `.devshop/scripts/check-file-headers.sh`       | Create                                                                                | 0a    |
| `.devshop/scripts/check-devshop-commit-msg.sh` | Create: PreToolUse hook for ---devshop--- enforcement                                 | 0a    |
| `.devshop/scripts/mirror-sync.sh`              | Create: commit-by-commit mirror sync script                                           | 0a    |
| `.devshop/scripts/test-mirror-sync.sh`         | Create: test harness for mirror sync (8 test cases)                                   | 0a    |
| `.github/workflows/public-mirror.yml`          | Create: commit-by-commit mirror to public repo (no force-push)                        | 0a    |
| `.github/workflows/keepalive.yml`              | Create: weekly ping to prevent Supabase free-tier pause                               | 0b    |
| `.claude/settings.json`                        | Modify: add DCG hook + devshop commit msg hook + write-deny rules                     | 0a    |
| `.claude/skills/devshop/spec/SKILL.md`         | Create                                                                                | 0a    |
| `.claude/skills/devshop/implement/SKILL.md`    | Create                                                                                | 0a    |
| `.claude/skills/devshop/pre-ship/SKILL.md`     | Create                                                                                | 0a    |
| `.claude/skills/devshop/post-merge/SKILL.md`   | Create                                                                                | 0a    |
| `.claude/skills/devshop/test-review/SKILL.md`  | Create: test quality review skill                                                     | 0a    |
| `.claude/skills/devshop/status/SKILL.md`       | Create: session orientation briefing                                                  | 0a    |
| `.claude/skills/devshop/init/SKILL.md`         | Create: guided new-project checklist walkthrough                                      | 0a    |
| `.devshop/TODOS.md`                            | Modify: restructure as tactical backlog (move strategic items to .devshop/ROADMAP.md) | 0a    |
| `.devshop/ROADMAP.md`                          | Create: devshop strategic backlog (capabilities, major improvements)                  | 0a    |
| `PRODUCT-ROADMAP.md`                           | Modify if needed: verify consistency with plan (already exists)                       | 0a    |
| `turbo.json`                                   | Create                                                                                | 0a    |
| `pnpm-workspace.yaml`                          | Create                                                                                | 0a    |
| `tsconfig.base.json`                           | Create: shared TypeScript baseline                                                    | 0a    |
| `eslint.config.mjs`                            | Create: replaces .eslintrc.json (flat config)                                         | 0a    |
| `package.json` (root)                          | Modify: add husky, lint-staged, turbo scripts                                         | 0a    |
| `.github/workflows/ci.yml`                     | Create (evolves in 1c and 1g)                                                         | 0a    |
| `.devshop/OVERVIEW.md`                         | Create: bird's eye view                                                               | 0a    |
| `.devshop/GUIDE.md`                            | Create: full operational reference (living doc)                                       | 0a    |
| `.devshop/scripts/check-devshop-docs.sh`       | Create: pre-commit reminder for doc sync                                              | 0a    |
| `CLAUDE.md`                                    | Modify: add devshop conventions section + project section                             | 0a    |
| `packages/core/`                               | Create                                                                                | 0b    |
| `packages/ui/`                                 | Create                                                                                | 0b    |
| `apps/web/`                                    | Create (Next.js 15 scaffold + Sentry wizard + PostHog provider + vercel.json)         | 0b    |
| `METRICS.md`                                   | Create: event taxonomy                                                                | 0b    |
| `ios/` → `ios-archive/`                        | Rename via git mv                                                                     | 1a    |
| `DESIGN.md`                                    | Modify: add web token mapping section                                                 | 1b    |
| `supabase/seed.sql`                            | Create: test fixtures for integration tests + CI                                      | 1c    |
| `.github/workflows/ci.yml`                     | Modify: add Supabase + integration tests + type drift                                 | 1c    |
| `apps/web/middleware.ts`                       | Create: route protection (redirect unauth to sign-in)                                 | 1d    |
| `supabase/functions/add-item/index.ts`         | Modify: add getUser() auth validation                                                 | 1f    |
| `.github/workflows/ci.yml`                     | Modify: add Playwright E2E                                                            | 1g    |
| `TODOS.md`                                     | Modify: carry forward relevant items, close resolved                                  | 1h    |
| `README.md`                                    | Modify: new setup instructions for React project                                      | 1h    |
