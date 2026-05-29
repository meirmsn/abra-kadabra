# Tasks: ak-build-phase6-pr-surface

Source: `specs/ak-build-phase6-pr-surface/spec.md § Task order`. All edits land in
`.claude/skills/devshop/build/SKILL.md` (Tasks 1+2) and
`kit/tests/util-product-update-blurb.bats` (Task 3). devshop-self-mode: bats test
surface, no METRICS.md, no UI.

Pre-scan against STOP-AND-ASK (CLAUDE.md § Confidence Calibration): none fire —
skill-prose edit, no schema/auth/third-party-API/perf/security/test-deletion. The
bats change adds one assertion and rewrites one to track the new contract.

## Task: D1 + D3 — drop the audit-comment post + consistency sweep

**Hat**: PM (skill-prose / docs)
**Depends on**: none
**Blocks**: D2, Tests
**Done when**: `grep -nE 'audit comment|audit-trail comment|Post audit trail comment'`
on SKILL.md returns nothing framing Phase 6 as *posting/rendering-in* a comment; the
`gh pr comment` audit block + "intentionally concise" preamble + `# NOW post…`
exit-checklist step are gone; Parts A–D verification sweeps remain; `gh pr edit`
body-fix calls in Parts A/B remain. Phase 7 confirmed comment-free.
**Risk**: medium (large file, many drifting line numbers — re-grep after each edit)
**Status**: done

## Task: D2 — rewrite Part D / Gate A to autonomous 3-way classify

**Depends on**: D1
**Blocks**: Tests
**Done when**: Gate A is autonomous (Accurate / Edit-and-self-resolve / Escalate),
mirroring Part C; the two "Why operator attention" + "~30s of operator attention"
justification paragraphs are removed; the `awk` blurb-extraction snippet + Gate-B
findings input are preserved; the Part D exit marker remains.
**Risk**: low
**Status**: done

## Task: Tests — update + add bats assertions

**Depends on**: D1, D2
**Blocks**: none
**Done when**: `kit/tests/util-product-update-blurb.bats` line-164 Gate-A assertion is
rewritten to the autonomous contract; a new "Phase 6 posts no audit comment"
assertion (mirroring the Phase 7.2 precedent) targets the comment verb specifically;
`bats kit/tests/util-product-update-blurb.bats` is green; broader affected bats green.
**Risk**: low
**Status**: done

## Decisions
