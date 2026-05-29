# Tasks: ak-build-commit-spec-expansion

## Task: Add commit-expanded-spec step to Phase 1 (edit region A) + bats G1/G2

**Hat**: PM (devshop-self-mode SKILL.md prose change)
**Depends on**: none
**Blocks**: Task 2
**Done when**: `### 1.1: Commit the expanded spec` subsection inserted after the `(Devshop mode)` addendum and before `## Phase 2`, with `git add` + `git diff --cached --quiet` guard + `docs($FEATURE): expand spec (Phase 1)` commit, no push; bats G1 + G2 added and pass on the targeted file.
**Risk**: low
**Status**: done

## Task: Extend registry row 1 + resume rungs 4/5 to committed state (edit regions B + C) + bats G3/G4

**Hat**: PM (devshop-self-mode SKILL.md prose change)
**Depends on**: Task 1
**Blocks**: none
**Done when**: registry row 1 reads `git show HEAD:$FEATURE_DIR/spec.md \| grep -q '## Task order'` (Producer Phase 1.1, pipe-escaped); rungs 4 + 5 read committed state via `git show HEAD:`; discriminator paragraph lightly amended; bats G3 + G4 added; targeted file AND full sweep green.
**Risk**: low
**Status**: done

## Decisions

- **Task 2 — pre-existing full-sweep failure routed, not fixed.** The full bats
  sweep has one failing test (`structural-invariants.bats:267`, "every
  non-exempt kit script is wired into a hook or pre-commit") flagging
  `reconcile-task-commits.sh`. Confirmed pre-existing on `main` (the script
  shipped in `ca4bc76`; my change touches only SKILL.md + `util-ak-build-skill.bats`,
  neither in that test's scope). Out-of-scope discovery → routed to `kit/TODOS.md`
  per the TODO protocol rather than expanding this feature's scope. All 46
  targeted-file assertions (incl. G1–G4) pass; the rest of the full sweep
  (1561/1562) passes.
