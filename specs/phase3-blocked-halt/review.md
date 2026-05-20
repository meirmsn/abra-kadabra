# Review — phase3-blocked-halt

## Audit 1: manual (2026-05-20)

<!-- audited-at: 8bd839f81f6964915af1cc0eda061e3c73bc02a9 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=3 low=1

### Docs findings

- [medium] kit/docs/guide/hooks.md:385 — Per-check-type model routing table's Sonnet row missing `blockedGateOverride`; operators looking up routing get a stale answer.
- [medium] kit/docs/guide/hooks.md:251 — "One check-type runs at pre-ship time rather than commit-time" framing now stale: `blockedGateOverride` is a second non-commit-time check-type (rationale lives in advance-log body, no `git -c devshop.<key>` surface).
- [medium] kit/docs/guide/hooks.md:421 — `/ak-build Phase 5.8 — testReviewSkipReason` section closes with "the only adversarial-review check-type whose surface isn't a git hook" — stale now that `blockedGateOverride` also fires inside `/ak-build`.
- [low] (range-level) — No `Docs-Coverage-Bypass:` trailers in range. Informational only.

### Tests findings

- (none) — bats coverage at `kit/tests/util-adversarial-review-blockedGateOverride.bats` (16 tests) matches the new `blockedGateOverride` case branch end-to-end: case wiring, prompt structure, Sonnet routing, FAIL/PASS paths, prior advance-log precedent surface, graceful degrade, narrowing fallback. Concrete content assertions throughout; no weak / shape-only patterns.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: f5a1144f6e9fa7e44c9edf73ab868ba2681f4ec3 -->
<!-- range: 8bd839f81f6964915af1cc0eda061e3c73bc02a9..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none) — Audit 1's three medium findings all closed by `f5a1144 fix(hooks): reflect blockedGateOverride in routing table + section heads`. Section sweep verifies: routing table (line 385) lists `blockedGateOverride` in Sonnet row; non-commit-time section (line 251) reframed to "Two check-types" with a second bullet matching `coreUserStoryNaReason`'s shape; testReviewSkipReason section closer (line 421) names both `testReviewSkipReason` and `blockedGateOverride` as the two non-git-hook check-types. All three sections mutually consistent.

### Tests findings

- (none) — Range is docs-only (`kit/docs/guide/hooks.md` + audit-artifact meta-commits). No new executable surface; no test-coverage gap. Bats coverage at `kit/tests/util-adversarial-review-blockedGateOverride.bats` from the prior commit is unchanged.

### Bypass trailer audit

- (none)
