---
name: init
version: 2.0.0
description: |
  Guided new-project setup walkthrough. Contains the full step-by-step instructions
  for initializing a project — prerequisites, scaffolding, integrations, security,
  and verification. Reads the checklist from .devshop/GUIDE.md for ordering and
  resume tracking (checkboxes), but owns the execution detail.
  Use when asked to "init", "initialize project", "new project setup". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
---

# Init

Guided walkthrough for setting up a new project. Not an automation wizard — a guided
checklist that handles what it can and asks the user for what it can't.

> **Maintenance note**: This file and `.devshop/GUIDE.md § Starting a New Project`
> are companions. The GUIDE.md checklist is the compact summary with checkboxes for
> resume tracking. This file has the execution detail. Update both when changing the
> init process.

## Step 1: Read the checklist

Read the "Starting a New Project" section from `.devshop/GUIDE.md` — the `- [ ]` items.
Use the checklist for ordering and resume tracking. Use this file for execution detail.

## Step 2: Walk through items

For each checklist item, in order, follow the detailed instructions below.

**IMPORTANT: After completing EVERY item (automated or [HUMAN]), immediately mark it
`- [x]` in `.devshop/GUIDE.md` before moving to the next item. This is the resume
mechanism — an unchecked item means it hasn't been done.**

**ONE STEP AT A TIME. Present a single step, wait for completion, then move to the
next. Never batch or group multiple steps — even if several consecutive steps are
all [HUMAN]. The user needs the chance to ask questions on each step.**

**DEPTH OVER SPEED. The checklist serves the work, not the other way around. When
a step hits friction (missing permissions, unexpected URLs, unclear docs), stop and
think about what consequences this has — a wrong URL means deploys fail, a missing
permission means /ship breaks, an undocumented gotcha means the next session wastes
time debugging it. Solve the problem, update the skill so the next project doesn't
hit it, and only move on when the step is genuinely done well.**

### On [HUMAN] items

- Show what the user needs to do (clear instructions, links where helpful)
- Wait for the user to say "done" or provide the requested value
- Do NOT present the next step until the current one is confirmed done
- Mark `- [x]` in .devshop/GUIDE.md

### On automated items

- Run the command/action per the detail below
- Verify success (check exit code, verify file exists, etc.)
- Mark `- [x]` in .devshop/GUIDE.md

### On failure

- Stop
- Show the error clearly
- Ask: retry / skip / abort

---

## Detailed Step Instructions

Ask the user for the project name before starting (used as `<project-name>` throughout).
Derive the npm scope: `@<project-name>`.

### Step 1: Check binary versions

Check if devshop tooling is current:

1. Read `devcontainer.json` build args for binary versions (git-delta, supabase-cli, DCG, gitleaks)
2. Read `.devcontainer/checksums.sha256` for current checksums
3. For each binary, compare against the latest release:
   - `gh api repos/dandavison/delta/releases/latest --jq .tag_name`
   - `gh api repos/supabase/cli/releases/latest --jq .tag_name`
   - `gh api repos/Dicklesworthstone/destructive_command_guard/releases/latest --jq .tag_name`
   - `gh api repos/gitleaks/gitleaks/releases/latest --jq .tag_name`
4. If newer versions are available: tell the user which ones, confirm whether to upgrade.
   Guide them to the release page for each binary to obtain the new checksum.
5. If all current: confirm and continue.

### Step 2: Seed PRODUCT-ROADMAP.md and BUILD-LOG.md

Check if `PRODUCT-ROADMAP.md` exists in the project root:

- **Exists**: ask the user if they want to merge the template items from `.devshop/templates/PRODUCT-ROADMAP.md.tmpl` or keep their existing file as-is.
- **Does not exist**: ask the user if they have a product roadmap elsewhere. If yes, let them point to it. If no, copy `.devshop/templates/PRODUCT-ROADMAP.md.tmpl` to `PRODUCT-ROADMAP.md` at the root as the starting point.

Never overwrite an existing `PRODUCT-ROADMAP.md` without confirmation.

Check if `BUILD-LOG.md` exists in the project root:

- **Does not exist**: copy `.devshop/templates/BUILD-LOG.md.tmpl` to `BUILD-LOG.md` at the root.
- **Exists**: keep as-is.

### Step 3: [HUMAN] Create accounts

- **Vercel**: create account at vercel.com, install the Vercel GitHub App (enables auto-deploy
  and preview URLs on PRs). Do NOT import the repo yet — import happens in Step 13 after
  `apps/web` is scaffolded (importing now would fail with no app to build).
- **Sentry**: create account at sentry.io, create a project (platform: React, slug: `<project-name>`)
- **PostHog**: create account at posthog.com, create a project (name: `<project-name>`)
- **Supabase** (if using): project should already exist.
- **Apple Developer** (if using Sign in with Apple): enroll at developer.apple.com ($99/yr,
  approval takes 1-2 days). Create a Service ID and register your domain once approved.

> **Reminder**: Enable MFA on each new account before proceeding.

### Step 4: [HUMAN] Fill credentials file

Fill `.devcontainer/.env` (already gitignored, read-protected by `.claude/settings.json`):

```
# Devcontainer
DEVCONTAINER_ROOT_PASSWORD=<pick-something>

# GitHub
GITHUB_TOKEN=<fine-grained-pat>

# Vercel
VERCEL_TOKEN=<personal-access-token>

# Supabase (if using)
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<publishable-key>
SUPABASE_SERVICE_ROLE_KEY=<secret-key>
SUPABASE_ACCESS_TOKEN=<personal-access-token>

# Sentry
SENTRY_DSN=https://<key>@o<org-id>.ingest.sentry.io/<project-id>
SENTRY_AUTH_TOKEN=<auth-token>

# PostHog
NEXT_PUBLIC_POSTHOG_KEY=<project-api-key>
```

Where to find each:

- Devcontainer root password: pick any password. Enables `sudo` for the human
  operator. Read by `init-devshop.sh` on container start — Claude cannot access
  this value (`.env` is read-denied in settings.json).
- GitHub PAT: github.com/settings/tokens → Fine-grained tokens → Generate new token.
  Scope to this repo only. Required permissions:
  - `Contents: Read and write` — push branches and commits
  - `Pull requests: Read and write` — create PRs (`/ship`), merge PRs (`/go-live`)
  - `Actions: Read` — watch CI status (`gh pr checks`, `gh run watch`)
  - `Variables: Read and write` — set `PRODUCTION_URL` via `gh variable set` (Step 14)
  - **Do NOT add `workflow` scope** — this is intentional. Commits that touch
    `.github/workflows/` must be pushed by the human operator using their own
    credentials (which have full scope). This prevents Claude from modifying
    CI/CD pipelines without human review of the push itself.
- Vercel: `vercel.com/account/tokens`
- Supabase URL + publishable key + secret key: Project Settings → API.
  "Publishable key" = `SUPABASE_ANON_KEY`, "Secret key" = `SUPABASE_SERVICE_ROLE_KEY`
  (Supabase renamed these from "anon public" / "service_role" in late 2025)
- Supabase access token: `supabase.com/dashboard/account/tokens`
- Sentry DSN: Project Settings → Client Keys. Auth token: Org Settings → Auth Tokens.
- PostHog: Project Settings → Project API key

`SUPABASE_SERVICE_ROLE_KEY` (secret key) is for `supabase gen types`.
`SUPABASE_ACCESS_TOKEN` is for `supabase link`.

### Step 5: [HUMAN] Add GitHub Secrets + Variables

These are CI environment variables — added on the GitHub website, not in repo files.
Go to your repo on github.com → **Settings** → **Secrets and variables** → **Actions**.

**Secrets** tab → under **Repository secrets** (not Environment secrets):

- `VERCEL_TOKEN` — Vercel CLI auth for CI deploy commands
- `SUPABASE_URL` — Supabase API endpoint, needed by CI build to compile app config
- `SUPABASE_ANON_KEY` — Supabase publishable key, embedded in the built app during CI
- `SENTRY_DSN` — Sentry error reporting endpoint, embedded in the built app during CI
- `SENTRY_AUTH_TOKEN` — Sentry source map upload during CI build (not in the app itself)
- `NEXT_PUBLIC_POSTHOG_KEY` — PostHog analytics key, embedded in the built app during CI

All values come from `.devcontainer/.env` (same values you already filled in Step 4).

Note: `PRODUCTION_URL` variable is set later in Step 14 (after Vercel is linked and
the actual domain is known — Vercel may append a suffix like `-ten` if the name is taken).

Note: the GitHub PAT (`GITHUB_TOKEN` in `.env`) is only used inside the devcontainer
for `git push` and `gh` commands. It does not need to be a GitHub Secret — GitHub
Actions gets its own `GITHUB_TOKEN` automatically.

### Step 6: [HUMAN] Add firewall domains

Add project-specific domains to `.devcontainer/init-firewall.sh`. Find the
`for domain in \` block and add the following lines right before the closing `; do`
(after `"fonts.gstatic.com" \`):

- `<production-domain>` — your Vercel production domain (e.g., `lalista-ten.vercel.app`).
  Needed by `/land-and-deploy` to health-check the deploy from inside the container.
  Check actual domain in Vercel dashboard — it may have a suffix if the name was taken.
- `<project-ref>.supabase.co` — app talks to your Supabase project (API, auth, realtime)
- `o<org-id>.ingest.sentry.io` — Sentry error reporting ingest endpoint
- `sentry.io` — Sentry dashboard + source map uploads (already in the list if added in Phase 0a)
- `us.i.posthog.com` (or `eu.i.posthog.com`) — PostHog analytics event ingest
- `registry-1.docker.io` — Docker Hub images (needed by `supabase start`)
- `auth.docker.io` — Docker Hub authentication
- `production.cloudflare.docker.com` — Docker Hub CDN layer

Copy-paste block (replace placeholders):

```
    "<production-domain>" \
    "<project-ref>.supabase.co" \
    "o<org-id>.ingest.sentry.io" \
    "us.i.posthog.com" \
    "registry-1.docker.io" \
    "auth.docker.io" \
    "production.cloudflare.docker.com" \
```

Where to find the placeholder values:

- `<production-domain>` — from Vercel dashboard → Project → Settings → Domains
  (e.g., `lalista-ten.vercel.app`). Vercel appends a suffix if the base name is taken.
- `<project-ref>` — subdomain from `SUPABASE_URL` in `.env`
  (e.g., `https://abcdefgh.supabase.co` → `abcdefgh`)
- `<org-id>` — number from `SENTRY_DSN` in `.env`
  (e.g., `https://key@o123456.ingest.sentry.io/789` → `123456`)

### Step 7: [HUMAN] Rebuild devcontainer

Rebuild the devcontainer so that `.devcontainer/.env` credentials and firewall changes
take effect. In VS Code: Cmd/Ctrl+Shift+P → "Dev Containers: Rebuild Container".

Wait for the rebuild to complete before proceeding — all subsequent steps run commands
that depend on the loaded environment variables and firewall rules.

After the user confirms the rebuild is done, verify all expected env vars are present
and non-empty (without printing values):

```python
python3 -c "
import os
keys = ['VERCEL_TOKEN','SUPABASE_URL','SUPABASE_ANON_KEY','SUPABASE_SERVICE_ROLE_KEY',
        'SUPABASE_ACCESS_TOKEN','SENTRY_DSN','SENTRY_AUTH_TOKEN',
        'NEXT_PUBLIC_POSTHOG_KEY','GITHUB_TOKEN']
for k in keys:
    v = os.environ.get(k, '')
    status = f'SET (len={len(v)})' if v else 'MISSING'
    print(f'{k}: {status}')
"
```

If any are MISSING, tell the user which ones and ask them to fix `.devcontainer/.env`
and rebuild again. Only mark Step 7 complete when all vars are confirmed.

### Step 8: Clean template placeholders + project README

If the project was created from the abra-kadabra template, delete placeholder content:

```bash
rm -rf apps/ packages/ supabase/ DESIGN.md METRICS.md
```

Skip if these directories don't exist (first project, no template). If they exist
and contain project-specific content (git-tracked files), ask the user before
deleting — they may be from a prior project, not template placeholders.

Then replace `README.md` with a minimal project README:

```markdown
# <project-name>

## Development

1. Open in VS Code and select **Reopen in Container**
2. Run `claude` in the terminal

### Commands

- `pnpm turbo run test:unit` — fast test loop
- `pnpm turbo run test` — full test suite
- `pnpm turbo run build` — production build
- `pnpm turbo run dev` — dev server

> See `.devshop/README.md` for architecture and devshop details.
```

The project README grows over time as features ship (`/document-release` updates it).
The template repo has its own README (`.devshop/templates/README.md.tmpl`), synced separately.

### Step 9: Disable turbo telemetry

```bash
pnpm turbo telemetry disable
```

### Step 10: Install gstack

gstack is a per-project vendored dependency — not part of the devshop template sync.
Each project installs and upgrades independently via `/gstack-upgrade`.

```bash
git clone https://github.com/garrytan/gstack.git .claude/skills/gstack
cd .claude/skills/gstack && ./setup
```

If `./setup` fails due to a virtiofs mount (ENOENT on rename), build from `/tmp` with
absolute source paths — see project memory for the workaround commands.

### Step 11: Scaffold packages/core

Create `packages/core/` with:

- `package.json`:
  - name: `@<project-name>/core`
  - `"main": "src/index.ts"` (TypeScript source — no build step)
  - dependencies: `@supabase/supabase-js` (if using Supabase)
- `tsconfig.json` extending `../../tsconfig.base.json`
- `src/index.ts` — barrel export
- `src/supabase.ts` — typed Supabase client factory: `createClient(config: CoreConfig)`.
  Framework-agnostic — does NOT read env vars directly. Each app passes config in.
- `src/supabase.types.ts` — run `supabase gen types typescript --project-id <ref>` to
  generate (if Supabase project exists). Otherwise create a placeholder.
- `src/models/index.ts` — barrel export re-exporting generated Supabase types
- `vitest.config.ts` + one passing smoke test (validates the package builds and runs)

After creating files and running `pnpm install`, add `pnpm.onlyBuiltDependencies` to root
`package.json` to approve esbuild's postinstall script:

```json
"pnpm": {
  "onlyBuiltDependencies": ["esbuild"]
}
```

pnpm v10 silently ignores build scripts unless explicitly approved. Without this, esbuild
postinstall is skipped and vitest fails at runtime (missing native binary).

**Boundary**: Init generates from existing state but never writes feature logic.
If a DB schema exists, `supabase gen types` produces real types. If not, create
a placeholder. API wrappers, query functions, and feature-specific model types
are built during `/build` — not here.

### Step 12: Scaffold packages/ui

Create `packages/ui/` with:

- `package.json`:
  - name: `@<project-name>/ui`
  - `"main": "src/index.ts"` (TypeScript source — no build step)
- `tsconfig.json` extending `../../tsconfig.base.json`
- `src/index.ts` — barrel export
- `src/tokens.ts` — all design tokens as typed constants. Source of truth for JS
  consumers (components, tests, scripts). Framework-agnostic: no Tailwind utilities,
  no React imports. Includes:
  - **Colors**: semantic theme tokens (`background`, `text`, `accent`, `border`, etc.)
    with `light` and `dark` variants. Scaffold provides sensible defaults (white/black/blue);
    project fills in actual values during design system migration.
  - **Breakpoints**: `{ sm: 375, md: 768, lg: 1024, xl: 1440, '2xl': 2560 }` —
    iPhone SE to large desktop.
  - **Spacing**: 8px base grid scale.
  - **Fonts**: placeholder font stack; project replaces during design system migration.
- One base component (`Button`) as proof-of-concept — uses Tailwind classes with theme
  tokens (not hardcoded colors), responsive padding.

**No `tailwind.config.js`** — Tailwind v4 (shipped with Next.js 16+) uses CSS-based
`@theme` directives instead of JS config files. Token values are mirrored into
`apps/web/app/globals.css` as CSS custom properties (see Step 13). Both `tokens.ts`
and `globals.css` are mechanical derivations of `DESIGN.md`.

**Boundary**: If `DESIGN.md` exists, read actual token values from it (mechanical
derivation). If not, use sensible defaults. Feature-specific components are built
during `/build` — not here.

### Step 13: Scaffold apps/web

```bash
pnpm create next-app apps/web --typescript --tailwind --app --no-src-dir --import-alias "@/*" --no-git
```

Then:

1. **Import repo on Vercel**: In the Vercel dashboard, import the GitHub repo and set
   root directory to `apps/web`. This is deferred from Step 3 (account creation) — the app must exist first.
2. **Tailwind v4 tokens** — rewrite `globals.css` to define all design tokens as CSS
   custom properties (`:root` for light, `.dark` for dark mode) and register them with
   `@theme inline`. This is how Tailwind v4 works — CSS-based, not JS config files.
   Mirror the values from `packages/ui/src/tokens.ts` (both derived from `DESIGN.md`).
   Include: colors, fonts, breakpoints, spacing, border-radius.
3. Add `transpilePackages: ['@<project-name>/core', '@<project-name>/ui']` to `next.config.ts`
4. Add workspace deps: `pnpm add @<project-name>/core @<project-name>/ui --filter apps/web`
5. **Sentry**: `pnpm add @sentry/nextjs --filter apps/web`. Create config files
   manually (`sentry.client.config.ts`, `sentry.server.config.ts`, `instrumentation.ts`,
   `next.config.ts` wrapping with `withSentryConfig`). Create `apps/web/app/global-error.tsx`
   (App Router error boundary). Verify test error appears in Sentry dashboard.
6. **PostHog**: `pnpm add posthog-js --filter apps/web`. Create
   `apps/web/app/providers.tsx` as a client component that initializes PostHog
   (`posthog.init()` with `NEXT_PUBLIC_POSTHOG_KEY` — client-side only). Wrap root
   layout with provider. Verify test event appears in PostHog dashboard.
7. **PWA** (manifest + meta tags only — service worker deferred to `PRODUCT-ROADMAP.md`):
   Create `public/manifest.json` (app name, placeholder icon, theme color from tokens,
   `"display": "standalone"`). Add meta tags to `app/layout.tsx`:
   - `<link rel="manifest" href="/manifest.json">`
   - `<meta name="apple-mobile-web-app-capable" content="yes">`
   - `<meta name="apple-mobile-web-app-status-bar-style" content="default">`
   - `<link rel="apple-touch-icon" href="/icon-192.png">`
     Do NOT add service worker yet — stale-data bugs during active development.
8. **Security headers** in `next.config.ts` `headers()`:
   - `Content-Security-Policy`: strict default-src, script-src, style-src, connect-src
     (allow Supabase, Sentry, PostHog endpoints). Start strict, loosen as needed.
   - `Strict-Transport-Security`: `max-age=63072000; includeSubDomains; preload`
   - `X-Frame-Options`: `DENY`
   - `X-Content-Type-Options`: `nosniff`
   - `Referrer-Policy`: `strict-origin-when-cross-origin`
   - `Permissions-Policy`: disable camera, microphone, geolocation unless needed
9. **vercel.json** for monorepo-aware builds:
   ```json
   {
     "installCommand": "cd ../.. && pnpm install",
     "buildCommand": "cd ../.. && pnpm turbo run build --filter @<project-name>/web"
   }
   ```
   Without this, Vercel runs `pnpm install` from `apps/web/` with no awareness of
   workspace packages, and `@<project-name>/*` imports fail during build.
10. Remove default Next.js placeholder content (page.tsx, globals.css reset, SVGs)
11. Add placeholder home page that imports and uses a `@<project-name>/ui` Button
    component (validates workspace linking)
12. Keep the generated `eslint.config.mjs` (eslint-config-next with core-web-vitals +
    typescript). Root ESLint must be v9 — `eslint-config-next` depends on
    `eslint-plugin-react` which is incompatible with ESLint 10.
13. Approve build scripts — add `@sentry/cli`, `core-js`, `protobufjs`, `sharp`,
    `unrs-resolver` to `pnpm.onlyBuiltDependencies` in root `package.json`

### Step 14: Add Vercel CLI + link project + pipe env vars

Add Vercel CLI as a project devDependency (not global — Vercel is a hosting choice):

```bash
pnpm add -D -w vercel
```

Link the project and pipe env vars from `.devcontainer/.env`:

```bash
pnpm exec vercel link --yes --project <project-name> --token $VERCEL_TOKEN
```

Add env vars using `--value` flag (Vercel CLI v50+ requires this for non-interactive
mode). Each env var needs separate calls per environment. For preview, pass empty
string `""` as the git branch argument to apply to all preview branches:

```bash
# Helper — adds one env var to all three environments
add_env() {
  local name="$1" value="$2" token="$VERCEL_TOKEN"
  pnpm exec vercel env add "$name" production --value "$value" --yes --token "$token"
  pnpm exec vercel env add "$name" preview "" --value "$value" --yes --token "$token"
  pnpm exec vercel env add "$name" development --value "$value" --yes --token "$token"
}

add_env NEXT_PUBLIC_SUPABASE_URL "$SUPABASE_URL"
add_env NEXT_PUBLIC_SUPABASE_ANON_KEY "$SUPABASE_ANON_KEY"
add_env NEXT_PUBLIC_POSTHOG_KEY "$NEXT_PUBLIC_POSTHOG_KEY"
add_env NEXT_PUBLIC_SENTRY_DSN "$SENTRY_DSN"

# SENTRY_AUTH_TOKEN is a secret — prod + preview only (not development)
pnpm exec vercel env add SENTRY_AUTH_TOKEN production --value "$SENTRY_AUTH_TOKEN" --yes --token "$VERCEL_TOKEN"
pnpm exec vercel env add SENTRY_AUTH_TOKEN preview "" --value "$SENTRY_AUTH_TOKEN" --yes --token "$VERCEL_TOKEN"
```

User enters credentials once in `.env`; this step syncs them to Vercel automatically.
Do not override install/build commands in the Vercel dashboard — `vercel.json` handles that.

**[HUMAN] Set `PRODUCTION_URL` GitHub variable:**

After Vercel is linked, ask the user to check the actual production domain in the
Vercel dashboard (Project → Settings → Domains). Vercel assigns
`<project-name>.vercel.app` if available, but appends a suffix (e.g., `-ten`, `-three`)
if the name is taken. Once the user confirms the domain, set the GitHub variable:

```bash
gh variable set PRODUCTION_URL --body "https://<production-domain>"
```

This is used by `keepalive.yml` (prevents Supabase free tier pause) and
`/land-and-deploy` (post-deploy health checks).

### Step 15: Install Playwright

```bash
pnpm add -D @playwright/test --filter apps/web
npx playwright install chromium
```

Playwright downloads its own headless Chromium (~183 MB) from `cdn.playwright.dev`
(with fallback to `playwright.download.prss.microsoft.com`). Both domains are in the
firewall allowlist.

After downloading, Playwright needs system shared libraries:

```bash
sudo apt-get update && sudo npx playwright install-deps chromium
```

This requires `deb.debian.org` in the firewall (already there from the devcontainer
base image). The `install-deps` command auto-resolves the correct package names for
the host distro (e.g., Debian Trixie `t64` suffixes).

Create `apps/web/playwright.config.ts` with two projects:

- **mobile**: 375px viewport
- **desktop**: 1440px viewport

Both must pass.

### Step 16: Supabase init + link (if using Supabase)

If `supabase/config.toml` doesn't exist yet:

```bash
supabase init
```

Then link to the remote project:

```bash
supabase link --project-ref <project-ref>
```

Uses `SUPABASE_ACCESS_TOKEN` from `.devcontainer/.env`. Must be done before first
`supabase start` or `supabase gen types`.

### Step 17: Create METRICS.md

Create the project-level metrics source of truth with the empty template structure:

```markdown
# Metrics

## Events

| Event | When it fires | Key properties | Why we care |
| ----- | ------------- | -------------- | ----------- |

## Feature Flags

| Flag | Controls | Default |
| ---- | -------- | ------- |
```

This is an empty structure — `/spec` populates it with project-specific events during
the first feature build. See `.devshop/GUIDE.md § Metrics Lifecycle` for the full flow.

### Step 18: Run /setup-deploy

Run the gstack `/setup-deploy` skill to configure `/land-and-deploy` with the production
URL and health check endpoints. Must be done after Vercel is linked and before the first
use of `/land-and-deploy`.

### Step 19: Create CLAUDE.project.md

Create `CLAUDE.project.md` in the project root with project-specific Claude guidance.
This file is tracked in git and is the project's contribution to the generated `CLAUDE.md`.

At container start, `init-devshop.sh` generates `CLAUDE.md` by concatenating:
- `abra-kadabra/CLAUDE.md` (devshop conventions) + `CLAUDE.project.md` (project context)

The generated `CLAUDE.md` is gitignored — edits go to `CLAUDE.project.md`.

Create `CLAUDE.project.md` with at minimum:

```markdown
## Project: <project-name>

<one-line description>

### Where Things Happen

_This section grows as code is added. Update it when introducing new paths._

### Stack

<list the stack>

### Env Var Naming

<env var table if applicable>
```

The project-specific sections (deploy config, migration workflow, etc.) are added as
they become relevant during feature development.

### Step 20: Enable documentation enforcement hooks

All scaffold commits are now landed. Enable the hooks that were intentionally deferred:

1. Wire up the pre-commit hook — update `.husky/pre-commit` to add:

   ```sh
   bash .devshop/scripts/check-devshop-docs.sh
   ```

   Note: `check-file-headers.sh` is NOT wired into pre-commit. File header enforcement
   is handled by `/pre-ship` convention check instead — mechanical pre-commit enforcement
   produces mechanical documentation.

2. Add `eslint-plugin-jsdoc` as a root dev dependency:

   ```bash
   pnpm add -D -w eslint-plugin-jsdoc
   ```

3. Configure `jsdoc/require-jsdoc` in root `eslint.config.mjs` for exported functions only:
   ```js
   {
     plugins: { jsdoc },
     rules: {
       'jsdoc/require-jsdoc': ['warn', {
         require: { FunctionDeclaration: true },
         contexts: ['ExportNamedDeclaration > VariableDeclaration > VariableDeclarator > ArrowFunctionExpression'],
         checkConstructors: false,
       }],
     },
   }
   ```

### Step 21: Update .gitleaks.toml allowlist

Update `.gitleaks.toml` with project-specific public key patterns before the first commit
with real config values. Common additions: Supabase anon key pattern, PostHog public key.

### Step 22: [HUMAN] Lock security-critical files

`init-devshop.sh` automatically locks injected files (`.claude/settings.json`, `.dcg.toml`)
on every container start. The project's `.devcontainer/` files also need locking:

```bash
sudo chown root:root .devcontainer/devcontainer.json .devcontainer/init-firewall.sh .devcontainer/Dockerfile .devcontainer/checksums.sha256 .devcontainer/.env
sudo chmod 644 .devcontainer/devcontainer.json .devcontainer/init-firewall.sh .devcontainer/Dockerfile .devcontainer/checksums.sha256 .devcontainer/.env
```

These files already have deny rules in settings.json; this adds filesystem-level protection.
To edit later: `sudo nano <file>`.

### Step 23: Create keepalive.yml

Create `.github/workflows/keepalive.yml` — prevents Supabase free tier from pausing after
1 week of inactivity (paused = silent production outage until manually resumed):

```yaml
name: Keepalive
on:
  schedule:
    - cron: '0 9 * * 1' # Every Monday at 9am UTC
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping production
        run: |
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${{ vars.PRODUCTION_URL }}")
          if [ "$STATUS" != "200" ]; then
            echo "::warning::Production returned $STATUS"
          fi
```

Requires the `PRODUCTION_URL` repository variable (set in Step 14).

> **[HUMAN] push required**: This commit adds a `.github/workflows/` file. The
> devcontainer PAT intentionally lacks `workflow` scope, so Claude cannot push it.
> The human operator must push using their own credentials:
>
> ```bash
> git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>
> ```
>
> This applies to any commit that creates or modifies workflow files.

### Step 24: [HUMAN] Service quota alerts

Set up quota alerts in each service's dashboard (free, no infrastructure):

- **Sentry**: Settings → Alerts → Spike Protection (auto-enabled) + quota alert at 80%
- **PostHog**: Settings → Billing → usage alerts
- **Vercel**: Settings → Usage → email notifications
- **GitHub Actions**: monitor via monthly `/retro` (no native alert)

### Step 25: [HUMAN] Set up abra-kadabra bind mount

The devshop repo (`abra-kadabra`) is bind-mounted into the devcontainer from the
host machine. `init-devshop.sh` injects devshop files into the workspace via symlinks
at container start. See `.devshop/GUIDE.md § Devshop Separation Architecture`.

**[HUMAN] One-time setup** (if not already done):

1. On the host, clone the devshop repo as a sibling to this project:
   ```bash
   cd <parent-of-project> && git clone https://github.com/<org>/abra-kadabra
   ```
2. Verify `.devcontainer/devcontainer.json` has the mount in the `mounts` array:
   ```json
   "source=${localWorkspaceFolder}/../abra-kadabra,target=/devshop,type=bind,consistency=delegated"
   ```
3. Rebuild the devcontainer.
4. Verify injection worked: `ls -la .devshop` should show a symlink to `/devshop/.devshop/`.

### Step 26: [HUMAN] Branch protection

Must be done AFTER the first PR has been pushed and CI has run at least once.
GitHub can only require a status check that has already produced a result.

Sequence: push first PR → verify CI produces a green `ci` check → then enable:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field 'required_status_checks={"strict":true,"contexts":["ci"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews=null \
  --field restrictions=null
```

### Step 27: Run /cso baseline audit

Run `/cso` (gstack) for a baseline infrastructure security audit: CI/CD config, secrets
setup, firewall, `.claude/settings.json`, Docker-in-Docker isolation, branch protection.
Run last so it audits the complete setup.

---

## Verification Checklist

After all steps pass, verify:

- [ ] `pnpm turbo run test` passes (placeholder tests in packages/core)
- [ ] `pnpm turbo run build` succeeds (web app builds without errors)
- [ ] Push a PR → GitHub Actions CI runs → green (including gitleaks)
- [ ] Vercel preview URL appears in PR comments automatically
- [ ] Merge to main → Vercel production deploys
- [ ] Trigger a test Sentry error from web → appears in Sentry dashboard
- [ ] PostHog dashboard receives a test event from web
- [ ] `METRICS.md` exists with event taxonomy structure
- [ ] `/cso` baseline audit passes

## Step 3: Resume support

On resume (some items already `- [x]`):

- Count completed items
- Show summary: "7/20 done, next: Scaffold packages"
- Skip completed items
- Continue from first unchecked item

## Step 4: Cleanup

After all items pass:

- Reset all checkboxes back to `- [ ]` (the file is a reusable template)
- Confirm completion
