# Tasks — ak-check-docs-orphan-stubs

## Task: Helper script + bats behavior tests

**Hat**: BE (devshop-self tooling)
**Depends on**: none
**Blocks**: Wire short-circuit
**Done when**: `kit/scripts/preship/audit-tracker-only.sh` exists per § Helper contract (exit 0/1/64, empty→0), tracked 644 + invoked via `bash` per devshop convention (init-devshop.sh locks `kit/scripts/*.sh` to 644); `kit/tests/util-audit-tracker-only.bats` covers all 8 matrix cases and is green.
**Risk**: low
**Status**: done

## Task: Wire short-circuit into SKILL.md Step 1 + grep test

**Hat**: BE
**Depends on**: Helper script
**Blocks**: Guide-doc note
**Done when**: `check-docs-and-tests/SKILL.md § Step 1` documents the tracker-only short-circuit (names helper, computes preliminary range, exits 0 without scaffold/sub-skills/append BEFORE the stub-scaffold substep); grep test in `util-check-docs-and-tests.bats` green.
**Risk**: low
**Status**: done

## Task: Guide-doc note + close TODOS + cross-ref unwind

**Hat**: PM/docs
**Depends on**: Wire short-circuit
**Blocks**: none
**Done when**: guide doc carries a concise note on the short-circuit + helper; orphan-stub entry deleted from `kit/TODOS.md`; cross-refs/friction-log unwound; full bats suite green.
**Risk**: low
**Status**: done

## Decisions

- **Guide note placement**: landed in BOTH the `/ak-check-docs-and-tests`
  skill-map row (Task 1, pairs the `kit/scripts/preship/**` surface) AND the
  Phase 5.8 pipeline prose (Task 2, pairs the touched `SKILL.md` surface) in
  `kit/docs/guide/workflow.md`. Two non-duplicative readers (reference table +
  pipeline narrative); no separate Task-3 guide commit needed.
- **FRICTION-LOG**: no matching entry — the orphan-stub bite was tracked
  directly in `kit/TODOS.md`, never promoted from the friction log, so nothing
  to delete/fold there per the closing convention.
- **Tests-coverage bypass (Task 1)**: `check-tests-coverage-devshop.sh`
  hardcodes `TESTS_DIR=/devshop/kit/tests` and can't see worktree-only `.bats`
  files; the test IS staged and green (8 cases). Used a specific
  `testsCoverageReason` bypass naming the worktree-awareness gap. Surfaced as
  friction for a real fix.
