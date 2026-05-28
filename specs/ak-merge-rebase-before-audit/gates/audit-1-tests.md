Tests look solid — no findings.

### Coverage + quality notes (informational)

- **Section A (coverage of new behavior)**: the SKILL.md restructure is a doc-only behavior change to a skill prose contract; the devshop-side rubric maps `.claude/skills/devshop/**/SKILL.md` changes to `util-<skill>.bats` smoke coverage. That coverage exists and was extended in-range: `kit/tests/util-ak-merge-devshop.bats` Section F2 adds 5 new tests pinning the load-bearing invariants —
  - rebase-before-audit ordering (rebase line < audit-invoke line, by line number),
  - Phase 1.0 runs `$GIT_CMD rebase "$ANCHOR"`,
  - Phase 1.0 anchor-selects between `origin/main` and local `main`,
  - Phase 1.0 documents the virtiofs phantom-error → merge fallback,
  - Phase 1.1 passes the explicit `--range ${ANCHOR}..HEAD`.
    Plus a Section G regression guard asserting Phase 2 NO LONGER contains a bare `$GIT_CMD rebase` line, and the phantom-error test repointed from Phase 2 to the Phase-1.0 dependency. Every new invariant in the diff has a corresponding assertion.
- **Section B (test quality)**: assertions are concrete, not weak — they grep for specific literal tokens (`$GIT_CMD rebase "$ANCHOR"`, `range ${ANCHOR}..HEAD`, `skill: "ak-check-docs-and-tests"`) and the ordering test compares actual line numbers (`[ "$rebase_line" -lt "$audit_line" ]`) rather than mere existence. The negative regression guard (`! ... | grep -qE '^\$GIT_CMD rebase'`) directly defends the restructure's core invariant. No `.only` / `.skip` patterns in the diff. No weak `toBeDefined`-equivalent shapes (the bats idiom here is `grep -q` exit-status, which is a real assertion against file content).
- **Empirical verification**: ran the full file with the vendored runner (`kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-merge-devshop.bats`) — **96/96 passing**, including all 5 new Section F2 tests (54–58) and the 2 updated Section G tests (60, 62). All grep anchors the tests rely on resolve against the live SKILL.md (verified Phase headers at lines 633/768/893/1058; rebase at 671 < audit-invoke at 809).
- No `Tests-Coverage-Bypass:` trailers in range.
