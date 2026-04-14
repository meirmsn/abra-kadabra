# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

---

## v1 (after v0 is validated on lalista)

### Tiered pre-ship pipeline

Auto-detect change scope and pick a tier:

- **Full** (schema, auth, new API, security): all steps
- **Standard** (UI features, new screens): skip `/cso` and `/benchmark`
- **Light** (bug fixes, styling, docs, config): lint + tests + `/review` + `/ship`

Announce which tier was picked. Override with `--full` or `--light`.

### Weekly pg_dump backup (beyond pre-migration dumps)

Pre-migration `pg_dump` lands in Phase 1c. This v1 item adds a weekly scheduled
backup independent of deploys — catches data corruption that isn't tied to a
migration. GitHub Action cron → `pg_dump` → artifact or private gist.

### Devshop observability — skill invocation log

Each devshop skill appends one line to `.devshop/log.csv`:
timestamp, skill name, duration, outcome (pass/fail/paused), notes.
`/retro` reads it to inform retrospectives with real data instead of opinions.

### Migration rollback integration testing

CI runs migration forward → rollback → re-apply to prove rollback SQL actually
works against real data. Currently only syntax-validated (v0). Full forward+backward
testing catches data-dependent rollback failures.

### Automated service quota monitoring

GitHub Action cron (weekly or monthly) that checks usage against quotas for
Supabase, Sentry, PostHog, GitHub Actions, and Vercel. Warns when usage > 80%.
v0 has manual dashboard links in `.devshop/GUIDE.md`; this automates the check.

### Local integration test alternatives to DinD

v0 uses Docker-in-Docker for `supabase start` inside the devcontainer (16GB+ RAM).
If DinD proves too heavy, evaluate alternatives: host-side Supabase with devcontainer
connecting via `host.docker.internal`, or optimized CI-only workflow.
Full research: `.devshop/notes/integration-test-local-alternatives.md`

### Subagent architecture for `/implement`

v0 uses single-agent implementation (full spec in one context, 1M model).
When context pressure is observed (agent losing track of earlier tasks, hitting
limits on large features), switch to orchestrator + per-task subagents.
Design: main agent manages TASKS.md, spawns subagent per task with task description,
relevant spec sections, hat principles, and a shared context summary file
(`CONTEXT.md`) that grows as tasks complete.
Trigger: when `/implement` starts losing context on features with 10+ tasks.

### Changesets

`@changesets/cli` + `.changeset/config.json` — automated changelog generation in PRs.
Removes manual CHANGELOG maintenance. Each PR includes a changeset file describing
the change; on merge, changesets auto-generates the changelog entry.

### Devshop self-build pipeline

Use the project build machinery (`/ak-build`) for devshop changes themselves.
Currently devshop work is manual: branch, edit, commit with `devshop:` prefix,
push, PR. The project pipeline (spec → implement → quality gates → ship) is
tightly coupled to project conventions (specs/ dir, metrics, responsive/theme
checks) and doesn't fit devshop changes.

**Options (pick at implementation time):**

- **`/ak-devshop-build`** — lighter devshop-specific pipeline: branch → edit →
  commit guard → docs consistency check → push → PR. Reuses `/ship` for the PR
  step. Skips specs, metrics, responsive checks.
- **Mode-aware `/ak-build`** — detect `devshop/` branch prefix → swap in devshop
  conventions (devshop commit prefix, docs drift checks, script tests) instead of
  project ones. Single entry point but more complex.

**Devshop quality gates (different from project):**

- Commit guard passes (no mixed commits)
- Docs consistency (three-way: CLAUDE.md ↔ README ↔ GUIDE)
- Script tests (when they exist — see TODOS.md)
- No responsive/theme/metrics checks

**Trigger:** when devshop changes become frequent enough that the manual
branch-edit-commit-push flow feels like friction.

### CLAUDE.project.md block assembly

Template snippets in `.devshop/templates/claude-blocks/` — one per technology choice
(`supabase.md`, `vercel.md`, `posthog.md`, `sentry.md`, etc.). Each block contains the
env vars, migration commands, file path patterns, and conventions for that tool.

`/ak-init` assembles `CLAUDE.project.md` from the relevant blocks based on which
services are set up (steps 3-6 already know). Same content across all projects using
the same stack; different for projects with different tech choices.

`/document-release` maintains "Where Things Happen" as paths get added post-init.

### Staging migration validation

Local `supabase start` and CI both run migrations against fresh DBs from seed.sql.
Neither tests against production data shapes. Data-dependent migration failures
(NOT NULL on columns with legacy nulls, table locks on large tables) only surface
in production. `-- ROLLBACK` and `pg_dump` are recovery, not prevention.

Options:

- Restore latest pg_dump into temporary local Supabase, run new migration against it
  before deploying (automated in `/post-merge`)
- At minimum, make every migration a "stop and ask" item with human review against
  production schema (already the convention — this automates verification)

### Accessibility testing in E2E (axe-core)

`eslint-plugin-jsx-a11y` already runs via `eslint-config-next`. Add runtime a11y
testing with `@axe-core/playwright` in E2E tests — catches issues that static
analysis misses (dynamic content, focus management, ARIA state). Wire into Playwright
test setup so every E2E page visit runs an axe scan.

Trigger: when the first E2E-testable flow exists (Phase 1e or equivalent).

### Sync script improvements

Current: simple `cp` guided by `manifest.txt` (plus heading-based injection
for `CLAUDE.md` — already in v0). Improve to:

- Diff before overwrite — show what changed, ask for confirmation
- Create PR on the devshop repo instead of direct push
- Conflict detection with abort + diff shown

---

## v+ (future — when the need is felt)

### Native/mobile devshop support

Extend the devshop to support React Native (Expo) apps alongside web. Adds `apps/mobile/`,
EAS CLI, Maestro E2E, mobile Sentry/PostHog, App Store/Play Store deployment.
Full build blueprint: `.devshop/notes/bootstrap/v1-native.md`.

### Fakeowner + Bash bypass hardening

Two known security gaps in the file protection model:

1. **Fakeowner**: Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic — Layer 2 (root ownership) doesn't enforce on these mounts.
2. **Bash bypass**: Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either.

**Current protection (v0):**

1. Deny rules in `settings.json` block Edit/Write tools
2. `init-devshop.sh` chowns files to root on container start (cosmetic on fakeowner)

**Known gap:** Bash commands can modify any file on the fakeowner mount regardless of
displayed ownership. Deny rules only cover Edit/Write tools, not Bash.

**Attempted fix: DCG custom block rules** — added `[overrides] block` patterns in
`.dcg.toml` matching protected filenames. Problem: DCG pattern-matches against the full
command string, so `git add .claude/settings.json` and `git commit` mentioning protected
files in messages trigger false positives. DCG's `allow` override precedence vs pack rules
(e.g., `core.git` blocking `git reset --hard`) is undocumented — blanket git allowlisting
might weaken existing protections. Reverted.

**Option A: DCG with surgical patterns** — instead of filename-only patterns, use
write-verb + filename combos (`> .*settings.json`, `tee .*settings.json`, `python.*settings.json`).
Avoids git false positives but requires enumerating all write verbs — misses novel ones
(`dd`, `perl`, `ruby`, `node -e`, etc.). Weaker net than broad filename matching.

**Option B: Symlink to ext4 volume** — move protected files to `/home/node/.claude/`
(real ext4 Docker named volume where permissions are kernel-enforced), symlink from
workspace. `init-devshop.sh` copies latest from git → volume target, then
`chown root:root` — kernel enforces it. Real protection, not pattern-matching.
Complexity: lifecycle management (git updates must flow through copy step), container
rebuild vs volume persistence timing, Claude Code must follow symlinks for settings
loading (likely works, untested).

**Option C: Custom PreToolUse hook** — a bash script (not DCG) that parses the command
from stdin JSON and checks if it would write to protected paths. More flexible than DCG
patterns, can do path resolution, but same fundamental limitation: pattern matching is
bypassable with sufficient creativity.

**Trigger:** When a Bash bypass is observed in practice (not just theoretical).

### CI slow job expansion

The `slow` job in `.github/workflows/ci.yml` is commented out at scaffold time. It gets
built incrementally, tied to feature milestones. Each expansion lands in the same PR as the
code it tests — no gap between "tests exist" and "CI runs them."

**Trigger 1: First DB-backed feature** (e.g., auth, data queries):

Uncomment the `slow` job (`needs: fast`, `if: github.event_name == 'pull_request'`). Add:

- `supabase/setup-cli` GitHub Action for Supabase CLI
- `supabase start` to spin up local DB stack (GitHub Actions has native Docker — no DinD needed)
- Load `seed.sql` via `psql` against local Supabase Postgres
- Integration test step: `pnpm turbo run test` (runs both unit + integration)
- Type drift check: `supabase gen types typescript` → `git diff --exit-code packages/core/src/supabase.types.ts` → fail if types have drifted from schema
- Rollback SQL validation: for each new migration, extract the `-- ROLLBACK` block and parse it against local Postgres (e.g., `EXPLAIN` wrapper). Fail if syntax is invalid — catches typos before they're needed in an emergency
- Mask secrets: `echo "::add-mask::$SUPABASE_SERVICE_ROLE_KEY"`
- Implementation note: verify which Supabase env vars are actually needed for `supabase start` + `supabase gen types` in CI. Wire only what's confirmed.

**Trigger 2: First E2E-testable flow** (e.g., sign-in → core action → verify):

Add to the `slow` job:

- Install browsers: `npx playwright install --with-deps chromium`
- Build and start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging
- Cache Playwright browsers using lockfile hash

**Additional secrets for slow job**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin access) and `ANTHROPIC_API_KEY` (if edge function integration tests call Anthropic). Add to GitHub Secrets when wiring up the slow job.

**After both expansions**: update branch protection to require `slow` as a required status check alongside `fast`.

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs, Playwright browsers. Cache keys use lockfile hash.

**Expected CI minutes**: ~260 min/month for 10 PRs (20 fast jobs × 4 min + 10 slow jobs × 15 min). GitHub Actions free tier: 2000 min/month.

### Backend alternatives and self-hosting evaluation

Evaluate alternatives to Supabase hosted for cost-conscious multi-project use:

- **Neon + Auth.js + Vercel functions**: free database branching, $0/mo, medium assembly
- **Self-hosted Supabase via Coolify + Hetzner**: ~€15/mo for multiple projects, higher ops burden
- **Backend-agnostic init**: `/ak-init` asks which backend and wires accordingly

Trigger: when monthly Supabase bills exceed ~€15/mo across projects, or when
staging/branching becomes a real bottleneck.

Full research: `.devshop/notes/backend-alternatives-research.md`

### `/rollback` skill

Dedicated skill that: reverts Vercel deployment (`vercel rollback`), warns about
migration state, walks through manual data recovery. Build when you've had your
first production incident and know what the workflow should actually be.

### Visual regression testing

Playwright screenshot comparison for key screens. Store baseline screenshots in
`tests/screenshots/`. CI step compares current vs baseline, fails if diff exceeds
threshold. Catches unintended visual changes that unit tests miss.

### `/ak-migrate` skill

Guided migration from an existing app to the devshop stack (e.g., Swift → React,
Django → Next.js). Archive old code for reference, port design system, set up
backend integration, rebuild screens, full test pass. Reference: lalista Phase 1
execution in `.devshop/notes/bootstrap/v0-web.md` as the first data point for
parametrization. Build after a second migration provides a second data point.

### Parallel implementation loops via worktrees

Two `/implement` sessions running simultaneously on different features using
git worktrees (separate working directories, each on its own branch).

**What it would achieve**: True parallel feature development. Two Claude Code
sessions, each with its own worktree, spec, and task list. Merge when both
are done.

**What it would require**: Worktree management tooling, resource budget (two
sessions + potentially two local Supabase instances), merge conflict strategy
for shared files (tokens.ts, shared components), and a way to coordinate
when both features touch the same package.

**When to build**: When single-loop development feels like a bottleneck — likely
when the app has 10+ screens and features can be cleanly isolated.

### Auto-trigger `/go-live` on PR approval

Currently: user approves PR on GitHub, comes back to terminal, says `/go-live`.
Goal: approving the PR on GitHub automatically triggers merge + deploy + canary +
reflection — no manual second step.

Options to explore: GitHub Actions on `pull_request_review` (approved) that calls
Claude Code remotely, or GitHub auto-merge + a webhook/scheduled agent that detects
newly merged PRs and runs the post-merge pipeline. Lightest option may be GitHub
auto-merge (PR merges when CI passes + approved) combined with a deploy workflow
that runs canary checks — but loses Claude's structured reflection step.

### Devshop testing

Test infrastructure for the devshop itself — scripts, hooks, and sync tooling.
Currently the devshop has no automated tests; correctness relies on manual
verification during use.

#### Hook tests (commit guard)

Automated tests for `devshop-commit-guard.sh` and other commit hooks. Set up
temp git repos, stage specific file combinations, and assert correct blocking
behavior. Key invariant: **no auto-pass** — checks must never silently pass
because the "right" files happen to be co-staged. Every blocking check must
require an explicit reason, regardless of what else is in the commit.

Test cases: mixed commit detection (project repo only), docs drift with/without
co-staged docs, doc consistency with 1/2/3 docs staged, cross-repo dirty state,
bypass flag parsing from stdin JSON, exit code 2 on failure, repo detection.

#### Sync script tests

Tests for `sync-from-devshop.sh` and `sync-to-devshop.sh`. Create two temp
repos, run sync in both directions, verify correct files copied, exclusions
honored, and CLAUDE.md injection works.

#### init-devshop.sh tests

Verify symlinks created, CLAUDE.md assembled correctly, security lockdown
applied, BUILD-LOG.md created when missing, skill symlinks resolve.

### Structured logging for edge functions

Sentry catches crashes. PostHog tracks user actions. Gap: application-level
operational logging. When a user reports "my item didn't appear," you need edge
function logs, query timing, auth flow steps. Supabase has logging but it's not
structured or correlated with user-facing issues.

Consider structured console.log in edge functions with a standard format
(timestamp, request ID, user ID, action, duration). Revisit after first
production debugging session reveals what's actually needed.

### DNS wildcard firewall rules

Current firewall resolves each domain to IPs via `dig` + `ipset`. Every subdomain
needs its own entry (e.g., `sentry.io` and `o123456.ingest.sentry.io` resolve to
different IPs). This works but means more entries to maintain per project.

Alternative: use a DNS-aware proxy (e.g., `squid` or `dnsmasq` with filtering) that
supports wildcards like `*.supabase.co`. Fewer entries, survives subdomain changes.
Trade-off: adds a proxy process and config — more moving parts than the current
plain `iptables` + `ipset` approach.

Trigger: when the firewall domain list grows unwieldy across multiple projects.
