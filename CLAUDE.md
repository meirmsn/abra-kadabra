# CLAUDE.md

## Devshop Conventions

<!-- Auto-loaded via additionalDirectories in settings.json.
     Project repos have their own CLAUDE.md with project-specific context. -->

### Context Loading

Reference docs (living):

- Always loaded: CLAUDE.md (you're reading it)
- For high-level orientation: `kit/docs/OVERVIEW.md`
- Before making decisions (workflow, conventions, architecture): `kit/docs/guide/`
- When implementing features: specs/<name>/spec.md + METRICS.md + DESIGN.md
- Design rationale ("why X?"): `kit/docs/FAQ.md`

Build blueprints (historical after execution):

- When bootstrapping or modifying devshop: `kit/notes/bootstrap/v0-web.md`
- When adding native/mobile: `kit/notes/bootstrap/v+-native.md`

Backlogs: `kit/TODOS.md` (tactical) + `kit/ROADMAP.md` (strategic). Project backlogs: `TODOS.md` + `PRODUCT-ROADMAP.md`.

### Session Start

A `SessionStart` hook (on `startup` and `clear`) automatically injects `README.md`, `BUILD-LOG.md` status, the current branch, and this devshop `CLAUDE.md` into context. It also reads init progress from `/devshop/kit/notes/projects/<name>.md` if bootstrapping is in progress. No manual reads needed — the hook runs `kit/scripts/session-start.sh`. (The devshop CLAUDE.md injection is a workaround for `anthropics/claude-code#22583` — remove when `additionalDirectories` loading is fixed.)

If the user asks you to implement, fix, or continue work (not just answer a question), run `/ak-status` first — it reads `BUILD-LOG.md`, git state, and any active spec to produce a one-paragraph orientation briefing.

### Philosophy

Speed comes from Claude, stability comes from process. The devshop automates the boring parts (test loops, quality gates, deploy) so the human can focus on product decisions.

### Implementation Approach

Default to simple. Pick the boring solution. Tried-and-true over clever. Readable and debuggable over optimal. No fancy patterns unless the simple one genuinely can't do the job.

Depth over speed. When a step or task hits friction, stop and think about what consequences it has for the project or the devshop. A wrong URL means deploys fail. A missing permission means /ship breaks. An undocumented gotcha means the next session wastes time debugging it. Solve the problem and update docs/skills so it doesn't recur. Don't suggest skipping or deferring unless the user asks.

Flag concerns not covered by existing docs or conventions — wait for confirmation before proceeding. Commit per logical change (one task, one fix, one devshop improvement).

**Two repos, two commit flows:**

- **Project commits** go to the project repo (`/workspace`). Use conventional commits (`feat:`, `fix:`, `chore:`, etc.). Branch protection requires PRs.
- **Devshop commits** go to the abra-kadabra repo (`/devshop`). Use conventional commits. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits are automatically in the abra-kadabra working tree — just `cd /devshop && git add && git commit`.

**Devshop shipping flow (no PRs):** The devshop is a single-developer private repo — the pre-commit guards (adversarial review, docs drift, test suite) serve as the quality gate. Use feature branches for grouped work, then rebase onto main and release:

1. `git checkout main && git rebase feat/my-branch` (or ask the user to confirm)
2. `bash kit/scripts/release.sh --bump patch|minor|major` (tags, pushes, creates GitHub release)

See `kit/docs/guide/architecture.md` for the full model, or `kit/docs/MODEL.md` for the conceptual overview.

### Non-Negotiables

- No code without tests — written alongside, never after.
- No code that breaks existing tests — full suite before marking done.
- No code without metrics — every user-facing feature has events in `METRICS.md`.
- Responsive from day one — 375px to 2560px, mobile-first.
- Light/dark theme required — both from launch, theme tokens only.
- Edge functions always validate auth server-side via `getUser()`.
- Auth flow changes always include route protection middleware in the same PR.
- Pre-commit enforcement on every commit, no bypass. See `kit/docs/guide/security.md` for what runs.
- Every devshop tooling change includes doc updates in the same commit. Before committing, review guide docs and README.md for accuracy against your changes. The commit guard will block — update the docs, don't look for workarounds.
- Shared packages export TypeScript source directly — no build step.
- Every non-trivial `.ts`/`.tsx` file under `src/` or `app/` starts with a 3-line header (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has a 1-2 sentence JSDoc. Config files (`*.config.*`, `*.d.ts`) are exempt. `/ak-pre-ship` convention check verifies.
- Do not add formatting rules to ESLint — Prettier owns all formatting. ESLint is for code quality only.
- For full detail on testing philosophy, metrics lifecycle, and backlog routing: see `kit/docs/guide/conventions.md`.

### Known Footguns

- Firewall IP rotation: if a build fails on a network error for an allowed domain, restart the container to re-resolve CDN IPs.
- Never commit directly to main: branch protection requires PRs. Before `git commit`, run `git branch --show-current`. If the result is `main` or `master`, create a branch first: `git checkout -b <type>/<topic>` where `<type>` is `feat`, `fix`, `docs`, or `chore`, and `<topic>` is derived from the work at hand (e.g. `docs/overview-pointers`, `feat/auth`, `fix/session-refresh`). A PreToolUse hook (`check-branch-not-main.sh`) blocks main commits as a safety net, but follow the rule proactively so you don't round-trip through the hook. For pipeline work, `/ak-spec` creates the branch automatically — this guidance covers ad-hoc edits.
- Workflow push requires human: the devcontainer PAT lacks `workflow` scope intentionally. If `git push` fails because a commit touches `.github/workflows/`, ask the human to push: `git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>` (GitHub will prompt for their PAT with workflow scope).
- Never discard unrelated dirty files: when the clean-tree guard flags files you didn't modify (WIP from a previous session), do NOT `git checkout` or `git restore` them — that permanently destroys uncommitted work. Use the bypass: `git -c devshop.dirtyTreeReason="<file> is WIP, committing separately" commit ...` or `git stash push <file>` before committing.
- Pre-push blocks stale PR descriptions / dirty trees / stashes: `.husky/pre-push` blocks `git push` to non-main branches if (a) an open PR's title/body doesn't describe the branch's commits, or (b) the working tree is dirty / has stash entries. Short-circuits: pushes to `main`/`master`, branch deletions, and conventional-commit-only (`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:`) pushes skip the PR-desc LLM review. Bypasses (both adversarially reviewed — generic reasons fail): `git -c devshop.prDescStaleReason="<specific reason>" push ...` for intentionally-lagging PR description (e.g. "batching updates, will squash-update after final rebase"); `git -c devshop.dirtyPushReason="<specific reason>" push ...` for intentional dirty state (e.g. "untracked local log files from debug, not project code"). Parallel to the commit-time `dirtyTreeReason`. See `kit/docs/guide/hooks.md` §3.
- Only `/home/node/.claude` is volume-mounted: state in `~/.config/` (e.g. `~/.config/turborepo/telemetry.json`) resets on every devcontainer rebuild. When configuring a persistent tool opt-out or preference, set it via `containerEnv` in `devcontainer.json` (e.g. `TURBO_TELEMETRY_DISABLED=1`) rather than running a one-time CLI disable command — the env-var form is declarative and rebuild-safe.

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
  - Devshop, fix soon → `kit/TODOS.md`
  - Devshop, build later → `kit/ROADMAP.md`
- **Minor issue** (< 5 min to fix) — fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) — add to `TODOS.md` with `[minor]` tag, continue

### Naming Convention

- `abra-kadabra` = brand name (devshop repo, doc titles). Never used in file names or CLI commands.
- `devshop` = code references (`.claude/skills/devshop/`).
- `kit/` = devshop operational files (docs, scripts, hooks) in the devshop repo. Symlinked as `.devshopkit` in project repos.
- `ak-` = skill prefix for devshop skills (`/ak-build`, `/ak-spec`, `/ak-new-project`, `/ak-migrate-project`, etc.).

### Quick Reference

- Test commands: `pnpm turbo run test:unit` (fast inner loop), `pnpm turbo run test` (full suite).
- Devshop repo layout, dev container setup, persistent storage: see `kit/docs/guide/architecture.md` and `kit/docs/guide/ops.md`.
- Full pipeline and skill maps: see `kit/docs/guide/workflow.md`.

### Claude Code Configuration

`.claude/settings.json` and `.dcg.toml` are root-owned copies (not symlinks) locked by init-devshop.sh — they survive git operations and can't be modified or deleted by node (sticky bit on `.claude/`). Other devshop files are symlinks, including `.hooks/pre-commit` (symlinked to `kit/hooks/pre-commit.sh`). See `kit/docs/guide/security.md` for the full list and rationale. To edit any locked file: `sudo nano <file>`.

Root-owned files can still be staged and committed with `git add` — git only needs read access. Do not assume root-owned means unstage-able.

Custom slash commands go in `.claude/commands/` as Markdown files. Personal overrides go in `.claude/settings.local.json` (gitignored).

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
