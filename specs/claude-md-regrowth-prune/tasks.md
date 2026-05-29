# Tasks: claude-md-regrowth-prune

## Decisions (judgment calls made during implementation)

- **D5 revised by Task-1 survey:** Session Start is the canonical contract home
  cited by `architecture.md:192` + `conventions.md:876`. Move is **slim-in-place,
  not relocate-and-repoint** — keep the injection contract the cites depend on,
  trim only the `/ak-sync-from-devshop` wrapper depth already owned by
  `architecture.md:153`. **No repoint needed.**
- **C2 submodule-step rationale STAYS** — it's a silent trap (skip → cryptic
  `bats-support/load` failure), not reference. Only the 3-step shipping flow +
  the duplicated worktree-aware-merge sentence trim.
- **C4 `ef6db18` SHA dropped** as one-off history (commit msg is the audit
  trail, per claude-md.md routing).

## Task 1: Layer-C classification sweep + verify-before-trim survey
**Status:** done
**Findings:** survey confirmed guide ownership: architecture.md:153 owns sync
wrapper; workflow.md:488 owns merge mechanics (NOT worktree-add submodule trap);
security.md:28 owns locked-file ownership; hooks.md:51,149 owns TOCTOU branch
guard. D8 re-confirmed (see Task 5).

## Task 2: C1 Session Start slim-in-place
**Status:** done
**Files:** `CLAUDE.md`

## Task 3: C2 + C3 + C4 prune
**Status:** done
**Files:** `CLAUDE.md`

## Task 4: Verify-no-loss + cross-ref grep + bats suite + file D8 to TODOS
**Status:** done
**Files:** `CLAUDE.md` (verify), `kit/TODOS.md` (D8 entry)

## Task 5: Close trackers (D7)
**Status:** done
**Files:** `kit/ROADMAP.md`, `PLAN.md`
