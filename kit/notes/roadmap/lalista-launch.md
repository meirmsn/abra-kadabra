# Lalista launch — pending v0 work, both sides

Snapshot 2026-05-04. Synthesizes `lalista/PLAN.md` + `lalista/PRODUCT-ROADMAP.md` +
`lalista/TODOS.md` and `/devshop/kit/ROADMAP.md` + `/devshop/kit/TODOS.md` into a
single picture of what's left for lalista v0 GA, what devshop v0 work is in
flight, and the order that minimizes wasted motion.

---

## Lalista v0 — pending

**Forward features** (chapter-grain — `PRODUCT-ROADMAP.md § v0` 1k/1l/1m;
sliced into PRs on `PLAN.md` as each becomes next-up):

- ✅ **Interlude: devshop-preship-hardening** — shipped 2026-04-27/28. Four
  parts: (a) RLS-coverage pre-ship gate, (b) `/ak-spec` render-condition
  matrix, (c) `/plan-design-review` "input duplicates existing data" prompt,
  (d) dev-side prod-Supabase isolation (Option 3 compose isolation —
  workspace has no docker socket; sibling `supabase-runner` holds it; narrow
  `<host>/supabase` bind; RPC relay on :9000). Architecture doc:
  `kit/docs/guide/local-supabase-compose-isolation.md`; threat-model:
  `kit/notes/security/local-supabase-isolation-options.md`.
- ✅ **chapter 1j (zod-validation)** — shipped 2026-04-27 as lalista #30
  `4ba875f` (closer #33 `a7450c9`). Adopted the upstream Zod LLM-boundary
  convention directly.
- 🚧 **chapter 1l: auth UX rework** — **in flight on `feat/auth-ux-rework`**.
  Splits the magic sign-in form into `/sign-in` + `/sign-up` +
  `/forgot-password` + `/reset-password`, adds branded EN-only Supabase
  email templates, hard-gates email confirmation with resend countdown,
  ships `AuthSubmitButton` (instant disable + 250ms threshold spinner),
  unified `AuthErrorDisplay`, email persistence via React context across
  auth screens, name-collection moved to onboarding. Supersedes the prior
  `auth-ux-refactor-to-adopt` framing — see "Inverted devshop-extraction
  sequencing" below.
- ⏳ **chapter 1k: structured-intent-parsing** — replace Claude's
  translator-only role in `add-item` with structured extraction (compound
  adds, quantity/unit, brand, store hints). Response grows `entries[]` for
  N-row optimistic inserts. `per-household-items-catalog` no longer a hard
  dep for single-household v0. (Was PR 7 in the prior snapshot.)
- ⏳ **chapter 1m: app-wide snappiness** — generalizes 1l's button-feedback
  pattern app-wide: lifts `AuthSubmitButton` → `packages/ui/SubmitButton`,
  adopts across AddItemSheet / ListRow / DisambiguationSheet / force-create /
  Settings / DisplayNameField; new `LoadingArea` primitive + `loading.tsx`
  on every route under `apps/web/app/**` (deliberately empty container with
  soft animated color shift, NOT wireframe skeletons). Structurally depends
  on 1l (the lift target).

**Pre-ship** (`TODOS.md § v0 § pre-ship`):

- ✅ **core-flows-happy-path-ci-investigation** — shipped 2026-04-27 as
  lalista #31 `4e78fbd`.
- ✅ **devcontainer-migrate-to-Option-3-compose-isolation** — shipped
  2026-04-28 as lalista PR 34 (`devcontainer-compose-isolated`, commits
  `75a02f6` → `7231cb9` → `3d4ef2d` → `cf71aad` → `a76b5f8`). Pivoted from
  the original Option 2 (host docker socket bind-mount) framing — the
  fallback branch `devcontainer-host-docker-socket` carries that snapshot.
  Five-commit diagnostic arc captured each failure mode hit during real
  verification (LOCAL_WORKSPACE_FOLDER unset → empty bind, port 54321/54322
  conflicts with supabase siblings, supabase CLI hardcoded localhost
  healthcheck failing inside the runner, integration-test URL gate too
  narrow, IPv6 vs iptables-IPv4-only) so future operators recognize them
  from the commit messages rather than re-deriving. Closes interlude (d)'s
  adoption gap on the lalista side. New devshop architecture doc captured
  the pattern at `kit/docs/guide/local-supabase-compose-isolation.md`;
  template-variant follow-up tracked in `kit/TODOS.md §
lalista-option3-template-variant`.

**Launch-day** (`TODOS.md § v0 § launch-day`):

- **bootstrap-purchase-history-prod** — run the prepared `do $$ ... $$` block
  once after first prod account creation, so `route_item_to_store` has signal
  from day one.

**v0 GA checkpoint** (PRODUCT-ROADMAP.md): every functional gate checked off
(auth, add/list/bought, realtime, dark mode, errors, CI, Sentry, PostHog).
**Remaining for GA = 1l (in flight) → 1k → 1m → launch-day seed.**
(1j shipped 2026-04-27; core-flows CI flake fix shipped same day; 1l/1m
chapters added to roadmap 2026-05-02 — supersede the prior PR 6/PR 7
framing.)

---

## Devshop v0 — pending (`/devshop/kit/ROADMAP.md` + `/devshop/kit/TODOS.md`)

Status legend: ⏳ truly pending · ✅ shipped (full detail in the parallel-cluster
section below) · v1 = deferred to v1, captured in `kit/ROADMAP.md`.

**Convention enforcement (paired):**

- ✅ **Audit `conventions.md` → distribute operational copy into skills** —
  audit shipped v1.22.0; per-skill redistribution shipped 2026-04-27 in
  commit `75500e2` (7 SKILL.mds inlined; Tier 1 already lived in
  `/devshop/CLAUDE.md` and arrives at project sessions via SessionStart hook).
- ✅ **Adversarial reviewer reads `guide/` for convention checks** —
  shipped v1.22.0 (`CONVENTIONS_TO_INCLUDE` map in `adversarial-review.sh`).

**Project-repo gates (triplet, pair-ship):**

- ✅ **Pre-commit test-presence hook** — shipped 2026-04-28 on devshop branch
  `feat/project-repo-gates-triplet`. `kit/scripts/commit-hooks/check-test-coverage-project.sh`
  - adversarial reviewer (`testCoverageProject`) + 23 bats cases. Override file
    `.devshop-test-coverage-exempt`. Wired into the project branch of
    `kit/hooks/pre-commit.sh`. See `conventions.md § Test Presence`.
- ✅ **Project-repo docs-freshness hook + adversarial reviewer** — shipped same
  branch. `check-docs-freshness-project.sh` blocks new `page.tsx` / `route.ts` /
  API wrappers / `posthog.capture` / `Sentry.captureException` without paired
  `CLAUDE.md` / `METRICS.md` update; blocks delete-with-stale-doc-reference.
  Reviewer (`docsFreshnessProject`) verifies bypass-claims against the actual
  staged docs. Override file `.devshop-docs-freshness-exempt`. 17 bats cases.
  See `conventions.md § Project Docs Freshness`.
- ✅ **Hierarchical docs scaffold in template** — shipped same branch. Template
  now ships `CLAUDE.md` / `TODOS.md` / `METRICS.md` skeletons alongside existing
  `PLAN.md` / `BUILD-LOG.md` / `PRODUCT-ROADMAP.md` / `README.md`.
  `/ak-new-project § Step 16` + `§ Step 18` simplified from "create the file"
  to "fill the scaffolded skeleton." See `conventions.md § Project Docs Hierarchy`.
  Adoption on lalista (false-positive flush) follows in a project-side commit
  that wires `.hooks/pre-commit` and seeds the override files.

**Migration / CI hygiene:**

- ✅ **Migration sequencing — Track B** shipped v1.22.0 (`/ak-go-live § Step
1.6` pre-flight). Tracks A + C remain file-and-forget per
  `kit/ROADMAP.md § Migration sequencing safety nets` — escalate only if
  Track B's data shows the pattern is real and frequent. Track B closes the
  **post-merge prod-cutover race** but does NOT close the **PR-window
  preview race** (see next bullet).
- v1 **PR-preview backend isolation** (backend #3 in the four-backend
  topology: local-dev / CI / preview / prod) — captured at
  `kit/ROADMAP.md § Migration sequencing § Out of scope`. Full-isolation
  solution is a separate staging Supabase project + Vercel preview env
  override + staging-targeted `deploy-migrations.yml` variant. Revisit when a
  2nd project adopts devshop or lalista hits a mutating migration causing
  real reviewer confusion.
- ✅ **CI slow-job lifecycle convention + helper backport to template**
  shipped v1.22.0 (gate `slow-job-lifecycle` + `template/scripts/{ci-type-drift,ci-rollback-explain}.sh`).

**Security (mostly already in flight):**

- ✅ **Security-posture cleanup sweep** — verified 2026-04-29: all 8
  project-side items from `kit/ROADMAP.md § Security-posture cleanup` are
  in place. Both deploy workflows sed-derive ref from `SUPABASE_PROD_URL`
  (no `SUPABASE_PROJECT_REF` references anywhere); CI service-role comes
  from `supabase status -o env` with explicit JWT-decode guard at
  `ci.yml:206` verifying `iss=supabase-demo` + `role=service_role`
  BEFORE any step uses it; `assertNotProdUrlInTestEnv` wired into all 4
  createClient call sites (`packages/core/src/supabase.ts`,
  `apps/web/lib/supabase/server.ts`, `apps/web/lib/supabase/client.ts`,
  `apps/web/middleware.ts`); Anthropic key split QA-vs-PROD; PR 5
  force-create uses table-level RLS instead of admin client. Roadmap
  entry is fully retrospective — nothing left to ship.
- v1 **JIT DB password entry via `/ak-go-live`** — demoted 2026-04-27
  (no incident forcing it; existing GH-Secret flow has shipped successfully).
  Captured at `kit/ROADMAP.md:824` with full implementation plan preserved.

**Operator pain (immediate-impact):**

- ✅ **Browse binary + Playwright availability in project devcontainers** —
  fixed via `kit/scripts/rebuild-browse.sh` + `populate-playwright-cache.sh`
  - structural `cli.ts` fallback (Bun src absent → bundled `server-node.mjs`
    via Node).
- _Deferred indefinitely_ **Devcontainer migration recipe +
  adversarial-review check** — no audience: lalista migrated directly via
  PR 34 (2026-04-28); no other host-docker-socket-bind-mount project exists.
  Captured at `kit/TODOS.md:10` (within the shipped
  `lalista-option3-template-variant` entry) with canonical-reference pointer
  to lalista PR 34 commits (`75a02f6` → `7231cb9` → `3d4ef2d` → `cf71aad`
  → `a76b5f8` → `9cdad4e` → `97eec6b`) for any future project that needs
  the diff.
- ✅ **Bats coverage for the new devcontainer shape** —
  `kit/tests/template-compose-isolation.bats` (structural assertions on the
  compose-isolation template port).

**Reusable conventions:**

- ⏳ **Auth UX conventions** — `@devshop-template/auth-ux`
  (`AwaitingConfirmationCard`, `friendlyAuthError`, `AuthSubmitButton`,
  `AuthErrorDisplay`, `(auth)/layout.tsx` email-context pattern) **plus**
  password-reset sub-pattern (`/auth/callback` recovery handler +
  `/reset-password` + Supabase `site_url` / `uri_allow_list` config + EN-only
  branded email templates).
  **Sequencing inverted vs the prior snapshot:** the original framing was
  "lalista refactors to adopt a future devshop helper." Chapter 1l's source
  line locks the new framing — **ship inline in lalista first → soak with
  real users → extract to devshop later** — to protect against extracting
  half-baked patterns. Devshop extraction now waits on 1l shipping and
  soaking; tracked at `lalista/PRODUCT-ROADMAP.md § v1 § Devshop extraction
of validated UX patterns`.
- ✅ **Runtime Zod validation at LLM / edge-function boundaries** —
  shipped 2026-04-27 in Cluster 1 step 3 (`kit/docs/guide/conventions.md §
Runtime Validation at LLM / Edge-Function Boundaries`); lalista PR 6
  adopted directly.

**Smaller v0 items (`/devshop/kit/TODOS.md`):**

- ✅ **Wrapper-API design rule** — convention + `/ak-test-review`
  deterministic check, shipped v1.22.0.
- ✅ **WS-failure E2E recipe** — Pattern 6 in `supabase-ssr-boilerplate.md`,
  shipped v1.22.0.
- ✅ **PR-body "Manual review" guardrail + Phase 6 auto-attest** — shipped
  v1.22.0 in `/ak-build`.

**Net for v0**: only ⏳ item above remains — the auth UX conventions
package, now sequenced AFTER lalista 1l ships (not before). The project-repo
gates triplet shipped on devshop 2026-04-28 and was adopted project-side
2026-04-29. None gate lalista v0 GA.

---

## Recommended order

The lalista PR queue and devshop work are intertwined: lalista is the
validation surface for several devshop conventions. Optimal ordering uses
that:

**Cluster 1 — unblock PR 6 (shipped 2026-04-27):**

1. ✅ **Browse binary + Playwright fix** — `kit/scripts/rebuild-browse.sh` +
   `populate-playwright-cache.sh` + structural `cli.ts` fallback (Bun src
   absent → use bundled `server-node.mjs` via Node). Lalista workspace
   verified end-to-end against `https://lalista-ten.vercel.app`.
2. ✅ **Devshop interlude** (lalista PLAN row 1, items a/b/c/d) —
   (a) `kit/scripts/preship/rls-coverage-check.sh` + new `rls-coverage` (ak)
   gate in `/ak-pre-ship` SKILL.md (verified caught the simulated PR 5
   Bug #1 gap);
   (b) `## Render conditions` matrix requirement in `/ak-spec` SKILL.md +
   quality-checklist row;
   (c) "input duplicates existing data" standing prompt in
   `/plan-design-review` Pass 1 (SKILL.md + .tmpl);
   (d) **template-side only** — `template/.devcontainer/devcontainer.json`
   swaps `docker-in-docker` feature for host `/var/run/docker.sock`
   bind-mount; Dockerfile installs docker CLI + ships
   `init-docker-socket.sh` for GID alignment; `init-firewall.sh` drops
   `api.supabase.com` + `aws-0-us-west-2.pooler.supabase.com`;
   `supabase-bootstrap.sh up` reports `blocked` (refusing hosted fallback)
   instead of `unavailable`, with bats coverage updated.
   **Adoption gap (surfaced 2026-04-27):** lalista was scaffolded before
   the template change and has not been migrated. `/var/run/docker.sock`
   does not exist in the lalista devcontainer; `supabase start` inside the
   container fails. No `/ak-new-project § Migration` recipe for the
   devcontainer shape exists. Tracked as a follow-up — see
   `lalista/TODOS.md § devcontainer-migrate-to-host-docker-socket`.
3. ✅ **Devshop Zod LLM-boundary convention** —
   `kit/docs/guide/conventions.md § Runtime Validation at LLM / Edge-Function
Boundaries` (when to use, schema-module pattern, wrapper-site
   `.safeParse()` + Sentry-scrubbed payload + typed-error pattern); template
   `packages/core/package.json` adds `zod`; `packages/core/src/schemas/README.md`
   placeholder created; ROADMAP entry marked shipped. Lalista PR 6 adopts
   directly — `lalista/PLAN.md` row 1 (zod-validation) updated to reference
   the convention.

**Cluster 2 — lalista feature flow:**

4. ✅ **chapter 1j (Zod)** — shipped 2026-04-27 (lalista #30 `4ba875f`,
   closer #33 `a7450c9`). Adopted the convention from step 3 directly.
5. ✅ **core-flows CI flake fix** — shipped 2026-04-27 (lalista #31
   `4e78fbd`). `supabase status` health-check + retry-once-on-502 in
   slow-job CI.
6. 🚧 **chapter 1l (auth UX rework)** — in flight on `feat/auth-ux-rework`.
   Ships first because it's already on a branch and gates 1m structurally
   (1m lifts `AuthSubmitButton` → `packages/ui/SubmitButton`).
7. ⏳ **chapter 1k (structured intent parsing)** — adds `entries[]` to the
   response (small Zod schema delta on top of 1j, not a rewrite). Independent
   of 1l; sequenced after to keep LLM-boundary changes diff-reviewable.
8. ⏳ **chapter 1m (app-wide snappiness)** — last because (a) it
   structurally depends on 1l's `AuthSubmitButton` existing as the lift
   source, and (b) it touches AddItemSheet + DisambiguationSheet —
   surfaces 1k may also touch — so doing 1m last avoids redoing snappy
   feedback wiring after 1k changes those surfaces.

**Cluster 3 — launch-day:**

9. **bootstrap-purchase-history-prod** — runs once after first prod account
   exists.

**In parallel** (doesn't block lalista GA, ships from devshop side):

- **Pair**: conventions audit → adversarial reviewer reads guide/ (audit first
  per ROADMAP sequencing note).
  - ✅ **Audit produced** (proposal at
    `kit/notes/roadmap/conventions-audit-redistribution-2026-04-27.md`,
    shipped in v1.22.0): classifies all 23 sections of `conventions.md` as
    Tier 1 / Tier 2 / Tier 3 with target SKILL.md paths and load-bearing
    rule extracts.
  - ✅ **Adversarial reviewer reads guide/** (shipped in v1.22.0): the
    `CONVENTIONS_TO_INCLUDE` map in `kit/scripts/adversarial-review.sh`
    inlines relevant `conventions.md` sections per check-type / gate-name;
    initial 10-route map covers `testCoverage`, `docsReviewed`, and
    `dismissalLog/<gate>` for 7 gates.
  - ✅ **Per-skill redistribution** shipped 2026-04-27 in commit
    `75500e2` (`docs(skills): redistribute conventions into per-skill
    SKILL.md inlines`). Tier 2 inlines added to 7 SKILL.mds:
    `pre-ship`, `implement`, `spec`, `design-conformance`, `go-live`,
    `new-project`, `test-review` (the other 2 of the audit's "9
    affected" — `slow-job-lifecycle` gate + `Wrapper API design`
    check + `Test Assertion Depth` Gate 5 + `new-project § Step 17b`
    Hardening Defaults — were already inlined earlier in v1.22.0, so
    not re-touched). Audit proposal doc deleted in the same commit
    (intent now lives in the actual SKILL.md edits). Tier 1 inlines
    were already present in `/devshop/CLAUDE.md` (Non-Negotiables,
    Confidence Calibration, Principle of Least Privilege, TODO
    Protocol, Closing TODO/ROADMAP entries) and arrive at project
    sessions via the SessionStart hook. The audit's recommendation
    to also duplicate Tier 1 into `/workspace/CLAUDE.md` was
    deliberately rejected — `/devshop/.claude/skills/devshop/new-project/SKILL.md
§ Step 18` codifies the "project CLAUDE.md is project directives
    only" principle; duplicating devshop conventions into project
    CLAUDE.md violates self-sufficiency (the SessionStart hook
    bridges the two layers at runtime, the file does not).
    The only project-side Tier 1 rule — **ON DELETE on auth.users
    FK references** — is in lalista's `/workspace/CLAUDE.md § Gotchas`.
- ✅ **Triplet**: test-presence hook + docs-freshness hook + hierarchical docs
  scaffold — shipped 2026-04-28 on devshop branch
  `feat/project-repo-gates-triplet` (40 new bats cases, all 379 in suite green).
  **Lalista-side adoption shipped 2026-04-29**: `.hooks/pre-commit` already
  symlinks to `/devshop/kit/hooks/pre-commit.sh` (which dispatches the
  project-side scripts via the `/workspace` branch of its case statement) — no
  project-side wiring change was needed. Seeded `.devshop-test-coverage-exempt`
  with 5 entries, each citing transitive coverage:
  `packages/core/src/supabase.types.ts` (generated types — covered by
  `ci-type-drift.sh`), `packages/core/src/errors.ts` (typed-error class,
  covered by `addItem.test.ts` + `reportAddItemValidationError.test.ts`),
  `packages/core/src/schemas/addItem.ts` (Zod schema, covered by
  `addItem.test.ts`), `apps/web/app/(auth)/onboarding/OnboardingForm.tsx`
  (covered by `auth-edge-cases.spec.ts`), and
  `apps/web/app/item/[id]/RemoveEntryButton.tsx` (covered by
  `item-detail.spec.ts § Step 4`). No `.devshop-docs-freshness-exempt`
  needed — current tree has zero false positives on that gate. Verified
  end-to-end via a synthetic ADD: hook BLOCKs unstaged path, exempt entry
  suppresses cleanly. **Devshop follow-up landed same day** on
  `feat/project-repo-gates-triplet`: `is_override` in both project-side
  scripts now strips trailing inline `# reason` comments before exact-match
  (was whole-line comments only — the docstring claimed both); 2 new bats
  cases (`override file accepts trailing inline comment after path`),
  381/381 green; `conventions.md § Test Presence` + `§ Project Docs
Freshness` updated to clarify the supported syntax.
- ✅ **Pair**: CI slow-job lifecycle convention + backport-to-template.
  Shipped in v1.22.0: `kit/docs/guide/conventions.md § Slow-Job Lifecycle`
  documents the Phase 1c/1g threshold + uncommenting checklist; new
  `/ak-pre-ship` gate `slow-job-lifecycle` (gate 2c) at
  `kit/scripts/preship/slow-job-lifecycle-check.sh` enforces it; helpers
  backported to `template/scripts/{ci-type-drift,ci-rollback-explain}.sh`;
  `kit/ROADMAP.md § CI slow job expansion Trigger 1` rewritten to reference
  the now-shipped helpers. Patch v1.22.1 fixed a 403 false-positive in the
  branch-protection sub-check.
- **JIT DB password** — _demoted to v1 on 2026-04-27_; see top-section
  bullet for rationale. No longer in lalista's parallel devshop cluster.
- ✅ **Standalone**: Migration-sequencing Track B. Shipped in v1.22.0 as
  `/ak-go-live § Step 1.6` migration-sequencing pre-flight (catches
  non-additive migrations before the parallel-deploy race window). Tracks A
  - C remain deferred per the original "do B first, escalate only if data
    shows the pattern is real" sequencing note.
- **Standalone**: Auth UX conventions (closes lalista's
  `auth-ux-refactor-to-adopt`).
- ✅ **Smaller**: wrapper-API rule, WS-failure E2E recipe, PR-body
  manual-review guardrail. All three shipped in v1.22.0:
  - **Wrapper API design** convention in `conventions.md` + deterministic
    check in `/ak-test-review` (flags wrappers in `packages/core/src/api/**`
    that call `.subscribe(`/`.on(`/`addEventListener(` without an
    `onError`-shaped param).
  - **Pattern 6** added to `kit/docs/guide/supabase-ssr-boilerplate.md`:
    `page.routeWebSocket(ws => ws.close())` (Playwright 1.48+) instead of
    `page.route().fulfill(503)` for E2E-testing realtime WS failures.
  - **PR-body manual-review guardrail (Layer A)** + **Phase 6 auto-attest
    (Layer B)** in `/ak-build`: defines the canonical Manual review set
    (spec/intent, visual audit, live QA, post-deploy metrics) and
    auto-attests factual checkboxes inline at Phase 6.

**Tangential improvements that shipped in this same session (not on the
original parallel list, but enabled by it)**:

- ✅ **Per-check-type adversarial-review model split** (v1.22.0): Haiku 4.5
  for deterministic checks (`dirtyTreeReason` / `dirtyPushReason` /
  `manifestReviewed`); Sonnet 4.6 for judgment-heavy checks (`docsReviewed`
  / `prDescStaleReason` / `testCoverage` / `dismissalLog` / `hookBypass`).
  `DEVSHOP_ADVERSARIAL_MODEL_OVERRIDE` env var as an operator-facing upgrade
  backdoor — say "use the upgraded adversarial review for this commit" and
  Claude prepends the env var.
- ✅ **Merged `docsVerified` + `docSyncReason` → `docsReviewed`** (v1.22.0):
  one check, one bypass flag, one adversarial call. Per-doc enumeration AND
  cross-file coherence covered in a single review. Closes the ergonomics
  TODO at `kit/TODOS.md:111` that proposed the merge investigation.
- ✅ **Bats coverage for both new preship gates** (v1.22.0): 32 new tests
  across `preship-rls-coverage.bats` (19 tests) and
  `preship-slow-job-lifecycle.bats` (13 + 5 added in v1.22.1 patch =
  18 tests). Closed the test-coverage debt the release-coverage
  adversarial review surfaced when v1.22.0 was first attempted.
- ✅ **Bun test for `gstack/browse/src/cli.ts` server-resolution path** —
  shipped at `.claude/skills/gstack/browse/test/cli.test.ts` (11 tests across
  three describe blocks: `resolveServerScript` covers the null-when-src-absent
  branch + dev-mode path resolution + execPath-adjacent resolution;
  `resolveNodeServerScript` covers the bundled `server-node.mjs` lookup;
  `USE_NODE_SERVER launch-path flip` is a contract test for the
  `IS_WINDOWS || !SERVER_SCRIPT` formula). `kit/TODOS.md` entry can be
  closed.

**Why this order:**

- Cluster 1 was high-leverage: the interlude paid back in 1j's spec quality
  AND validated 4 devshop conventions on the same ship.
- 1j → 1k sequencing keeps the LLM-boundary changes diff-reviewable;
  1k's `entries[]` is a small Zod-schema extension on top of 1j.
- **1l → 1k → 1m within Cluster 2** — 1l is already in flight; 1m
  structurally depends on 1l (lift source); 1k slots between because it's
  independent of both, and putting 1m last lets it polish 1k's new
  compound-add UX surfaces in one pass instead of touching them twice.
- **Auth UX devshop extraction now waits on 1l soaking in prod** — flipped
  from the prior "lalista adopts a devshop helper" framing per chapter 1l's
  ship-inline-→-soak-→-extract sequencing rule.
- **Lalista devcontainer migration is project-side first, devshop recipe
  second** — same pattern as the 2026-04-25 credential-layout migration
  recipe. Doing it on a real project produces the empirical diff that
  becomes the recipe's content; writing the recipe first risks aspirational
  steps that don't match what's actually needed. Sequencing: lalista
  migrates → diff captured → `/ak-new-project § Migration: existing project
to host-docker-socket devcontainer` written → adversarial check + bats
  coverage as parallel cleanup.
- The parallel devshop cluster is "fixes a gap every future project hits" —
  value scales with project count. Within it, prioritize the bundles that
  unblock the next-project onboarding (auth UX + docs scaffold + freshness
  hook) over deeper convention work (audit → reviewer).
- Security-posture cleanup is largely retrospective at this point — JIT DB
  password (now v1) is the only meaningful remaining structural step, and
  it shouldn't gate lalista GA.
