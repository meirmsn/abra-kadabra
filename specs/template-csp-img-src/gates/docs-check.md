## Gate 1: docs-check
- Result: pass

Verified the docs change is self-coherent and matches spec scope (D1–D4). This is a docs/boilerplate change; every behavior change IS a doc update, all in this diff.

- **No dangling cross-references.** `grep` for the OLD anchor `pattern-2-csp-connect-src-builder-handles-both-httpswss-and-httpws` across all `*.md` returns ZERO hits — fully retired. The NEW anchor `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` appears in exactly two places, both correct: the boilerplate's own `## Contents` TOC (line 10) and the README.md routing-index row (line 70). Old prose ("connect-src ... builder handles BOTH", "handles BOTH https...") returns zero hits anywhere (md + ts).
- **New anchor matches the heading slug.** Heading `## Pattern 2: CSP \`connect-src\` and \`img-src\` builders derive from the Supabase origin` (line 113) → GitHub-slugifies (lowercase, drop backticks + colon, spaces→hyphens) to `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin`. Exact match to both references.
- **New `### CSP` sub-section reachable from conventions.md TOC.** TOC entry `[CSP](#csp)` at line 56 → `### CSP` heading at line 726. Slug `csp` matches. Placed correctly between `### Responsive + Theme` (718) and `### PWA` (731), per D3 / spec § Gotchas.
- **README.md routing-index row points at the correct new anchor** (line 70) and updates the trigger column (adds `"img-src"`, "Supabase Storage images") + summary ("Both derive from `$NEXT_PUBLIC_SUPABASE_URL`") to cover the new img-src case. Matches spec D3 + README routing intent.
- **Scope match vs spec.md.** All four In-scope items present: (1) Pattern 2 IIFE now computes one trimmed `supabaseUrl`, spreads `connect-src` + `img-src` from it, old standalone `"img-src 'self' data: blob:"` line removed (grep confirms gone); (2) D2 load-bearing inline block-comment present; (3) `**Why:**` prose extended for the img-src/Storage case; (4) new `### CSP` convention sub-section; (5) template `next.config.ts` `// Does NOT:` header updated to "`connect-src` + `img-src` builders". No out-of-scope additions (no media-src in the snippet, no actual CSP block added to template).

## Dismissals
None
