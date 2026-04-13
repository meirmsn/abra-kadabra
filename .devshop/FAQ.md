# Dev-Shop FAQ

Answers to questions that came up while reviewing the devshop plan (`notes/bootstrap/v0-web.md`).

---

## What is this dev-shop, at a high level?

A repeatable system that takes an idea to a deployed, tested, monitored app with minimal manual intervention — built for a solo developer using Claude Code as the implementation engine.

The dev-shop is already ~70% assembled via **gstack** (planning, QA, code review, shipping, monitoring). What the plan adds is the repo + CI/CD infrastructure that gstack runs on, plus the conventions (`.devshop/GUIDE.md`, `CLAUDE.md`, per-feature specs/) that make handoffs between tools clean.

The guinea pig project is **lalista** — a bilingual grocery list app being migrated from Swift/SwiftUI to React (Next.js web) + React Native (Expo mobile).

---

## Is the dev-shop machinery portable to future projects?

Yes — portability is a first-class concern. Files are separated into three categories:

**Injected** (from abra-kadabra via symlinks at container start, gitignored in project):

- `.devshop/`, `.claude/` (skills, commands, settings), `.dcg.toml`, `CLAUDE.md`, `BUILD-LOG.md`

**Shared** (copied from abra-kadabra during `/ak-init`, then project-owned):

- `.devcontainer/`, `.husky/`, `.github/workflows/`, `turbo.json`, `eslint.config.mjs`, etc.

**Project-only** (never in abra-kadabra):

- `apps/`, `packages/`, `supabase/`, `CLAUDE.project.md`, `DESIGN.md`, `specs/`, `METRICS.md`

The devshop (abra-kadabra) and project repos are separate (since v1.0.0). Devshop files get injected into the workspace at container start via `init-devshop.sh` symlinks — they're gitignored in the project repo. Build tooling files (turbo.json, eslint, etc.) are tracked in both repos and can be synced:

- `.devshop/scripts/sync-to-devshop.sh` — push build tooling improvements to abra-kadabra
- `.devshop/scripts/sync-from-devshop.sh` — pull build tooling updates into a project

No git submodules. Git-native. You review every change. See GUIDE.md § Devshop Separation Architecture for the full model.

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

## Why are there multiple CLAUDE files?

- **`abra-kadabra/CLAUDE.md`** — devshop conventions: confidence calibration, non-negotiables, workflow, hooks. Lives in the devshop repo, same across all projects.
- **`CLAUDE.project.md`** (project root) — project-specific context: stack, paths, env vars, deploy config. Tracked in the project repo.
- **`CLAUDE.md`** (project root) — generated by `init-devshop.sh` at container start by concatenating the above two. Gitignored in the project repo.

Claude Code only auto-loads `CLAUDE.md` from the project root. The generation step ensures both devshop conventions and project context are in Claude's context without requiring extra file reads.

Edit devshop conventions in `abra-kadabra/CLAUDE.md`. Edit project context in `CLAUDE.project.md`. The generated `CLAUDE.md` updates on next container start.
