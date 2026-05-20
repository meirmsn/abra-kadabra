# Review — convention-housekeeping

## Audit 1: manual (2026-05-19)

<!-- audited-at: c1d53cf3a0a2f8d56d5c43e556a77b16b4f6fd35 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=4 low=2

### Docs findings

- [medium] kit/docs/guide/conventions.md:28-29 — ToC entries `[Confidence Calibration]` + `[TODO Protocol]` still link to anchors deleted in e0d5adc. Pattern in same ToC for relocated sections is `_moved to [...]_` suffix; missing here.
- [medium] kit/docs/guide/workflow.md:455 — Asserts conventions.md baseline coverage includes "Confidence Calibration"; no longer in conventions.md post-e0d5adc.
- [medium] kit/docs/guide/ops.md:333 — Tail of PostgREST gotcha bullet says "Inherited by every new project as a template/CLAUDE.md § Gotchas entry"; FALSE post-3633daa strip.
- [medium] kit/docs/guide/hooks.md:150 — Hook diff (00e155f) added an audit-prose carve-out to `check-docs-coverage-project.sh`; hooks.md still describes the hook without the carve-out.
- [low] template/CLAUDE.md:14 — Stale reference to `check-docs-freshness-project.sh` (renamed to `check-docs-coverage-project.sh` in PR-C). Pre-existing in template, but bundle touched the file so on review surface.

### Tests findings

- [low] kit/tests/guard-docs-coverage-project.bats:104-113 — BLOCK negative-case test under-specifies the contract. Asserts `assert_output --partial "METRICS.md"` but doesn't pin which staged path is cited. A regression citing the prose path instead of the real call site would still pass. Tightener: add `assert_output --partial "apps/web/lib/foo.ts"` + `refute_output --partial "specs/foo/review.md"`.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-19)

<!-- audited-at: d6fa5607452d6c5d0f92e989f04a14bb772eabd5 -->
<!-- range: b17e123..HEAD -->

findings: high=1 medium=2 low=1

### Docs findings

- [high] commit `d6fa560` message body — asserts `30/30 suite passing` but actual run is 29/30. Test #8 (`BLOCK: actual call site...`) fails on the newly-added `assert_output --partial "apps/web/lib/foo.ts"` because the hook's BLOCK message doesn't emit file paths — only the generic literal `new posthog.capture(...) / Sentry.captureException(...) call site(s)`. Audit 1's tightener was based on a false premise about hook output. Recovery: revert the tightener (original test was sufficient — it caught broad-exempt regression via the BLOCK-vs-PASS contrast).
- [medium] kit/docs/guide/conventions.md:687 — Audit 1 finding #4 was a two-location fix (hooks.md AND conventions.md § Project Docs Coverage § Trigger map); only hooks.md was updated.
- [medium] kit/docs/guide/conventions.md:28-29 — ToC `_moved to_` suffixes added in d6fa560 fix HALF the pattern; sibling sections (Supabase Hardening Defaults at line 24, etc.) pair the ToC self-anchor with a stub heading later in the file. The two newly-deleted sections need matching stub headings so bare anchors `(#confidence-calibration)` and `(#todo-protocol)` resolve.
- [low] template/METRICS.md:3 + template/.devshop-docs-freshness-exempt:1 — Sibling stale `check-docs-freshness-project.sh` references not unwound by d6fa560's template/CLAUDE.md ride-along.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Audit 3: manual (2026-05-19)

<!-- audited-at: fe4459aa70e7b9e95e8c75e69b09e4fa8eb4f4dd -->
<!-- range: 2c076fa..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/ROADMAP.md:939 — Pre-existing stale `check-docs-freshness-project.sh` reference (post-rename `check-docs-coverage-project.sh`) in v0 entry (E6) gen #11. Outside the closure commit's template-only scope but same drift class.

### Tests findings

- (none) — agent independently re-ran bats suite (30/30 passing) + read hook source to verify the path-scope contract pins at the diff-input level via the pathspec exclusion + 3 companion tests.

### Bypass trailer audit

- (none)
