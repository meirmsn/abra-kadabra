# Lalista launch — pending v0 work, both sides

Snapshot 2026-04-28. Synthesizes `lalista/PLAN.md` + `lalista/PRODUCT-ROADMAP.md` +
`lalista/TODOS.md` and `/devshop/kit/ROADMAP.md` + `/devshop/kit/TODOS.md` into a
single picture of what's left for lalista v0 GA, what devshop v0 work is in
flight, and the order that minimizes wasted motion.

---

## Lalista v0 — pending

**Forward features** (`PLAN.md` rows 1–3):

- **Interlude: devshop-preship-hardening** — no lalista PR; devshop work that
  lands before PR 6 so subsequent feature PRs benefit. Four parts:
  (a) RLS-coverage pre-ship gate, (b) `/ak-spec` render-condition matrix for
  new UI elements, (c) `/plan-design-review` "input duplicates existing data"
  prompt, (d) dev-side prod-Supabase isolation. After exploring the
  host-`/var/run/docker.sock`-bind-mount path (Option 2) we shipped Option 3
  compose isolation instead: workspace dev container has NO docker socket,
  sibling `supabase-runner` compose service holds the socket and runs
  `supabase start` against the host engine, narrow `<host>/supabase` bind on
  the runner, RPC relay on :9000 for orchestration commands, host-path-
  mirrored bind so spawned function-runtime sees the same path inside and
  outside the runner. Refuses hosted fallback; strips prod hosts from
  firewall; drops `SUPABASE_SERVICE_ROLE_KEY` from `.devcontainer/.env`.
  Architecture doc: `kit/docs/guide/local-supabase-compose-isolation.md`;
  threat-model: `kit/notes/security/local-supabase-isolation-options.md`.
- **PR 6: zod-validation** — runtime validation of `AddItemResponse` at
  `invokeAddItem` (the one genuinely unchecked seam). `.safeParse()` + Sentry
  on failure, `.passthrough()` on objects. ~2–3 hrs.
- **PR 7: structured-intent-parsing** — replace Claude's translator-only role
  in `add-item` with structured extraction (compound adds, quantity/unit,
  brand, store hints). Response grows `entries[]` for N-row optimistic
  inserts. `per-household-items-catalog` no longer a hard dep for
  single-household v0.

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
**Remaining for GA = PR 7, then the launch-day seed.** (PR 6 shipped
2026-04-27; core-flows CI flake fix shipped same day.)

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

- ⏳ **Pre-commit test-presence hook** — block new `src/*.ts` without paired
  `.test.ts`; exempt-list file; adversarial reviewer for modify cases.
- ⏳ **Project-repo docs-freshness hook + adversarial reviewer** — sibling on
  the docs side: new `page.tsx` / API wrapper / `posthog.capture` requires
  `CLAUDE.md` / `METRICS.md` update in the same diff.
- ⏳ **Hierarchical docs scaffold in template** — template ships `CLAUDE.md`
  / `TODOS.md` / `METRICS.md` skeletons (explicitly paired with the freshness
  hook). Ship the triplet together so one lalista commit cycle flushes
  false-positive exempt lists for all three.

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

- ⏳ **Security-posture cleanup sweep** — Anthropic split + URL guard
  already shipped (commits #28, #18); ROADMAP entry largely retrospective.
  Worth a sweep to confirm any residual items.
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
  (`AwaitingConfirmationCard`, `friendlyAuthError`) **plus** password-reset
  sub-pattern (`PasswordResetCard` + `/auth/callback` + `/reset-password` +
  Supabase `site_url` / `uri_allow_list` config). Closes lalista's
  `auth-ux-refactor-to-adopt` debt.
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

**Net for v0**: only ⏳ items above remain — the project-repo gates triplet,
the security-posture sweep, and the auth UX conventions package. None gate
lalista v0 GA.

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

4. ✅ **PR 6 (Zod)** — shipped 2026-04-27 (lalista #30 `4ba875f`, closer #33
   `a7450c9`). Adopted the convention from step 3 directly.
5. **PR 7 (structured intent parsing)** — adds `entries[]` to the response
   (small Zod schema delta on top of PR 6, not a rewrite). Sequencing 6→7
   keeps the response-shape change cleanly diff-able; bundling would make a
   wide-blast-radius single PR.
6. ✅ **core-flows CI flake fix** — shipped 2026-04-27 (lalista #31
   `4e78fbd`). `supabase status` health-check + retry-once-on-502 in
   slow-job CI; rode alongside PR 6 as planned.

**Cluster 3 — launch-day:**

7. **bootstrap-purchase-history-prod** — runs once after first prod account
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
- **Triplet**: test-presence hook + docs-freshness hook + hierarchical docs
  scaffold — ship together so one lalista commit cycle flushes false-positive
  exempt lists for all three.
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

- Cluster 1 is high-leverage: the interlude pays back in PR 6's spec quality
  AND validates 4 devshop conventions on the same ship.
- PR 6 → PR 7 sequencing keeps the LLM-boundary changes diff-reviewable;
  PR 7's `entries[]` is a 5-line schema extension if PR 6 lands first.
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
