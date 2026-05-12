# Routing-validation fixture trace (PR-B)

Per spec § D8 — this doc validates that the context-aware guideline routing system shipped on devshop commit `3f5ecea` correctly absorbs the 13 new routing rows added by PR-B. Each section below pairs a synthetic spec/diff signal with the routing-row target it should match, plus a 1-line attestation that the row's trigger pattern resolves.

**How to read**: for each row, the "Signal" is what `/ak-spec` Step 1.5 or `/ak-implement` Step 1 would see in a real PR's spec or diff. The "Target" is what the routing index would surface for that signal. The "Attestation" is the 1-line proof that the row's trigger pattern matches.

This is NOT a runtime invocation — runtime introspection of the routing system would require a fixture-spec corpus and is out of scope (see spec § D8 rationale). The trace below is the audit artifact.

---

## Frontend stack group

### Row 1: `tailwind.md § Tailwind v4 @source directive`

**Signal:** A spec or diff that touches `apps/web/app/globals.css` and references the keyword `@source`, OR adds a new workspace package under `packages/*/src/**/*.{ts,tsx}` whose components are consumed by `apps/web/**`.

**Target:** [`/devshop/kit/docs/guide/tailwind.md § Tailwind v4 @source directive`](../../../devshop/kit/docs/guide/tailwind.md#tailwind-v4-source-directive)

**Attestation:** Trigger row's path-glob `apps/web/app/globals.css` and keyword `@source` are both present in the lalista `feature/my-stores` branch's diff against main when `packages/ui/**` components are touched — verified by inspecting the existing Tailwind config setup at `apps/web/app/globals.css:1`.

### Row 2: `tailwind.md § Named-key sizing utilities resolve through --spacing-*`

**Signal:** A spec mentioning Tailwind v4 named-key utilities (`max-w-sm`, `max-w-md`, `h-xl`, `w-2xl`) OR a diff that adds such utilities to an `apps/web/components/**/*.tsx` file.

**Target:** [`/devshop/kit/docs/guide/tailwind.md § Named-key sizing utilities resolve through --spacing-*`](../../../devshop/kit/docs/guide/tailwind.md#named-key-sizing-utilities-resolve-through---spacing-)

**Attestation:** Lalista PR 53 (the originating empirical-verification PR) cited `--spacing-*` tokens defined in `apps/web/app/globals.css`'s `@theme inline` block — the same trigger surface the row fires on for future PRs.

---

## Data group

### Row 3: `database-queries.md § PostgREST relationship inference does not chain through auth.*`

**Signal:** A spec referencing `addedByName`, `actorName`, `displayName` hydration OR a diff that adds an `.in('user_id', uniqueIds)` two-query pattern in `packages/core/src/api/*.ts`.

**Target:** [`/devshop/kit/docs/guide/database-queries.md § PostgREST relationship inference does not chain through auth.*`](../../../devshop/kit/docs/guide/database-queries.md#postgrest-relationship-inference-does-not-chain-through-auth)

**Attestation:** Lalista's `packages/core/src/api/lists.ts` (per CLAUDE.md gotcha row 10) implements the exact two-query pattern this section documents; the row's keyword + path-glob triggers cover both the existing call site and future ones.

### Row 4: `migrations.md § Load-bearing SQL invariants and sentinel comments`

**Signal:** A migration file under `supabase/migrations/**` containing the literal string `LOAD-BEARING(do-not-remove)` OR a spec Decisions section discussing `FOR UPDATE` / row locks / EPQ semantics.

**Target:** [`/devshop/kit/docs/guide/migrations.md § Load-bearing SQL invariants and sentinel comments`](../../../devshop/kit/docs/guide/migrations.md#load-bearing-sql-invariants-and-sentinel-comments)

**Attestation:** Lalista's `supabase/migrations/015_household_collaborators.sql` carries the canonical sentinel comment; the pure-file BATS-like test at `packages/core/src/migrations/015_for_update.test.ts` greps for both the `for update` clause AND the sentinel comment — the row's trigger pattern captures both the runtime invariant and the enforcement test surface.

### Row 5: `migrations.md § DB constraint as loud structural backstop`

**Signal:** A migration file containing `unique constraint <name>` or `unique (...)` that backs an application-layer business rule, OR a wrapper that maps `23505` (Postgres unique-violation errcode) to a typed application error.

**Target:** [`/devshop/kit/docs/guide/migrations.md § DB constraint as loud structural backstop`](../../../devshop/kit/docs/guide/migrations.md#db-constraint-as-loud-structural-backstop-for-application-layer-business-rules)

**Attestation:** Lalista's `household_members_one_per_user_v0` constraint in migration 015 + the `OnboardingForm` 23505 handler implement the pattern verbatim; the row's keyword + path-glob fires on both schema-level and application-level signals.

### Row 6: `migrations.md § seed.sql gotrue compatibility — required text columns + matching auth.identities`

**Signal:** A diff that touches `supabase/seed.sql` adding rows to `auth.users` OR a Decisions section discussing seed-file authentication.

**Target:** [`/devshop/kit/docs/guide/migrations.md § seed.sql gotrue compatibility`](../../../devshop/kit/docs/guide/migrations.md#seedsql-gotrue-compatibility--required-text-columns--matching-authidentities)

**Attestation:** Lalista's `supabase/seed.sql` lines 222-258 is the canonical example; the gotcha was a chapter-1m / household-collaborators Phase 3 blocker. The row's `supabase/seed.sql` path-glob + `auth.users` keyword captures the trigger surface for any future seed addition.

---

## Auth + security group

### Row 7: `security.md § RLS-bypass write fallback ladder`

**Signal:** A spec Decisions section discussing `SECURITY DEFINER` / `service_role` / RLS-bypass writes, OR a new RPC under `supabase/migrations/**` that takes a write target the caller's role can't reach.

**Target:** [`/devshop/kit/docs/guide/security.md § RLS-bypass write fallback ladder`](../../../devshop/kit/docs/guide/security.md#rls-bypass-write-fallback-ladder)

**Attestation:** Lalista's `mark_item_bought` RPC + `items_insert` RLS policy + `add_household_store` SECURITY DEFINER RPC together cover all three rungs of the ladder. The row's keyword pattern fires on any of those signals; future PRs adding a new RPC will surface this section.

### Row 8: `security.md § Per-environment secret split with canonical inner name`

**Signal:** A diff that adds a new GitHub Secret with a `_QA` / `_PROD` suffix OR an edge function reading `Deno.env.get('<NAME>')` where `<NAME>` is a third-party paid-API credential.

**Target:** [`/devshop/kit/docs/guide/security.md § Per-environment secret split with canonical inner name`](../../../devshop/kit/docs/guide/security.md#per-environment-secret-split-with-canonical-inner-name)

**Attestation:** Lalista's `ANTHROPIC_API_KEY_QA` / `ANTHROPIC_API_KEY_PROD` split is the canonical instance. The row's trigger pattern (path-glob `.devcontainer/.env` + keyword `_QA` / `_PROD`) captures both the GH Secret surface and the local `.devcontainer/.env` surface.

### Row 9: `supabase-ssr-boilerplate.md § Pattern 7: emailRedirectTo origin resolution + query-string survival`

**Signal:** A diff containing `emailRedirectTo:` in `signUp` / `signInWithOtp` / `resetPasswordForEmail` calls OR a Decisions section mentioning `NEXT_PUBLIC_SITE_URL` / redirect-URL allow-list.

**Target:** [`/devshop/kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 7`](../../../devshop/kit/docs/guide/supabase-ssr-boilerplate.md#pattern-7-emailredirectto-origin-resolution--query-string-survival)

**Attestation:** Lalista's `packages/core/src/api/auth.ts` (signUp) and `packages/core/src/api/invitations.ts` (createInvite) both call sites use the `NEXT_PUBLIC_SITE_URL ?? window.location.origin` fallback. Row 9 covers both the origin-fallback half (row 18 input) and the query-string-survival half (row 24 input) of the original lalista gotcha — a single routing row absorbs both because they share the same trigger surface.

### Row 10: `supabase-ssr-boilerplate.md § Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows`

**Signal:** A diff that touches `apps/web/middleware.ts` adding to a route allow-list OR a spec Decisions section discussing recovery flows (`/reset-password`, `/auth/callback`) + middleware.

**Target:** [`/devshop/kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 8`](../../../devshop/kit/docs/guide/supabase-ssr-boilerplate.md#pattern-8-middleware-allow-list-authed-bypass-carve-out-for-recovery-flows)

**Attestation:** Lalista's `apps/web/middleware.ts` allows `/`, `/sign-in`, `/sign-up`, `/forgot-password`, `/reset-password`, `/auth/callback` unauth pass-through; the recovery-flow carve-out (do NOT bounce authed users away from `/reset-password` or `/auth/callback`) is exactly what Pattern 8 documents.

---

## Ops + deploy group

### Row 11: `ops.md § Out-of-band dashboard surfaces`

**Signal:** A diff that touches `supabase/templates/*.html`, `supabase/config.toml` (auth/email blocks), OR a Decisions section discussing custom-domain swap / SMTP provider / Vercel project settings.

**Target:** [`/devshop/kit/docs/guide/ops.md § Out-of-band dashboard surfaces`](../../../devshop/kit/docs/guide/ops.md#out-of-band-dashboard-surfaces)

**Attestation:** Lalista shipped `supabase/templates/password-changed.html` + the corresponding `[auth.email.notification.password_changed]` block in `supabase/config.toml` in migration 014 / db-hardening. The row's path-glob covers both the `.html` template files and the `config.toml` auth blocks; the keyword pattern covers the dashboard-paste discipline narrative.

---

## Dev + meta group

### Row 12: `wrapper-boundaries.md § Removed-member realtime leak — thread invariant data back from the wrapper`

**Signal:** A new wrapper in `packages/core/src/api/**` that pairs a list query with a Realtime subscription AND depends on a per-user membership / authorization invariant, OR a Decisions section discussing realtime channel teardown after permission revocation.

**Target:** [`/devshop/kit/docs/guide/wrapper-boundaries.md § Removed-member realtime leak`](../../../devshop/kit/docs/guide/wrapper-boundaries.md#removed-member-realtime-leak--thread-invariant-data-back-from-the-wrapper)

**Attestation:** Lalista's `fetchListEntries` returns `{entries, currentHouseholdId}` — `currentHouseholdId` IS the membership-invariant data threaded back per the pattern. The wrapper-API design row also covers the `subscribeToList` companion. Future wrappers that touch realtime + membership will surface this section.

### Row 13: `testing.md § Pattern 2: enable_confirmations flip per-test`

**Signal:** A new `*.integration.test.ts` under `packages/core/src/migrations/` OR `apps/web/e2e/*.spec.ts` that exercises an auth-confirmation path (sign-up + email confirmation, password reset + email link).

**Target:** [`/devshop/kit/docs/guide/testing.md § Pattern 2: enable_confirmations flip per-test`](../../../devshop/kit/docs/guide/testing.md#pattern-2-enable_confirmations-flip-per-test)

**Attestation:** Lalista's currently-deferred `015_household_collaborators.integration.test.ts § beforeAll` is the canonical instance (flips `auth.email.enable_confirmations = true` per-test). The row's path-glob + keyword pattern covers integration + E2E test surfaces.

---

## Cross-row attestations (synthetic rows S1–S3)

The audit table includes three synthetic rows (S1–S3) that lift patterns from project-specific gotchas without being tied to a specific gotcha. These are covered by routing rows 10 (S1 → Pattern 8), 12 (S2 → Removed-member realtime leak), and 5 (S3 → DB constraint as loud structural backstop). The lalista CLAUDE.md edits add `_Pattern: …_` suffixes on the project-specific entries (rows 7, 19, 20) pointing at the same lifted sections — so a maintainer reading the lalista-specific gotcha is exactly one click from the generalized pattern.

---

## Summary

13 new routing rows, all paired to lalista signals (real-world grounding test corpus). 3/3 BATS suites pass against the new rows (per the devshop subagent's report at PR-B Phase 2 task 5):

- `routing-link-resolution.bats` — every `(file, anchor)` resolves to a real H2/H3.
- `routing-completeness.bats` — `tailwind.md` is listed in the new Frontend stack group; no double-listing.
- `routing-real-world-grounding.bats` — ≥3-trigger assertion passes on the lalista spec corpus.

The validation artifact is this doc; the runtime-introspection extension is deferred to a separate v1 entry per spec § D8 if the static check surfaces gaps.
