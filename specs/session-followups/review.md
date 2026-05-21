# Review — session-followups

## Audit 1: manual (2026-05-20)

<!-- audited-at: 073b048 -->
<!-- range: origin/main..HEAD -->

findings: high=1 medium=1 low=1

### Docs findings

- (none)

### Tests findings

- [high] `kit/tests/structural-invariants.bats:747-762` — new E5 placeholder-free header test is structurally incapable of failing. The shell sequence `grep -q ... && { ... false; } || true` evaluates to true regardless of grep outcome (the trailing `|| true` swallows the `false`). The test passes today even though `src/index.ts` line 1 contains the placeholder it claims to guard against. Fix in commit `f71f0a6` (Audit 2): rewrite to if-then-fail shape; narrow scope to vitest.config.ts only (src/index.ts + package.json legitimately keep the placeholder — substituted at scaffold time by Step 10 sed).
- [medium] `kit/tests/util-ak-merge-devshop.bats § Phase 3` source-worktree test used a single grep-qiE OR with 4 alternatives — exactly the loose-OR anti-pattern the same commit refactored away from for Phase 4.2. Fix in commit `f71f0a6`: split into 3 independent grep-q calls (never-touch-devshop / direct-push-from-worktree / skip-checkout-and-ff).
- [low] `kit/tests/util-ak-merge-devshop.bats § Phase 0.1` source-worktree had 5 guard predicates with only 2 covered. Fix in commit `f71f0a6`: added 3 new tests pinning path-does-not-exist refusal + on-main-or-detached refusal + no-commits-ahead refusal.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: ce549adc2c729047f8eb42d3bf500fe6730511fd -->
<!-- range: 073b048..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none — range is test-only + audit-trail-only; devshop self-mode carve-outs apply)

### Tests findings

- (none — all 3 Audit 1 closures verified: E5 test now if-then-fail shape + scoped to vitest.config.ts only; Phase 3 OR-grep split into 3 independent grep-q calls; Phase 0.1 5/5 guards covered. Full kit/tests/util-ak-merge-devshop.bats + structural-invariants.bats: 128/128.)

### Bypass trailer audit

- (none)

