---
name: ak-new-project
version: 1.1.0
description: |
  Create and set up a new project from the devshop template. Single entry point
  with two phases: Phase A creates a GitHub repo with the template from any
  container. Phase B does interactive setup inside the new project's container.
  Phase B also generates apps/web/.env.local so local `pnpm dev` and browser
  gates (design-review / qa / benchmark / Playwright E2E) work without extra
  manual plumbing.
  Use when asked to "new project", "create project", "start a project". (devshop)
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

# New Project

Single entry point for creating and setting up a new project from the devshop
template. Auto-detects which phase to run based on the workspace context.

## Phase Detection

```
if kit/ is a real directory (not symlink) → Phase A (create repo)
elif /devshop/kit/notes/projects/<name>.md exists → Resume Phase B (continue setup)
elif turbo.json exists                            → Phase B first run (start setup)
else                                              → Error: not a recognized context
```

---

## Phase A: Create Project Repository

Runs from the devshop's own devcontainer or any existing project's container.
Creates a GitHub repo populated with the devshop template.

### Steps

1. **Ask project details**:
   - Project name (used for GitHub repo and npm scope `@<name>`)
   - One-line description
   - GitHub visibility (private/public)
   - GitHub org (optional — defaults to personal account)

2. **Create GitHub repo**:

   ```bash
   gh repo create <name> --<visibility> --description "<description>"
   ```

   Or with org: `gh repo create <org>/<name> --<visibility> --description "<description>"`

3. **Clone + populate from template**:

   ```bash
   git clone <repo-url> /tmp/<name>
   rsync -a /devshop/template/ /tmp/<name>/
   ```

4. **Fill basic placeholders in README.md**:
   Replace `<project-name>` and `<one-line description>` in `/tmp/<name>/README.md`.

5. **Commit and push**:

   ```bash
   cd /tmp/<name>
   git add -A
   git commit -m "chore: scaffold from devshop template"
   git push
   ```

6. **Print next steps**:

   ```
   Project created: <repo-url>

   Next:
     1. On your host, clone the repo next to abra-kadabra:
        cd <parent-of-abra-kadabra> && git clone <repo-url>
     2. Open the cloned folder in VS Code
     3. Select "Reopen in Container"
     4. Run `claude` and say `/ak-new-project`
   ```

---

## Phase B: Set Up Project

Runs inside the new project's devcontainer. Walks through service setup,
scaffolding, and configuration. Tracks progress in `/devshop/kit/notes/projects/<name>.md`
(not in the project repo — keeps project history clean).

### Resume Support

On first run: create `/devshop/kit/notes/projects/<name>.md` with all steps unchecked.
On subsequent runs: read that file, count completed items, show summary
("7/20 done, next: Scaffold packages"), skip completed, continue from first unchecked.

Derive `<name>` from the git remote: `git remote get-url origin | sed 's#.*/##; s/\.git$//'`.

### Principles

**ONE STEP AT A TIME.** Present a single step, wait for completion, then move to
the next. Never batch or group multiple steps — even if several consecutive steps
are all [HUMAN]. The user needs the chance to ask questions on each step.

**DEPTH OVER SPEED.** When a step hits friction (missing permissions, unexpected
URLs, unclear docs), stop and think about consequences — a wrong URL means deploys
fail, a missing permission means /ship breaks. Solve the problem, update the skill
so the next project doesn't hit it, and only move on when the step is genuinely done.

### On [HUMAN] items

- Show what the user needs to do (clear instructions, links where helpful)
- Wait for the user to say "done" or provide the requested value
- Do NOT present the next step until the current one is confirmed done
- Mark `[x]` in `/devshop/kit/notes/projects/<name>.md`

### On automated items

- Run the command/action per the detail below
- Verify success (check exit code, verify file exists, etc.)
- Mark `[x]` in `/devshop/kit/notes/projects/<name>.md`

### On failure

- Stop
- Show the error clearly
- Ask: retry / skip / abort

---

## Init Tracker Format

Created by this skill at `/devshop/kit/notes/projects/<name>.md` on first Phase B run:

```markdown
# Init Tracker — <project-name>

Created by `/ak-new-project` on <date>.

## Progress

1. [ ] Check binary versions
2. [ ] Customize project docs (BUILD-LOG.md, PRODUCT-ROADMAP.md, README.md)
3. [ ] **[HUMAN]** Create accounts (Vercel, Sentry, PostHog, Supabase)
4. [ ] **[HUMAN]** Fill .devcontainer/.env with credentials
5. [ ] **[HUMAN]** Add GitHub Secrets + Variables
6. [ ] **[HUMAN]** Add firewall domains to .devcontainer/init-firewall.sh
7. [ ] **[HUMAN]** Rebuild devcontainer
       7b. [ ] **[HUMAN]** Set up Claude Code notifications (optional, one-time per user)
8. [ ] Disable turbo telemetry
9. [ ] Install gstack
10. [ ] Scaffold packages/core
11. [ ] Scaffold packages/ui
12. [ ] Scaffold apps/web
13. [ ] Add Vercel CLI + link + pipe env vars
14. [ ] Install Playwright
15. [ ] Supabase init + link (if using)
16. [ ] Create METRICS.md
17. [ ] Run /setup-deploy
        17b. [ ] Harden Supabase auth defaults (password + CAPTCHA + site_url / uri_allow_list)
18. [ ] Create project CLAUDE.md
19. [ ] Enable doc enforcement hooks
20. [ ] Update .gitleaks.toml allowlist
21. [ ] **[HUMAN]** Lock security-critical files
22. [ ] Create keepalive.yml
23. [ ] **[HUMAN]** Set up service quota alerts
24. [ ] **[HUMAN]** Enable branch protection
25. [ ] Run /cso baseline security audit
```

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
5. If all current: confirm and continue.

### Step 2: Customize project docs and root package.json

The template includes `BUILD-LOG.md`, `PRODUCT-ROADMAP.md`, and `README.md` at their
final locations. Customize them in-place:

- **README.md**: already filled with project name and description from Phase A. Verify
  placeholders are replaced. If any `<project-name>` or `<one-line description>` remain, fill them.
- **BUILD-LOG.md**: generic template — no changes needed unless the user wants to customize.
- **PRODUCT-ROADMAP.md**: generic template — ask the user if they have existing roadmap
  items to add, or keep as-is for now.
- **Root `package.json`**: template ships `"name": "project-name"` as a placeholder. Rename
  it to the project name (used by `notify-claude-*` hooks for the banner label; also keeps
  pnpm's workspace root name honest). Safe to change — nothing else in the tree references it.

  ```bash
  tmp=$(mktemp) && jq ".name = \"<project-name>\"" package.json > "$tmp" && mv "$tmp" package.json
  ```

  Optional `-dev` suffix if you plan to publish a public npm package under the same name later
  (e.g. `lalista-dev` so `lalista` stays free on npm).

### Step 3: [HUMAN] Create accounts

- **Vercel**: create account at vercel.com, install the Vercel GitHub App (enables auto-deploy
  and preview URLs on PRs). Do NOT import the repo yet — import happens in Step 12 after
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
SUPABASE_DB_PASSWORD=<project-db-password>

# Anthropic (if using Claude in edge functions)
ANTHROPIC_API_KEY=<api-key>

# Sentry
SENTRY_DSN=https://<key>@o<org-id>.ingest.sentry.io/<project-id>
SENTRY_AUTH_TOKEN=<auth-token>

# PostHog
NEXT_PUBLIC_POSTHOG_KEY=<project-api-key>

# Claude Code notifications (optional)
# Same topic across all your projects — generate once per user, reuse everywhere.
# See kit/docs/guide/notifications.md
NTFY_URL=https://ntfy.sh/<your-topic>
```

Where to find each:

- Devcontainer root password: pick any password. Enables `sudo` for the human operator.
- GitHub PAT: github.com/settings/tokens → Fine-grained tokens → Generate new token.
  Scope to this repo only. Required permissions:
  - `Contents: Read and write` — push branches and commits
  - `Pull requests: Read and write` — create PRs, merge PRs
  - `Actions: Read` — watch CI status via `gh run list` / `gh run watch`
    (the richer `gh pr checks <N>` needs Check Runs API access, which
    fine-grained PATs can't grant — GitHub removed the Checks
    permission after initial release and hasn't reintroduced it; see
    https://github.com/orgs/community/discussions/129512. `Actions: Read`
    is enough for every CI-monitoring flow `/ak-build` actually runs.)
  - **Do NOT add `workflow` scope** — workflow file changes must be pushed by the human.
- Vercel: `vercel.com/account/tokens`
- Supabase URL + keys: Project Settings → API.
- Supabase access token: `supabase.com/dashboard/account/tokens`
- Supabase DB password: Project Settings → Database → Connection string (the password
  shown when you copy a connection string). Used by the migration auto-deploy workflow
  to authenticate `supabase db push` non-interactively.
- Anthropic API key: console.anthropic.com → Settings → API Keys. Required only if the
  project's edge functions call Claude. Slow-job CI integration tests will fail loudly
  without it (per the project's own pre-merge actions list).
- Sentry DSN: Project Settings → Client Keys. Auth token: Org Settings → Auth Tokens.
- PostHog: Project Settings → Project API key
- NTFY_URL: one-time per user. Generate a topic: `openssl rand -hex 32` (ntfy caps topics at 64 chars; 64 hex = exactly 64).
  Reuse the same URL across every project — banner differentiates by project name via the
  hook scripts. Subscribe on iPhone (ntfy app) and Mac (ntfy.sh URL in Safari → Add to Dock).
  Full details in `kit/docs/guide/notifications.md`. Optional — leave blank to disable.

### Step 5: [HUMAN] Add GitHub Secrets + Variables

Go to repo on github.com → **Settings** → **Secrets and variables** → **Actions**.

**Secrets** tab → **Repository secrets**. All values come from `.devcontainer/.env`. Group by which workflow consumes them (so missing entries surface as a workflow failure, not a silent skip):

- **Front-end + fast-job CI baseline**: `VERCEL_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`
- **Slow-job CI** (integration tests + edge-function deploy proof): `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY` (only if edge functions call Claude — slow-job will fail loudly without it)
- **Migration auto-deploy workflow** (`.github/workflows/deploy-migrations.yml`, applies migrations to prod on push:main when `supabase/migrations/**` changes): `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`. Without these, the workflow fails at link/push and prod schema goes stale silently — same failure mode as no auto-deploy at all, just noisier.

Note: `PRODUCTION_URL` is a **Variable** (not a Secret) and is added later in Step 13 after the Vercel domain is known.

### Step 6: [HUMAN] Add firewall domains

Add project-specific domains to `.devcontainer/init-firewall.sh`. Find the `for domain in \`
block and add lines before the closing `; do`. See placeholder comments in the file for
which domains to add (Vercel app URL, Supabase project ref, Sentry org ingest, PostHog,
Docker Hub for supabase start).

### Step 7: [HUMAN] Rebuild devcontainer

Rebuild: Cmd/Ctrl+Shift+P → "Dev Containers: Rebuild Container".

After rebuild, verify env vars:

```python
python3 -c "
import os
keys = ['VERCEL_TOKEN','SUPABASE_URL','SUPABASE_ANON_KEY','SUPABASE_SERVICE_ROLE_KEY',
        'SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','ANTHROPIC_API_KEY',
        'SENTRY_DSN','SENTRY_AUTH_TOKEN','NEXT_PUBLIC_POSTHOG_KEY','GITHUB_TOKEN']
for k in keys:
    v = os.environ.get(k, '')
    status = f'SET (len={len(v)})' if v else 'MISSING'
    print(f'{k}: {status}')
"
```

### Step 7b: [HUMAN] Set up Claude Code notifications (optional, one-time per user)

Claude Code pings your iPhone/Apple Watch/Mac via ntfy.sh when it needs input or finishes a task. The firewall allowlist ships with the template; the hook wiring is propagated from `/devshop/.claude/settings.json` into every project's `.claude/settings.json` by `init-devshop.sh` at each container start. Per-user pieces: pick a topic (once, reused across projects), put it in each project's `.devcontainer/.env`, and subscribe on your devices.

**Skip if you already have a topic and have subscribed**: just confirm `NTFY_URL` in `.devcontainer/.env` matches your existing topic and move to Step 8.

**Otherwise, one-time setup (do this in your first project; reuse in every subsequent project)**:

1. **Generate a topic** (shared across all your projects, high-entropy so it's unguessable):

   ```bash
   openssl rand -hex 32
   ```

   Example output: `60c9bacd782a4622bdb17719acd11c65d13ccf4447ffe8244d017f34f53c17c2` (64 hex chars — ntfy caps topics at 64, so no prefix fits).

2. **Set `NTFY_URL` in `.devcontainer/.env`** — replace the `<your-topic>` placeholder from Step 4:

   ```
   NTFY_URL=https://ntfy.sh/<your-topic>
   ```

   Reuse the exact same value in every project's `.devcontainer/.env`. Rotating later means editing N files — rare, acceptable.

3. **Subscribe on iPhone**: install [ntfy iOS app](https://apps.apple.com/us/app/ntfy/id1625396347), tap **+**, paste just the topic (`<your-topic>` — no `https://` prefix), accept the notification permission. Apple Watch mirrors automatically.

4. **Subscribe on Mac** (optional, no app needed): open `https://ntfy.sh/<your-topic>` in Safari → accept notifications → File → **Add to Dock** to keep it alive when the browser closes. Chrome alternative: ⋮ menu → Install ntfy.sh as app.

5. **Rebuild this devcontainer** so Docker re-reads `.devcontainer/.env`. If you already rebuilt in Step 7 after filling in NTFY_URL in Step 4, you're done.

See `kit/docs/guide/notifications.md` for architecture, privacy notes, rotation, and disabling.

### Step 8: Disable turbo telemetry

```bash
pnpm turbo telemetry disable
```

### Step 9: Install gstack

```bash
git clone https://github.com/garrytan/gstack.git .claude/skills/gstack
cd .claude/skills/gstack && ./setup
```

If `./setup` fails due to virtiofs mount, build from `/tmp` — see project memory.

### Step 10: Scaffold packages/core

Create `packages/core/` with:

- `package.json` (name: `@<project-name>/core`, main: `src/index.ts`)
- `tsconfig.json` extending `../../tsconfig.base.json`
- `src/index.ts` (barrel), `src/supabase.ts` (typed client factory), `src/supabase.types.ts` (generated or placeholder), `src/models/index.ts`
- `vitest.config.ts` + one passing smoke test

Add `pnpm.onlyBuiltDependencies: ["esbuild"]` to root package.json.

### Step 11: Scaffold packages/ui

Create `packages/ui/` with:

- `package.json` (name: `@<project-name>/ui`, main: `src/index.ts`)
- `tsconfig.json`, `src/index.ts`, `src/tokens.ts` (design tokens as typed constants)
- One `Button` component proof-of-concept

No `tailwind.config.js` — Tailwind v4 uses CSS `@theme`.

### Step 12: Scaffold apps/web

```bash
pnpm create next-app apps/web --typescript --tailwind --app --no-src-dir --import-alias "@/*" --no-git
```

Then: import on Vercel, Tailwind v4 tokens in globals.css, transpilePackages,
workspace deps, Sentry, PostHog, PWA manifest, security headers, vercel.json,
remove placeholders, approve build scripts in onlyBuiltDependencies.

### Step 13: Add Vercel CLI + link + pipe env vars

```bash
pnpm add -D -w vercel
pnpm exec vercel link --yes --project <project-name> --token $VERCEL_TOKEN
```

Pipe env vars with `--value` flag (Vercel CLI v50+).

**[HUMAN]** Add `PRODUCTION_URL` as a GitHub **Variable** (not Secret) once the Vercel
domain is known. Value is the Vercel production domain (e.g. `https://<project>-<hash>.vercel.app`
or your custom domain).

To fetch the value, run:

```bash
pnpm exec vercel inspect <project-name> --token $VERCEL_TOKEN 2>&1 | grep -i 'production\|domain' | head -5
```

Or check Vercel dashboard → Project → Settings → Domains. Show the value to the user.

Add it at: repo on github.com → **Settings** → **Secrets and variables** → **Actions** → **Variables** tab → **New repository variable**.

Used by `.github/workflows/keepalive.yml` to prevent Supabase auto-pause.

#### Step 13b: Generate `apps/web/.env.local` for local dev

The devcontainer loads `.devcontainer/.env` as shell env with base names
(`SUPABASE_URL`, `SUPABASE_ANON_KEY`, …). Next.js only exposes env vars to the
browser when they are prefixed `NEXT_PUBLIC_*`. Vercel has already been piped
the prefixed names above, but **local** `pnpm dev` still needs them — generate
a `.env.local` that maps shell vars to the prefixed names.

```bash
mkdir -p apps/web
cat > apps/web/.env.local <<EOF
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
NEXT_PUBLIC_POSTHOG_KEY=$NEXT_PUBLIC_POSTHOG_KEY
NEXT_PUBLIC_SENTRY_DSN=$SENTRY_DSN
EOF
```

Verify Next.js's default `.gitignore` covers `apps/web/.env*.local` (it does for
`create-next-app` output, but double-check). If not, append:

```
# Local env (never commit)
.env*.local
```

to `apps/web/.gitignore`. The `.env.local` file itself is never committed — it
is a local derivation of shell env, and the shell env comes from `.devcontainer/.env`
which is itself gitignored + read-protected.

Without this step, every browser-dependent gate (`/design-review`, `/qa`,
`/benchmark`, Playwright E2E) + local dev breaks with "supabaseUrl is required"
or a crashing 500 on first render, because the Next.js client bundle can't read
the unprefixed shell env at build time.

### Step 14: Install Playwright

```bash
pnpm add -D @playwright/test --filter apps/web
npx playwright install chromium
sudo apt-get update && sudo npx playwright install-deps chromium
```

Create `playwright.config.ts` with mobile (375px) and desktop (1440px) projects.

### Step 15: Supabase init + link (if using)

```bash
supabase init    # if supabase/config.toml doesn't exist
supabase link --project-ref <project-ref>
```

### Step 16: Create METRICS.md

Empty event taxonomy structure. `/ak-spec` populates during first feature build.

### Step 17: Run /setup-deploy

Run gstack `/setup-deploy` to configure deploy settings.

### Step 17b: Harden Supabase auth defaults

Supabase's free-tier defaults are too permissive for production: `password_min_length: 6`, CAPTCHA off, `site_url: http://localhost:3000`, empty `uri_allow_list`. Every email-based auth flow (password recovery, magic link, email change, signup confirmation) silently breaks when the user clicks a link from a real inbox because the redirect lands on `localhost`. Patch these at setup time so no project ships with the bad defaults.

This step runs **after** Step 17 because `site_url` + `uri_allow_list` derive from the production URL written to `CLAUDE.md § Deploy Configuration` by `/setup-deploy`.

**Inputs**:

- `SUPABASE_ACCESS_TOKEN` — already in shell env from Step 4
- `SUPABASE_URL` — from `.env.local` (generated in Step 13b) or `.devcontainer/.env` — used to derive the project ref
- Production URL — from `CLAUDE.md § Deploy Configuration § Production URL` (written by `/setup-deploy` at Step 17)
- Vercel project slug — from `.vercel/project.json` (written in Step 13)

**Sub-step 1: Password policy (mandatory, non-interactive)**

Bump `password_min_length` from the free-tier default 6 → 8.

```bash
PROJECT_REF=$(echo "$SUPABASE_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')

curl -sX PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"password_min_length": 8}'

# Verify
curl -sX GET "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  | jq '.password_min_length'
# Expected output: 8
```

**Sub-step 2: CAPTCHA (interactive)**

```
[HUMAN] Paste your hCaptcha secret from https://dashboard.hcaptcha.com/, or leave blank to skip:
```

If a secret is provided:

```bash
curl -sX PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"security_captcha_enabled\": true, \"security_captcha_provider\": \"hcaptcha\", \"security_captcha_secret\": \"${HCAPTCHA_SECRET}\"}"
```

If skipped, prepend a visible reminder to `BUILD-LOG.md` so it surfaces at every `/ak-status`:

```markdown
# Build Log — <project>

> **[TODO] CAPTCHA deferred** — hCaptcha was not configured during /ak-new-project Step 17b. Add before public launch via PATCH /v1/projects/{ref}/config/auth with `security_captcha_enabled: true`, `security_captcha_provider: "hcaptcha"`, `security_captcha_secret: "<secret>"`. Remove this line when done.

Project build history.
...
```

The reminder lives above the `Project build history.` line — BUILD-LOG is for shipped features, not platform TODOs, so platform reminders surface as a visible header note.

**Sub-step 3: site_url + uri_allow_list (mandatory site_url; minimal allow list by default, opt-in extras)**

Compose the minimal allow list (production URL + localhost) from values `/setup-deploy` already wrote to `CLAUDE.md`. Preview-deploy wildcards and additional Vercel aliases are **opt-in** — their exact patterns vary per Vercel team + hash, are hard to auto-derive reliably, and are not needed for basic email-auth flows to work.

```bash
# Production URL from /setup-deploy (Step 17 wrote it to CLAUDE.md § Deploy Configuration § Production URL)
PROD_URL=$(awk -F': ' '/Production URL:/ {print $2; exit}' CLAUDE.md | tr -d ' \r')

# Minimal default: production + localhost. No project alias, no preview wildcard.
# This matches the lalista 2026-04-20 convention — the minimal set that makes
# password recovery + magic link + email change + signup confirm all work in
# production AND local dev, without over-permissively opening additional surface.
URI_ALLOW="${PROD_URL}/**,http://localhost:3000/**"
```

**Opt-in A: Vercel preview deploys**

Ask whether email-auth flows need to work from Vercel PR previews. Most projects don't need this for MVP — previews are developer-facing.

```
[HUMAN] Want email-auth flows (password reset, magic link, signup confirm) to work from Vercel PR preview deploys? [y/N]:
```

If `y`, help the user compose the wildcard. Preview URLs look like `https://<project>-git-<branch>-<team>-<hash>.vercel.app`. The wildcard that catches all of them is typically `https://*-<team>-<hash>.vercel.app/**`.

```
[HUMAN] Look at a recent Vercel preview URL (paste it here or look up in the Vercel dashboard). Enter the wildcard pattern — e.g., `https://*-meirs-projects-4803a76a.vercel.app/**` if your team slug is `meirs-projects` and your hash is `4803a76a`:
```

```bash
# After user enters the wildcard:
URI_ALLOW="${URI_ALLOW},${PREVIEW_WILDCARD}"
```

If `n` (or user skips), log a TODO to `BUILD-LOG.md` so it surfaces at next `/ak-status`:

```markdown
> **[TODO] Preview-deploy email-auth deferred** — `uri_allow_list` does not include the Vercel preview wildcard. Email-auth flows (password reset, magic link) will not work from PR preview deploys. Add via `PATCH /v1/projects/{ref}/config/auth` when needed.
```

**Opt-in B: additional aliases** (rare — e.g., custom domains + the default `<project>.vercel.app` alias Vercel auto-provides):

```
[HUMAN] Any other URLs that need email-auth redirects (comma-separated wildcards, or blank to skip)?
```

Append to `URI_ALLOW` if provided.

**Apply and verify**:

```bash
curl -sX PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"site_url\": \"${PROD_URL}\", \"uri_allow_list\": \"${URI_ALLOW}\"}"

# Read-back for confirmation
echo "Configured URLs:"
curl -sX GET "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  | jq '{site_url, uri_allow_list}'
```

```
[HUMAN] Do these match your deploy targets (production + opted-in extras + localhost)? [y/N]:
```

If the user says no, iterate with them to correct before advancing. Misconfigured `site_url` is a silent failure mode at runtime — get it loud and right at setup time.

**Why minimal-by-default**: the 2026-04-20 lalista application of this step used `${PROD_URL}/**,http://localhost:3000/**` (nothing else) and fixed the immediate broken-email-links issue. Additional patterns can always be added later via a single Management API PATCH — no downside to starting minimal. Over-permissive defaults, in contrast, create latent attack surface if a wildcard ever matches an attacker-controlled domain.

**What this step does NOT touch** (by design):

- `rate_limit_email_sent` — stays at the free-tier default (2/hour). Tightening is a production-launch concern, not a setup-time concern; raising requires custom SMTP, which is per-project.
- `disable_signup` — stays `false`. Invite-code alternative is a separate roadmap item tracked in `kit/ROADMAP.md § v1 § Invite-code signup control`.

See `kit/docs/guide/conventions.md § Supabase Hardening Defaults` for the full rationale + FK-cascade convention that pairs with this step.

### Step 18: Create project CLAUDE.md

Project-specific Claude guidance. Tracked in git. Devshop conventions auto-loaded
from devshop repo via `additionalDirectories`.

### Step 19: Enable doc enforcement hooks

Add `eslint-plugin-jsdoc`, configure in root `eslint.config.mjs`.

### Step 20: Update .gitleaks.toml allowlist

Add project-specific public key patterns (Supabase anon key, PostHog key).

### Step 21: [HUMAN] Lock security-critical files

```bash
sudo chown root:root .devcontainer/devcontainer.json .devcontainer/init-firewall.sh .devcontainer/Dockerfile .devcontainer/checksums.sha256 .devcontainer/.env
sudo chmod 644 .devcontainer/devcontainer.json .devcontainer/init-firewall.sh .devcontainer/Dockerfile .devcontainer/checksums.sha256 .devcontainer/.env
```

### Step 22: Create keepalive.yml

Create `.github/workflows/keepalive.yml` — weekly ping to prevent Supabase pause.

> **[HUMAN] push required**: Workflow files need human push (PAT lacks `workflow` scope).

### Step 23: [HUMAN] Service quota alerts

Set up in each service's dashboard: Sentry (80% alert), PostHog (usage), Vercel (email).

### Step 24: [HUMAN] Branch protection

After first CI run produces a green `fast` check (triggered by a PR, since the workflow doesn't run on direct pushes to main):

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field 'required_status_checks={"strict":true,"contexts":["fast"]}' \
  --field enforce_admins=true \
  --field 'required_pull_request_reviews={"dismiss_stale_reviews":true,"required_approving_review_count":0}' \
  --field required_linear_history=true \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field restrictions=null
```

This requires:

- PRs for all merges (no required approvals, but stale approvals dismissed on new pushes)
- `fast` status check must pass + branch must be up-to-date before merge
- Linear history (works with repo-level squash-only merges)
- No force pushes, no branch deletion, no admin bypass

Also configure repo-level **merge settings** at github.com → repo → Settings → General → Pull Requests:

- Enable **Allow squash merging** only (disable merge commits and rebase)
- Enable **Allow auto-merge** — lets you queue PRs to merge when branch protection requirements are met (useful for Dependabot PRs)
- Enable **Automatically delete head branches**

> **Note**: this API call requires a PAT with `Administration: write` permission, which the default PAT lacks. Either temporarily add that scope, run the call with an admin-scoped token, or configure manually via the GitHub UI (Settings → Branches).

### Step 25: Run /cso baseline audit

Run `/cso` for infrastructure security audit (last — audits complete setup).

---

## Verification Checklist

After all steps pass, verify:

- [ ] `pnpm turbo run test` passes
- [ ] `pnpm turbo run build` succeeds
- [ ] Push a PR → CI green
- [ ] Vercel preview URL in PR
- [ ] Merge to main → production deploys
- [ ] Sentry receives test error
- [ ] PostHog receives test event
- [ ] `METRICS.md` exists
- [ ] `/cso` baseline passes

## Cleanup

After all items pass, confirm completion with the user. The init tracker at
`/devshop/kit/notes/projects/<name>.md` stays as a permanent record of when
the project was set up and which steps were completed.
