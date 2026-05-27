# Hooks & Commit Flow

How git hooks, husky chains, and Claude Code's PreToolUse hooks compose to guard the workflow. Pre-commit fires first (Layer 1 quick checks), then pre-push (Layer 2 audit), then `/ak-pre-ship` (Layer 3 gate-time adversarial review). This guide is the canonical reference for the full chain.

## Contents

- [Claude Code Hooks](#claude-code-hooks)
- [Commit Flow](#commit-flow)
- [Full Hook Chain Detail](#full-hook-chain-detail)
- [Practical recipes](#practical-recipes)
- [Why workflow nudges live at the git layer](#why-workflow-nudges-live-at-the-git-layer)
- [Commit Convention](#commit-convention)
- [On Push](#on-push)
- [Dismissal Log (pre-ship gate-time adversarial review)](#dismissal-log-pre-ship-gate-time-adversarial-review)

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

2. .husky/pre-commit  (git hook, runs 7 steps sequentially)
   ├─ 2a. Claude branch guard          → blocks Claude ($CLAUDECODE=1) on main/master
   │       Backstop for 1c — closes TOCTOU race (parallel session can switch branch
   │       between PreToolUse "allow" and git commit). Humans pass through.
   ├─ 2b. create-devshop-symlinks.sh   → recreate symlinks if lost by git ops
   ├─ 2c. pnpm exec lint-staged        → ESLint + Prettier on staged files
   ├─ 2d. pnpm turbo run typecheck     → TypeScript check all packages
   ├─ 2e. gitleaks protect --staged    → Secret scan
   ├─ 2f. bats kit/tests/              → kit tests (devshop only; full suite on main, affected-only on branches)
   └─ 2g. devshop pre-commit guards    → devshop guards (called by absolute path)
          ├─ check-security-files-freshness.sh: settings.json/.dcg.toml present + current → block
          ├─ check-clean-tree.sh: untracked/unstaged files OR stashed changes → block
          ├─ check-manifest.sh: template/ files added/removed → propose manifest update (devshop only)
          ├─ check-port-offset-unique.sh: duplicate supabase_port_offset in kit/notes/projects/*.md → block (devshop only)
          ├─ check-exempt-additions.sh (project only): added entries in
          │  .devshop-test-coverage-exempt / .devshop-docs-freshness-exempt → pre-flight
          │  cited paths exist + adversarial review of inline reasons
          ├─ check-tests-coverage-{project,devshop}.sh: Layer 1 file-pairing for tests
          │  (project: src ADD without paired test → block; devshop: new script without
          │  paired .bats → block). Bypass `devshop.testsCoverageReason` accepts on flag
          │  presence (no LLM call); prepare-commit-msg appends `Tests-Coverage-Bypass:` trailer.
          ├─ check-docs-coverage-{project,devshop}.sh: Layer 1 file-pairing for docs
          │  (project: page/wrapper/event without CLAUDE/METRICS update → block, per-package
          │  READMEs + OVERVIEW/ARCHITECTURE opt-in fire only when file exists at HEAD;
          │  devshop: surface→doc mapping per kit/ROADMAP.md § PR-C § A). Bypass
          │  `devshop.docsCoverageReason` accepts on flag presence (no LLM call);
          │  prepare-commit-msg appends `Docs-Coverage-Bypass:` trailer.
          ├─ check-rollback-prose.sh (project only): staged migration ROLLBACK blocks
          │  scanned for prose lines that would become SQL syntax errors after
          │  ci-rollback-explain.sh strips `-- ` prefixes → block
          └─ commit-guard.sh (1 check after PR-C):
             └─ mixed-commit: devshop + project files staged together → block (project repo only)
   (Layer 2 — `/ak-docs-review` and `/ak-tests-review` — fires at audit time via
    `/ak-check-docs-and-tests`, NOT per commit; PR-C of the audit-time docs+tests
    migration removed the per-commit Layer 2 calls. See `kit/ROADMAP.md § PR-C`.)

2.5. .husky/prepare-commit-msg (git hook, runs after pre-commit, before message finalize)
     └─ append-bypass-trailers.sh: when `devshop.{tests,docs}CoverageReason` is set,
        appends a `Tests-Coverage-Bypass:` / `Docs-Coverage-Bypass:` trailer to the
        commit message via `git interpret-trailers --in-place`. Trailers travel with
        the commit (survive rebase, push, clone) and audit-time `/ak-{docs,tests}-review`
        harvests them as `[bypass-revisit]` findings.

3. Git creates the commit (if pre-commit passed)

4. On eventual `git push`: `.husky/pre-push` (thin wrapper) →
   `.hooks/pre-push` (symlink) → `kit/hooks/pre-push.sh` (unified policy).
   Repo-mode (project vs devshop) detected at runtime; same wrapper, both repos.
   ├─ PROJECT mode (workspace/`/workspace`):
   │   ├─ no-direct-push-to-main → BLOCK (no bypass)
   │   ├─ PR text hygiene: accuracy + title readability + body shape (devshop.prTextHygieneReason)
   │   └─ dirty tree / stash (devshop.dirtyPushReason)
   └─ DEVSHOP mode (`/devshop` itself):
       ├─ push to main/master short-circuits (release.sh territory)
       └─ dirty tree / stash (devshop.dirtyPushReason)
      (PR-desc check skipped — devshop has no PRs; text-hygiene fires at
       squash time inside /ak-merge-devshop Phase 0.4.5 instead, via the
       same adversarial-review.sh engine with DEVSHOP_HYGIENE_SURFACE=squash)
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

| Hook                        | What                                                                                                                                                     | Blocking?                   |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| Claude branch guard         | Blocks Claude (`$CLAUDECODE=1`) from committing on main/master — backstop for PreToolUse `check-branch-not-main.sh`, closes TOCTOU race                 | Yes — Claude only           |
| `pnpm exec lint-staged`     | ESLint + Prettier on staged files                                                                                                                        | Yes — both repos            |
| `pnpm turbo run typecheck`  | TypeScript type checking                                                                                                                                 | Yes — both repos            |
| `gitleaks protect --staged` | Secret scanning                                                                                                                                          | Yes — both repos            |
| `bats kit/tests/`           | Kit tests: scripts + structural invariants (custom progress formatter `kit/hooks/bats-format-progress` + `--report-formatter tap` for pass/fail parsing) | Yes — devshop only          |
| `.hooks/pre-commit`         | Devshop guards (see below)                                                                                                                               | Yes — no-op without devshop |
| `.husky/prepare-commit-msg` | Append bypass trailers when Layer 1 bypass flag set (after pre-commit)                                                                                   | No — message hook           |

`.hooks/pre-commit` is gitignored, symlinked to `kit/hooks/pre-commit.sh` (created by `sync/create-devshop-symlinks.sh` for both repos). It detects which repo it's in and calls the appropriate guards.

**lint-staged config** lives in `package.json` under the top-level `"lint-staged"` key (lint-staged v15+, `^15.0.0` per `devDependencies`):

```json
"lint-staged": {
  "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,css}":   ["prettier --write"]
}
```

Both tasks modify files, so lint-staged's default `stash: true` behavior fires on every pre-commit: a backup of staged + unstaged state is created via `git stash create` and stored under a `refs/lint-staged/*` namespace (lint-staged v15 — distinct from `refs/stash`), then dropped after task success or popped on failure. This backup mechanic is hypothesized to interact with operator stashes — see [§ Practical recipes § Recovering a vanished stash](#recovering-a-vanished-stash).

Guards are split into **deterministic** (auto-pass when condition is met) and **semantic** (always require a review explanation). All bypass reasons are verified by `adversarial-review.sh` — an agent that actively tries to reject the reason. On API error, the review **fails closed** (blocks the commit). Human fallback: `devshop.humanReviewed` flag, but blocked for Claude via PreToolUse hook — only reachable when the human runs the commit directly in the terminal.

| Guard                               | Type                     | What                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Bypass                                                                                                                               |
| ----------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `check-security-files-freshness.sh` | Deterministic            | settings.json / .dcg.toml present and current vs `template/` source — drift means `init-devshop.sh` failed to refresh or post-commit drift slipped in. Self-skips in devshop-self mode (`$WS/kit` is a real dir, not a symlink) — mirrors the same detection in `kit/hooks/pre-commit.sh`, prevents spurious "stale / MISSING" warnings on session start in the devshop devcontainer where `/workspace` and `/devshop` resolve to the same host dir and devshop's own infra (devcontainer.json, .husky hooks) intentionally diverges from `template/`                                                                                                                                                                                                                                                                                                                                                                                         | No bypass — fix with `sudo bash /devshop/kit/scripts/init-devshop.sh`                                                                |
| `check-clean-tree.sh`               | Deterministic            | Blocks if untracked/unstaged files exist                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `dirtyTreeReason` — adversarially reviewed                                                                                           |
| `check-manifest.sh`                 | **Semantic**             | template/ files added/removed — propose manifest.txt update with reasoning (devshop only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `manifestReviewed` — always required, adversarially reviewed                                                                         |
| `check-port-offset-unique.sh`       | Deterministic            | Devshop only. Scans `kit/notes/projects/*.md` for duplicate `supabase_port_offset:` values when a project notes file is staged. Prevents two projects from sharing the same port offset (which causes silent host-port collisions).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | No bypass — fix the duplicate offset                                                                                                 |
| `check-tests-coverage-devshop.sh`   | Deterministic (Layer 1)  | Devshop only. New scripts block if no test file; modified scripts warn. Layer 2 (`/ak-tests-review`) fires at audit time, NOT per commit.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | `testsCoverageReason` — accept on flag presence (no LLM call); trailer recorded for audit                                            |
| `check-docs-coverage-devshop.sh`    | Deterministic (Layer 1)  | Devshop only. Surface→doc mapping per `kit/ROADMAP.md § PR-C § A` — `kit/scripts/commit-hooks/**` → `guide/hooks.md`; `kit/scripts/notify/**` → `guide/notifications.md`; `template/**` → `guide/{architecture,security,ops}.md`; `.claude/skills/**/SKILL.md` → `guide/workflow.md` OR `CLAUDE.md`; etc. Carve-outs: `kit/notes/**`, `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/docs/CHANGELOG.md`, `kit/version`, `kit/tests/**`, `kit/docs/**`. Layer 2 (`/ak-docs-review`) fires at audit time.                                                                                                                                                                                                                                                                                                                                                                                                                                               | `docsCoverageReason` — accept on flag presence (no LLM call); trailer recorded for audit                                             |
| `check-exempt-additions.sh`         | **Semantic**             | Additions to `.devshop-test-coverage-exempt` / `.devshop-docs-freshness-exempt` (project only) — pre-flight: any cited covering test/spec path in inline reason must exist on disk; Layer 2: adversarial review judges per-entry specificity                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | No check-specific bypass — improve inline reasons or use `humanReviewed`                                                             |
| `check-tests-coverage-project.sh`   | Deterministic (Layer 1)  | Project repo only. New file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` without paired `.test.ts` → block. Source delete with paired test still present → block as orphan. Modify without test → WARN. Layer 2 (`/ak-tests-review`) fires at audit time.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `testsCoverageReason` — accept on flag presence (no LLM call); trailer recorded for audit; or add to `.devshop-test-coverage-exempt` |
| `check-docs-coverage-project.sh`    | Deterministic (Layer 1)  | Project repo only. Three trigger groups (see `kit/docs/guide/conventions.md § Project Docs Coverage`): **Always-loaded** — new `apps/*/app/**/page.tsx` / `layout.tsx` / `route.ts` / `middleware.ts` and `packages/*/src/api/*.ts` → `CLAUDE.md` must be staged; new `posthog.capture(...)` / `Sentry.captureException(...)` call sites → `METRICS.md`. **Foundational repo-root / per-package** (opt-in: only when target file exists at HEAD): `OVERVIEW.md` / `ARCHITECTURE.md` / per-package `README.md`. Source delete with stale ref in any doc → BLOCK. **Carve-out**: `specs/*/review.md` + `specs/*/tasks.md` excluded from the analytics-event grep — audit-prose paths quote `posthog.capture` / `Sentry.captureException` as the subject of audit text, not as new call sites; pathspec-scoped so a real call in `apps/` / `packages/` / `supabase/functions/` is still caught. Layer 2 (`/ak-docs-review`) fires at audit time. | `docsCoverageReason` — accept on flag presence (no LLM call); trailer recorded for audit; or add to `.devshop-docs-freshness-exempt` |
| `check-rollback-prose.sh`           | Deterministic            | Project repo only. Scans staged `supabase/migrations/*.sql` files for prose lines in `-- ROLLBACK:` blocks. After `ci-rollback-explain.sh` strips the `-- ` prefix, prose lines (capitalized English words that aren't SQL keywords) become bare text that Postgres rejects with a syntax error. Skips: empty lines, lowercase-starting lines (SQL continuations), special-char starts (`(`, `)`, `'`, `"`, `-`, `*`, digits), recognized SQL keywords, and `noop:` lines (case-insensitive). Worked incident: home-os PR #35 migration 015 — `Restore the migration 006b version (resets card_count only):` caused `ERROR: syntax error at or near "Restore"` in CI.                                                                                                                                                                                                                                                                         | No bypass — fix the prose line                                                                                                       |
| `commit-hooks/commit-guard.sh`      |                          | After PR-C: holds only `mixed-commit` (the docs-reviewed and release-coverage checks both moved to audit-time `/ak-check-docs-and-tests`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |                                                                                                                                      |
| └─ `mixed-commit`                   | Deterministic            | Mixed devshop + project files (project repo only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | No bypass — unstage one set                                                                                                          |
| `check-template-propagation.sh`     | **Nudge** (never blocks) | Project repo only. After all blocking guards pass, scans staged files against `[sync]`-tagged manifest entries. For each match with a counterpart at `/devshop/template/<file>`, prints a one-line nudge: "📦 `<file>` → `/devshop/template/<file>`" with the suggestion to run `.devshopkit/scripts/sync/to-devshop.sh`. Skips `[scaffold-once]` (intentionally project-owned), `[symlink]` (auto-propagates via symlink), `[locked]` (project can't edit). Honors `!`-exclusions in manifest. Closes the propagation gap where project-side fixes to shared tooling (e.g. `.github/workflows/`, `.husky/`, `turbo.json`) drift from the template — home-os PR #15's ci.yml fixes are the case study.                                                                                                                                                                                                                                        | No bypass — soft nudge, exit 0 always                                                                                                |

The blocking pre-commit `cross-repo` check (other repo has uncommitted changes → fail) was removed in **v1.20.0**. Its lockstep assumption (one template + one validation project, in dual-goal sessions) only held for v0 dogfooding; in a multi-project world the bypass became the rule rather than the exception. The session-start.sh "cross-repo WIP heads-up" — informational, runs once per session — replaces it as the better fit and is documented above (line 13) and below (line 151 §session-start.sh additive change).

Both repos use the same guard chain. Checks run in the order listed above.

Bypass via `git -c devshop.<key>="<reason>"` works natively in husky. Surviving semantic-bypass-reason flags (`dirtyTreeReason`, `dirtyPushReason`, `manifestReviewed`, `prTextHygieneReason`, `hookBypass`, `exemptAddition`, `testReviewSkipReason`, `localTestSkipReason`) are verified by `adversarial-review.sh` — an agent that actively tries to reject the reason. On API error, the review fails closed (blocks). Human fallback: `git -c devshop.humanReviewed="approve: <assessment>"` — blocked for Claude via PreToolUse, only usable from the terminal.

Layer 1 docs/tests-coverage flags (`testsCoverageReason`, `docsCoverageReason`) work differently after PR-C — they accept on flag presence with no LLM call, and the `prepare-commit-msg` hook appends a `Tests-Coverage-Bypass:` / `Docs-Coverage-Bypass:` trailer to the commit message. Audit-time `/ak-{docs,tests}-review` harvests trailers from the commit range and surfaces each one as a `[bypass-revisit]` finding (VERIFIED / DEFER / ESCALATE per the diff at audit time). Deterministic checks auto-pass when the condition is met.

See § Bypass trailers in `kit/docs/guide/conventions.md` for the full convention (trailer keys, audit-time consumption, and the rationale for trailers vs side-log).

**Handling WIP files (clean-tree guard):** When the clean-tree guard flags files you didn't modify in this session (WIP from a previous session or the user's in-progress work), NEVER discard them with `git checkout` or `git restore` — that permanently destroys uncommitted work. Instead, use the bypass: `git -c devshop.dirtyTreeReason="<file> is WIP, committing separately" commit ...`. Alternatively, `git stash push <file>` before committing, then `git stash pop` after.

### 3. Husky pre-push (during git push)

Single unified policy at `kit/hooks/pre-push.sh`, symlinked into both repos as `.hooks/pre-push` by `sync/create-devshop-symlinks.sh` (mirrors the `.hooks/pre-commit` pattern documented in §2 above — same gitignored symlink, same auto-recovery). Each repo's `.husky/pre-push` is a tiny husky-shim wrapper that `exec bash .hooks/pre-push "$@"` and contains no policy. Repo mode (project vs devshop) is detected inside the script at runtime by probing whether `kit/` exists at the repo root and is a real directory — the same probe `kit/hooks/pre-commit.sh` uses (incrementally migrating to `kit/scripts/sync/lib/detect-mode.sh`'s `is_devshop_self_mode` helper, which adds a `DEVSHOP_FORCE_MODE=project|devshop-self|auto` env override so bats tests can simulate either mode without filesystem trickery). The two modes share the dirty-tree check; they diverge on main-push behavior and PR-desc:

**Project mode** (`/workspace` repo — both the wrapper at `template/.husky/pre-push` propagated to every project, and the policy in `kit/hooks/pre-push.sh` under the project branch):

| Check                                 | What                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Blocking?                                                                                                                                                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **No direct push to `main`/`master`** | Refuses any push whose `<remote-ref>` is `refs/heads/main` or `refs/heads/master`. Catches direct commits, FF-merges, cherry-picks — every path that lands commits on local main without a PR.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | **Yes — no bypass.** Projects deploy via PR-merge → CI → Vercel; there's no `release.sh` equivalent that needs direct-push. The remote enforces the same rule via GitHub branch protection; this hook fails fast. Hotfixes ride a PR. |
| PR text hygiene                       | Three independent dimensions, all judged on every non-trivial push: (a) is the PR title + body current vs all commits on the branch (accuracy)? (b) does the PR title describe the **observable change** (not the implementation mechanism), ≤72 chars, no internal jargon (readability)? (c) does the body lead with `## Product update` (Headline + Detail sub-sections, or the collapsed combined form) followed by `## Engineering details` per `kit/docs/guide/conventions.md § Commit + PR Text Style`? Pure-infra PRs may use `Infrastructure update — no user-visible change in this PR.` as the Headline. Skipped when every commit is `chore:` / `docs:` / `style:` / `test:` / `ci:` / `build:` / `perf:` **AND** zero source-file changes (`apps/*/src/`, `packages/*/src/`). Both conditions must hold — a `chore:`-prefixed commit that touches source still fires the check. | Yes — `devshop.prTextHygieneReason` adversarially reviewed; FAIL on any dimension.                                                                                                                                                    |
| Dirty tree / stash                    | Is the working tree clean? Zero stash entries?                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Yes — `devshop.dirtyPushReason` adversarially reviewed                                                                                                                                                                                |

**Devshop mode** (`/devshop` repo — wrapper at `/devshop/.husky/pre-push`, policy in `kit/hooks/pre-push.sh` under the devshop branch):

| Check                                                | What                                                                                                                                                                                                                                                                                                                                                  | Blocking?                                                                                                                      |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Feature-branch push to `main` requires approval flag | When on a feature branch and the remote ref is `refs/heads/main`, requires `devshop.pushToMainApproved` with an adversarially-reviewed reason naming the `/ak-merge-devshop` ceremony. Pushes from `main` itself (release.sh) short-circuit before this. Error message says "run /ak-merge-devshop" — does NOT print the bypass flag (no self-serve). | Yes — `devshop.pushToMainApproved` adversarially reviewed (Sonnet). Only passes when reason names `/ak-merge-devshop Phase 3`. |
| Dirty tree / stash                                   | Is the working tree clean? Zero stash entries?                                                                                                                                                                                                                                                                                                        | Yes — `devshop.dirtyPushReason` adversarially reviewed                                                                         |

The PR-description check used to be inlined in `/devshop/.husky/pre-push` as dead code — devshop has no PRs (`release.sh` tags + pushes direct to main), so `gh pr list --head <branch>` always returned empty and the check no-op'd. Under the unified script the PR-desc branch is gated behind project-mode detection; in devshop mode it's skipped entirely (no `gh` invocation at all). The check still lives where PRs actually exist (project mode).

**Devshop text-hygiene fires at squash time, not push time.** Devshop commits collapse to squash commits inside `/ak-merge-devshop`'s Phase 0.4.5; the same `adversarial-review.sh prTextHygieneReason` engine that judges project PR titles at pre-push time judges the squash subject + body before the operator's approval gate. Selection is via the `DEVSHOP_HYGIENE_SURFACE=squash` env switch — the squash surface reads subject + body from `DEVSHOP_HYGIENE_MESSAGE_FILE` (the tempfile Phase 0.3 composed) and constituent commits from `origin/main..$DEVSHOP_HYGIENE_BRANCH`; it judges rules (a) accuracy and (b) title readability but SKIPS rule (c) body-structure because devshop squashes use the bold-led-bullet + `## Squashed commits` shape from `.claude/skills/devshop/merge-devshop/SKILL.md § 0.3`, not the project-PR `## Product update` + `## Engineering details` H2 shape. The reviewer's verdict is surfaced in Phase 0.5's approval gate, where "Approve anyway" is the explicit override (logged as a `Hygiene-Override:` trailer in the squash commit body).

Short-circuits (no review, exit 0):

- **Both:** detached HEAD; branch deletions (zero-sha local).
- **Devshop only:** push to `main`/`master` **from the `main` branch** (release.sh territory). Feature-branch pushes targeting main require the `devshop.pushToMainApproved` flag.
- **Project only:** push from a feature branch where remote-ref ≠ main/master AND every branch commit has a trivial conventional-prefix (`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:`) AND zero source-file changes (`apps/*/src/`, `packages/*/src/`). The PR-desc check skips; the dirty-tree check still fires. The source-file requirement closes the mis-prefix exploit (a substantive commit labeled `chore:` would otherwise bypass the PR-desc check).
- **Project only — SHA-enumeration fast path:** PR-desc check skips when every commit SHA in `origin/main..HEAD` appears as a literal string in the PR body (full SHA OR any ≥7-char abbreviation; Git's default minimum). The body is up-to-date by construction in this case, so the LLM reviewer would PASS — short-circuit saves the round-trip. Reviewer still fires on judgment cases (partial-SHA matches, commit-subject-overlap, missing SHAs, empty body). Codified into `kit/hooks/pre-push.sh § Check 2` Check 2 by the `home-os-skill-polish-batch § B3` ship (2026-05-20); test coverage at `kit/tests/util-pre-push.bats § B3`.

Bypass flags run through the same shared engine as commit-time guards (`kit/scripts/adversarial-review.sh`). Generic reasons (`WIP`, `later`, `fine`) fail; specific structural reasons (`intentionally batching updates until post-rebase — will squash-update after final review`, `stashed feature X to push hotfix Y on unrelated branch`) pass.

Release-side work (`/ak-release-devshop` skill) is invoked manually or by a follow-up skill chain. The old PostToolUse commit-time "remember to run release.sh" reminder was deleted — release is a deliberate decision, not a post-commit nudge.

---

## Practical recipes

Use-case index for the gates documented above. Each recipe links into the reference material rather than duplicating it.

### Doc-only PR

Goal: ship a PR touching only Markdown / docs / non-source files with minimum ceremony.

1. Branch off `main`. Prefix every commit with `docs:` (or `chore:` / `style:` / `test:` / `ci:` / `build:` / `perf:` if more accurate).
2. Commit normally. The project-side pre-commit gates ([§ 2](#2-husky-pre-commit-during-git-commit)) — `check-tests-coverage-project` and `check-docs-coverage-project` — only fire on `apps/*/src/` or `packages/*/src/` changes, so a doc-only diff sails through. If an edge case does flag, use `git -c devshop.docsCoverageReason="<per-doc enumeration>" commit ...` or `git -c devshop.testsCoverageReason="<why>" commit ...` — both accept on flag presence (no LLM call) and emit a `Docs-Coverage-Bypass:` / `Tests-Coverage-Bypass:` trailer for audit-time review.
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

The targeted bypass flags work identically for humans and Claude. Two flavors:

- **Adversarial-reviewed** (`devshop.dirtyTreeReason`, `devshop.dirtyPushReason`, `devshop.prTextHygieneReason`, `devshop.manifestReviewed`, `devshop.hookBypassReason`, `devshop.testReviewSkipReason`, `devshop.localTestSkipReason`) — go through `adversarial-review.sh`; generic reasons fail.
- **Trailer-emitting Layer 1** (`devshop.docsCoverageReason`, `devshop.testsCoverageReason`) — accept on flag presence (no LLM call); the `prepare-commit-msg` hook appends a `Docs-Coverage-Bypass:` / `Tests-Coverage-Bypass:` trailer to the commit message; audit-time `/ak-{docs,tests}-review` harvests trailers from the commit range and surfaces each as a `[bypass-revisit]` finding (VERIFIED / DEFER / ESCALATE).

Full list in [§ 2](#2-husky-pre-commit-during-git-commit) and [§ 3](#3-husky-pre-push-during-git-push). The trailer mechanism is documented in `kit/docs/guide/conventions.md § Bypass trailers`.

**Pre-ship-time / pipeline additions to the adversarial-review surface.** Three
check-types fire outside commit-time (pre-ship gates or pipeline phases). Two
have their rationale captured in the spec / advance-log body (no `git -c
devshop.<key>` flag); one uses a git config key just like the commit-time
checks:

- `coreUserStoryNaReason` — invoked from `kit/scripts/preship/verify-story.sh`
  when a spec's `## Core user story` body declares `N/A — <reason>` and Gate 9's
  per-verb artifact assertion is being skipped. The reviewer judges whether the
  rationale names a verifiable file/path claim (`no .tsx files modified`,
  `diff is supabase/migrations/** only`) — PASS — or interpretive prose (`no
visible UI change`, `cosmetic only`) — FAIL. Routes to Sonnet (interpretive
  judgment is not Haiku-tier). No `git -c devshop.<key>` flag — the rationale
  lives in the spec body itself. On reject, the verdict propagates to stdout
  and lands in `review.md § Gate 9` as the fix recipe.
- `blockedGateOverride` — invoked from `/ak-build § Phase 3 → Phase 4 handoff §
  Rung 2` when a pre-ship gate returns `blocked` and the operator picks the
  override option in the orchestrator's `AskUserQuestion` halt. The captured
  override (gate + reason + follow-up tracker) lands in `specs/<feature>/
review.md § Phase 3 → 4 advance log` with an `<!-- adversarial-review-stamp -->`
  marker, and this check-type judges the reason. Rule #12 has four PASS
  sub-criteria: (a) gate-specific reason (not precedent framing — "matches PR
  #27" FAILS), (b) no core-user-story crossing, (c) verifiable follow-up tracker
  pointer (path:section or GitHub issue URL), (d) no § In scope contradiction.
  No `git -c devshop.<key>` flag — the rationale lives in the advance-log body
  itself. Routes to Sonnet (judgment-heavy; the override is a stronger claim
  than any finding dismissal — the gate didn't run at all).
- `advisorBypassReason` — invoked from `kit/scripts/preship/advisor-clean.sh`
  (Gate 2g) when the operator has set `git config devshop.advisorBypassReason
"<reason>"` to short-circuit the DB-hardening advisor probe (`pnpm db:advisor`,
  9 lints against `pg_catalog` — see `kit/docs/guide/security.md § DB
hardening`). The reviewer judges per-finding rigor (which lint, which object,
  why the deviation is intentional, where the deferral is tracked) — PASS — vs
  generic dismissal (`extension-in-public is fine`, `we'll fix it later`) —
  FAIL. Routes to Sonnet; inlines `kit/docs/guide/conventions.md § Supabase
Hardening Defaults` as convention context for the judgment. The bypass flag
  IS a `git config` key (unlike `coreUserStoryNaReason` and
  `blockedGateOverride`) — the rationale belongs at the migration-author level,
  not in the spec.

### Recovering a vanished stash

Goal: get a named operator stash back when `git stash list` no longer shows it, even though no explicit `git stash pop` / `git stash drop` was run.

**When this fires**: most commonly during an `/ak-merge-devshop` session where the operator (or Claude) stashed dirty WIP before invoking the skill, then later finds the stash entry gone from `git stash list` after the merge / push completed. The pre-commit lint-staged backup mechanic ([§ 2 — lint-staged config](#2-husky-pre-commit-during-git-commit)) is the leading suspect — it uses `git stash create` machinery for its own backup and runs on every commit — though lint-staged v15's separate `refs/lint-staged/*` namespace argues against simple index confusion. Root cause is still open ([`kit/TODOS.md` — "Operator stashes vanish silently"](../../TODOS.md)).

**The data is NEVER lost.** `git stash` writes real commit objects to the object database; `git stash drop` removes the named ref but not the commit. Lost stashes become "dangling commits" that `git fsck` enumerates.

**Recovery**:

```bash
# 1. List dangling stash-shaped commits.
git fsck --no-reflogs 2>/dev/null \
  | grep '^dangling commit' | awk '{print $3}' \
  | while read c; do
      msg=$(git log -1 --format='%s' "$c" 2>/dev/null)
      case "$msg" in
        "On "*|"WIP on "*|"index on "*|"untracked files on "*)
          echo "$c: $msg"
          ;;
      esac
    done

# 2. Identify yours by the -m label (or by branch context if you didn't use -m).

# 3. Apply by full SHA. Reconstructs identically to git stash pop.
git stash apply <full-SHA>
```

**Prevention**: when `/ak-merge-devshop` halts at its Phase 0.1 pre-flight refusal (`✖ working tree dirty at $TARGET`), respect it — commit WIP to a throwaway branch rather than stashing. Operator stashes made BEFORE invoking the skill are still at risk if lint-staged fires during the merge. See `.claude/skills/devshop/merge-devshop/SKILL.md § Known limitations § Operator stashes can vanish silently mid-merge` for the worked incident.

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

The `.husky/pre-push` hook runs at the git layer on every `git push`. The wrapper exec's `kit/hooks/pre-push.sh` via the `.hooks/pre-push` symlink (single-source policy, mirrors the pre-commit chain). In **project mode** the script hard-blocks any push whose remote-ref is `refs/heads/main` or `refs/heads/master` with no bypass — projects deploy via PR-merge → CI → Vercel and the remote enforces the same rule via GitHub branch protection. For pushes to feature branches, if there's an open PR and the PR description does not track the commits (excluding trivial conventional-commit-only pushes that don't touch source files), the push is blocked until the description is updated — or the push provides an adversarially-reviewed bypass reason. A third check blocks pushes with a dirty tree or non-empty stash list on the same pass. Branch deletions short-circuit. In **devshop mode** the script short-circuits when on `main` (release.sh territory), blocks feature-branch pushes to `refs/heads/main` unless `devshop.pushToMainApproved` matches the branch name (`/ak-merge-devshop` sets this), skips the PR-desc check (devshop has no PRs), and runs the dirty-tree / stash check. See §3 above for the full check lists and bypass flag names.

---

## Dismissal Log (pre-ship gate-time adversarial review)

Commit-time guards check that the developer explained bypasses. The pre-ship layer has a parallel concern: each quality gate (`simplify`, `docs-and-tests-review` (ak), `review`, `cso`, `design-review`, `design-conformance` (ak), `qa`, `benchmark`, etc. — `(ak)` marks devshop-native gates, bare names wrap gstack skills) produces an advisory report, and the pipeline used to rubber-stamp "gate said pass" without checking whether the gate silently dismissed findings it surfaced. The Dismissal Log closes that hole.

**See also:** [`conventions.md § Bypass trailers`](./conventions.md#bypass-trailers) — the commit-time Layer 1 sibling of this gate-time mechanism; both surface a "skipped a finding" decision into the auditable history, one at git-commit time and one at pre-ship time.

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

### Fast-path: dismissals on a `blocked` gate are rejected before the LLM call

A `blocked` outcome is a **tooling-gap signal**, not a reviewable finding. The gate didn't run (Chromium unavailable, Supabase Kong unreachable, etc.); dismissing whatever the gate would have found is meaningless because the gate found nothing. The dismissal-shim would otherwise short-circuit the orchestrator's `blocked > 0` halt path by cascading the blocked through review.

`adversarial-review.sh dismissalLog` matches the gate section's `Result:` line **before** invoking the LLM. If the result is `blocked` AND the parenthetical does NOT carry `n/a per scope:`, the check returns FAIL immediately with rationale "blocked outcomes cannot be dismissed via shim-map; resolve the tooling gap or report the gate as blocked to the caller." This holds across formatting variants (`- Result: blocked (...)`, `Result: blocked`, `**Result:** blocked`).

The `blocked (n/a per scope: <reason>)` shape IS a legitimate dismissal target — the gate didn't run because of scope, not tooling, and the rationale is what this reviewer normally judges (the LLM call proceeds and applies the per-gate convention inlining). Other outcomes (`pass`, `findings (N)`) are also pass-through: the fast-path only fires on a literal `blocked` Result line.

Codified from home-os PR #15 (2026-05-14) where Gate 9 `/qa` reported `blocked: 1` (Supabase Kong unreachable), the dismissal-shim cascaded the blocked past review, and the PR shipped with placeholder hero shots from the sign-in flow instead of the actual feature. Coverage: `kit/tests/util-adversarial-review-blocked-dismissal.bats`.

### Convention adherence (CONVENTIONS_TO_INCLUDE inlining)

`adversarial-review.sh` additionally inlines relevant sections of `kit/docs/guide/conventions.md` into the reviewer's context block, keyed by `(check-type, gate-name)`. Bypass-reason authors must demonstrate that the diff or dismissal is **consistent with the inlined rules** — a change that violates an explicit convention rule fails unless the reason explicitly engages that rule's stated rationale.

Beyond convention adherence, the reviewer also enforces rule 4(a)'s **named-edits requirement**: each AFFECTED-doc claim must name a distinctive phrase from the edit that will appear in the staged diff, and the reviewer verifies each named phrase by searching the staged diff for it. A claim of "updated to add X" where X is not visible in the diff FAILS.

How it works:

- A `CONVENTIONS_TO_INCLUDE` map (function `get_conventions_to_inline` in `adversarial-review.sh`) returns the pipe-separated list of `## ` heading names from `conventions.md` to inline for a given check-type. For `dismissalLog`, the map is keyed additionally by gate-name so each gate's review sees only its relevant convention(s).
- The `extract_convention_section` helper greps the requested sections out of `conventions.md` and appends them to `CONTEXT` under a `=== Relevant conventions ===` header.
- Rule 5 in the prompt template instructs the reviewer to FAIL when the diff/dismissal violates an explicit rule unless the reason engages the rule's rationale.

After PR-C narrowing the map covers: `testReviewSkipReason` → Non-Negotiables | Test Assertion Depth; `exemptAddition` → Test Presence | Project Docs Coverage | Project Docs Hierarchy; `dismissalLog/<gate>` for `qa`, `docs-and-tests-review`, `design-review`, `cso`, `rls-coverage`, `slow-job-lifecycle`, `review`, `metrics-check`. The `docsReviewed` / `testCoverage` / `testCoverageProject` entries removed in PR-C moved with their check-types to audit-time `/ak-check-docs-and-tests`.

Extending enforcement:

1. Identify the convention in `conventions.md` (must already exist as a `## ` section).
2. Add the routing entry in `get_conventions_to_inline` (case statement keyed by check-type, with a nested case for `dismissalLog` gate-names).
3. The new section is now inlined for every matching adversarial review — no further code changes needed.

The map is intentionally conservative: only enforce conventions whose violations have been seen in the wild AND whose textual rule is concrete enough for an LLM reviewer to judge against. Aspirational / taxonomic sections (Tier 3 per the audit at `kit/notes/roadmap/conventions-audit-redistribution-2026-04-27.md`) should NOT be inlined.

### Guide-body inlining (removed in PR-C)

The `GUIDES_TO_INCLUDE` map fired only for `docsReviewed`, which moved to audit-time `/ak-docs-review` in PR-C of the audit-time docs+tests migration. The map moved with it; no surviving check-type needs full-body guide inlining at commit-time. Audit-time `/ak-docs-review` reads guide doc bodies directly from disk during the audit pass; see `.claude/skills/devshop/docs-review/SKILL.md` for the audit-time prompt structure.

### Bypass flags + env hatches

| Flag / Env                                         | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Where it applies                                |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `DEVSHOP_SKIP_ADVERSARIAL=1` (env)                 | Skip ALL adversarial review for this process — intended for tight iteration loops with active human review. Never set in CI / release. **Blocked for Claude** by `check-hook-bypass.sh` PreToolUse — only reachable from a terminal commit by the human operator. Same boundary as `devshop.humanReviewed`.                                                                                                                                                      | Every adversarial call (commit-time + pre-ship) |
| `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=<model>` (env) | Force a specific model (`haiku` / `sonnet`) for ALL check-types in this invocation. Use to upgrade a normally-Haiku check for a high-stakes commit. The mechanism is the env var; the operator-facing pattern is "tell Claude `use the upgraded adversarial review for this commit`" and Claude prepends the env var to the git invocation.                                                                                                                      | Every adversarial call (commit-time + pre-ship) |
| `PRESHIP_ADVERSARIAL_TIMEOUT=<sec>` (env)          | Per-call timeout for `dismissalLog` reviews (default 120s). Commit-time calls use a 180s default. Pre-ship can fire up to N per gate-run and each call's context is denser.                                                                                                                                                                                                                                                                                      | Only `dismissalLog`                             |
| `devshop.humanReviewed="..."` (git config)         | Fully-human-approved bypass — ONLY reachable from a terminal commit (PreToolUse hook blocks Claude).                                                                                                                                                                                                                                                                                                                                                             | All adversarial calls                           |
| `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` (env)        | Skips `/ak-merge-devshop` Phase 1's interactive `AskUserQuestion` pause on medium-severity audit findings (proceeds straight to Phase 2 squash with the findings recorded as bypass-trailer-equivalent in `review.md`). For auto-mode flows that have already inspected the findings and explicitly chose to ship-with-record. No reviewer; the operator's prior decision IS the audit trail. Source: `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1`. | `/ak-merge-devshop` Phase 1 audit (medium-only) |

#### Per-check-type model routing

`adversarial-review.sh` runs different models per check-type — Haiku 4.5 for deterministic rule-application checks (cheap, fast, sufficient) and Sonnet 4.6 for judgment-heavy or high-blast-radius checks (where false-passes compound or are irreversible):

| Model      | Check-types                                                                                                                                                                                 | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Haiku 4.5  | `dirtyTreeReason`, `dirtyPushReason`, `manifestReviewed`                                                                                                                                    | Pure rule-application: does the reason name specific files? does the manifest decision reasoning hold? False-passes are recoverable (operator notices via downstream symptoms).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Sonnet 4.6 | `prTextHygieneReason`, `testReviewSkipReason`, `localTestSkipReason`, `dismissalLog`, `hookBypass`, `exemptAddition`, `coreUserStoryNaReason`, `advisorBypassReason`, `blockedGateOverride` | PR titles + descriptions + body shape are the canonical reviewer-facing record; `testReviewSkipReason` ships unaudited polish-loop coverage gaps to merge; `localTestSkipReason` skips the cheap-test-gates-local floor on a stack-needing diff; `dismissalLog` weighs spec scope; `hookBypass` can leak secrets via gitleaks bypass; an unreviewed exempt entry silently disables the upstream gate forever; `coreUserStoryNaReason` decides whether a spec's "no user story" claim is a verifiable file-system fact or interpretive cover; `advisorBypassReason` decides whether a DB-hardening lint deferral is per-finding rigor or a generic dismissal — a false-pass would ship an un-pinned `SECURITY DEFINER` or unwrapped RLS policy past the `advisor-clean` (Gate 2g); `blockedGateOverride` waves past a gate that didn't run at all — strongest claim in the surface. (The `docsReviewed` / `testCoverage` / `testCoverageProject` entries moved to audit-time in PR-C.) |

Routing lives in `get_model_for_check_type` near the bottom of `adversarial-review.sh`. Override via `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE=sonnet` to upgrade a Haiku check for a high-stakes commit. Operator pattern: ask Claude to "use the upgraded adversarial review" and Claude prepends the env var.

#### Dual-surface check-types

A single check-type may serve more than one caller via env-var selection — the reviewer's rules live in one place, but the data source varies per surface. Currently one such check-type exists; the pattern is documented here so future additions follow it.

| Check-type            | Surface  | Caller                           | Data source                                                                                                | Rules applied                                                              |
| --------------------- | -------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `prTextHygieneReason` | `pr`     | `.husky/pre-push` (project mode) | `gh pr view --json title,body` + `origin/main..HEAD`                                                       | (a) accuracy + (b) readability + (c) `## Product update` / eng-details H2s |
| `prTextHygieneReason` | `squash` | `/ak-merge-devshop` Phase 0.4.5  | `DEVSHOP_HYGIENE_MESSAGE_FILE` (head-1 = subject, tail-2+ = body) + `origin/main..$DEVSHOP_HYGIENE_BRANCH` | (a) accuracy + (b) readability; (c) skipped (squashes use bullet shape)    |

Surface selection is via `DEVSHOP_HYGIENE_SURFACE` (defaults to `pr` when unset). The squash surface reads from `DEVSHOP_HYGIENE_MESSAGE_FILE` (mandatory; FAIL if missing or not a file) and `DEVSHOP_HYGIENE_BRANCH` (defaults to current branch — required when called from `/devshop` while the feature lives in a linked worktree, since `/devshop`'s `HEAD` is on `main` in that case and `git log origin/main..HEAD` would be empty). The reviewer's prompt block is unchanged across surfaces; per-surface behavior diverges only in the `CONTEXT` block (which body to judge, which constituent commits to compare against) and in two inlined `NOTE` blocks the squash surface adds. **`NOTE 1` — primary judgment, not bypass review:** the squash surface fires from `/ak-merge-devshop` Phase 0.4.5 at compose time as a content check, NOT in response to an operator-supplied bypass attempt. The reviewer is told to treat the second CLI arg (the `REASON` field, e.g. `"auto-check at compose time"`) as a procedural telemetry marker rather than scrutinize it as an operator's rule-skipping defense. Without `NOTE 1`, the engine's default-REJECT-generic-reason rule would fire on procedural markers before the title rules were evaluated — every clean title FAILed in the shipped Phase 0.4.5 form until this NOTE landed. **`NOTE 2` — skip rule (c):** devshop squashes use the bold-led-bullet shape from `.claude/skills/devshop/merge-devshop/SKILL.md § 0.3`, not the project-PR `## Product update` + `## Engineering details` H2 shape, so the body-structure rule is skipped on the squash surface. **Dual-call-pattern contract**: this is the first check-type with a primary-judgment vs. bypass-review distinction; future dual-surface check-types should follow the same NOTE-1 pattern when a caller invokes the engine as a content checker rather than a bypass-defense judge.

Why one check-type instead of two: rules (a) and (b) are universal per `kit/docs/guide/conventions.md § Commit + PR Text Style`. Duplicating them would let the two surfaces drift — a change to the readability convention would move one surface and miss the other. The env-var split keeps the rule definitions in lockstep.

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

Five adversarial-review check-types fire outside git hooks — two inside `/ak-build` (`testReviewSkipReason` here for Phase 5.8 post-audit halt override; `blockedGateOverride` for the Phase 3 → 4 halt override — see `.claude/skills/devshop/build/SKILL.md § Phase 3 → Phase 4 handoff § Rung 2`) and three inside `/ak-pre-ship` (`coreUserStoryNaReason` via `verify-story.sh` at Gate 9, `advisorBypassReason` via `advisor-clean.sh` at Gate 2g, `dismissalLog` via `router-shim.sh` per-gate). The bypass-flag and per-check-type model routing are otherwise identical to the rest.
