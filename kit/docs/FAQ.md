# Dev-Shop FAQ

Answers to questions that came up while reviewing the devshop plan (`notes/bootstrap/v0-web.md`).

---

## What is this dev-shop, at a high level?

A repeatable system that takes an idea to a deployed, tested, monitored app with minimal manual intervention — built for a solo developer using Claude Code as the implementation engine.

The dev-shop is already ~70% assembled via **gstack** (planning, QA, code review, shipping, monitoring). What the plan adds is the repo + CI/CD infrastructure that gstack runs on, plus the conventions (the guide, `CLAUDE.md`, per-feature specs/) that make handoffs between tools clean.

The first project built with the devshop was a bilingual grocery list app migrated from Swift/SwiftUI to React (Next.js web) + React Native (Expo mobile).

---

## Is the dev-shop machinery portable to future projects?

Yes — portability is a first-class concern. New projects are created from `template/` at the devshop repo root via `/ak-new-project` (no cloning the devshop itself). `kit/manifest.txt` is the single source of truth for every workspace path the devshop manages; each declared path carries an inline lifecycle annotation. See `guide/architecture.md § File lifecycle` for the full table and the parser library.

**`[symlink]`** (node-owned symlinks to `/devshop/`, auto-recovered if lost by git ops):

- `.devshopkit/`, `.claude/skills/`, `.claude/commands/`, `.hooks/pre-commit`

**`[locked]` + `[locked-dir]`** (root-owned copies refreshed every container start, sticky-bit dirs prevent deletion):

- `.claude/settings.json`, `.dcg.toml`, `.devcontainer/{Dockerfile,init-devshop.sh,init-firewall.sh,devcontainer.json,checksums.sha256}`, `.husky/{pre-commit,pre-push}` (see `guide/security.md`)

**`[sync]`** (initial copy at scaffold, then project-owned and may diverge; manual bidirectional sync via `from-devshop.sh` / `to-devshop.sh`):

- `.devcontainer/`, `.husky/`, `.github/workflows/`, `turbo.json`, `eslint.config.mjs`, etc.

**`[scaffold-once]`** (copied once at `/ak-new-project` time, project owns thereafter — template's version becomes irrelevant):

- `BUILD-LOG.md`, `CLAUDE.md`, `PLAN.md`, `TODOS.md`, `METRICS.md`, `.devshop-test-coverage-exempt`, `.devshop-docs-freshness-exempt`

**Project-only** (never in abra-kadabra, not in the manifest):

- `apps/`, `packages/`, `supabase/`, `DESIGN.md`, `specs/`, `.devcontainer/.env`, `.claude/settings.local.json`

The devshop (abra-kadabra) and project repos are separate (since v1.0.0). The `template/` directory at the devshop root contains the project skeleton — `/ak-new-project` creates a GitHub repo from it. Devshop files get injected into the workspace at container start via `init-devshop.sh` — they're gitignored in the project repo. Build tooling files (turbo.json, eslint, etc.) are tracked in both repos and can be synced:

- `kit/scripts/sync/to-devshop.sh` — push build tooling improvements to abra-kadabra's `template/`
- `kit/scripts/sync/from-devshop.sh` — pull build tooling updates from `template/` into a project

No git submodules. Git-native. You review every change. See `guide/architecture.md` for the full model.

---

## Do I need two separate apps for web and mobile, or is React Native built on top of the web app?

Two separate apps. React Native compiles to native iOS/Android components — it doesn't wrap the web app in a WebView or extend it.

What they **share** via the monorepo:

- `packages/core` — Supabase client, types, API wrappers, data models (written once)
- `packages/ui` — design tokens + base components styled with NativeWind (same Tailwind class names on both)

What you write **twice**: the UI layer — each screen exists in both `apps/web` and `apps/mobile`. But they share the same component primitives and design tokens, so duplication is mostly layout-level glue.

**Why not a single Expo app targeting both web and native?** Expo does support web export, but you'd lose Next.js features (SSR, SEO, file-based routing). Next.js for web, Expo for mobile is the right split when SEO and server rendering matter for the web experience.

---

## Does the plan account for dev happening inside a devcontainer?

Yes. The `.devcontainer/` is part of the dev-shop layer — each project gets its own devcontainer with the devshop mounted via bind mount.

Devcontainer-specific considerations in the plan:

- **Dockerfile** gets `pnpm` + `@expo/eas-cli` added (Phase 0 Step 1)
- **Firewall** (`init-firewall.sh`) gets `expo.dev`, `vercel.com`, `cdn.jsdelivr.net`, `objects.githubusercontent.com` added (Phase 0 Step 2)
- **Expo dev server** uses `--tunnel` mode to reach a physical iPhone, since the devcontainer can't reach the LAN directly

One thing to know: the `/home/node/.claude` Docker volume (Claude's API key, sessions, internal config) is per-machine, not per-project. It's shared across all devcontainers on the same machine — fine for a solo dev, just means it's not in git and is lost on machine migration.

---

## What's committed to git vs what's ephemeral?

**Committed to git:**

- `.claude/` — settings, skills, hooks, custom commands
- `/home/node/.claude/projects/-workspace/memory/` — Claude's memory files (symlinked into the repo so they're git-tracked)

**Ephemeral (not git-tracked):**

- Claude Code sessions and conversation history — lost if the container is rebuilt from scratch

This is acceptable because: container failures are rare, and the implementation loop commits frequently. On resume, `/ak-status` reconstructs context from file state — it reads `PLAN.md` (what's active, what's planned), the active branch's `specs/<name>/tasks.md` (per-task status), `BUILD-LOG.md` (what's shipped recently), and `git log` / `git status`. No session history needed.

**Mitigation**: avoid rebuilding the container from scratch during long-running implementation work.

---

## How are specs and pipeline artifacts organized?

Three layers of tracking, each at its own grain:

```
Project root (forward-looking)
  PLAN.md               — Active + Planned features at PR grain
  BUILD-LOG.md          — shipped entries (append-only, newest first)
  PRODUCT-ROADMAP.md    — deferred / long-term
  TODOS.md              — tactical bugs/polish

Per-feature (specs/<name>/)
  spec.md           — seeded by /ak-build Phase 0 as a Decisions skeleton,
                      expanded by /ak-spec into the full spec; includes a
                      required `## Core user story` section (or N/A) whose
                      verbs Gate 9 enforces with per-verb artifacts
  tasks.md          — task breakdown + decisions (from /ak-implement)
  qa-walk/          — gitignored: per-verb artifacts from Gate 9 (screenshots
                      or state JSON) proving each Core user story verb
                      completed; path: verb-<N>-<slug>.{png,json}
  review.md         — quality gate results (from /ak-pre-ship). First line is
                      `<!-- audited-at: <SHA> -->` (the contract /ak-build
                      Phase 5.8 reads to derive the post-pre-ship audit range)
  test-review-followup.md
                    — committed: post-pre-ship test-coverage findings written
                      by /ak-build Phase 5.8 (Sonnet subagent re-runs
                      /ak-tests-review over <pre-ship-sha>..HEAD). First line
                      is `<!-- audited-at: <SHA> -->`. Read by Phase 6's
                      audit comment + Step 0 resume rung 1a
  hero/             — committed: 1–2 durable screenshots per key screen
  screenshots/      — gitignored: per-gate evidence (4 viewport/theme combos)
  design-claims.json            — gitignored: normative claims extracted
                                  from DESIGN.md by /ak-design-conformance
                                  (cached by sha256, re-extracted on DESIGN.md
                                  changes)
  design-conformance-report.md  — gitignored: per-claim verdict + findings
                                  from the design-conformance (ak) gate
```

Each feature directory is immutable after merge — a permanent record of the full pipeline: **bug → code → spec → plan** traceability. Improvements to a shipped feature get a new folder (e.g. `specs/auth-invite-codes/`, not `specs/auth/v2/`), with a `**Builds on**:` pointer to the prior spec in the new spec.md.

`/ak-build` resolves the active feature from `PLAN.md § Active` (Branch + Spec columns). `/ak-implement` and `/ak-status` do the same. No root-level pointer file needed.

**Hero vs evidence screenshots:**

- `specs/<name>/hero/` is **committed**. 1–2 files per key user-facing screen, default 1440×light (`signin.png`, `onboarding.png`). Embedded in the `/ak-build` audit comment and referenced from `BUILD-LOG.md` as the durable visual record of what shipped. Captured after all gates pass.
- `specs/<name>/screenshots/` is **gitignored** via the root `.gitignore` pattern `specs/*/screenshots/`. Holds the 4 viewport/theme combos (375 × light/dark, 1440 × light/dark) captured during Gate 3 as per-run evidence. Regenerable; never committed.

The split exists so durable documentation (hero) doesn't bloat the repo with every pre-ship run's full 4-combo grid, while the grid itself is still available locally for audit.

---

## Why this specific stack (Turborepo, Next.js, Vitest, Playwright)?

Each choice optimizes for a solo dev using Claude Code in a devcontainer:

- **Turborepo + pnpm** — fast incremental builds across monorepo packages with free remote caching. pnpm is faster than npm for monorepos (hard-links, no duplication). Both are standard, well-maintained, and free. The monorepo structure (`apps/web`, `packages/core`, `packages/ui`) supports future mobile apps without migration.
- **Next.js (App Router)** — best-in-class React framework. Zero-config Vercel deployment. SSR + SSG + SEO out of the box. App Router is the current standard (Pages Router is legacy).
- **Vitest** — faster than Jest, TypeScript-native, same config for unit and integration tests. Single test runner for the web-first phase.
- **Playwright** — best-in-class web E2E tool, runs in GitHub Actions, built-in mobile viewport support (375px + 1440px). Covers visual regression via screenshot comparison.
- **No Storybook/Chromatic** — too much overhead for a solo dev. Playwright screenshot comparison covers visual regression without a separate tool or service.
- **Platform-agnostic shared packages** — `packages/core` and `packages/ui` must NOT contain Next.js-specific imports. They export pure TypeScript — framework-agnostic logic and design tokens. This ensures future mobile apps can import them without modification. Each consuming app (`apps/web`, future `apps/mobile`) handles its own framework integration.

---

## Why are there two CLAUDE files?

- **`CLAUDE.md`** (devshop repo root) — devshop conventions: confidence calibration, non-negotiables, workflow, hooks. Same across all projects.
- **`CLAUDE.md`** (project root) — project-specific context: stack, paths, env vars, deploy config. Tracked in the project repo.

Claude Code auto-loads both: the project's via natural CLAUDE.md discovery in the workspace; the devshop's via the SessionStart hook, which injects `/devshop/CLAUDE.md` into project sessions at runtime (workaround for `anthropics/claude-code#22583` — `additionalDirectories` CLAUDE.md isn't loaded by Claude Code natively). No assembly or generation step needed; the file copies stay independent.

**Design principle: project `CLAUDE.md` is self-sufficient for public contributors.** Because the SessionStart hook delivers devshop context at runtime, the project's committed `CLAUDE.md` does **not** need to mention devshop conventions, point at `/devshop/...` paths, or otherwise reference the devshop side. A public contributor cloning the project on GitHub sees only project-relevant content (stack, paths, env vars, gotchas, deploy config) — nothing pointing into the private `/devshop` bind mount they can't navigate. The hook bridges the two layers at runtime; the file does not. When tempted to add a `/devshop/CLAUDE.md § X` cross-reference to project `CLAUDE.md`, the rule is: **don't**. Either lift the convention into project-side guidance (if it applies project-side) or trust the hook.

Edit devshop conventions in the devshop repo's `CLAUDE.md`. Edit project context in the project's `CLAUDE.md`. The hook handles the rest. See `/devshop/CLAUDE.md § Session Start` for the mechanism and `/ak-new-project § Step 18` for what goes in (and what does NOT go in) project `CLAUDE.md` at scaffold time.

---

## What's the fast path for a hotfix, doc-only PR, or commit from the terminal?

Each case has a different fast path through the husky pre-commit / pre-push gates:

- **Doc-only PRs** auto-skip the pre-push PR-description review via the trivial-commit short-circuit (every commit prefixed `docs:` / `chore:` / `style:` / `test:` / `ci:` / `build:` / `perf:` AND zero source-file changes under `apps/*/src/` or `packages/*/src/`).
- **Hotfixes** still ride a PR — direct push to `main` is hard-blocked locally AND at the remote via branch protection — but adversarially-reviewed `git -c devshop.<flag>="..."` bypass keys clear non-essential gates that fire on a one-line fix.
- **Human terminal commits** have escape hatches Claude can't reach: `devshop.humanReviewed` (skips the LLM reviewer), `DEVSHOP_SKIP_ADVERSARIAL=1` (skips all adversarial review for the process), and plain `--no-verify` (bypasses husky entirely, no `hookBypassReason` needed).

See [`guide/hooks.md § Practical recipes`](guide/hooks.md#practical-recipes) for step-by-step recipes and the canonical bypass-flag names per gate.
