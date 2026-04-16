# Hooks & Commit Flow

## Claude Code Hooks

Hooks in `.claude/settings.json` guard the development workflow:

| Hook                  | Event                    | Trigger                        | What it does                                                                                                                                                                                       |
| --------------------- | ------------------------ | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DCG                   | PreToolUse (all Bash)    | Every Bash command             | Destructive Command Guard — blocks 49+ dangerous patterns (rm -rf, git reset --hard, DROP TABLE, etc.)                                                                                             |
| check-hook-bypass     | PreToolUse (Bash)        | `*git*commit*` commands        | Blocks hook bypass: always blocks `core.hooksPath`/`HUSKY=0`/`devshop.humanReviewed`, requires `devshop.hookBypassReason` for `--no-verify` (adversarially reviewed, fail-closed on API error)     |
| check-memory-created  | PreToolUse (Write\|Edit) | Write/Edit to memory paths     | Blocks memory file writes — Claude must classify (project → `/workspace/.claude/memory/`, devshop → incorporate into `/devshop/CLAUDE.md`, unclear → ask user) and get confirmation before writing |
| release.sh reminder   | PostToolUse (git commit) | `*git*commit*` in devshop repo | Reminds to run `release.sh` for version bump + changelog (no-op in project repos)                                                                                                                  |
| dirty tree check      | PostToolUse (git commit) | `*git*commit*` commands        | If tree still dirty after commit, tells Claude to address remaining files                                                                                                                          |
| PR description update | PostToolUse (git push)   | `*git push*` commands          | Two-step: (1) Claude assesses title/description vs commits — text only, no edits. (2) Next response: runs `gh pr edit` if needed.                                                                  |
| session-start.sh      | SessionStart             | New session or `/clear`        | Recreates symlinks if missing, then context for Claude (README, BUILD-LOG, branch, devshop CLAUDE.md) + briefing via `systemMessage`                                                               |

---

## Commit Flow

Two enforcement levels: PreToolUse (Claude Code) and pre-commit (git). PreToolUse exists because git hooks can't prevent their own bypass — `--no-verify` skips all hooks silently. Something outside git must intercept the command first.

```
1. PreToolUse: dcg  (settings.json hook, all Bash)
   └─ Blocks destructive commands (not relevant for git commit, passes through)

1b. PreToolUse: check-hook-bypass.sh  (settings.json hook, *git*commit*)
    └─ Blocks core.hooksPath/HUSKY=0, requires reason for --no-verify
    └─ WHY: guarantees step 2 (git hooks) can't be skipped

2. .husky/pre-commit  (git hook, runs 5 steps sequentially)
   ├─ 2a. create-devshop-symlinks.sh   → recreate symlinks if lost by git ops
   ├─ 2b. pnpm exec lint-staged        → ESLint + Prettier on staged files
   ├─ 2c. pnpm turbo run typecheck     → TypeScript check all packages
   ├─ 2d. gitleaks protect --staged    → Secret scan
   └─ 2e. devshop pre-commit guards    → devshop guards (called by absolute path)
          ├─ check-security-files-freshness.sh: settings.json/.dcg.toml present + current → block
          ├─ check-clean-tree.sh: untracked/unstaged files OR stashed changes → block
          ├─ check-manifest.sh: template/ files added/removed → propose manifest update
          └─ devshop-commit-guard.sh (4 checks):
             ├─ Mixed commit: devshop + project files staged together → block
             ├─ Docs drift: tooling changed → reviews ALL docs for needed updates (semantic)
             ├─ Doc consistency: reference doc changed → requires review notes (semantic)
             └─ Cross-repo: other repo dirty → block

3. Git creates the commit (if pre-commit passed)

4. PostToolUse hooks (settings.json):
   ├─ release.sh reminder (devshop repo only)
   └─ check-dirty-after-commit.sh: remaining dirty files in either repo
```

Step 1 is a Claude Code hook (runs before the tool executes). Step 2 is the git pre-commit hook (runs during commit). Step 4 is a Claude Code hook (runs after). Steps 2a-2d are all blocking (fail = commit aborted).

---

## Full Hook Chain Detail

When Claude runs `git commit`, three layers fire in sequence:

### 1. Claude PreToolUse (before git runs)

Configured in `.claude/settings.json`.

| Hook  | What                                 | Blocking?                                                    |
| ----- | ------------------------------------ | ------------------------------------------------------------ |
| `dcg` | Destructive command guard (all Bash) | Yes (compiled binary, only mechanism that blocks Bash calls) |

Note: PreToolUse hooks from shell scripts cannot block Bash tool calls (anthropics/claude-code#26923). DCG works because it's a compiled binary with special integration.

### 2. Husky pre-commit (during git commit)

Configured in `.husky/pre-commit`.

| Hook                        | What                              | Blocking?                   |
| --------------------------- | --------------------------------- | --------------------------- |
| `pnpm exec lint-staged`     | ESLint + Prettier on staged files | Yes — both repos            |
| `pnpm turbo run typecheck`  | TypeScript type checking          | Yes — both repos            |
| `gitleaks protect --staged` | Secret scanning                   | Yes — both repos            |
| `bats kit/tests/`           | Kit script regression tests       | Yes — devshop only          |
| `.hooks/pre-commit`         | Devshop guards (see below)        | Yes — no-op without devshop |

`.hooks/pre-commit` is gitignored, symlinked to `kit/hooks/pre-commit.sh` (created by `create-devshop-symlinks.sh` for both repos). It detects which repo it's in and calls the appropriate guards.

Guards are split into **deterministic** (auto-pass when condition is met) and **semantic** (always require a review explanation). All bypass reasons are verified by `adversarial-review.sh` — an agent that actively tries to reject the reason. On API error, the review **fails closed** (blocks the commit). Human fallback: `devshop.humanReviewed` flag, but blocked for Claude via PreToolUse hook — only reachable when the human runs the commit directly in the terminal.

| Guard                             | Type          | What                                                                                  | Bypass                                                       |
| --------------------------------- | ------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `check-clean-tree.sh`             | Deterministic | Blocks if untracked/unstaged files exist                                              | `dirtyTreeReason` — adversarially reviewed                   |
| `check-manifest.sh`               | **Semantic**  | template/ files added/removed — propose manifest.txt update with reasoning            | `manifestReviewed` — always required, adversarially reviewed |
| `check-test-coverage.sh`          | Deterministic | New scripts block if no test file; modified scripts warn (devshop only)               | Add to exempt list with reason, or write tests               |
| `devshop-commit-guard.sh` check 1 | Deterministic | Mixed devshop + project files (project repo only)                                     | No bypass — unstage one set                                  |
| check 2                           | **Semantic**  | Tooling changed — reviews ALL docs (including ones that don't yet mention the change) | `docsVerified` — always required, adversarially reviewed     |
| check 3                           | **Semantic**  | Reference doc changed — consistency review                                            | `docSyncReason` — always required, adversarially reviewed    |
| check 4                           | Deterministic | Other repo has uncommitted changes                                                    | `crossRepoReason` — adversarially reviewed                   |

Both repos use the same guard chain.

Bypass via `git -c devshop.<key>="<reason>"` works natively in husky. Every bypass reason is verified by an adversarial agent that actively tries to reject it. On API error, the review fails closed (blocks). Human fallback: `git -c devshop.humanReviewed="approve: <assessment>"` — blocked for Claude via PreToolUse, only usable from the terminal. Semantic checks (2, 3) always require a reason — there is no auto-pass. Deterministic checks (clean tree, cross-repo) auto-pass when the condition is met.

### 3. Claude PostToolUse (after git commit)

Configured in `.claude/settings.json`.

| Hook                          | What                                                   | Fires when                        |
| ----------------------------- | ------------------------------------------------------ | --------------------------------- |
| Release prompt                | "Ask user about version bump + changelog"              | Commits in abra-kadabra repo only |
| `check-dirty-after-commit.sh` | Checks current repo + other repo for remaining changes | All commits                       |
| `check-pr-description.sh`     | PR description quality check                           | On `*git push*`, not commit       |

PostToolUse hooks are advisory (inject context, don't block).

---

## Commit Convention

Both repos use conventional commits (`feat:`, `fix:`, `chore:`, etc.). The `devshop:` prefix is no longer needed — with separate repos, the commit's repo makes the context obvious. The commit guard warns if both types of files are staged together in the project repo — separate them into distinct commits.

## On Push

A PostToolUse prompt hook checks if there's an open PR for the branch. If the PR description is missing, outdated, or doesn't reflect the current commits, it updates the description automatically. Skips trivial pushes (typo fixes, formatting).
