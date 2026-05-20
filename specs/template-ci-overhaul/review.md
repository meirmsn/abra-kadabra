# Review — template-ci-overhaul

## Audit 1: manual (2026-05-19)

<!-- audited-at: 5fb1abc06b8e22a9e0b7140cd097554a5f27b92a -->
<!-- range: origin/main..HEAD -->

findings: high=3 medium=3 low=5

### Docs findings

- [high] .claude/skills/devshop/pre-ship/SKILL.md:251,380-398 — gate 2c row + dedicated section still document pre-2026-05-19 conditional-on-Phase-1c/1g behavior; not touched by this PR though the gate's behavior changed (now active-from-day-one, new Check 4 / 4b, no `n/a (threshold not crossed)` exit path). Operators land on the wrong mental model.
- [medium] kit/docs/guide/conventions.md:16,18 — TOC entry `[Uncommenting checklist](#uncommenting-checklist)` dangling (section removed in this PR); `[Structural enforcement](#structural-enforcement)` anchor stale after rename to `#structural-enforcement-regression-guard`.
- [low] .claude/skills/devshop/build/SKILL.md:617,673,836 — three bare gate-name refs (informational; bare enumerations don't need behavior-tracking).
- [low] kit/docs/guide/conventions.md:154-296 — adequacy spot-check; Per-step empty-state guards table grounds claims in specific globs; all paths verified against template ci.yml.
- [low] no Docs-Coverage-Bypass trailers in range.

### Tests findings

- [high] kit/tests/preship-slow-job-lifecycle.bats — bats spec for the rewritten gate was NOT touched. Line 55 asserts the removed n/a string; lines 164 + 245 assert the old Check 2 finding text; fixture lines 149–165 no longer triggers Check 2 (its if: lacks the `needs.changes.outputs.runtime` reference the rescoped check requires); new Check 4 (hashFiles guards) + 4b (Start local Supabase unguarded) have zero coverage.
- [high] kit/tests/structural-invariants.bats:619 — invariant "all kit/scripts/*.sh tracked as 644" violated: both `slow-job-lifecycle-check.sh` and `migration-rollback-roundtrip.sh` are now 755 in the index. The test was reverted from worktree-aware `git rev-parse --show-toplevel` to hardcoded `git -C /devshop`, masking the violation. Either `git add --chmod=-x` the two scripts (restores 644 + test silently passes) or restore worktree-aware resolution.
- [medium] kit/tests/template-ci-yml-shape.bats:204-212 — "Start local Supabase has NO hashFiles gate" reads only the line immediately after `- name:`. An `env:` block or comment inserted between `name:` and `if:` would silently bypass the guard. Scan forward to next step boundary instead.
- [medium] kit/tests/template-ci-yml-shape.bats (multiple @test blocks) — generic patterns like `^[[:space:]]+- uses: actions/checkout@v4` match both fast-job and changes-job. A malformed changes-job could pass the test on fast-job's match alone. Job-scope each assertion (awk between `^  changes:` and next `^  [a-z]+:` boundary).
- [low] kit/tests/template-compose-isolation.bats:179-183 — supabase-port assertions hardened from env-var form to literal `54321/54322`. If env-aware ports remain the convention, restore the indirection; if reverted intentionally, document. (Outside this branch's stated scope.)
- [low] no Tests-Coverage-Bypass trailers in range.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-19)

<!-- audited-at: 9850786498f410cb77c29c0c399195a306bccdd5 -->
<!-- range: 5fb1abc06b8e22a9e0b7140cd097554a5f27b92a..HEAD -->

findings: high=0 medium=0 low=8

All Audit 1 high + medium findings closed by commit 9850786. Re-audit confirms:

- HIGH-1 (docs, pre-ship/SKILL.md gate-2c row + section): rewritten to day-one-active model; check set enumerated matches gate behavior.
- HIGH-2 (tests, preship-slow-job-lifecycle.bats): rewritten end-to-end (24 tests); Check 4 / 4b coverage added; broken-if: fixture refit to trigger rescoped Check 2.
- HIGH-3 (tests, structural-invariants.bats): both scripts chmod 100755 → 100644 in index + filesystem; invariant #102 passes for first time.
- MEDIUM-1 (docs, conventions.md TOC): dangling `#uncommenting-checklist` removed; new sub-section anchors added; `Structural enforcement` anchor updated.
- MEDIUM-2 (tests, template-ci-yml-shape.bats): Start-local-Supabase guard scope widened via awk; `job_body()` helper added for job-scoped changes-job assertions.

### Docs findings

- [low] coverage: every source surface touched in range has matching doc edits OR is mechanical chmod-only bookkeeping that doesn't trigger the rubric.
- [low] adequacy: pre-ship/SKILL.md gate-2c rewrite is substantive and matches gate behavior; outcomes enumerate Check 2/4/4b/6/7 inline.
- [low] adequacy: conventions.md TOC anchors all resolve at HEAD; cross-repo grep for stale `Uncommenting checklist` returns zero hits.
- [low] coherence: cross-doc sweep for `Structural enforcement` heading rename has its sole consumer (TOC) updated; no other doc embeds the old anchor.
- [low] no Docs-Coverage-Bypass trailers in range.

### Tests findings

- [low] kit/tests/template-ci-yml-shape.bats:61 — dead `run bash -c ...` line in the `changes: job uses actions/checkout@v4` test (subshell can't see the `job_body()` helper; author's inline replacement works but the original line wasn't deleted). Cosmetic; propagation-hazard for copy-paste. Cleanup deferred to follow-up.
- [low] kit/tests/preship-slow-job-lifecycle.bats:592-622 — multi-gap test description says "three findings" but the gate emits four (migration-guard finding fires alongside the named three). Partial-match assertions still pass; cosmetic comment-vs-behavior drift. Cleanup deferred to follow-up.
- [low] no Tests-Coverage-Bypass trailers in range.

### Bypass trailer audit

- (none)

