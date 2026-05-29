## Gate 11: convention

- Result: pass

<evidence>

Scope: changed docs/config in `git diff origin/main...HEAD` — `kit/docs/guide/README.md`, `kit/docs/guide/conventions.md`, `kit/docs/guide/supabase-ssr-boilerplate.md`, `template/apps/web/next.config.ts`. (Non-checked changes: `PLAN.md`, `specs/template-csp-img-src/*` — bookkeeping, out of convention-gate scope.)

n/a items (no matching files in diff):
- SKILL.md frontmatter — no SKILL.md changed.
- Shell-script structure — no `kit/scripts/**` / hooks changed.
- Bats test files for new scripts — no new scripts.

**Anchor slug — heading renamed, all three references agree.** Pattern 2 heading is now `## Pattern 2: CSP `connect-src` and `img-src` builders derive from the Supabase origin`. GitHub slug derives to `pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` (verified against the GitHub slug algorithm: lowercase, strip backticks/colon, spaces→hyphens). Both pointers match exactly:
- in-file TOC (`supabase-ssr-boilerplate.md:10`): `…#pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin`
- README routing row (`README.md:70`): same anchor.
- Heading (`supabase-ssr-boilerplate.md:113`): produces that slug.
No stale `#pattern-2-csp-connect-src-builder-handles-both-httpswss-and-httpws` references remain (grep clean).

**Routing index — correct placement, no new row needed.** The CSP `next.config.ts`-edit routing row already exists (README.md:70, the Pattern 2 row) and was correctly updated to add the `"img-src"` / Supabase-Storage-images keyword triggers and the new anchor. The `### CSP` sub-section in conventions.md does NOT need its own README routing row: README treats conventions.md as a whole-doc entry (README.md:129) and maintains no per-`###` rows for its sibling sub-sections (`### Responsive + Theme`, `### PWA`, `### Code Structure` all lack README rows). The `### CSP` sub-section is correctly discoverable via conventions.md's own `## Contents` TOC: entry present at conventions.md:56 (`- [CSP](#csp)`), anchor `#csp` matches `### CSP` (conventions.md:728).

**conventions.md § CSP prose follows sibling bold-led-bullet style.** Both bullets use the `- **Bold lead** — prose` shape of `### Responsive + Theme` / `### PWA`: `- **Every CSP directive that must reach Supabase derives from `$NEXT_PUBLIC_SUPABASE_URL`** — …` and `- **A `https:` token alone is insufficient** — …`. Cross-ref to `§ Pattern 2` present and resolves.

**next.config.ts header preserves // What / // Why / // Does NOT shape.** All three header tags intact (lines 1, 3, 8). Touch-up confined to the `// Does NOT:` block: `the Pattern 2 `connect-src` builder` → `the Pattern 2 `connect-src` + `img-src` builders`; the `§ Pattern 2` pointer unchanged and still resolves. No functional change.

**Pattern 2 body / TOC consistency.** Supabase boilerplate `## Contents` TOC line (supabase-ssr-boilerplate.md:10) matches the renamed heading text verbatim; `**Why:**` prose extended for the img-src case in sibling-consistent style.

</evidence>

## Dismissals

None
