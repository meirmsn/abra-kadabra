# Tasks: triage-todos-to-friction-log

Atomic-commit per task. Follow spec § Task order exactly.

- [x] **Task 1 — File the 7 friction-log entries.** Drafts 1–7 → `kit/FRICTION-LOG.md § Open`, full schema each, sorted by Score desc. Commit `bbe1a24`.
- [x] **Task 2 — Delete the 7 moved entries + driver triage entry from `kit/TODOS.md`; unwind cross-refs.** Re-ran cross-ref grep — zero orphans. Commit `218e65b`.
- [x] **Task 3 — Promote virtiofs to PLAN + tag its TODOS entry `[v0]`.** Inserted `virtiofs-rebase-auto-switch` as first body row of `PLAN.md § Planned (v0)`, Lev 8.0, Hook 106 chars. Commit `93cb800`.
- [x] **Task 4 — Version-tag remaining `kit/TODOS.md` entries.** Applied every KEEP+TAG / RETAG per § Tag mapping table; #28 retagged `[v+]`→`[v0]`. Commit `edc8bf9`.
