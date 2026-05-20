# Review — squash-hygiene-check

## Audit 1: manual (2026-05-20)

<!-- audited-at: af4971b -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=3

The two findings surfaced by the post-merge run of this audit (medium: `conventions.md § Where the rule fires` PR row cited `hooks.md § Devshop mode` instead of `§ Project mode`; low: CLAUDE.md cited bare `SKILL.md § 0.3` without path qualifier) were closed in `af4971b` BEFORE this section landed. Three test-side low findings remain — all defensive coverage gaps with no behavioral risk; recorded for follow-up but not blocking the merge.

### Docs findings

- (none — both pre-fix findings closed in `af4971b`)

### Tests findings

- [low] kit/tests/util-adversarial-review-narrowing.bats:161 — happy-path test does not grep for the `Constituent commits being squashed (origin/main..$HYG_BRANCH):` header. A future refactor that drops the `git log` interpolation would not be caught by current assertions.
- [low] kit/scripts/adversarial-review.sh:319 — `HYG_BRANCH` fallback to `git branch --show-current` is not exercised by any test (all four added tests set `DEVSHOP_HYGIENE_BRANCH` explicitly). A future caller invoking the squash surface without the env var, from a detached HEAD, would silently produce an empty range.
- [low] kit/tests/util-adversarial-review-narrowing.bats — no test drives a FAIL-returning `claude` mock to verify the script preserves the non-zero exit + diagnostic text through to the caller's `2>&1` capture.

### Bypass trailer audit

- (none)
