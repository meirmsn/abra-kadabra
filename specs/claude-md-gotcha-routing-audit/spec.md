<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: claude-md-gotcha-routing-audit -->
<!-- date: 2026-05-12 -->

# Spec: claude-md-gotcha-routing-audit (PR-B)

**Sources:**

- `/devshop/kit/ROADMAP.md § PR-B: lalista CLAUDE.md gotcha audit + lift into routing system` (line 1295) — primary scope; v0 follow-on filed 2026-05-11 by the routing-system PR.
- `/devshop/kit/ROADMAP.md § Context-aware guideline routing for /ak-spec and /ak-implement` (closed by `feat(routing): context-aware guideline routing`, devshop commit 3f5ecea) — the system this PR validates.
- `/devshop/kit/docs/guide/README.md` — the routing index this PR extends. Group structure: Data / Auth + security / Frontend + UI / Ops + deploy / Dev + meta / Out of routing.
- `/devshop/kit/tests/routing-link-resolution.bats`, `routing-completeness.bats`, `routing-real-world-grounding.bats` — coverage invariants for the routing system.
- `/workspace/CLAUDE.md § Gotchas` on lalista's `main` (26 entries) — the canonical input.
- Prior spec `/workspace/specs/my-stores/spec.md` — style + structure reference for /ak-spec.

PR-B audits lalista's 26 CLAUDE.md gotchas. Each is classified as already-in-devshop (replace with one-line pointer), generalizable (lift to a devshop guide section + add a paired routing-row trigger), or project-specific (leave verbatim in lalista CLAUDE.md). Ships as two coordinated PRs — devshop side adds the lifted content + routing rows + tests; lalista side replaces lifted gotchas with one-line pointers. Validation artifact: a fixture-trace doc that walks each new routing row through a representative diff signal and shows the target would resolve.

---

## Decisions (resolved at spec time)

9 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: Branch base for the lalista side

**Decision:** Branch `feature/claude-md-gotcha-routing-audit` off `main` (not `feat/my-stores`).

**Rationale:** my-stores is a separate unmerged PR. Auditing the canonical 25-gotcha input means main's 26-gotcha CLAUDE.md, not the 31-gotcha post-my-stores tree. The 5 my-stores gotchas get a follow-on audit after that PR merges; D4 makes them explicitly out-of-scope here.

### D2: Repo shape — one PR or two?

**Decision:** Two PRs — a lalista PR (delete + pointer edits in CLAUDE.md) and a devshop PR (new guide sections + routing rows + BATS coverage). Cross-link in each PR description.

**Rationale:** Each repo has independent CI / merge paths. The lalista pointer text uses relative paths into devshop's guide tree — those resolve once devshop ships, regardless of merge ordering. Splitting also keeps each PR scannable: lalista PR is purely a delete + 14 pointer lines; devshop PR is the substantive new content.

### D3: Classification criteria — what makes a gotcha "generalizable"?

**Decision:** A gotcha is generalizable when (a) the underlying pattern reproduces across other projects on the same stack (Supabase + Next.js + Vercel + Tailwind v4) AND (b) it can be lifted without preserving lalista-specific filenames/columns/RPCs as load-bearing detail. Where the _pattern_ generalizes but the gotcha is prose-anchored in lalista specifics, lift the pattern to devshop in stack-agnostic form and leave the project-specific instance in lalista (no pointer needed for the instance — only for fully-lifted entries).

**Rationale:** Sharper than "could another project hit this." The conjunction guards against dumping project-noisy prose into shared guides; the carve-out for pattern-only lifts captures partial generalizations (e.g., the "PostgREST can't join through `auth.*`" pattern is generalizable; the specific `addedByName` two-query call site stays).

### D4: Out-of-scope: which gotchas to skip

**Decision:** Skip (a) the 5 my-stores gotchas (post-canonical — added on `feat/my-stores`, not on `main`); (b) the "Where Things Happen" bullets at lines 14–23 (not gotchas — they're a file-location index). Audit only the 26 entries under `### Gotchas` on `main` at HEAD `aa37b74`.

**Rationale:** Roadmap entry says "~25 canonical input." 26 on main is the right cut. The my-stores gotchas haven't reached main yet; auditing them inside this PR would invert the PR-B-after-C ordering the operator called out (gotchas potentially slated for deletion shouldn't get routed only to be un-routed shortly after).

### D5: New guide files vs extend existing

**Decision:** Extend existing devshop guides where possible (~9 of ~11 lifts land in existing files). Create one new file `/devshop/kit/docs/guide/tailwind.md` to hold the 2 Tailwind v4 gotchas (`@source` directive, named-key sizing utilities). Add a new "Frontend stack" group in the routing index for that file.

**Rationale:** Existing guides are tightly scoped (migrations, database-queries, security, ops, testing) — extending them stays clean. Tailwind has no existing home and two gotchas justify a small dedicated file; the routing index's promote-to-subdirectory rule explicitly notes ≥3 sustained files is the threshold for a _subdirectory_ — a single new top-level file at 2 entries is fine. The README preamble already documents this.

### D6: Already-in-devshop deletions — full delete or one-line pointer?

**Decision (corrected mid-flight):** **Pure delete from lalista CLAUDE.md, no pointer line.** The corrected lalista PR drops all 20 lifted / already-in-devshop gotchas entirely. Project-specific gotchas (the 6) stay verbatim with **no `_Pattern: …_` suffix** either.

**Rationale:** The routing system already handles devshop discovery — `/ak-implement` reads `/devshop/kit/docs/guide/README.md` on every PR and surfaces the relevant lifted sections based on the diff's trigger signals. Lalista's CLAUDE.md doesn't need outward pointers; they're noise, not value. Future projects don't read lalista's CLAUDE.md; they get the patterns via the routing system the same way lalista does.

**Why this was a mid-flight correction (not the original D6):** The original D6 specified one-line pointers per the routing-system PR's "pointer-redirect" pattern. But that pattern fits when content moves _within_ the same doc tree (a section relocates within `kit/docs/guide/`); it does NOT fit cross-repo where the discovery mechanism is different. In the cross-repo case the discovery is the routing system, not in-file ToC scanning. Caught during the corrections turn; lalista commit `66d9447` enforces the corrected shape.

**Pointer convention status:** "Pointer-redirect" pattern still applies within devshop (e.g., when a guide section moves to a new file under `kit/docs/guide/`). It does NOT apply for project → devshop lifts; those are pure delete.

### D7: BATS test coverage for new routing rows

**Decision:** Every new routing row is covered by the existing three BATS suites:

- `routing-link-resolution.bats` — verifies every `(file, anchor)` resolves to a real H2/H3.
- `routing-completeness.bats` — verifies `kit/docs/guide/tailwind.md` is listed in a group (new "Frontend stack").
- `routing-real-world-grounding.bats` — fires its ≥3-trigger assertion against the new rows using existing lalista specs as the fixture corpus.

No new BATS files; no skill changes. New section anchors must be H2 or H3 with predictable slugs to satisfy link-resolution.

**Rationale:** The discipline shipped with the routing PR; PR-B's job is to exercise it on real lifts, not re-litigate test design. Keeping the test surface stable bounds blast radius and proves the test design holds up to first real use.

### D8: Validation — how do we prove the routing system worked end-to-end?

**Decision:** Author `specs/claude-md-gotcha-routing-audit/routing-validation.md` — a fixture-trace doc with one section per new routing row, each section containing:

- The synthetic spec/diff signal the row should match (e.g., "Decisions section contains 'Tailwind v4'", "diff touches `apps/web/app/globals.css`").
- The expected target (file, anchor) from the routing index.
- A 1-line attestation that the row's trigger pattern matches the signal.

NOT a runtime invocation of `/ak-spec` — that would require a fixture-spec corpus and a way to introspect routing decisions, both of which are out of scope. Markdown trace IS the audit artifact.

**Rationale:** Roadmap entry line: "Validates the routing system shipped in `feature/context-aware-guideline-routing` by exercising it on the canonical gotcha list it was built to absorb." A trace-doc with one row per lift is the lightest deliverable that demonstrates the system absorbed the input correctly. Runtime invocation can come later (in a separate v1 entry) if the trace surfaces gaps the static check missed.

### D9: Devshop-side branch base

**Decision:** Branch off devshop `main` at `1c32baa` — current tip. The routing system already shipped on main at `3f5ecea`.

**Rationale:** Build on the just-shipped infrastructure; devshop's main is stable.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Audit classification table,
     Files to create/modify (both repos), Tests, Dependencies, Task order, Gotchas,
     Acceptance / rollout / rollback. The Decisions section above stays verbatim. -->

## In scope

**Lalista changes** (single PR off `main` per D1):

- `CLAUDE.md` — replace 9 already-in-devshop gotchas with one-line pointers (D6 format); replace 11 generalizable gotchas with one-line pointers; leave 6 project-specific gotchas verbatim. Net delete: ~250 lines of prose; net add: 20 pointer lines.
- `specs/claude-md-gotcha-routing-audit/spec.md` — this file (already on branch).
- `specs/claude-md-gotcha-routing-audit/routing-validation.md` — new fixture-trace doc per D8, one section per new routing row.

**Devshop changes** (single PR off `main` at `1c32baa` per D9):

- `kit/docs/guide/tailwind.md` — new file (D5); 2 lifted sections.
- `kit/docs/guide/security.md` — append `RLS-bypass write fallback ladder` + `Per-environment secret split with canonical inner name`.
- `kit/docs/guide/database-queries.md` — append `PostgREST relationship inference does not chain through auth.*`.
- `kit/docs/guide/migrations.md` — append `Load-bearing SQL invariants and sentinel comments` + `DB constraint as loud structural backstop` + `seed.sql gotrue compatibility`.
- `kit/docs/guide/ops.md` — append `Out-of-band dashboard surfaces`.
- `kit/docs/guide/supabase-ssr-boilerplate.md` — append `Pattern 7: emailRedirectTo origin resolution + query-string survival` + `Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows`.
- `kit/docs/guide/testing.md` — append `Pattern 2: enable_confirmations flip per-test`.
- `kit/docs/guide/wrapper-boundaries.md` — append `Removed-member realtime leak — thread invariant data back from the wrapper`.
- `kit/docs/guide/README.md` — add new `## Frontend stack` group (per D5) plus 13 routing-row triggers across existing + new groups. Add `tailwind.md` to the alphabetical file list.

**Not in scope** (explicit):

- The 5 `feat/my-stores` gotchas (post-canonical per D4) — separate follow-on audit after that PR merges.
- The 10 "Where Things Happen" location-map bullets at `CLAUDE.md` lines 14-23 (not gotchas per D4).
- New BATS suites — D7 reuses the three shipped suites.
- Runtime invocation of `/ak-spec` against a fixture corpus — D8 makes the trace markdown the artifact.
- METRICS.md changes — no new events introduced (docs-only PR).
- ROADMAP edits, skill edits, template edits — none of the lifts change skill behavior or the new-project template scaffold; future PRs may decide to inline some of these into the template later.

## Audit

26 canonical gotchas from `CLAUDE.md § Gotchas` on lalista `main` at HEAD `aa37b74`, in source order. Classifications per D3; targets per D5. Synthetic rows (`S*`) cover patterns lifted from project-specific instances per D3's two-condition test.

| #   | Title (first 70 chars)                                                                                               | Classification                          | Target                                                                 | Rationale (≤ 30 words)                                                                                                                                                                     |
| --- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Tailwind v4 `@source` directive is required                                                                          | Generalizable — lift                    | `tailwind.md § Tailwind v4 @source directive`                          | Stack-wide trap on any monorepo with workspace-package styled components under Tailwind v4. New file (D5).                                                                                 |
| 2   | Don't use named-key sizing utilities (`max-w-sm` etc.) with `--spacing-*` tokens                                     | Generalizable — lift                    | `tailwind.md § Named-key sizing utilities resolve through spacing`     | Tailwind v4 + 8px-grid spacing tokens is a standard template choice; trap reproduces everywhere. Empirical verification carries over.                                                      |
| 3   | `mark_item_bought` RPC is the ONLY way to mark bought                                                                | Project-specific — stay                 | n/a                                                                    | Load-bearing on the specific RPC + table names; pattern lifted via row 9 (RLS-bypass fallback ladder).                                                                                     |
| 4   | Realtime for `list_entries` uses `subscribeToList`                                                                   | Already in devshop — delete + pointer   | `wrapper-boundaries.md § Wrapper API design`                           | Already the worked example in wrapper-boundaries.md; the `supabase_realtime` publication half is in `migrations.md § Realtime publication setup`.                                          |
| 5   | `list_entries.added_by` and `purchase_history.added_by` are nullable                                                 | Project-specific — stay                 | n/a                                                                    | Load-bearing on specific column + UI fallback strings; pattern lifted via row 6 (ON DELETE).                                                                                               |
| 6   | `ON DELETE` on every `auth.users(id)` FK is mandatory                                                                | Already in devshop — delete + pointer   | `migrations.md § ON DELETE on auth.users FK references`                | Verbatim coverage including the CASCADE/SET NULL/RESTRICT decision table.                                                                                                                  |
| 7   | Information architecture — `/` public landing, middleware allow-list, recovery-flow carve-out                        | Project-specific — stay                 | n/a                                                                    | Load-bearing on lalista routes (`/list`, `/sign-in`, `/reset-password`); pattern lifted via synthetic row S1.                                                                              |
| 8   | Edge function changes need explicit deploy step                                                                      | Already in devshop — delete + pointer   | `conventions.md § Deploy Boundaries`                                   | The Deploy Boundaries table explicitly lists `supabase/functions/**` as a separate path-filtered workflow; covers the same "front-end deploys but back-end doesn't" hazard.                |
| 9   | Principle of least privilege for RLS-bypass writes                                                                   | Generalizable — lift                    | `security.md § RLS-bypass write fallback ladder`                       | Three-tier ordering (policy → SECURITY DEFINER RPC → service-role) reproduces on every Supabase project.                                                                                   |
| 10  | `addedByName` hydration is a two-query read, not a PostgREST join                                                    | Generalizable — lift                    | `database-queries.md § PostgREST cannot join through auth.*`           | PostgREST relationship-inference gap is structural to Supabase. Audit-feed gotcha (row 22) is the same pattern reapplied; rationale unified.                                               |
| 11  | Integration tests run opt-in via `VITEST_INTEGRATION=1`                                                              | Already in devshop — delete + pointer   | `conventions.md § Slow-Job Lifecycle`                                  | Slow-Job Lifecycle text names `VITEST_INTEGRATION=1` and the `*.integration.test.ts` exclusion-by-default convention.                                                                      |
| 12  | Local Supabase runs in a sibling compose container (Option 3 compose isolation)                                      | Already in devshop — delete + pointer   | `local-supabase-compose-isolation.md`                                  | Full file dedicated to the architecture, lifecycle, smoke tests, debugging tree.                                                                                                           |
| 13  | CI-only `SUPABASE_URL` / `SUPABASE_ANON_KEY` secrets are localhost placeholders                                      | Already in devshop — delete + pointer   | `security.md § CI Credential Isolation`                                | Covers local-stack defaults + URL guard combination. Env-var table at `ops.md § Env Var Naming Convention` carries the per-surface values.                                                 |
| 14  | `SUPABASE_PROD_URL` is the single source of truth for deploy workflows                                               | Already in devshop — delete + pointer   | `ops.md § Env Var Naming Convention`                                   | The env-var table explicitly marks `SUPABASE_PROD_URL` as deploy-workflow-only and notes the sed-derive pattern.                                                                           |
| 15  | Anthropic API key is split QA/PROD; function code reads canonical `ANTHROPIC_API_KEY`                                | Generalizable — lift                    | `security.md § Per-environment secret split with canonical inner name` | Blast-radius split + boundary-translation pattern reproduces for any third-party paid API with separate billing scopes per environment.                                                    |
| 16  | Custom domain + transactional email config lives in dashboards, not in this repo                                     | Generalizable — lift                    | `ops.md § Out-of-band dashboard surfaces`                              | Vercel Domains, SMTP provider, Supabase Auth UI templates + URL allow-list — none auto-deploy from CI on most stacks; pattern is stack-wide.                                               |
| 17  | Latency feedback tiers (A1/A2/B/C/D)                                                                                 | Already in devshop — delete + pointer   | `latency-feedback.md` (status note)                                    | `latency-feedback.md` already lists lalista's `specs/app-snappiness/spec.md § D1` as the canonical reference + flags post-soak lift; this entry exists to point at that stub.              |
| 18  | `emailRedirectTo` origin resolution prefers `NEXT_PUBLIC_SITE_URL`, falls back to `window.location.origin`           | Generalizable — lift                    | `supabase-ssr-boilerplate.md § Pattern 7`                              | Reproduces on every Next.js + Supabase Auth project. Row 24 (query-string survival) folds into the same Pattern 7 section.                                                                 |
| 19  | `fetchListEntries` returns `{entries, currentHouseholdId}`, not a bare array                                         | Project-specific — stay                 | n/a                                                                    | Load-bearing on the specific wrapper + `RemovedFromHouseholdError`; pattern lifted via synthetic row S2.                                                                                   |
| 20  | Single-household v0 invariant lives in BOTH layers; map 23505 in `OnboardingForm`                                    | Project-specific — stay                 | n/a                                                                    | Load-bearing on `household_members_one_per_user_v0` + `OnboardingForm`; pattern lifted via synthetic row S3.                                                                               |
| 21  | `accept_invite`'s `for update` row lock is load-bearing — sentinel comment enforced by unit test                     | Generalizable — lift                    | `migrations.md § Load-bearing SQL invariants and sentinel comments`    | EPQ-semantics-back-the-invariant + grep-enforced sentinel comment is a stack-wide pattern for any SQL block whose semantics depend on a specific clause.                                   |
| 22  | Audit-feed display-name hydration is a two-query read, not a PostgREST join                                          | Project-specific — stay                 | n/a                                                                    | Load-bearing on `household_audit_events` columns; + pattern lifted via row 10 (same PostgREST-auth.\* gap, single shared lift).                                                            |
| 23  | Migration-vs-Vercel deploy race window is documented, not split                                                      | Already in devshop — delete + pointer   | `conventions.md § Deploy Boundaries`                                   | The Deploy Boundaries section covers the parallel-race shape + schema-additive-vs-mutating split + the two operator options.                                                               |
| 24  | `emailRedirectTo` query string survives Supabase's redirect-URL allow-list — verify pre-merge                        | Generalizable — lift                    | `supabase-ssr-boilerplate.md § Pattern 7`                              | Same operator-pre-merge check around the same Supabase Auth feature; folded into Pattern 7 with row 18 to avoid splitting a single concept.                                                |
| 25  | Local-Supabase integration tests for email-confirm gap require flipping `enable_confirmations = true` per-test       | Generalizable — lift                    | `testing.md § Pattern 2: enable_confirmations flip per-test`           | The local-dev-default-no-confirm vs production-require-confirm gap reproduces on every Supabase project that runs auth-flow integration tests.                                             |
| 26  | `supabase/seed.sql`'s `auth.users` insert must populate 4 text columns as `''` AND insert matching `auth.identities` | Generalizable — lift                    | `migrations.md § seed.sql gotrue compatibility`                        | gotrue v2.188+ driver-scan strictness is a runtime constraint imposed by the auth server, not by lalista. Affects every project's local-dev loop + CI integration tests.                   |
| S1  | _(synthetic)_ Middleware allow-list authed-bypass carve-out for recovery flows                                       | Generalizable — lift (pattern from #7)  | `supabase-ssr-boilerplate.md § Pattern 8`                              | Recovery flows arrive with a session already; the middleware allow-list must NOT bounce authed users away from `/reset-password` and `/auth/callback`. Stack-wide.                         |
| S2  | _(synthetic)_ Realtime channel keeps delivering to removed members until JWT refresh — thread invariant data back    | Generalizable — lift (pattern from #19) | `wrapper-boundaries.md § Removed-member realtime leak`                 | RLS on REST is instant; Realtime channel takes a JWT-refresh round-trip to tear down. Wrappers that pair a list query with a realtime subscription should return the membership invariant. |
| S3  | _(synthetic)_ DB unique-constraint as loud structural backstop for application-layer business rules                  | Generalizable — lift (pattern from #20) | `migrations.md § DB constraint as loud structural backstop`            | Application-layer check + DB constraint is the loud-over-silent pattern. App handles common case; DB catches the race; wrapper maps both error codes to the same typed error.              |

**Count by classification:**

- `Already in devshop — delete + pointer`: 9 (rows 4, 6, 8, 11, 12, 13, 14, 17, 23)
- `Generalizable — lift`: 11 (rows 1, 2, 9, 10, 15, 16, 18, 21, 24, 25, 26) + 3 synthetic (S1, S2, S3) = 14 lift entries total, 13 distinct new sections (rows 18 + 24 share Pattern 7)
- `Project-specific — stay`: 6 (rows 3, 5, 7, 19, 20, 22)

Sum-check: 9 + 11 + 6 = 26 actual gotchas; 3 synthetic patterns lifted alongside.

## Lifts

13 new devshop sections, drafted in the imperative-present "do X / don't Y" style of the existing guides. Phase 2 appends each to the named target file verbatim.

### tailwind.md § Tailwind v4 `@source` directive

Tailwind v4 scans `@source`-declared globs for class-name usage; classes used only inside a non-scanned file ship as dead CSS. In a monorepo where styled components live in workspace packages outside the app's own tree (e.g. `packages/ui/**` consumed by `apps/web/**`), the app's root CSS file MUST declare each workspace-package source as an `@source` line.

```css
/* apps/web/app/globals.css */
@import 'tailwindcss';
@source "../../../packages/ui/src/**/*.{ts,tsx}";
```

Forgetting the `@source` line silently strips utilities used only by the consumed package — token classes (`bg-primary`, `border-border`), spacing utilities, etc. — and produces unstyled output without a build error or warning. When a new styled workspace package is added (e.g. a future `packages/icons`), add a matching `@source` line in the same PR.

### tailwind.md § Named-key sizing utilities resolve through `--spacing-*`

When `--spacing-*` tokens are defined in a Tailwind v4 `@theme inline` block (8/16/24/32 px on an 8px grid is a common template default), Tailwind v4 resolves every named-key sizing utility — `max-w-sm`, `max-w-md`, `min-w-lg`, `h-xl`, `w-2xl`, etc. — through the spacing scale, NOT the container scale. So `max-w-sm` ships as `max-width: 8px`, not the 24rem container value. Defining `--container-*` tokens alongside `--spacing-*` does NOT override.

Use arbitrary values for sizing — `max-w-[24rem]`, `h-[32px]`, `min-w-[420px]` — and reserve named keys for true spacing utilities (`p-4`, `gap-2`). The two scales collide at named-key resolution, and the container scale loses.

Restoring the container scale requires dropping `--spacing-*` and inheriting Tailwind's defaults — a wide blast radius on every gap/padding token in the codebase. Not done lightly. Verified empirically against direct `@tailwindcss/node` compile (2026-05-07).

### security.md § RLS-bypass write fallback ladder

When a code path needs to write a table its caller's role can't, prefer the narrower fix in this order:

1. **Table-level RLS policy** scoped to `authenticated` (or stricter) with the specific predicate the write needs — narrowest possible widening of the trust boundary.
2. **`SECURITY DEFINER` RPC** with an explicit `auth.uid()` check inside the function body — bypasses RLS for the duration of the function only; the auth check is the gate.
3. **Service-role escalation in an edge function** — the admin client can write ANY table; only acceptable when (1) and (2) are infeasible (e.g., the write must touch tables across multiple users and the auth check is multi-actor).

Service-role is the last resort because the admin client's blast radius is "any row in any table," not "this specific operation." It also moves the security boundary from auditable SQL (RLS policy + RPC body) into application code, where review discipline and observability are weaker. Default to (1); reach for (2) when the operation needs cross-row state the policy can't express; reserve (3) for the genuinely-cross-user cases.

### database-queries.md § PostgREST relationship inference does not chain through `auth.*`

PostgREST's natural-join syntax — `from('child').select('parent!fk_name(col)')` — relies on a FK pointing directly at a table in a PostgREST-reachable schema (default `public`). It does NOT chain through `auth.*`: a FK from `public.child(user_id)` to `auth.users(id)` does not let you join through to `public.profiles(user_id)` via shared FK target.

The fix is a two-query read — first select the child rows, union the `user_id`s into a unique set, then issue a second `profiles.select('user_id, display_name').in('user_id', uniqueIds)` and dedupe + map. The two-query shape is load-bearing — don't "simplify" it back to a single join without also adding a direct `child.user_id → profiles.user_id` FK, which would conflict with any `ON DELETE SET NULL` semantics on the `auth.users` reference (see `migrations.md § ON DELETE on auth.users FK references`).

Render a graceful fallback in the UI when either side is null: the `auth.users` row may have been deleted (`SET NULL` clears the column), or the `profiles` row may be unreadable under RLS. A null-safe display string ("someone" / "deleted user") avoids a UI crash and matches the soft-delete semantics of `ON DELETE SET NULL`.

### security.md § Per-environment secret split with canonical inner name

For third-party paid APIs with per-environment billing scopes (e.g. an LLM API), split the secret on the outer surface — CI/local-dev gets one secret-store name, production gets another — and translate to a single canonical name at the consumption boundary. Two reasons:

1. **Blast-radius separation.** A leaked QA key can't drain prod billing; prod rate-limit pressure from real users can't break CI.
2. **SDK alignment without per-environment branching.** The consumer (edge function, server-side runtime) reads `process.env.<CANONICAL_NAME>` — the name the SDK expects — and the surfaces around it (workflow steps, devcontainer env, deploy workflow) translate. The function body never sees the per-environment names; no `if (env === 'prod')` branch.

Concrete shape:

- GH Secret `<NAME>_QA` is re-exported as `<NAME>` inside `ci.yml`'s test steps.
- `.devcontainer/.env` carries the QA value under the `_QA` suffix (deliberately suffixed so any Claude Code instance running in the devcontainer doesn't mis-detect it as its own credential and prompt). A gitignored bridge file (e.g. `supabase/functions/.env`) re-names it to the canonical inside the local function-serve process.
- GH Secret `<NAME>_PROD` is pushed to the production runtime's secret store as `<NAME>` automatically by the deploy workflow — never lands on a local disk.

Operator setup is a checklist: create both GH Secrets; mint a separate prod-only key from the vendor's console; set the QA value in `.devcontainer/.env`; create the gitignored bridge file. First deploy after the prod secret exists auto-pushes it to the runtime.

### ops.md § Out-of-band dashboard surfaces

CI deploys the app, the database migrations, and the edge functions on push:main (per `conventions.md § Deploy Boundaries`). Several adjacent surfaces do NOT auto-deploy and need manual dashboard work — failing to do so means "the PR shipped but the user-facing change is invisible":

| Surface                                       | Where it lives                                            | When it ships                                                                                                          |
| --------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Custom domain + DNS                           | Vercel project → Domains; A/AAAA + CNAME at the registrar | Manual, once per domain                                                                                                |
| Transactional email provider                  | Provider's dashboard (Resend, Postmark, etc.) + SPF/DKIM  | Manual, once per project; rotate on provider switch                                                                    |
| Supabase Auth → SMTP Settings                 | Supabase dashboard → Auth → SMTP                          | Manual paste; never deploys from CI                                                                                    |
| Supabase Auth → Templates                     | Supabase dashboard → Auth → Templates (per-template tab)  | Manual paste; `supabase/templates/*.html` in the repo is the source of truth but does NOT auto-deploy                  |
| Supabase Auth → URL Configuration             | Supabase dashboard → Auth → URL Configuration             | Manual; covers the redirect allow-list for `emailRedirectTo`                                                           |
| Supabase Auth → Password Changed notification | Supabase dashboard → Auth → Templates → Password Changed  | Manual paste; the `[auth.email.notification.password_changed]` block in `supabase/config.toml` enables it locally only |

When a PR edits any of `supabase/templates/*.html`, `supabase/config.toml`'s auth/email blocks, or introduces a new redirect URL, the PR description MUST include the dashboard-paste step in the test plan. `/ak-go-live` does not handle out-of-band surfaces.

The `[auth.email.smtp]` block in `supabase/config.toml` is typically kept commented intentionally so local-dev mail flows to a sandbox (mailpit) instead of burning the provider's free tier — toggling it on locally costs real sends.

### supabase-ssr-boilerplate.md § Pattern 7: `emailRedirectTo` origin resolution + query-string survival

Two coupled rules for any `signUp` / `signInWithOtp` / `resetPasswordForEmail` call site that passes `emailRedirectTo`.

**Origin resolution prefers an env var, falls back to `window.location.origin`:**

```ts
const origin = process.env.NEXT_PUBLIC_SITE_URL ?? window.location.origin;
await supabase.auth.signUp({
  email,
  password,
  options: { emailRedirectTo: `${origin}/auth/callback?invite=${token}` },
});
```

Set `NEXT_PUBLIC_SITE_URL` on **Production** Vercel to pin the canonical URL even if the call ever runs from an unusual origin (CDN proxy, iframe). Leave it **unset on Preview** so previews self-route via `window.location.origin` — preview-to-preview testing works without a per-deploy env-var update.

**Query strings on `emailRedirectTo` survive Supabase's redirect-URL allow-list, but verify empirically before relying on it.** Supabase's Auth → URL Configuration matches by path, not query — an entry for `https://<host>/auth/callback` covers `?invite=<token>`, `?reset=<id>`, etc., automatically. Pre-merge manual test: trigger a real `signUp` against the prod Supabase project with `emailRedirectTo: <site>/auth/callback?test=42`, fetch the resulting email, confirm the link in the email body still contains `?test=42`. If not, add a wildcarded entry to Auth → URL Configuration. Make this a HARD BLOCKER on the PR test plan for any feature whose mechanism depends on the query-string surviving.

### migrations.md § Load-bearing SQL invariants and sentinel comments

When a SQL block's correctness depends on a specific clause that's easy to remove during a "simplifying" cleanup (an explicit `for update`, a `where used_at is null`, a `select … into strict`, an `on conflict do nothing`), pair the clause with a sentinel comment AND a pure-file grep test that asserts both are present.

```sql
-- LOAD-BEARING(do-not-remove): FOR UPDATE — Postgres EPQ semantics back the single-use guarantee
update tokens set used_at = now()
  where id = (
    select id from tokens
      where token = p_token and used_at is null
      for update
  )
  returning id;
```

The grep test lives next to the migration's integration test and asserts the sentinel comment + the load-bearing clause both still appear in the migration file. The integration test validates the runtime semantic (concurrent-write race, FK enforcement under load); the pure-file test catches the upstream code-change risk where a reviewer or formatter strips the clause without re-running integration.

Sentinel format: `LOAD-BEARING(do-not-remove)` followed by `—` and a one-line explanation of why removing the clause silently breaks the invariant. The explanation is the part future-you reads when re-encountering the comment cold.

### migrations.md § DB constraint as loud structural backstop for application-layer business rules

When an application-layer rule ("a user can only be in one household") needs to hold even under concurrent two-tab races, the application check is necessary but not sufficient. Add a DB-level UNIQUE / CHECK / EXCLUDE constraint as the loud-over-silent structural backstop, and map its error code at the wrapper boundary back to the same typed error the application check raises.

```sql
-- application check fires the typed error in the common case (P0001 raise)
-- DB constraint catches the two-tab race
alter table household_members
  add constraint household_members_one_per_user_v0 unique (user_id);
```

```ts
// wrapper boundary maps both signals to the same typed error
if (err.code === 'P0001' && err.message.includes('already in a household')) {
  throw new AlreadyInHouseholdError();
}
if (
  err.code === '23505' &&
  err.message.includes('household_members_one_per_user_v0')
) {
  throw new AlreadyInHouseholdError();
}
```

Reserve the unique-violation errcode (`23505`) exclusively for the literal DB constraint signal — don't use it as a generic "already exists" check at the application layer. Mixing the two collapses the distinction the two-layer defense is built to preserve.

### testing.md § Pattern 2: `enable_confirmations` flip per-test for email-confirm-gap coverage

Local Supabase dev typically runs with `auth.email.enable_confirmations = false` so sign-ups auto-confirm and the inner-loop test feedback stays fast. The trade-off: any code path that depends on the email-confirmation step (recovery flows, invite-token transport via `emailRedirectTo`, signup confirmation URL handling) never exercises end-to-end in the default config.

Per-test flip pattern:

```ts
beforeAll(async () => {
  await flipAuthConfig({ enable_confirmations: true });
});
afterAll(async () => {
  await flipAuthConfig({ enable_confirmations: false });
});

test('confirmation email link carries query-string params', async () => {
  await signUpWithRedirect({
    emailRedirectTo: `${url}/auth/callback?invite=${token}`,
  });
  const link = await fetchLatestEmailLink(); // mailpit / inbucket / similar
  expect(link).toContain(`?invite=${token}`);
});
```

The flip is per-suite; reset in `afterAll` so the next suite running against the same stack inherits the default config. If the local config endpoint doesn't expose a runtime flip, the fallback is to edit `supabase/config.toml`'s `[auth.email]` block and restart the auth service via whatever lifecycle channel exists for the project (a relay command, a `supabase stop && supabase start`).

This pattern lifts the "false-default for inner-loop speed; opt-in for the end-to-end test" trade-off out of the project's gotchas and into the testing convention. New projects inherit the toggle option; existing projects add the flip the first time they ship a feature whose mechanism depends on the email contents (not just the email being sent).

### migrations.md § `seed.sql` gotrue compatibility — required text columns + matching `auth.identities`

Recent gotrue versions (v2.188+) scan four `auth.users` text columns into Go `string` (not `*string` / `sql.NullString`):

- `email_change`
- `recovery_token`
- `confirmation_token`
- `email_change_token_new`

Any seed row that leaves these NULL trips a driver scan error on every read — `auth.admin.listUsers()` and `/auth/v1/token` both return 500 `Database error querying schema`. gotrue's own signup path inserts `''` for these; seed rows must match.

Additionally, gotrue's `listUsers` + token endpoints expect every user to have at least one row in `auth.identities` with `provider = 'email'` and `provider_id = user.id::text`. A user row without a paired identity row fails the same endpoints with the same shape.

Canonical seed row shape:

```sql
insert into auth.users (id, email, encrypted_password, email_confirmed_at,
  email_change, recovery_token, confirmation_token, email_change_token_new, ...)
values (
  '...', 'alice@example.com', crypt('password', gen_salt('bf')), now(),
  '', '', '', '', ...
);

insert into auth.identities (id, user_id, provider, provider_id, identity_data, last_sign_in_at)
values (
  gen_random_uuid(), '<user_id>', 'email', '<user_id>',
  jsonb_build_object('sub', '<user_id>', 'email', 'alice@example.com'),
  now()
);
```

Verify after any seed change with `pnpm db:reset && curl <auth-url>/auth/v1/admin/users -H 'Authorization: Bearer <service-role>'` — must return a JSON users array, not 500. The constraint is enforced at runtime by the auth server, not by Postgres — the only forcing function is the smoke check.

### supabase-ssr-boilerplate.md § Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows

Most marketing/auth-screen routes (`/sign-in`, `/sign-up`, `/forgot-password`) should bounce authed users away — visiting them mid-session is a confused state. Recovery routes (`/reset-password`, `/auth/callback`) are different: they arrive WITH a session because the route handler created one (magic-link exchange, recovery-token exchange).

```ts
// apps/web/middleware.ts
const PUBLIC_PATHS = [
  '/',
  '/sign-in',
  '/sign-up',
  '/forgot-password',
  '/reset-password',
  '/auth/callback',
];
const AUTHED_BOUNCE_PATHS = ['/sign-in', '/sign-up', '/forgot-password'];
// NOT in AUTHED_BOUNCE_PATHS: '/reset-password', '/auth/callback'

if (session && AUTHED_BOUNCE_PATHS.includes(path)) {
  return NextResponse.redirect(new URL('/list', req.url));
}
```

Bouncing authed users away from `/reset-password` would break recovery — the user arrives with the session the route handler just minted and immediately gets redirected away from the password form. Same for `/auth/callback` — the exchange happens inside that handler.

PWA `start_url` should point at the authed landing route (e.g. `/list`) so installed users skip the marketing screen on launch.

### wrapper-boundaries.md § Removed-member realtime leak — thread invariant data back from the wrapper

When a wrapper pairs a list query (REST) with a realtime subscription (WebSocket) on the same data, REST and Realtime tear down asymmetrically when membership changes. RLS on the REST side enforces "must be a member" on the next request — instant. The Realtime channel keeps emitting until the JWT refreshes — up to one JWT-refresh round-trip of leaked events to a removed member.

Mitigate by threading the membership invariant back through the wrapper's return shape, so the consumer can self-heal on every realtime tick:

```ts
// Before — bare array; consumer has no way to detect membership revocation
export async function fetchListEntries(client, householdId): Promise<Entry[]> { ... }

// After — return shape carries the membership signal
export async function fetchListEntries(client): Promise<{
  entries: Entry[];
  currentHouseholdId: string;
}> {
  const { data: hh } = await client.rpc('current_household_id');
  if (!hh) throw new RemovedFromHouseholdError();
  const { data: entries } = await client.from('list_entries').select('*');
  return { entries, currentHouseholdId: hh };
}
```

Consumers debounce-refetch on every realtime event; when the wrapper throws `RemovedFromHouseholdError`, the consumer tears down the subscription and routes the user to a "you've been removed" screen. Bounds the leak to ~1 round-trip.

Don't "simplify" the wrapper back to a bare array — the membership signal is the recovery path; collapsing the shape resurrects the leak.

## Routing rows

13 new rows for `kit/docs/guide/README.md`. Grouped to match the existing index structure; D5 introduces one new top-level group, `Frontend stack`, for `tailwind.md`.

### New group: `## Frontend stack`

> Stack-version footguns surfaced by Tailwind v4 + workspace-package source scanning + spacing tokens. Fires on `apps/web/app/globals.css`, `packages/ui/src/**`, and keyword `"Tailwind"` / `"@source"` / `"max-w-"` in Decisions.

| Trigger                                                                                                                                              | Target                                                                                                                                    | Notes                                                                                            |
| ---------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| New / modified `apps/web/app/globals.css` OR new workspace package with styled components OR keyword `"@source"` in Decisions                        | [`tailwind.md § Tailwind v4 @source directive`](./tailwind.md#tailwind-v4-source-directive)                                               | Add an `@source` line for every styled workspace package consumed by the app.                    |
| Sizing-utility usage in PR diff (`max-w-`, `min-w-`, `w-{xs,sm,md,lg,xl,2xl}`, `h-{xs,…}`) OR keyword `"--spacing-"` / `"--container-"` in Decisions | [`tailwind.md § Named-key sizing utilities resolve through spacing`](./tailwind.md#named-key-sizing-utilities-resolve-through---spacing-) | Use arbitrary values for sizing (`max-w-[24rem]`); named keys collide with `--spacing-*` tokens. |

### Additions to existing groups

**Under `## Data`:**

| Trigger                                                                                                                                                                                           | Target                                                                                                                                                        | Notes                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| PostgREST join syntax in `.select(...)` referencing tables under `auth.*` OR keyword `"PostgREST join"` / `"auth.users"` in Decisions                                                             | [`database-queries.md § PostgREST cannot join through auth.*`](./database-queries.md#postgrest-cannot-join-through-auth)                                      | Two-query hydration is the fix; UI fallback for null author / unreadable profile.     |
| New migration with a clause whose semantics depend on a specific keyword (`for update`, `select … into strict`, `on conflict do nothing`) OR keyword `"LOAD-BEARING"` / `"sentinel"` in Decisions | [`migrations.md § Load-bearing SQL invariants and sentinel comments`](./migrations.md#load-bearing-sql-invariants-and-sentinel-comments)                      | Sentinel comment + pure-file grep test + integration test for the runtime semantic.   |
| New `unique` / `check` / `exclude` constraint backstopping an application-layer business rule OR new RPC catching `23505` / `P0001` errcodes                                                      | [`migrations.md § DB constraint as loud structural backstop`](./migrations.md#db-constraint-as-loud-structural-backstop-for-application-layer-business-rules) | App check (`P0001`) + DB constraint (`23505`) → same typed error at wrapper boundary. |
| `supabase/seed.sql` edits adding `auth.users` rows OR keyword `"gotrue"` / `"auth.identities"` / `"email_change"` in Decisions                                                                    | [`migrations.md § seed.sql gotrue compatibility`](./migrations.md#seedsql-gotrue-compatibility--required-text-columns--matching-authidentities)               | 4 required text columns must be `''`; matching `auth.identities` row required.        |

**Under `## Auth + security`:**

| Trigger                                                                                                                                                                                                  | Target                                                                                                                                         | Notes                                                             |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| New write path needing RLS bypass (new `SECURITY DEFINER` RPC, edge-fn service-role escalation, new RLS policy widening `authenticated`) OR keyword `"SECURITY DEFINER"` / `"service-role"` in Decisions | [`security.md § RLS-bypass write fallback ladder`](./security.md#rls-bypass-write-fallback-ladder)                                             | Policy → RPC → service-role, in order; default to the narrowest.  |
| New third-party paid-API secret (LLM, payments, email-provider) OR PR adds a `_QA` / `_PROD` GH Secret pair OR keyword `"split secret"` / `"blast radius"` in Decisions                                  | [`security.md § Per-environment secret split with canonical inner name`](./security.md#per-environment-secret-split-with-canonical-inner-name) | Outer surfaces use prefixed names; consumer reads canonical name. |

**Under `## Frontend + UI`:**

| Trigger                                                                                                                                                       | Target                                                                                                                                                | Notes                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `signUp` / `signInWithOtp` / `resetPasswordForEmail` call sites with `emailRedirectTo` OR keyword `"NEXT_PUBLIC_SITE_URL"` / `"emailRedirectTo"` in Decisions | [`supabase-ssr-boilerplate.md § Pattern 7`](./supabase-ssr-boilerplate.md#pattern-7-emailredirectto-origin-resolution--query-string-survival)         | Origin via `NEXT_PUBLIC_SITE_URL ?? window.location.origin`; verify query-string survival pre-merge. |
| `apps/web/middleware.ts` allow-list edits OR new recovery-flow route (`/reset-password`, `/auth/callback`) OR keyword `"recovery flow"` in Decisions          | [`supabase-ssr-boilerplate.md § Pattern 8`](./supabase-ssr-boilerplate.md#pattern-8-middleware-allow-list-authed-bypass-carve-out-for-recovery-flows) | Recovery routes must NOT bounce authed users — they arrive with a session by design.                 |

**Under `## Ops + deploy`:**

| Trigger                                                                                                                                                                              | Target                                                                               | Notes                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `supabase/templates/*.html` edits OR `supabase/config.toml` `[auth.email.*]` edits OR new custom domain OR new SMTP provider OR keyword `"out-of-band"` / `"dashboard"` in Decisions | [`ops.md § Out-of-band dashboard surfaces`](./ops.md#out-of-band-dashboard-surfaces) | Vercel Domains, SMTP provider, Supabase Auth UI — none auto-deploy from CI. |

**Under `## Dev + meta`:**

| Trigger                                                                                                                                                                  | Target                                                                                                                    | Notes                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| New integration test exercising a path that depends on email-confirmation OR `signUp` flow OR keyword `"enable_confirmations"` / `"mailpit"` / `"inbucket"` in Decisions | [`testing.md § Pattern 2: enable_confirmations flip per-test`](./testing.md#pattern-2-enable_confirmations-flip-per-test) | Per-suite `beforeAll` flip; reset in `afterAll`. |

**Under `## Data` (synthetic-row coverage — wrapper change paired with realtime):**

| Trigger                                                                                                                                                                                | Target                                                                                                                                                      | Notes                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| API wrapper in `packages/core/src/api/**` that pairs a `.from(...).select(...)` with a `subscribeTo<X>` on the same data AND the underlying table has a membership-style RLS predicate | [`wrapper-boundaries.md § Removed-member realtime leak`](./wrapper-boundaries.md#removed-member-realtime-leak--thread-invariant-data-back-from-the-wrapper) | Wrapper returns `{rows, <membership-invariant>}`; throws typed `RemovedFromX` error when membership revoked. |

### Alphabetical-file-list addition

Add a single row to the existing alphabetical file list:

| Guide                          | What it covers                                                                                                                                                              |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`tailwind.md`](./tailwind.md) | Tailwind v4 footguns — `@source` directive for workspace-package source scanning; named-key sizing utilities resolving through `--spacing-*` instead of the container scale |

### Contents-list addition

Add `- [Frontend stack](#frontend-stack)` to the top-of-file `## Contents` block, between `Frontend + UI` and `Ops + deploy`.

## Lalista CLAUDE.md edits (corrected mid-flight per D6)

**Shape (corrected):** **Pure delete** of all 20 lifted / already-in-devshop gotchas. Project-specific 6 stay **verbatim** (no `_Pattern: …_` suffix). One-line header note in the gotchas section points readers at the routing index for stack-wide patterns — that's the only outward reference.

**Why corrected:** Original D6 specified one-line pointers; the corrected D6 (see above) specifies pure delete because the routing system handles devshop discovery via `/ak-implement` automatically. Pointers from project → devshop are noise — they duplicate the routing system's job and don't carry their weight.

**Deleted from lalista CLAUDE.md (20 entries):**

Already-in-devshop set (9): Realtime `subscribeToList`; `ON DELETE` on `auth.users` FK; Edge function deploy step; `VITEST_INTEGRATION=1`; Local Supabase compose isolation; CI `SUPABASE_URL` placeholders; `SUPABASE_PROD_URL` single source of truth; Latency feedback tiers; Migration-vs-Vercel deploy race.

Generalizable-lift set (11; rows 18 + 24 fold into Pattern 7): Tailwind `@source`; Named-key sizing; RLS-bypass principle; `addedByName` two-query; Anthropic API key split; Custom domain + email; `emailRedirectTo` origin + query-string survival (combined); `accept_invite` FOR UPDATE; Email-confirm gap test pattern; `seed.sql` gotrue compatibility.

**Kept verbatim (6 project-specific):**

- `mark_item_bought` RPC (row 3) — load-bearing on the specific RPC + table names.
- `list_entries.added_by` nullable (row 5) — load-bearing on specific column + UI fallback strings.
- Information architecture (row 7) — load-bearing on lalista routes.
- `fetchListEntries` returns `{entries, currentHouseholdId}` (row 19) — load-bearing on the specific wrapper + `RemovedFromHouseholdError`.
- Single-household v0 invariant; map 23505 (row 20) — load-bearing on `household_members_one_per_user_v0` + `OnboardingForm`.
- Audit-feed display-name two-query (row 22) — load-bearing on `household_audit_events` columns.

**Header note added (1 line):** Above the bullets, the section header carries a one-line clarification: "Lalista-specific only. Stack-wide patterns lifted to devshop guides where /ak-implement finds them via the routing index — see /devshop/kit/docs/guide/README.md." Sets reader expectation without per-bullet pointers.

**Net diff:** CLAUDE.md only, -62 lines / +2 lines on the lalista side. The `specs/claude-md-gotcha-routing-audit/` directory is NOT created in `/workspace` — those audit artifacts (this spec, tasks.md, routing-validation.md) live in `/devshop/specs/claude-md-gotcha-routing-audit/` instead, because PR-B's substantive output IS the devshop changes; the lalista CLAUDE.md trim is a downstream consequence.

## Files to create/modify

### Lalista (`feature/claude-md-gotcha-routing-audit` off `main`)

**Modified (only file touched on lalista side):**

- `CLAUDE.md` — pure delete of 20 lifted / already-in-devshop gotchas; 6 project-specific entries kept verbatim; one-line header note added pointing at devshop routing index. Net: -62 lines, +2 lines.

**No `specs/claude-md-gotcha-routing-audit/` directory created on the lalista side** — those audit artifacts live in `/devshop/specs/claude-md-gotcha-routing-audit/` (see below) because PR-B's substantive output is the devshop changes.

### Devshop (`feature/lalista-claude-md-gotcha-lifts` off `main` at `1c32baa`)

**Created:**

- `kit/docs/guide/tailwind.md` — new file with 2 sections per D5.
- `kit/notes/lalista-claude-md-classification.md` — Audit-table snapshot for the devshop PR's "what changed" link.
- `specs/claude-md-gotcha-routing-audit/spec.md` — this file.
- `specs/claude-md-gotcha-routing-audit/tasks.md` — Phase 2 implementation log.
- `specs/claude-md-gotcha-routing-audit/routing-validation.md` — fixture-trace doc per D8.

**Modified:**

- `kit/docs/guide/README.md` — new `## Frontend stack` group; 13 new routing rows distributed across groups; `tailwind.md` row added to alphabetical file list; Contents list updated.
- `kit/docs/guide/security.md` — append `## RLS-bypass write fallback ladder` and `## Per-environment secret split with canonical inner name`; update Contents.
- `kit/docs/guide/database-queries.md` — append `## PostgREST cannot join through auth.*`; update Contents.
- `kit/docs/guide/migrations.md` — append `## Load-bearing SQL invariants and sentinel comments`, `## DB constraint as loud structural backstop for application-layer business rules`, and `## seed.sql gotrue compatibility — required text columns + matching auth.identities`; update Contents.
- `kit/docs/guide/ops.md` — append `## Out-of-band dashboard surfaces`; update Contents.
- `kit/docs/guide/supabase-ssr-boilerplate.md` — append `## Pattern 7: emailRedirectTo origin resolution + query-string survival` and `## Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows`; update Contents.
- `kit/docs/guide/testing.md` — append `## Pattern 2: enable_confirmations flip per-test`; update Contents.
- `kit/docs/guide/wrapper-boundaries.md` — append `## Removed-member realtime leak — thread invariant data back from the wrapper`; update Contents.

**Not modified:**

- Any skill body, command, or hook script — D7 reuses the shipped three BATS suites without changes to skill behavior.
- `kit/manifest.txt` — no template-tracked file changes; new guides aren't auto-synced to projects.
- ROADMAP — entry for PR-B remains open; Phase 4 marks it closed.

## Task order

Phase 2 implementation order, with dependencies. Each task is committed atomically.

1. **Devshop: classification artifact** — copy the Audit table from this spec into `kit/notes/lalista-claude-md-classification.md` for the devshop PR description's "what changed" link. Keeps the spec file in lalista canonical; the devshop side gets a permalink artifact.
2. **Devshop: create `kit/docs/guide/tailwind.md`** — H1 + Contents + 2 lift sections from `## Lifts` above. Forms the basis for the new Frontend-stack group.
3. **Devshop: append new sections to existing guides**, in alphabetical order to minimize merge-conflict surface across the 6 modified files:
   - 3a. `database-queries.md` — 1 new section (PostgREST cannot join through `auth.*`); update Contents.
   - 3b. `migrations.md` — 3 new sections (Load-bearing SQL invariants; DB constraint as loud backstop; seed.sql gotrue compatibility); update Contents.
   - 3c. `ops.md` — 1 new section (Out-of-band dashboard surfaces); update Contents.
   - 3d. `security.md` — 2 new sections (RLS-bypass write fallback ladder; Per-environment secret split); update Contents.
   - 3e. `supabase-ssr-boilerplate.md` — 2 new patterns (7, 8); update Contents.
   - 3f. `testing.md` — 1 new pattern (Pattern 2: enable_confirmations flip); update Contents.
   - 3g. `wrapper-boundaries.md` — 1 new section (Removed-member realtime leak); update Contents.
4. **Devshop: update `kit/docs/guide/README.md`** — add `## Frontend stack` group, 13 new routing rows distributed across groups, alphabetical-file-list row for `tailwind.md`, Contents list entry. Single commit so the index update is atomic.
5. **Devshop: BATS validation** — run `pnpm test:kit` (invokes the three routing-\* suites). Fix any anchor-resolution failures by adjusting either the new section heading slug or the routing-row link target. Re-run until green.
6. **Lalista: branch from `main`** at `aa37b74` per D1.
7. **Lalista: edit `CLAUDE.md`** — apply pointer replacements per `## Lalista CLAUDE.md edits` above:
   - 7a. Replace 9 already-in-devshop gotcha bodies with one-line pointers.
   - 7b. Replace 11 generalizable gotcha bodies with one-line pointers (with rows 18 + 24 sharing one pointer line under Pattern 7).
   - 7c. Append "_Pattern: ..._" line to each of the 6 project-specific entries.
8. **Lalista: write `specs/claude-md-gotcha-routing-audit/routing-validation.md`** — one section per new routing row, each containing the synthetic diff signal, the expected `(file, anchor)` target, and the 1-line attestation per D8.
9. **Lalista: verify devshop links resolve from `/workspace/CLAUDE.md`** — local sanity check via a markdown link checker (`pnpm exec lint-md` or `markdownlint-cli2`) OR a quick `cat`-and-grep against the new devshop sections. The relative paths assume `/workspace/CLAUDE.md` and `/devshop/kit/docs/guide/<file>.md` are siblings under `/` (`/workspace/` and `/devshop/`) — which is the canonical devcontainer layout per `architecture.md`. Operators not running the devcontainer may have a different `/devshop` location; the pointer convention assumes the standard layout per D6 / the routing-system PR.
10. **Both repos: PR descriptions cross-link** — lalista PR body links to the devshop PR + the classification artifact (`kit/notes/lalista-claude-md-classification.md`); devshop PR body links back at the lalista PR + the routing-validation doc.

## Tests

Per D7, no new BATS suites and no new unit / integration / E2E specs (docs-only diff).

**Reused:**

- `kit/tests/routing-link-resolution.bats` — asserts every routing-row `(file, anchor)` resolves to a real H2/H3 in the target guide. Runs against the 13 new rows.
- `kit/tests/routing-completeness.bats` — asserts every guide in `kit/docs/guide/*.md` is in either a routing group or the out-of-routing list. Will fail if `tailwind.md` is added to the file tree but not listed; passes once the README updates land in the same commit.
- `kit/tests/routing-real-world-grounding.bats` — fires the ≥3-trigger assertion against the new rows. The corpus is existing lalista specs; this PR doesn't widen the corpus.

**Invocation:**

- Local: `pnpm test:kit` from `/devshop/`.
- CI: `kit-tests` job in `/devshop/.github/workflows/ci.yml` (already runs on every devshop push).

**Coverage check the PR must pass:**

- `routing-link-resolution.bats` is green after Task 5.
- `routing-completeness.bats` is green after Task 4 (the `tailwind.md` addition and the `Frontend stack` group land together).
- `routing-real-world-grounding.bats` is green; if it fails for a new row, either widen the trigger or pick a sturdier fixture from lalista specs.

**Lalista side:**

- No tests added or modified.
- Existing CI (`fast` job) runs as usual on the pointer-replacement PR; no functional code changes.

## Gotchas

Pitfalls for future maintenance of the audit's outputs. Aimed at the next person who extends the routing index or adds a guide section.

- **Section anchors must follow GitHub's slug rules** — lowercase, spaces → `-`, punctuation stripped, multiple `-` collapsed but trailing `-` preserved if literal characters cause it. `routing-link-resolution.bats` derives expected anchors via the same algorithm; a heading with non-trivial punctuation (e.g. `### Section foo — bar`) generates an anchor with the em-dash spaces preserved (`#section-foo--bar`). The PR's `## Lifts` section already uses headings that round-trip cleanly through the slug algorithm; if a Phase 2 wordsmith pass changes a heading, regenerate the routing-row link anchor in lockstep.
- **The BATS link-resolution test parses headings, not link text** — if a future PR adds a new section to one of the modified guides and the routing index still points at the old anchor, the BATS test catches it. But if both the heading and the link change in the same commit and the new combination doesn't match the actual slug rule, the test catches it too. Don't hand-write a complex anchor; let the slug-generator deduce it from the heading.
- **`tailwind.md` is a 2-section file at first; promote to subdirectory only at ≥3 files per the routing index's promote-to-subdirectory rule** — adding a third Tailwind-related lift to the same file is fine; adding a fourth and splitting into `tailwind/v4-quirks.md` / `tailwind/responsive-patterns.md` would require updating the routing rows' relative paths in the same commit. Don't split prematurely.
- **The Pattern-7 + Pattern-8 numbering on `supabase-ssr-boilerplate.md` is sequential after the existing 6 patterns** — Pattern 6 (`page.routeWebSocket`) is the current highest; this PR adds 7 + 8. If a parallel PR also tries to add a Pattern 7, the merge conflict is loud and obvious; resolve by re-numbering one of them. The routing-row anchors update in the same conflict resolution.
- **Pointer text in lalista `CLAUDE.md` is the canonical "found here" path** — when a future devshop PR renames or reorganizes one of the targeted sections, the routing index updates in-place but the lalista pointer goes stale silently. Mitigation: the routing-system's BATS suite catches the devshop-side anchor drift; the lalista pointer convention (per D6) is "trust the routing index" — future audits walk the pointers and refresh them on each canonical audit cycle.
- **Adding a new line to "Where Things Happen" (lines 14-23 of lalista's CLAUDE.md) is NOT a gotcha and is out of scope for this audit per D4** — but those bullets do grow as new features ship. A future PR that adds e.g. an "Inventory" section to "Where Things Happen" should not collide with this audit's pointer block; the two sections are separated by a heading and don't interact.
- **The 5 `feat/my-stores` gotchas (post-canonical) will need a follow-on audit after that PR merges** — they're explicitly out of scope per D4. The follow-on can ride this audit's classification rubric without re-litigating D3.
- **Routing-validation doc is markdown, not code** — D8 explicitly chose the trace-doc shape over a runtime invocation harness. Don't try to "test" the routing-validation doc programmatically; it's evidence, not test code. If a runtime invocation harness ships in a future v1 entry, the doc becomes redundant and can be deleted.

## Acceptance / rollout / rollback

### Acceptance

The PR pair lands when ALL of:

- Lalista PR: `CLAUDE.md`'s `### Gotchas` section is 6 verbatim entries + 20 pointer lines (= 26 entries total, matching the canonical input). Total file lines ~110-120 vs main's 160.
- Devshop PR: 13 new routing rows resolve to real H2/H3 sections per `routing-link-resolution.bats` (green). `routing-completeness.bats` is green with `tailwind.md` in the new Frontend-stack group. `routing-real-world-grounding.bats` is green.
- All devshop kit-tests pass: `pnpm test:kit` green from `/devshop/`.
- Lalista's existing `fast` CI job is green on the pointer-replacement diff (no functional code change).
- Cross-references between the two PRs are present in each PR description.
- `specs/claude-md-gotcha-routing-audit/routing-validation.md` exists and has one section per new routing row.

### Rollout

**Merge ordering** — devshop PR can merge first OR second; per D2, the pointer text uses relative paths into the devshop tree and resolves correctly regardless of merge order. The recommended order is:

1. **Devshop PR first.** Routing rows are validated by BATS before merge; section anchors are real.
2. **Lalista PR second.** Once devshop's new sections exist on `main`, lalista's pointer links resolve from a fresh clone — useful for any operator who pulls lalista before pulling devshop. (In the standard devcontainer layout, both repos are sibling clones under `/`; resolution doesn't depend on cloud-side merge ordering.)

**Reverse order is fine too** — if devshop is in CI longer than lalista, merge lalista first; pointer text references devshop's `main` but the routing index BATS-tested the anchors pre-merge, so even unmerged devshop content has the right anchors. The only failure mode is a partial-rollback (devshop reverts a section), which would point lalista at a 404; the rollback section below covers that.

**No deploy step** — both PRs are docs-only. No Vercel deploy, no Supabase migration, no edge-function deploy. CI green = ship.

### Rollback

**Lalista PR rollback** — revert via `git revert <merge-sha>` on `main`. Pointer lines disappear; the deleted gotcha bodies come back. No data loss; no migration unwind. The devshop sections stay in place and remain referenced by the routing index — lalista just doesn't lean on them anymore.

**Devshop PR rollback** — revert via `git revert <merge-sha>` on `main`. The 13 routing rows + the new sections disappear. If the lalista PR has merged, the pointer links point at 404s until either the devshop revert is itself reverted OR the lalista PR is also reverted. Resolution: prefer re-reverting (i.e. re-applying the devshop PR with a fix-forward patch) over reverting the lalista PR. Reverting both is the conservative path if a substantive section needs rewriting.

**Partial rollback** (one new section removed without reverting the whole PR) — fix the routing-row anchor in lockstep OR add a pointer-redirect at the moved/deleted anchor (the existing "pointer-redirect" pattern from the routing-system PR). BATS Test 1 catches the routing-row drift; the lalista-side pointer drift requires a follow-on audit.

**No state to restore** — docs-only PR. No DB rows, no env vars, no edge-function code. The git-revert is the rollback.
