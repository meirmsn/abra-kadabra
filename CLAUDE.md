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

Depth over speed. When a step or task hits friction, stop and think about what consequences it has for the project or the devshop. A wrong URL means deploys fail. A missing permission means /ship breaks. An undocumented gotcha means the next session wastes time debugging it. Solve the problem and update docs/skills so it doesn't recur. Don't suggest skipping or deferring unless the user asks.

Flag concerns not covered by existing docs or conventions — wait for confirmation before proceeding. Commit per logical change (one task, one fix, one devshop improvement).

**Principle of least privilege** for security-sensitive code paths. When a code path needs more access than its caller's role grants (e.g., an authenticated user needs to write a table that RLS doesn't allow), prefer the narrower fix in this order:

1. **Table-level RLS policy** scoped to the actual role (`to authenticated`, `to anon`). Declarative, auditable in SQL, smallest blast radius.
2. **`SECURITY DEFINER` RPC** with an explicit auth check inside (e.g. `mark_item_bought` style). Use when the operation needs to span tables or violate multiple policies in a controlled way; the in-RPC check stands in for the bypassed RLS.
3. **Service-role escalation in the edge function** (admin client constructed without the user's `Authorization` header). **Last resort** — admin can write any table, not just the one you needed. The escalation moves the security boundary from SQL into application code, which is harder to inspect.

Don't reach for option 3 because option 1 felt like "more work" — a one-line policy in a migration is almost always less code than the function-side workaround, and the long-term audit story is dramatically better. Recent example: lalista PR 5 ("add as new" force-create) needed authenticated users to insert into `items`. First-pass fix was an admin client; correct fix that shipped was migration 011 `items_insert` policy.

**Two repos, two commit flows:**

- **Project commits** go to the project repo (`/workspace`). Use conventional commits (`feat:`, `fix:`, `chore:`, etc.). Branch protection requires PRs.
- **Devshop commits** go to the abra-kadabra repo (`/devshop`). Use conventional commits. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits are automatically in the abra-kadabra working tree — just `cd /devshop && git add && git commit`.

**Devshop shipping flow (no PRs):** The devshop is a single-developer private repo — pre-commit guards (adversarial review, docs drift, release-coverage, test suite) are the quality gate. Three steps:

1. **Branch for anything beyond trivial.** New capability, multi-file refactor, risky tooling change → feature branch (`feat/<topic>`, `fix/<topic>`, etc.). Trivial doc nits may go direct-to-main, but only by a human in a raw terminal — Claude is blocked by the `check-branch-not-main.sh` PreToolUse hook. Scripts that legitimately need main commits (e.g., `release.sh`) wrap them so the outer Bash call doesn't match the hook pattern.

2. **Land with fast-forward or rebase.** `git checkout main && git merge --ff-only feat/my-branch` (or `git rebase feat/my-branch` if divergence). No new commit — just pointer movement. Multiple feature branches can land on main before a release is cut.

   **For coordinated devshop+project changes**, hold the ff-merge until the project side validates. When a devshop change ships paired with a project-side change (template files mirrored to a project, a new convention exercised by a project's PR, a skill update validated by an actual `/ak-build` run), keep the devshop change on its feature branch until the project side proves the pattern works. Then ff-merge devshop. The reflex is "hash out details on the project before integrating to the template" — lalista PR 18's deploy-workflow rollout (2026-04-25) is the case study where ff-merging too early left two follow-up devshop commits patching what could have been one. Solo devshop changes (just a doc edit, just a skill tweak with no project pairing) still ff-merge directly — the rule is scoped to coordinated changes.

3. **Release when a cohesive delta has landed.** Not per commit, not per feature — per meaningful batch that consumers (project repos pinning a devshop version) would want. Mechanism: `bash kit/scripts/release.sh --bump patch|minor|major` or invoke `/ak-release-devshop` for Claude-guided categorization. `release.sh` is atomic: pre-commit failure (tests, adversarial review) rolls back `kit/version` + `CHANGELOG.md` automatically; post-commit failure (tag clash, push error) keeps the commit so retries don't re-trigger expensive adversarial review.

Bump levels: `patch` (bug fix / doc / refactor) · `minor` (new capability, script, skill) · `major` (breaking for consumers).

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

- Firewall IP rotation: if a build fails on a network error for an allowed domain, restart the container to re-resolve CDN IPs. Chromium is exempt from this footgun as of 2026-04-23 — `template/.devcontainer/Dockerfile` apt-installs `chromium + chromium-driver` and `containerEnv` sets `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`, so Playwright never reaches its CDN. Other domains (Vercel, Google Fonts, Supabase) are still subject to ipset staleness; container restart remains the workaround.
- GH Actions artifact access on pre-2026-04-24 projects: `productionresultssa*.blob.core.windows.net` (Azure Blob for GH Actions workflow artifacts) was added to `template/.devcontainer/init-firewall.sh` on 2026-04-24. Older projects' firewalls lack it — `gh run download` fails with `no route to host` (absent from allowlist, not stale IPs). Fix: diff project's `.devcontainer/init-firewall.sh` against `template/.devcontainer/init-firewall.sh`, bring in the artifact-host loop (after the project-domain loop). It reuses `$gh_ranges` from the existing GitHub CIDR fetch — works as-is on standard scripts. Rebuild container. Post-2026-04-24 scaffolds inherit automatically. Required for `/ak-build` Phase 5.4 trace-pull.
- Verify state before stating it in a user-facing artifact. When asserting "CI is green" / "preview reachable" / "deploy succeeded" in a PR comment, audit log, or other public artifact, verify the assertion BEFORE the artifact is written — and verify the **canonical signal**, not a proxy. Examples of canonical-signal-vs-proxy: `gh run view --json conclusion` (canonical) vs "the prior run was green so this one must be too" (assumption); platform bot's `Ready` badge in its PR comment (canonical) vs `curl -sfI <preview-url>` from a locked-down devcontainer (proxy that breaks on firewall/CDN-rotation). Lalista PR 18 (2026-04-25) is the case study: audit + ready-for-review comments were posted against an earlier green CI run while the latest run (for the bookkeeping commit) was still `in_progress` and ultimately failed → public retraction comment. `/ak-build` Phase 5.7 codifies the post-Phase-5.6 CI re-watch; Phase 6's Part B evidence-sweep now reads the platform bot's status comment instead of curl-ing the preview URL. The general rule applies beyond `/ak-build`: any `gh pr comment` / commit body / status update that asserts external state must verify that state at the moment of assertion against its canonical source.
- Never commit directly to main: branch protection requires PRs. Before `git commit`, run `git branch --show-current`. If the result is `main` or `master`, create a branch first: `git checkout -b <type>/<topic>` where `<type>` is `feat`, `fix`, `docs`, or `chore`, and `<topic>` is derived from the work at hand (e.g. `docs/overview-pointers`, `feat/auth`, `fix/session-refresh`). A PreToolUse hook (`check-branch-not-main.sh`) blocks main commits as a safety net, but follow the rule proactively so you don't round-trip through the hook. For pipeline work, `/ak-spec` creates the branch automatically — this guidance covers ad-hoc edits.
- Workflow push requires human: the devcontainer PAT lacks `workflow` scope intentionally. If `git push` fails because a commit touches `.github/workflows/`, ask the human to push: `git -c credential.helper= push https://<github-user>@github.com/<owner>/<repo>.git <branch>` (GitHub will prompt for their PAT with workflow scope).
- Never discard unrelated dirty files: when the clean-tree guard flags files you didn't modify (WIP from a previous session), do NOT `git checkout` or `git restore` them — that permanently destroys uncommitted work. Use the bypass: `git -c devshop.dirtyTreeReason="<file> is WIP, committing separately" commit ...` or `git stash push <file>` before committing.
- Pre-push blocks stale PR descriptions / dirty trees / stashes: `.husky/pre-push` blocks `git push` to non-main branches if (a) an open PR's title/body doesn't describe the branch's commits, or (b) the working tree is dirty / has stash entries. Short-circuits: pushes to `main`/`master`, branch deletions, and conventional-commit-only (`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:`) pushes skip the PR-desc LLM review. Bypasses (both adversarially reviewed — generic reasons fail): `git -c devshop.prDescStaleReason="<specific reason>" push ...` for intentionally-lagging PR description (e.g. "batching updates, will squash-update after final rebase"); `git -c devshop.dirtyPushReason="<specific reason>" push ...` for intentional dirty state (e.g. "untracked local log files from debug, not project code"). Parallel to the commit-time `dirtyTreeReason`. See `kit/docs/guide/hooks.md` §3.
- Only `/home/node/.claude` is volume-mounted: state in `~/.config/` (e.g. `~/.config/turborepo/telemetry.json`) resets on every devcontainer rebuild. When configuring a persistent tool opt-out or preference, set it via `containerEnv` in `devcontainer.json` (e.g. `TURBO_TELEMETRY_DISABLED=1`) rather than running a one-time CLI disable command — the env-var form is declarative and rebuild-safe.
- Devshop commits may fire TWO adversarial reviewers via pre-commit, not one. `docs-drift` fires on **any** staged file in the devshop repo except release artifacts (`kit/docs/CHANGELOG.md` + `kit/version`) — match-all-minus-exclusions, so new tooling surfaces auto-trigger without a hook edit. Expects `git -c devshop.docsVerified="<reason listing which of the 7 top-level docs you reviewed and why each is/isn't affected>"`. `doc-consistency` fires when any `kit/docs/guide/*.md` file (or `CLAUDE.md` at repo root, or `kit/docs/MODEL.md` / `OVERVIEW.md` / `FAQ.md`) is staged and expects `git -c devshop.docSyncReason="<reason explaining cross-file coherence>"`. Both reviewers reject weak / generic reasons — write thorough ones that enumerate each of the seven reference docs (MODEL.md, OVERVIEW.md, guide/{workflow,conventions,hooks,security,ops,architecture}.md, FAQ.md) explicitly. When a commit touches both a reference doc AND other files, both bypass flags are needed in the same `git -c ... -c ... commit` invocation.
- Browse binary + Playwright browsers can fail silently in older project devcontainers. Symptoms when running `/qa-only` / `/design-review` / `/canary` / `/benchmark`: (1) `bun-polyfill.cjs:16: Attempted to assign to readonly property` — workspace's `gstack/browse/dist/browse` was built against an older Bun, recent Bun made `globalThis.Bun` non-writable; (2) "Please run `npx playwright install`" — Playwright doesn't honor `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` when `~/.cache/ms-playwright/` is empty; (3) `playwright install chromium` fails with "Failed to download FFmpeg" — devcontainer firewall blocks Playwright's CDN. Lalista (scaffolded pre-2026-04-23) hits all three; new scaffolds inherit the apt-baked Chromium fix and dodge (2)/(3). Operator fallback recipe: `cd /tmp && bun build --compile /devshop/.claude/skills/gstack/browse/src/cli.ts --outfile /tmp/browse-bin && cp /tmp/browse-bin /workspace/.claude/skills/gstack/browse/dist/browse && chmod +x /workspace/.claude/skills/gstack/browse/dist/browse && cd /workspace/.claude/skills/gstack && bash browse/scripts/build-node-server.sh` (rebuilds workspace browse from devshop source — workspace gstack is dist-only by design). Then either `sudo apt-get install -y chromium chromium-driver` (if not already) and stub the Playwright cache: `mkdir -p ~/.cache/ms-playwright/chromium-1140/chrome-linux && ln -sf /usr/bin/chromium ~/.cache/ms-playwright/chromium-1140/chrome-linux/chrome` (version-dir name varies; check `node_modules/.pnpm/playwright-core@*` for current). The strategic fix (verifiable preflight check, env-var fallback in browse, migration recipe for older devcontainers) is tracked in `kit/ROADMAP.md § Browse binary + Playwright browser availability`.
- Prod Supabase service-role key is the highest-blast-radius credential a project owns and **must never enter CI**. If it leaks (CI logs, container images, misconfigured workflow step, accidental `echo`), prod is fully compromised — full DB admin via REST, no RLS. Defense-in-depth: (1) CI's `SUPABASE_URL` GH Variable points at the local stack `http://127.0.0.1:54321`; (2) CI's `SUPABASE_SERVICE_ROLE_KEY` is the published local-stack default JWT (admin on a sandbox the runner spins up fresh per job); (3) `packages/core/src/supabase.ts` exports `assertNotProdUrlInTestEnv`, wired into every `createClient` call site, that throws if a `NODE_ENV=test` caller ever passes the prod URL. Templates ship all three by default as of 2026-04-25 (devshop feat/security-posture-cleanup); pre-cleanup projects need the migration recipe at `/ak-new-project § Migration: existing project to current credential layout`. Full surface matrix (`.devcontainer/.env` / GH Variables / GH Secrets / Vercel / Supabase auto-inject) + blast-radius table + Variables-vs-Secrets classification rules + access-token-vs-service-role-key comparison (avoid confusing the per-project data-plane JWT with the account-wide control-plane token): `/ak-new-project § Security Posture` and `kit/docs/guide/security.md § CI Credential Isolation`.
- `/ak-pre-ship` gates MUST emit a `## Dismissals` section in each gate's `review.md` entry. Body is either `None` (zero findings dismissed) or a bulleted list with per-bullet `rationale:` fields explaining why each surfaced finding was NOT fixed / escalated. Non-`None` bodies invoke `adversarial-review.sh dismissalLog` (check-type #10) which rejects rationales that are generic, scope-contradicting, or punt to follow-ups without tags. Rejection fails the gate as `findings (N) pending`. Escape hatch: `DEVSHOP_SKIP_ADVERSARIAL=1` env var bypasses ALL adversarial review (commit-time + pre-ship) — intended for tight iteration loops with active human review; never set in CI / release. Per-call timeout for pre-ship dismissalLog reviews is controlled by `PRESHIP_ADVERSARIAL_TIMEOUT=<sec>` (default 120s; commit-guard calls stay at 90s). See `kit/docs/guide/hooks.md § Dismissal Log (pre-ship gate-time adversarial review)` for the full contract.

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
