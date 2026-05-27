<!-- audited-at: 37f1ae9 -->

## Section A — Coverage

All changed files are in coverage carve-outs:

- `PLAN.md` — not a rubric surface.
- `kit/ROADMAP.md` — explicitly carved out.
- `kit/docs/guide/migrations.md` — `kit/docs/**` carve-out ("audit handles guide-only commits").

No coverage findings.

## Section B — Adequacy

### [domain: docs] [section: B] [severity: low]

**File**: kit/docs/guide/migrations.md:5-15
**What**: `## Contents` ToC not updated with new `### Upcoming: explicit GRANTs required on all new tables (Oct 2026)` subsection.
**Why**: The parent section `## Supabase Cloud GRANT posture` was already missing from the ToC (pre-existing), but this branch added a new subsection under it and did not update the ToC. Readers navigating via the ToC will not discover the new rule.
**Fix**: Add `- [Supabase Cloud GRANT posture](#supabase-cloud-grant-posture)` and `  - [Upcoming: explicit GRANTs required on all new tables (Oct 2026)](#upcoming-explicit-grants-required-on-all-new-tables-oct-2026)` to the `## Contents` section. Also add the other missing pre-existing entries (`plpgsql OUT-parameter column collisions`, `Why not just edit the original create type migration`).

## Section C — Cross-doc coherence

No contradictions found. Checked:

- `kit/docs/OVERVIEW.md:268` summarizes `migrations.md` — summary does not claim to be exhaustive; no contradiction with the new GRANT subsection.
- `kit/docs/guide/README.md:44` routing entry routes `CREATE TABLE` / `GRANT ALL` / `42501` keywords to `migrations.md § Supabase Cloud GRANT posture` — the new subsection is a child of that section, so routing still fires correctly.
- `kit/docs/guide/README.md:137` alphabetical list describes `migrations.md` without the GRANT rule — same summary-level entry, no contradiction.
- No renamed or deleted files in range; no stale-reference sweep needed.

## Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range.

## Section E — CLAUDE.md hygiene

Skipped — devshop mode (Section E is project mode only).
