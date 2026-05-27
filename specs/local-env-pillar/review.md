# Review — local-env-pillar

## Audit 1: manual (2026-05-27)

<!-- audited-at: 37f1ae940196f412ea407c2d5091fb0292af3845 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/docs/guide/migrations.md:5-15 — `## Contents` ToC not updated with new `### Upcoming: explicit GRANTs required on all new tables (Oct 2026)` subsection. The parent section `## Supabase Cloud GRANT posture` was already missing from the ToC (pre-existing), but this branch added a new subsection under it and did not update the ToC. Readers navigating via the ToC will not discover the new rule.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
