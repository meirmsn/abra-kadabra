# Hooks & Commit Flow

## Claude Code Hooks

Hooks in `.claude/settings.json` guard the development workflow:

| Hook                  | Event                    | Trigger                    | What it does                                                                                                                                                                                                                                                        |
| --------------------- | ------------------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DCG                   | PreToolUse (all Bash)    | Every Bash command         | Destructive Command Guard — blocks 49+ dangerous patterns (rm -rf, git reset --hard, DROP TABLE, etc.)                                                                                                                                                              |
| check-hook-bypass     | PreToolUse (Bash)        | `*git*commit*` commands    | Blocks hook bypass: always blocks `core.hooksPath`/`HUSKY=0`/`devshop.humanReviewed`, requires `devshop.hookBypassReason` for `--no-verify` (adversarially reviewed, fail-closed on API error)                                                                      |
| check-branch-not-main | PreToolUse (Bash)        | `*git*commit*` commands    | Blocks direct commits to `main`/`master` from Claude. Parses `git -C <dir>` and `cd <dir> &&` prefixes to target the right repo. Humans committing from the terminal are unaffected (PreToolUse only intercepts Claude) — so `release.sh` version bumps still work. |
| check-memory-created  | PreToolUse (Write\|Edit) | Write/Edit to memory paths | Blocks memory file writes — Claude must classify (project → `/workspace/.claude/memory/`, devshop → incorporate into `/devshop/CLAUDE.md`, unclear → ask user) and get confirmation before writing                                                                  |
| session-start.sh      | SessionStart             | New session or `/clear`    | Recreates symlinks if missing, then context for Claude (README, BUILD-LOG latest build, branch, devshop CLAUDE.md) + init progress from devshop notes + cross-repo WIP heads-up (uncommitted/stashed state in either repo) + briefing via `systemMessage`           |

> PostToolUse Bash workflow hooks are intentionally absent. Workflow nudges that used to fire after `git commit` / `git push` (release reminder, dirty-tree check, PR description review) now live at the **git layer** (`.husky/pre-push`, husky pre-commit guards) or are owned by skills (`/ak-release-devshop`). See [Why workflow nudges live at the git layer](#why-workflow-nudges-live-at-the-git-layer) below for the rationale.

> **Notification hooks** (`Notification`, `Stop`, `UserPromptSubmit` cancel, `PreToolUse` cancel) push alerts to iPhone/Watch/Mac via ntfy.sh when Claude needs input or a task finishes, with 30s debounce to stay quiet during active sessions. Separate concern from the commit-flow guards above. See [notifications.md](notifications.md).

---

## Commit Flow

Three enforcement levels: PreToolUse (Claude Code), pre-commit (husky), and pre-push (husky). PreToolUse exists because git hooks can't prevent their own bypass — `--no-verify` skips all hooks silently. Something outside git must intercept the command first. Pre-push adds push-time checks (PR description staleness, dirty-tree / stash) at the git layer so they fire agent-agnostically — see [Why workflow nudges live at the git layer](#why-workflow-nudges-live-at-the-git-layer).

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
          ├─ check-manifest.sh: template/ files added/removed → propose manifest update
          └─ devshop-commit-guard.sh (5 checks, run in this order):
             ├─ mixed-commit: devshop + project files staged together → block
             ├─ docs-drift: any devshop file staged (except release artifacts) → reviews ALL docs (semantic)
             ├─ doc-consistency: reference doc changed → requires review notes (semantic)
             ├─ cross-repo: other repo dirty → block
             └─ release-coverage (devshop only): kit/version staged → adversarial
                reviews whether changes since last tag have adequate test coverage
                (semantic); bypass via `devshop.releaseReviewed`

3. Git creates the commit (if pre-commit passed)

4. On eventual `git push`: `.husky/pre-push`
   └─ PR description staleness + dirty-tree / stash cleanliness
      (adversarially reviewed; bypass via `devshop.prDescStaleReason` / `dirtyPushReason`)
```

Step 1 is a Claude Code hook (runs before the tool executes). Step 2 is the git pre-commit hook (runs during commit). Step 4 is the git pre-push hook (runs during `git push`, independent of commit). Steps 2a-2d and 4 are all blocking (fail = operation aborted).

---

## Full Hook Chain Detail

Enforcement layers in chronological order. Sections 1 and 2 fire during `git commit`; section 3 fires later, on `git push`:

### 1. Claude PreToolUse (before git runs)

Configured in `.claude/settings.json`.

| Hook                       | What                                                                                               | Blocking?                                                    |
| -------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `dcg`                      | Destructive command guard (all Bash)                                                               | Yes (compiled binary, only mechanism that blocks Bash calls) |
| `check-hook-bypass.sh`     | Blocks `--no-verify`/`core.hooksPath`/`HUSKY=0` without adversarially-reviewed reason              | Yes (exit 2 on `*git*commit*` match)                         |
| `check-branch-not-main.sh` | Blocks `git commit` when HEAD is `main`/`master`. Parses `git -C <dir>` and `cd <dir> &&` prefixes | Yes (exit 2 on `*git*commit*` match); terminal humans pass   |

Shell-script PreToolUse hooks block Bash calls by exiting with code 2 and printing the message to stdout — Claude Code surfaces stdout as the block reason. DCG is a compiled binary for performance (it runs on every Bash call, so startup cost matters); the other hooks run only on matched patterns like `*git*commit*`.

### 2. Husky pre-commit (during git commit)

Configured in `.husky/pre-commit`.

| Hook                        | What                                       | Blocking?                   |
| --------------------------- | ------------------------------------------ | --------------------------- |
| `pnpm exec lint-staged`     | ESLint + Prettier on staged files          | Yes — both repos            |
| `pnpm turbo run typecheck`  | TypeScript type checking                   | Yes — both repos            |
| `gitleaks protect --staged` | Secret scanning                            | Yes — both repos            |
| `bats kit/tests/`           | Kit tests: scripts + structural invariants | Yes — devshop only          |
| `.hooks/pre-commit`         | Devshop guards (see below)                 | Yes — no-op without devshop |

`.hooks/pre-commit` is gitignored, symlinked to `kit/hooks/pre-commit.sh` (created by `create-devshop-symlinks.sh` for both repos). It detects which repo it's in and calls the appropriate guards.

Guards are split into **deterministic** (auto-pass when condition is met) and **semantic** (always require a review explanation). All bypass reasons are verified by `adversarial-review.sh` — an agent that actively tries to reject the reason. On API error, the review **fails closed** (blocks the commit). Human fallback: `devshop.humanReviewed` flag, but blocked for Claude via PreToolUse hook — only reachable when the human runs the commit directly in the terminal.

| Guard                     | Type          | What                                                                                                                     | Bypass                                                       |
| ------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| `check-clean-tree.sh`     | Deterministic | Blocks if untracked/unstaged files exist                                                                                 | `dirtyTreeReason` — adversarially reviewed                   |
| `check-manifest.sh`       | **Semantic**  | template/ files added/removed — propose manifest.txt update with reasoning                                               | `manifestReviewed` — always required, adversarially reviewed |
| `check-test-coverage.sh`  | Deterministic | New scripts block if no test file; modified scripts warn (devshop only)                                                  | Add to exempt list with reason, or write tests               |
| `devshop-commit-guard.sh` |               |                                                                                                                          |                                                              |
| └─ `mixed-commit`         | Deterministic | Mixed devshop + project files (project repo only)                                                                        | No bypass — unstage one set                                  |
| └─ `docs-drift`           | **Semantic**  | Any devshop file staged (except release artifacts) — reviews ALL docs (including ones that don't yet mention the change) | `docsVerified` — always required, adversarially reviewed     |
| └─ `doc-consistency`      | **Semantic**  | Reference doc changed — consistency review                                                                               | `docSyncReason` — always required, adversarially reviewed    |
| └─ `cross-repo`           | Deterministic | Other repo has uncommitted changes                                                                                       | `crossRepoReason` — adversarially reviewed                   |
| └─ `release-coverage`     | **Semantic**  | Release commit (devshop only) — `kit/version` staged → adversarial reviews coverage                                      | `releaseReviewed` — justification re-reviewed with diff      |

Both repos use the same guard chain. Checks run in the order listed above.

Bypass via `git -c devshop.<key>="<reason>"` works natively in husky. Every bypass reason is verified by an adversarial agent that actively tries to reject it. On API error, the review fails closed (blocks). Human fallback: `git -c devshop.humanReviewed="approve: <assessment>"` — blocked for Claude via PreToolUse, only usable from the terminal. Semantic checks (`docs-drift`, `doc-consistency`, `release-coverage`) always run an adversarial review — either of a user-provided reason (`docs-drift`, `doc-consistency`) or of the coverage directly (`release-coverage`). Deterministic checks auto-pass when the condition is met.

**Handling WIP files (clean-tree guard):** When the clean-tree guard flags files you didn't modify in this session (WIP from a previous session or the user's in-progress work), NEVER discard them with `git checkout` or `git restore` — that permanently destroys uncommitted work. Instead, use the bypass: `git -c devshop.dirtyTreeReason="<file> is WIP, committing separately" commit ...`. Alternatively, `git stash push <file>` before committing, then `git stash pop` after.

### 3. Husky pre-push (during git push)

Configured in `.husky/pre-push`.

| Check              | What                                                                                                                                                            | Blocking?                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| PR description     | Is the PR title + body current vs all commits on the branch? Skipped when every commit is `chore:` / `docs:` / `style:` / `test:` / `ci:` / `build:` / `perf:`. | Yes — `devshop.prDescStaleReason` adversarially reviewed |
| Dirty tree / stash | Is the working tree clean? Zero stash entries?                                                                                                                  | Yes — `devshop.dirtyPushReason` adversarially reviewed   |

Short-circuits (no review, exit 0): detached HEAD, push to `main`/`master` (release.sh territory), branch deletions (zero-sha local).

Both bypass flags run through the same shared engine as commit-time guards (`kit/scripts/adversarial-review.sh`). Generic reasons (`WIP`, `later`, `fine`) fail; specific structural reasons (`intentionally batching updates until post-rebase — will squash-update after final review`, `stashed feature X to push hotfix Y on unrelated branch`) pass.

Release-side work (`/ak-release-devshop` skill) is invoked manually or by a follow-up skill chain. The old PostToolUse commit-time "remember to run release.sh" reminder was deleted — release is a deliberate decision, not a post-commit nudge.

---

## Why workflow nudges live at the git layer

The devshop used to have PostToolUse Bash hooks in `.claude/settings.json` for workflow nudges that fired after `git commit` / `git push`:

- **release.sh reminder** — "commit in abra-kadabra → remember to bump version"
- **check-dirty-after-commit.sh** — "tree still dirty after commit, deal with the remaining files"
- **check-pr-description.sh** — "PR open, review title/body vs commits"

They shared an audience problem: **PostToolUse Bash fires in subagents too**. A subagent with a narrow mandate (e.g., `/ak-pre-ship` gates, `/ak-build` phases) has no authority to commit a parent's WIP or edit a parent's PR description. When these hooks fired inside a subagent, the subagent either ignored the nudge (burning tokens deciding each time) or partially complied (acting outside its scope). Neither is correct. The PostToolUse payload does not carry subagent identity — the hook cannot self-detect.

**Git hooks fire at git invocation regardless of which agent ran git.** A subagent that legitimately commits or pushes passes through the same pre-commit + pre-push gates as the parent. Each agent satisfies the gates in its own narrow context. No audience reasoning is baked into the trigger — the gate is agent-agnostic by construction.

Three moves replaced the three audience-confused PostToolUse hooks:

1. **`check-dirty-after-commit.sh`** deleted as redundant with existing husky pre-commit guards (`check-clean-tree.sh` in devshop-commit-guard.sh — same dirty-tree concern, commit-time, blocking).
2. **`check-pr-description.sh`** superseded by `.husky/pre-push` "PR description" check — now blocking (was advisory), agent-agnostic, single adversarial review.
3. **Inline release reminder** replaced by the `/ak-release-devshop` skill — invocation is explicit, not post-commit-prompted.

Plus one additive change: `session-start.sh` grew a "cross-repo WIP heads-up" section that warns (non-blocking) at session boundaries if either `/workspace` or `/devshop` has uncommitted or stashed work. Catches WIP left over from a previous session before Claude starts editing over it.

See [kit/notes/roadmap/hook-migration-plan.md](../../notes/roadmap/hook-migration-plan.md) for the investigation, alternatives considered, and migration scope.

**PreToolUse hooks are unchanged.** They enforce agent-agnostic invariants (`dcg`, `check-hook-bypass.sh`, `check-branch-not-main.sh`, `check-memory-created.sh`) — any agent running any `Bash` or `Write`/`Edit` should be intercepted by them. Their audience-correctness was never the problem.

---

## Commit Convention

Both repos use conventional commits (`feat:`, `fix:`, `chore:`, etc.). The `devshop:` prefix is no longer needed — with separate repos, the commit's repo makes the context obvious. The commit guard warns if both types of files are staged together in the project repo — separate them into distinct commits.

## On Push

The `.husky/pre-push` hook runs at the git layer on every `git push` to non-main branches. If there's an open PR for the branch and the PR description does not track the commits (excluding trivial conventional-commit-only pushes), the push is blocked until the description is updated — or the push provides an adversarially-reviewed bypass reason. A second check blocks pushes with a dirty tree or non-empty stash list on the same pass. Branch deletions and pushes to `main` / `master` short-circuit. See §3 above for the full check list and bypass flag names.

---

## Dismissal Log (pre-ship gate-time adversarial review)

Commit-time guards check that the developer explained bypasses. The pre-ship layer has a parallel concern: each quality gate (`simplify`, `test-review` (ak), `review`, `cso`, `design-review`, `design-conformance` (ak), `qa`, `benchmark`, etc. — `(ak)` marks devshop-native gates, bare names wrap gstack skills) produces an advisory report, and the pipeline used to rubber-stamp "gate said pass" without checking whether the gate silently dismissed findings it surfaced. The Dismissal Log closes that hole.

### Contract (every gate)

Every gate's output MUST include a `## Dismissals` section with exactly one of:

- **Body `None`** — zero findings were worth dismissing. Default for most gate runs.
- **Bulleted list** — one bullet per dismissal with a `rationale:` field (1 line) explaining why the gate chose not to act.

Pre-ship aggregates all gates' Dismissals into a `## Router Summary` block at the top of `review.md`. Every dismissal is the auditable reason a finding did NOT become a pending blocker.

### Adversarial review

When a gate's `## Dismissals` body is non-`None` (scoped parse — `kit/scripts/preship-router-shim.sh is-empty <report>`), pre-ship hands the rationales to `adversarial-review.sh dismissalLog`. The check-type rejects rationales that:

- Are generic (`not critical`, `minor`, `can wait`, `won't fix`)
- Contradict the spec's `## Core user story` (Phase 1 — coming) or `## In scope`
- Punt to TODOS / follow-up without a specific tag or issue reference
- Omit the `rationale:` field entirely

Rejection fails the gate with outcome `findings (N) pending` — the pipeline pauses like any other unresolved finding. The reviewer has the full `review.md` entry + the spec's scope sections as context, so "this is consistent with our scope" claims get checked against the actual scope.

### Bypass flags + env hatches

| Flag / Env                                 | Purpose                                                                                                                                                                                                      | Where it applies                                |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| `DEVSHOP_SKIP_ADVERSARIAL=1` (env)         | Skip ALL adversarial review for this process — intended for tight iteration loops with active human review. Never set in CI / release.                                                                       | Every adversarial call (commit-time + pre-ship) |
| `PRESHIP_ADVERSARIAL_TIMEOUT=<sec>` (env)  | Per-call timeout for `dismissalLog` reviews (default 120s). Commit-time calls keep the 90s default because they run one-at-a-time; pre-ship can fire up to N per gate-run and each call's context is denser. | Only `dismissalLog`                             |
| `devshop.humanReviewed="..."` (git config) | Fully-human-approved bypass — ONLY reachable from a terminal commit (PreToolUse hook blocks Claude).                                                                                                         | All adversarial calls                           |

### Shim: structured-output gates

Gates that already emit structured findings get a mechanical dismissal mapping via `kit/scripts/preship-router-shim.sh` — no LLM call for the obvious cases:

- `cso` JSON with `severity: TENTATIVE` → auto-dismissed with rationale `"TENTATIVE per /cso confidence tier (self-verified only)"`. CRITICAL / HIGH / MEDIUM stay as findings.
- `benchmark` metrics within threshold → filtered at the gate itself; no dismissal needed.

The shim's output is a rendered Dismissals body that pre-ship treats like any other gate's — an explicit gate run can still override and invoke adversarial review.

### Forward-compatibility (Phase 4 — deferred)

Today's Dismissal Log entries carry a single `rationale:` field. Phase 4 (Finding Router, not yet landed) will add a `disposition:` field adjacent (`fix-now` | `fix-before-ship` | `TODO` | `spec-amendment` | `ignore`) to route dismissals into concrete actions. Today's entries extend, not migrate — the `rationale:` field stays.

See `/devshop/.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log (every gate, mandatory)` for the full skill-level contract, including the canonical ordered gate list.
