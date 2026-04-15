# CLAUDE.md

## Devshop Conventions

<!-- Auto-loaded via additionalDirectories in settings.json.
     Project repos have their own CLAUDE.md with project-specific context. -->

### Context Loading

Reference docs (living):

- Always loaded: CLAUDE.md (you're reading it)
- For high-level orientation: `.devshop/OVERVIEW.md`
- Before making decisions (workflow, conventions, architecture): `.devshop/GUIDE.md`
- When implementing features: specs/<name>/spec.md + METRICS.md + DESIGN.md

Build blueprints (historical after execution):

- When bootstrapping or modifying devshop: `.devshop/notes/bootstrap/v0-web.md`
- When adding native/mobile: `.devshop/notes/bootstrap/v1-native.md`

### Session Start

A `SessionStart` hook (on `startup` and `clear`) automatically injects `README.md`, the first 15 lines of `BUILD-LOG.md`, the current branch, and this devshop `CLAUDE.md` into context. No manual reads needed — the hook runs `.devshop/scripts/session-start.sh`. (The devshop CLAUDE.md injection is a workaround for `anthropics/claude-code#22583` — remove when `additionalDirectories` loading is fixed.)

If the user asks you to implement, fix, or continue work (not just answer a question), run `/ak-status` first — it reads `BUILD-LOG.md`, git state, and any active spec to produce a one-paragraph orientation briefing. Alternatively, read `BUILD-LOG.md` § Status directly for phase, next step, and blockers.

### Philosophy

Speed comes from Claude, stability comes from process. The devshop automates the boring parts (test loops, quality gates, deploy) so the human can focus on product decisions.

### Implementation Approach

Default to simple. Pick the boring solution. Tried-and-true over clever. Readable and debuggable over optimal. No fancy patterns unless the simple one genuinely can't do the job.

Depth over speed. When a step or task hits friction, stop and think about what consequences it has for the project or the devshop. A wrong URL means deploys fail. A missing permission means /ship breaks. An undocumented gotcha means the next session wastes time debugging it. Solve the problem and update docs/skills so it doesn't recur. Don't suggest skipping or deferring unless the user asks.

Flag concerns not covered by existing docs or conventions — wait for confirmation before proceeding. Commit per logical change (one task, one fix, one devshop improvement).

**Two repos, two commit flows:**

- **Project commits** go to the project repo (`/workspace`). Use conventional commits (`feat:`, `fix:`, `chore:`, etc.).
- **Devshop commits** go to the abra-kadabra repo (`/devshop`). Use conventional commits. Since `.devshop/` is a symlink, edits are automatically in the abra-kadabra working tree — just `cd /devshop && git add && git commit`.

See `.devshop/GUIDE.md § Devshop Separation Architecture` for the full model.

### Non-Negotiables

- No code without tests — written alongside, never after.
- No code that breaks existing tests — full suite before marking done.
- No code without metrics — every user-facing feature has events in `METRICS.md`.
- Responsive from day one — 375px to 2560px, mobile-first.
- Light/dark theme required — both from launch, theme tokens only.
- Edge functions always validate auth server-side via `getUser()`.
- Auth flow changes always include route protection middleware in the same PR.
- Pre-commit enforcement on every commit, no bypass. See GUIDE.md § Security + Quality for what runs.
- Every devshop tooling change includes doc updates in the same commit. Before committing, review GUIDE.md and README.md for accuracy against your changes. The commit guard will block — update the docs, don't look for workarounds.
- Shared packages export TypeScript source directly — no build step.
- For full detail on testing philosophy, metrics lifecycle, and backlog routing: see `.devshop/GUIDE.md § Shared Conventions`.

### Known Footguns

- Firewall IP rotation: if a build fails on a network error for an allowed domain, restart the container to re-resolve CDN IPs.
- Never commit directly to main: branch protection requires PRs. Always create a feature branch first, even for small fixes.
- Workflow push requires human: the devcontainer PAT lacks `workflow` scope intentionally. If `git push` fails because a commit touches `.github/workflows/`, ask the human to push: `git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>` (GitHub will prompt for their PAT with workflow scope).

### Documentation Convention

- Every non-trivial `.ts`/`.tsx` file under `src/` or `app/` starts with a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Write on non-trivial files; `/ak-pre-ship` convention check verifies.
- Every exported function has a 1-2 sentence JSDoc. Internal/private: no doc required.
- Config files (`*.config.*`, `*.d.ts`) are exempt.

### Confidence Calibration

**Proceed autonomously:**

- UI components + their tests
- Extending existing API endpoints
- Bug fixes with clear root cause + confirming test
- Styling / design token changes
- Documentation updates
- Adding new Supabase queries (no schema changes)
- Instrumenting metrics for events already defined in METRICS.md

**Stop and ask (before implementing):**

- New database columns/tables (migrations are hard to reverse)
- Auth flow changes
- New third-party API integrations not yet in codebase
- Performance-sensitive code paths
- Security-related logic — stop before writing, get human sign-off; `/cso` still runs after
- Anything requiring deletion of existing tests
- New metric event definitions (add to METRICS.md requires review)

### TODO Protocol

- **Blocker** (can't complete task without human input) — stop, add to `TODOS.md` with `[blocked]` tag, mark task `blocked` in tasks.md, ping user
- **Out-of-scope discovery** — route by who cares and urgency, skip, continue:
  - Project, fix soon → `TODOS.md`
  - Project, build later → `PRODUCT-ROADMAP.md`
  - Devshop, fix soon → `.devshop/TODOS.md`
  - Devshop, build later → `.devshop/ROADMAP.md`
- **Minor issue** (< 5 min to fix) — fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) — add to `TODOS.md` with `[minor]` tag, continue

### Naming Convention

- `abra-kadabra` = brand name (devshop repo, doc titles). Never used in file names or CLI commands.
- `devshop` = code references (`.devshop/`, `.claude/skills/devshop/`).
- `ak-` = skill prefix for devshop skills (`/ak-build`, `/ak-spec`, `/ak-init`, etc.).

### Devshop Documentation Structure

All devshop docs live in `.devshop/`:

- Overview: `.devshop/OVERVIEW.md` + operational reference: `.devshop/GUIDE.md` + design rationale: `.devshop/FAQ.md`
- Backlogs: `.devshop/TODOS.md` + `.devshop/ROADMAP.md` (grow independently)
- Build blueprints: `.devshop/notes/bootstrap/` (historical after execution)

### Devshop Repo Layout

When working in the devshop repo (`/devshop/`):

- **Root** = repo infrastructure only (config, CI, devcontainer). No content files here.
- **`.devshop/`** = the devshop itself — all docs (CHANGELOG, ROADMAP, TODOS, GUIDE, notes/), scripts, and templates. This is what gets symlinked into project repos.
- **`.claude/`** = Claude Code runtime config (skills, commands, settings). Also symlinked.

Never create CHANGELOG, NOTES, ROADMAP, or other content files at the repo root.

### Build and Deploy

- `/ak-build` — autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify. Say "build it" after autoplan.
- `/ak-go-live` — autonomous deploy: merge → deploy → canary → reflect → notify. Say "land it" after PR review.
- Individual skills (`/ak-spec`, `/ak-implement`, `/ak-pre-ship`) still work standalone.
- Test commands: `pnpm turbo run test:unit` (fast inner loop), `pnpm turbo run test` (full suite).

### Dev Container

The dev container is defined in `.devcontainer/` and requires:

1. API keys and credentials placed in `.devcontainer/.env`
2. Opening in VS Code and selecting **Reopen in Container**

The container runs as the `node` user (non-root). On every start, `init-firewall.sh` runs with sudo to lock down outbound network access before VS Code connects. The firewall uses `iptables` + `ipset` to allowlist outbound traffic — everything else is rejected.

### Claude Code Configuration

`.claude/settings.json` and `.dcg.toml` are root-owned copies (not symlinks) locked by init-devshop.sh — they survive git operations and can't be modified or deleted by node (sticky bit on `.claude/`). Other devshop files are symlinks, including `.hooks/pre-commit` (symlinked to `.devshop/hooks/pre-commit.sh`). See `.devshop/GUIDE.md § Security` for the full list and rationale. To edit any locked file: `sudo nano <file>`.

Custom slash commands go in `.claude/commands/` as Markdown files. Personal overrides go in `.claude/settings.local.json` (gitignored).

### Persistent Storage

Two Docker named volumes survive container rebuilds:

- `/commandhistory` — shell history (bash/zsh)
- `/home/node/.claude` — Claude Code config, sessions, and API key

These volumes are **not** on the host filesystem and are **lost on machine migration**.

### gstack

gstack is installed at `.claude/skills/gstack/` and provides a suite of skills for web browsing, QA, planning, and more.

**Web browsing:** Always use the `/browse` skill for all web browsing. Never use `mcp__claude-in-chrome__*` tools — they are slow, unreliable, and not what this project uses.

**If gstack skills aren't working**, run the following to rebuild the binary and register skills:

```bash
cd .claude/skills/gstack && ./setup
```

**Do NOT add `.gstack/` to .gitignore.** The `.gstack/projects/` directory contains gstack-generated plans (office-hours, eng-review, etc.) that should be tracked in git. If ignoring specific subfolders is needed (e.g. analytics or sessions), ignore those specifically — never the whole `.gstack/` folder.

### Design System

Always read `DESIGN.md` before making any visual or UI decisions. All font choices, colors, spacing, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA mode, flag any code that doesn't match DESIGN.md.

### Code Style

- Do not add formatting rules to ESLint — Prettier owns all formatting. ESLint is for code quality only.
