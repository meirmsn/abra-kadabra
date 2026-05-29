Clean — no docs findings.

---

**Verification of corrected claims (commit 3c25c96 — the docs fix this audit was asked to verify against repo reality):**

The range's substantive commit rewrites `kit/ROADMAP.md § Template CSP img-src must include the Supabase origin` to fix the two findings raised in Audit 1 (the invented `buildConnectSrc()` reference [medium] and the `https:`-token prod-unchanged rationale [low]). All corrected claims were checked against HEAD and match repo reality:

- **`buildConnectSrc()` / `buildImgSrc()` references removed** — VERIFIED. `grep -rn "buildConnectSrc\|buildImgSrc" template/ kit/docs/` → 0 rows. The corrected entry no longer names any nonexistent template function.
- **"canonical Pattern 2 `img-src` ... is `'self' data: blob:` with no `https:` token"** — VERIFIED. `kit/docs/guide/supabase-ssr-boilerplate.md:140` reads exactly `"img-src 'self' data: blob:"` — no `https:` token present.
- **"the Pattern 2 `connect-src` builder (inline IIFE)"** — VERIFIED. supabase-ssr-boilerplate.md:133-139 is an anonymous `((): string => { ... })()` IIFE producing the `connect-src` directive; the `## Pattern 2: CSP connect-src builder` heading exists at line 113. The cross-ref bullet to `§ Pattern 2` resolves.
- **"template `apps/web/next.config.ts` ships no CSP headers yet — Pattern 2 'added when Supabase / Realtime wiring lands' (per the file's own header comment)"** — VERIFIED. `template/apps/web/next.config.ts` has no `headers()`/CSP block; its `// Does NOT:` header (lines 8-12) states CSP headers "belong in THIS file via the Pattern 2 `connect-src` builder (`kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`), added when Supabase / Realtime wiring lands."
- **prod-coverage reasoning fixed** — VERIFIED. Corrected text now conditions prod coverage on the base directive ("a base carrying a broad `https:` token covers it for free, but the canonical Pattern 2 `img-src` ... is `'self' data: blob:` with no `https:` token — under that base the prod Supabase origin is load-bearing too"), and the risk line now reads "Behavior delta is the dev-only `http` origin always, plus the prod `https` Supabase origin whenever the base omits a broad `https:` token." The old false "prod behavior provably unchanged" claim is gone. This matches the Pattern 2 base (which lacks `https:`).

**Section A (coverage)**: No findings. The range touches `kit/ROADMAP.md` (explicit carve-out — surface→doc coverage does not fire on backlog files) plus audit-record artifacts under `specs/csp-img-src-and-worktree-recovery/` (also non-firing). No `kit/scripts/**`, `kit/hooks/**`, `template/**`, `.devcontainer/**`, or `kit/manifest.txt` touched, so no surface→required-doc pairing applies. Existing-project migration block: not applicable — no propagation-relevant surface in the range.

**Section B (adequacy)**: No findings. The ROADMAP edit is substantive (it materially rewrites the entry's mechanism, rationale, and cross-refs, not whitespace/reflow). Every named-mechanism claim in the corrected entry was empirically verified by grep / Read against HEAD (see verification block above) and matches.

**Section C (cross-doc coherence)**: No findings. No files renamed or deleted in the range. The corrected entry's cross-references (`supabase-ssr-boilerplate.md § Pattern 2`, `conventions.md § Responsive + Theme`) resolve. No contradiction introduced against non-touched reference docs — the entry now agrees with the canonical Pattern 2 `img-src` shape rather than contradicting it.

**Section D (bypass trailers)**: No Docs-Coverage-Bypass trailers in range.

**Section E (CLAUDE.md hygiene)**: Skipped — devshop self-mode ($GIT_ROOT == /devshop); Section E is project-mode only.
