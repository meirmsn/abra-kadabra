# Review — conventions-md-globbing

## Audit 1: manual (2026-05-12)

<!-- audited-at: 3a08240db7c85a40f4f14b68c4894a6d4f19778a -->
<!-- range: origin/main...HEAD -->

findings: high=0 medium=0 low=1

> Audit-1 pre-history: an earlier audit at `40da79a` returned 1 high (conventions.md:254 corrupted by prettier rewriting nested `*` → `_` inside a `**…**` bold span that also contained inline-code `**/*.md`). Resolved at `3a08240` by splitting the warning into two paragraphs and keeping the bold span asterisk-free; verified prettier-idempotent (`pnpm exec prettier --write` returns `unchanged`). This `## Audit 1` records the post-fix HEAD only.

### Docs findings

- [low] specs/slow-job-skip-on-docs-only/spec.md:165 — historical spec's "case matches treat `**` as `*` collapsing two levels — close enough for this list" dismissal turned out to be the bug PR #63 surfaced. Spec is time-frozen, so optional 1-line `> [!CORRECTION]` breadcrumb pointing at `kit/docs/guide/conventions.md § Skip-on-docs-only filter`. Low because live guides carry the corrected truth; the spec isn't on the canonical-doc surface.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
