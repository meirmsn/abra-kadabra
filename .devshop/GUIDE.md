<!-- Editorial: enough detail to act on — exact file paths, exact commands, specific gotchas.
     If it's a one-time build instruction, it belongs in notes/bootstrap/, not here.
     If it's a one-line orientation fact, it belongs in README.md.
     This file is the living reference — update it when code structure changes.
     Target: under 500 lines. If a section grows past ~30 lines, consider whether the
     detail belongs in a separate file (see "When to split" at the end). -->

# Abra-Kadabra Dev Shop

## Workflow: Idea to Deployed

### Step 1: Write rough notes

Problem description + rough solution idea. Not a full spec — just enough to seed the conversation.

### Step 2: `/office-hours` (gstack)

Interviews you, challenges framing, produces a product design doc. Forces you to articulate demand, urgency, and scope.

### Step 3: `/autoplan` (gstack)

Runs CEO, design, and engineering review sequentially. Locks in architecture, edge cases, and decisions. Output: a gstack plan in `.gstack/projects/<slug>/`.

- **3b: `/design-shotgun`** (optional) — visual variants before spec. Use for UI-heavy features only. Approve one direction before proceeding.
- **3c: `/design-html`** (optional) — turns approved mockup into an HTML reference file. Claude builds React from this instead of interpreting a description.

### Step 4: `/build` (devshop skill) — autonomous pipeline

One command after autoplan. Chains everything through PR creation, CI verification, and notification. Resumable if the session is interrupted.

**Phase 1: `/spec`** — converts gstack plan into implementation-ready spec. May stop for METRICS.md confirmation (the one interactive moment before PR).

**Phase 2: `/implement`** — reads spec, decomposes into tasks, implements with tests. Stuck protocol: try fix → `/investigate` → ask user. Logs judgment calls in `specs/<name>/tasks.md` § Decisions.

**Phase 3: `/pre-ship`** — quality gates only (no shipping):

1. Devshop docs check
2. Metrics check
3. Responsive + theme check (UI PRs)
4. `/simplify` → test:unit checkpoint
5. `/test-review`
6. `/review` → test:unit checkpoint
7. `/cso` → test:unit checkpoint
8. `/design-review` (UI PRs) → test:unit checkpoint
9. `/qa` (has own fix loop)
10. `/benchmark` (UI PRs)
11. Convention check

**Phase 4: `/ship`** (gstack) — merges base, runs tests + review (final verification), bumps VERSION, pushes, creates PR, auto-invokes `/document-release`.

**Phase 5: CI watch + fix loop** — watches CI via `gh pr checks --watch`. On failure: reads CI logs, reads local test/source code, makes informed fix, verifies locally if possible, pushes. Max 3 fix cycles. Escalates via PR @mention if stuck.

**Phase 6: Audit trail + notify** — posts PR comment with quality gate results, implementation decisions, CI fix summary. Notifies user: "@username PR ready for review."

### Step 5: You review the PR

- Release notes (from `/ship`) + audit trail comment (from `/build`)
- CI green + Vercel preview URL
- You merge or request changes

### Step 6: `/go-live` (devshop skill) — autonomous deploy

One command after you approve the PR.

1. `/land-and-deploy` (gstack) — checks CI green, merges, waits for deploy, verifies prod health
2. `/canary` (gstack) — ~15 min post-deploy monitoring. If fail: stops, notifies with rollback info (no auto-rollback)
3. **Structured reflection** — routes learnings to committed files (CLAUDE.md, `.devshop/GUIDE.md`, backlogs)
4. **Notify** — PR comment: "@username deployed. Canary: pass/fail. Rollback SHA: xxx"

---

## Where Things Happen

### Auth

- Logic: `packages/core/src/api/auth.ts`
- Screens: `apps/web/app/(auth)/sign-in/`, `apps/web/app/(auth)/onboarding/`
- Route protection: `apps/web/middleware.ts` (Supabase SSR session check)
- Config: Supabase Auth dashboard, Apple Developer portal (Service ID + domain verification)

### Data Flow

- Schema: `supabase/migrations/` (7 SQL files — do not modify directly; new migrations only)
- Generated types: `packages/core/src/supabase.types.ts` (regenerated via `supabase gen types`)
- Client factory: `packages/core/src/supabase.ts` (framework-agnostic, takes config)
- API wrappers: `packages/core/src/api/` (items, stores, addItem, auth, realtime)
- Edge functions: `supabase/functions/` (add-item with Claude NLP + auth validation)

**Migration workflow** (quick reference):

```bash
# Create a new migration
supabase migration new <name>        # creates supabase/migrations/<timestamp>_<name>.sql

# Apply locally (resets local DB and replays all migrations)
supabase db reset

# Apply to remote project
supabase db push

# Regenerate TypeScript types after schema changes
supabase gen types typescript --project-id <ref> > packages/core/src/supabase.types.ts
```

### Design System

- Source of truth: `DESIGN.md`
- Tokens: `packages/ui/src/tokens.ts` (typed JS constants — framework-agnostic, no Tailwind/React imports)
- Tailwind config: `packages/ui/tailwind.config.js` (imports from tokens.ts, maps to CSS custom properties)
- Components: `packages/ui/src/` (shared), `apps/web/components/` (page-level)
- Fonts: loaded via `next/font/google` in `apps/web/app/layout.tsx` (self-hosted at build time)

### Testing

- Unit tests: `packages/core/**/*.test.ts`, `packages/ui/**/*.test.ts` (Vitest, mock externals)
- Integration tests: `packages/core/**/*.integration.test.ts` (Vitest, real local Supabase via Docker-in-Docker)
- E2E tests: `apps/web/tests/` (Playwright — runs at 375px + 1440px viewports)
- Test fixtures: `supabase/seed.sql` (minimum: 1 household, 2 users in different households for RLS tests, 1 store, list entries)

### CI/CD

- Workflow: `.github/workflows/ci.yml` (base CI in Phase 0b — will add Supabase integration tests with Phase 1c, Playwright E2E with Phase 1g)
- Vercel config: `apps/web/vercel.json` (monorepo-aware install/build commands)
- Branch protection: `main` requires PR + CI green before merge
- Branch strategy: `main` (production), `feature/*`, `fix/*` — no `develop` branch

### Observability

- Sentry config: `apps/web/sentry.client.config.ts`, `sentry.server.config.ts`, `instrumentation.ts`
- Sentry error boundary: `apps/web/app/global-error.tsx`
- PostHog provider: `apps/web/app/providers.tsx` (client component, `posthog.init()`)
- Event taxonomy: `METRICS.md`

### PWA

- Manifest: `apps/web/public/manifest.json` (app name, icons, theme color, `display: standalone`)
- Apple meta tags: `apps/web/app/layout.tsx` (`apple-mobile-web-app-capable`, `apple-touch-icon`, status bar style)
- Service worker caching (`@serwist/next`) deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable

_This section grows as code is added. `/implement` updates it when introducing new paths._

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
| `/cso`                 | Every PR; infra baseline at Phase 0    | Repo state                | Security audit (OWASP, STRIDE, secrets, CI/CD)                                                                       |
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

| Skill          | When to use                    | What it does                                                                                 |
| -------------- | ------------------------------ | -------------------------------------------------------------------------------------------- |
| `/build`       | After autoplan — "build it"    | Autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Resumable. |
| `/go-live`     | After PR review — "land it"    | Autonomous deploy: merge → deploy → canary → reflect → notify.                               |
| `/spec`        | Standalone or inside /build    | Converts gstack plan to implementation-ready spec + METRICS.md                               |
| `/implement`   | Standalone or inside /build    | Implements tasks with tests, stuck protocol, decisions log                                   |
| `/pre-ship`    | Standalone or inside /build    | Quality gates only (11 gates). Does not ship.                                                |
| `/test-review` | Standalone or inside /pre-ship | Fresh-eyes test quality review (report only)                                                 |
| `/status`      | Start of any session           | One-paragraph orientation briefing (read-only)                                               |
| `/init`        | New project setup              | Guided walkthrough of new-project checklist                                                  |

---

## Shared Conventions

Single source of truth for conventions referenced by multiple skills. Skills point here, not copy.

### Metrics Lifecycle

Metrics flow through the devshop at four points:

1. **`/spec` creates `METRICS.md`** on first run — drafts taxonomy from autoplan output, asks user to confirm. On subsequent runs: proposes new events when features introduce new user actions. New event definitions are always a "stop and ask" item.
2. **`/implement` instruments** — `posthog.capture()` calls for events referenced in the spec's Metrics section. Instrumented alongside code, never after.
3. **`/pre-ship` validates** — cross-references user-facing code against `METRICS.md`. Pauses if a user-facing PR is missing instrumentation.
4. **You confirm new events** — never auto-added without review.

#### Metrics principles (for drafting/updating `METRICS.md`)

1. Every event must answer a question you'd act on. Can't name the decision? Don't track it.
2. Track outcomes, not clicks. Prefer `item_added` over `add_button_clicked`. Exception: funnel drop-off needs start + end events.
3. One event per user intent, not per UI element. Multiple paths to same action = one event with a `method` property.
4. Properties carry context, not event names. Stable names, filterable properties.
5. Error events must include enough to reproduce: `error_type`, `screen`, `user_action_before`.
6. Instrument boundaries, not internals. Entry/exit of flows, not every state. Internals are for logs.
7. Start sparse, add when you have questions. Launch with 5-10 events covering core flows.

#### `METRICS.md` structure

```markdown
# Metrics

## Events

| Event | When it fires | Key properties | Why we care |
| ----- | ------------- | -------------- | ----------- |

## Feature Flags

| Flag | Controls | Default |
| ---- | -------- | ------- |
```

### TASKS.md Format

```markdown
## Task: [name]

**Hat**: FE | BE | Data | PM
**Depends on**: [task names or "none"]
**Blocks**: [task names or "none"]
**Done when**: [concrete, testable criterion — tests pass, endpoint returns X, etc.]
**Risk**: low | medium | high
**Status**: todo | in_progress | done | blocked
```

#### Resume pattern

When a session is interrupted, start a new session with:

```
claude "use a sub-agent to read specs/<name>/tasks.md and recent git log,
then tell me in one paragraph: which tasks are done, which is next,
what context I need to continue"
```

Sub-agent reads the file; main session gets a short summary — no context pollution.

### SPEC.md Quality Checklist

Every spec must have:

- [ ] All user-facing behaviors described (happy path + error states)
- [ ] Data model changes explicit (exact schema diffs or "no changes")
- [ ] API contracts specified (endpoints, inputs, outputs, auth requirements)
- [ ] Out-of-scope items explicitly listed
- [ ] Offline behavior declared for any feature with remote data: (a) online-only with error state, (b) read-only cache, (c) full offline with sync. Default to (a) unless explicitly upgraded.
- [ ] Metrics section referencing events from `METRICS.md`
- [ ] Provenance header linking to gstack plan

### Confidence Calibration

#### Proceed autonomously

- UI components + their tests
- Extending existing API endpoints
- Bug fixes with clear root cause + confirming test
- Styling / design token changes
- Documentation updates
- Adding new Supabase queries (no schema changes)
- Instrumenting metrics for events already defined in METRICS.md

#### Stop and ask (before implementing)

- New database columns/tables (migrations are hard to reverse)
- Auth flow changes
- New third-party API integrations not yet in codebase
- Performance-sensitive code paths
- Security-related logic — stop before writing, get human sign-off; `/cso` still runs after
- Anything requiring deletion of existing tests
- New metric event definitions (add to METRICS.md requires review)

### TODO Protocol

- **Blocker** (can't complete task without human input) → stop, add to `TODOS.md` with `[blocked]` tag, mark task `blocked` in tasks.md, ping user
- **Out-of-scope discovery** (real bug or feature, but not in current spec) → route per backlog guide below, skip, continue
- **Minor issue** (< 5 min to fix) → fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) → add to `TODOS.md` with `[minor]` tag, continue

### Backlog Routing Guide

Two questions decide where deferred work goes:

1. **Who cares?** App user → project row. Dev using the devshop → devshop row.
2. **When?** Fix/do soon → TODO. Build eventually → ROADMAP.

|             | Tactical            | Strategic             |
| ----------- | ------------------- | --------------------- |
| **Project** | `TODOS.md`          | `PRODUCT-ROADMAP.md`  |
| **Devshop** | `.devshop/TODOS.md` | `.devshop/ROADMAP.md` |

TODO items can be scheduled into versions defined in their corresponding ROADMAP (e.g., `[v0.2]`, `[v2]`). Project files never reference devshop files.

### Non-Negotiables

#### Testing

- **No code without tests** — written alongside, never after.
- **No code that breaks existing tests** — full test suite runs before marking done.
- **Testing layers**:
  - Unit tests (`*.test.ts`): mock external dependencies. Pure business logic only — validation, transforms, calculations.
  - Integration tests (`*.integration.test.ts`): must hit a real local database (Docker-in-Docker). Never mock the DB layer for queries, access control, or data integrity. Supabase: `supabase start`. Other: Docker Compose.
  - E2E tests: required for every user-facing flow. Playwright runs at 375px (mobile) and 1440px (desktop). Both must pass.
- **Test commands**: `pnpm turbo run test:unit` (unit only, no DB) vs `pnpm turbo run test` (unit + integration, needs local DB). Use `test:unit` for the fast inner loop; `test` for full verification.
- **Auth boundary tests (RLS)**: every table with RLS policies must have at least one integration test — authenticate as User A, create data, authenticate as User B, verify data is NOT visible. RLS bugs are silent data leaks; mocked tests can never catch them.
- **`seed.sql`**: minimum test fixtures for integration tests. At least 2 users in different households for RLS boundary tests.
- **CI enforcement lands in the same PR as the code it tests** — no gap between "tests exist" and "CI runs them."
- **CI mirrors runtime**: if the app uses a DB at runtime, CI starts it locally. Never skip integration tests because "they work locally." Never hit shared remote environments from CI. Supabase: `supabase start` + `seed.sql` + type drift check + mask `SUPABASE_SERVICE_ROLE_KEY`.
- **Type drift check**: CI regenerates types from schema and fails if committed types have drifted.

#### Testing Lifecycle

| Stage                | What runs                                      | Needs DB?          | Blocking?                       |
| -------------------- | ---------------------------------------------- | ------------------ | ------------------------------- |
| Per-task (local)     | `test:unit`                                    | No                 | Yes — task not done until green |
| Pre-commit hook      | Lint + secrets + devshop-docs reminder         | No                 | Yes — commit blocked            |
| CI fast (every push) | Lint + types + `test:unit` + build             | No                 | Yes — shows red on PR           |
| CI slow (PR to main) | `test` (unit+integration) + E2E + type drift   | Yes (CI starts it) | Yes — merge blocked             |
| `/pre-ship`          | `/test-review` (reads tests) + `/qa` (browser) | App running        | Pauses on findings              |

Unit tests are the fast inner loop (local + CI fast). Integration + E2E are the outer gate (CI slow). No env var needed — the command you run is the mode.

#### Metrics

- **No code without metrics** — every user-facing feature must have events in `METRICS.md`, instrumented in the same PR.

#### Responsive + Theme

- **Responsive from day one** — works (not just renders) from iPhone SE (375px) to large desktop (2560px). Mobile-first. `packages/ui/src/tokens.ts` defines breakpoints as single source of truth; `tailwind.config.js` reads them. No hardcoded pixel widths. Playwright E2E runs at mobile + desktop. Snapshot tests include both variants.
- **Light/dark theme required** — both from launch. `tokens.ts` defines semantic theme tokens. Tailwind maps to CSS custom properties. Theme follows `prefers-color-scheme` with optional toggle. No hardcoded colors — always theme tokens. Snapshots include both themes.

#### PWA

- **PWA-installable** — `manifest.json`, Apple meta tags. "Add to Home Screen" works on iOS/Android. Service worker caching (`@serwist/next`) deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable to avoid stale-data bugs during active development. Placeholder icons at scaffold; replaced with real branding during design system migration.

#### Security + Quality

- **Edge functions always validate auth server-side** — `getUser()` to verify against auth server, even with gateway JWT verification.
- **Pre-commit**: husky + lint-staged → ESLint + Prettier + gitleaks secret scan on every commit, no bypass. Ship `.gitleaks.toml` with known-safe public key patterns to prevent false-positive rot.
- **Secrets in CI**: wired into `ci.yml` in the same PR as the integration — never a follow-up.
- **Third-party binaries**: pinned to specific version + SHA256 checksum. Never "latest." Update version + checksum in same commit.
- **Security-critical files are root-owned** — six files have two layers of protection: (1) deny rules in `.claude/settings.json` block Edit/Write tools, and (2) `chown root:root` + `chmod 644` blocks Bash workarounds. Claude can read them but cannot modify them by any means. To edit: `sudo nano <file>`.
  - `.claude/settings.json` — protects deny list, DCG hook, and permission mode
  - `.devcontainer/devcontainer.json` — protects DinD config, env var loading, container setup
  - `.devcontainer/init-firewall.sh` — protects the network egress allowlist
  - `.devcontainer/Dockerfile` — protects base image, binary installs, system packages
  - `.devcontainer/checksums.sha256` — protects integrity verification for pinned binaries
  - `.devcontainer/.env` — protects secrets and credentials
- **Template repo gets the same protection** — after `sync-to-template.sh` (seed or regular sync), lock the same files in the template repo (minus `.env` which isn't synced). The sync script prints the exact commands. This prevents Claude from modifying synced security files when working directly in the template repo.

#### Code Structure

- **Shared packages export TypeScript source directly** — `"main": "src/index.ts"`. Each consuming app transpiles. Every package has a `src/index.ts` barrel export. No deep path imports across package boundaries.
- **File documentation**: every non-trivial `.ts`/`.tsx` file under `src/` or `app/` has a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has 1-2 sentence JSDoc (enforced by ESLint via `eslint-plugin-jsdoc`). Internal/private: no doc required. Config files (`*.config.*`, `*.d.ts`) are exempt. Headers are checked by `/pre-ship` convention check, not pre-commit — mechanical enforcement produces mechanical documentation.
- **Implementation approach**: default to simple. Boring solution. Tried-and-true over clever. Readable over optimal.
- **ESLint for code quality only** — Prettier owns all formatting.

---

## Structured Reflection Prompt (Step 11)

After each feature ships, run structured reflection and route learnings to committed files (not memory files):

- What went well? What was surprisingly hard?
- New conventions, gotchas, calibration updates → `CLAUDE.md`
- New troubleshooting entries → `.devshop/GUIDE.md` (Troubleshooting section)
- Decision log entries → `.devshop/GUIDE.md` (Decision Log section)
- Devshop friction or ideas → `.devshop/TODOS.md` (tactical) or `.devshop/ROADMAP.md` (strategic)
- Did confidence calibration need adjustment? (New items for "proceed" or "stop and ask" in `CLAUDE.md`)

---

## Starting a New Project

Create a repo from the `abra-kadabra` template on GitHub, open it in the devcontainer,
then run `/devshop:init` for a guided walkthrough with detailed instructions for each step.
The init skill owns the execution detail; this checklist is the compact summary with
checkboxes for resume tracking. Update both when changing the init process.

> **Maintenance note**: This checklist and `.claude/skills/devshop/init/SKILL.md` are
> companions. Update both when changing the init process.

### Steps (all walked by /devshop:init — [HUMAN] items prompt the user)

1. [x] Check binary versions in `devcontainer.json` — upgrade if newer available
2. [x] Seed `PRODUCT-ROADMAP.md` and `BUILD-LOG.md` (from `.devshop/templates/`)
3. [x] **[HUMAN]** Create accounts: Vercel (+ install GitHub App — do NOT import repo yet), Sentry, PostHog, optionally Apple Developer
4. [x] **[HUMAN]** Fill `.devcontainer/.env` with credentials (init skill shows full list + where to find each)
5. [x] **[HUMAN]** Add GitHub Secrets (CI env vars) + variable `PRODUCTION_URL` (init skill has full list)
6. [x] **[HUMAN]** Add project-specific firewall domains to `init-firewall.sh`
7. [x] **[HUMAN]** Rebuild devcontainer (Cmd/Ctrl+Shift+P → "Rebuild Container")
8. [x] Clean template placeholders (`apps/`, `packages/`, `supabase/`, `DESIGN.md`, `METRICS.md`) + replace `README.md` with project README
9. [x] Disable turbo telemetry: `pnpm turbo telemetry disable`
10. [x] Install gstack: `git clone ... .claude/skills/gstack && ./setup`
11. [x] Scaffold `packages/core` (Supabase client factory, generated types, vitest)
12. [x] Scaffold `packages/ui` (tokens.ts, proof-of-concept component — no tailwind.config.js, Tailwind v4 uses CSS `@theme`)
13. [x] Scaffold `apps/web` (Next.js + Sentry + PostHog + PWA + security headers + vercel.json + import repo on Vercel)
14. [x] Add Vercel CLI + link project + pipe env vars from `.env` to Vercel
15. [x] Install Playwright + create config (375px mobile + 1440px desktop viewports)
16. [x] Supabase init + link: `supabase init` (if needed) + `supabase link --project-ref <ref>` (if using Supabase)
17. [x] Create `METRICS.md` with empty event taxonomy structure
18. [x] Run `/setup-deploy` to configure deploy settings
19. [x] Create `CLAUDE.project.md` with project-specific Claude guidance (init-devshop.sh generates `CLAUDE.md` by combining devshop + project parts)
20. [x] Enable doc enforcement hooks: wire `check-devshop-docs.sh` into pre-commit, add `eslint-plugin-jsdoc`
21. [x] Update `.gitleaks.toml` allowlist with project-specific public key patterns
22. [x] **[HUMAN]** Lock security-critical files: `sudo chown root:root && sudo chmod 644` on settings.json, devcontainer.json, init-firewall.sh, Dockerfile, checksums.sha256, .env
23. [x] Create `keepalive.yml` GitHub Action (prevents Supabase free tier pause)
24. [x] **[HUMAN]** Set up service quota alerts: Sentry, PostHog, Vercel
25. [ ] **[HUMAN]** Set up abra-kadabra bind mount: clone/place `abra-kadabra` next to the project on the host. The `.devcontainer/devcontainer.json` mount handles the rest.
26. [ ] **[HUMAN]** Enable branch protection on `main` (after first CI run produces a green `ci` check)
27. [ ] Run `/cso` for baseline infrastructure security audit (last — audits the complete setup)

---

## Devshop Separation Architecture

The devshop (abra-kadabra) and the project repo (e.g., lalista) are separate git repositories. The project repo is clean and publishable — it contains only project code, build config, and CI. All devshop infrastructure gets **injected at container start** via symlinks.

### Two repos, one workspace

```
Host filesystem:
├── abra-kadabra/          ← devshop repo (opened in VS Code)
│   ├── .devshop/          ← scripts, docs, templates
│   ├── .claude/           ← skills, commands, settings
│   ├── .devcontainer/     ← init-devshop.sh (injection script)
│   ├── CLAUDE.md          ← devshop conventions for Claude
│   └── (template configs) ← .editorconfig, turbo.json, etc.
│
└── lalista/               ← project repo (mounted at /workspace)
    ├── .devcontainer/     ← Dockerfile, firewall, thin forwarder
    ├── CLAUDE.project.md  ← project-specific Claude context (tracked)
    ├── .claude-memory/    ← Claude memory (tracked)
    ├── apps/, packages/   ← project code
    └── (build configs)    ← turbo.json, eslint, etc. (tracked)

Inside container:
/workspace/                ← lalista (bind mount)
├── .devshop/              ← symlink → /devshop/.devshop/
├── .claude/               ← created by init-devshop.sh (skills, settings)
├── CLAUDE.md              ← generated: devshop CLAUDE.md + CLAUDE.project.md
├── BUILD-LOG.md           ← created if missing
├── .dcg.toml              ← symlink → /devshop/.dcg.toml
└── (everything else)      ← project files, tracked normally

/devshop/                  ← abra-kadabra (bind mount)
```

### What lives where

| Content | Repo | Tracked? | How it gets to /workspace |
|---------|------|----------|--------------------------|
| `.devshop/` (scripts, docs, templates) | abra-kadabra | yes | symlink by init-devshop.sh |
| `.claude/skills/`, `.claude/commands/` | abra-kadabra | yes | symlink by init-devshop.sh |
| `.claude/settings.json` | abra-kadabra | yes | copied by init-devshop.sh (root-owned) |
| `CLAUDE.md` (combined) | neither | no | generated by init-devshop.sh |
| `CLAUDE.project.md` | project | yes | already there |
| `.claude-memory/` | project | yes | already there |
| `BUILD-LOG.md` | project | no (gitignored) | created by init-devshop.sh if missing |
| `.devcontainer/` | project | yes | already there |
| `.husky/`, `.github/`, `turbo.json`, etc. | project | yes | already there |
| `apps/`, `packages/`, `supabase/` | project | yes | already there |
| Sessions, API keys, credentials | neither | no | `~/.claude/` volume (persists across rebuilds) |

### How init-devshop.sh works

Runs as root via sudo on every container start (`postStartCommand`). The project's `.devcontainer/init-devshop.sh` is a thin forwarder:

```bash
[ -f /devshop/.devcontainer/init-devshop.sh ] && exec bash /devshop/.devcontainer/init-devshop.sh
```

The real script in abra-kadabra:
1. Sets root/node passwords from `.devcontainer/.env`
2. Symlinks `.devshop/` → `/devshop/.devshop/`
3. Symlinks `.dcg.toml` → `/devshop/.dcg.toml`
4. Creates `.claude/skills/` with symlinks to devshop + gstack skill directories
5. Copies skill symlinks (ak-*, gstack tools) preserving relative targets
6. Symlinks `.claude/commands/` → `/devshop/.claude/commands/`
7. Symlinks `.claude/settings.json`
8. Generates `CLAUDE.md` by concatenating `abra-kadabra/CLAUDE.md` + `CLAUDE.project.md`
9. Creates `BUILD-LOG.md` with default content if missing
10. Locks security-critical files (root-owned, 644)

### Doing project work

All project work happens in the project repo. Branches, PRs, commits — all on the project's GitHub.

- `git status` only shows project files (devshop files are gitignored)
- Commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- PRs go to the project repo — clean diffs, no devshop noise
- Edit `CLAUDE.project.md` for project-specific Claude guidance (tracked)
- Edit `BUILD-LOG.md`, `TODOS.md`, `METRICS.md` as normal project docs

### Doing devshop work

Devshop changes go to the abra-kadabra repo. Since `.devshop/` is a symlink to `/devshop/.devshop/`, edits to devshop files are automatically in the abra-kadabra working tree.

```bash
cd /devshop                    # abra-kadabra repo
git status                     # see devshop changes
git add -A && git commit -m "devshop: ..."
# Push from host (container PAT may lack scope)
```

- Devshop commits use the `devshop:` prefix
- Changes take effect immediately (symlinks resolve live)
- All injected files (including `.claude/settings.json`) are symlinks — edits in `/devshop/` take effect immediately. The lock step (`chown root:root`) follows symlinks, so the target files in abra-kadabra are also locked.

### Propagating build tooling updates

Build tooling files (`turbo.json`, `eslint.config.mjs`, `.husky/`, etc.) are tracked in both repos — abra-kadabra has the template version, the project has its copy. They can diverge.

To pull template updates into a project:
```bash
.devshop/scripts/sync-from-template.sh    # diffs + applies; you review
```

To push project improvements back to the template:
```bash
.devshop/scripts/sync-to-template.sh      # copies to abra-kadabra; you review + push
```

`manifest.txt` defines which files are injected vs templated. See `.devshop/manifest.txt`.

### Public contributors (without devshop)

Contributors who clone the project without abra-kadabra get a working repo:
- `pnpm install && pnpm turbo run dev` works
- `.devcontainer/` works (init-devshop.sh forwarder is a no-op without `/devshop`)
- Rename `CLAUDE.project.md` → `CLAUDE.md` for Claude Code guidance
- No devshop skills, hooks, or quality gates — just standard development

---

## Env Var Naming Convention

Each framework requires a specific prefix for client-accessible vars. GitHub Secrets use the base name; each surface adds its own prefix.

| Secret (base name)        | Next.js (Vercel)                |
| ------------------------- | ------------------------------- |
| `SUPABASE_URL`            | `NEXT_PUBLIC_SUPABASE_URL`      |
| `SUPABASE_ANON_KEY`       | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| `SENTRY_DSN`              | `NEXT_PUBLIC_SENTRY_DSN`        |
| `NEXT_PUBLIC_POSTHOG_KEY` | `NEXT_PUBLIC_POSTHOG_KEY`       |

`packages/core` does NOT read env vars directly — exports `createClient(config: CoreConfig)`. Each app reads its prefixed vars and passes them in.

---

## Stack

| Layer             | Tool                               | Why                                                         |
| ----------------- | ---------------------------------- | ----------------------------------------------------------- |
| Web app           | Next.js 15 (App Router)            | Best React framework, zero-config Vercel                    |
| Monorepo          | Turborepo + pnpm                   | Fast incremental builds, workspace support                  |
| Shared logic      | `packages/core`                    | Supabase client, types, API wrappers (framework-agnostic)   |
| Shared UI         | `packages/ui` + tokens.ts          | Tailwind (web) + tokens (platform-agnostic source of truth) |
| Backend           | Supabase                           | Schema + functions already solid                            |
| Auth              | Supabase Auth + Sign in with Apple | Already implemented in Swift; port to web                   |
| Web hosting       | Vercel (free tier)                 | Zero-config Next.js, preview URLs on PRs                    |
| Errors            | Sentry (free: 5k errors/mo)        | Crash reports before users tell you                         |
| Analytics + flags | PostHog (free: 1M events/mo)       | Usage analytics + feature flags                             |
| Web unit tests    | Vitest                             | Fast, TS-native                                             |
| Web E2E           | Playwright                         | Best-in-class, GitHub Actions ready                         |
| CI/CD             | GitHub Actions (free tier)         | Tests + builds + deploys                                    |
| Secrets           | GitHub Secrets + Vercel env vars   | Managed; no .env in CI                                      |
| DB migrations     | Supabase CLI                       | Keep existing workflow                                      |
| Lint/format       | ESLint + Prettier                  | Pre-commit via husky + lint-staged                          |
| Safety            | DCG (Destructive Command Guard)    | PreToolUse hook blocks 49+ destructive patterns             |
| Secret scanning   | gitleaks                           | Pre-commit + CI; `.gitleaks.toml` prevents false positives  |

---

## Devshop Documentation Structure

All devshop docs live in `.devshop/`. Three types: reference docs (living), backlogs (growing), and build blueprints (historical).

### Reference docs (living — update together in the same commit)

- `.devshop/README.md` — bird's eye view (~60-80 lines). Read for orientation.
- `.devshop/GUIDE.md` — full operational reference (this file). Read when implementing or shipping.

Pre-commit nudge: if either file is staged, prints a reminder to verify both are in sync. `/pre-ship` enforces.

### Backlogs (living — grow independently)

- `.devshop/TODOS.md` — tactical (friction, bugs, small fixes). Items can have version tags (e.g., `[v0.2]`).
- `.devshop/ROADMAP.md` — strategic (capabilities, major improvements). Defines version milestones.

See "Backlog Routing Guide" above for routing rules. Project backlogs (`TODOS.md`, `PRODUCT-ROADMAP.md`) are separate — see that section too.

### Build blueprints (one-time — historical after execution)

- `.devshop/notes/bootstrap/v0-web.md` — web devshop construction.
- `.devshop/notes/bootstrap/v1-native.md` — native/mobile capability (deferred).

Blueprints are not synced to projects — they live in the template repo as construction history for the devshop maintainer.

### When to split

Create a details file only when a signal fires:

1. **Size signal**: `GUIDE.md` exceeds ~500 lines.
2. **Context signal**: Claude regularly reads GUIDE.md but only uses ~30%.

Split: GUIDE.md keeps workflow/skill map/checklists. Details file gets full path map, troubleshooting, decision log.

---

## Local Development

### With Docker-in-Docker (16GB+ RAM)

Full local stack: `supabase start` provides local Postgres, Auth, Realtime, etc. Run integration tests locally.

```bash
pnpm turbo run dev          # start Next.js dev server
supabase start              # local Supabase (needs DinD)
pnpm turbo run test         # full suite (unit + integration)
```

### Without Docker-in-Docker (< 16GB RAM or DinD unavailable)

First-class workflow, not a degraded experience. Unit tests cover business logic; integration tests run in CI.

```bash
pnpm turbo run dev          # start Next.js dev server (uses remote Supabase)
pnpm turbo run test:unit    # fast inner loop — no DB needed
```

Integration tests (`*.integration.test.ts`) run in CI's slow job against a real Supabase instance. Push a PR to run them.

---

## Service Quotas

Check monthly or when approaching a launch. `/init` fills in project-specific links.

| Service        | Free Tier Limit                                  | Dashboard                          |
| -------------- | ------------------------------------------------ | ---------------------------------- |
| Supabase       | 500MB DB, 50k auth MAU, 500k edge fn invocations | `supabase.com/dashboard`           |
| Sentry         | 5k errors/month                                  | `sentry.io` → Settings → Usage     |
| PostHog        | 1M events/month                                  | `posthog.com` → Settings → Billing |
| GitHub Actions | 2000 min/month                                   | `github.com/<repo>/actions/usage`  |
| Vercel         | 100GB bandwidth, 100k serverless invocations     | `vercel.com` → Settings → Usage    |

### Expected CI Minutes

Rough estimate for 10 PRs/month:

- 20 fast jobs × ~4 min = 80 min
- 10 slow jobs × ~15 min = 150 min
- 10 mirror runs × ~3 min = 30 min
- **Total: ~260 min/month** (13% of 2000 min free tier)

Track if it creeps up as the test suite grows. The `/retro` skill reports on this.

---

## Known Footguns

- **Firewall IP rotation**: CDN domains like `fonts.gstatic.com` rotate IPs. Firewall resolves at container start. If a build fails on a network error for an allowed domain hours later, restart the container to re-resolve.

---

## When Things Go Wrong

### Vercel rollback

```bash
vercel rollback    # reverts to previous deployment
```

Find the deployment ID in the rollback checkpoint (PR comment from `/go-live`).

### Migration rollback

Every migration file ends with a `-- ROLLBACK` comment block containing the SQL to reverse it. Copy-paste and run via `psql` or Supabase SQL editor. Test on a non-production environment first if possible.

### Canary failure

If `/canary` detects issues after deploy, immediately run `vercel rollback`. Then investigate root cause on the branch — do not push forward.

### Data recovery

Free-tier Supabase has no point-in-time recovery. Pre-migration `pg_dump` will be automated in Phase 1c — runs before applying new migrations, stored as GitHub Actions artifact. For weekly backups beyond deploys, see `.devshop/ROADMAP.md` v1. Always test schema changes against `supabase start` locally before deploying.

---

## Troubleshooting

_Grows as issues are encountered. Add entries with date, symptom, cause, fix._

---

## Decision Log

_Short entries: "chose X over Y because Z, date" — extracted from reviews and retros._
