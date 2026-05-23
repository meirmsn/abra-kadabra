# Review — kit-scripts-deny-rule-investigation

## Audit 1: manual (2026-05-23)

<!-- audited-at: a917e9daa3b07e86150d3a6bfe25bad255dfca04 -->
<!-- range: origin/main..HEAD -->

findings: high=2 medium=0 low=1

### Docs findings

- [high] kit/docs/guide/security.md:52 — Docs assert deny rules use only absolute-path patterns, but settings.json still has relative patterns. The committed settings.json has 4 deny lines; the docs claim 2. When merged, init-devshop.sh will lock the 4-line version, contradicting the docs.
- [high] CLAUDE.md:119 — Known Footguns entry claims worktree copies are "intentionally editable" but the relative deny patterns `kit/scripts/**` still exist in the committed settings.json and would fire on worktree paths.

### Tests findings

- [low] kit/scripts/sync/from-devshop.sh:14 — `PROJECT_ROOT` resolution changed from 3-levels-up to 2-levels-up with no functional test covering the path resolution. Pre-existing gap, not newly introduced.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-23)

<!-- audited-at: 7eac1c7 -->
<!-- range: a917e9d..HEAD -->

findings: high=0 medium=1 low=0

### Docs findings

- (none)

### Tests findings

- [medium] kit/tests/structural-invariants.bats (missing test) — No regression guard test asserts that kit/scripts deny rules use absolute paths only. A future settings.json edit could re-add relative patterns without any test catching it.

### Bypass trailer audit

- (none)

## Audit 3: manual (2026-05-23)

<!-- audited-at: 233fdf3 -->
<!-- range: 7eac1c7..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none) — no docs touched in range

### Tests findings

- (none) — regression guard test added in 233fdf3 addresses Audit 2 medium finding

### Bypass trailer audit

- (none)
