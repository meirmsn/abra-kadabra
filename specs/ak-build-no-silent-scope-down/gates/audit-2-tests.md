Tests look solid — no findings.

Notes (not findings — informational):
- Coverage (Section A): the only source surface in range is
  `.claude/skills/devshop/build/SKILL.md` (a SKILL.md prose change) plus the
  `kit/docs/guide/workflow.md` coherence line. Devshop rubric for a SKILL.md
  change is satisfied by `util-<skill>.bats` smoke coverage — the new Section E
  (6 tests) in `kit/tests/util-ak-build-skill.bats` guards the prohibition
  block, its Phase 0 one-liner restatement, the AskUserQuestion template, and
  the workflow.md line. Covered.
- Quality (Section B): assertions are pinned to the exact committed prose
  (regression-guard pattern, appropriate for a prose-only SKILL.md change with
  no executable code path). No weak/vacuous assertions:
  - Test 33 ("anti-bias phrasing present AND forbidden step absent") is the
    load-bearing guard — positive greps confirm the deviation-as-exception
    framing, and negative greps (`! grep ... 'assess pipeline applicability'`,
    `! grep ... 'Step 0\.1'`) confirm the forbidden routine per-run
    applicability beat stays absent. Verified live: both negative-grep targets
    return 0 matches at HEAD, so the guards are meaningful, not vacuous.
  - Test 33 + Test 35 correctly anchor the `AskUserQuestion` / Phase 0
    cross-reference greps to the block region via `awk` range scans, avoiding
    the file-wide false-positive trap the test comments themselves call out.
  - No skip / `.only` / no-arg-skip patterns in the diff.
  - No browser/E2E, realtime, wrapper-API, or LLM/edge-boundary surfaces touched
    — those Section B sub-checks do not apply.
- Full suite run from the worktree: `bats kit/tests/util-ak-build-skill.bats`
  → 36/36 ok (tests 31–36 are the new Section E block). No skipped tests.
- Bypass trailers (Section C): no Tests-Coverage-Bypass trailers in range.
