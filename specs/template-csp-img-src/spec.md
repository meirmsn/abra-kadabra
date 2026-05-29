<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: template-csp-img-src -->
<!-- date: 2026-05-28 -->

# Spec: template-csp-img-src (devshop)

**Sources:**

- `kit/ROADMAP.md § Template CSP img-src must include the Supabase origin` — primary scope + decisions [v0, lev 8.0]
- `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2` — the canonical `connect-src` builder the `img-src` derivation mirrors
- `kit/docs/guide/conventions.md § Responsive + Theme` — neighbor for the new `### CSP` sub-section
- home-os PR #43 commit `4469d99` — reference implementation (`img-src` derived from `$NEXT_PUBLIC_SUPABASE_URL`)
- Prior shipped spec `specs/*/spec.md` — style/structure reference

Fold the `img-src` Supabase-origin derivation into the Pattern 2 CSP boilerplate so every Supabase+Storage project picks it up when it adds CSP — Storage images stop silently failing in local dev and browser QA because the local stack's `http` Storage origin is now permitted, not just the prod `https:` origin.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — `/ak-build`
Phase 4.0 copies Headline into BUILD-LOG `Headline:` and Detail into
`Summary:`; `/ak-merge-devshop` reads this section for the squash body.

### Headline (user-facing)

Storage photos (avatars, card images, any signed-URL image) now render correctly in local development and browser QA out of the box — no more silently-blank image boxes the first time a project shows a Supabase Storage image.

### Detail (team-facing)

The Pattern 2 CSP boilerplate now derives the `img-src` Supabase origin from `$NEXT_PUBLIC_SUPABASE_URL` (the same way `connect-src` already does), so the local stack's `http://host.docker.internal:<port>` Storage origin — which no `https:` token covers — is permitted in dev/QA, and the prod origin is covered too when the base omits a broad `https:` token.

---

## Decisions (resolved at spec time)

4 spec-time decisions resolved in Phase 0 with the user. Recorded below so
Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Where the `img-src` Supabase-origin derivation lives

**Decision:** Fold it into the **existing Pattern 2 inline IIFE** in `kit/docs/guide/supabase-ssr-boilerplate.md`, mirroring the `connect-src` builder. Compute the trimmed `supabaseUrl` origin once and reuse it for both the `connect-src` and `img-src` directives.

**Rationale:** One builder, one source of truth; matches the shape projects already copy. Avoids a second, separately-maintained derivation that could drift from `connect-src`.

### D2: `img-src` base scheme

**Decision:** Keep the canonical `img-src 'self' data: blob:` base (**no** `https:` token) and append the bare `${supabaseUrl}` origin. Add an inline block-comment noting the appended origin is load-bearing for **both** dev (`http` local-stack origin) and prod (`https` Supabase origin) under this base; if a project's base instead carries a broad `https:` token, only the dev `http` origin is the new behavior.

**Rationale:** The ROADMAP's canonical Pattern 2 omits `https:`, so the appended origin covers both cases. The comment prevents a future reader from "tidying away" what looks redundant.

### D3: Convention-note placement in `conventions.md`

**Decision:** New `### CSP` sub-section, sibling to `### Responsive + Theme` and `### PWA`. Content: directives that must reach Supabase (`connect-src`, `img-src`, and `media-src` if serving Storage video) derive from `$NEXT_PUBLIC_SUPABASE_URL`; the local stack's `http` origin is why `https:` alone is insufficient.

**Rationale:** CSP isn't CSS/theme, so a dedicated sub-section reads cleaner and is more discoverable than a bullet buried under Responsive + Theme. ROADMAP offered either.

### D4: Existing-projects propagation block

**Decision:** Author an `**Existing projects:**` block in the squash body — when introducing the Pattern 2 CSP block into a project's `next.config.ts`, derive `img-src`'s Supabase origin from `$NEXT_PUBLIC_SUPABASE_URL`. Note home-os already carries the fix (PR #43, commit `4469d99`).

**Rationale:** This is boilerplate projects adopt; the propagation log is the migration trail even though the diff is docs-only (below the hard-enforced propagation-path set).

---

<!-- /ak-spec (Phase 1) expanded the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. This is
     devshop-self-mode: no METRICS.md, no UI; test surface is bats. -->

## In scope

- Fold an `img-src` Supabase-origin derivation into the canonical Pattern 2 CSP builder in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`, mirroring the existing `connect-src` derivation: compute the trimmed `supabaseUrl` origin once inside the IIFE and reuse it for both directives (D1).
- Keep the `img-src 'self' data: blob:` base (no `https:` token) and append `${supabaseUrl}`; add an inline block-comment explaining the appended origin is load-bearing for both dev (`http` local-stack) and prod (`https`) under the no-`https:` base (D2).
- Update the Pattern 2 `**Why:**` prose so it covers the `img-src` case alongside the existing `connect-src` reasoning (the local stack serves Storage over an `http` origin that no `https:` token covers).
- Add a new `### CSP` sub-section to `kit/docs/guide/conventions.md`, sibling to `### Responsive + Theme` and `### PWA`, documenting that the directives that must reach Supabase (`connect-src`, `img-src`, and `media-src` if serving Storage video) all derive from `$NEXT_PUBLIC_SUPABASE_URL`, with a cross-ref to Pattern 2 (D3).
- Light touch-up of the `template/apps/web/next.config.ts` `// Does NOT:` header comment: "the Pattern 2 `connect-src` builder" → "the Pattern 2 `connect-src` + `img-src` builders". No functional change (the template ships no CSP block; the comment points future implementers at the boilerplate).

## Out of scope

- Adding an actual CSP header block to `template/apps/web/next.config.ts`. The template intentionally ships no CSP block (it's added when Supabase/Realtime wiring lands per `/ak-new-project § Step 12`); this feature only updates the doc-comment pointer.
- `media-src` derivation in the Pattern 2 code snippet. The `### CSP` convention note mentions `media-src` as a conditional ("if serving Storage video"), but the boilerplate snippet stays `connect-src` + `img-src` only — no project currently serves Storage video, and adding an unused directive to the canonical snippet invites cargo-culting.
- Backporting the fix into existing projects' `next.config.ts`. That's the `**Existing projects:**` propagation block (D4) — a migration-trail entry, applied by each project when it introduces or revisits its CSP block, not a code task in this PR. home-os already carries the fix (PR #43, commit `4469d99`).
- Re-resolving any of D1–D4. They are user-approved at Phase 0.

## Files to create / modify

| File | Change |
| --- | --- |
| `kit/docs/guide/supabase-ssr-boilerplate.md` | Pattern 2: fold `img-src` into the IIFE (reuse the trimmed `supabaseUrl`, append `${supabaseUrl}` to `img-src 'self' data: blob:`), add the D2 inline block-comment, extend the `**Why:**` prose for the `img-src` case. |
| `kit/docs/guide/conventions.md` | Add new `### CSP` sub-section between `### Responsive + Theme` and `### PWA` (D3). |
| `template/apps/web/next.config.ts` | `// Does NOT:` header: `connect-src` builder → `connect-src` + `img-src` builders. Editable here because this is a worktree copy (`/devshop/.worktrees/...`), not the permission-locked canonical `template/**`. |

## Tests

**No new bats tests.** This is a pure-prose / boilerplate-comment docs change with no executable surface:

- The Pattern 2 snippet is a fenced code excerpt in a markdown guide, not a script that runs. There is nothing to exercise — bats tests guard `kit/scripts/**`, `kit/hooks/**`, and `.devcontainer/**` shell behavior, none of which this touches.
- No existing bats test asserts the Pattern 2 snippet's content or shape. The only doc-aware test, `kit/tests/guard-docs-coverage-devshop.bats`, checks that `supabase-ssr-boilerplate.md` (and `conventions.md`) exist and are covered — it does NOT parse or assert the `img-src` / `connect-src` directive text, so editing the snippet does not change its outcome.
- The `template/apps/web/next.config.ts` change is a comment-only touch-up (no runtime code), so no unit test applies; the file ships no CSP block to assert against.

The `/ak-build` devshop-mode gate set (docs coverage + adversarial review at audit moments) is the relevant quality surface here, not bats.

## Dependencies

None. All three files already exist; the changes are self-contained edits with no ordering dependency on other in-flight work.

## Task order

Three tasks, mirroring the Phase 0 tracker. Order is independent — listed in narrative order (canonical snippet first, then the convention note that cross-refs it, then the template pointer).

1. **Pattern 2 `img-src` fold** (`supabase-ssr-boilerplate.md`) — restructure the IIFE to compute `supabaseUrl` once and emit both `connect-src` and `img-src` lines from it; add the D2 block-comment; extend `**Why:**`.
2. **`### CSP` convention sub-section** (`conventions.md`) — new sub-section between Responsive + Theme and PWA, cross-referencing Pattern 2.
3. **Template `// Does NOT:` pointer touch-up** (`template/apps/web/next.config.ts`) — `connect-src` builder → `connect-src` + `img-src` builders.

## Gotchas

- **Strict CSP scheme matching — `https:` does NOT cover an `http` origin.** Listing `https:` (or any `https://<host>`) in `img-src` permits only https origins; the local Supabase stack serves Storage over an `http` origin (`http://127.0.0.1:<port>` or `http://host.docker.internal:<port>`) that no `https:` token covers. This is the same strictness Pattern 2's `connect-src` comment already calls out for `wss`/`ws`. Appending the bare `${supabaseUrl}` origin is what makes dev/QA Storage images load. The symptom when missed is silent: the browser blocks the image with a CSP console warning and renders a blank box — no thrown error, no failed network panel entry that looks like an app bug.
- **The appended origin is load-bearing under the no-`https:` base — don't "tidy it away".** Because the canonical base omits a broad `https:` token, `${supabaseUrl}` is the ONLY thing permitting the prod `https` Supabase origin too, not just the dev `http` one. The D2 inline comment exists to stop a future reader from deleting it as redundant. If a project's base instead carries a broad `https:` token, only the dev `http` origin is genuinely new behavior — but the canonical Pattern 2 stays no-`https:`.
- **`.trim()` defends whitespace-contaminated env vars.** The single trimmed `supabaseUrl` read (reused for both directives) carries forward Pattern 1's defense — a trailing `\n` on `NEXT_PUBLIC_SUPABASE_URL` would otherwise leak a `%0A`-encoded origin into the CSP header (the exact lalista PR 26 failure mode). Computing it once and reusing keeps the trim in one place.
- **`conventions.md` sub-section placement.** Insert `### CSP` as a sibling between `### Responsive + Theme` (~line 717) and `### PWA` (~line 725), not nested under either. CSP is neither CSS/theme nor PWA, so a dedicated peer reads cleaner and is more discoverable.
- **Template path is editable only because this is a worktree.** `template/apps/web/next.config.ts` is permission-denied for Write/Edit in the canonical `/devshop` tree but intentionally editable in this worktree copy. The implement agent makes the edit here; no `/tmp + sudo install` handoff is needed.

## Acceptance / rollout

**Acceptance:**

- Pattern 2's IIFE computes a single trimmed `supabaseUrl` and emits both `connect-src` and `img-src` lines from it; the `img-src` line reads `img-src 'self' data: blob: ${supabaseUrl}` and carries the D2 block-comment explaining the load-bearing appended origin.
- Pattern 2's `**Why:**` prose covers the `img-src` case (local stack serves Storage over an `http` origin no `https:` token covers).
- `conventions.md` has a `### CSP` sub-section between Responsive + Theme and PWA, naming `connect-src` / `img-src` / conditional `media-src` as `$NEXT_PUBLIC_SUPABASE_URL`-derived, cross-referencing Pattern 2.
- `template/apps/web/next.config.ts`'s `// Does NOT:` header says "the Pattern 2 `connect-src` + `img-src` builders".
- Devshop-mode gate set passes (docs coverage; adversarial review at the audit moment).

**Rollout (D4):**

- The `**Existing projects:**` propagation block lives in the `/ak-merge-devshop` squash body, NOT as a code task in this PR. `release.sh` lifts that block into `kit/docs/PROPAGATION.md` for the version range.
- Migration step for existing projects: when introducing (or revisiting) the Pattern 2 CSP block in a project's `next.config.ts`, derive `img-src`'s Supabase origin from `$NEXT_PUBLIC_SUPABASE_URL` the same way `connect-src` does.
- home-os already carries the fix (PR #43, commit `4469d99`) — note it in the propagation block so it isn't flagged as still-pending there.
- Close the `kit/ROADMAP.md § Template CSP img-src must include the Supabase origin` entry in this PR (per the "Closing TODO / ROADMAP entries when a fix ships" convention).
