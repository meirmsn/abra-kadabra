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

### Step 4: `/ak-build` (devshop skill) — autonomous pipeline

One command after autoplan. Chains everything through PR creation, CI verification, and notification. Resumable if the session is interrupted.

**Phase 1: `/ak-spec`** — converts gstack plan into implementation-ready spec. May stop for METRICS.md confirmation (the one interactive moment before PR).

**Phase 2: `/ak-implement`** — reads spec, decomposes into tasks, implements with tests. Stuck protocol: try fix → `/investigate` → ask user. Logs judgment calls in `specs/<name>/tasks.md` § Decisions.

**Phase 3: `/ak-pre-ship`** — quality gates only (no shipping):

1. Devshop docs check
2. Metrics check
3. Responsive + theme check (UI PRs)
4. `/simplify` → test:unit checkpoint
5. `/ak-test-review`
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

- Release notes (from `/ship`) + audit trail comment (from `/ak-build`)
- CI green + Vercel preview URL
- You merge or request changes

### Step 6: `/ak-go-live` (devshop skill) — autonomous deploy

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

_This section grows as code is added. `/ak-implement` updates it when introducing new paths._

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

| Skill             | When to use                       | What it does                                                                                 |
| ----------------- | --------------------------------- | -------------------------------------------------------------------------------------------- |
| `/ak-build`       | After autoplan — "build it"       | Autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Resumable. |
| `/ak-go-live`     | After PR review — "land it"       | Autonomous deploy: merge → deploy → canary → reflect → notify.                               |
| `/ak-spec`        | Standalone or inside /ak-build    | Converts gstack plan to implementation-ready spec + METRICS.md                               |
| `/ak-implement`   | Standalone or inside /ak-build    | Implements tasks with tests, stuck protocol, decisions log                                   |
| `/ak-pre-ship`    | Standalone or inside /ak-build    | Quality gates only (11 gates). Does not ship.                                                |
| `/ak-test-review` | Standalone or inside /ak-pre-ship | Fresh-eyes test quality review (report only)                                                 |
| `/ak-status`      | Start of any session              | One-paragraph orientation briefing (read-only)                                               |
| `/ak-init`        | New project setup                 | Guided walkthrough of new-project checklist                                                  |

> **Skill autocomplete**: The `name` field in SKILL.md frontmatter drives `/` autocomplete,
> not the directory or symlink name. When adding or renaming a skill, set `name: ak-<skill>`
> in the frontmatter to match the desired slash command.

---

## Shared Conventions

Single source of truth for conventions referenced by multiple skills. Skills point here, not copy.

### Metrics Lifecycle

Metrics flow through the devshop at four points:

1. **`/ak-spec` creates `METRICS.md`** on first run — drafts taxonomy from autoplan output, asks user to confirm. On subsequent runs: proposes new events when features introduce new user actions. New event definitions are always a "stop and ask" item.
2. **`/ak-implement` instruments** — `posthog.capture()` calls for events referenced in the spec's Metrics section. Instrumented alongside code, never after.
3. **`/ak-pre-ship` validates** — cross-references user-facing code against `METRICS.md`. Pauses if a user-facing PR is missing instrumentation.
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

Owned by `/ak-implement` — see `.claude/skills/devshop/implement/SKILL.md` for the task format template and resume pattern.

### SPEC.md Quality Checklist

Owned by `/ak-spec` — see `.claude/skills/devshop/spec/SKILL.md § Quality checklist` for the full checklist.

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

**When a roadmap item ships**: remove it from the roadmap entirely and log the completion in `BUILD-LOG.md`. Roadmaps only show what's ahead — `BUILD-LOG.md` is the record of what was done.

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
- **`seed.sql`**: minimum test fixtures for integration tests. Must include at least 2 users with different access levels (e.g., different households or roles) for RLS boundary testing — User A's data must be invisible to User B. Include representative data for each table with RLS policies. Loaded by `supabase start` automatically and by CI before running integration tests.
- **CI enforcement lands in the same PR as the code it tests** — no gap between "tests exist" and "CI runs them."
- **CI mirrors runtime**: if the app uses a DB at runtime, CI starts it locally. Never skip integration tests because "they work locally." Never hit shared remote environments from CI. Supabase: `supabase start` + `seed.sql` + type drift check + mask `SUPABASE_SERVICE_ROLE_KEY`.
- **Type drift check**: CI regenerates types from schema and fails if committed types have drifted.

#### Testing Lifecycle

| Stage                | What runs                                           | Needs DB?          | Blocking?                             |
| -------------------- | --------------------------------------------------- | ------------------ | ------------------------------------- |
| Per-task (local)     | `test:unit`                                         | No                 | Yes — task not done until green       |
| Pre-commit (husky)   | lint-staged + typecheck + gitleaks + devshop guards | No                 | Yes — commit blocked                  |
| Pre-tool (Claude)    | DCG only (shell hooks can't block Bash calls)       | No                 | Yes — DCG blocks destructive commands |
| Post-commit (Claude) | dirty-tree + cross-repo reminder                    | No                 | No — advisory context                 |
| CI fast (every push) | Lint + types + `test:unit` + build                  | No                 | Yes — shows red on PR                 |
| CI slow (PR to main) | `test` (unit+integration) + E2E + type drift        | Yes (CI starts it) | Yes — merge blocked                   |
| `/ak-pre-ship`       | `/ak-test-review` (reads tests) + `/qa` (browser)   | App running        | Pauses on findings                    |

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
- **Pre-commit (husky)**: lint-staged (ESLint + Prettier) + typecheck + gitleaks secret scan + devshop guards (via `.hooks/pre-commit`, gitignored, generated by `init-devshop.sh`). Guards include clean-tree check and commit guard (4 checks: mixed commit, docs drift — reviews ALL docs including ones that don't yet mention the change, doc consistency, cross-repo awareness). Bypass with `git -c devshop.<key>="<reason>"` — auditable in git log. Ship `.gitleaks.toml` with known-safe public key patterns to prevent false-positive rot.
- **Pre-tool (Claude)**: DCG only. Shell-script PreToolUse hooks cannot block Bash tool calls (anthropics/claude-code#26923). DCG works because it's a compiled binary with special integration.
- **Post-commit (Claude hooks)**: `check-dirty-after-commit.sh` checks both current repo and companion repo for uncommitted changes. Advisory — injects context, doesn't block.
- **Secrets in CI**: wired into `ci.yml` in the same PR as the integration — never a follow-up.
- **Third-party binaries**: pinned to specific version + SHA256 checksum. Never "latest." Update version + checksum in same commit.
- **Security-critical files are root-owned** — two layers of protection: (1) deny rules in `.claude/settings.json` block Edit/Write tools, and (2) `chown root:root` + `chmod 644` blocks Bash workarounds. Claude can read them but cannot modify them by any means. To edit: `sudo nano <file>`. See `init-devshop.sh` lock section for the full list and per-file rationale.
- **Devshop repo gets the same protection** — `init-devshop.sh` locks both symlinked files (settings.json, .dcg.toml — via `chown` following symlinks) and devshop `.devcontainer/` files directly. Deny rules in settings.json mirror workspace-relative patterns with explicit `/devshop/` absolute paths. Guard scripts (`.devshop/scripts/*`) are also denied at both paths.
- **Guard script deny rules are easy to toggle** — when the user wants Claude to edit guard scripts, uncomment the four `.devshop/scripts/*` deny lines in settings.json.
- **`.claude/` allow is broad, settings.json is denied** — `Edit(.claude/**)` allows Claude to edit skills, commands, and memory through the symlink path. `settings.json` is safe: the explicit `Edit(**/.claude/settings.json)` deny takes priority.
- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic (displayed but not enforced by the kernel). Layer 2 only provides real protection on native Linux or Docker named volumes. See ROADMAP.md § v+ for hardening options.
- **Known gap: Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either. DCG custom block rules were attempted but cause false positives on git commands (git add, git commit mention the filenames). See ROADMAP.md § v+ for planned fix.

#### Claude Code Hooks

Hooks in `.claude/settings.json` guard the development workflow:

| Hook                  | Event                    | Trigger                        | What it does                                                                                                                      |
| --------------------- | ------------------------ | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| DCG                   | PreToolUse (all Bash)    | Every Bash command             | Destructive Command Guard — blocks 49+ dangerous patterns (rm -rf, git reset --hard, DROP TABLE, etc.)                            |
| check-memory-created  | PreToolUse (Write\|Edit) | Write/Edit to memory paths     | Blocks memory file writes — forces Claude to ask user before creating memories                                                    |
| release.sh reminder   | PostToolUse (git commit) | `*git*commit*` in devshop repo | Reminds to run `release.sh` for version bump + changelog (no-op in project repos)                                                 |
| dirty tree check      | PostToolUse (git commit) | `*git*commit*` commands        | If tree still dirty after commit, tells Claude to address remaining files                                                         |
| PR description update | PostToolUse (git push)   | `*git push*` commands          | Two-step: (1) Claude assesses title/description vs commits — text only, no edits. (2) Next response: runs `gh pr edit` if needed. |
| session-start.sh      | SessionStart             | New session or `/clear`        | Context for Claude (README, BUILD-LOG, branch) + visible briefing for user (state, workflow, next step)                           |

#### Commit Flow

```
1. PreToolUse: dcg  (settings.json hook, all Bash)
   └─ Blocks destructive commands (not relevant for git commit, passes through)

2. .husky/pre-commit  (git hook, runs 4 steps sequentially)
   ├─ 2a. pnpm exec lint-staged        → ESLint + Prettier on staged files
   ├─ 2b. pnpm turbo run typecheck     → TypeScript check all packages
   ├─ 2c. gitleaks protect --staged    → Secret scan
   └─ 2d. .hooks/pre-commit            → devshop guards (generated by init-devshop.sh)
          ├─ check-claude-md-freshness.sh: CLAUDE.md matches sources → auto-fix
          ├─ check-clean-tree.sh: untracked/unstaged files → block (deterministic)
          └─ devshop-commit-guard.sh (4 checks):
             ├─ Mixed commit: devshop + project files staged together → block (deterministic)
             ├─ Docs drift: tooling changed → reviews ALL docs for needed updates (semantic, adversarial)
             ├─ Doc consistency: reference doc changed → requires review notes (semantic, adversarial)
             └─ Cross-repo: other repo dirty → block (deterministic, adversarial on bypass)

3. Git creates the commit (if pre-commit passed)

4. PostToolUse hooks (settings.json):
   ├─ release.sh reminder (devshop repo only)
   └─ check-dirty-after-commit.sh: remaining dirty files in either repo

5. PostToolUse: check-dirty-after-commit.sh  (settings.json hook, if: *git*commit*)
   └─ If working tree still dirty: tells Claude to address remaining files
   └─ Claude stages + commits, stashes, or gitignores — loop until clean
```

Step 1 is a Claude Code hook (runs before the tool executes). Step 2 is the git pre-commit hook (runs during commit). Steps 4-5 are Claude Code hooks (run after). Steps 2a-2d are all blocking (fail = commit aborted).

**Devshop commit convention**: commits that change devshop-layer files use the `devshop:` prefix (e.g., `devshop: add CI expansion docs`). Project commits use conventional commits (e.g., `feat(auth): add sign-in screen`). The commit guard warns if both types of files are staged together — separate them into distinct commits.

**On push**: a PostToolUse prompt hook checks if there's an open PR for the branch. If the PR description is missing, outdated, or doesn't reflect the current commits, it updates the description automatically. Skips trivial pushes (typo fixes, formatting).

#### Code Structure

- **Shared packages export TypeScript source directly** — `"main": "src/index.ts"`. Each consuming app transpiles. Every package has a `src/index.ts` barrel export. No deep path imports across package boundaries.
- **File documentation**: every non-trivial `.ts`/`.tsx` file under `src/` or `app/` has a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has 1-2 sentence JSDoc (enforced by ESLint via `eslint-plugin-jsdoc`). Internal/private: no doc required. Config files (`*.config.*`, `*.d.ts`) are exempt. Headers are checked by `/ak-pre-ship` convention check, not pre-commit — mechanical enforcement produces mechanical documentation.
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

Create a repo, add a devcontainer that mounts `../abra-kadabra` at `/devshop`, open it,
then run `/ak-init` for a guided walkthrough with detailed instructions for each step.
The init skill owns the execution detail; this checklist is the compact summary with
checkboxes for resume tracking. Update both when changing the init process.

> **Maintenance note**: This checklist and `.claude/skills/devshop/init/SKILL.md` are
> companions. Update both when changing the init process.

### Steps (all walked by /ak-init — [HUMAN] items prompt the user)

1. [x] Check binary versions in `devcontainer.json` — upgrade if newer available
2. [x] Seed `PRODUCT-ROADMAP.md` and `BUILD-LOG.md` (from `.devshop/templates/`, copied by init)
3. [x] **[HUMAN]** Create accounts: Vercel (+ install GitHub App — do NOT import repo yet), Sentry, PostHog, optionally Apple Developer
4. [x] **[HUMAN]** Fill `.devcontainer/.env` with credentials (init skill shows full list + where to find each)
5. [x] **[HUMAN]** Add GitHub Secrets (CI env vars) + variable `PRODUCTION_URL` (init skill has full list)
6. [x] **[HUMAN]** Add project-specific firewall domains to `init-firewall.sh`
7. [x] **[HUMAN]** Rebuild devcontainer (Cmd/Ctrl+Shift+P → "Rebuild Container")
8. [x] Clean scaffolding placeholders (`apps/`, `packages/`, `supabase/`, `DESIGN.md`, `METRICS.md`) + replace `README.md` with project README
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
20. [x] Enable doc enforcement hooks: `devshop-commit-guard.sh` as Claude PreToolUse hook, add `eslint-plugin-jsdoc`
21. [x] Update `.gitleaks.toml` allowlist with project-specific public key patterns
22. [x] **[HUMAN]** Lock security-critical files — handled automatically by `init-devshop.sh` on container start (see lock section for full list)
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
│   ├── .devshop/          ← scripts, docs, file templates
│   ├── .claude/           ← skills, commands, settings
│   ├── .devcontainer/     ← init-devshop.sh (injection script)
│   ├── CLAUDE.md          ← devshop conventions for Claude
│   └── (shared configs)   ← .editorconfig, turbo.json, etc.
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

**Scope expansion:** `additionalDirectories: ["/devshop"]` in `.claude/settings.json` tells Claude Code to treat `/devshop/` as part of the project. This lets `acceptEdits` mode auto-approve Read/Edit on devshop files without per-path allow rules. The Bash allow list also includes common read-only utilities (`cat`, `find`, `head`, `tail`, `wc`, `echo`, `git show`) so skills and hook scripts can use them without prompts — Claude itself should still prefer dedicated tools (Read, Grep, Glob) per its system instructions.

### What lives where

| Content                                     | Repo         | Tracked?        | How it gets to /workspace                      |
| ------------------------------------------- | ------------ | --------------- | ---------------------------------------------- |
| `.devshop/` (scripts, docs, file templates) | abra-kadabra | yes             | symlink by init-devshop.sh                     |
| `.claude/skills/`, `.claude/commands/`      | abra-kadabra | yes             | symlink by init-devshop.sh                     |
| `.claude/settings.json`                     | abra-kadabra | yes             | symlinked by init-devshop.sh                   |
| `CLAUDE.md` (combined)                      | neither      | no              | generated by init-devshop.sh                   |
| `CLAUDE.project.md`                         | project      | yes             | already there                                  |
| `.claude-memory/`                           | project      | yes             | already there                                  |
| `BUILD-LOG.md`                              | project      | no (gitignored) | created by init-devshop.sh if missing          |
| `.devcontainer/`                            | project      | yes             | already there                                  |
| `.husky/`, `.github/`, `turbo.json`, etc.   | project      | yes             | already there                                  |
| `apps/`, `packages/`, `supabase/`           | project      | yes             | already there                                  |
| Sessions, API keys, credentials             | neither      | no              | `~/.claude/` volume (persists across rebuilds) |

### How init-devshop.sh works

Runs as root via sudo on every container start (`postStartCommand`). The project's `.devcontainer/init-devshop.sh` is a thin forwarder that delegates to `/devshop/.devcontainer/init-devshop.sh` — the **single source of truth** for what gets symlinked, generated, and locked. Read the script directly for the full list.

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
git add -A && git commit -m "chore: ..."
# Push from host (container PAT may lack scope)
```

- Devshop commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- All injected files (including `.claude/settings.json`) are symlinks — edits in `/devshop/` take effect immediately. The lock step (`chown root:root`) follows symlinks, so the target files in abra-kadabra are also locked.

### When devshop changes take effect

| What you changed                                                            | When it takes effect                                                                                | Why                                                                           |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Skills, scripts, docs (`.devshop/`, `.claude/skills/`, `.claude/commands/`) | Immediately                                                                                         | Symlinks resolve live                                                         |
| `CLAUDE.md` (root, in abra-kadabra)                                         | Next project commit (auto-reassembled by pre-commit hook), or `sudo /usr/local/bin/init-devshop.sh` | Assembled from `/devshop/CLAUDE.md` + `CLAUDE.project.md` (copy, not symlink) |
| Shared build tooling (`.husky/`, `turbo.json`, CI, etc.)                    | Manual: run `sync-from-devshop.sh`                                                                  | Project owns its copy — can diverge from devshop                              |

### Propagating build tooling updates

Build tooling files (`turbo.json`, `eslint.config.mjs`, `.husky/`, etc.) are tracked in both repos — abra-kadabra has the base version, the project has its copy. They can diverge.

To pull devshop updates into a project:

```bash
.devshop/scripts/sync-from-devshop.sh    # diffs + applies; you review
```

To push project improvements back to the devshop:

```bash
.devshop/scripts/sync-to-devshop.sh      # copies to abra-kadabra; you review + push
```

`manifest.txt` defines which files the sync scripts operate on. See `.devshop/manifest.txt`.

### Public contributors (without devshop)

Contributors who clone the project without abra-kadabra get a working repo:

- `pnpm install && pnpm turbo run dev` works
- `.devcontainer/` works (init-devshop.sh forwarder is a no-op without `/devshop`)
- Rename `CLAUDE.project.md` → `CLAUDE.md` for Claude Code guidance
- No devshop skills, hooks, or quality gates — just standard development

### Known gotchas (separation)

- **macOS bind mount no-execute**: Scripts on the `/devshop/` mount can't execute via shebang (`/usr/bin/env: bad interpreter: Permission denied`). The thin forwarder must use `exec bash /devshop/...` not `exec /devshop/...`.
- **Thin forwarder mechanism**: The Dockerfile COPYs `init-devshop.sh` at build time → baked at `/usr/local/bin/init-devshop.sh`. A NOPASSWD sudoers rule only covers this exact path. The project's `.devcontainer/init-devshop.sh` is a thin forwarder (`[ -f /devshop/... ] && exec bash /devshop/...`) that delegates to abra-kadabra. This way the Dockerfile and sudoers rule don't change — only the forwarder content matters, and it gets re-baked on container rebuild.
- **Container PAT scope**: The GitHub token in `.devcontainer/.env` is scoped to the project repo. Cannot push to abra-kadabra from the container. Push devshop changes from the host machine.
- **`.devcontainer/` files are root-owned**: Cannot edit inside the container without sudo. Edit from the host filesystem or use `sudo nano <file>`.
- **`[ -e ]` not `[ -f ]` for symlinks**: `[ -f ]` tests for regular files and may return false for symlinks. Use `[ -e ]` (exists) for symlinked paths.
- **gitignore patterns for symlinks**: Use `.devshop` and `.claude` (no trailing `/`). A trailing slash only matches directories, but symlinks to directories may not match.
- **Migration commits (one-time)**: `git rm --cached` combined with lint-staged's stash/restore can delete files from disk if they're gitignored. Use `--no-verify` for one-time migration commits that bulk-remove tracked files.
- **Heredoc terminal indentation**: Pasting heredocs in the terminal may add leading whitespace. Use `sed -i 's/^  //' file` to strip, or write from a script.

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

### Commit Flow — Full Hook Chain

When Claude runs `git commit`, three layers fire in sequence:

**1. Claude PreToolUse (before git runs)** — configured in `.claude/settings.json`

| Hook  | What                                 | Blocking?                                                    |
| ----- | ------------------------------------ | ------------------------------------------------------------ |
| `dcg` | Destructive command guard (all Bash) | Yes (compiled binary, only mechanism that blocks Bash calls) |

Note: PreToolUse hooks from shell scripts cannot block Bash tool calls (anthropics/claude-code#26923). DCG works because it's a compiled binary with special integration.

**2. Husky pre-commit (during git commit)** — configured in `.husky/pre-commit`

| Hook                        | What                              | Blocking?                   |
| --------------------------- | --------------------------------- | --------------------------- |
| `pnpm exec lint-staged`     | ESLint + Prettier on staged files | Yes — both repos            |
| `pnpm turbo run typecheck`  | TypeScript type checking          | Yes — both repos            |
| `gitleaks protect --staged` | Secret scanning                   | Yes — both repos            |
| `.hooks/pre-commit`         | Devshop guards (see below)        | Yes — no-op without devshop |

`.hooks/pre-commit` is gitignored, generated by `init-devshop.sh` for both repos. It calls:

**Project repo** (`.hooks/pre-commit`):

Guards are split into **deterministic** (auto-pass when condition is met) and **semantic** (always require a review explanation). All bypass reasons are verified by `adversarial-doc-review.sh` — a haiku agent that actively tries to reject the reason.

| Guard                             | Type          | What                                                                                  | Bypass                                                    |
| --------------------------------- | ------------- | ------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `check-claude-md-freshness.sh`    | Auto-fix      | Reassembles CLAUDE.md if sources diverged                                             | N/A — never blocks                                        |
| `check-clean-tree.sh`             | Deterministic | Blocks if untracked/unstaged files exist                                              | `dirtyTreeReason` — adversarially reviewed                |
| `devshop-commit-guard.sh` check 1 | Deterministic | Mixed devshop + project files (project repo only)                                     | No bypass — unstage one set                               |
| check 2                           | **Semantic**  | Tooling changed — reviews ALL docs (including ones that don't yet mention the change) | `docsVerified` — always required, adversarially reviewed  |
| check 3                           | **Semantic**  | Reference doc changed — consistency review                                            | `docSyncReason` — always required, adversarially reviewed |
| check 4                           | Deterministic | Other repo has uncommitted changes                                                    | `crossRepoReason` — adversarially reviewed                |

Both repos use the same guard chain (project repo adds `check-claude-md-freshness.sh` first).

Bypass via `git -c devshop.<key>="<reason>"` works natively in husky. Every bypass reason is verified by an adversarial sonnet agent that actively tries to reject it. Semantic checks (2, 3) always require a reason — there is no auto-pass. Deterministic checks (clean tree, cross-repo) auto-pass when the condition is met.

**3. Claude PostToolUse (after git commit)** — configured in `.claude/settings.json`

| Hook                          | What                                                   | Fires when                        |
| ----------------------------- | ------------------------------------------------------ | --------------------------------- |
| Release prompt                | "Ask user about version bump + changelog"              | Commits in abra-kadabra repo only |
| `check-dirty-after-commit.sh` | Checks current repo + other repo for remaining changes | All commits                       |
| `check-pr-description.sh`     | PR description quality check                           | On `*git push*`, not commit       |

PostToolUse hooks are advisory (inject context, don't block).

---

## Devshop Documentation Structure

All devshop docs live in `.devshop/`. Three types: reference docs (living), backlogs (growing), and build blueprints (historical).

### Reference docs (living — update together in the same commit)

- `.devshop/README.md` — bird's eye view (~60-80 lines). Read for orientation.
- `.devshop/GUIDE.md` — full operational reference (this file). Read when implementing or shipping.

Commit guard enforces: check 3 (doc consistency) blocks if one is staged without the others unless a reason is provided via `git -c devshop.docSyncReason="<reason>"`. `/ak-pre-ship` also enforces.

### Backlogs (living — grow independently)

- `.devshop/TODOS.md` — tactical (friction, bugs, small fixes). Items can have version tags (e.g., `[v0.2]`).
- `.devshop/ROADMAP.md` — strategic (capabilities, major improvements). Defines version milestones.

See "Backlog Routing Guide" above for routing rules. Project backlogs (`TODOS.md`, `PRODUCT-ROADMAP.md`) are separate — see that section too.

### Build blueprints (one-time — historical after execution)

- `.devshop/notes/bootstrap/v0-web.md` — web devshop construction.
- `.devshop/notes/bootstrap/v1-native.md` — native/mobile capability (deferred).

Blueprints are not synced to projects — they live in the devshop repo as construction history for the devshop maintainer.

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

Check monthly or when approaching a launch. `/ak-init` fills in project-specific links.

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
- **Total: ~230 min/month** (12% of 2000 min free tier)

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

Find the deployment ID in the rollback checkpoint (PR comment from `/ak-go-live`).

### Migration rollback

Every migration file ends with a `-- ROLLBACK` comment block containing the SQL to reverse it. Copy-paste and run via `psql` or Supabase SQL editor. Test on a non-production environment first if possible.

### Canary failure

If `/canary` detects issues after deploy, immediately run `vercel rollback`. Then investigate root cause on the branch — do not push forward.

### Data recovery

Free-tier Supabase has no point-in-time recovery. Pre-migration `pg_dump` will be automated in Phase 1c — runs before applying new migrations, stored as GitHub Actions artifact. For weekly backups beyond deploys, see `.devshop/ROADMAP.md` v1. Always test schema changes against `supabase start` locally before deploying.

---

## Troubleshooting

_Grows as issues are encountered. Add entries with date, symptom, cause, fix._

### init-devshop.sh failures (2026-04-12)

**Symptom**: Container start fails with exit code 126 or "Permission denied"
**Cause**: macOS bind mount doesn't preserve execute permission on `/devshop/`
**Fix**: The thin forwarder must use `exec bash /devshop/...` not `exec /devshop/...`

**Symptom**: Container starts but no devshop skills/settings
**Check**: `ls -la /workspace/.devshop` — should be a symlink to `/devshop/.devshop/`
**Check**: `ls /workspace/.claude/skills/ | wc -l` — should be ~38
**Check**: `cat /workspace/CLAUDE.md | head -5` — should show devshop + project content

**Symptom**: `git status` shows devshop files as untracked
**Check**: `.gitignore` must have `.devshop` and `.claude` (no trailing `/` — symlinks need pattern without slash)

**Symptom**: Can't sudo inside container
**Cause**: init-devshop.sh didn't run (password setup is in that script)
**Fix**: Run `sudo /usr/local/bin/init-devshop.sh` (NOPASSWD rule covers this path). If that also fails, the thin forwarder may be broken — check `/workspace/.devcontainer/init-devshop.sh` content.

---

## Decision Log

_Short entries: "chose X over Y because Z, date" — extracted from reviews and retros._
