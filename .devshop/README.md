<!-- Editorial: one line per concept. If it takes more than one line to explain,
     it belongs in GUIDE.md. This file should stay under 80 lines / ~1k tokens. -->

# Abra-Kadabra Dev Shop — Overview

A one-person dev shop that goes from rough notes to deployed, tested, observable web app with minimal manual intervention. Claude Code implements autonomously; gstack handles the full lifecycle around it (planning, review, QA, security, deploy, monitoring). The glue is conventions, pre-commit hooks, CI, and custom skills. Two touchpoints: review the PR, say "land it."

**Architecture**: The devshop (abra-kadabra) and project repos are separate. The project repo is clean and publishable. Devshop files get injected into the workspace at container start via `init-devshop.sh` symlinks. See GUIDE.md § Devshop Separation Architecture for the full model.

**New project?** Create a repo, add a `.devcontainer/` that mounts `../abra-kadabra` at `/devshop`, then run `/ak-init` — walks you through the setup checklist in GUIDE.md step by step.

## Workflow (Idea to Deployed)

1. You write rough notes — problem description + rough solution idea
2. `/office-hours` (gstack) — interviews you, challenges framing, produces product design doc
3. `/autoplan` (gstack) — eng/CEO/design review; locks in architecture, edge cases, decisions
   3b. `/design-shotgun` (optional) — visual variants if feature is UI-heavy; approve one direction
   3c. `/design-html` (optional) — HTML reference from approved mockup; Claude builds React from this
4. `/ak-build` (devshop) — autonomous: spec → implement → quality gates → ship → CI watch+fix → notify you
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
Docs:    GUIDE.md (reference) · DESIGN.md (visual) · METRICS.md (analytics) · CLAUDE.md (agent config) · PRODUCT-ROADMAP.md (deferred items)
Apps:    apps/web/ (Next.js 15, App Router)
Shared:  packages/core/ (business logic, Supabase client, API wrappers) · packages/ui/ (design tokens, components)
Backend: supabase/migrations/ (schema) · supabase/functions/ (edge functions)
CI/CD:   .github/workflows/ci.yml · apps/web/vercel.json
Devshop: .devshop/ → symlink to /devshop/.devshop/ (injected at container start from abra-kadabra)
Claude:  .claude/ (injected: skills, commands, settings) · CLAUDE.md (generated) · CLAUDE.project.md (tracked, project-specific)
Logs:    BUILD-LOG.md (project builds, gitignored) · .devshop/CHANGELOG.md (devshop versions)
Backlogs: TODOS.md (project tactical) · PRODUCT-ROADMAP.md (project strategic) · .devshop/TODOS.md (devshop tactical) · .devshop/ROADMAP.md (devshop strategic)
Config:  turbo.json · pnpm-workspace.yaml · tsconfig.base.json · eslint.config.mjs · .dcg.toml · .gitleaks.toml
```

## Key Conventions

- **No code without tests** — written alongside, never after. Unit + integration + E2E. Integration tests hit a real local DB, never mocks.
- **No code without metrics** — `/spec` creates events in `METRICS.md`, `/implement` instruments them, `/pre-ship` validates.
- **No broken tests** — full suite runs before marking a task done. CI gates PR merge.
- **Responsive + light/dark from day one** — build for 375px, scale up. Theme tokens only, no hardcoded colors. Both themes verified before ship.
- **PWA-ready** — manifest.json, service worker, Apple meta tags. "Add to Home Screen" works on iOS/Android.
- **Pre-commit enforcement** — ESLint + Prettier + gitleaks secret scan + file header check on every commit, no bypass.
- **CI mirrors runtime** — if the app uses a DB at runtime, CI starts it locally and runs integration tests against it.
- **Edge functions validate auth server-side** — `getUser()` on every request, even if gateway checks JWT.
- **Shared packages export TypeScript source** — no build step. Barrel exports only, no deep path imports.
- **Every `.ts`/`.tsx` file has a 3-line header** (`What` / `Why` / `Does NOT`); every export has JSDoc.

## Glossary

- **abra-kadabra** — brand name for the dev shop (template repo, doc titles). Never used in file names or CLI commands.
- **devshop** — code name: `.devshop/`, `.claude/skills/devshop/`, `/devshop:*` skills.
- **gstack** — AI lifecycle toolkit (`.claude/skills/gstack/`). Per-project install, not part of template sync.
- **specs/<name>/** — per-feature folder: `spec.md` (spec), `tasks.md` (tasks + decisions), `review.md` (quality gate results). Permanent record after merge.
- **METRICS.md** — event taxonomy + feature flags. Source of truth for analytics.

## Further Reading

- `./GUIDE.md` — full operational reference (workflow details, skill map, checklists, new-project guide)
- `./TODOS.md` — devshop tactical backlog (friction, bugs, small fixes)
- `./ROADMAP.md` — devshop strategic backlog (capabilities, major improvements)
- `./notes/bootstrap/v0-web.md` — construction blueprint for the web devshop (historical after build)
- `./notes/bootstrap/v1-native.md` — construction blueprint for native/mobile capability (deferred)
