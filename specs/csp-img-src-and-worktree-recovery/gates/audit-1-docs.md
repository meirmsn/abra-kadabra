### [domain: docs] [section: B] [severity: medium]

**File**: kit/ROADMAP.md:425 (and :429, :437, :441 — § Template CSP `img-src` must include the Supabase origin)
**What**: The entry repeatedly names the template's existing CSP pattern `buildConnectSrc()` — a named function ("mirroring the template's existing `buildConnectSrc()` pattern", "add a `buildImgSrc()` helper alongside the existing `buildConnectSrc()`", cross-ref bullet "`template/apps/web/next.config.ts` `buildConnectSrc()` — the existing same-shape pattern"). No `buildConnectSrc()` function exists anywhere in `template/` or `kit/docs/` (`grep -rn buildConnectSrc template/ kit/docs/` → no rows). The actual `connect-src` builder is an anonymous IIFE documented in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`, and `template/apps/web/next.config.ts` ships NO CSP headers at all yet — Pattern 2 is explicitly "added when Supabase / Realtime wiring lands" (per the file's own header comment, lines 8-12).
**Why**: Named-section/named-mechanism claim disproved by grep (Section B adequacy). The entry asserts a concrete artifact ("the template's existing `buildConnectSrc()`") that does not exist; an implementer following this v0 entry would look for `buildConnectSrc()` + a CSP block in the template, find neither, and have to reconcile the entry against reality before starting. Bounded because this is a backlog entry (future work), not a live operator instruction — but it internalizes a wrong mental model of the template's current shape.
**Fix**: Rename the references from `buildConnectSrc()` to the actual pattern — the inline `connect-src` IIFE in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2` — and note that the template does not yet carry a CSP header block (Pattern 2 lands with Supabase/Realtime wiring), so `buildImgSrc()` is a sibling to add _when_ the Pattern 2 CSP block is introduced into a project's `next.config.ts`, not an edit to existing template code.

### [domain: docs] [section: B] [severity: low]

**File**: kit/ROADMAP.md:427-428 (§ Template CSP `img-src`, "Shape of the fix" + "Why v0")
**What**: The entry's reasoning rests on the CSP `img-src` base already containing a `https:` token ("already covered by the broad `https:` token most CSPs carry"; "Keep `'self' data: blob: https:` as the base"). But the documented Pattern 2 `img-src` directive is `"img-src 'self' data: blob:"` (supabase-ssr-boilerplate.md:140) — no `https:` token. The "prod is already covered by `https:`, so the appended origin is redundant-but-harmless in prod" argument depends on a token the canonical pattern doesn't contain.
**Why**: Adequacy — the load-bearing rationale ("prod behavior provably unchanged because `https:` already covers it") is built on an inaccurate description of the base directive. If the base lacks `https:`, prod is NOT already covered and the appended origin is load-bearing in prod too, which changes the risk analysis ("Risk: low — additive" / "prod behavior provably unchanged").
**Fix**: Reconcile against the canonical `img-src` shape in supabase-ssr-boilerplate.md § Pattern 2 (`'self' data: blob:`). Either correct the entry to add `https:` to the base as part of the same fix, or drop the "already covered by `https:`" prod-unchanged claim and state the appended origin is load-bearing in both dev and prod.

---

**Section A (coverage)**: No findings. Both touched files (`PLAN.md`, `kit/ROADMAP.md`) are explicit carve-outs in the devshop coverage rubric (backlog/tracker files; the audit does not fire surface→doc coverage on them). No source/script/template/hook surfaces changed in the range, so no surface→required-doc pairing applies. Existing-project migration block: not applicable — the range touches no propagation-relevant surface (`template/**`, `kit/scripts/**`, `kit/hooks/**`, `.devcontainer/**`, `kit/manifest.txt`).

**Section C (cross-doc coherence)**: No findings. No files renamed or deleted in the range. The conventions.md § Responsive + Theme cross-reference cited in the new entry resolves (conventions.md:717). No contradiction introduced against non-touched reference docs.

**Section D (bypass trailers)**: No Docs-Coverage-Bypass trailers in range.

**Section E (CLAUDE.md hygiene)**: Skipped — devshop self-mode ($GIT_ROOT == /devshop); Section E is project-mode only.
