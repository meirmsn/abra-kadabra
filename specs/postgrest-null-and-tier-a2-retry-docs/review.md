# Review — postgrest-null-and-tier-a2-retry-docs

## Audit 1: manual (2026-05-08)

<!-- audited-at: 1f99e9205eec0f7e1b600bc1d53af8dcbefe6d1b -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=2

### Docs findings

- [low] kit/docs/guide/testing.md:66 — Cross-ref to `kit/docs/guide/conventions.md § Latency feedback framework` is dangling at HEAD; the `(post-lift from ...)` parenthetical signals it but the link form still suggests the section exists. Fix: either accept as forward-looking with an HTML-comment marker, or reword to "(currently in `lalista/specs/app-snappiness/spec.md § D1`; pending lift)".
- [low] template/CLAUDE.md:22 — Convention rule "Add an entry only when a real gotcha bit a session — not preemptively." is in tension with this PR seeding an inaugural inherited gotcha into the template. User-approved trade-off (real lalista PR #49 incident). Fix: tighten the rule to permit inherited gotchas with a `Source: <project> PR #N` reference; defer if accepting the trade-off as-is.

### Tests findings

- (none) — prose-only PR; no source/tests/scripts/migrations changed. Section A and B rubrics do not apply.

### Bypass trailer audit

- (none) — no `Docs-Coverage-Bypass:` or `Tests-Coverage-Bypass:` trailers in range.
