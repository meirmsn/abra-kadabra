# CLAUDE.md

> **Orientation**: this is the entry-point doc loaded at every session start. Drill into `PLAN.md` / `BUILD-LOG.md` / `TODOS.md` / `METRICS.md` / `PRODUCT-ROADMAP.md` only when the question demands it.

## Project: <project-name>

<one-line description of what this project is>

### Where Things Happen

Path map of every documented surface. Update this section when introducing a new page, API wrapper, edge function, design token surface, or CI/CD workflow — `kit/scripts/commit-hooks/check-docs-freshness-project.sh` blocks PRs that add a triggering surface without updating this section.

- **Forward plan**: `PLAN.md` (Active + Planned features at PR grain). Shipped history in `BUILD-LOG.md`. Deferred / long-term in `PRODUCT-ROADMAP.md`. Tactical bugs/polish in `TODOS.md`.
- **<surface name>**: <one-sentence pointer to the file path(s) where it lives>

_This section grows as code is added. Update it when introducing new paths._

### Gotchas

Non-obvious rules surfaced by shipping work. Read before touching the relevant area. Add an entry only when a real gotcha bit a session — not preemptively.

_No gotchas captured yet._

### Testing

Unit tests live alongside their source (`packages/*/**.test.ts`, `apps/*/**.test.ts`). Integration tests opt in via the `*.integration.test.ts` suffix. E2E lives in `apps/web/e2e/` (or wherever your E2E surface ends up).

**Test-presence is enforced at pre-commit**: every new `.ts`/`.tsx` file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` needs a paired `*.test.ts` (or sibling exemption — see `guide/conventions.md § Test Presence`). The override file is `.devshop-test-coverage-exempt` at repo root.

### Stack

<your stack — fill in: e.g. Next.js 15 (App Router) · Turborepo + pnpm · Supabase · Vercel · Sentry · PostHog · Vitest · Playwright · GitHub Actions · ESLint + Prettier · husky + lint-staged · gitleaks · DCG>

### Env Var Naming

Per devshop convention, GitHub Secrets use the base name; each surface adds its prefix. `packages/core` does NOT read env vars — exports `createClient(config)`, each app passes prefixed vars in.

| Base name                 | Next.js (Vercel)                |
| ------------------------- | ------------------------------- |
| `SUPABASE_URL`            | `NEXT_PUBLIC_SUPABASE_URL`      |
| `SUPABASE_ANON_KEY`       | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| `SENTRY_DSN`              | `NEXT_PUBLIC_SENTRY_DSN`        |
| `NEXT_PUBLIC_POSTHOG_KEY` | `NEXT_PUBLIC_POSTHOG_KEY`       |

<add project-specific entries below, e.g. an Anthropic key split>

### Migration Workflow

```bash
supabase migration new <name>   # create migration (workspace — fs only, no docker)
pnpm db:reset                   # apply locally (relay → supabase-runner)
pnpm db:gen-types               # regen types from local stack (relay → supabase-runner)
# Migrations deploy via CI on push-to-main
# (.github/workflows/deploy-migrations.yml; project ref is sed-derived from
# the SUPABASE_PROD_URL Variable).
```

## Deploy Configuration (configured by /setup-deploy)

- Platform: <fill in>
- Production URL: <fill in>
- Deploy workflow: <fill in>
- Deploy status command: <fill in>
- Merge method: <fill in — typically squash>
- Project type: <fill in>
- Post-deploy health check: <fill in>

### Custom deploy hooks

- Pre-merge: <none, or specify>
- Deploy trigger: <e.g. automatic on push to main>
- Deploy status: <e.g. poll production URL>
- Health check: <URL>
