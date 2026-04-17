---
name: ak-new-project
version: 1.0.0
description: |
  Create and set up a new project from the devshop template. Single entry point
  with two phases: Phase A creates a GitHub repo with the template from any
  container. Phase B does interactive setup inside the new project's container.
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

### Step 2: Customize project docs

The template includes `BUILD-LOG.md`, `PRODUCT-ROADMAP.md`, and `README.md` at their
final locations. Customize them in-place:

- **README.md**: already filled with project name and description from Phase A. Verify
  placeholders are replaced. If any `<project-name>` or `<one-line description>` remain, fill them.
- **BUILD-LOG.md**: generic template — no changes needed unless the user wants to customize.
- **PRODUCT-ROADMAP.md**: generic template — ask the user if they have existing roadmap
  items to add, or keep as-is for now.

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

# Sentry
SENTRY_DSN=https://<key>@o<org-id>.ingest.sentry.io/<project-id>
SENTRY_AUTH_TOKEN=<auth-token>

# PostHog
NEXT_PUBLIC_POSTHOG_KEY=<project-api-key>
```

Where to find each:

- Devcontainer root password: pick any password. Enables `sudo` for the human operator.
- GitHub PAT: github.com/settings/tokens → Fine-grained tokens → Generate new token.
  Scope to this repo only. Required permissions:
  - `Contents: Read and write` — push branches and commits
  - `Pull requests: Read and write` — create PRs, merge PRs
  - `Actions: Read` — watch CI status
  - **Do NOT add `workflow` scope** — workflow file changes must be pushed by the human.
- Vercel: `vercel.com/account/tokens`
- Supabase URL + keys: Project Settings → API.
- Supabase access token: `supabase.com/dashboard/account/tokens`
- Sentry DSN: Project Settings → Client Keys. Auth token: Org Settings → Auth Tokens.
- PostHog: Project Settings → Project API key

### Step 5: [HUMAN] Add GitHub Secrets + Variables

Go to repo on github.com → **Settings** → **Secrets and variables** → **Actions**.

**Secrets** tab → **Repository secrets**:

- `VERCEL_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`

All values come from `.devcontainer/.env`.

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
        'SUPABASE_ACCESS_TOKEN','SENTRY_DSN','SENTRY_AUTH_TOKEN',
        'NEXT_PUBLIC_POSTHOG_KEY','GITHUB_TOKEN']
for k in keys:
    v = os.environ.get(k, '')
    status = f'SET (len={len(v)})' if v else 'MISSING'
    print(f'{k}: {status}')
"
```

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
