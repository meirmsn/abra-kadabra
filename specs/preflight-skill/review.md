# Review — preflight-skill

## Audit 1: manual (2026-05-12)

<!-- audited-at: bf39e322cbadf7770638cc2021932eb4ca2f7d12 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=4 low=0

### Docs findings

- [medium] kit/docs/guide/workflow.md:449 — Devshop Skill Map table entry for `/ak-pre-ship` still says "15 gates"; the ASCII pipeline diagram + Phase 3 narrative in the same file were updated to 17. **Fix:** rewrite as "17 gates incl. rls-coverage, slow-job-lifecycle, fast-job-local, changed-tests-local, design-conformance, preflight-final" so the table also names the newly-added gates.
- [medium] CLAUDE.md:128 — `changed-tests-local (ak) pre-ship gate (#2d, ...)` carries stale gate-position number after this PR renumbered the gate from 2d to 2e (to seat the new `fast-job-local` gate ahead of it). **Fix:** `#2d` → `#2e`. Narrative description of what the gate does is unchanged.
- [medium] kit/docs/guide/conventions.md:272 — `the local-floor gate changed-tests-local (#2d in /ak-pre-ship)` carries the same stale gate-position number. **Fix:** `#2d` → `#2e`.
- [medium] kit/docs/guide/conventions.md:276 — `/ak-pre-ship Gate changed-tests-local (ak) at #2d` carries the same stale gate-position number. **Fix:** `#2d` → `#2e`.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Followup

All 4 medium-severity findings fixed inline in the same commit (via `git commit --amend` after the audit ran). Final HEAD is clean (0/0/0). Listed Audit 1 retains the original findings as historical record; subsequent re-audits of this range will detect the amend (the `audited-at` SHA points to the pre-amend HEAD which is no longer in the branch's commit chain) and fall back to a fresh range per `/ak-check-docs-and-tests` Step 2's rebase-fallback contract.
