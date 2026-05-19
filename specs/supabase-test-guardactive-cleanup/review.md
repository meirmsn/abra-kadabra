# Review — supabase-test-guardactive-cleanup

## Audit 1: manual (2026-05-19)

<!-- audited-at: be732a5f076f0e669019e74bd4e5e999738fd832 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=0

### Docs findings

### [domain: docs] [section: C] [severity: medium]
**File**: .claude/skills/devshop/new-project/SKILL.md:778
**What**: Stale reference to removed `guardActive` symbol — comment still claims "If guardActive=false (placeholder still present) the prod-URL tests are skipped — re-check the sed substitution." The `guardActive` const and all four `it.skipIf(!guardActive)` wrappers were removed from `template/packages/core/src/supabase.test.ts` in this commit. The five guard tests now always run; no conditional-skip exists for the operator to diagnose.
**Why**: Cross-doc coherence — a reference doc not touched by this PR still describes a symbol the PR deleted. Operator running `/ak-new-project` Step 10 Sub-step 1 will be misdirected if a guard test fails (the "re-check the sed substitution" advice presumes a skip mechanism that no longer exists). Same severity class as the rubric's "deleted file in this commit → stale references → finding" case, applied to a deleted symbol.
**Fix**: Update SKILL.md:778-779 to reflect unconditional-run reality. Suggested replacement: `# Expected: 5 tests pass unconditionally. If a guard test fails, the sed substitution likely did not hit PROD_REF in supabase.test.ts — re-run the substitution and verify PROD_REF holds your real project ref.`

### Tests findings

- (none)

### Bypass trailer audit

- (none)
