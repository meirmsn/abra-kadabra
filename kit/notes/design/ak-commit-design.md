# `/ak-commit` — Design Notes

## Problem

After `git commit`, a PostToolUse hook (`check-dirty-after-commit.sh`) advises Claude
about remaining dirty files — but Claude can ignore it. The tree stays dirty. We need
a skill that **owns the full commit loop** and real enforcement that prevents raw
`git commit` from bypassing it.

## Key Discovery: Enforcement Options

Shell PreToolUse hooks **cannot block Bash calls** (confirmed by testing,
anthropics/claude-code#26923). The `permissionDecision: "deny"` JSON output was also
tested and confirmed ineffective for Bash. Only DCG (compiled binary) can block Bash
via PreToolUse, and custom DCG rules cause false positives on git commands.

**But husky pre-commit hooks CAN block** — they already do (exit 1 = commit aborted).
So enforcement goes through husky, not Claude Code hooks. Same pattern as
`check-clean-tree.sh` and `devshop-commit-guard.sh`.

To prevent trivial bypass (passing a boolean flag), the gate uses **adversarial review**
on the reason — same pattern as `dirtyTreeReason` and `docsReviewed`.

## Design

### 1. Skill: `/ak-commit` (SKILL.md)

Location: `/devshop/.claude/skills/devshop/commit/SKILL.md`

A simple loop with an escape hatch:

1. **Assess** — `git status --porcelain` in both `/workspace` and `/devshop`
2. **Classify** each dirty file into buckets:

   | Bucket          | Action                                 | Example                                  |
   | --------------- | -------------------------------------- | ---------------------------------------- |
   | stage-project   | Stage + include in project commit      | Modified source files in /workspace      |
   | stage-devshop   | Stage + include in devshop commit      | Modified files in /devshop               |
   | separate-commit | Needs its own commit (different scope) | Unrelated fix found during feature work  |
   | stash           | WIP, not ready                         | Half-finished changes in unrelated files |
   | gitignore       | Should not be tracked                  | Build artifacts, local config            |
   | **unknown**     | **Ask user**                           | Anything ambiguous                       |

3. **Plan** — ordered list of commits (devshop before project if prerequisite), print
   plan before executing
4. **Execute** each commit:
   - Stage specific files (never `git add -A` or `git add .`)
   - Construct `-c` bypass flags as needed (`dirtyTreeReason`, `crossRepoReason`,
     `docsReviewed`)
   - Pass `devshop.viaAkCommit="ak-commit: <description of this commit in context>"` to
     pass the husky gate
   - If pre-commit rejects, fix the root cause and retry (don't bypass)
5. **Verify** — `git status --porcelain` both repos. If still dirty, loop back to step 2.
   If unknown files remain, ask user.
6. **Summary** — print commits made, files stashed, final state of both repos

Rules:

- Never mix devshop + project files in one commit (commit guard blocks this anyway)
- Never `git add -A` or `git add .` — stage specific files by name
- Escape hatch: ask user for any file you can't classify — do not guess

### 2. Husky gate: `check-ak-commit.sh`

Location: `/devshop/.devshop/scripts/check-ak-commit.sh`

Runs as the **first** step in the husky pre-commit chain (before all other guards):

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

REASON=$(git config --get devshop.viaAkCommit 2>/dev/null || true)

# No flag → block
if [ -z "$REASON" ]; then
  echo ""
  echo "✖ Raw git commit blocked. Use /ak-commit instead."
  echo "  /ak-commit handles both repos, bypass flags, and clean-tree verification."
  echo "  If committing from another skill, pass:"
  echo "    git -c devshop.viaAkCommit=\"<skill>: <what and why>\" commit ..."
  exit 1
fi

# Reason provided — adversarial review
echo "⏳ ak-commit gate: reviewing reason with adversarial agent..."
REVIEW_RESULT=$(bash "$SCRIPT_DIR/adversarial-review.sh" viaAkCommit "$REASON" 2>&1) || {
  echo ""
  echo "✖ ADVERSARIAL REVIEW REJECTED your ak-commit reason."
  echo "  $REVIEW_RESULT"
  echo ""
  echo "  Provide a specific reason describing the workflow context."
  exit 1
}
echo "✓ ak-commit gate: adversarial review accepted."
exit 0
```

**Reason examples (accepted):**

- `"ak-commit: committing 3 devshop files (1 of 2 planned commits, project commit next)"`
- `"ak-implement: task 3 complete — auth validation with tests"`
- `"ak-build: pre-ship gate passed, shipping PR"`

**Reason examples (rejected):**

- `"true"` — not a reason
- `"bypassing"` — not a workflow context
- `"test commit"` — not descriptive

### 3. Changes to existing files

**`init-devshop.sh`** — add `check-ak-commit.sh` as the first line in the generated
`.hooks/pre-commit` for both repos:

```bash
bash .devshop/scripts/check-ak-commit.sh   # ← new, first in chain
bash .devshop/scripts/check-claude-md-freshness.sh
bash .devshop/scripts/check-clean-tree.sh
bash .devshop/scripts/devshop-commit-guard.sh
```

**`check-dirty-after-commit.sh`** — update advisory messages to reference `/ak-commit`:

- "Working tree still dirty..." → add "Run /ak-commit to handle remaining files."
- "Other repo has uncommitted changes..." → add "Run /ak-commit to handle both repos."

**GUIDE.md** — updates needed in:

- Devshop Skill Map table (~line 168): add `/ak-commit` row
- Security + Quality (~line 324): mention ak-commit gate in pre-commit description
- Claude Code Hooks table (~line 338): not needed (this is a husky guard, not a Claude hook)
- Commit Flow (~line 347): add `check-ak-commit.sh` as step 2a (first in husky chain)
- Husky hooks table (~line 616): add new row for the gate

**CLAUDE.md** (devshop, ~line 36, non-negotiables): Add:

```
- Use `/ak-commit` instead of raw `git commit`. The husky gate blocks raw commits
  (adversarially reviewed). Other skills (e.g., `/ak-implement`) can commit directly
  by passing a descriptive `devshop.viaAkCommit` reason.
```

### 4. No changes to settings.json

No PreToolUse hook needed — husky handles enforcement. The existing PostToolUse
`check-dirty-after-commit.sh` stays as a safety net with updated messaging.

## Files summary

| File                                           | Action                                         |
| ---------------------------------------------- | ---------------------------------------------- |
| `.claude/skills/devshop/commit/SKILL.md`       | **Create** — the skill                         |
| `.devshop/scripts/check-ak-commit.sh`          | **Create** — husky gate                        |
| `.devshop/scripts/init-devshop.sh`             | **Edit** — add gate to .hooks/pre-commit       |
| `.devshop/scripts/check-dirty-after-commit.sh` | **Edit** — reference /ak-commit                |
| `.devshop/GUIDE.md`                            | **Edit** — skill map, commit flow, hooks table |
| `.devshop/CLAUDE.md`                           | **Edit** — non-negotiables                     |

## What we're NOT changing

- Existing pre-commit guards (`check-clean-tree.sh`, `devshop-commit-guard.sh`) — they
  remain and run after the ak-commit gate
- `settings.json` — no PreToolUse hook needed
- `/ak-implement` — commits per-task in its own loop with a descriptive `viaAkCommit` reason

## Verification plan

1. Invoke `/ak-commit` with dirty files in both repos — confirm full loop until clean
2. Run raw `git commit` (no flag) — confirm husky blocks with "use /ak-commit"
3. Run `git -c devshop.viaAkCommit="true" commit` — confirm adversarial review **rejects**
4. Run `git -c devshop.viaAkCommit="ak-implement: task 3 — auth validation" commit` —
   confirm adversarial review **accepts**
5. After `/ak-commit` completes, confirm both repos are clean
6. Leave an ambiguous untracked file — confirm skill asks user (escape hatch)
7. Verify `init-devshop.sh` regenerates `.hooks/pre-commit` with gate first
8. Verify docs pass commit guard (co-staged with skill changes)
