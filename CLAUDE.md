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

A `SessionStart` hook (on `startup` and `clear`) injects context that depends on which repo owns the session (`$ROOT = git rev-parse --show-toplevel`):

- **Project session** (cwd is a project repo) — injects project `README.md`, project `BUILD-LOG.md` (head 15, recent ship entries), project `PLAN.md` (`## Active` + `## Planned`), current branch, and `/devshop/CLAUDE.md` (workaround for `anthropics/claude-code#22583` — `additionalDirectories` CLAUDE.md not loaded).
- **Devshop session** (cwd is `/devshop`) — injects devshop `README.md`, `kit/docs/CHANGELOG.md` (head 25, recent releases), current branch. Skips the `/devshop/CLAUDE.md` force-inject because the session cwd's native CLAUDE.md discovery already loads it.

The hook also reads init progress from `/devshop/kit/notes/projects/<name>.md` if bootstrapping is in progress. No manual reads needed — the hook runs `kit/scripts/session-start.sh`.

**Design principle: project `CLAUDE.md` is self-sufficient for public contributors.** Because the SessionStart hook delivers `/devshop/CLAUDE.md` to project sessions at runtime, the project's own committed `CLAUDE.md` does NOT need to mention devshop conventions, point at `/devshop/...` paths, or otherwise reference the devshop side. Project `CLAUDE.md` is **project directives only** — what a public contributor cloning the repo on GitHub sees, with no broken pointers into the private `/devshop` bind mount. The hook bridges the two layers at runtime; the file does not. When tempted to add a `/devshop/CLAUDE.md § X` cross-reference to project `CLAUDE.md`, the rule is: **don't**. Either (a) lift the convention into project-side guidance if it applies project-side, or (b) trust the hook to deliver the devshop context. Skill files (`/ak-new-project § Step 18`) restate this principle at scaffold time so each new project starts in the right shape.

If the user asks you to implement, fix, or continue work (not just answer a question), run `/ak-status` first — it reads `PLAN.md` (forward), `BUILD-LOG.md` (backward), the active branch's `specs/<name>/tasks.md`, and git state to produce a structured briefing plus a "Next up" synthesis when phase is `between features`.

### Philosophy

Speed comes from Claude, stability comes from process. The devshop automates the boring parts (test loops, quality gates, deploy) so the human can focus on product decisions.

### Implementation Approach

Default to simple. Pick the boring solution. Tried-and-true over clever. Readable and debuggable over optimal. No fancy patterns unless the simple one genuinely can't do the job.

Depth over speed. When a step or task hits friction, stop and think about what consequences it has for the project or the devshop. Solve the problem and update docs/skills so it doesn't recur. Don't suggest skipping or deferring unless the user asks.

**Surface devshop-generalizable lessons proactively, before the session ends.** When a session produces non-obvious learnings — skill bug, convention gap, infra flake recipe, template patch, doc-drift the agent caught itself in — name them with proposed devshop placement (skill amendment / template fix / new convention / `kit/ROADMAP.md § v0`/`v1` entry) and let the user pick which to ship now vs file. Don't wait to be prompted. Most sessions produce zero such lessons; that's fine — explicitly say "nothing to surface" rather than trawl. Codified into `/ak-go-live § Step 5b` as the canonical reflection moment for ship-ending sessions; the rule applies to any non-trivial session.

Flag concerns not covered by existing docs or conventions — wait for confirmation before proceeding. Commit per logical change (one task, one fix, one devshop improvement).

**Principle of least privilege** for security-sensitive code paths. Prefer the narrower fix in this order: (1) table-level RLS policy scoped to the role; (2) `SECURITY DEFINER` RPC with explicit auth check inside; (3) service-role escalation in the edge function (last resort). Recipe + worked examples: `kit/docs/guide/security.md § RLS-bypass write fallback ladder`.

### Two repos, two commit flows

- **Project commits** go to the project repo (`/workspace`). Conventional commits. Branch protection requires PRs.
- **Devshop commits** go to the abra-kadabra repo (`/devshop`). Conventional commits. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits are automatically in the abra-kadabra working tree — just `cd /devshop && git add && git commit`.

**Devshop shipping flow (no PRs)** — pre-commit guards are the inner quality gate; audit-time `/ak-check-docs-and-tests` is the outer gate. Three steps:

1. **Branch for anything beyond trivial.** Feature branch (`feat/<topic>`, `fix/<topic>`, etc.). Trivial doc nits may go direct-to-main, but only by a human in a raw terminal — Claude is blocked by `check-branch-not-main.sh`.
2. **Land via `/ak-merge-devshop`.** Audits, squashes ON THE FEATURE BRANCH, then fast-forwards main. Every landed branch becomes one commit on main. Skill owns the format. **Don't run `git merge --ff-only` / `git merge --squash` by hand.** For coordinated devshop+project changes, hold the merge until the project side validates.
3. **Release when a cohesive delta has landed.** `bash kit/scripts/release.sh --bump patch|minor|major` or `/ak-release-devshop`.

**Parallel work via linked worktrees**: `git worktree add .worktrees/<topic> -b <type>/<topic> && git -C .worktrees/<topic> submodule update --init --recursive`. The `.worktrees/` path is gitignored. `session-start.sh` detects devshop worktrees and routes to devshop context. All pre-commit hooks fire identically. **Merging is worktree-aware** — invoke `/ak-merge-devshop` from `/devshop` on `main` and the skill scans `git worktree list --porcelain` for a feature worktree ahead of `origin/main`, squashes via `git -C "$WORKTREE_PATH"`, fast-forwards main, and tears the worktree down after the merge. No manual `git worktree remove` step required. If multiple feature worktrees are in flight, pass `` `--branch <name>` `` to disambiguate.

**Why the submodule step**: `git worktree add` materializes the parent repo's working tree but does NOT recursively check out submodule contents into the new worktree — those directories exist as empty placeholders. The submodule SHAs are already committed in the parent (tracked via `.gitmodules`), so `submodule update --init --recursive` only populates files; nothing new gets committed. Skip the step and any bats test run from the worktree fails with `Could not find '<...>/kit/tests/lib/bats-support/load'` — the bats vendored libraries are git submodules.

Full shipping model: `kit/docs/guide/workflow.md` + `.claude/skills/devshop/merge-devshop/SKILL.md`. Conceptual overview: `kit/docs/OVERVIEW.md § Concept`.

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

**Adversarial Layer 2 reviews fire at audit moments**, not per commit. Per-commit hooks run only Layer 1 (deterministic file-existence math). Layer 2 (Sonnet judgment over the diff) fires when `/ak-check-docs-and-tests` is invoked: first audit when working code is done, second audit before merge. Devshop's audit moment is before each merge to main (inside `/ak-merge-devshop` Phase 1). Both audits append to a single `specs/<feature>/review.md`. Full contract: `kit/docs/guide/hooks.md § Adversarial review` + `kit/docs/guide/hooks.md § Audit moments` + `kit/docs/guide/conventions.md § Bypass trailers`.

For full detail on testing philosophy, metrics lifecycle, and backlog routing: see `kit/docs/guide/conventions.md`.

### Known Footguns

Silent-failure devshop-development traps. Recipe-heavy entries point at the guide doc that owns the recipe; the entry here is the symptom + first-action.

- **Firewall IP rotation** — CDN edges rotate IPs; cached `ipset` goes stale within hours. Most common bite: post-deploy `EHOSTUNREACH` to a project's prod URL. **First action**: `sudo /usr/local/bin/refresh-allowed-ips.sh` for prod URL; for additional domains edit `.devcontainer/firewall-extra-domains` + rebuild. **Don't** re-run `init-firewall.sh` mid-session (stalls). Full recipe + setup + `fakeowner` rationale: `kit/docs/guide/ops.md § Firewall IP rotation`.

- **GH Actions artifact access on pre-2026-04-24 projects** — `productionresultssa*.blob.core.windows.net` was added to the template `init-firewall.sh` on 2026-04-24. Older projects' firewalls lack it — `gh run download` fails with `no route to host`. Diff project's `.devcontainer/init-firewall.sh` against the template; bring in the artifact-host loop; rebuild. Full recipe: `kit/docs/guide/ops.md § GH Actions artifact access`.

- **Verify state before stating it in a user-facing artifact** — PR comments, audit logs, and any other public output asserting "CI green / preview reachable / deploy succeeded" must verify against canonical signal at write-time, not against a proxy or stale assumption. Worked incident: lalista PR 18 (2026-04-25). Full convention + recipe + canonical-signal map: `kit/docs/guide/conventions.md § Verify state before public assertion`.

- **Never commit directly to main** — every change goes through a feature branch. Before `git commit`, run `git branch --show-current`. If `main`/`master`, create a branch first: `git checkout -b <type>/<topic>`. `check-branch-not-main.sh` PreToolUse hook blocks; follow proactively. **Do not propose creating a GitHub PR on devshop** — that's the project workflow; devshop lands via `/ak-merge-devshop`.

- **Workflow push requires human** — the devcontainer PAT lacks `workflow` scope. If `git push` fails on a `.github/workflows/` touch, ask the human to push with their PAT.

- **Never discard unrelated dirty files** — when the clean-tree guard flags files you didn't modify (WIP from a previous session), do NOT `git checkout` / `git restore` them (permanently destroys uncommitted work). Use the bypass: `git -c devshop.dirtyTreeReason="<reason>" commit ...` or `git stash push <file>` first.

- **Operator stashes can vanish silently during `/ak-merge-devshop` flows** — named stashes (operator-made or Claude-autostashed) sometimes disappear from `git stash list` after a merge / push completes, with no explicit `git stash pop` / `git stash drop` ever firing. Lint-staged's pre-commit stash-backup machinery is the leading suspect; root cause is still under investigation. **The data is never lost** — stash commits are durable in the object database as "dangling commits". **First action**: `git fsck --no-reflogs | grep 'dangling commit'`, filter for stash-shaped subjects (`On *` / `WIP on *` / `index on *` / `untracked files on *`), then `git stash apply <full-SHA>`. Full recipe + lint-staged config context: `kit/docs/guide/hooks.md § Practical recipes § Recovering a vanished stash`. **Prevention**: when `/ak-merge-devshop` halts at its dirty-tree pre-flight refusal, commit WIP to a throwaway branch rather than stashing.

- **Pre-push blocks PR text-hygiene failures, dirty trees, stash entries** — `.husky/pre-push` blocks pushes to non-main branches when the PR's reviewer-facing text fails any of three dimensions: (a) **accuracy** — title/body describes ALL commits on the branch; (b) **title readability** — title describes the observable change, ≤72 chars, no internal jargon (per `kit/docs/guide/conventions.md § Commit + PR Text Style`); (c) **body shape** — body leads with `## Product update` (Headline + Detail) followed by `## Engineering details`. Also blocks when the working tree is dirty / has stash entries. The `prTextHygieneReason` reviewer judges (a) AND (b) AND (c) as independent dimensions — FAIL on any. Bypasses (both adversarially reviewed): `git -c devshop.prTextHygieneReason="..."` or `git -c devshop.dirtyPushReason="..."`. Full contract + short-circuits + per-flag reviewer behavior: `kit/docs/guide/hooks.md § 3 — Husky pre-push`.

- **Only `/home/node/.claude` is volume-mounted** — state in `~/.config/` (e.g., `~/.config/turborepo/telemetry.json`) resets on every devcontainer rebuild. When configuring a persistent tool opt-out or preference, set it via `containerEnv` in `devcontainer.json` (e.g., `TURBO_TELEMETRY_DISABLED=1`) rather than running a one-time CLI disable command — the env-var form is declarative and rebuild-safe.

- **Permission-denied paths block Write/Edit AND Bash file-creation** — `.devcontainer/`, `/devshop/template/**`, root-owned `.claude/settings.json` + `.dcg.toml`, `/etc/`, `/usr/local/bin/`. Even `mkdir` / `cat > file` / `tee` is denied. **Don't loop trying alternative tools** when denied — switch to the `/tmp + sudo install` handoff immediately. Full recipe (flat staging, `install -m <mode> -o root -g root`, trigger phrases, why the ownership flags are required): `kit/docs/guide/security.md § Authoring locked files (denied-path recipe)`.

- **Devshop commits fire ONE adversarial reviewer for docs** — check-type `docsReviewed` fires on any staged file in the devshop repo except release artifacts. Expects `git -c devshop.docsReviewed="<per-doc affected/not-affected enumeration with named distinctive phrases for each AFFECTED edit per audit rule 1(a)>"`. The reviewer rejects weak / generic reasons + verifies named phrases against the staged diff. Per-check-type model split (Haiku for rule-application; Sonnet for judgment-heavy / high-blast-radius). Verbal upgrade backdoor: `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=sonnet git ... commit ...`. Full contract + check-type matrix + bypass-flag inventory: `kit/docs/guide/hooks.md § Adversarial review` + `kit/docs/guide/hooks.md § Bypass flags + env hatches`.

- **Browse binary + Playwright browsers can fail in project devcontainers** — two distinct concerns (Bun-drift on the bundled browse binary; missing Chromium in Playwright's cache). Two operator scripts: `/devshop/kit/scripts/rebuild-browse.sh` and `/devshop/kit/scripts/populate-playwright-cache.sh`. Full triage + recipes: `kit/docs/guide/ops.md § Chromium symlink autoheal` + `§ Browse daemon binary drift` + `§ Playwright cache population`.

- **Never edit `.claude/skills/gstack/**`** — gstack is upstream-owned (`github.com/garrytan/gstack`), vendored as a checked-in clone. `/gstack-upgrade § Step 4` (vendored install path) clones a fresh copy, `mv`s the local tree to `.bak`, then `rm -rf`s the backup once `./setup` succeeds — every local edit disappears with NO operator warning. **First action when tempted**: stop. Either file the bug upstream OR design a devshop-side wrapper (kit/script pre-flight, CLAUDE.md instruction, template-side env var) that intercepts the symptom from outside the gstack tree. Worked drop: home-os PR #15 D3/D4 (Chromium fallback + screenshot allow-list extension) shipped briefly inside gstack source on 2026-05-19, then got reverted in `dc18aa3` once this rule was spotted. Full rationale + worked-wrapper-patterns: `CLAUDE.md § gstack`.

- **Prod Supabase service-role key is the highest-blast-radius credential a project owns and must never enter CI.** If it leaks (CI logs, container images, misconfigured workflow step, accidental `echo`), prod is fully compromised — full DB admin via REST, no RLS. Defense-in-depth: (1) CI's `SUPABASE_URL` GH Variable points at the local stack `http://127.0.0.1:54321`; (2) CI's `SUPABASE_SERVICE_ROLE_KEY` is the published local-stack default JWT (admin on a sandbox); (3) `packages/core/src/supabase.ts` exports `assertNotProdUrlInTestEnv`, wired into every `createClient` call site, that throws if `NODE_ENV=test` ever passes the prod URL. Templates ship all three by default as of 2026-04-25; pre-cleanup projects need the migration recipe at `/ak-new-project § Migration: existing project to current credential layout`. Full surface matrix + blast-radius table + access-token-vs-service-role-key comparison: `kit/docs/guide/security.md § CI Credential Isolation` + `/ak-new-project § Security Posture`.

- **`/ak-pre-ship` gates MUST emit a `## Dismissals` section** in each gate's `review.md` entry. Body is either `None` (zero findings dismissed) or a bulleted list with per-bullet `rationale:` fields. Non-`None` invokes `adversarial-review.sh dismissalLog` (check-type #10) which rejects generic / scope-contradicting / no-tracker rationales. Fast-path: dismissals on a `blocked` gate are rejected before the LLM call (`blocked` is tooling-gap signal, not reviewable finding; only legitimate dismissable shape is `blocked (n/a per scope: <reason>)`). LLM-mediated gates (6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa`) MUST emit `pass | findings | blocked` — never `n/a`. Full contract + escape hatch (`DEVSHOP_SKIP_ADVERSARIAL=1`) + timeout (`PRESHIP_ADVERSARIAL_TIMEOUT`): `kit/docs/guide/hooks.md § Dismissal Log` + `.claude/skills/ak-pre-ship/SKILL.md § Outcome semantics`.

- **`devshop.localTestSkipReason` bypasses the `changed-tests-local (ak)` pre-ship gate** — Sonnet-routed adversarial review on the reason via the `localTestSkipReason` check-type. Generic reasons fail; specific per-category rationale + TODOS pointer passes. `devshop.requireHealthyLocalStack` controls preflight's degraded-stack promotion. Full convention + smoke-set glob + wallclock budgets: `kit/docs/guide/conventions.md § Local Pre-Push Test Gates`.

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
- **Minor issue** (< 5 min to fix) — fix in current task's commit, note in commit message
- **Minor issue** (> 5 min to fix) — add to `TODOS.md` with `[minor]` tag, continue

### Closing TODO / ROADMAP entries when a fix ships

The same PR that ships a fix MUST close the tracker entries for it — delete from `kit/ROADMAP.md` / `kit/TODOS.md` / project `TODOS.md`; rewrite docs that described the prior constraint from conditional prose to imperative present tense; unwind every cross-reference in the same PR. Otherwise stale entries get cited as "still pending" in future sessions and recreate the false belief the fix removed. Full convention + worked incident: `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`.

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

`.claude/settings.json` and `.dcg.toml` are root-owned copies (not symlinks) locked by init-devshop.sh — they survive git operations and can't be modified or deleted by node (sticky bit on `.claude/`). Other devshop files are symlinks, including `.hooks/pre-commit`. See `kit/docs/guide/security.md` for the full list. To edit any locked file: `sudo nano <file>`.

Root-owned files can still be staged and committed with `git add` — git only needs read access.

Custom slash commands go in `.claude/commands/`. Personal overrides go in `.claude/settings.local.json` (gitignored).

### gstack

gstack is installed at `.claude/skills/gstack/` and provides a suite of skills for web browsing, QA, planning, and more. It is **third-party, upstream-owned** (`github.com/garrytan/gstack`) — we vendor it as a checked-in clone, not a fork.

**Web browsing**: always use `/browse`. Never use `mcp__claude-in-chrome__*` tools.

**If gstack skills aren't working**, run: `cd .claude/skills/gstack && ./setup`.

**NEVER edit any file under `.claude/skills/gstack/**`.** The vendored-install upgrade path at `.claude/skills/gstack-upgrade § Step 4` clones a fresh copy from upstream, `mv`s the local tree to `.bak`, then `rm -rf`s the backup once `./setup` succeeds — local edits disappear with NO operator warning. Bug fixes / feature requests for gstack code go to the upstream repo (`github.com/garrytan/gstack`). If a gstack symptom is bad enough to need a same-week workaround and we don't have an upstream merge path, design a **devshop-side wrapper** that intercepts the symptom from outside the gstack tree (e.g., a kit/script that pre-flights the gstack invocation, a CLAUDE.md instruction that adjusts the operator's call, a template-side env var that gstack picks up). Worked drop: home-os PR #15 D3/D4 (Chromium fallback + screenshot allow-list extension) were reverted from the home-os-pr15-backfill-fixes bundle (2026-05-19) once this rule was spotted; both shipped as commits, both got reverted in `dc18aa3` rather than ship inside gstack source.

**Review artifacts under `.gstack/projects/` must stay tracked.** Plans, office-hours docs, design HTML, screenshots, approval JSON, and eng-review history are first-class artifacts that belong in git. The template's `.gitignore` ignores `.gstack/projects/**` and re-includes `.md` / `.html` / `.png` / `.json` at any depth so the four reviewable artifact types stay version-tracked while runtime noise (JSONL logs, sessions, analytics, `config.yaml`) stays filtered out. Don't blanket-ignore `.gstack/` without that re-include pattern.

The container's `containerEnv` sets BOTH `GSTACK_HOME` and `GSTACK_STATE_DIR` to `/workspace/.gstack` because gstack has split-brain: CLI binaries honor `GSTACK_STATE_DIR`, SKILL.md preamble bash blocks honor `GSTACK_HOME`. Setting both keeps every artifact under one tree. **Plus** `init-devshop.sh` symlinks `/home/node/.gstack/projects → /workspace/.gstack/projects` so the five gstack skills that hardcode `~/.gstack/projects/$SLUG/...` (`canary`, `ship`, `land-and-deploy`, `plan-ceo-review`, `plan-design-review`) follow the symlink into the same git-tracked tree — closes the last artifact-preservation gap from outside the upstream tree. Full mechanism + backfill recipe for existing projects: `kit/docs/guide/ops.md § gstack runtime state`.

### Design System

Always read `DESIGN.md` before making any visual or UI decisions. All font choices, colors, spacing, and aesthetic direction are defined there. Do not deviate without explicit user approval. In QA mode, flag any code that doesn't match DESIGN.md.
