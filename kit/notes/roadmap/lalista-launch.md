# Lalista launch — pending v0 work, both sides

Snapshot 2026-04-27. Synthesizes `lalista/PLAN.md` + `lalista/PRODUCT-ROADMAP.md` +
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
  prompt, (d) dev-side prod-Supabase isolation (DiD bind-mount, refuse hosted
  fallback, strip prod hosts from firewall, drop `SUPABASE_SERVICE_ROLE_KEY`
  from `.devcontainer/.env`).
- **PR 6: zod-validation** — runtime validation of `AddItemResponse` at
  `invokeAddItem` (the one genuinely unchecked seam). `.safeParse()` + Sentry
  on failure, `.passthrough()` on objects. ~2–3 hrs.
- **PR 7: structured-intent-parsing** — replace Claude's translator-only role
  in `add-item` with structured extraction (compound adds, quantity/unit,
  brand, store hints). Response grows `entries[]` for N-row optimistic
  inserts. `per-household-items-catalog` no longer a hard dep for
  single-household v0.

**Pre-ship** (`TODOS.md § v0 § pre-ship`):

- **core-flows-happy-path-ci-investigation** — flaky-on-edge-runtime-startup,
  NOT test-side broken. Long-term fix: `supabase status` health-check +
  retry-once-on-502 in slow-job CI.

**Launch-day** (`TODOS.md § v0 § launch-day`):

- **bootstrap-purchase-history-prod** — run the prepared `do $$ ... $$` block
  once after first prod account creation, so `route_item_to_store` has signal
  from day one.

**v0 GA checkpoint** (PRODUCT-ROADMAP.md): every functional gate checked off
(auth, add/list/bought, realtime, dark mode, errors, CI, Sentry, PostHog).
**Remaining for GA = PR 6 + PR 7, then the launch-day seed.**

---

## Devshop v0 — pending (`/devshop/kit/ROADMAP.md` + `/devshop/kit/TODOS.md`)

**Convention enforcement (paired):**

- **Audit `conventions.md` → distribute operational copy into skills** —
  Tier 3 rules don't fire; move into Tier 1 (CLAUDE.md) / Tier 2 (SKILL.md).
- **Adversarial reviewer reads `guide/` for convention checks** — depends on
  audit; inlines relevant guide sections so the reviewer flags violations at
  commit time.

**Project-repo gates (cluster, pair-ship):**

- **Pre-commit test-presence hook** — block new `src/*.ts` without paired
  `.test.ts`; exempt-list file; adversarial reviewer for modify cases.
- **Project-repo docs-freshness hook + adversarial reviewer** — sibling on the
  docs side: new `page.tsx` / API wrapper / `posthog.capture` requires
  `CLAUDE.md` / `METRICS.md` update in the same diff.
- **Hierarchical docs scaffold in template** — template ships `CLAUDE.md` /
  `TODOS.md` / `METRICS.md` skeletons (explicitly paired with the freshness
  hook).

**Migration / CI hygiene:**

- **Migration sequencing safety nets for the Vercel-preview window** — Track B
  (`/ak-go-live` Step 1.6 pre-flight) is highest leverage; A + C deferred
  until B's data justifies them.
- **CI slow-job lifecycle convention** — pre-ship gate enforces "uncomment
  slow-job + update branch protection" at Phase 1c/1g threshold; codifies the
  lalista PR-26 edge-runtime retry pattern.
- **Backport lalista's CI slow-job + helpers** (`ci-type-drift.sh`,
  `ci-rollback-explain.sh`) **to the template.**

**Security (mostly already in flight):**

- **Security-posture cleanup** — Tracks A–F (eliminate `SUPABASE_PROJECT_REF`,
  reclassify public values to Variables, URL guard, blast-radius docs).
  Anthropic split + URL guard already shipped (commits #28, #18); ROADMAP
  entry is largely retrospective. Worth a sweep to confirm any residual items.
- **JIT DB password entry via `/ak-go-live`** — structural follow-on: delete
  `deploy-migrations.yml`, operator-side JIT password fetch via
  password-manager CLI or `!`-prefix shell escape.

**Operator pain (immediate-impact):**

- **Browse binary + Playwright availability in project devcontainers** — fix
  stale browse binary + Chromium-env-var fallback so `/qa-only`,
  `/design-review`, `/canary`, `/benchmark` actually work on lalista
  (currently broken since 2026-04-26).

**Reusable conventions:**

- **Auth UX conventions** — `@devshop-template/auth-ux`
  (`AwaitingConfirmationCard`, `friendlyAuthError`) **plus** password-reset
  sub-pattern (`PasswordResetCard` + `/auth/callback` + `/reset-password` +
  Supabase `site_url` / `uri_allow_list` config). Closes lalista's
  `auth-ux-refactor-to-adopt` debt.
- **Runtime Zod validation at LLM / edge-function boundaries** — companion to
  lalista PR 6. If devshop ships first, PR 6 adopts directly; otherwise
  lalista ships inline and refactors later.

**Smaller v0 items in `/devshop/kit/TODOS.md`:**

- **Wrapper-API design rule** — convention + `/ak-test-review` deterministic
  check (motivated by lalista PR 27's realtime `onError` gap).
- **WS-failure E2E recipe** — Pattern 6 in `supabase-ssr-boilerplate.md` (use
  `page.routeWebSocket(... ws.close())`, not `route.fulfill(503)`).
- **PR-body "Manual review" guardrail + Phase 6 auto-attest** — keep
  manual-review section judgmental-only; `/ak-build` Phase 6 auto-verifies
  factual items.

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
   (d) template `.devcontainer/devcontainer.json` swaps `docker-in-docker`
   feature for host `/var/run/docker.sock` bind-mount; Dockerfile installs
   docker CLI + ships `init-docker-socket.sh` for GID alignment;
   `init-firewall.sh` drops `api.supabase.com` +
   `aws-0-us-west-2.pooler.supabase.com`; `supabase-bootstrap.sh up`
   reports `blocked` (refusing hosted fallback) instead of `unavailable`,
   with bats coverage updated.
3. ✅ **Devshop Zod LLM-boundary convention** —
   `kit/docs/guide/conventions.md § Runtime Validation at LLM / Edge-Function
Boundaries` (when to use, schema-module pattern, wrapper-site
   `.safeParse()` + Sentry-scrubbed payload + typed-error pattern); template
   `packages/core/package.json` adds `zod`; `packages/core/src/schemas/README.md`
   placeholder created; ROADMAP entry marked shipped. Lalista PR 6 adopts
   directly — `lalista/PLAN.md` row 1 (zod-validation) updated to reference
   the convention.

**Cluster 2 — lalista feature flow:**

4. **PR 6 (Zod)** — adopts the convention from step 3.
5. **PR 7 (structured intent parsing)** — adds `entries[]` to the response
   (small Zod schema delta on top of PR 6, not a rewrite). Sequencing 6→7
   keeps the response-shape change cleanly diff-able; bundling would make a
   wide-blast-radius single PR.
6. **core-flows CI flake fix** — ship anytime, ride alongside PR 6 or PR 7.
   Cheap.

**Cluster 3 — launch-day:**

7. **bootstrap-purchase-history-prod** — runs once after first prod account
   exists.

**In parallel** (doesn't block lalista GA, ships from devshop side):

- **Pair**: conventions audit → adversarial reviewer reads guide/ (audit first
  per ROADMAP sequencing note).
- **Triplet**: test-presence hook + docs-freshness hook + hierarchical docs
  scaffold — ship together so one lalista commit cycle flushes false-positive
  exempt lists for all three.
- **Pair**: CI slow-job lifecycle convention + backport-to-template.
- **JIT DB password** — follow-on to the now-shipped security-posture
  cleanup; lalista is mid-rollout so docs cascade lands once.
- **Standalone**: Migration-sequencing Track B (single SKILL.md edit; A + C
  only if Track B's data shows the pattern is real).
- **Standalone**: Auth UX conventions (closes lalista's
  `auth-ux-refactor-to-adopt`).
- **Smaller**: wrapper-API rule, WS-failure E2E recipe, PR-body manual-review
  guardrail.

**Why this order:**

- Cluster 1 is high-leverage: the interlude pays back in PR 6's spec quality
  AND validates 4 devshop conventions on the same ship.
- PR 6 → PR 7 sequencing keeps the LLM-boundary changes diff-reviewable;
  PR 7's `entries[]` is a 5-line schema extension if PR 6 lands first.
- The parallel devshop cluster is "fixes a gap every future project hits" —
  value scales with project count. Within it, prioritize the bundles that
  unblock the next-project onboarding (auth UX + docs scaffold + freshness
  hook) over deeper convention work (audit → reviewer).
- Security-posture cleanup is largely retrospective at this point — JIT DB
  password is the only meaningful remaining structural step, and it shouldn't
  gate lalista GA.
