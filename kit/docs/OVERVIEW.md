<!-- Editorial: prose sections use one line per concept (detail belongs in the guide).
     Diagrams (System Components) are an exception — they pack operational detail visually. -->

# Abra-Kadabra Dev Shop — Overview

A one-person dev shop that goes from rough notes to deployed, tested, observable web app with minimal manual intervention. Claude Code implements autonomously; gstack handles the full lifecycle around it (planning, review, QA, security, deploy, monitoring). The glue is conventions, pre-commit hooks, CI, and custom skills. Two touchpoints: review the PR, say "land it."

**Architecture**: The devshop (abra-kadabra) and project repos are separate. The project repo is clean and publishable. Devshop files get injected into the workspace at container start via `init-devshop.sh` (symlinks + root-owned copies). See `guide/architecture.md` for the full model.

**New project?** Run `/ak-new-project` from any devcontainer — Phase A creates the GitHub repo from the `template/` skeleton, Phase B runs setup after you open the new project.

## System Components

### Workspace layout

```
Container Workspace (/workspace)
│
├── Project repo (git-tracked, public-facing)
│   ├── apps/web/                Next.js 15 app
│   ├── packages/core/           Business logic, Supabase client, types
│   ├── packages/ui/             Design tokens, shared components
│   ├── supabase/                Migrations, edge functions
│   ├── .github/workflows/       CI (lint, typecheck, test, build)
│   ├── .husky/pre-commit        → kit/hooks/pre-commit.sh (5-step chain + 4 guards)
│   ├── CLAUDE.md                Project-specific agent config
│   └── METRICS.md, TODOS.md    Project analytics + backlog
│
├── Devshop injection (gitignored — created at container start by init-devshop.sh)
│   ├── .devshopkit/ ──symlink──→ /devshop/kit/
│   │   ├── scripts/             Init, release, session, statusline, adversarial review, changelog (root)
│   │   │   ├── preship/         Pre-ship gate helpers: router-shim, verify-story, design-conformance, supabase-bootstrap
│   │   │   ├── commit-hooks/    commit-guard + check-* (clean-tree, manifest, security-freshness, etc.)
│   │   │   ├── sync/            from/to-devshop, create-devshop-symlinks, normalize-devshop-paths
│   │   │   └── notify/          claude-{cancel,done,request}
│   │   ├── hooks/pre-commit.sh  Orchestrates the 5-step + 4-guard chain
│   │   ├── tests/               BATS test suite (guards, routing, goals, structural invariants)
│   │   └── docs/                MODEL, OVERVIEW, guide/ (6 files), FAQ
│   ├── .claude/
│   │   ├── skills/ ──symlink──→ /devshop/.claude/skills/
│   │   │   ├── devshop/         ak-build, ak-spec, ak-implement, ak-pre-ship...
│   │   │   └── gstack/          autoplan, review, qa, browse, ship, canary...
│   │   └── settings.json       ← root-owned copy (permissions, hooks, deny rules)
│   └── .dcg.toml               ← root-owned copy (49+ blocked destructive patterns)
│
└── /devshop/ (bind mount — private repo, not tracked in project)
    ├── kit/             Operational devshop (symlinked into projects)
    ├── template/        Project skeleton for /ak-new-project
    ├── CLAUDE.md        Devshop conventions (auto-loaded every session)
    └── README.md        Entry point — goals, getting started
```

### Event flow

What fires and when across the session lifecycle (per-hook detail: `guide/hooks.md`):

```
Container Start
  └─ init-devshop.sh ────────── create symlinks, copy+lock security files, install deps

Session Start (new session or /clear)
  └─ session-start.sh ────────── recover symlinks, check security freshness, inject context

Every Bash Command
  └─ DCG ──────────────────────── blocks 49+ destructive patterns (rm -rf, DROP TABLE, etc.)

git commit
  ├─ PreToolUse
  │   ├─ check-hook-bypass.sh ──── blocks --no-verify without documented reason
  │   └─ check-branch-not-main.sh ─ blocks Claude from committing on main/master
  ├─ .husky/pre-commit (6 steps + devshop guards)
  │   ├─ 1. sync/create-devshop-symlinks.sh ── recover if git ops lost them
  │   ├─ 2. lint-staged ───────────────── ESLint + Prettier on staged files
  │   ├─ 3. turbo typecheck ──────────── TypeScript errors
  │   ├─ 4. gitleaks ─────────────────── secret scan on staged files
  │   ├─ 5. bats kit/tests/ ────────────── kit tests: scripts + structural invariants (devshop only)
  │   └─ 6. devshop guards (under commit-hooks/)
  │       ├─ check-security-files-freshness.sh
  │       ├─ check-clean-tree.sh ────────── no unaddressed dirty state
  │       ├─ check-manifest.sh ──────────── (devshop repo only)
  │       ├─ check-test-coverage.sh ─────── new scripts need tests (devshop only)
  │       └─ commit-guard.sh ──────────── 5 checks (run in this order):
  │           ├─ mixed-commit ───────────── devshop + project files together? block
  │           ├─ docs-drift ─────────────── any devshop file staged (non-release)? block
  │           ├─ doc-consistency ────────── one ref doc changed without others? block
  │           ├─ cross-repo ─────────────── other repo has uncommitted changes? block
  │           └─ release-coverage ───────── kit/version bumped? adversarial agent
  │                                         judges whether changes since last tag
  │                                         need test coverage (one Sonnet call)
  (no PostToolUse — workflow nudges live at the git layer; see guide/hooks.md)

git push
  └─ .husky/pre-push (blocking)
      ├─ PR description staleness ────── vs commits on branch
      │                                   (skipped for chore/docs/test/etc. only)
      └─ dirty tree / stash check ────── block if unclean
           (both adversarially reviewed; bypass via
            devshop.prDescStaleReason / devshop.dirtyPushReason)

release.sh (devshop version bump)
  └─ Bump + commit + tag + push
      (the test-coverage review runs via the commit guard above — triggered by
       kit/version being staged — so any bump commit is reviewed, whether from
       release.sh or a manual git commit)
```

## Workflow (Idea to Deployed)

See `guide/workflow.md` for the full pipeline diagram and per-step detail.

1. You write rough notes — problem description + rough solution idea
2. `/office-hours` (gstack) — interviews you, challenges framing, produces product design doc
3. `/autoplan` (gstack) — eng/CEO/design review; locks in architecture, edge cases, decisions
   3b. `/design-shotgun` (optional) — visual variants if feature is UI-heavy; approve one direction
   3c. `/design-html` (optional) — HTML reference from approved mockup; Claude builds React from this
4. `/ak-build` (devshop) — autonomous: preview → spec → implement → quality gates → ship → CI watch+fix → notify you
5. You review PR — release notes + audit trail + CI green + preview URL
6. `/ak-go-live` (devshop) — autonomous: merge → deploy → canary → reflect → notify you

### Branch strategy

`main` (production) — always deployable. No `develop` branch.

- `/ak-build` creates a `feature/<name>` or `fix/<name>` branch, implements, pushes, opens PR
- You review the PR (preview URL + audit trail + CI green)
- `/ak-go-live` merges the PR, deploys, runs canary, reflects

Branch protection on `main` requires PR + CI green before merge.

## File Map

```
Docs:    guide/ (reference) · DESIGN.md (visual) · METRICS.md (analytics) · CLAUDE.md (agent config) · PLAN.md (forward plan at PR grain) · PRODUCT-ROADMAP.md (deferred items)
Apps:    apps/web/ (Next.js 15, App Router)
Shared:  packages/core/ (business logic, Supabase client, API wrappers) · packages/ui/ (design tokens, components)
Backend: supabase/migrations/ (schema) · supabase/functions/ (edge functions)
CI/CD:   .github/workflows/ci.yml · apps/web/vercel.json
Template: template/ (project skeleton — .devcontainer/, .github/, turbo.json, eslint, package.json, etc.)
Devshop: .devshopkit/ → symlink to /devshop/kit/ (injected at container start from abra-kadabra)
Hooks:   .husky/pre-commit calls /devshop/kit/hooks/pre-commit.sh by absolute path (devshop guards, repo-aware)
Claude:  .claude/ (injected: skills, commands, settings) · CLAUDE.md (project-specific, tracked) · /devshop/CLAUDE.md (devshop conventions, auto-loaded)
Logs:    BUILD-LOG.md (shipped features, tracked) · kit/docs/CHANGELOG.md (devshop versions) · kit/notes/projects/<name>.md (init tracking)
Backlogs: TODOS.md (project tactical) · PRODUCT-ROADMAP.md (project strategic) · kit/TODOS.md (devshop tactical) · kit/ROADMAP.md (devshop strategic)
Config:  turbo.json · pnpm-workspace.yaml · tsconfig.base.json · eslint.config.mjs · .dcg.toml · .gitleaks.toml
```

## Key Conventions

Full specification in `guide/conventions.md`; enforcement in `guide/hooks.md`; security rules in `guide/security.md`.

- **Detail lives closest to where it's used** — if one skill runs it, that skill owns it. If it spans skills or the whole workflow, the guide owns it. OVERVIEW.md is orientation; CLAUDE.md is agent config. Don't duplicate — point.
- **No code without tests** — written alongside, never after. Unit + integration + E2E. Integration tests hit a real local DB, never mocks.
- **No code without metrics** — `/ak-spec` creates events in `METRICS.md`, `/ak-implement` instruments them, `/ak-pre-ship` validates.
- **No broken tests** — full suite runs before marking a task done. CI gates PR merge.
- **Responsive + light/dark from day one** — build for 375px, scale up. Theme tokens only, no hardcoded colors. Both themes verified before ship.
- **PWA-installable** — manifest.json, Apple meta tags. "Add to Home Screen" works on iOS/Android. Service worker deferred until core screens are stable.
- **Pre-commit enforcement** — symlink recovery + ESLint + Prettier + typecheck + gitleaks secret scan + security file freshness check + devshop commit guard on every commit. Hook bypass protection blocks `--no-verify` without a reason; bypass reasons are adversarially reviewed by an independent agent.
- **CI mirrors runtime** — if the app uses a DB at runtime, CI starts it locally and runs integration tests against it.
- **Edge functions validate auth server-side** — `getUser()` on every request, even if gateway checks JWT.
- **Shared packages export TypeScript source** — no build step. Barrel exports only, no deep path imports.
- **Every `.ts`/`.tsx` file has a 3-line header** (`What` / `Why` / `Does NOT`); every export has JSDoc.

## What the Guide Covers (cross-cutting reference)

These topics span multiple skills, so the guide (`./guide/`) owns them:

- **Metrics Lifecycle** (`guide/conventions.md § Metrics Lifecycle`) — how events flow through /ak-spec → /ak-implement → /ak-pre-ship
- **Testing layers** (`guide/conventions.md § Testing`) — unit vs integration vs E2E, RLS boundary tests, seed.sql, CI mirrors runtime
- **Security + Quality** (`guide/security.md`) — pre-commit steps, security-critical file list, fakeowner caveat, known gaps
- **Hooks table + Commit Flow** (`guide/hooks.md`) — what fires on commit/push/session-start and in what order
- **Notifications** (`guide/notifications.md`) — push alerts to iPhone/Watch/Mac via ntfy.sh, 30s debounce, privacy, rotation
- **Rollback procedures** (`guide/ops.md § When Things Go Wrong`) — Vercel rollback, migration rollback SQL, canary failure response

CI slow job expansion plans are in ROADMAP.md § v+.

## Glossary

- **abra-kadabra** — brand name for the dev shop (devshop repo, doc titles). Never used in file names or CLI commands.
- **devshop** — code name: `kit/` (repo), `.devshopkit/` (workspace symlink), `.claude/skills/devshop/`. Skills use `ak-` prefix (`/ak-build`, `/ak-spec`, etc.).
- **gstack** — AI lifecycle toolkit (`.claude/skills/gstack/`). Per-project install, not part of devshop sync.
- **specs/<name>/** — per-feature folder: `spec.md` (seeded by /ak-build Phase 0 as a Decisions skeleton, expanded by /ak-spec into the full spec with a required `## Core user story` section), `tasks.md` (tasks + decisions from /ak-implement), `review.md` (quality gate results from /ak-pre-ship), `hero/` (committed durable screenshots), `screenshots/` (gitignored per-gate evidence), `qa-walk/` (gitignored per-verb artifacts proving each Core user story verb completed — Gate 9 enforcement), `design-claims.json` + `design-claims.json.sha256` + `design-conformance-report.md` (gitignored per-run artifacts from the design-conformance (ak) gate — claim cache + verification report). Permanent record after merge; see `FAQ.md § How are specs and pipeline artifacts organized?` for the hero/evidence split.
- **/screenshots/** — repo-root folder for dev-context shots (what you paste into a conversation / share for a bug report). Contents gitignored; tracked `README.md` inside documents the convention. Distinct from `specs/<name>/hero/` (per-PR product shots) and `specs/<name>/screenshots/` (pre-ship gate evidence). See `guide/conventions.md § Screenshot Routing`.
- **METRICS.md** — event taxonomy + feature flags. Source of truth for analytics.

## Further Reading

- `./guide/README.md` — full operational reference (table of contents; per-doc summaries for workflow, conventions, hooks, security, architecture, ops)
- `./FAQ.md` — design rationale and architecture decisions
- `../TODOS.md` — devshop tactical backlog (friction, bugs, small fixes)
- `../ROADMAP.md` — devshop strategic backlog (capabilities, major improvements)
- `../notes/bootstrap/v0-web.md` — construction blueprint for the web devshop (historical after build)
- `../notes/bootstrap/v+-native.md` — construction blueprint for native/mobile capability (deferred)
