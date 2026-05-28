# Tasks: ak-build-no-silent-scope-down

Prose-only devshop-self change. Test surface is bats. No METRICS.md / vitest / Playwright.

## Task: Prohibition block + Phase 0 one-liner in build/SKILL.md

**Hat**: PM (skill prose)
**Depends on**: none
**Blocks**: Section E tests
**Done when**: `## Non-negotiable: run the full pipeline` H2 inserted between the
"Two modes" intro block and `## Architecture: subagent delegation`; contains the
unconditional default, no-discretion sentence, anti-bias framing, exception path,
and an embedded AskUserQuestion template (3 ordered options). Phase 0 one-liner
cross-referencing the block inserted as the first line under `## Phase 0`. No
`Step 0.1` / `assess pipeline applicability` introduced.
**Risk**: medium (wording is load-bearing — D2)
**Status**: done

## Task: One-line coherence touch to kit/docs/guide/workflow.md

**Hat**: PM (doc prose)
**Depends on**: none
**Blocks**: Section E tests
**Done when**: one sentence in workflow.md Step 4 (`/ak-build` step) notes the
pipeline runs in full by default and that /ak-build asks before deviating to a
lighter flow. One line, no new section.
**Risk**: low
**Status**: done

## Task: Section E regression-guard tests in util-ak-build-skill.bats

**Hat**: PM (tests)
**Depends on**: Task 1, Task 2
**Done when**: `# === Section E` banner + the @tests from spec § Tests appended,
greps pinned to the committed prose, including absence assertions
(`! grep ... 'assess pipeline applicability'`, `! grep ... 'Step 0\.1'`). Full
suite (A–E) green from the worktree.
**Risk**: low
**Status**: done

## Decisions

- **Task 1**: anti-bias prose must NOT contain the literal strings
  `assess pipeline applicability` or `Step 0.1`, because Section E's load-bearing
  absence assertions (`! grep ...`) would otherwise FAIL against my own negation
  of those terms. Rephrased the "no routine sizing beat" sentence to "no routine
  applicability check ... no preliminary work-sizing beat ... any such routine
  pre-run assessment" — conveys the same prohibition without tripping the
  absence greps. The greps stay meaningful: they still catch a future edit that
  *introduces* a real Step 0.1 / applicability beat.
