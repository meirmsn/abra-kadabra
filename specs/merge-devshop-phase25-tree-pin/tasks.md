# Tasks: merge-devshop-phase25-tree-pin

## Task: Add HEAD-pin guard to SKILL.md § Phase 2.5

**Hat**: BE (tooling / prompt-contract)
**Depends on**: none
**Blocks**: G2 content-validation tests
**Done when**: Phase 2.5 resolves `$BATS_CWD` to an absolute path, pins
`EXPECTED_SHA=$(git -C "$BATS_CWD" rev-parse "$BRANCH")`, asserts HEAD ==
EXPECTED_SHA before AND after the suite (halt on mismatch), keeps the existing
count-based verdict + 2026-05-27 comment unchanged, and carries a rationale
comment naming the parallel-merge HEAD-flip race + Phase 3 mirror + `1d343bf`.
**Risk**: low
**Status**: done

## Task: Add Section G2 content-validation bats tests

**Hat**: BE (tests)
**Depends on**: HEAD-pin guard
**Blocks**: none
**Done when**: five new G2 tests (absolute path, EXPECTED_SHA pin, before
assertion, after assertion, race rationale) pass; full `kit/tests/` suite green.
**Risk**: low
**Status**: done

## Task: Close kit/TODOS.md HEAD-race entry + unwind cross-refs

**Hat**: PM (bookkeeping)
**Depends on**: none
**Blocks**: none
**Done when**: TODOS.md HEAD-race entry deleted; grep finds no doc/skill citing
it as pending (excluding spec.md historical Sources pointer + PLAN.md row).
**Risk**: low
**Status**: done

## Decisions

(D1-D4 resolved at Phase 0 — see spec.md § Decisions.)

- **Out-of-scope discovery (Task 2 full-suite run):** the full bats suite has one
  pre-existing red — `structural-invariants.bats` "wiring: every non-exempt kit
  script is wired" fails because `reconcile-task-commits.sh` (landed by `ca4bc76`
  on origin/main) is neither hook-wired nor exempted. Unrelated to this PR's
  diff (SKILL.md + bats + TODOS only). Per CLAUDE.md TODO Protocol, filed to
  `kit/TODOS.md` rather than folded into this feature squash; the HEAD-pin guard
  + its 5 new G2 tests are all green.
- **Preserved a sub-concern when closing the HEAD-race TODO (Task 3):** the
  deleted entry's "Complementary prevention" note (content-drift between a
  doc/SKILL edit and the bats test asserting it) is a separate unsolved problem,
  not closed by this fix. Re-filed as its own standalone `kit/TODOS.md` entry so
  it isn't lost with the HEAD-race entry.
