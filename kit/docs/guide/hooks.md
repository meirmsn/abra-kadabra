# Hooks & Commit Flow

## Claude Code Hooks

Hooks in `.claude/settings.json` guard the development workflow:

| Hook                  | Event                    | Trigger                    | What it does                                                                                                                                                                                                                                                                                                                   |
| --------------------- | ------------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| DCG                   | PreToolUse (all Bash)    | Every Bash command         | Destructive Command Guard — blocks 49+ dangerous patterns (rm -rf, git reset --hard, DROP TABLE, etc.)                                                                                                                                                                                                                         |
| check-hook-bypass     | PreToolUse (Bash)        | `*git*commit*` commands    | Blocks hook bypass: always blocks `core.hooksPath`/`HUSKY=0`/`devshop.humanReviewed`/`DEVSHOP_SKIP_ADVERSARIAL=`, requires `devshop.hookBypassReason` for `--no-verify` (adversarially reviewed, fail-closed on API error)                                                                                                     |
| check-branch-not-main | PreToolUse (Bash)        | `*git*commit*` commands    | Blocks direct commits to `main`/`master` from Claude. Parses `git -C <dir>` and `cd <dir> &&` prefixes to target the right repo. Humans committing from the terminal are unaffected (PreToolUse only intercepts Claude) — so `release.sh` version bumps still work.                                                            |
| check-memory-created  | PreToolUse (Write\|Edit) | Write/Edit to memory paths | Blocks memory file writes — Claude must classify (project → `/workspace/.claude/memory/`, devshop → incorporate into `/devshop/CLAUDE.md`, unclear → ask user) and get confirmation before writing                                                                                                                             |
| session-start.sh      | SessionStart             | New session or `/clear`    | Recreates symlinks if missing, then context for Claude (README, BUILD-LOG latest build, branch, devshop CLAUDE.md) + init progress from devshop notes + cross-repo WIP heads-up (uncommitted/stashed state in either repo) + DEPS-WATCH.md overdue alerts (parked-dependency revisit reminders) + briefing via `systemMessage` |

> PostToolUse Bash workflow hooks are intentionally absent. Workflow nudges that used to fire after `git commit` / `git push` (release reminder, dirty-tree check, PR description review) now live at the **git layer** (`.husky/pre-push`, husky pre-commit guards) or are owned by skills (`/ak-release-devshop`). See [Why workflow nudges live at the git layer](#why-workflow-nudges-live-at-the-git-layer) below for the rationale.

> **Notification hooks** (`Notification`, `Stop`, `UserPromptSubmit` cancel, `PreToolUse` cancel) push alerts to iPhone/Watch/Mac via ntfy.sh when Claude needs input or a task finishes, with 30s debounce to stay quiet during active sessions. Separate concern from the commit-flow guards above. See [notifications.md](notifications.md).

---

## Commit Flow

Three enforcement levels: PreToolUse (Claude Code), pre-commit (husky), and pre-push (husky). PreToolUse exists because git hooks can't prevent their own bypass — `--no-verify` skips all hooks silently. Something outside git must intercept the command first. Pre-push adds push-time checks (no-direct-push-to-main on projects, PR description staleness, dirty-tree / stash) at the git layer so they fire agent-agnostically — see [Why workflow nudges live at the git layer](#why-workflow-nudges-live-at-the-git-layer).

```
1. PreToolUse: dcg  (settings.json hook, all Bash)
   └─ Blocks destructive commands (not relevant for git commit, passes through)

1b. PreToolUse: check-hook-bypass.sh  (settings.json hook, *git*commit*)
    └─ Blocks core.hooksPath/HUSKY=0, requires reason for --no-verify
    └─ WHY: guarantees step 2 (git hooks) can't be skipped

1c. PreToolUse: check-branch-not-main.sh  (settings.json hook, *git*commit*)
    └─ Blocks Claude from committing on main/master (parses git -C and cd &&)
    └─ Humans committing from the terminal pass through (release.sh works)

2. .husky/pre-commit  (git hook, runs 5 steps sequentially)
   ├─ 2a. create-devshop-symlinks.sh   → recreate symlinks if lost by git ops
   ├─ 2b. pnpm exec lint-staged        → ESLint + Prettier on staged files
   ├─ 2c. pnpm turbo run typecheck     → TypeScript check all packages
   ├─ 2d. gitleaks protect --staged    → Secret scan
   └─ 2e. devshop pre-commit guards    → devshop guards (called by absolute path)
          ├─ check-security-files-freshness.sh: settings.json/.dcg.toml present + current → block
          ├─ check-clean-tree.sh: untracked/unstaged files OR stashed changes → block
          ├─ check-manifest.sh: template/ files added/removed → propose manifest update (devshop only)
          ├─ check-exempt-additions.sh (project only): added entries in
          │  .devshop-test-coverage-exempt / .devshop-docs-freshness-exempt → pre-flight
          │  cited paths exist + adversarial review of inline reasons
          ├─ check-test-coverage-project.sh (project only): src ADD without paired test → block
          ├─ check-docs-freshness-project.sh (project only): page/wrapper/event without CLAUDE/METRICS update → block; per-package READMEs + OVERVIEW/ARCHITECTURE opt-in (fire only when file exists at HEAD)
          └─ commit-guard.sh (4 checks, run in this order):
             ├─ mixed-commit: devshop + project files staged together → block
             ├─ docs-reviewed: any devshop file staged (except release artifacts) → reviews ALL docs + cross-file coherence when reference docs staged + rename/move/delete drift sweep (semantic; merged from docs-drift + doc-consistency)
             └─ release-coverage (devshop only): kit/version staged → adversarial
                reviews whether changes since last tag have adequate test coverage
                (semantic); bypass via `devshop.releaseReviewed`

3. Git creates the commit (if pre-commit passed)

4. On eventual `git push`: `.husky/pre-push` (thin wrapper) →
   `.hooks/pre-push` (symlink) → `kit/hooks/pre-push.sh` (unified policy).
   Repo-mode (project vs devshop) detected at runtime; same wrapper, both repos.
   ├─ PROJECT mode (workspace/`/workspace`):
   │   ├─ no-direct-push-to-main → BLOCK (no bypass)
   │   ├─ PR description staleness (devshop.prDescStaleReason)
   │   └─ dirty tree / stash (devshop.dirtyPushReason)
   └─ DEVSHOP mode (`/devshop` itself):
       ├─ push to main/master short-circuits (release.sh territory)
       └─ dirty tree / stash (devshop.dirtyPushReason)
      (PR-desc check skipped — devshop has no PRs)
```

Step 1 is a Claude Code hook (runs before the tool executes). Step 2 is the git pre-commit hook (runs during commit). Step 4 is the git pre-push hook (runs during `git push`, independent of commit). Steps 2a-2d and 4 are all blocking (fail = operation aborted).

---

## Full Hook Chain Detail

Enforcement layers in chronological order. Sections 1 and 2 fire during `git commit`; section 3 fires later, on `git push`:

### 1. Claude PreToolUse (before git runs)

Configured in `.claude/settings.json`.

| Hook                       | What                                                                                                              | Blocking?                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `dcg`                      | Destructive command guard (all Bash)                                                                              | Yes (compiled binary, only mechanism that blocks Bash calls) |
| `check-hook-bypass.sh`     | Blocks `--no-verify`/`core.hooksPath`/`HUSKY=0`/`DEVSHOP_SKIP_ADVERSARIAL=` without adversarially-reviewed reason | Yes (exit 2 on `*git*commit*` match)                         |
| `check-branch-not-main.sh` | Blocks `git commit` when HEAD is `main`/`master`. Parses `git -C <dir>` and `cd <dir> &&` prefixes                | Yes (exit 2 on `*git*commit*` match); terminal humans pass   |

Shell-script PreToolUse hooks block Bash calls by exiting with code 2 and printing the message to stdout — Claude Code surfaces stdout as the block reason. DCG is a compiled binary for performance (it runs on every Bash call, so startup cost matters); the other hooks run only on matched patterns like `*git*commit*`.

The bypass-string regexes in `check-hook-bypass.sh` are anchored to **assignment / env-var-prefix / git-config form**, not bare string matching: `devshop.humanReviewed=` (with `=`), `DEVSHOP_SKIP_ADVERSARIAL=` and `HUSKY=0`/`HUSKY_SKIP=` at start of command, after a shell separator, or after `export`, and `core.hooksPath` only via `git -c <flag>`, `git config <flags> core.hooksPath` (bounded to a single shell command), or `GIT_CONFIG_PARAMETERS=…core.hooksPath`. This lets commit messages and PR-body prose discuss the bypass mechanisms as documentation without tripping the gate. The actual bypass requires one of these load-bearing forms for git or the shell to apply it.

The outer `if: Bash(*git*commit*)` matcher uses substring globbing, so it fires on any command containing both `git` and `commit` — including `gh pr create --body "...git commit..."`. To avoid spurious hook invocations on PR-authoring commands, both `check-hook-bypass.sh` and `check-branch-not-main.sh` apply a **leading-executable whitelist** at the top of the script: env-var assignments (`KEY=value`) at command start are stripped, and the leading executable must be `git` (any path), `cd` (for `cd /foo && git commit` chains), or `export` (for `export VAR=val && git commit` chains) to proceed. Anything else (`gh`, `echo`, `pnpm`, etc.) exits 0 immediately. Bypass strings inside env-var prefixes (`HUSKY=0 git commit`) are still caught — env-vars are stripped to find the leading executable, but the bypass-string regexes inspect the original command. `check-branch-not-main.sh` additionally strips `-c key=val` and `-C dir` flag segments (handling all three quoting forms — bare, single-quoted, double-quoted) before checking for the commit verb; this closes the prior `[^ ]+` regex bug where `git -c devshop.foo="quoted val" commit` failed to match because the regex couldn't resync past the space inside the quoted value.

### 2. Husky pre-commit (during git commit)

Configured in `.husky/pre-commit`.

| Hook                        | What                                       | Blocking?                   |
| --------------------------- | ------------------------------------------ | --------------------------- |
| `pnpm exec lint-staged`     | ESLint + Prettier on staged files          | Yes — both repos            |
| `pnpm turbo run typecheck`  | TypeScript type checking                   | Yes — both repos            |
| `gitleaks protect --staged` | Secret scanning                            | Yes — both repos            |
| `bats kit/tests/`           | Kit tests: scripts + structural invariants | Yes — devshop only          |
| `.hooks/pre-commit`         | Devshop guards (see below)                 | Yes — no-op without devshop |

`.hooks/pre-commit` is gitignored, symlinked to `kit/hooks/pre-commit.sh` (created by `sync/create-devshop-symlinks.sh` for both repos). It detects which repo it's in and calls the appropriate guards.

Guards are split into **deterministic** (auto-pass when condition is met) and **semantic** (always require a review explanation). All bypass reasons are verified by `adversarial-review.sh` — an agent that actively tries to reject the reason. On API error, the review **fails closed** (blocks the commit). Human fallback: `devshop.humanReviewed` flag, but blocked for Claude via PreToolUse hook — only reachable when the human runs the commit directly in the terminal.

| Guard                               | Type                         | What                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Bypass                                                                                     |
| ----------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `check-security-files-freshness.sh` | Deterministic                | settings.json / .dcg.toml present and current vs `template/` source — drift means `init-devshop.sh` failed to refresh or post-commit drift slipped in                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | No bypass — fix with `sudo bash /devshop/kit/scripts/init-devshop.sh`                      |
| `check-clean-tree.sh`               | Deterministic                | Blocks if untracked/unstaged files exist                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | `dirtyTreeReason` — adversarially reviewed                                                 |
| `check-manifest.sh`                 | **Semantic**                 | template/ files added/removed — propose manifest.txt update with reasoning (devshop only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `manifestReviewed` — always required, adversarially reviewed                               |
| `check-test-coverage.sh`            | Deterministic                | New scripts block if no test file; modified scripts warn (devshop only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Add to exempt list with reason, or write tests                                             |
| `check-exempt-additions.sh`         | **Semantic**                 | Additions to `.devshop-test-coverage-exempt` / `.devshop-docs-freshness-exempt` (project only) — pre-flight: any cited covering test/spec path in inline reason must exist on disk; Layer 2: adversarial review judges per-entry specificity                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | No check-specific bypass — improve inline reasons or use `humanReviewed`                   |
| `check-test-coverage-project.sh`    | Deterministic + **Semantic** | Project repo only. Layer 1: new file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` without paired `.test.ts` → block. Source delete with paired test still present → block as orphan. Layer 2: adversarial review judges modify-cases when a bypass reason is given                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `testCoverageReviewed` — adversarially reviewed; or add to `.devshop-test-coverage-exempt` |
| `check-docs-freshness-project.sh`   | Deterministic + **Semantic** | Project repo only. Three trigger groups (see `kit/docs/guide/conventions.md § Project Docs Hierarchy` for the full doc-category framing): **Always-loaded** — new `apps/*/app/**/page.tsx` / `layout.tsx` / `route.ts` / `middleware.ts` and `packages/*/src/api/*.ts` → `CLAUDE.md` must be staged; new `posthog.capture(...)` / `Sentry.captureException(...)` call sites → `METRICS.md` staged. **Foundational repo-root** (opt-in, fires only when target doc exists at HEAD): new user-visible page/layout → `OVERVIEW.md`; new module-map surface (page / route / middleware / function index) → `ARCHITECTURE.md`. **Foundational per-package** (opt-in per package, fires only when target README exists at HEAD): new file under `apps/<x>/`, `packages/<x>/src/`, or `supabase/functions/<x>/` → corresponding per-package `README.md`. Source delete while any doc (CLAUDE / METRICS / OVERVIEW / ARCHITECTURE / per-package READMEs) still references the path → block on stale ref. Layer 2 invokes the unified `adversarial-review.sh docsReviewed` (project branch — same check-type as the devshop-side docs-coverage gate, branched internally on `$GIT_ROOT`) which judges per-doc rationales | `docsReviewed` — adversarially reviewed; or add to `.devshop-docs-freshness-exempt`        |
| `commit-hooks/commit-guard.sh`      |                              |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |                                                                                            |
| └─ `mixed-commit`                   | Deterministic                | Mixed devshop + project files (project repo only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | No bypass — unstage one set                                                                |
| └─ `docs-reviewed`                  | **Semantic**                 | Any devshop file staged (except release artifacts) — single review judges per-doc enumeration of every reference doc shown in the inlined catalog (with named distinctive phrases for each AFFECTED edit, verified via grep-on-diff per rule 1(a)) + cross-file coherence (when reference docs ARE staged) + new-capability docs at the right level + rename/move/delete drift sweep + addition drift sweep. Merged 2026-04-27 from the former `docs-drift` + `doc-consistency` pair; unified with project-side `docsFreshnessProject` 2026-05-01 (one check-type, branches internally on `$GIT_ROOT`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `docsReviewed` — always required, adversarially reviewed                                   |
| └─ `release-coverage`               | **Semantic**                 | Release commit (devshop only) — `kit/version` staged → adversarial reviews coverage                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `releaseReviewed` — justification re-reviewed with diff                                    |

The blocking pre-commit `cross-repo` check (other repo has uncommitted changes → fail) was removed in **v1.20.0**. Its lockstep assumption (one template + one validation project, in dual-goal sessions) only held for v0 dogfooding; in a multi-project world the bypass became the rule rather than the exception. The session-start.sh "cross-repo WIP heads-up" — informational, runs once per session — replaces it as the better fit and is documented above (line 13) and below (line 151 §session-start.sh additive change).

Both repos use the same guard chain. Checks run in the order listed above.

Bypass via `git -c devshop.<key>="<reason>"` works natively in husky. Every bypass reason is verified by an adversarial agent that actively tries to reject it. On API error, the review fails closed (blocks). Human fallback: `git -c devshop.humanReviewed="approve: <assessment>"` — blocked for Claude via PreToolUse, only usable from the terminal. Semantic checks (`docs-reviewed`, `release-coverage`) always run an adversarial review — either of a user-provided reason (`docs-reviewed`) or of the coverage directly (`release-coverage`). Deterministic checks auto-pass when the condition is met.

**Handling WIP files (clean-tree guard):** When the clean-tree guard flags files you didn't modify in this session (WIP from a previous session or the user's in-progress work), NEVER discard them with `git checkout` or `git restore` — that permanently destroys uncommitted work. Instead, use the bypass: `git -c devshop.dirtyTreeReason="<file> is WIP, committing separately" commit ...`. Alternatively, `git stash push <file>` before committing, then `git stash pop` after.

### 3. Husky pre-push (during git push)

Single unified policy at `kit/hooks/pre-push.sh`, symlinked into both repos as `.hooks/pre-push` by `sync/create-devshop-symlinks.sh` (mirrors the `.hooks/pre-commit` pattern documented in §2 above — same gitignored symlink, same auto-recovery). Each repo's `.husky/pre-push` is a tiny husky-shim wrapper that `exec bash .hooks/pre-push "$@"` and contains no policy. Repo mode (project vs devshop) is detected inside the script at runtime by probing whether `kit/` exists at the repo root and is a real directory — the same probe `kit/hooks/pre-commit.sh` uses. The two modes share the dirty-tree check; they diverge on main-push behavior and PR-desc:

**Project mode** (`/workspace` repo — both the wrapper at `template/.husky/pre-push` propagated to every project, and the policy in `kit/hooks/pre-push.sh` under the project branch):

| Check                                 | What                                                                                                                                                                                                                                                                                                                                  | Blocking?                                                                                                                                                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **No direct push to `main`/`master`** | Refuses any push whose `<remote-ref>` is `refs/heads/main` or `refs/heads/master`. Catches direct commits, FF-merges, cherry-picks — every path that lands commits on local main without a PR.                                                                                                                                        | **Yes — no bypass.** Projects deploy via PR-merge → CI → Vercel; there's no `release.sh` equivalent that needs direct-push. The remote enforces the same rule via GitHub branch protection; this hook fails fast. Hotfixes ride a PR. |
| PR description                        | Is the PR title + body current vs all commits on the branch? Skipped when every commit is `chore:` / `docs:` / `style:` / `test:` / `ci:` / `build:` / `perf:` **AND** zero source-file changes (`apps/*/src/`, `packages/*/src/`). Both conditions must hold — a `chore:`-prefixed commit that touches source still fires the check. | Yes — `devshop.prDescStaleReason` adversarially reviewed                                                                                                                                                                              |
| Dirty tree / stash                    | Is the working tree clean? Zero stash entries?                                                                                                                                                                                                                                                                                        | Yes — `devshop.dirtyPushReason` adversarially reviewed                                                                                                                                                                                |

**Devshop mode** (`/devshop` repo — wrapper at `/devshop/.husky/pre-push`, policy in `kit/hooks/pre-push.sh` under the devshop branch):

| Check              | What                                           | Blocking?                                              |
| ------------------ | ---------------------------------------------- | ------------------------------------------------------ |
| Dirty tree / stash | Is the working tree clean? Zero stash entries? | Yes — `devshop.dirtyPushReason` adversarially reviewed |

The PR-description check used to be inlined in `/devshop/.husky/pre-push` as dead code — devshop has no PRs (`release.sh` tags + pushes direct to main), so `gh pr list --head <branch>` always returned empty and the check no-op'd. Under the unified script the PR-desc branch is gated behind project-mode detection; in devshop mode it's skipped entirely (no `gh` invocation at all). The check still lives where PRs actually exist (project mode).

Short-circuits (no review, exit 0):

- **Both:** detached HEAD; branch deletions (zero-sha local).
- **Devshop only:** push to `main`/`master` (release.sh territory).
- **Project only:** push from a feature branch where remote-ref ≠ main/master AND every branch commit has a trivial conventional-prefix (`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:`) AND zero source-file changes (`apps/*/src/`, `packages/*/src/`). The PR-desc check skips; the dirty-tree check still fires. The source-file requirement closes the mis-prefix exploit (a substantive commit labeled `chore:` would otherwise bypass the PR-desc check).

Bypass flags run through the same shared engine as commit-time guards (`kit/scripts/adversarial-review.sh`). Generic reasons (`WIP`, `later`, `fine`) fail; specific structural reasons (`intentionally batching updates until post-rebase — will squash-update after final review`, `stashed feature X to push hotfix Y on unrelated branch`) pass.

Release-side work (`/ak-release-devshop` skill) is invoked manually or by a follow-up skill chain. The old PostToolUse commit-time "remember to run release.sh" reminder was deleted — release is a deliberate decision, not a post-commit nudge.

---

## Practical recipes

Use-case index for the gates documented above. Each recipe links into the reference material rather than duplicating it.

### Doc-only PR

Goal: ship a PR touching only Markdown / docs / non-source files with minimum ceremony.

1. Branch off `main`. Prefix every commit with `docs:` (or `chore:` / `style:` / `test:` / `ci:` / `build:` / `perf:` if more accurate).
2. Commit normally. The project-side pre-commit gates ([§ 2](#2-husky-pre-commit-during-git-commit)) — `check-test-coverage-project` and `check-docs-freshness-project` — only fire on `apps/*/src/` or `packages/*/src/` changes, so a doc-only diff sails through. If an edge case does flag, use `git -c devshop.docsReviewed="<per-doc enumeration>" commit ...` or `git -c devshop.testCoverageReviewed="<why>" commit ...`.
3. Push. The pre-push trivial-commit short-circuit ([§ 3](#3-husky-pre-push-during-git-push)) skips the PR-description review entirely when both conditions hold: every branch commit has a trivial conventional prefix AND zero source-file changes. The dirty-tree check still fires.
4. Open the PR. Squash-merge as usual; Vercel auto-deploys on merge.

If a commit accidentally touches `apps/*/src/` or `packages/*/src/`, the short-circuit drops and the PR-desc check fires — fix the prefix or split the commit, don't reach for a bypass.

### Hotfix

Goal: get a small fix to production fast. There's no `release.sh` equivalent for projects — the no-direct-push-to-main rule on pre-push ([§ 3](#3-husky-pre-push-during-git-push)) and GitHub branch protection both refuse a direct push, so the fast path is still a PR.

1. `git checkout -b hotfix/<short-name> main`.
2. Make the minimum change. One commit, conventional prefix.
3. `git push -u origin hotfix/<short-name>` then `gh pr create`.
4. If a non-essential gate flags something in the way (test-coverage on a one-line guard, docs-freshness on a tiny config tweak), use the relevant `git -c devshop.<flag>="<reason>" commit ...` — adversarially reviewed, so the reason needs to be specific. For genuine emergencies a human at the terminal can use `git -c devshop.humanReviewed="approve: <assessment>" commit ...` to skip the LLM step entirely.
5. Squash-merge → Vercel auto-deploys.

Do NOT try to work around the no-direct-push-to-main rule. It's hard-blocked at the local hook AND at the remote via branch protection — the bypass flags don't apply, by design.

### Committing from the terminal as a human

Goal: commit and push by hand without Claude in the loop. The git hooks run unconditionally; nothing is disabled. What changes is which escape hatches are reachable — the PreToolUse layer ([§ 1](#1-claude-pretooluse-before-git-runs)) only intercepts Claude's `Bash` invocations, so a human at the terminal can use bypass forms Claude can't.

Standard process:

```bash
git add <files>
git commit -m "..."     # husky: lint-staged → typecheck → gitleaks → devshop guards
git push                # husky: no-main-push, PR-desc staleness, dirty-tree
```

Human-only escape hatches (PreToolUse `check-hook-bypass.sh` blocks all three for Claude):

- `git -c devshop.humanReviewed="approve: <your assessment>" commit ...` — bypass any commit guard with no LLM review.
- `DEVSHOP_SKIP_ADVERSARIAL=1 git commit ...` — skip all adversarial reviews for this process. Tight iteration loops only; never CI.
- `git commit --no-verify` — bypass husky entirely. The nuclear option; reach for the targeted bypass flags first. (Claude additionally needs `devshop.hookBypassReason` to use `--no-verify` even with PreToolUse off; humans don't.)

The targeted bypass flags (`devshop.dirtyTreeReason`, `devshop.testCoverageReviewed`, `devshop.docsReviewed`, `devshop.prDescStaleReason`, `devshop.dirtyPushReason`) work identically for humans and Claude — both go through the adversarial reviewer. Full list in [§ 2](#2-husky-pre-commit-during-git-commit) and [§ 3](#3-husky-pre-push-during-git-push). `devshop.docsReviewed` is the unified key for both devshop docs-coverage and project docs-freshness — the script branches internally on `$GIT_ROOT` so the same key serves both surfaces.

Performance notes:

- Pre-commit typecheck runs against the whole repo. On a cold turbo cache it's slow — warm it once with `pnpm turbo run typecheck` before a commit-heavy session and subsequent commits are near-instant.
- gitleaks runs on staged content. False-positives belong in `.gitleaksignore`, not behind `--no-verify`.

---

## Why workflow nudges live at the git layer

The devshop used to have PostToolUse Bash hooks in `.claude/settings.json` for workflow nudges that fired after `git commit` / `git push`:

- **release.sh reminder** — "commit in abra-kadabra → remember to bump version"
- **check-dirty-after-commit.sh** — "tree still dirty after commit, deal with the remaining files"
- **check-pr-description.sh** — "PR open, review title/body vs commits"

They shared an audience problem: **PostToolUse Bash fires in subagents too**. A subagent with a narrow mandate (e.g., `/ak-pre-ship` gates, `/ak-build` phases) has no authority to commit a parent's WIP or edit a parent's PR description. When these hooks fired inside a subagent, the subagent either ignored the nudge (burning tokens deciding each time) or partially complied (acting outside its scope). Neither is correct. The PostToolUse payload does not carry subagent identity — the hook cannot self-detect.

**Git hooks fire at git invocation regardless of which agent ran git.** A subagent that legitimately commits or pushes passes through the same pre-commit + pre-push gates as the parent. Each agent satisfies the gates in its own narrow context. No audience reasoning is baked into the trigger — the gate is agent-agnostic by construction.

Three moves replaced the three audience-confused PostToolUse hooks:

1. **`check-dirty-after-commit.sh`** deleted as redundant with existing husky pre-commit guards (`check-clean-tree.sh` in commit-guard.sh — same dirty-tree concern, commit-time, blocking).
2. **`check-pr-description.sh`** superseded by `.husky/pre-push` "PR description" check — now blocking (was advisory), agent-agnostic, single adversarial review.
3. **Inline release reminder** replaced by the `/ak-release-devshop` skill — invocation is explicit, not post-commit-prompted.

Plus one additive change: `session-start.sh` grew a "cross-repo WIP heads-up" section that warns (non-blocking) at session boundaries if either `/workspace` or `/devshop` has uncommitted or stashed work. Catches WIP left over from a previous session before Claude starts editing over it.

See [kit/notes/roadmap/hook-migration-plan.md](../../notes/roadmap/hook-migration-plan.md) for the investigation, alternatives considered, and migration scope.

**PreToolUse hooks are unchanged.** They enforce agent-agnostic invariants (`dcg`, `check-hook-bypass.sh`, `check-branch-not-main.sh`, `check-memory-created.sh`) — any agent running any `Bash` or `Write`/`Edit` should be intercepted by them. Their audience-correctness was never the problem.

---

## Commit Convention

Both repos use conventional commits (`feat:`, `fix:`, `chore:`, etc.). The `devshop:` prefix is no longer needed — with separate repos, the commit's repo makes the context obvious. The commit guard warns if both types of files are staged together in the project repo — separate them into distinct commits.

## On Push

The `.husky/pre-push` hook runs at the git layer on every `git push`. The wrapper exec's `kit/hooks/pre-push.sh` via the `.hooks/pre-push` symlink (single-source policy, mirrors the pre-commit chain). In **project mode** the script hard-blocks any push whose remote-ref is `refs/heads/main` or `refs/heads/master` with no bypass — projects deploy via PR-merge → CI → Vercel and the remote enforces the same rule via GitHub branch protection. For pushes to feature branches, if there's an open PR and the PR description does not track the commits (excluding trivial conventional-commit-only pushes that don't touch source files), the push is blocked until the description is updated — or the push provides an adversarially-reviewed bypass reason. A third check blocks pushes with a dirty tree or non-empty stash list on the same pass. Branch deletions short-circuit. In **devshop mode** the script skips the no-direct-push-to-main check (release.sh territory) and the PR-desc check (devshop has no PRs); it runs only the dirty-tree / stash check. See §3 above for the full check lists and bypass flag names.

---

## Dismissal Log (pre-ship gate-time adversarial review)

Commit-time guards check that the developer explained bypasses. The pre-ship layer has a parallel concern: each quality gate (`simplify`, `docs-and-tests-review` (ak), `review`, `cso`, `design-review`, `design-conformance` (ak), `qa`, `benchmark`, etc. — `(ak)` marks devshop-native gates, bare names wrap gstack skills) produces an advisory report, and the pipeline used to rubber-stamp "gate said pass" without checking whether the gate silently dismissed findings it surfaced. The Dismissal Log closes that hole.

### Contract (every gate)

Every gate's output MUST include a `## Dismissals` section with exactly one of:

- **Body `None`** — zero findings were worth dismissing. Default for most gate runs.
- **Bulleted list** — one bullet per dismissal with a `rationale:` field (1 line) explaining why the gate chose not to act.

Pre-ship aggregates all gates' Dismissals into a `## Router Summary` block at the top of `review.md`. Every dismissal is the auditable reason a finding did NOT become a pending blocker.

### Adversarial review

When a gate's `## Dismissals` body is non-`None` (scoped parse — `kit/scripts/preship/router-shim.sh is-empty <report>`), pre-ship hands the rationales to `adversarial-review.sh dismissalLog`. The check-type rejects rationales that:

- Are generic (`not critical`, `minor`, `can wait`, `won't fix`)
- Contradict the spec's `## Core user story` (Phase 1 — coming) or `## In scope`
- Punt to TODOS / follow-up without a specific tag or issue reference
- Omit the `rationale:` field entirely

Rejection fails the gate with outcome `findings (N) pending` — the pipeline pauses like any other unresolved finding. The reviewer has the full `review.md` entry + the spec's scope sections as context, so "this is consistent with our scope" claims get checked against the actual scope.

### Convention adherence (CONVENTIONS_TO_INCLUDE inlining)

`adversarial-review.sh` additionally inlines relevant sections of `kit/docs/guide/conventions.md` into the reviewer's context block, keyed by `(check-type, gate-name)`. Bypass-reason authors must demonstrate that the diff or dismissal is **consistent with the inlined rules** — a change that violates an explicit convention rule fails unless the reason explicitly engages that rule's stated rationale.

Beyond convention adherence, the reviewer also enforces rule 4(a)'s **named-edits requirement**: each AFFECTED-doc claim must name a distinctive phrase from the edit that will appear in the staged diff, and the reviewer verifies each named phrase by searching the staged diff for it. A claim of "updated to add X" where X is not visible in the diff FAILS.

How it works:

- A `CONVENTIONS_TO_INCLUDE` map (function `get_conventions_to_inline` in `adversarial-review.sh`) returns the pipe-separated list of `## ` heading names from `conventions.md` to inline for a given check-type. For `dismissalLog`, the map is keyed additionally by gate-name so each gate's review sees only its relevant convention(s). For `docsReviewed`, the map is keyed additionally by `$GIT_ROOT` so the project-side check pulls in `Project Docs Freshness | Project Docs Hierarchy` while the devshop-side check pulls in `Backlog Routing Guide`.
- The `extract_convention_section` helper greps the requested sections out of `conventions.md` and appends them to `CONTEXT` under a `=== Relevant conventions ===` header.
- Rule 7 in the prompt template instructs the reviewer to FAIL when the diff/dismissal violates an explicit rule unless the reason engages the rule's rationale.

Initial map covers: `testCoverage` → Non-Negotiables; `testCoverageProject` → Test Presence | Non-Negotiables; `testReviewSkipReason` → Non-Negotiables | Test Assertion Depth; `docsReviewed` (devshop) → Backlog Routing Guide; `docsReviewed` (project) → Project Docs Freshness | Project Docs Hierarchy; `exemptAddition` → Test Presence | Project Docs Freshness | Project Docs Hierarchy; and `dismissalLog/<gate>` for `qa`, `docs-and-tests-review`, `design-review`, `cso`, `rls-coverage`, `slow-job-lifecycle`, `review`, `metrics-check`.

Extending enforcement:

1. Identify the convention in `conventions.md` (must already exist as a `## ` section).
2. Add the routing entry in `get_conventions_to_inline` (case statement keyed by check-type, with a nested case for `dismissalLog` gate-names).
3. The new section is now inlined for every matching adversarial review — no further code changes needed.

The map is intentionally conservative: only enforce conventions whose violations have been seen in the wild AND whose textual rule is concrete enough for an LLM reviewer to judge against. Aspirational / taxonomic sections (Tier 3 per the audit at `kit/notes/roadmap/conventions-audit-redistribution-2026-04-27.md`) should NOT be inlined.

### Guide-body inlining (GUIDES_TO_INCLUDE)

The devshop-side `docsReviewed` context inlines `kit/docs/guide/*.md` as `## ` headings only — chapter titles without bodies. That's cheap but creates a structural blind spot: the reviewer can see `hooks.md` has a section called "Husky pre-commit (during git commit)" but can't see the bypass table inside it, so historically a new guard's row got missed every time the diff added a guard without also touching the table. The `GUIDES_TO_INCLUDE` map closes that gap.

The map is paired with rule 4(a)'s **named-edits requirement**: when a guide doc lands in the inlined bodies (FULL), the bypass author can cite a specific edit and the reviewer verifies it via grep-on-diff. When a guide doc only appears as headers-only (not in the routed full-body inlines), the reason MUST cite which enumeration was checked and quote the relevant row — header-only context cannot verify table-row presence on the reviewer's behalf.

How it works:

- A `GUIDES_TO_INCLUDE` map (function `get_guides_to_inline` in `adversarial-review.sh`) returns pipe-separated `<abs-path>:<heading-or-FULL>` entries based on the **staged-paths** (not check-type — guide bodies are diff-relevant, not review-relevant). Only fires for `docsReviewed` (devshop branch — project-side `docsReviewed` doesn't have a guide/\* tree yet).
- The same `extract_convention_section` helper extracts `## <heading>` sections, or the full file when marker is `FULL`. Inlined under a `=== Relevant guide doc bodies (selectively inlined based on staged diff) ===` block.
- Rule 1(e) "Addition drift sweep" in the prompt template instructs the reviewer to scan the inlined bodies for structured enumerations (tables / flowcharts / file-maps / lists) and FAIL when the diff adds a structural unit that an enumeration should grow a new entry for.

Initial map covers 3 routes: `kit/scripts/commit-hooks/` / `kit/hooks/` / `kit/scripts/preship/` / `template/.husky/` / `.claude/settings.json` → `hooks.md` (FULL); `template/` / `kit/manifest.txt` / `init-devshop.sh` / `kit/scripts/sync/` → `architecture.md § File lifecycle`; `.devcontainer/` / `init-firewall.sh` → `security.md` (FULL).

Extending: add a route in `get_guides_to_inline` keyed off `grep -qE` on the staged paths. Same conservative bar as the conventions map — only inline guide bodies whose enumerations have caught real drift in the wild. The keyword routing is path-based so it stays generic across check-types and survives convention-doc reorganization.

### Bypass flags + env hatches

| Flag / Env                                         | Purpose                                                                                                                                                                                                                                                                                                                                     | Where it applies                                |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `DEVSHOP_SKIP_ADVERSARIAL=1` (env)                 | Skip ALL adversarial review for this process — intended for tight iteration loops with active human review. Never set in CI / release. **Blocked for Claude** by `check-hook-bypass.sh` PreToolUse — only reachable from a terminal commit by the human operator. Same boundary as `devshop.humanReviewed`.                                 | Every adversarial call (commit-time + pre-ship) |
| `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=<model>` (env) | Force a specific model (`haiku` / `sonnet`) for ALL check-types in this invocation. Use to upgrade a normally-Haiku check for a high-stakes commit. The mechanism is the env var; the operator-facing pattern is "tell Claude `use the upgraded adversarial review for this commit`" and Claude prepends the env var to the git invocation. | Every adversarial call (commit-time + pre-ship) |
| `PRESHIP_ADVERSARIAL_TIMEOUT=<sec>` (env)          | Per-call timeout for `dismissalLog` reviews (default 120s). Commit-time calls use a 180s default (bumped from 90s after PR #25 inlined full guide-doc bodies into `docsReviewed` prompts — sonnet started hitting the prior limit on dense commits). Pre-ship can fire up to N per gate-run and each call's context is denser.              | Only `dismissalLog`                             |
| `devshop.humanReviewed="..."` (git config)         | Fully-human-approved bypass — ONLY reachable from a terminal commit (PreToolUse hook blocks Claude).                                                                                                                                                                                                                                        | All adversarial calls                           |

#### Per-check-type model routing

`adversarial-review.sh` runs different models per check-type — Haiku 4.5 for deterministic rule-application checks (cheap, fast, sufficient) and Sonnet 4.6 for judgment-heavy or high-blast-radius checks (where false-passes compound or are irreversible):

| Model      | Check-types                                                                                                                                                                          | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Haiku 4.5  | `dirtyTreeReason`, `dirtyPushReason`, `manifestReviewed`                                                                                                                             | Pure rule-application: does the reason name specific files? does the manifest decision reasoning hold? False-passes are recoverable (operator notices via downstream symptoms).                                                                                                                                                                                                                                                                                 |
| Sonnet 4.6 | `docsReviewed` (both devshop + project branches), `prDescStaleReason`, `testCoverage`, `testCoverageProject`, `testReviewSkipReason`, `dismissalLog`, `hookBypass`, `exemptAddition` | Errors compound (stale docs feed future sessions; PR descriptions are the canonical reviewer-facing record), require code/spec-scope judgment (testCoverage, dismissalLog, exemptAddition, testReviewSkipReason), or have irreversible failure modes (gitleaks bypass via hookBypass can leak secrets; an unreviewed exempt entry silently disables the upstream gate forever; a thin testReviewSkipReason ships unaudited polish-loop coverage gaps to merge). |

Routing lives in `get_model_for_check_type` near the bottom of `adversarial-review.sh`. Override via `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=sonnet` to upgrade a Haiku check for a high-stakes commit. Operator pattern: ask Claude to "use the upgraded adversarial review" and Claude prepends the env var.

### Shim: structured-output gates

Gates that already emit structured findings get a mechanical dismissal mapping via `kit/scripts/preship/router-shim.sh` — no LLM call for the obvious cases:

- `cso` JSON with `severity: TENTATIVE` → auto-dismissed with rationale `"TENTATIVE per /cso confidence tier (self-verified only)"`. CRITICAL / HIGH / MEDIUM stay as findings.
- `benchmark` metrics within threshold → filtered at the gate itself; no dismissal needed.

The shim's output is a rendered Dismissals body that pre-ship treats like any other gate's — an explicit gate run can still override and invoke adversarial review.

### Forward-compatibility (Phase 4 — deferred)

Today's Dismissal Log entries carry a single `rationale:` field. Phase 4 (Finding Router, not yet landed) will add a `disposition:` field adjacent (`fix-now` | `fix-before-ship` | `TODO` | `spec-amendment` | `ignore`) to route dismissals into concrete actions. Today's entries extend, not migrate — the `rationale:` field stays.

See `/devshop/.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log (every gate, mandatory)` for the full skill-level contract, including the canonical ordered gate list.

### `/ak-build` Phase 5.8 — `testReviewSkipReason`

`adversarial-review.sh` is invoked from one more surface beyond commit-time and pre-ship: `/ak-build` Phase 5.8 (post-pre-ship docs + tests re-audit). When the audit subagent surfaces high-severity findings in `specs/<feature>/review.md` § the latest `## Audit N` section, Phase 5.8 halts. The operator can override by setting the bypass:

```bash
git config devshop.testReviewSkipReason "<per-finding rationale>"
```

…and re-invoking `/ak-build`. The bypass is judged by `adversarial-review.sh testReviewSkipReason` — Sonnet model, with `Non-Negotiables` + `Test Assertion Depth` from `conventions.md` inlined as the rule corpus. The reviewer FAILS the override unless the reason satisfies all four:

1. **Per-finding engagement** — names each high-severity finding (file:line) and explains specifically why shipping without the test is acceptable. Generic "tests are fine" / "audit is overzealous" without per-finding rationale FAILS.
2. **No core-flow dismissal** — a high finding touching the project's primary user verb (sign-in / add / list / bought / equivalent) is categorically NOT acceptable.
3. **Plausible follow-up commitment** (when "will fix later" appears) — names a specific TODOS.md / ROADMAP entry / issue, not a vague intent.
4. **No security-boundary skips** — findings touching auth, RLS, password policy, or other security-relevant assertions cannot be deferred.

The default is REJECT — the audit already weighed signal vs noise; high-severity findings reflect real gaps. The override exists for genuinely-justified ship-now cases (e.g., the test fixture is blocked on infrastructure that lands next week and is tracked in TODOS).

This is the only adversarial-review check-type whose surface isn't a git hook — it fires inside the `/ak-build` skill rather than at commit or push time. The bypass flag and per-check-type model routing are otherwise identical to the rest.
