### [domain: docs] [section: C] [severity: medium]

**File**: `kit/TODOS.md:10`
**What**: The `/ak-merge-devshop audits before rebasing — stale-base worktrees get phantom revert findings` TODO entry is still open (`[ ]`) at HEAD, but this branch ships the fix for exactly that bug (Phase 1.0 rebase-before-audit, commit `9e9c511`). Per CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships", the same PR that ships a fix MUST close (delete) the tracker entry.
**Why**: A stale open TODO describing a bug that has been fixed gets cited as "still pending" in future sessions and recreates the false belief the fix removed. The entry was added by this branch's Phase 0 commit (`2a2a17d`) as the spec source pointer, and the fix landed in `9e9c511` — both in this range — yet the checkbox was never flipped/deleted.
**Fix**: Delete the `kit/TODOS.md:10` entry and remove the PLAN.md Active-row `Source` cross-reference that points at it (`PLAN.md:72`). Note: `tasks.md § Task order` explicitly defers this to "Phase 4.0 bookkeeping," and the task tracker shows Phase 4.0 as still `pending` — so this is a scheduled, in-flight closure rather than a forgotten one. It MUST land before the squash merges (Phase 4.5 `/ak-merge-devshop`). Surfaced as medium so the operator confirms the closure happens before merge rather than slipping.

### [domain: docs] [section: B] [severity: low]

**File**: `.claude/skills/devshop/merge-devshop/SKILL.md:286`
**What**: The new Phase 0.2 audit-status display row references `$ANCHOR` in its operator-facing message (`Phase 1.0 rebases onto $ANCHOR, then 1.1 re-audits the rebased HEAD`), but Phase 0.2 only computes `$BASE_DIVERGED` — `$ANCHOR` is not selected until Phase 1.0. If a reader treats the table cell as a literal shell echo, the message would print the unexpanded token `$ANCHOR` rather than `origin/main` / `main`.
**Why**: Minor reader-confusion / mild inaccuracy. The cell lives in a markdown "display logic" table (descriptive prose, not an executable block), so in practice it reads as intentional placeholder text — but the inconsistency (computing one var, displaying another not-yet-defined var) is a small adequacy nit.
**Fix**: Either reword the 0.2 cell to drop the forward-reference (`Phase 1.0 rebases onto the merge target, then 1.1 re-audits the rebased HEAD`), or add a one-line note that `$ANCHOR` is selected in Phase 1.0. Cosmetic; not blocking.

### Size-trend / coverage note (informational)

- Coverage is otherwise solid: the restructure (SKILL.md Phase 1.0/1.1 + Phase 2 soft-reset-only) is reflected in the two co-touched reference docs — `kit/docs/guide/workflow.md` (skill-map row rewritten to describe rebase-before-audit) and `.claude/skills/devshop/build/devshop-mode.md` (Phase 1 bullet rewritten with the rebase + re-audit idempotence semantics). No stale "Phase 2 rebase" claims remain in `kit/docs/`, `CLAUDE.md`, or `architecture.md` (the surviving SKILL.md hits at lines 749/909/974 are intentional historical-context / dependency prose, not stale claims).
- No `Docs-Coverage-Bypass:` or `CLAUDE-MD-Bypass:` trailers in range.
- Section E (CLAUDE.md hygiene) skipped — devshop self-mode (`$GIT_ROOT == /devshop`).
