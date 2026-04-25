# Operations

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

- **PR-time gates**: `.github/workflows/ci.yml` (lint, typecheck, test:unit, build on every push; integration + Playwright E2E + edge-fn deploy proof on PRs to main per the slow-job)
- **Push:main auto-deploy** (post-merge):
  - `.github/workflows/deploy-migrations.yml` — path-filtered to `supabase/migrations/**`; runs `supabase db push --include-roles` against the linked project. Concurrency-grouped so back-to-back merges serialize.
  - `.github/workflows/deploy-functions.yml` — path-filtered to `supabase/functions/**`; deploys every non-underscore-prefixed function dir via the management API.
  - Vercel auto-deploys the Next.js app via its own webhook on push:main. All three surfaces (migrations, functions, app) fire in parallel — see `guide/conventions.md § Deploy Boundaries` for the backwards-compatibility constraints that follow from the parallel-deploy race.
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

### Local Supabase — manual workflow for QA / ad-hoc testing

`/ak-pre-ship` Phase 0 automates this via `preship/supabase-bootstrap.sh` (Fix A) when Docker-in-Docker is available. For manual use outside pre-ship, or when DinD is inert:

```bash
supabase start     # starts Postgres, Auth, Realtime containers (~45s first time)
supabase status    # prints local API URL + anon key
```

Temporarily point `apps/web/.env.local` at local (back up the hosted values first — the file is gitignored either way):

```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
NEXT_PUBLIC_POSTHOG_KEY=<keep hosted>
NEXT_PUBLIC_SENTRY_DSN=<keep hosted>
```

Restart the dev server to pick up the new env. Use seeded test accounts for sign-in — project `seed.sql` inserts directly into `auth.users` bypassing the email validator, so `.test.local` TLDs work (e.g. `alice@test.local` / `password123` if the project follows the template seed pattern). Freshly-created users via the UI use `@example.com` (RFC 2606 reserved TLD).

When done: revert `.env.local` to hosted, run `supabase stop`.

### Hero screenshot — manual capture

`/ak-pre-ship` end-of-run captures hero shots automatically. For ad-hoc captures between gates (e.g., documenting a design iteration), use the gstack `browse` daemon directly:

```bash
cd /workspace/.claude/skills/gstack/browse/dist && ./browse status   # ensure daemon is up

./browse goto http://localhost:3000/sign-in
./browse screenshot /workspace/specs/<feature>/hero/signin.png --full-page
```

For dark-mode captures when the app hasn't yet wired a theme bootstrap (CSS vars respond to `.dark` on `<html>`):

```bash
./browse exec "document.documentElement.classList.add('dark')"
./browse screenshot /workspace/specs/<feature>/hero/signin-dark.png --full-page
```

Put shots under `specs/<feature>/hero/` (committed per `guide/conventions.md § Screenshot Routing`).

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

## Dev Container

The dev container is defined in `.devcontainer/` and requires:

1. API keys and credentials placed in `.devcontainer/.env`
2. Opening in VS Code and selecting **Reopen in Container**

The container runs as the `node` user (non-root). On every start, `init-firewall.sh` runs with sudo to lock down outbound network access before VS Code connects. The firewall uses `iptables` + `ipset` to allowlist outbound traffic — everything else is rejected.

---

## Persistent Storage

Two Docker named volumes survive container rebuilds:

- `/commandhistory` — shell history (bash/zsh)
- `/home/node/.claude` — Claude Code config, sessions, and API key

These volumes are **not** on the host filesystem and are **lost on machine migration**.

---

## Known Footguns

- **Firewall IP rotation**: CDN domains like `fonts.gstatic.com` rotate IPs. Firewall resolves at container start. If a build fails on a network error for an allowed domain hours later, restart the container to re-resolve.
- **GH Actions artifact access on pre-2026-04-24 projects**: projects scaffolded from the template before 2026-04-24 don't have `productionresultssa*.blob.core.windows.net` (Azure Blob storage where GH Actions stashes workflow artifacts — Playwright traces, screenshots, coverage reports) in their `.devcontainer/init-firewall.sh`. Symptom: `gh run download` from inside the devcontainer fails with `no route to host`, not an IP-rotation stale-ipset problem — the host is absent from the allowlist entirely. Fix: diff the project's `.devcontainer/init-firewall.sh` against `/devshop/template/.devcontainer/init-firewall.sh` and bring in the artifact-host loop (insert after the existing project-domain `for domain in ... ; do ... done` block). The artifact-host loop reuses `$gh_ranges` which the script already fetches for GitHub CIDR resolution — no additional setup needed if the project's script still has the standard CIDR fetch section. Then rebuild the devcontainer. Projects scaffolded on or after 2026-04-24 inherit this from the template. Blocks `/ak-build` Phase 5.4's trace-pull-on-second-failure convention until fixed.
- **Never commit directly to main**: branch protection requires PRs. Always create a feature branch first, even for small fixes.
- **Workflow push requires human**: the devcontainer PAT lacks `workflow` scope intentionally. If `git push` fails because a commit touches `.github/workflows/`, ask the human to push: `git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>` (GitHub will prompt for their PAT with workflow scope).

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

Free-tier Supabase has no point-in-time recovery. Pre-migration `pg_dump` will be automated in Phase 1c — runs before applying new migrations, stored as GitHub Actions artifact. For weekly backups beyond deploys, see `kit/ROADMAP.md` v1. Always test schema changes against `supabase start` locally before deploying.

---

## Troubleshooting

_Grows as issues are encountered. Add entries with date, symptom, cause, fix._

### init-devshop.sh failures (2026-04-12)

**Symptom**: Container start fails with exit code 126 or "Permission denied"
**Cause**: macOS bind mount doesn't preserve execute permission on `/devshop/`
**Fix**: The thin forwarder must use `exec bash /devshop/...` not `exec /devshop/...`

**Symptom**: Container starts but no devshop skills/settings
**Check**: `ls -la /workspace/.devshopkit` — should be a symlink to `/devshop/kit/`
**Check**: `ls /workspace/.claude/skills/ | wc -l` — should be ~38
**Check**: `cat /workspace/CLAUDE.md | head -5` — should show project-specific content

**Symptom**: `git status` shows devshop files as untracked
**Check**: `.gitignore` must have `.devshopkit` and `.claude` (no trailing `/` — symlinks need pattern without slash)

**Symptom**: Can't sudo inside container
**Cause**: init-devshop.sh didn't run (password setup is in that script)
**Fix**: Run `sudo /usr/local/bin/init-devshop.sh` (NOPASSWD rule covers this path). If that also fails, the thin forwarder may be broken — check `/workspace/.devcontainer/init-devshop.sh` content.

### Chromium symlink autoheal (2026-04-20)

**Symptom**: `/ak-pre-ship` gates that use the gstack `browse` daemon fail with `Executable doesn't exist at .../chromium-1208/chrome-linux/chrome` (or similar version number).

**Cause**: The compiled `browse` daemon is pinned to a specific Playwright Chromium version directory (e.g. `chromium-1208`). Playwright may install a newer version (`chromium-1217`, etc.) when the devcontainer is rebuilt — the pinned path goes stale.

**Fix**: `/ak-pre-ship` Phase 0 creates the symlink automatically. If you invoke `browse` outside pre-ship and hit this, run:

```bash
LATEST=$(ls -d /home/node/.cache/ms-playwright/chromium-* | grep -v headless_shell | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium-1208 ] && ln -sf "$LATEST" /home/node/.cache/ms-playwright/chromium-1208
LATEST_HS=$(ls -d /home/node/.cache/ms-playwright/chromium_headless_shell-* | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium_headless_shell-1208 ] && ln -sf "$LATEST_HS" /home/node/.cache/ms-playwright/chromium_headless_shell-1208
```

**Upstream resolution** (tracked in `kit/TODOS.md`): the `browse` daemon should autodetect the highest-version dir under `~/.cache/ms-playwright/` instead of hard-coding a version. When that ships, drop the symlink workaround.

**Root cause fix** (shipped 2026-04-23): the template Dockerfile now apt-installs `chromium + chromium-driver` and `template/.devcontainer/devcontainer.json` sets `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` in `containerEnv`. Eliminates the Playwright-CDN firewall-stale-ipset problem entirely. **Note**: this fixes the _download_ layer but does not by itself fix the daemon's pinned-version path lookup — the symlink autoheal above is still required because the compiled `browse` binary expects `/home/node/.cache/ms-playwright/chromium-1208/chrome-linux/chrome` regardless of `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`. Until the daemon is updated to autodetect the highest-version dir (or honor the env var), pre-ship's symlink workaround creates `chromium-1208` pointing at the apt-installed binary's location.

---

## Decision Log

_Short entries: "chose X over Y because Z, date" — extracted from reviews and retros._
