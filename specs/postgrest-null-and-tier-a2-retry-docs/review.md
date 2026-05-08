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

## Audit 2: manual (2026-05-08)

<!-- audited-at: 132a98d9a856411456b1db455620963b1cc46efe -->
<!-- range: origin/main..HEAD -->
<!-- rebased: prior audit at 1f99e92 squashed into main as eb26f79; range overridden from 1f99e92..HEAD to origin/main..HEAD to focus on the actual branch delta -->

findings: high=0 medium=0 low=1 (resolved inline before squash)

### Docs findings

- [low → resolved] kit/docs/guide/testing.md:66 — Parenthetical "(focused stub today — Tier C only)" undercounts what `kit/docs/guide/latency-feedback.md` actually ships (Tier C at line 21 + sizing-primitive override rule at line 72). Fixed inline by rewording to "(focused stub today — Tier C + sizing-primitive override only)" before squash-merge.

### Tests findings

- (none) — one-line prose edit; Section A and B rubrics do not apply.

### Bypass trailer audit

- (none) — no trailers in range.
