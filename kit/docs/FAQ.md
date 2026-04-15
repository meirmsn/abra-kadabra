# Dev-Shop FAQ

Answers to questions that came up while reviewing the devshop plan (`notes/bootstrap/v0-web.md`).

---

## What is this dev-shop, at a high level?

A repeatable system that takes an idea to a deployed, tested, monitored app with minimal manual intervention — built for a solo developer using Claude Code as the implementation engine.

The dev-shop is already ~70% assembled via **gstack** (planning, QA, code review, shipping, monitoring). What the plan adds is the repo + CI/CD infrastructure that gstack runs on, plus the conventions (the guide, `CLAUDE.md`, per-feature specs/) that make handoffs between tools clean.

The guinea pig project is **lalista** — a bilingual grocery list app being migrated from Swift/SwiftUI to React (Next.js web) + React Native (Expo mobile).

---

## Is the dev-shop machinery portable to future projects?

Yes — portability is a first-class concern. New projects are created from `template/` at the devshop repo root via `/ak-new-project` (no cloning the devshop itself). Files fall into five categories (see `guide/architecture.md` § File Lifecycle for full detail):

**1. Symlinked** (from abra-kadabra at container start, gitignored in project):

- `.devshopkit/`, `.claude/skills/`, `.claude/commands/`, `.hooks/pre-commit`

**2. Root-owned copies** (from abra-kadabra at container start, gitignored in project):

- `.claude/settings.json`, `.dcg.toml` (locked by init-devshop.sh, survive git ops, sticky bit prevents deletion — see guide/security.md)

**3. Manifest files** (from abra-kadabra initial clone, then project-owned, can diverge):

- `.devcontainer/`, `.husky/`, `.github/workflows/`, `turbo.json`, `eslint.config.mjs`, etc.

**4. Generated** (created at container start if missing):

- `BUILD-LOG.md` (templated if missing, then project-owned and tracked)

**5. Project-only** (never in abra-kadabra):

- `apps/`, `packages/`, `supabase/`, `CLAUDE.md`, `DESIGN.md`, `specs/`, `METRICS.md`

The devshop (abra-kadabra) and project repos are separate (since v1.0.0). The `template/` directory at the devshop root contains the project skeleton — `/ak-new-project` creates a GitHub repo from it. Devshop files get injected into the workspace at container start via `init-devshop.sh` — they're gitignored in the project repo. Build tooling files (turbo.json, eslint, etc.) are tracked in both repos and can be synced:

- `kit/scripts/sync-to-devshop.sh` — push build tooling improvements to abra-kadabra's `template/`
- `kit/scripts/sync-from-devshop.sh` — pull build tooling updates from `template/` into a project

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

This is acceptable because: container failures are rare, and the plan's implementation loop commits frequently. If a session is interrupted, the resume pattern (`read specs/<name>/tasks.md + recent git log`) reconstructs context from git state without needing the session history.

**Mitigation**: avoid rebuilding the container from scratch during long-running implementation work.

---

## How are specs and pipeline artifacts organized?

Each feature gets its own folder in `specs/`:

```
specs/add-item-voice/
  spec.md      — implementation spec (from /spec)
  tasks.md     — task breakdown + decisions (from /implement)
  review.md    — quality gate results (from /pre-ship)
```

No root pointer files — `/build` derives the feature name from the branch. Each skill reads/writes to `specs/<name>/`. After merge, the folder is a permanent record of the full pipeline: **bug → code → spec → plan** traceability.

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

Claude Code auto-loads both because `/devshop` is configured as an `additionalDirectories` entry in `settings.json`. No assembly or generation step needed.

Edit devshop conventions in the devshop repo's `CLAUDE.md`. Edit project context in the project's `CLAUDE.md`.
