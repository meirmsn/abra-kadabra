## Gate 1: docs-check

- Result: pass
- New resume-reconcile behavior is documented at every required surface:
  - `build/SKILL.md` Step 0 — resume-state table row 2 updated (awk parse + `reconcile-task-commits.sh`); rung 2 fully reworked to invoke the helper, with exit-0 (skip Phase 3) vs non-zero (re-enter Phase 2, print diagnostic) branches; rung 3 destination unchanged and noted as the shared landing point.
  - `build/SKILL.md` Phase 2 — new "non-clean subagent return" note explaining why the gate lives at Step 0 rung 2 (next-invocation risk), not at the live Phase 2 return.
  - `implement/SKILL.md` Step 3 (step 11) — done-means-committed invariant reaffirmed (commit in step 10 AND clean tree).
  - `implement/SKILL.md` Step 4 — completion-summary precondition: confirm done-means-committed before emitting the all-done signal /ak-build trusts.
  - `kit/docs/guide/workflow.md` § tasks.md artifact — reworded to drop the SHA claim and describe the Step 0 reconcile (clean tree + impl-commit-count ≥ done-count, mismatch re-enters Phase 2).
- `kit/scripts/reconcile-task-commits.sh` is referenced from the prose that invokes it: build/SKILL.md (table row 2, rung-2 command + contract pointer, Phase 2 note), implement/SKILL.md (steps 11 + Step 4), and workflow.md tasks.md bullet. Bats-coverage pointer (`kit/tests/util-reconcile-task-commits.bats`) resolves; file exists.
- No doc references a removed/renamed symbol. The stale "tasks.md carries commit SHAs" claim was cleaned up (zero `commit SHA` matches in workflow.md). The merge-devshop row's new cross-ref to `hooks.md § Dual-surface check-types` resolves (hooks.md:486). Referenced bats files (`util-reconcile-task-commits.bats`, `util-ak-build-skill.bats`) both present.
- Tracker closed per close-on-ship convention: the originating `kit/TODOS.md` entry (`/ak-build Phase 2 resume trusts tasks.md done markers`) was added in f81e653 and deleted in cea718c — net-zero across MB..HEAD, absent from HEAD (0 matches). The slot was reused for a separately-discovered, unrelated pre-existing bats failure (legitimately filed, not a leftover of this entry). PLAN.md row moved from "No work in progress" to an Active row; closure of the Active row is Phase 4.0 bookkeeping, out of docs-check scope.

## Dismissals

- None.
