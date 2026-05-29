findings: high=0 medium=1 low=2

## Docs findings

- [medium] template/apps/web/next.config.ts — diff touches `template/**` but no per-commit body in the range carries an `**Existing projects:**` migration block. **ALREADY RESOLVED** (not a new finding): identical to the Audit 1 medium. The migration block lives in the `/ak-merge-devshop` squash commit body (already composed + operator-approved), which is the correct resolution per spec Decision D4. The squash-surface hygiene reviewer (`/ak-merge-devshop` Phase 0.4.5, `DEVSHOP_HYGIENE_SURFACE=squash`) enforces the block at squash time — this is exactly the surface that satisfies it. Re-surfaced here only because the docs reviewer re-runs the same template-touch heuristic; no action required.
- [low] kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2 — coverage + adequacy VERIFIED. The heading rename ("connect-src and img-src builders derive from the Supabase origin"), `**Why:**` prose extension (Storage http-origin / blank-box silent-failure), spread-IIFE refactor (one trimmed `supabaseUrl` reused across both `connect-src` + `img-src`), and load-bearing "do NOT delete it as redundant" inline comment are all present and self-coherent. Informational, not a defect.
- [low] kit/docs/guide/{README,conventions}.md coherence VERIFIED — README routing-index row repointed to the new anchor `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` with updated trigger column (`"img-src"`, "Supabase Storage images") + summary; conventions.md `### CSP` sub-section added with matching `[CSP](#csp)` TOC entry placed between Responsive+Theme and PWA. dce3a27 (TOC entry) closes the Phase 2.5 fresh-eyes fix. No stale old-anchor refs repo-wide. Bookkeeping (BUILD-LOG entry added, PLAN row removed, ROADMAP v0 entry deleted) correctly unwound per § Closing TODO/ROADMAP entries when a fix ships. Informational, not a defect.

## Bypass trailer audit

- (none) — no Docs-Coverage-Bypass, CLAUDE-MD-Bypass, or Hygiene-Override trailers in range.
