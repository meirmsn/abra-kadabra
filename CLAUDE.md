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

Backlogs: `kit/TODOS.md` (tactical) + `kit/ROADMAP.md` (strategic). Project backlogs: `TODOS.md` + `PRODUCT-ROADMAP.md`. Friction intake (upstream of the backlogs): `kit/FRICTION-LOG.md` — recurring trip-ups/lessons land here first, then get promoted into ROADMAP/TODOS/PLAN when they earn it. File via `/ak-record-friction-log`.

### Session Start

A `SessionStart` hook (on `startup` and `clear`) injects context that depends on which repo owns the session (`$ROOT = git rev-parse --show-toplevel`):

- **Project session** (cwd is a project repo) — injects project `README.md`, project `BUILD-LOG.md` (head 15, recent ship entries), project `PLAN.md` (`## Active` + `## Planned (vN)`), current branch, and `/devshop/CLAUDE.md` (workaround for `anthropics/claude-code#22583` — `additionalDirectories` CLAUDE.md not loaded).
- **Devshop session** (cwd is `/devshop`) — injects devshop `README.md`, `kit/docs/CHANGELOG.md` (head 25, recent releases), current branch. Skips the `/devshop/CLAUDE.md` force-inject because the session cwd's native CLAUDE.md discovery already loads it.

The hook also reads init progress from `/devshop/kit/notes/projects/<name>.md` if bootstrapping is in progress, and for project sessions compares `.devshop-version` against `/devshop/kit/version` to show a `Sync:` reminder pointing at `/ak-sync-from-devshop` when they differ. The hook runs `kit/scripts/session-start.sh`. Sync-wrapper + `PROPAGATION.md` generation mechanics: `kit/docs/guide/architecture.md § Propagating build tooling updates`.

**Design principle: project `CLAUDE.md` is self-sufficient for public contributors.** Because the SessionStart hook delivers `/devshop/CLAUDE.md` to project sessions at runtime, the project's own committed `CLAUDE.md` does NOT need to mention devshop conventions, point at `/devshop/...` paths, or otherwise reference the devshop side. Project `CLAUDE.md` is **project directives only** — what a public contributor cloning the repo on GitHub sees, with no broken pointers into the private `/devshop` bind mount. The hook bridges the two layers at runtime; the file does not. When tempted to add a `/devshop/CLAUDE.md § X` cross-reference to project `CLAUDE.md`, the rule is: **don't**. Either (a) lift the convention into project-side guidance if it applies project-side, or (b) trust the hook to deliver the devshop context. Skill files (`/ak-new-project § Step 12.6`) restate this principle at scaffold time so each new project starts in the right shape.

If the user asks you to implement, fix, or continue work (not just answer a question), run `/ak-status` first — it reads `PLAN.md` (forward), `BUILD-LOG.md` (backward), the active branch's `specs/<name>/tasks.md`, and git state to produce a structured briefing plus a "Next up" synthesis when phase is `between features`.

### Philosophy

Speed comes from Claude, stability comes from process. The devshop automates the boring parts (test loops, quality gates, deploy) so the human can focus on product decisions.

### Implementation Approach

Default to simple. Pick the boring solution. Tried-and-true over clever. Readable and debuggable over optimal. No fancy patterns unless the simple one genuinely can't do the job.

Depth over speed. When a step or task hits friction, stop and think about what consequences it has for the project or the devshop. Solve the problem and update docs/skills so it doesn't recur. Don't suggest skipping or deferring unless the user asks.

**Surface devshop-generalizable lessons proactively, before the session ends.** When a session produces non-obvious learnings — skill bug, convention gap, infra flake recipe, template patch, doc-drift caught mid-session — name each with a proposed devshop placement and let the user pick ship-now vs file. **For each lesson not shipped now, invoke `/ak-record-friction-log` yourself — don't hand the operator the command — then report what you filed or bumped** (the skill owns dedup / count / promotion-flagging). Most sessions produce zero; say "nothing to surface" rather than trawl. This is the end-of-pipeline reflection beat (canonical moment: `/ak-go-live § Step 5b`; applies to any non-trivial session), NOT the per-PR merge audit (`/ak-merge-devshop` Phase 1.1).

Flag concerns not covered by existing docs or conventions — wait for confirmation before proceeding. Commit per logical change (one task, one fix, one devshop improvement).

**Principle of least privilege** for security-sensitive code paths. Prefer the narrower fix in this order: (1) table-level RLS policy scoped to the role; (2) `SECURITY DEFINER` RPC with explicit auth check inside; (3) service-role escalation in the edge function (last resort). Recipe + worked examples: `kit/docs/guide/security.md § RLS-bypass write fallback ladder`.

### Two repos, two commit flows

- **Project commits** go to the project repo (`/workspace`). Conventional commits. Branch protection requires PRs.
- **Devshop commits** go to the abra-kadabra repo (`/devshop`). Conventional commits. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits are automatically in the abra-kadabra working tree — just `cd /devshop && git add && git commit`.

**Devshop shipping flow (no PRs):** branch for anything beyond trivial (Claude is blocked on `main` by `check-branch-not-main.sh`); run `/ak-build` for the full pipeline — it auto-detects devshop mode for `/devshop` + its linked worktrees via `--git-common-dir`, runs a reduced gate set, then invokes `/ak-merge-devshop` as the transport (or invoke `/ak-merge-devshop` directly for one-line nits); `release.sh --bump patch|minor|major` (or `/ak-release-devshop`) when a cohesive delta lands.

- **Stash-then-commit trips the clean-tree guard.** Pre-commit's clean-tree check counts entries in `git stash list` as part of the dirty-tree signal — a `git stash push` of WIP from a previous session leaves a stash entry whose presence flips the guard to "dirty" even though the working tree itself is now clean. First action when the guard fires on a stash you intentionally left behind: bypass with `git -c devshop.dirtyTreeReason="<specific stash + scope>" commit ...` (the Sonnet-routed `dirtyTreeReason` reviewer accepts named-stash bypasses with rationale; generic "stash exists" fails). **Don't** drop the stash to satisfy the guard — that destroys WIP. See also `§ Known Footguns` "Operator stashes can vanish silently" for the recovery path if a stash disappears later.

**Parallel work via linked worktrees**: `git worktree add .worktrees/<topic> -b <type>/<topic> origin/main && (cd .worktrees/<topic> && pnpm install)` (the vendored bats libs are plain checked-in files, present immediately after `git worktree add` — no submodule init step; the `pnpm install` step regenerates husky's `.husky/_` and populates `node_modules` so pre-commit hooks actually fire in-worktree). `.worktrees/` is gitignored; `session-start.sh` routes worktrees to devshop context. Three load-bearing traps:

- **`origin/main` base is load-bearing** — without it `git worktree add` defaults to /devshop's current HEAD and silently inherits whatever WIP branch /devshop is on (worked bite: `calibration-and-task-phases`, 2026-05-20, picked up a stray commit, caught only at merge). **When Claude creates a worktree and /devshop is on a non-main branch, it MUST `AskUserQuestion` to confirm the base** (default `origin/main`).
- **Pre-commit hooks fire in-worktree only after the recipe's `pnpm install`** — husky's `.husky/_` is gitignored and regenerated only by `pnpm install`, so skipping the recipe's install step leaves an empty `core.hooksPath` and every gate silently no-ops. Run the full recipe (install step included) before trusting an in-worktree commit as gate-verified. (Off-convention worktrees that skipped it are still netted: `/ak-merge-devshop` Phase 2 runs a gitleaks scan on the squash delta — see `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2`.)
- **Merging is worktree-aware** — `/ak-merge-devshop` from `/devshop` on `main` finds the worktree, squashes, ff-merges, tears it down (`--branch <name>` disambiguates multiples).

Full shipping model + worktree/merge mechanics: `kit/docs/guide/workflow.md` + `.claude/skills/devshop/merge-devshop/SKILL.md`. Conceptual overview: `kit/docs/OVERVIEW.md § Concept`.

### Non-Negotiables

LOUD-failure rules (toolchain catches; listed for posture, the hook teaches at violation):

- **No code without tests** — written alongside, never after. (`check-tests-coverage-{project,devshop}.sh`)
- **No code that breaks existing tests** — full suite before marking done. (CI)
- **No code without metrics** — every user-facing feature has events in `METRICS.md`. (`check-docs-coverage-project.sh`)
- **Pre-commit enforcement on every commit, no bypass.** See `kit/docs/guide/security.md` for what runs.
- **Every devshop tooling change includes doc updates in the same commit.** Commit guard blocks; update the docs, don't look for workarounds.

Silent-failure rules (no toolchain catches; must be known upfront):

- **Responsive from day one** — 375px to 2560px, mobile-first.
- **Light/dark theme required** — both from launch, theme tokens only.
- **Edge functions always validate auth server-side via `getUser()`**.
- **Auth flow changes always include route protection middleware in the same PR.**
- **Shared packages export TypeScript source directly** — no build step.
- **Every non-trivial `.ts`/`.tsx` file under `src/` or `app/` starts with a 3-line header** (`// What:` / `// Why:` / `// Does NOT:`). Every exported function has a 1-2 sentence JSDoc. Config files exempt. `/ak-pre-ship` convention check verifies.
- **Do not add formatting rules to ESLint** — Prettier owns all formatting.

**Adversarial Layer 2 reviews fire at audit moments**, not per commit. Per-commit hooks run Layer 1 (deterministic checks) plus a small set of semantic gates that invoke the adversarial reviewer inline (CLAUDE.md classification, bats-skip, hook-bypass). Full contract: `kit/docs/guide/hooks.md § Adversarial review` + `§ Audit moments`.

For full detail on testing philosophy and metrics lifecycle: see `kit/docs/guide/conventions.md`. Backlog routing is covered above in § TODO Protocol.

### Known Footguns

Silent-failure devshop-development traps. Recipe-heavy entries point at the guide doc that owns the recipe; the entry here is the symptom + first-action.

- **Firewall IP rotation** — CDN edges rotate IPs; cached `ipset` goes stale within hours. Most common bite: post-deploy `EHOSTUNREACH` to a project's prod URL. **First action**: `sudo /usr/local/bin/refresh-allowed-ips.sh` for prod URL; for additional domains edit `.devcontainer/firewall-extra-domains` + rebuild. **Don't** re-run `init-firewall.sh` mid-session (stalls). Full recipe + setup + `fakeowner` rationale: `kit/docs/guide/ops.md § Firewall IP rotation`.

- **GH Actions artifact access on pre-2026-04-24 projects** — `productionresultssa*.blob.core.windows.net` was added to the template `init-firewall.sh` on 2026-04-24. Older projects' firewalls lack it — `gh run download` fails with `no route to host`. Diff project's `.devcontainer/init-firewall.sh` against the template; bring in the artifact-host loop; rebuild. Full recipe: `kit/docs/guide/ops.md § GH Actions artifact access`.

- **Verify state before stating it in a user-facing artifact** — PR comments, audit logs, and any other public output asserting "CI green / preview reachable / deploy succeeded" must verify against canonical signal at write-time, not against a proxy or stale assumption. Worked incident: lalista PR 18 (2026-04-25). Full convention + recipe + canonical-signal map: `kit/docs/guide/conventions.md § Verify state before public assertion`.

- **Never commit directly to main** — loud-caught for Claude by `check-branch-not-main.sh` (PreToolUse) + the husky `$CLAUDECODE=1` branch guard (which closes the parallel-session TOCTOU race); humans commit on main unconditionally. Enforcement detail: `kit/docs/guide/hooks.md`. The residual silent trap: **do not propose creating a GitHub PR on devshop** — that's the project workflow; devshop lands via `/ak-merge-devshop`.

- **Workflow push requires human** — the devcontainer PAT lacks `workflow` scope. If `git push` fails on a `.github/workflows/` touch, ask the human to push with their PAT.

- **Never discard unrelated dirty files** — when the clean-tree guard flags files you didn't modify (WIP from a previous session), do NOT `git checkout` / `git restore` them (permanently destroys uncommitted work). Use the bypass: `git -c devshop.dirtyTreeReason="<reason>" commit ...` or `git stash push <file>` first.

- **Phantom "local changes would be overwritten" on rebase (virtiofs)** — on macOS/linuxkit devcontainers, `git rebase` intermittently aborts with `Your local changes ... would be overwritten` on a verifiably clean tree (and sometimes stalls as a "rescheduled pick") — a stat-cache race, not a real diff; the silent risk is mistaking it for a real conflict and abandoning the rebase. **First action** inside an `/ak-merge-devshop` run: nothing — Phase 1.0 auto-handles it via `kit/scripts/virtiofs-rebase.sh` and surfaces only genuine conflicts. For a **manual** `cherry-pick` / `am` (the call-sites the helper does NOT cover), retry inline with `git -c core.checkStat=minimal -c core.trustctime=false <op> <ref>` — flags **inline**, never repo-global. Full recipe + the helper's recovery ladder + exit-code contract: `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0`.

- **Operator stashes can vanish silently during `/ak-merge-devshop` flows** — named stashes sometimes disappear from `git stash list` after a merge / push, with no explicit `pop` / `drop` firing (root cause still under investigation). **The data is never lost** — stash commits survive as dangling commits. **First action**: `git fsck --no-reflogs | grep 'dangling commit'`, filter for stash-shaped subjects, then `git stash apply <full-SHA>`. **Prevention**: when `/ak-merge-devshop` halts at its dirty-tree pre-flight, commit WIP to a throwaway branch rather than stashing. Full recipe: `kit/docs/guide/hooks.md § Practical recipes § Recovering a vanished stash`.

- **Only `/home/node/.claude` is volume-mounted** — state in `~/.config/` (e.g., `~/.config/turborepo/telemetry.json`) resets on every devcontainer rebuild. When configuring a persistent tool opt-out or preference, set it via `containerEnv` in `devcontainer.json` (e.g., `TURBO_TELEMETRY_DISABLED=1`) rather than running a one-time CLI disable command — the env-var form is declarative and rebuild-safe.

- **Permission-denied paths block Write/Edit AND Bash file-creation** — `.devcontainer/`, `/devshop/template/**`, `/devshop/kit/scripts/**` (canonical tree only — worktree copies are intentionally editable), root-owned `.claude/settings.json` + `.dcg.toml`, `/etc/`, `/usr/local/bin/`. Even `mkdir` / `cat > file` / `tee` is denied. **Don't loop trying alternative tools** when denied — switch to the `/tmp + sudo install` handoff immediately. Full recipe (flat staging, `install -m <mode> -o root -g root`, trigger phrases, why the ownership flags are required): `kit/docs/guide/security.md § Authoring locked files (denied-path recipe)`.

- **Browse binary + Playwright browsers can fail in project devcontainers** — two flavors: missing Chromium in Playwright's cache (auto-healed by `init-devshop.sh` on container start; if it still bites, run `bash /devshop/kit/scripts/populate-playwright-cache.sh`) and Bun-drift on the bundled browse binary (`bash /devshop/kit/scripts/rebuild-browse.sh`). Full triage: `kit/docs/guide/ops.md § Chromium symlink autoheal` + `§ Browse daemon binary drift` + `§ Playwright cache population`.

- **Screenshots into `specs/<feature>/hero/` and `.gstack/qa-reports/screenshots/` go through `capture-screenshot.sh`, not `browse screenshot` directly** — gstack's browse daemon rejects writes to `<git-root>/specs/` or `<git-root>/.gstack/` (path allow-list we can't extend at source — gstack is upstream-owned). Use `bash /devshop/kit/scripts/capture-screenshot.sh <final-path> [browse-flags...]` — it screenshots to `/tmp`, then `cp`s to the final path. Full recipe: `kit/docs/guide/ops.md § Hero screenshot — manual capture`.

- **Never edit** `.claude/skills/gstack/**` — gstack is upstream-owned; the `/gstack-upgrade` vendored-install path silently `rm -rf`s local edits with NO operator warning. **First action when tempted**: stop — file the bug upstream OR build a devshop-side wrapper (kit/script pre-flight, CLAUDE.md instruction, template env var) outside the gstack tree. Full rationale + worked drops + wrapper patterns: `§ gstack` below.

- **Prod Supabase service-role key is the highest-blast-radius credential a project owns and must never enter CI.** If it leaks, prod is fully compromised — full DB admin via REST, no RLS. Defense-in-depth (templates ship all three as of 2026-04-25): CI's `SUPABASE_URL` points at the local stack, CI's `SUPABASE_SERVICE_ROLE_KEY` is the sandbox default JWT, and `assertNotProdUrlInTestEnv` (wired into every `createClient`) throws if `NODE_ENV=test` ever sees the prod URL. Pre-cleanup projects need the migration recipe at `/ak-new-project § Migration`. Full surface matrix + blast-radius table: `kit/docs/guide/security.md § CI Credential Isolation`.

- **`devshop.localTestSkipReason` bypasses the `changed-tests-local` pre-ship gate** — Sonnet-reviewed; generic reasons fail. Full convention: `kit/docs/guide/conventions.md § Local Pre-Push Test Gates`.

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

- New database columns/tables
- Auth flow changes
- New third-party API integrations not yet in codebase
- Performance-sensitive code paths
- Security-related logic
- Deletion of existing tests
- New METRICS.md event definitions
- Behavior edge cases on new input-handling paths
- Accessibility + i18n posture for new UI surfaces
- New error / observability surface

Full per-category rationale: `kit/docs/guide/conventions.md § Confidence Calibration`.

### TODO Protocol

- **Blocker** (can't complete task without human input) — stop, add to `TODOS.md` with `[blocked]` tag, mark task `blocked` in tasks.md, ping user
- **Out-of-scope discovery** — route by who cares and urgency, skip, continue:
  - Project, fix soon → `TODOS.md`
  - Project, build later → `PRODUCT-ROADMAP.md`
  - Devshop, fix soon → `kit/TODOS.md`
  - Devshop, build later → `kit/ROADMAP.md`
  - Recurring friction / trip-up / lesson (not yet a committed to-do) → `kit/FRICTION-LOG.md` via `/ak-record-friction-log` (intake; promote to a tracker above when it earns it)
- **Minor issue** (< 5 min to fix) — fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) — add to `TODOS.md` with `[minor]` tag, continue

### Closing TODO / ROADMAP entries when a fix ships

The same PR that ships a fix MUST close the tracker entries for it — delete from `kit/ROADMAP.md` / `kit/TODOS.md` / project `TODOS.md`; rewrite docs that described the prior constraint from conditional prose to imperative present tense; unwind every cross-reference in the same PR; and delete any `kit/FRICTION-LOG.md` entry promoted into that tracker, folding its recurrence history into the `BUILD-LOG.md` entry (the friction log keeps only live observations — no `## Resolved` archive). Otherwise stale entries get cited as "still pending" in future sessions and recreate the false belief the fix removed. Full convention + worked incident: `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`.

### Commit + PR text style

Every commit subject, PR title, and PR body section follows the same readability rule:

- **Subjects + titles** describe the **observable change**, not the implementation detail. ≤ 72 chars.
- **PR body leads with `## Product update`** (`### Headline (user-facing)` + `### Detail (team-facing)` copied verbatim from `spec.md § Product update`), then `## Engineering details` (bullet-led TL;DR + 3-7 bullets at eng grain).
- **Commit bodies + `## Engineering details`** open with a one-sentence TL;DR + 3-7 bullets — each one a concrete user-meaningful unit. No internal jargon.

Self-test: would a teammate scrolling `git log` two months from now know what shipped without opening the diff?

Full rules + examples + routing table: `kit/docs/guide/conventions.md § Commit + PR Text Style`. Product-update authoring contract + downstream routing: `.claude/skills/ak-spec/SKILL.md § Product update`. Squash-specific shape: `.claude/skills/devshop/merge-devshop/SKILL.md`. Pipeline path (Phase 4.1 → Phase 6 Part D verification): `/ak-build` SKILL.md.

### Naming Convention

- `abra-kadabra` = brand name (devshop repo, doc titles). Never used in file names or CLI commands.
- `devshop` = code references (`.claude/skills/devshop/`).
- `kit/` = devshop operational files (docs, scripts, hooks) in the devshop repo. Symlinked as `.devshopkit` in project repos.
- `ak-` = skill prefix for devshop skills (`/ak-build`, `/ak-spec`, `/ak-new-project`, `/ak-migrate-project`, etc.).

### Quick Reference

- Test commands: `pnpm turbo run test:unit` (fast inner loop), `pnpm turbo run test` (full suite).
- Devshop repo layout, dev container setup, persistent storage: `kit/docs/guide/architecture.md` + `kit/docs/guide/ops.md`.
- Full pipeline and skill maps: `kit/docs/guide/workflow.md`.

### Claude Code Configuration

`.claude/settings.json` and `.dcg.toml` are root-owned copies (not symlinks), locked by init-devshop.sh; other devshop files are symlinks. To edit a locked file: `sudo nano <file>`. Root-owned files can still be `git add`-ed (git only needs read access). Full locked-file list + ownership/sticky-bit model: `kit/docs/guide/security.md`.

Custom slash commands go in `.claude/commands/`. Personal overrides go in `.claude/settings.local.json` (gitignored).

### gstack

gstack is installed at `.claude/skills/gstack/` and provides a suite of skills for web browsing, QA, planning, and more. It is **third-party, upstream-owned** (`github.com/garrytan/gstack`) — we vendor it as a checked-in clone, not a fork.

**Web browsing**: always use `/browse`. Never use `mcp__claude-in-chrome__*` tools.

**If gstack skills aren't working**, run: `cd .claude/skills/gstack && ./setup`.

- **NEVER edit** `.claude/skills/gstack/**` — `/gstack-upgrade` silently `rm -rf`s local edits with NO warning. File bugs upstream (`github.com/garrytan/gstack`), or build a **devshop-side wrapper** (kit/script pre-flight, CLAUDE.md instruction, template env var) that intercepts the symptom from outside the gstack tree. Worked drop: home-os PR #15 D3/D4, reverted in `dc18aa3`.
- **`.gstack/projects` artifacts are deliberately git-tracked** — a `.gitignore` re-include keeps plans / design HTML / screenshots / approval JSON version-tracked under an otherwise-ignored tree. Don't blanket-ignore `.gstack/`, and dismiss the `/cso` "`.gstack/` not in `.gitignore`" finding as a false positive (`n/a`).
- **Runtime-state mechanics** — the `.gitignore` re-include pattern, the `GSTACK_HOME`/`GSTACK_STATE_DIR` split-brain, the `~/.gstack/projects` symlink, + the existing-project backfill recipe: `kit/docs/guide/ops.md § gstack runtime state`.

### Design System

Always read `DESIGN.md` before making any visual or UI decisions. All font choices, colors, spacing, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA mode, flag any code that doesn't match DESIGN.md.
