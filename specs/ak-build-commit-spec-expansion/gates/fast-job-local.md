## Gate 2d: fast-job-local

- Result: pass-with-note

Devshop test surface is bats (kit/tests/), not turbo. Ran:
- Targeted `util-ak-build-skill.bats`: 46/46 pass (incl. new Section G: G1–G4).
- Full sweep `kit/tests/`: 1561/1562 pass. The single failure is
  `structural-invariants.bats` "wiring: every non-exempt kit script is wired"
  flagging `reconcile-task-commits.sh` — **pre-existing on `main`** (introduced
  by `ca4bc76`, confirmed by running the test against origin/main HEAD 48eed4a),
  out of this change's scope (diff touches only SKILL.md + util-ak-build-skill.bats).
  Routed to `kit/TODOS.md` in this branch per the TODO protocol.

## Dismissals

- `structural-invariants.bats` reconcile-task-commits wiring failure — rationale: pre-existing on main, unrelated to this diff, routed to kit/TODOS.md for a separate fix.
