# Tasks: ak-merge-rebase-before-audit

Implementation done inline by /ak-build (devshop self-build) — focused 3-file
skill/test/doc change; full context already loaded, so no subagent dispatch.

## Task order

- [done] **T1 — Phase 1.0 rebase + audit restructure** (`merge-devshop/SKILL.md`)
  - Renamed `## Phase 1: Audit` → `## Phase 1: Rebase + audit`.
  - Added `### 1.0: Rebase onto the merge target` (GIT_CMD + anchor detection +
    `$GIT_CMD rebase "$ANCHOR"` + virtiofs phantom-error → merge fallback +
    cherry-pick/`am` unsticker + "Why rebase before the audit" rationale with the
    2026-05-28 worked incident).
  - Existing audit prose became `### 1.1: Audit`; invocation now passes
    `--range ${ANCHOR}..HEAD`.
  - Commit `9e9c511`.
- [done] **T2 — Phase 2 soft-reset-only + idempotence + 0.2 table** (`merge-devshop/SKILL.md`)
  - Phase 2 dropped the rebase; recomputes `$ANCHOR` (deterministic); keeps
    soft-reset + rename-detection + commit. Reworded "Why the soft-reset target
    is `$ANCHOR`" + added anchor-mismatch caveat.
  - Idempotence section: added Phase 1.0 rebase bullet; reworded Phase 2 bullet.
  - Phase 0.2 audit-status table: added non-blocking diverged-base row +
    `BASE_DIVERGED` detection.
  - Commit `9e9c511`.
- [done] **T3 — bats coverage** (`kit/tests/util-ak-merge-devshop.bats`)
  - Section F2: rebase-before-audit ordering (line-order), Phase 1.0 rebase,
    anchor-select, phantom fallback, `--range` arg.
  - Section G: Phase 2 test drops the rebase grep + adds a regression guard that
    Phase 2 no longer rebases; phantom test repointed to Phase 1.0 dependency.
  - 96/96 green. Commit `9e9c511`.
- [done] **T4 — workflow.md cross-ref** (`kit/docs/guide/workflow.md`)
  - `/ak-merge-devshop` skill-map row reflects rebase-before-audit ordering.
  - Commit `9e9c511`.

(PLAN Active row removal + `kit/TODOS.md` entry deletion are Phase 4.0
bookkeeping, not Phase 2 tasks.)

## Decisions

See `spec.md § Decisions` (D1–D5), resolved at Phase 0 and unchanged during
implementation:

- D1: rebase as Phase 1.0 (post-approval, pre-audit); phase numbers stable.
- D2: audit passes explicit `--range "$ANCHOR..HEAD"`.
- D3: Phase 2 recomputes `$ANCHOR` (no shared shell state across orchestrator steps).
- D4: phantom-error/merge fallback lives in Phase 1.0.
- D5: light non-blocking diverged-base preview row (no hard guard).

## Test status

- `kit/tests/util-ak-merge-devshop.bats`: 96 passed, 0 failed.
- Full `bats kit/tests/` runs at Phase 2.5 / Gate 2d.
