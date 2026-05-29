## Gate 5: docs-and-tests-review

<!-- audited-at: 81d238b0d744a482ff39df7c69315f24097e282f -->
<!-- range: 4a77f285af222a3128315a76cd2b32fa1cd446a5..81d238b0d744a482ff39df7c69315f24097e282f -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] specs/implement-resume-reconcile/spec.md:§Tests case 7 — spec names only 2 usage-error cases (missing feature-dir arg; tasks.md absent), but the implemented bats adds a 3rd (`case 7c: unresolvable base-ref → exit 64`). Tests exceed the spec rather than fall short; spec could enumerate the base-ref case for parity. Informational drift only, no coverage gap.

Coherence + coverage (no findings): the four changed prose surfaces (build/SKILL.md Step 0 rung 2, build/SKILL.md Phase 2 note, implement/SKILL.md step 11 + Step 4, workflow.md tasks.md description) all describe the same gate consistently. workflow.md's stale "per-task status with commit SHAs" claim was correctly rewritten and is guarded by a negative bats assertion. Script D1/D3/D4 cross-refs resolve to real spec sections. The awk `done` matcher matches exactly the `**Status**: done` marker /ak-implement writes.

### Tests findings

- (none)

Coverage + adequacy (no findings): the reconcile gate is covered by `util-reconcile-task-commits.bats` (11 cases, all green at HEAD): pass, count-shortfall, dirty-tree, partial-done, rebase-SHA-rewrite (D3), bookkeeping-exclusion positive (case 6) + load-bearing negative (case 6b), 3 usage errors, mawk parity. Assertions are deep — every case asserts the exact exit code AND greps concrete diagnostic values (`done=3`, `impl-commits=1`, `no matching commit`, `dirty`, `does not resolve`), not presence-only. Case 5 asserts SHAs actually changed before asserting the verdict survived. Case 6b is mutation-resistant (inverts case 6 to prove a prefix-typo regression would fail). Wiring guarded by `util-ak-build-skill.bats` Section F (6 region-scoped grep cases). Full suite green 1545/1545. The done_count=0 edge is unreachable via rung 2 (routes via rung 6) — no test owed.

### Bypass trailer audit

- (none)
