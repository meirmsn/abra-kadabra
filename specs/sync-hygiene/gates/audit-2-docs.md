# Docs Review — Audit 2

**Range**: `9f8217e2dc9e8c7c5a035d10f934397982cb5ad1..HEAD` (2 commits: `099ab2d`, `77ca94d`)
**Date**: 2026-05-26
**Prior audit**: Audit 1 found 2 medium + 1 low. Commit `77ca94d` fixed all three.

## Section A — Coverage

All three Audit 1 medium/low findings addressed in `77ca94d`:

1. **architecture.md:181** — now documents the `package.json` jq merge exception with identity fields (`name`, `version`, `packageManager`) preserved and structural fields synced from template. Fallback to raw copy documented. **VERIFIED — fix adequate.**
2. **ops.md:71** — battle-earned fixes count updated from "Five" to "Seven"; two new bullets added (dynamic API port from `config.toml`, `./apps/web` directory-based filter). **VERIFIED — fix adequate.**
3. **conventions.md:159** — filter form updated from bare `apps/web` to `./apps/web`. **VERIFIED — fix adequate.**

New source change in range: `kit/scripts/sync/from-devshop.sh:72` — jq guard refined from `command -v jq` to `echo '{}' | jq '.'`. Matching doc coverage exists in `architecture.md:181` ("If jq is unavailable, falls back to raw copy") within the same commit. Coverage satisfied.

No uncovered source changes remain.

## Section B — Adequacy

Verified each touched doc's claims against source:

- **architecture.md:181** — claims `from-devshop.sh` preserves `name`, `version`, `packageManager` while syncing structural fields. Source (`from-devshop.sh:76-83`) confirms: jq does `$tmpl + { name: $proj.name, version: ($proj.version // $tmpl.version), packageManager: ($proj.packageManager // $tmpl.packageManager) }`. Accurate.
- **ops.md:77** — claims dynamic port reads from `supabase/config.toml`, falls back to 54321. Template CI (`ci.yml:213-214`) confirms: `grep -A5 '^\[api\]' supabase/config.toml | grep '^port'` with fallback `[ -z "$API_PORT" ] && API_PORT=54321`. Accurate.
- **ops.md:78** — claims `./apps/web` prefix survives scoped package names. Template CI lines 199, 285, 319 all use `./apps/web`. Accurate.
- **ops.md:71** — count "Seven battle-earned fixes" matches 7 sub-bullets (lines 72-78). Accurate.
- **conventions.md:159** — claims template invokes `pnpm --filter ./apps/web test:e2e`. Template CI line 319 confirms. Accurate.

No stale cross-references found: `grep` for bare `apps/web` filter form and "Five battle-earned" across all docs returned zero hits.

No stub edits, no dangling references, no missing actionable guidance.

## Section C — Cross-doc coherence

- No renames or deletions in the range.
- `OVERVIEW.md:229` mentions `package.json` in the template skeleton listing — no behavioral claims about sync, so no contradiction with the new architecture.md merge-exception paragraph.
- No contradictions found between touched docs and non-touched reference docs.

## Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range.

## Section E — CLAUDE.md hygiene

Skipped (devshop mode — Section E is project-mode only per the skill spec).

## Summary

- **high**: 0
- **medium**: 0
- **low**: 0

Clean — no docs findings. All three Audit 1 findings verified as adequately fixed.
