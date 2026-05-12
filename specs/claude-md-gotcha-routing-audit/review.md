# Review — claude-md-gotcha-routing-audit

Audit log for PR-B. Sections appended by `/ak-check-docs-and-tests`.

## Audit 1: manual (2026-05-12)

<!-- audited-at: fcde118315582a188ada794fd39da8b79d5dae2a -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=2

### Docs findings

- [low] kit/docs/guide/migrations.md:6 — Contents ToC missing entry for the new H3 "Why `for update` matters here — Postgres EvaluatePlanQual (EPQ) semantics" nested under the "Load-bearing SQL invariants and sentinel comments" H2. Fix: add `  - [Why for update matters here — Postgres EvaluatePlanQual (EPQ) semantics](#why-for-update-matters-here--postgres-evaluateplanqual-epq-semantics)` as a nested bullet under the H2's Contents entry. Hygiene-grade — the H2 entry exists and the H3 is reachable.
- [low] kit/docs/OVERVIEW.md:109 — Claim `guide/ (~16 files, README is the context-aware routing index)` is stale; this PR added `tailwind.md` bumping the count to 17. Within "~" tolerance but a coherence drift this PR introduced. Fix: bump `~16 files` → `~17 files`.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Summary

Range covers 12 commits, 14 files touched. All touched paths are docs / notes / tracker / spec artifacts; no source surface in the diff. Behavior added (new routing rows + new `tailwind.md` guide) is covered by existing BATS suites — `routing-link-resolution.bats`, `routing-completeness.bats`, `routing-real-world-grounding.bats` — all three green at every commit (785/785 cases in full kit suite green throughout the branch). No test changes; no skip/only patterns; no bypass trailers. Two low-severity docs findings are hygiene-grade; do not halt.

## Audit 2: manual (2026-05-12)

<!-- audited-at: f3cf27aea77d5ef112fbd06cf2b083c316f5c43b -->
<!-- range: fcde118..f3cf27a -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Summary

Range covers 1 commit (`f3cf27a fix(docs): close 2 low-severity findings from Audit 1`), 3 files touched (`kit/docs/OVERVIEW.md`, `kit/docs/guide/migrations.md`, `specs/claude-md-gotcha-routing-audit/review.md`). The commit is the targeted resolution of Audit 1's two low-severity items. No source surface; no new tests; no skip patterns; no bypass trailers. **Clean — Audit 1 findings resolved.**
