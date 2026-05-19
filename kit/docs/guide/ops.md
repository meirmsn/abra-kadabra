# Operations

Day-to-day operational reference. Auth, data flow, design system, CI/CD, observability, PWA — where each lives in the codebase. Env-var naming, stack inventory, local dev recipes, troubleshooting tree, and the decision log for irreversible past calls.

## Contents

- [Where Things Happen](#where-things-happen)
- [Env Var Naming Convention](#env-var-naming-convention)
- [Stack](#stack)
- [Local Development](#local-development)
- [Service Quotas](#service-quotas)
- [Dev Container](#dev-container)
- [Persistent Storage](#persistent-storage)
- [Known Footguns](#known-footguns)
- [When Things Go Wrong](#when-things-go-wrong)
- [Troubleshooting](#troubleshooting)
- [Out-of-band dashboard surfaces](#out-of-band-dashboard-surfaces)
- [Decision Log](#decision-log)

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
- Integration tests: `packages/core/**/*.integration.test.ts` (Vitest, real local Supabase reached at `host.docker.internal:54321` under the template-default compose-isolation shape, or `localhost:54321` under Host Supabase — see `local-supabase-compose-isolation.md` for which-runs-where)
- E2E tests: `apps/web/tests/` (Playwright — runs at 375px + 1440px viewports)
- Test fixtures: `supabase/seed.sql` (minimum: 1 household, 2 users in different households for RLS tests, 1 store, list entries)

### CI/CD

- **PR-time gates**: `.github/workflows/ci.yml` (lint, typecheck, test:unit, build on every push; integration + Playwright E2E + edge-fn deploy proof on PRs to main per the slow-job). The slow-job skips on docs-only diffs via a `changes:` setup-job that classifies the diff in inline bash — see `guide/conventions.md § Skip-on-docs-only filter` for shape. **Operational gotcha**: the classify step is bash `case` (pattern matching), not pathname expansion — `*` already matches `/` inside `case`, so the markdown arm is `*.md`, NOT `**/*.md`. The latter behaves like `*/*.md` and silently misses root-level files (`CLAUDE.md`, `README.md`); lalista PR #63 (2026-05-12) was the regression that surfaced this. `shopt -s globstar` does NOT change `case` behavior — don't add it back thinking it helps. The structural enforcement is `kit/tests/template-ci-yml-shape.bats` (assertions both forbid the buggy form and pin the correct one).
- **Template slow-job stub carries the canonical shape, fully baked.** The `slow:` + `changes:` jobs in `template/.github/workflows/ci.yml` ship commented out (per `guide/conventions.md § Slow-Job Lifecycle`, uncomment when the project crosses the slow-job threshold). The commented stub is the FULL canonical shape — uncomment-ritual is "strip every leading `# `", not "fill in the blanks". Five fixes are baked in so they don't have to be re-discovered per project:
  - `playwright install --with-deps chromium webkit` — `devices['iPhone N']` defaults to WebKit; chromium-only installs fail every `[mobile]` spec at browser launch (home-os PR #15).
  - Step-level `${{ env.API_URL }}` / `env.ANON_KEY` / `env.SERVICE_ROLE_KEY` mapping per test step — job-level `env:` shadows `$GITHUB_ENV` writes from `supabase status -o env`, leaving `process.env.SUPABASE_SERVICE_ROLE_KEY` empty and `adminClient()` throws "supabaseKey is required".
  - `sed -E 's/="(.*)"$/=\1/'` quote-strip before `>> $GITHUB_ENV` — `supabase status -o env` wraps every value in `"..."` literals; without stripping, GITHUB_ENV stores quotes verbatim and downstream consumers see invalid URLs.
  - Artifact upload path includes `apps/web/test-results/` (not just `playwright-report/`) — under `reporter: 'github'`, `playwright-report/` is empty; videos / traces / `error-context.md` live in `test-results/`.
  - `supabase_edge_runtime` cold-start retry (lalista PR #26) — probe `/functions/v1/` and restart once on 502 / timeout; ~30s extra in the unhappy path, zero in the happy path.
- **`push: branches: [main]`, NOT `branches-ignore: [main]`.** The inverse triggered a redundant `fast` run on every PR-branch push because `pull_request` already fires for the same event — doubled CI minutes per push without any added signal. The corrected shape keeps `push` as a post-merge canary on trunk only; pre-merge CI rides the `pull_request` event exclusively. Source: home-os PR #15 dup-runs investigation.
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

- Manifest: `apps/web/public/manifest.json` (app name, icons, theme color, `display: standalone`, explicit `scope: "/"`).
- Apple meta tags: emitted by Next's `metadata.appleWebApp` in `apps/web/app/layout.tsx`. The `apple-touch-icon` link is NOT auto-detected from `/public/apple-touch-icon.png` — declare it explicitly via `metadata.icons.apple` or place the file at `app/apple-icon.png` (Next convention). Without the link, iOS uses a screenshot for the home-screen icon.
- Viewport must include `viewportFit: 'cover'` for full-bleed on notched iOS devices — without it Safari leaves white safe-area bars that look like the browser frame is leaking through.
- **iOS input-zoom rule.** Every focusable form control (`<input>`, `<textarea>`, `<select>`) must render at font-size ≥ 16px on small screens. Below 16px, Safari zooms the viewport on focus and doesn't reliably zoom back out — looks like a layout bug after submit. Enforce in shared input primitives (e.g. `packages/ui/src/Input.tsx`), not per-call-site, and add a snapshot test pinning the floor.
- **Cross-origin redirect breaks standalone.** If a PWA is installed from origin A and A redirects to origin B (custom-domain swap, vercel preview → prod), iOS launches it in Safari chrome on next open. There is no in-app fix; users must remove the home-screen icon and re-add from the canonical origin. When swapping domains, surface this in release notes.
- Service worker caching (`@serwist/next`) deferred to `PRODUCT-ROADMAP.md` — added after core screens are stable

**See also:** [`latency-feedback.md`](./latency-feedback.md) — the iOS input-zoom rule above applies to every Tier B submit-button form; the floor pins inside shared input primitives, the framework lives in latency-feedback.

_This section grows as code is added. `/ak-implement` updates it when introducing new paths._

---

## Env Var Naming Convention

**How it works.** `packages/core/src/supabase.ts` exports `createClient({ supabaseUrl, supabaseAnonKey })` — the package never reads `process.env` itself. Each surface reads its own prefix-named vars and passes them into the same factory, so identical code runs in all three places and only the config object differs:

- **Local dev** — `compose.yml`'s workspace env-block auto-sets `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` to `host.docker.internal:54321` + the published local-stack default JWTs at every container start. `apps/web/.env.local` mirrors them as `NEXT_PUBLIC_*` for the dev server.
- **CI** — there is no separate "CI Supabase" service. `supabase/setup-cli@v1` + `supabase start` brings up the same local stack as your laptop, _inside_ the GH Actions runner. The slow-job pipes the just-spun-up stack's keys into the workflow env via `supabase status -o env >> $GITHUB_ENV` (resolves `API_URL` / `ANON_KEY` / `SERVICE_ROLE_KEY`), then downstream steps plumb those into `NEXT_PUBLIC_SUPABASE_URL` / `SUPABASE_URL` for the build and integration tests. The fast-job's GH-Variable values (`http://127.0.0.1:54321` + default JWT) are compile-time placeholders only — fast-job tests mock the network.
- **Production** — Vercel env (`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY`) points at the prod project. Migrations + edge functions deploy via separate workflows that sed-derive the project ref from the `SUPABASE_PROD_URL` GH Variable.

Don't reuse a value across surfaces without checking which side you're on — the same name carries different values per surface. The table below is the lookup index.

| Base name                   | GH Variable (CI)                 | Vercel (`apps/web`)                                                          | What it actually is on each side                                                                                                               |
| --------------------------- | -------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `SUPABASE_URL`              | `http://127.0.0.1:54321`         | `NEXT_PUBLIC_SUPABASE_URL` = prod URL                                        | GH = local-stack; Vercel = prod. Front-end runtime needs prod; CI tests don't.                                                                 |
| `SUPABASE_ANON_KEY`         | published local-stack JWT        | `NEXT_PUBLIC_SUPABASE_ANON_KEY` = prod anon                                  | GH = published default; Vercel = prod. Public on both sides.                                                                                   |
| `SUPABASE_SERVICE_ROLE_KEY` | published local-stack JWT        | _(not on Vercel — server-side)_                                              | Prod service-role NEVER reaches CI. The local-stack default is admin on a sandbox the runner spins up fresh.                                   |
| `SUPABASE_PROD_URL`         | prod URL (deploy workflows only) | _(piped from `.devcontainer/.env` to `NEXT_PUBLIC_SUPABASE_URL` at Step 13)_ | The single source of truth for "where does this push go?" — `deploy-{migrations,functions}.yml` sed-derive the project ref from this Variable. |
| `SENTRY_DSN`                | _(GH Secret)_                    | `NEXT_PUBLIC_SENTRY_DSN`                                                     | Same value on both sides.                                                                                                                      |
| `NEXT_PUBLIC_POSTHOG_KEY`   | `NEXT_PUBLIC_POSTHOG_KEY`        | `NEXT_PUBLIC_POSTHOG_KEY`                                                    | Same value on both sides.                                                                                                                      |

The `createClient` factory wraps `assertNotProdUrlInTestEnv` as a runtime backstop — throws if a `NODE_ENV=test` caller ever passes the prod URL, so a misconfigured CI Secret can't silently dial prod. See `guide/security.md § CI Credential Isolation` for the structural-defense rationale; `/ak-new-project § Security Posture` for the blast-radius table; `/ak-new-project § Migration: existing project to current credential layout` for the cleanup recipe.

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

The template ships **compose isolation by default** — workspace dev container has no docker socket; the sibling `supabase-runner` compose service holds the socket and runs `supabase start` against the host engine. `/ak-new-project` Step 2b lets the operator pick a different local-supabase reachability shape per project. Architecture + lifecycle table + smoke tests + debugging tree: [`local-supabase-compose-isolation.md`](./local-supabase-compose-isolation.md). Threat model + decision matrix: [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md).

### Compose isolation (default)

Workspace + supabase-runner sibling. The workspace drives the local stack via `pnpm db:*` wrappers that call the runner's whitelisted RPC relay on `supabase-runner:9000`:

```bash
pnpm turbo run dev          # start Next.js dev server
pnpm db:start               # spawn local Supabase via runner relay
pnpm db:status              # local API URL + anon/service-role keys
pnpm test:integration       # integration tests against the running local stack
pnpm db:stop                # tear down (host docker engine reclaims sibling container resources)
```

`SUPABASE_URL` + `SUPABASE_ANON_KEY` + `SUPABASE_SERVICE_ROLE_KEY` are auto-set on every workspace start by `compose.yml` (env-block on the workspace service), pointing at `host.docker.internal:54321` + the published local-stack default JWTs — so vitest / supabase-js scripts / integration tests work without any manual env-prefix.

### Host Supabase (supabase CLI on macOS host)

Workspace has no docker access; supabase runs natively on macOS. `pnpm db:*` scripts don't apply (relay isn't installed under this option). From a macOS host terminal:

```bash
supabase start     # starts Postgres, Auth, Realtime containers (~45s first time)
supabase status    # local API URL + anon key
```

Workspace processes reach the host stack via `host.docker.internal:54321`. Same `/etc/hosts` entry applies as for compose isolation.

### Skip — no local Supabase

Integration tests (`*.integration.test.ts`) run in CI's slow job only. Local feedback is unit tests:

```bash
pnpm turbo run dev          # start Next.js dev server (dials Vercel-piped prod for SSR data)
pnpm turbo run test:unit    # fast inner loop — no DB needed
```

Push a PR to run integration tests in CI.

### Local Supabase — manual ad-hoc QA flow

`/ak-pre-ship` Phase 0 automates the bring-up via `preship/supabase-bootstrap.sh`. The script auto-detects the project's reachability shape (compose-isolation / docker-bind / Host Supabase) and routes lifecycle accordingly: under compose isolation it `curl -fsS -X POST $RELAY_URL/start`s the cmd-relay (same mechanism `pnpm db:start` uses); under Host Supabase it just verifies the host-running stack is reachable + rewrites `.env.local` (lifecycle stays on the macOS host); under docker-bind (legacy) it shells out to `supabase start`. Either way the data plane lands on `http://host.docker.internal:54321` (compose isolation / Host Supabase) or `http://localhost:54321` (docker-bind, host-bound).

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

### Compose isolation — workspace + supabase-runner sibling

The template default is two-container compose isolation. The workspace dev container has NO docker access (no socket bind-mount, no docker CLI installed). A sibling `supabase-runner` compose service holds `/var/run/docker.sock` and runs `supabase start` against the host engine; the spawned supabase containers (`supabase_db_<project>`, `supabase_kong_<project>`, …) are siblings of the runner on the HOST docker engine, NOT nested. The runner exposes a whitelisted RPC relay on `:9000` so the workspace can drive supabase lifecycle commands (`start`, `stop`, `status`, `db reset`, `gen types`) without docker access. `pnpm db:*` scripts curl the relay.

The workspace + macOS browser reach the supabase data plane via `host.docker.internal:54321 / :54322` (Docker Desktop maps `host.docker.internal` to the host gateway from any container; the operator adds `127.0.0.1 host.docker.internal` to `/etc/hosts` so the browser resolves it too). `init-firewall.sh` includes the host.docker.internal allow rule using `getent ahostsv4` to force IPv4 (iptables is IPv4-only; Docker Desktop's resolution can flip to IPv6 between restarts).

**Port rebinding (concurrent projects).** Projects running concurrently on the same host (e.g. lalista on default `54321/54322` + home-os on `54421/54422`) avoid port collisions by setting `SUPABASE_API_PORT` + `SUPABASE_DB_PORT` in `.devcontainer/.env`. `init-firewall.sh` reads `.env` directly (the script runs as root via sudo in `postStartCommand`; sudo strips env vars by default so reading the file rather than relying on inherited environment is self-contained), validates each port is numeric and in `1..65535`, and uses the resolved values for the `iptables --dport` ACCEPT rules. Missing or unset vars fall back to the upstream Supabase defaults (`54321` REST/kong + `54322` Postgres). Non-numeric or out-of-range values exit the script non-zero with a clear error naming the bad variable — no silent EHOSTUNREACH. The same `.env` flows into compose's `env_file` for the workspace service, so the supabase-runner's lifecycle commands target the same ports without manual coordination.

Earlier devshop generations shipped two precursor shapes that are no longer offered (both rejected because the workspace had docker access, which broke the macOS-home blast-radius isolation):

- **Host docker socket bind-mount, single container** (the threat model's Option 2) — devcontainer held `/var/run/docker.sock`, container shipped docker CLI + `init-docker-socket.sh` postStart script that aligned the in-container `docker` group's GID with the host socket's GID.
- **`docker-in-docker:2` feature** — inert without `--privileged`, silently routed `/ak-pre-ship` Gate 9 to admin-API-against-hosted-prod.

Both have been superseded; compose isolation is the default and Host Supabase is the alternative for operators who prefer host-side supabase tooling. `/ak-new-project § Step 2b` lets a project pick Host Supabase, compose isolation (default), or skip (no local stack). Architecture + decision matrix: [`local-supabase-compose-isolation.md`](./local-supabase-compose-isolation.md) + [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md). `kit/scripts/preship/supabase-bootstrap.sh up` reports `blocked` (refusing the hosted fallback) when the local stack isn't reachable.

**Why "compose isolation is the template default" doesn't conflict with the threat model recommending Host Supabase**: these are two different axes, not a contradiction.

- **Template default = compose isolation**: zero-friction first-run (no macOS-side `brew install supabase/tap/supabase`; `pnpm db:start` and you have a local stack). Optimizes for the common case where an operator scaffolds a project and wants integration tests working immediately.
- **Threat-model default-recommendation = Host Supabase (Option 1)**: stronger blast-radius isolation for operators whose `~/dev/` parent contains multiple project families. Under Host Supabase the workspace has zero docker surface (no socket, no narrow bind, no relay). Under compose isolation the workspace also has zero docker surface, BUT the sibling supabase-runner has the docker socket + a narrow `<host>/supabase` bind — a marginally larger attack surface than Host Supabase, even though both options block the macOS-home read that motivated the rejection of the host-docker-socket-bind-mount shape.

For single-project-family operators, compose isolation is a clean ergonomics win. For multi-project-family operators, the threat-model recommends Host Supabase for the marginal-extra-isolation. `/ak-new-project § Step 2b` exposes both at scaffold time; the operator picks per their profile.

Debugging compose isolation ("which container am I in", "is the relay reachable", "did supabase start fail"): see [`local-supabase-compose-isolation.md § Debugging tree`](./local-supabase-compose-isolation.md).

### gstack runtime state

`containerEnv` in `template/.devcontainer/devcontainer.json` sets BOTH `GSTACK_HOME` and `GSTACK_STATE_DIR` to `/workspace/.gstack` — gstack has a split-brain where its CLI binaries (e.g. `gstack-config`) honor `GSTACK_STATE_DIR` while SKILL.md preamble bash blocks honor `GSTACK_HOME`. Setting both ensures `projects/`, `sessions/`, `analytics/`, and `learnings.jsonl` all land under the workspace alongside `config.yaml` instead of split across `$HOME` and the project tree. `template/.gitignore` ships `.gstack/*` with explicit re-includes for `.gstack/projects/**/*.md` so design docs, office-hours plans, and eng-review history stay version-tracked while runtime state, logs, analytics, and `config.yaml` (which gstack rewrites on every run) are filtered out. Don't blanket-ignore `.gstack/` without the re-include pattern — that loses the plans.

---

## Persistent Storage

Two Docker named volumes survive container rebuilds:

- `/commandhistory` — shell history (bash/zsh)
- `/home/node/.claude` — Claude Code config, sessions, and API key

These volumes are **not** on the host filesystem and are **lost on machine migration**.

---

## Known Footguns

- **Firewall IP rotation**: CDN domains rotate IPs throughout the day; `init-firewall.sh` resolves them once at container start, so the cached `ipset` goes stale within hours. Most common bite: post-deploy `EHOSTUNREACH` to your prod URL.

  **Recovery for the prod URL specifically**: `sudo /usr/local/bin/refresh-allowed-ips.sh` — re-resolves the project's `PRODUCTION_URL` and `ipset add`s fresh IPs without flushing or restarting the container. Additive only; safe mid-session.

  **Setup**: operator sets `PRODUCTION_URL=your-app.com` (bare hostname; no scheme/path/port) in `.devcontainer/.env` and rebuilds the container. At each container start, `init-firewall.sh` invokes the boot-only `init-prod-url.sh` which validates the `.env` value and writes it to `/etc/refresh-allowed-ips/production_url` (overlay-fs, root-only — kernel-enforced). `refresh-allowed-ips.sh` reads from the locked file at runtime.

  **Why two files**: `.devcontainer/.env` sits on Docker Desktop's `fakeowner` virtiofs where root-ownership is advisory — a compromised npm dep can rewrite it despite its 644 root-owned mode. `/etc` is overlay-fs where the kernel enforces perms, so the locked file is genuinely tamper-resistant. `init-prod-url.sh` deliberately has NO NOPASSWD sudoers entry — it only fires from `init-firewall.sh`'s root context at container start. Mid-session edits to `.env` take effect on next container rebuild — by design.

  **Format divergence**: same name as the GitHub Variable `PRODUCTION_URL` (used by `keepalive.yml`) but format differs — the GH Variable holds `https://your-app.com`, the `.env` value is just `your-app.com`. Empty/unset → script no-ops.

  **For project-specific allowlist additions** (additional Supabase project URLs, Sentry org ingest, PostHog region, Vercel app URL — anything beyond the static template list in `init-firewall.sh`): the canonical edit target is `.devcontainer/firewall-extra-domains` — a `[scaffold-once]` operator-editable overlay file (one bare hostname per line; lines with `#` or empty are skipped; strict DNS-label regex validates each line at runtime, malformed entries warn-and-skip into the SKIPPED_DOMAINS banner). Seeded from `template/.devcontainer/firewall-extra-domains` by `init-devshop.sh` if missing, then chowned `root:root 644` on every container start so node (Claude / npm) cannot tamper. Edit via `sudo nano /workspace/.devcontainer/firewall-extra-domains`; additions take effect on next rebuild. See `guide/architecture.md § File lifecycle § Hybrid lifecycle` for the mechanism.

  **For rotating CDN entries** (`fonts.gstatic.com`, etc.): rebuilding the container is still the path until the refresh script's domain list is generalized. Chromium is exempt — apt-installed by the template `Dockerfile` so Playwright never reaches its CDN.

  **In-session shortcut without rebuild** (additive, no flush — same mechanism as `refresh-allowed-ips.sh`): `dig +short A <hostname> | while read ip; do sudo ipset add allowed-domains "$ip" 2>/dev/null || true; done`. Effective until next container restart; persist by editing `firewall-extra-domains` and rebuilding.

  **Don't re-run `sudo /usr/local/bin/init-firewall.sh` mid-session.** Observed twice (2026-04-20, lalista PR 2 close-out) to stall the Claude session; container rebuild was the only recovery. The observation pre-dates both `refresh-allowed-ips.sh` (2026-05-09) and the tolerant-DNS update (`e2f441f`, 2026-05-02), so the original triggering use-case (refresh stale prod-URL IPs) no longer applies. The hypothesized mechanism — conntrack invalidation from the boot-time `iptables -F` + `iptables -t mangle -F` + `ipset destroy allowed-domains` sequence dropping the session's in-flight API connection — is unverified post-fix but the relevant code path is unchanged, so the risk plausibly remains. Both current refresh use-cases (prod URL → `refresh-allowed-ips.sh`; project-specific domains → `firewall-extra-domains` overlay + the `ipset add` shortcut above) are additive-only and safe — there's no current reason to invoke `init-firewall.sh` mid-session, so the unverified-but-unchanged-mechanism risk doesn't have to be tested. Tracked in `kit/TODOS.md` (proper fix proposal: connection-preserving atomic ipset swap).

  Scripts ship from `template/.devcontainer/{refresh-allowed-ips,init-prod-url}.sh` as `[locked]` manifest entries. Inherited by every new project as a `template/CLAUDE.md § Gotchas` entry.

- **GH Actions artifact access on pre-2026-04-24 projects**: projects scaffolded from the template before 2026-04-24 don't have `productionresultssa*.blob.core.windows.net` (Azure Blob storage where GH Actions stashes workflow artifacts — Playwright traces, screenshots, coverage reports) in their `.devcontainer/init-firewall.sh`. Symptom: `gh run download` from inside the devcontainer fails with `no route to host`, not an IP-rotation stale-ipset problem — the host is absent from the allowlist entirely. Fix: diff the project's `.devcontainer/init-firewall.sh` against `/devshop/template/.devcontainer/init-firewall.sh` and bring in the artifact-host loop (insert after the existing project-domain `for domain in ... ; do ... done` block). The artifact-host loop reuses `$gh_ranges` which the script already fetches for GitHub CIDR resolution — no additional setup needed if the project's script still has the standard CIDR fetch section. Then rebuild the devcontainer. Projects scaffolded on or after 2026-04-24 inherit this from the template. Required for `/ak-build` Phase 5.4 artifact-pull on attempt #2.
- **Never commit directly to main**: branch protection requires PRs. Always create a feature branch first, even for small fixes.
- **Workflow push requires human**: the devcontainer PAT lacks `workflow` scope intentionally. If `git push` fails because a commit touches `.github/workflows/`, ask the human to push: `git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>` (GitHub will prompt for their PAT with workflow scope).
- **PostgREST null-deref masks column typos**: a Playwright/integration test that crashes with `TypeError: Cannot read properties of null (reading '<field>')` after a recent `.select()` change is almost always a column-name typo (or a stale generated-types cast), not a missing-data bug. PostgREST returns `data: null` + populated `error` on a non-existent column; downstream code that destructures `data` swallows the diagnostic. Re-read the `.select()` call against the current schema before chasing null-handling. Convention: `kit/docs/guide/database-queries.md`. Inherited by every new project as a `template/CLAUDE.md § Gotchas` entry.
- **Vercel env-var limit is 4096 bytes per variable** (per the Vercel dashboard's enforcement; not in their public docs in 2025-2026 but consistently reproducible). Matters for any operator-tunable env var that holds prose — system prompts, copy templates, base64-encoded config blobs. Common failing pattern: an operator-tunable prompt env (`TRIAGE_SYSTEM_PROMPT`, `FOO_PROMPT_OVERRIDE`) grows past 4096 bytes during iteration and the Vercel dashboard silently rejects the save (or truncates depending on the UI path), leading to a "the prompt env is set but the deploy uses the default" mystery. **Recipe**: pin a runtime cap below the Vercel cap. The `home-os` apps/web pattern is `PROMPT_MAX_CHARS = 3500` constant declared next to the resolver (`apps/web/app/api/triage/_lib/prompt.ts`), with a paired unit test asserting the default prompt + any test-supplied long prompt are both within the cap. 3500 chars leaves headroom for trailing whitespace / encoding overhead under the 4096-byte cap. Apply to every operator-tunable prompt env var; the test catches regressions before deploy. Inherited by every new project that adds a `_PROMPT` env var as a `template/CLAUDE.md § Gotchas` entry.

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

Free-tier Supabase has no point-in-time recovery. Pre-migration `pg_dump` will be automated in Phase 1c — runs before applying new migrations, stored as GitHub Actions artifact. For weekly backups beyond deploys, see `kit/ROADMAP.md` v1. Always test schema changes against the local Supabase stack before deploying — `pnpm db:reset` under compose isolation (template default), or `supabase db reset` from the macOS host terminal under Host Supabase.

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

**Symptom**: `postStartCommand from devcontainer.json failed with exit code 1` and the log shows `init-devshop.sh FAILED at line 21 (exit 1):   ROOT_PASSWORD=$(grep '^DEVCONTAINER_ROOT_PASSWORD=' "$WS/.devcontainer/.env" | cut -d= -f2)` (or similar from the password-setup block).
**Cause**: `.devcontainer/.env` exists but doesn't contain a `DEVCONTAINER_ROOT_PASSWORD=` line. Under `set -euo pipefail` the `grep` returns 1 and the pipeline aborts before the devshop-self guard runs.
**Fix**: From v1.29+ this is non-fatal — the password block prints a yellow `⚠ DEVCONTAINER_ROOT_PASSWORD not set ...` advisory and degrades to the Dockerfile default (node has NOPASSWD only on `init-firewall.sh` and `init-devshop.sh`). To restore full `sudo nano`-style access, add `DEVCONTAINER_ROOT_PASSWORD=<pick-something>` to `.devcontainer/.env` and rebuild (or `sudo /usr/local/bin/init-devshop.sh`). On older versions, the same `.env` edit is the unblock.

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

### Browse daemon binary drift (separate concern)

When the workspace's bundled `browse` binary drifts from the current Bun runtime (e.g., after a Bun upgrade in the devcontainer base image), the daemon may fail to launch entirely — distinct from the Chromium symlink path issue above.

**Fix**: `/devshop/kit/scripts/rebuild-browse.sh [TARGET_PROJECT_ROOT]` rebuilds `browse` + `find-browse` binaries and the Node server bundle from `/devshop/.claude/skills/gstack/browse/src/`, copies them into the project's `.claude/skills/gstack/browse/dist/`. Works around virtiofs by building in `/tmp`. As of 2026-04-27 the CLI also falls back to the bundled `server-node.mjs` (Node) when the source tree (`server.ts`, Bun) isn't shipped — so once the binaries are rebuilt against current source, the workspace install no longer needs the devshop source mounted at runtime. Run after a Bun upgrade or whenever `.claude/skills/gstack/browse/dist/.version` is older than `git -C /devshop/.claude/skills/gstack rev-parse HEAD`.

### Playwright cache population (separate concern)

When Playwright's launch path can't find a Chromium executable in `~/.cache/ms-playwright/` even with `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` set (e.g., on older project devcontainers without the post-2026-04-23 apt-baked Chromium fix):

**Fix**: `/devshop/kit/scripts/populate-playwright-cache.sh [TARGET_PROJECT_ROOT]` discovers each `playwright-core/browsers.json` revision under the project + devshop and symlinks `~/.cache/ms-playwright/chromium-<rev>/chrome-linux/{chrome,headless_shell}` → `$PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` (defaults to `/usr/bin/chromium`). Idempotent. Avoids hitting Playwright's CDN, which is intentionally firewall-blocked.

New scaffolds (post-2026-04-23) inherit the apt-baked Chromium and the structural CLI fix; older projects need both scripts run once after a `from-devshop.sh` sync. Strategic fix history (verifiable preflight check in `/ak-pre-ship`, env-var fallback in `browse/src/cli.ts`, migration recipe) is recorded in `BUILD-LOG.md` and the relevant skill / convention docs at HEAD.

---

## Out-of-band dashboard surfaces

CI deploys the app, the database migrations, and the edge functions on push:main (per `conventions.md § Deploy Boundaries`). Several adjacent surfaces do NOT auto-deploy and need manual dashboard work — failing to do so means "the PR shipped but the user-facing change is invisible":

| Surface                                       | Where it lives                                            | When it ships                                                                                                          |
| --------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Custom domain + DNS                           | Vercel project → Domains; A/AAAA + CNAME at the registrar | Manual, once per domain                                                                                                |
| Transactional email provider                  | Provider's dashboard (Resend, Postmark, etc.) + SPF/DKIM  | Manual, once per project; rotate on provider switch                                                                    |
| Supabase Auth → SMTP Settings                 | Supabase dashboard → Auth → SMTP                          | Manual paste; never deploys from CI                                                                                    |
| Supabase Auth → Templates                     | Supabase dashboard → Auth → Templates (per-template tab)  | Manual paste; `supabase/templates/*.html` in the repo is the source of truth but does NOT auto-deploy                  |
| Supabase Auth → URL Configuration             | Supabase dashboard → Auth → URL Configuration             | Manual; covers the redirect allow-list for `emailRedirectTo`                                                           |
| Supabase Auth → Password Changed notification | Supabase dashboard → Auth → Templates → Password Changed  | Manual paste; the `[auth.email.notification.password_changed]` block in `supabase/config.toml` enables it locally only |

When a PR edits any of `supabase/templates/*.html`, `supabase/config.toml`'s auth/email blocks, or introduces a new redirect URL, the PR description MUST include the dashboard-paste step in the test plan. `/ak-go-live` does not handle out-of-band surfaces.

The `[auth.email.smtp]` block in `supabase/config.toml` is typically kept commented intentionally so local-dev mail flows to a sandbox (mailpit) instead of burning the provider's free tier — toggling it on locally costs real sends.

---

## Decision Log

_Short entries: "chose X over Y because Z, date" — extracted from reviews and retros._
