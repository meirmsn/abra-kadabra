# Devshop Roadmap

Devshop capabilities to build eventually — how you build, not what you ship.
Tactical fixes go in `TODOS.md`. Project features go in root `PRODUCT-ROADMAP.md`.

Priority tiers:

- **v0** — fixes the current template needs before a second project adopts it. Each exists because the first template-validation project (lalista) surfaced a gap every future project will hit. Factoring up now avoids each project re-inventing the wheel.
- **v1** — devshop capabilities that would be valuable but aren't blocking next-project onboarding.
- **v+** — future, when the need is felt.

---

## v0 — blocks next-project adoption

### CI artifact-host firewall allowlist

The devcontainer's `init-firewall.sh` allowlists `vscode.blob.core.windows.net` (for VS Code updates) but NOT `*.blob.core.windows.net` (where GitHub Actions stores workflow artifacts — trace zips, screenshot PNGs, test reports). Every `gh run download` attempt from inside the devcontainer fails with `no route to host`, which means Claude cannot pull Playwright traces, jest coverage reports, or any CI-generated artifact for offline inspection.

Lalista surfaced this during PR 4's slow-job stabilization (2026-04-24): Playwright E2E failed with a test-side bug the CI log didn't contain enough context to diagnose. The trace artifact would have shown the page DOM + network logs + screenshots at the assertion moment — a 30-second inspection would have replaced the 3-round guess-and-check loop that burned ~30 minutes of CI time.

**Shape of the fix:**

- Add `*.blob.core.windows.net` (or more narrowly: `productionresultssa*.blob.core.windows.net`, which is Microsoft's Azure storage pattern for GH-hosted runners — currently `productionresultssa9`, `productionresultssa10`, etc. rotate per-region) to `.devcontainer/init-firewall.sh`'s allowlist.
- Narrower preferred (smaller attack surface): grep the CI run's artifact URLs for the exact domain, use a wildcard-bounded regex.
- The allowlist is GH-Actions-generic — every devshop project that uses GH Actions will need this.

**Why v0 — blocks next-project adoption:**

Without trace access, `/ak-build` Phase 5's fix loop is guess-based. First-time CI failures for any new project will hit the same blind-debugging trap. Adding the domain is a one-line change + devcontainer rebuild; every project benefits.

**Trigger:**

- Lalista completes PR 4 investigation — that happens when trace pull works. Block until fixed (as of 2026-04-24 blocked).
- Second project's first CI failure.

**Cross-ref:**

- `lalista/TODOS.md § v0 § Pre-ship § core-flows-happy-path-ci-investigation` — the immediate beneficiary of this fix
- `kit/ROADMAP.md § v0 § /ak-build Phase 5 trace-pull-on-second-failure` — the convention this fix unblocks
- `lalista/.devcontainer/init-firewall.sh` lines 77-105 — existing allowlist structure for guidance

---

### /ak-build Phase 5 — trace-pull-on-second-failure convention

`/ak-build` Phase 5's CI fix loop currently guesses from `gh run view --log-failed` output. This worked for straightforward failures (YAML typo, missing dep, env-var format) but fails for anything requiring UI / runtime observability (Playwright failures, hidden page state, race conditions).

The 2026-04-24 lalista session burned ~30 minutes + 6 CI roundtrips trying to fix a single Playwright test because each attempt guessed from the log without access to the Playwright trace. The trace would have definitively shown what the page looked like at the assertion — turning a 30-minute guess-loop into a 30-second diagnosis.

**Shape of the convention:**

Amend `/ak-build` Phase 5.4 (CI failure → fix loop) to the following rhythm:

1. **Failure #1**: pull `--log-failed`, guess based on error context. Fix + push. Cost: 1 CI round (~5 min). This is the "same as today" path — often the failure is straightforward and the log is enough.
2. **Failure #2** (same or related test): before attempting another fix, run:
   ```bash
   RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
   # Pull every failure artifact (Playwright report, uploaded screenshots, coverage, etc.)
   for art in $(gh api "/repos/OWNER/REPO/actions/runs/$RUN_ID/artifacts" --jq '.artifacts[].name'); do
     gh run download "$RUN_ID" --name "$art" --dir "/tmp/ci-artifacts/$RUN_ID/"
   done
   ```
   Inspect `error-context.md` files (human-readable Playwright assertion context), PNG screenshots, and `trace.zip` (via `playwright show-trace` or unzipping for DOM snapshots). Diagnosis is now observability-driven, not log-driven.
3. **Failure #3+** (if still unresolved after trace inspection): escalate to user — something structural is wrong; pattern-matching isn't enough.

**Prerequisites:**

- CI artifact-host firewall allowlist (above) — without it step #2's `gh run download` fails.
- Playwright workflow must upload `playwright-report/` on failure (lalista already does — `actions/upload-artifact@v4` with `if: failure()`).
- `playwright show-trace` requires a local Playwright install + X11/web-ui; the fallback of reading `error-context.md` + PNG screenshots + zipped DOM snapshots works without it.

**Why v0 — blocks next-project adoption:**

The "blind guess" loop is the #1 time sink in `/ak-build` today. Every project using slow-job Playwright will hit the same trap. Documenting the convention + wiring the skill to follow it turns "I got lucky / unlucky" into "investigation was bounded at 2 rounds."

**Shape of the skill amendment:**

`kit/skills/ak-build/SKILL.md` Phase 5.4 block grows a decision tree:

```
- Attempt 1 fix: infer from `gh run view --log-failed`. One-shot.
- Attempt 2 fix: before guessing, `gh run download` all artifacts to
  `/tmp/ci-artifacts/<RUN_ID>/`. Inspect `error-context.md` per failed test,
  PNG screenshots, and (if available) unzipped trace.zip for DOM snapshots +
  network logs. THEN fix.
- Attempt 3 fix: if artifacts didn't resolve it, escalate to user.
```

**Trigger:**

- CI firewall allowlist ships (prereq).
- Then: amend the skill in one commit.

**Cross-ref:**

- `lalista/TODOS.md § v0 § Pre-ship § core-flows-happy-path-ci-investigation` — the 2026-04-24 case study that motivated this
- `kit/ROADMAP.md § v0 § CI artifact-host firewall allowlist` — the prereq
- `kit/skills/ak-build/SKILL.md § Phase 5` — target for the amendment

**Cost/risk:**

- Implementation: ~30 min (script changes to SKILL.md) + testing on one deliberate CI-failure reproduction
- Risk: artifact downloads eat CI-minutes billing trivially (MB not GB); no security-surface change assuming allowlist is narrow
- Benefit: substantially shorter debug loops on E2E / UI-heavy failures

---

### Security-posture cleanup: CI/prod credential separation + URL guard + classification

Audit of `/ak-new-project`'s credential surface (2026-04-25, after the auto-deploy-backend ship) surfaced four issues that compound:

1. **Real duplication**: `SUPABASE_PROJECT_REF` is the subdomain slice of `SUPABASE_URL` (the URL is `https://<ref>.supabase.co`). We added it as a GH Variable when the deploy workflows landed; it can be derived inline. Single source of truth = `SUPABASE_URL`. Eliminate the Variable.

2. **Public values stored as Secrets**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NEXT_PUBLIC_POSTHOG_KEY` are public by design — baked into the front-end JS bundle, visible to every browser. Storing as GH Secrets is symmetric with the rest but technically a misclassification. Doesn't leak (Secrets and Variables share the same UI) but confuses readers about what's actually sensitive. Move to Variables.

3. **Real security risk: `SUPABASE_SERVICE_ROLE_KEY` ambiguity**. The skill says `SUPABASE_SERVICE_ROLE_KEY=<secret-key>` without specifying which project. A reader will paste their **prod** service-role key — full DB admin access via REST, no RLS. If it leaks (CI logs, container image, misconfigured workflow), prod is **totally compromised**. Lalista's PR 18 D8 + D22 already worked around this (CI's `SUPABASE_URL` rotated to local stack `http://127.0.0.1:54321`; CI's service-role key is the local stack's published default JWT, not sensitive); plus a runtime URL guard `assertNotProdUrlInTestEnv` that throws if test-env code ever instantiates a Supabase client pointing at prod. The template + skill need to ship this discipline by default.

4. **Documentation gaps**: each credential has "where to find it" but no blast-radius callout, no CI-vs-prod separation guidance, no rotation cadence, no explanation of why some are stored as Secrets vs Variables.

**Shape of the fix** (5 tracks; do them as one coordinated change because they cross-reference each other):

**Track A — Eliminate `SUPABASE_PROJECT_REF`**:

- `template/.github/workflows/deploy-migrations.yml` + `deploy-functions.yml`: replace `--project-ref ${{ vars.SUPABASE_PROJECT_REF }}` with a sed-derive from `SUPABASE_PROD_URL`:
  ```bash
  PROJECT_REF=$(echo "$SUPABASE_PROD_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
  supabase link --project-ref "$PROJECT_REF"
  ```
- `/ak-new-project` Step 5 Variables: drop `SUPABASE_PROJECT_REF`; add `SUPABASE_PROD_URL` instead (this is the prod URL the deploy workflows target — distinct from CI's `SUPABASE_URL` which points at local stack).
- Lalista mirrors the same change (its workflows also derive ref from `SUPABASE_PROD_URL`).

**Track B — Reclassify public values + add CI-vs-prod naming distinction**:

- `/ak-new-project` Step 5 reorganized:
  - **Variables tab** (public):
    - `SUPABASE_URL` = local stack URL `http://127.0.0.1:54321` (used by CI fast/slow jobs against `supabase start`)
    - `SUPABASE_ANON_KEY` = local stack's published default anon JWT
    - `SUPABASE_SERVICE_ROLE_KEY` = local stack's published default service-role JWT (still admin, but on a sandboxed local instance — not prod)
    - `SUPABASE_PROD_URL` = real prod URL (used by deploy-migrations + deploy-functions only)
    - `NEXT_PUBLIC_POSTHOG_KEY` = PostHog key (public via NEXT*PUBLIC* convention)
  - **Secrets tab** (genuinely sensitive):
    - `SUPABASE_DB_PASSWORD` = prod DB password (used by deploy-migrations)
    - `SUPABASE_ACCESS_TOKEN` = account-wide Supabase token (used by both deploy workflows)
    - `ANTHROPIC_API_KEY` = if edge functions call Claude (used by slow-job)
    - `SENTRY_DSN` + `SENTRY_AUTH_TOKEN`
    - `VERCEL_TOKEN`
- Vercel env (separate surface from GH) keeps prod values: `NEXT_PUBLIC_SUPABASE_URL` = prod, `NEXT_PUBLIC_SUPABASE_ANON_KEY` = prod anon. Skill should explicitly note Vercel and GH are different env surfaces with different values.

**Track C — Local-stack defaults documented in skill**:

- `/ak-new-project` Step 5 Variables sub-section gains the **literal values** for local-stack defaults:
  - `SUPABASE_URL` value: `http://127.0.0.1:54321`
  - `SUPABASE_ANON_KEY` value: the published JWT (currently `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9...` — implementer should source the current published value from `supabase start` output or Supabase docs)
  - `SUPABASE_SERVICE_ROLE_KEY` value: same shape, role: service_role
- Note that these are public hardcoded values across every Supabase local-stack install, so no per-project copying from `.env` is needed for these three.

**Track D — Ship the URL guard helper in the template**:

- New file `template/packages/core/src/supabase.ts` (or similar — match the template's existing structure) exporting `assertNotProdUrlInTestEnv` per lalista's PR 18 D22 implementation.
- Helper logic: when `process.env.NODE_ENV === 'test'` AND the URL passed to `createClient` matches a prod-shaped pattern (`*.supabase.co` and NOT the configured project's CI-allowed values), throw with a clear message.
- Tests for the helper (mirror lalista's 5 unit tests in `packages/core/src/supabase.test.ts`).
- Wire into the template's `createClient` call sites so it fires on every client instantiation in test env.

**Track E — Add § Security Posture to `/ak-new-project`**:

New section after Step 5 (or as part of Step 5) with:

- **Blast-radius table** per credential — what an attacker can do if it leaks:

  | Credential                                    | Blast radius if leaked                                                                                       |
  | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
  | `SUPABASE_DB_PASSWORD`                        | Direct DB connection (no RLS); read/write any table                                                          |
  | `SUPABASE_ACCESS_TOKEN`                       | Account-wide: all projects on this Supabase account, manage settings, drop projects                          |
  | `ANTHROPIC_API_KEY`                           | Spend rate-limit until rotated                                                                               |
  | `SENTRY_AUTH_TOKEN`                           | Upload sourcemaps, manage org                                                                                |
  | `VERCEL_TOKEN`                                | Deploy to any of your Vercel projects                                                                        |
  | `SUPABASE_SERVICE_ROLE_KEY` (prod, NOT in CI) | Full DB admin via REST; no RLS — if it gets in CI accidentally, that's the highest-blast-radius failure mode |
  | Local-stack defaults (Variables)              | None — published constants                                                                                   |

- **CI-vs-prod credential separation** — explicit rule: CI never holds prod Supabase credentials except `SUPABASE_PROD_URL` (used only by deploy workflows), `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`. Everything else CI uses is the local-stack default.

- **Rotation cadence**: rotate `SUPABASE_ACCESS_TOKEN` quarterly (account-wide blast radius); `SUPABASE_DB_PASSWORD` after any team-member departure or suspected compromise; sourcemaps tokens annually.

- **URL guard reminder**: the structural defense (assertNotProdUrlInTestEnv) is in the template by default — Track D — and projects should keep it active.

**Track F — Cleanup step in `/ak-new-project` for upgrading existing projects**:

For projects that already went through the OLD `/ak-new-project` flow (lalista is one), add a "Migration to new credential layout" step OR a one-off cleanup section in the skill:

- List of GH Secrets to delete that no longer apply (e.g., legacy `SUPABASE_PROJECT_REF` Variable if previously set)
- List of values to add (e.g., `SUPABASE_PROD_URL` Variable if not present)
- List of Secrets to convert to Variables
- Rotation prompt for any potentially-mixed credentials

This step is `[HUMAN]` — Claude can list what to do but can't manage GH Secrets via the devcontainer PAT.

**Doc propagation** (after Tracks A–E land):

- `OVERVIEW.md` — workspace-layout file map gains the URL guard helper file at `packages/core/src/supabase.ts` (already there for lalista; needs template parity)
- `kit/docs/guide/conventions.md` — § Deploy Boundaries already updated for auto-deploy; gains a callout about CI-vs-prod credential separation as the structural enforcement of the boundary
- `kit/docs/guide/security.md` — gains a § "CI credential isolation" subsection summarizing the URL guard + local-stack-defaults pattern
- `kit/docs/guide/ops.md` § CI/CD — already updated; verify the prod-URL-vs-local-URL distinction is noted
- `CLAUDE.md` § Known Footguns — gains an entry about the prod-service-role-in-CI risk + URL guard remediation

**Project-side changes (lalista — first adopter)**:

After the devshop side lands on a feature branch (NOT ff-merged yet — per the new "hold ff-merge until project validates" convention from CLAUDE.md § Devshop shipping flow):

1. **Workflow files**: update `.github/workflows/deploy-migrations.yml` + `deploy-functions.yml` to derive ref from `SUPABASE_PROD_URL` instead of `vars.SUPABASE_PROJECT_REF`. Drop the `SUPABASE_PROJECT_REF` Variable.
2. **GH Variables additions**:
   - Add `SUPABASE_PROD_URL` = `https://nzfdfjctpotjyuxdfcpw.supabase.co`
3. **GH Secrets → Variables migrations** (delete from Secrets after confirming Variables tab has them):
   - `SUPABASE_URL` (value already = local stack URL per D8) → Variables
   - `SUPABASE_ANON_KEY` (value already = local stack default) → Variables
   - `SUPABASE_SERVICE_ROLE_KEY` (value already = local stack default) → Variables
   - `NEXT_PUBLIC_POSTHOG_KEY` → Variables
4. **GH Secrets to keep as Secrets**: `SUPABASE_DB_PASSWORD`, `SUPABASE_ACCESS_TOKEN`, `ANTHROPIC_API_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `VERCEL_TOKEN`.
5. **GH Variable to delete**: `SUPABASE_PROJECT_REF` (added today; superseded by `SUPABASE_PROD_URL` + sed-derive).
6. **URL guard already present**: lalista already has D22's `assertNotProdUrlInTestEnv` in `packages/core/src/supabase.ts` — verify it's wired into all `createClient` call sites.
7. **CI verification**: re-run slow-job CI on `feat/auto-deploy-backend` to confirm both deploy workflows still run green after the parameterization change.
8. **Once CI green on lalista, ff-merge devshop-side feature branch to devshop main**.

**Why v0**:

- Track A: trivial debt that compounds with every future project — fix while it's fresh.
- Track B–E: closes a real security gap. The prod-service-role-in-CI footgun is the highest-blast-radius failure mode in the current `/ak-new-project` flow. Every project scaffolded today has it; fixing now means the second project starts in the secure-by-default state.
- Track F: existing projects need a migration path; without it, the cleanup is ambiguous.

**Trigger**:

- Lalista PR 18 retro (2026-04-25) surfaced the audit — concrete case study + first adopter ready.
- Coordinated devshop+project change: implement on devshop feature branch, validate on lalista, ff-merge devshop after lalista CI green (per the convention from CLAUDE.md § Devshop shipping flow step 2 added 2026-04-25).

**Cross-ref**:

- Lalista PR 18 D8 (CI URL/anon rotation to local stack) — already shipped, this entry generalizes the pattern to template
- Lalista PR 18 D22 (`assertNotProdUrlInTestEnv` URL guard) — already shipped, this entry generalizes to template
- `kit/docs/guide/conventions.md` § Deploy Boundaries — context for the parallel-deploy model
- `kit/ROADMAP.md` § "Pre-commit test-presence hook (project repo)" below — sibling project-repo convention propagation

**Cost/risk**:

- Implementation: ~3-4 focused hours (template helper + tests, skill rewrite of Step 4/5, doc propagation across 5+ files, lalista mirror, CI re-run + verification). Adversarial review will require 2-3 doc enumeration cycles per commit; budget for that.
- Risk during rollout: lalista's deploy workflows briefly need `SUPABASE_PROD_URL` Variable BEFORE the workflow file change merges (or the parameter substitution will fail). Set the Variable first; merge second. Same for any future project adopting from template.
- Benefit: closes the prod-service-role-in-CI risk by default; eliminates the `SUPABASE_PROJECT_REF` redundancy; documents what's actually sensitive vs symmetric-but-public; provides migration recipe for existing projects.

---

### Pre-commit test-presence hook (project repo)

Today `check-test-coverage.sh` runs only in the devshop repo itself — it flags `kit/scripts/*.sh` additions/modifications that lack a `.bats` test. Project repos (lalista, every future project) have no equivalent: new `.ts`/`.tsx` files under `apps/*/src/` + `packages/*/src/` can land without a paired `.test.ts` and the pre-commit gate says nothing. `/ak-test-review` catches this at ship time (late — feature already built), and adversarial reviewers can't enforce test _existence_ because no machine-readable invariant exists.

Lalista surfaced the gap post-PR-4 when surveying what CI actually protects: every E2E / integration gate runs only in slow-job CI, unit-test coverage is not machine-enforced at all, and test deletion during refactor is invisible until coverage numbers drift down — which nobody watches.

**Shape of the convention:**

- **New script**: `kit/scripts/commit-hooks/check-test-coverage-project.sh` — mirrors the existing devshop-self version but scoped to project-repo paths:
  - Walks staged `.ts`/`.tsx` files under `apps/*/src/`, `apps/*/app/`, `apps/*/components/`, `apps/*/lib/`, `packages/*/src/`
  - For each, requires an adjacent `.test.ts` / `.test.tsx` / `.integration.test.ts`
  - New file without a test → BLOCK. Modified without a test → WARN (same tiering as the devshop script).
  - Exempt list (conservative, project-tunable): barrel `index.ts`, `*.d.ts`, `*.config.ts`, `page.tsx` / `layout.tsx` (route entry points — unit-testing server components is fraught; E2E covers those), `middleware.ts` (covered by `middleware.test.ts` but flagging needed once), anything under `*/e2e/` or `*/tests/`, any file whose sibling dir contains a `*.integration.test.ts` or `*.spec.ts` that references the filename.
  - Per-project override: `.devshop-test-coverage-exempt` file at repo root, one path per line, commit-auditable.

- **Wire into `.hooks/pre-commit`**: in the project-repo branch, add `bash "$SCRIPTS_DIR/commit-hooks/check-test-coverage-project.sh"` after `check-security-files-freshness.sh`.

- **Convention doc** in `guide/conventions.md § Test Presence`: explain what's blocked vs. warned, how to add to the exempt list (with a commit message explaining why), and the relationship to `/ak-test-review` (hook catches "I forgot entirely"; review catches "this test is weak").

- **`.bats` tests** in `kit/tests/` for the script: fixtures cover (a) new file without test → block, (b) new file with adjacent test → pass, (c) modified file without test → warn not block, (d) exempt file → pass, (e) override file addition → pass.

**Why v0 — blocks next-project adoption:**

Every devshop project will hit this exact gap. Lalista is already carrying a `TODOS.md § v0 § e2e-audit-fill-gaps` entry that exists because unit-test enforcement was not in place — future projects shouldn't have to carry the same note. The hook is cheap (~100 LOC bash, ~200 ms pre-commit overhead) and high-value (closes the "silent test removal" gap `qa-options.md § Q3 shift #6` identified for every project).

**Trigger:**

- Lalista adopts the hook and runs a full commit cycle to flush out false-positive-exempt-list tuning — that data feeds the template's default exempt list
- OR: a second project shows up and immediately needs test-presence enforcement — ship at that moment

**Cross-ref:**

- `kit/scripts/commit-hooks/check-test-coverage.sh` — the devshop-repo prior art (kit-scripts only)
- `lalista/TODOS.md § v0 § e2e-audit-fill-gaps` — the E2E-side pair of this unit-side convention
- `lalista/PLAN.md` row 1 — the concrete surfacing opportunity

**Cost/risk reference (from 2026-04-24 lalista scoping session):**

- Implementation: ~4–6 focused hours (script + .bats tests + doc + wire-in)
- False-positive risk: mitigated by conservative exempt list + per-project override file
- Test-file-existence ≠ test quality: deliberate — `/ak-test-review` is the quality gate
- Maintenance: exempt list drifts a few entries per year; cheap to keep current

---

### Auth UX conventions — shared error-surface + state patterns

Projects using Supabase auth keep re-solving the same UX gaps because there's no shared convention. Lalista surfaced two that every hosted-Supabase auth flow hits:

1. **Unconfirmed-signup silent bounce** — `mailer_autoconfirm: false` (default) makes a successful signup return no session. If the client immediately routes to an authed area, middleware redirects the unconfirmed user back to `/sign-in` with no feedback. Looks broken.
2. **Raw Supabase error strings leaking to users** — messages like "Invalid login credentials" / "Email rate limit exceeded" / "User already registered" are developer-facing. Users read them as "what does this mean?"

Both were fixed ad-hoc in lalista (commit `31b5637` on `feature/auth`: new `awaitingConfirmation` state + `friendlyAuthError()` helper). Every next project will hit the same gaps.

**Shape of the convention (not final):**

- **Package**: a thin `@devshop-template/auth-ux` helper module (or inline pattern in the template's sign-in page) providing:
  - `AwaitingConfirmationCard({ email, onBack })` React component — standardized "Check your email" UI
  - `friendlyAuthError(message: string): string` — normalizes Supabase error strings to user copy. Exhaustive coverage of the ~6 common cases (`invalid_credentials`, `email_not_confirmed`, `email rate limit exceeded`, `user already registered`, `over_email_send_rate_limit`, `signup disabled`). Unmapped messages pass through unchanged (safe default).
- **Convention doc** in `guide/conventions.md § Auth UX Conventions` with:
  - When to show awaiting-confirmation vs. sign-in-error UI
  - Error-copy style guide (user-action-oriented, not dev-state-oriented)
  - Email enumeration vs. UX-clarity trade-offs (projects pick a stance; document which one they picked)
- **Template sign-in page**: the lalista-auth-feature scaffold (or its successor) includes the pattern out-of-the-box so projects don't rediscover it.
- **Test helpers**: a standardized `e2e/helpers/auth-ux.ts` that exercises the awaiting-confirmation path, rate-limit path, wrong-password path — pairs with the "user-state matrix" expansion to Step 2's Fix C (QA walks must exercise more than the admin-API happy path).

**Password-reset sub-pattern (required for the full story):**

Surfaced 2026-04-20 while testing PR #10 on the Vercel preview. Supabase's dashboard "Send password recovery" email links to `<site_url>/#access_token=...&type=recovery`; if the project has no callback route to land on, the link hangs. Every Supabase project needs this plumbing.

- **`PasswordResetCard` component**: email input → `supabase.auth.resetPasswordForEmail(email, { redirectTo: <callback URL> })` → success state ("Check your email for a reset link"). Lives in the same `@devshop-template/auth-ux` module as `AwaitingConfirmationCard`.
- **`/auth/callback` route** (RSC + Route Handler hybrid): reads `code` query param, calls `supabase.auth.exchangeCodeForSession(code)` server-side, then redirects based on `type` (`recovery` → `/reset-password`; `email_change` → `/settings`; default → `/`). Sets the session cookie so subsequent requests are authed.
- **`/reset-password` route**: form to set a new password (validated against `password_min_length`). Calls `supabase.auth.updateUser({ password })` on submit — works because the callback already set a session. On success, push to `/` (or `/onboarding` if the user has no household).
- **Required Supabase config** (must be set at `/ak-new-project` time — see the `/ak-new-project` Phase B auth-hardening step):
  - `site_url` = production URL (e.g., `https://app.vercel.app`) — **NOT** `localhost:3000` (the free-tier default). Recovery emails embed this; a wrong value makes every reset link hang.
  - `uri_allow_list` includes: production URL, Vercel preview wildcard (`https://*-<team>.vercel.app/**`), and `http://localhost:3000/**` for dev. Without this, `redirectTo` values get rejected.

**Why v0 — blocks next-project adoption:**

Combined with the auth-hardening step (password_min_length: 8, landed in v1.11.0) and the invite-code signup (v1 entry below), this completes the "serious project auth out of the box" story. Waiting means every project gets an ad-hoc implementation. Lalista is example #1 with the `awaitingConfirmation` state and `friendlyAuthError()` function; lalista has a `TODOS.md § auth-ux-refactor-to-adopt` entry standing by to adopt the helper once it ships, which also verifies the helper works in practice.

**Trigger:**

- Second project adopts the devshop and hits the same silent-bounce bug (almost guaranteed)
- OR: lalista's implementation gets iterated on twice — the 3rd refinement is the signal to factor up
- OR: lalista clears its `auth-ux-refactor-to-adopt` verification debt as soon as the helper ships (current plan)

**Cross-ref:**

- Lalista commits `31b5637` (fix) and sign-in page.tsx / page.test.tsx — the concrete prior art
- Lalista `TODOS.md § v0 § auth-ux-refactor-to-adopt` — the refactor-to-adopt TODO that verifies the helper when it ships
- The `/ak-pre-ship` Gate 9 user-state matrix (landed in devshop v1.11.0) — the QA-side pair of this UX-side convention

---

### Runtime validation at LLM / edge-function boundaries (Zod)

Projects with LLM-backed edge functions (or any endpoint returning structured data) currently rely on TypeScript's compile-time assertions alone — `client.functions.invoke<T>(...)` in Supabase, `(await fetch()).json() as T` in general. The generic or cast is a compiler promise, not a runtime check: whatever the server sends flows through untyped. For LLM-backed endpoints the risk is real — a prompt tweak, model swap, or function refactor that alters the response shape crashes clients at the use-site (`response.foo.bar` on `undefined`) instead of failing fast at the boundary.

Lalista surfaced this during TODOS cleanup 2026-04-22. See `lalista/PRODUCT-ROADMAP.md § v0 § 1j` + PR 6 (`feature/zod-validation`, queued): the `add-item` edge function returns an `AddItemResponse` shape generated by Claude Sonnet + pg_trgm logic, typed client-side via `functions.invoke<AddItemResponse>` with no runtime guard. Every next devshop project with an LLM-backed edge function will hit the same gap.

**Shape of the convention:**

- **Zod as the standard runtime-validation dependency** — added to the template's `packages/core` at scaffold time. ~12 KB min+gzip, tree-shakeable, TS-first schemas with inference.
- **Schema module pattern** — `packages/core/src/schemas/<feature>.ts` holds the Zod mirror of each `<feature>Response` type in `models/index.ts`. `z.infer<typeof Schema>` keeps the TS type and runtime schema in sync from one source.
- **Parse at the client wrapper boundary** — API wrappers in `packages/core/src/api/` call `Schema.safeParse(data)` before returning. On failure: report to Sentry with the raw payload (PII-scrubbed) and throw a typed `{Feature}ValidationError`. `.safeParse()` (not `.parse()`) gives observability a chance before the existing error boundary catches the throw.
- **Permissive object defaults** — use `.passthrough()` on object schemas so unknown fields (forward-compat from future additions) don't throw. Strict only on required shape.
- **Convention doc** in `guide/conventions.md § Runtime Validation at LLM / Edge-Function Boundaries`:
  - When to add Zod (LLM-backed endpoints) vs. when not to (DB queries — generated types + CI drift check already cover; form inputs — HTML5 + platform validation already cover)
  - How to author a schema (`.passthrough()` default, `z.infer` for type)
  - How to surface validation errors (Sentry with scrubbed payload, typed error class)
- **Template scaffold** — `/ak-new-project` adds Zod to `packages/core/package.json` and creates `packages/core/src/schemas/` with a placeholder `README.md` pointing at the convention doc.

**Why v0 — blocks next-project adoption:**

Lalista is about to implement this inline at PR 6 (`lalista/PRODUCT-ROADMAP.md § v0 § 1j`). Shipping the devshop convention **before** lalista PR 6 means lalista adopts the template directly and verifies the convention works on first use. Shipping after means factoring from lalista's inline implementation as prior art (same playbook as Auth UX conventions above, sourced from lalista's PR 2). Either order works — but the convention needs to exist before a second project onboards.

**Trigger:**

- Lalista reaches PR 6 `/ak-spec` time (imminent — queued on `lalista/PLAN.md` row 2)
- OR: a second project shows up with an LLM-backed edge function

**Cross-ref:**

- `lalista/PRODUCT-ROADMAP.md § v0 § 1j` — the inline implementation prior art (or target of adoption if the devshop convention lands first)
- `lalista/TODOS.md § v0 § zod-validation-refactor-to-adopt` — the refactor-to-adopt TODO (filed only if lalista ships inline before the devshop convention lands)
- `models/index.ts` is the devshop-template file where response types live today — schemas colocate as `schemas/*.ts`

---

## v1 (after v0 is validated on the first project)

### Tiered pre-ship pipeline

Auto-detect change scope and pick a tier:

- **Full** (schema, auth, new API, security): all steps
- **Standard** (UI features, new screens): skip `/cso` and `/benchmark`
- **Light** (bug fixes, styling, docs, config): lint + tests + `/review` + `/ship`

Announce which tier was picked. Override with `--full` or `--light`.

### Weekly pg_dump backup (beyond pre-migration dumps)

Pre-migration `pg_dump` lands in Phase 1c. This v1 item adds a weekly scheduled
backup independent of deploys — catches data corruption that isn't tied to a
migration. GitHub Action cron → `pg_dump` → artifact or private gist.

### Devshop observability — skill invocation log

Each devshop skill appends one line to `kit/log.csv`:
timestamp, skill name, duration, outcome (pass/fail/paused), notes.
`/retro` reads it to inform retrospectives with real data instead of opinions.

### Migration rollback integration testing

CI runs migration forward → rollback → re-apply to prove rollback SQL actually
works against real data. Currently only syntax-validated (v0). Full forward+backward
testing catches data-dependent rollback failures.

### Automated service quota monitoring

GitHub Action cron (weekly or monthly) that checks usage against quotas for
Supabase, Sentry, PostHog, GitHub Actions, and Vercel. Warns when usage > 80%.
v0 has manual dashboard links in the guide; this automates the check.

### Local integration test alternatives to DinD

v0 uses Docker-in-Docker for `supabase start` inside the devcontainer (16GB+ RAM).
If DinD proves too heavy, evaluate alternatives: host-side Supabase with devcontainer
connecting via `host.docker.internal`, or optimized CI-only workflow.
Full research: `kit/notes/integration-test-local-alternatives.md`

### Subagent architecture for `/implement`

v0 uses single-agent implementation (full spec in one context, 1M model).
When context pressure is observed (agent losing track of earlier tasks, hitting
limits on large features), switch to orchestrator + per-task subagents.
Design: main agent manages TASKS.md, spawns subagent per task with task description,
relevant spec sections, hat principles, and a shared context summary file
(`CONTEXT.md`) that grows as tasks complete.
Trigger: when `/implement` starts losing context on features with 10+ tasks.

### Changesets

`@changesets/cli` + `.changeset/config.json` — automated changelog generation in PRs.
Removes manual CHANGELOG maintenance. Each PR includes a changeset file describing
the change; on merge, changesets auto-generates the changelog entry.

### `/ak-commit` skill + husky gate

Replace raw `git commit` with an `/ak-commit` skill that owns the full commit loop:
assess dirty state in both repos → classify files → plan commits → execute → verify
clean → repeat until done (or ask user for unknowns). Enforced by a husky pre-commit
gate (`check-ak-commit.sh`) that blocks raw commits — bypass requires a descriptive
reason, adversarially reviewed. Same pattern as `dirtyTreeReason` and `docsVerified`.

Problem it solves: raw `git commit` has no skill-level orchestration of the
assess → classify → plan → commit → verify loop. The pre-commit husky gates
block bad commits and the pre-push gate blocks stale PRs / dirty pushes (since
the 2026-04-19 hook architecture migration), but neither plans multi-commit
sequences. `/ak-commit` would own the commit loop end-to-end, replacing raw
`git commit` for anything beyond a single-file change.

Full design: `kit/notes/ak-commit-design.md`

### PR-description staleness check — layer + approach decision

**Context:** The 2026-04-19 hook architecture migration replaced the old PostToolUse `check-pr-description.sh` with a blocking `.husky/pre-push` check (`prDescStaleReason`). It catches a real observed bug — Claude has been seen pushing new commits without updating the open PR's title/body. But the current implementation fires the adversarial reviewer on EVERY non-trivial push, and a blank bypass reason auto-rejects regardless of whether the description is actually aligned → per-push friction even when the description matches. Tactical TODO + inline options captured in `kit/TODOS.md`.

**Alternatives considered (2026-04-19 session):**

- **(A) Prompt tune.** In `kit/scripts/adversarial-review.sh`, run item 8(a) "PR description genuinely matches the commits" alignment check BEFORE the generic blank-reason auto-reject path. Keeps the reviewer always-on; reduces false positives on aligned descriptions. ~10 LoC. Risk: shared-engine regression on other check types that rely on the "blank reason → generic → reject" semantics.
- **(B) Symptom detection in the hook** ("reframe-B"). Short-circuit when PR title prefix matches the highest-impact commit prefix + no bypass reason set → skip reviewer. Fire reviewer only on prefix mismatch OR explicit bypass. Parallels the `check-clean-tree.sh` pattern — deterministic symptom gate, reviewer only for edge cases. ~15-20 LoC in `.husky/pre-push`. False negative: title-aligned-but-body-stale slips through — same miss rate as the old advisory-hook era. Acceptable tradeoff per hook-migration precedent.
- **(C) Both A + B.** Most robust. Moderate effort.
- **(D) Drop the hook check entirely.** Rejected — the forget-to-update-PR bug has been observed in practice; the hook is earning its place.
- **(E) Move to skill layer.** Remove from the hook; add "verify + update PR description" step to skills that own PR operations (`/ship` gstack, `/ak-build` Phase 5 devshop, future `/ak-ship-devshop`). Architecturally cleaner: workflow concerns in workflow-owning skills, hook layer reserved for safety invariants (dirty tree, stash, release-coverage). Gap: ad-hoc `git push` from Claude outside pipeline-driven skills would have no check. Could combine with (B) as "hook = safety net for ad-hoc pushes, skill = active workflow step."

**Current lean:** (B) as the hook tune + (E) added to `/ak-build` Phase 5 in a separate follow-up. Hook stays as the belt-and-suspenders safety net for ad-hoc pushes; skill step is the active reminder where most PR operations actually happen.

**Decision trigger:** after PR 3 (`/ak-build core-flows`) has surfaced real data on (a) the false-positive rate of the current always-fires implementation, (b) whether the prefix-match heuristic holds up against real PR-desc patterns, (c) whether Claude's forget-to-update bug recurs during PR 3's pushes. Decide between A / B / C / E / hybrid with evidence.

**Cross-refs:** `kit/TODOS.md` (tactical TODO — compressed to a pointer back to this section). Origin in the 2026-04-19 hook architecture migration — see git log around v1.10.0.

### Devshop self-build pipeline

Use the project build machinery (`/ak-build`) for devshop changes themselves.
Currently devshop work is manual: branch, edit, commit, push, PR. The project pipeline (spec → implement → quality gates → ship) is
tightly coupled to project conventions (specs/ dir, metrics, responsive/theme
checks) and doesn't fit devshop changes.

**Options (pick at implementation time):**

- **`/ak-devshop-build`** — lighter devshop-specific pipeline: branch → edit →
  commit guard → docs consistency check → push → PR. Reuses `/ship` for the PR
  step. Skips specs, metrics, responsive checks.
- **Mode-aware `/ak-build`** — detect devshop branch prefix → swap in devshop
  conventions (devshop commit prefix, docs drift checks, script tests) instead of
  project ones. Single entry point but more complex.

**Devshop quality gates (different from project):**

- Commit guard passes (no mixed commits)
- Docs consistency (three-way: CLAUDE.md ↔ README ↔ GUIDE)
- Script tests (when they exist — see TODOS.md)
- No responsive/theme/metrics checks

**Trigger:** when devshop changes become frequent enough that the manual
branch-edit-commit-push flow feels like friction.

### CLAUDE.md block assembly

Template snippets in `kit/templates/claude-blocks/` — one per technology choice
(`supabase.md`, `vercel.md`, `posthog.md`, `sentry.md`, etc.). Each block contains the
env vars, migration commands, file path patterns, and conventions for that tool.

`/ak-init` assembles the project's `CLAUDE.md` from the relevant blocks based on which
services are set up (steps 3-6 already know). Same content across all projects using
the same stack; different for projects with different tech choices.

`/document-release` maintains "Where Things Happen" as paths get added post-init.

### Staging migration validation

Local `supabase start` and CI both run migrations against fresh DBs from seed.sql.
Neither tests against production data shapes. Data-dependent migration failures
(NOT NULL on columns with legacy nulls, table locks on large tables) only surface
in production. `-- ROLLBACK` and `pg_dump` are recovery, not prevention.

Options:

- Restore latest pg_dump into temporary local Supabase, run new migration against it
  before deploying (automated in `/post-merge`)
- At minimum, make every migration a "stop and ask" item with human review against
  production schema (already the convention — this automates verification)

### Accessibility testing in E2E (axe-core)

`eslint-plugin-jsx-a11y` already runs via `eslint-config-next`. Add runtime a11y
testing with `@axe-core/playwright` in E2E tests — catches issues that static
analysis misses (dynamic content, focus management, ARIA state). Wire into Playwright
test setup so every E2E page visit runs an axe scan.

Trigger: when the first E2E-testable flow exists (Phase 1e or equivalent).

### Sync script improvements

Current: simple `cp` guided by `manifest.txt`. Improve to:

- Diff before overwrite — show what changed, ask for confirmation
- Create PR on the devshop repo instead of direct push
- Conflict detection with abort + diff shown

### `/ak-collateral` skill — marketing / landing-page asset composer

Devshop has design-ops skills (`/design-consultation`, `/design-review`, `/plan-design-review`) but nothing that composes marketing collateral. Produce README banners and landing-page imagery from assets the pipeline already generates.

**Shape (not final):**

- Inputs: latest `specs/<feature>/hero/*.png` across merged features, project `README.md`, `DESIGN.md` tokens, optional `PRODUCT-ROADMAP.md` teaser line.
- Output: one or more composed PNGs (README banner, social card, hero strip) + an HTML landing-page layout (one page, static, design-system-consistent) in `docs/collateral/` or similar.
- Related: similar compositional pattern to `/design-html` + `/design-shotgun` — reuse that infrastructure if possible.

**Why not now:**

Projects need something to showcase before showcase tooling matters. lalista is pre-MVP (PR 2 = auth, PR 3 = core flows) — nothing to feature yet. The `guide/conventions.md § Screenshot Routing` table explicitly defers README-banner / marketing imagery until "the first project needs one." When the first flow ships with a visible product surface, that's the signal to build this.

**Trigger:**

- First project has at least one merged feature with committed `hero/*.png` showing end-user value (not just an auth gate).
- OR: user explicitly asks for a README banner and we realize this is the fourth ad-hoc composition request.

**First-pass design work:**

- Whether to reuse `/design-html`'s Playwright + screenshot pipeline vs. a new sharp/canvas-based compositor.
- Whether output lives in `docs/collateral/` (per project) or `specs/_collateral/` (spec-adjacent).
- How to handle brand assets (logo, fonts) — point at `DESIGN.md` token set or require a separate brand kit.

### Invite-code signup control — opt-in at `/ak-new-project`

Some projects launch invite-only (private beta, controlled rollout, reputation-protection while testing). Supabase's built-in signup is open by default; the only lever is `disable_signup: True` which blocks everyone indiscriminately. Invite-code gating is the common middle-ground and will be a repeat request.

**Shape (not final):**

- **Migration**: `invite_codes` table — `id uuid`, `code text unique not null`, `created_by uuid references auth.users(id)`, `used_by_user_id uuid references auth.users(id)`, `created_at`, `expires_at`, `invalidated_at`, `notes text`. RLS: service_role full access; authed users can only SELECT their own redeemed code (for UI confirmation).
- **Admin RPCs** (SECURITY DEFINER, grant to `authenticated` with admin check inside):
  - `create_invite_code(p_notes text, p_expires_in interval default '30 days')` returns `text` (the new code).
  - `invalidate_invite_code(p_id uuid)` returns `void`.
  - `list_active_invite_codes()` returns `setof invite_codes`.
- **Edge function `signup-with-invite`** (public endpoint) — accepts `{email, password, invite_code}`, validates the code against the table, marks it used atomically, calls `auth.admin.createUser` with service role. All in one transaction so a failed `createUser` doesn't burn the code.
- **Supabase auth config**: `disable_signup: True` to force all signups through the edge function.
- **Optional admin surface**: simple CLI script under `kit/scripts/invite-codes.sh` (list/generate/invalidate). A full UI page is project-specific — out of scope for the devshop template.

**Integration pattern:**

- `/ak-new-project` Phase B: interactive prompt "enable invite-code signup control? [y/N, default N]". If yes, run an `ak-scaffold-invites` sub-step that:
  1. Drops the migration into `supabase/migrations/`
  2. Drops the edge function into `supabase/functions/signup-with-invite/`
  3. Patches auth config to `disable_signup: True`
  4. Drops the CLI script + seed invite code into `kit/scripts/`
  5. Updates project `README.md` with a "Closed beta — signups require an invite code" note
- If no, skip — open signup stays default. Projects can opt in later by running the same scaffold-invites step manually (or via a future `/ak-add-invites` skill).
- Existing projects (like lalista) that want to adopt invite-only post-launch: point them at this scaffold flow.

**Why v1, not v+:**

This was the second auth-hardening request in one conversation (password_min_length: 8 was first, now invite-code gating). Paired with the Supabase hardening step shipping in Step 2 — the auth-defaults story is incomplete without a controlled-signup option. Invite-only is table stakes for any serious closed-beta launch; waiting until v+ means the first project needing it gets an ad-hoc implementation.

**Trigger:**

- First project explicitly asks for invite-only signup (lalista might; future projects very likely when launching)
- OR: second project adopts the devshop and hits the same "bots will hammer the site" concern — that's the "don't forget reviewing this again on next project" moment

**Cross-ref:**

- The `/ak-new-project` Phase B auth-hardening step (landed in devshop v1.11.0) — mandatory password-length + interactive CAPTCHA ship first; invite-code gating is the next layer up for projects that need it.

---

## v+ (future — when the need is felt)

### Full Finding Router — structured `disposition:` per gate dismissal

**What this is** — an extension of the Dismissal Log (see `.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`). Today every `/ak-pre-ship` gate's report includes a `## Dismissals` section where findings the gate chose not to fix get a free-text `rationale:` field. The Finding Router adds a **structured `disposition:` field next to each rationale**, turning "here's why I dismissed this" into "here's what should happen with this finding" — and then the pipeline does the appropriate thing with each.

**Background — why it's deferred until now**

The 3-PR gstack-guidance-enforcement work (landed in devshop v1.16 as `feat/preship-dismissal-log` + `feat/preship-core-user-story` + `feat/preship-design-conformance`) sized the Finding Router as the fourth and largest piece, intentionally cut out to land the other three first:

- Dismissal Log (the scaffolding) forces every gate to make triage explicit and gives us an adversarial-reviewed `rationale:` field — catches silent dismissals now.
- Core User Story + Gate 9 artifact assertion — catches silent no-ops (the original `add-sheet open+Escape` failure mode).
- Design-conformance gate — catches DESIGN.md drift the visual `/design-review` gate doesn't check.

All three closed the concrete bugs that motivated the work. The Finding Router is the clean-up layer: it takes the `rationale:` data the other three produce and routes it into concrete actions.

**What the router adds**

Five dispositions, each mapped to a pipeline action:

| `disposition:`    | Meaning                                                  | Pipeline action when the gate emits this                                                                                                          |
| ----------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fix-now`         | Real bug, must resolve in this PR                        | Agent fixes inline, commits (atomic per finding), gate re-runs                                                                                    |
| `fix-before-ship` | Must resolve before merge, but not necessarily right now | Appends a must-fix checkbox to the PR body; `/ak-build` Phase 6 verifies these are checked before declaring ready-for-review                      |
| `TODO`            | Valid concern, out of scope for this PR                  | Auto-append to `TODOS.md` with source tag (`[gate-name]`) so the next `/ak-status` surfaces it                                                    |
| `spec-amendment`  | Spec was ambiguous, not a real implementation gap        | Auto-amend `specs/<name>/spec.md` with the clarification + commit; gate re-runs against the clarified spec                                        |
| `ignore`          | Not actionable (false positive, out-of-scope-forever)    | Noted in `review.md` with reasoning — stays searchable but takes no pipeline action. This is the ONLY disposition Phase 3's MVP implements today. |

**How it composes with Phase 3's Dismissal Log**

Today's `rationale:` bullets stay exactly as-is. A Phase 4 dismissal just gains a `disposition:` line adjacent to the `rationale:`:

```markdown
## Dismissals

- polish-tier visual tweak on settings page
  - rationale: nits a designer would fuss over, but off-path for PR 3's core-flows scope
  - disposition: TODO
```

Dismissal-Log entries written before Phase 4 still parse — they just lack `disposition:` and route through the `ignore` path by default (current behavior). Net effect: additive, not migrational.

**Per-gate routing rules — where incremental lands**

This is where "Phase 4 wires gates incrementally" makes sense. Each gate has different severity taxonomies, and the mapping from a gstack finding to a `disposition:` isn't one-size-fits-all:

| Gate                 | Finding source                                          | Mechanical mapping possible?                                                                                   | Suggested landing order                     |
| -------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `/cso`               | JSON with `severity: CRITICAL\|HIGH\|MEDIUM\|TENTATIVE` | Yes — CRITICAL/HIGH → fix-now, MEDIUM → TODO, TENTATIVE already auto-dismisses via the Phase 3 shim            | 5th (mechanical, easy win)                  |
| `/benchmark`         | Metrics + thresholds (LCP, CLS, bundle size)            | Yes — threshold-based routing; above-threshold → fix-now, borderline → TODO, within-threshold already filtered | 6th                                         |
| `/qa`                | Prose findings with Critical/High/Medium/Low severity   | No — needs LLM judgment ("is this High severity blocker for this PR or not?")                                  | **1st (highest subjective-judgment value)** |
| `/design-review`     | Visual issues with impact rating (High/Medium/Polish)   | No — same reason as `/qa`                                                                                      | 2nd                                         |
| `/ak-test-review`    | Prose findings about test quality                       | No — needs judgment                                                                                            | 3rd                                         |
| `/review`            | Inline code-review comments + Greptile triage           | No — needs judgment                                                                                            | 4th                                         |
| `/simplify`          | Duplications / over-abstractions                        | Mostly auto-fixes inline today; router handles the residual                                                    | 7th                                         |
| `design-conformance` | Per-claim `needs_review` entries                        | No — needs judgment against DESIGN.md                                                                          | Bundle with `/design-review` (2nd)          |

Each gate's routing rules live in a small file under `kit/scripts/finding-router-rules/<gate>.sh` or similar — a per-gate mapping function that takes a finding (with severity + description) and returns a disposition.

**Adversarial review expansion**

The existing `dismissalLog` check-type in `kit/scripts/adversarial-review.sh` (landed in Phase 3) judges `rationale:` quality. Phase 4 extends the same check-type — or adds a sibling `dispositionRouting` check-type — that also judges whether the chosen `disposition:` is plausible given the rationale + the spec's `## Core user story` + `## In scope`. E.g., dismissing a core-story-touching finding as `ignore` with a vague rationale should be rejected.

**Concrete implementation sketch**

When Phase 4 lands:

1. **`kit/scripts/finding-router.sh`** — new script with subcommands: `route <gate> <findings.json>` (apply gate-specific rules + emit dispositions), `execute <disposition-plan.json>` (perform the pipeline action per entry), `verify <feature>` (confirm every fix-before-ship entry is actually resolved before declaring gate pass).
2. **`kit/scripts/finding-router-rules/<gate>.sh`** — per-gate mapping functions, starting with `/qa` and `/design-review` as the first wired gates. Other gates route everything through `ignore` by default until their rule file lands.
3. **`.claude/skills/devshop/pre-ship/SKILL.md § Dismissal Log`** — extended with the `disposition:` field spec + invocation of `finding-router.sh` after each gate's report is produced.
4. **Adversarial review prompt** — rule #11 added alongside rule #10 (dismissalLog) in `kit/scripts/adversarial-review.sh` for routing-plausibility judgment.
5. **Integration tests** — new `kit/tests/finding-router.bats` + per-rule fixtures under `kit/tests/fixtures/finding-router/` exercising each gate's routing.
6. **Docs** — `kit/docs/guide/workflow.md` Phase 3 pre-ship paragraph extended; `kit/docs/guide/hooks.md` § Dismissal Log subsection upgraded to § Finding Router; `CLAUDE.md` Known Footguns entry updated for the new dismissal-log contract.

**Ship size estimate**: ~250 lines for the router core + ~60 lines per wired gate + ~80 lines per bats test file. Landing the first two gates (`/qa` + `/design-review`) is roughly ~500 LOC. Subsequent gates are smaller as patterns emerge.

**Cost breakdown (2026-04-22 estimate)**

- **Phase 4a — router scaffold + first two gates (`/qa` + `/design-review`)**: ~500 LOC across ~5 files. Realistically 2 PRs (scaffolding PR: router core + adversarial-review extension + bats tests; then gate-wiring PR). Several focused sessions, not a single sitting.
- **Phase 4b — remaining 5 gates (`/ak-test-review`, `/review`, `/cso`, `/benchmark`, `/simplify`)**: ~60–100 LOC per gate for the rule file + tests. ~400 LOC total. Can be incremental over weeks as patterns emerge.
- **Full program**: ~900 LOC, 3–5 PRs, spread over multiple working days.
- **Doubled adversarial-review load**: every non-`None` dismissal goes through TWO LLM calls (rationale-quality + disposition-plausibility). Cost per pipeline run doubles for dismissal review specifically; the short-circuit on `None` bodies (Phase 3's scoped parse) keeps default runs at zero cost.

**Risk breakdown (2026-04-22 estimate)**

Medium-to-high overall. Four distinct risk classes:

1. **Automated `fix-now` is a real risk.** The pipeline decides "this is a bug, fix it now" and commits inline. If the routing is wrong (finding is a false positive) or the fix is wrong, bad code lands without human review. The existing `/ak-implement` stuck protocol + tests-must-pass gate help but don't eliminate this — layering "pipeline decides to fix" on top of "pipeline tries to fix" is a new compound failure mode. Mitigation: require `fix-now` to route through `/ak-implement`'s atomic commit pattern; never allow `fix-now` to skip test verification.

2. **Automated `spec-amendment` is worse.** The pipeline decides "the spec was ambiguous, let me amend it" and edits `spec.md` mid-run. That invalidates earlier agent decisions made against the old spec, may contradict things the user already approved at Phase 0 of /ak-build. Safe design: `spec-amendment` PAUSES and asks the user rather than auto-amending. Which reduces the automation value — you've added ceremony without speed. Probably right to require human confirmation on this disposition specifically.

3. **Opacity vs. transparency.** Today the human reads `review.md` and sees findings + rationales. With Phase 4, many findings auto-route and the human sees "pipeline did X with Y finding." Harder to audit retrospectively ("why did it choose TODO over fix-before-ship?"). The project's strength has been human-in-the-loop visibility; heavy automation here works against that. Mitigation: every routing decision writes an audit-trail entry with the chosen disposition + its rationale, not just the outcome.

4. **Secondary risks**:
   - **Per-gate rule drift** — six+ mapping functions (one per wired gate) that can subtly differ over time without shared conventions. Mitigation: a shared `kit/scripts/finding-router-rules/_common.sh` for severity-agnostic logic; per-gate files only hold gate-specific mappings.
   - **Regression surface** — if Phase 4 code has bugs, it can block pipelines Phase 3 handles fine. Mitigation: feature-flag per-gate wiring so each gate's router can be disabled independently; phase-in matches the incremental landing order.
   - **Adversarial-reviewer false-rejection rate** — the disposition plausibility judgment adds a new rejection surface. If the reviewer is too strict, pipelines grind on edge cases. Mitigation: the same `DEVSHOP_SKIP_ADVERSARIAL=1` escape hatch Phase 3 already has.

**Trigger — when to build this**

After v1.16 has been used in anger for a month or two on a real project. The signal to land: a Phase 3 review.md surfaces dismissals with weak rationales that an adversarial reviewer can't cleanly accept or reject because the finding would clearly be `fix-now` / `TODO` / `spec-amendment` if only we had that vocabulary. That's when the current `rationale:`-only vocabulary is hitting its ceiling; Phase 4 unblocks further automation.

**What NOT to do while deferred**

- Don't add ad-hoc `disposition`-like fields to Phase 3's `rationale:` section — that fragments the format before Phase 4 can unify it.
- Don't wire routing for one gate without the reusable `finding-router.sh` substrate — per-gate one-offs are how the devshop would end up with 7 subtly different routing implementations.
- Don't treat deferring this as technical debt. The three landed phases cover the concrete failure modes that motivated the work; Phase 4 is an efficiency / hygiene upgrade for the triage step, not a correctness fix. Current Phase-3 users get adversarial review of rationales; Phase 4 is how routing becomes mechanical after those rationales pile up.

### Git hook symlink recovery (post-checkout / post-merge)

Add husky `post-checkout` and `post-merge` hooks that call
`create-devshop-symlinks.sh` to proactively recreate symlinks after git
operations that can lose them. Currently symlinks are recreated reactively
(at session start and before commits). Proactive recovery would mean
symlinks are restored immediately after `git checkout`, `git merge`, and
`git pull` — no waiting for the next session or commit.

Trigger: after the symlink fragility TODO is resolved (settings.json copy
vs symlink decision), reassess whether proactive recovery is still needed.

### Native/mobile devshop support

Extend the devshop to support React Native (Expo) apps alongside web. Adds `apps/mobile/`,
EAS CLI, Maestro E2E, mobile Sentry/PostHog, App Store/Play Store deployment.
Full build blueprint: `kit/notes/bootstrap/v+-native.md`.

### Fakeowner + Bash bypass hardening

Two known security gaps in the file protection model:

1. **Fakeowner**: Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic — Layer 2 (root ownership) doesn't enforce on these mounts.
2. **Bash bypass**: Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either.

**Current protection (v0):**

1. Deny rules in `settings.json` block Edit/Write tools
2. `init-devshop.sh` chowns files to root on container start (cosmetic on fakeowner)

**Known gap:** Bash commands can modify any file on the fakeowner mount regardless of
displayed ownership. Deny rules only cover Edit/Write tools, not Bash.

**Attempted fix: DCG custom block rules** — added `[overrides] block` patterns in
`.dcg.toml` matching protected filenames. Problem: DCG pattern-matches against the full
command string, so `git add .claude/settings.json` and `git commit` mentioning protected
files in messages trigger false positives. DCG's `allow` override precedence vs pack rules
(e.g., `core.git` blocking `git reset --hard`) is undocumented — blanket git allowlisting
might weaken existing protections. Reverted.

**Option A: DCG with surgical patterns** — instead of filename-only patterns, use
write-verb + filename combos (`> .*settings.json`, `tee .*settings.json`, `python.*settings.json`).
Avoids git false positives but requires enumerating all write verbs — misses novel ones
(`dd`, `perl`, `ruby`, `node -e`, etc.). Weaker net than broad filename matching.

**Option B: Symlink to ext4 volume** — move protected files to `/home/node/.claude/`
(real ext4 Docker named volume where permissions are kernel-enforced), symlink from
workspace. `init-devshop.sh` copies latest from git → volume target, then
`chown root:root` — kernel enforces it. Real protection, not pattern-matching.
Complexity: lifecycle management (git updates must flow through copy step), container
rebuild vs volume persistence timing, Claude Code must follow symlinks for settings
loading (likely works, untested).

**Option C: Custom PreToolUse hook** — a bash script (not DCG) that parses the command
from stdin JSON and checks if it would write to protected paths. More flexible than DCG
patterns, can do path resolution, but same fundamental limitation: pattern matching is
bypassable with sufficient creativity.

**Trigger:** When a Bash bypass is observed in practice (not just theoretical).

### Symlink replacement protection

The `.devshopkit` symlink (and other injected symlinks like `.claude/commands`,
`.claude/skills/*`) are node-owned and have no deny rules. A single `mv` command
(which is in the Bash allow list) could replace `.devshopkit` with a symlink to an
attacker-controlled directory. All guard scripts (`bash kit/scripts/...`)
and PreToolUse hooks would then execute from the new target.

**Current mitigations:**

1. `create-devshop-symlinks.sh` recovers symlinks at pre-commit and session start
2. Detection window is one tool call (the next PreToolUse hook fires from the wrong location)
3. `ln` is not in the Bash allow list — only `mv` could replace a symlink without prompt

**Why not fixed now:** The attack requires `mv` (allowed), has a one-tool-call
detection window, and self-heals at the next checkpoint. Practical risk is low.

**Options when hardening:**

- PreToolUse hook that validates `.devshopkit` symlink target before executing any
  command that references `kit/` paths
- Integrity check in DCG that verifies symlink targets haven't changed
- Root-owned wrapper script at a fixed path (not a symlink) that hooks call
  instead of relying on the `.devshopkit` symlink path

**Trigger:** When a symlink replacement is observed in practice, or when
hardening the Bash bypass gap (above) — both share the same attack surface.

### CI slow job expansion

The `slow` job in `.github/workflows/ci.yml` is commented out at scaffold time. It gets
built incrementally, tied to feature milestones. Each expansion lands in the same PR as the
code it tests — no gap between "tests exist" and "CI runs them."

**Trigger 1: First DB-backed feature** (e.g., auth, data queries):

Uncomment the `slow` job (`needs: fast`, `if: github.event_name == 'pull_request'`). Add:

- `supabase/setup-cli` GitHub Action for Supabase CLI
- `supabase start` to spin up local DB stack (GitHub Actions has native Docker — no DinD needed)
- Load `seed.sql` via `psql` against local Supabase Postgres
- Integration test step: `pnpm turbo run test` (runs both unit + integration)
- Type drift check: `supabase gen types typescript` → `git diff --exit-code packages/core/src/supabase.types.ts` → fail if types have drifted from schema
- Rollback SQL validation: for each new migration, extract the `-- ROLLBACK` block and parse it against local Postgres (e.g., `EXPLAIN` wrapper). Fail if syntax is invalid — catches typos before they're needed in an emergency
- Mask secrets: `echo "::add-mask::$SUPABASE_SERVICE_ROLE_KEY"`
- Implementation note: verify which Supabase env vars are actually needed for `supabase start` + `supabase gen types` in CI. Wire only what's confirmed.

**Trigger 2: First E2E-testable flow** (e.g., sign-in → core action → verify):

Add to the `slow` job:

- Install browsers: `npx playwright install --with-deps chromium`
- Build and start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
- Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
- Upload trace artifacts on failure via `actions/upload-artifact` for debugging
- Cache Playwright browsers using lockfile hash

**Additional secrets for slow job**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin access) and `ANTHROPIC_API_KEY` (if edge function integration tests call Anthropic). Add to GitHub Secrets when wiring up the slow job.

**After both expansions**: update branch protection to require `slow` as a required status check alongside `fast`.

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs, Playwright browsers. Cache keys use lockfile hash.

**Expected CI minutes**: ~260 min/month for 10 PRs (20 fast jobs × 4 min + 10 slow jobs × 15 min). GitHub Actions free tier: 2000 min/month.

### Backend alternatives and self-hosting evaluation

Evaluate alternatives to Supabase hosted for cost-conscious multi-project use:

- **Neon + Auth.js + Vercel functions**: free database branching, $0/mo, medium assembly
- **Self-hosted Supabase via Coolify + Hetzner**: ~€15/mo for multiple projects, higher ops burden
- **Backend-agnostic init**: `/ak-init` asks which backend and wires accordingly

Trigger: when monthly Supabase bills exceed ~€15/mo across projects, or when
staging/branching becomes a real bottleneck.

Full research: `kit/notes/backend-alternatives-research.md`

### `/rollback` skill

Dedicated skill that: reverts Vercel deployment (`vercel rollback`), warns about
migration state, walks through manual data recovery. Build when you've had your
first production incident and know what the workflow should actually be.

### Visual regression testing

Playwright screenshot comparison for key screens. Store baseline screenshots in
`tests/screenshots/`. CI step compares current vs baseline, fails if diff exceeds
threshold. Catches unintended visual changes that unit tests miss.

### `/ak-migrate-project` skill

Skeleton exists (`.claude/skills/devshop/migrate-project/SKILL.md`). Two tiers:

- **Lightweight (same stack)**: existing Node/Next.js project, just needs devshop
  tooling. Merge configs (`.prettierrc`, `eslint.config.mjs`, `tsconfig.base.json`,
  etc.) instead of replacing, create/adapt `.devcontainer/`, skip N/A steps
  (no Supabase, no PostHog, etc.), don't delete existing `apps/`/`packages/`.
- **Full (different stack)**: migration from another framework (e.g., Swift → React,
  Django → Next.js). Archive old code for reference, port design system, set up
  backend integration, rebuild screens, full test pass.

`/ak-init` assumes a fresh template clone. `/ak-migrate` handles the cases where
that assumption doesn't hold. Reference: Phase 1 execution in
`kit/notes/bootstrap/v0-web.md` as the first data point for parametrization.

Trigger: when a second project needs to adopt the devshop.

### Parallel implementation loops via worktrees

Two `/implement` sessions running simultaneously on different features using
git worktrees (separate working directories, each on its own branch).

**What it would achieve**: True parallel feature development. Two Claude Code
sessions, each with its own worktree, spec, and task list. Merge when both
are done.

**What it would require**: Worktree management tooling, resource budget (two
sessions + potentially two local Supabase instances), merge conflict strategy
for shared files (tokens.ts, shared components), and a way to coordinate
when both features touch the same package.

**When to build**: When single-loop development feels like a bottleneck — likely
when the app has 10+ screens and features can be cleanly isolated.

### Auto-trigger `/go-live` on PR approval

Currently: user approves PR on GitHub, comes back to terminal, says `/go-live`.
Goal: approving the PR on GitHub automatically triggers merge + deploy + canary +
reflection — no manual second step.

Options to explore: GitHub Actions on `pull_request_review` (approved) that calls
Claude Code remotely, or GitHub auto-merge + a webhook/scheduled agent that detects
newly merged PRs and runs the post-merge pipeline. Lightest option may be GitHub
auto-merge (PR merges when CI passes + approved) combined with a deploy workflow
that runs canary checks — but loses Claude's structured reflection step.

### Devshop testing

Test infrastructure for the devshop itself — scripts, hooks, and sync tooling.
Currently the devshop has no automated tests; correctness relies on manual
verification during use.

#### Hook tests (commit guard)

Automated tests for `devshop-commit-guard.sh` and other commit hooks. Set up
temp git repos, stage specific file combinations, and assert correct blocking
behavior. Key invariant: **no auto-pass** — checks must never silently pass
because the "right" files happen to be co-staged. Every blocking check must
require an explicit reason, regardless of what else is in the commit.

Test cases: mixed commit detection (project repo only), docs drift with/without
co-staged docs, doc consistency with 1/2/3 docs staged, cross-repo dirty state,
bypass flag parsing from stdin JSON, exit code 2 on failure, repo detection.

#### Sync script tests

Tests for `sync-from-devshop.sh` and `sync-to-devshop.sh`. Create two temp
repos, run sync in both directions, verify correct files copied and exclusions
honored.

#### init-devshop.sh tests

Verify symlinks created, security lockdown applied, BUILD-LOG.md created when
missing, skill symlinks resolve.

### Structured logging for edge functions

Sentry catches crashes. PostHog tracks user actions. Gap: application-level
operational logging. When a user reports "my item didn't appear," you need edge
function logs, query timing, auth flow steps. Supabase has logging but it's not
structured or correlated with user-facing issues.

Consider structured console.log in edge functions with a standard format
(timestamp, request ID, user ID, action, duration). Revisit after first
production debugging session reveals what's actually needed.

### ~~Repo layout clarification~~ — RESOLVED

Resolved: created `template/` directory at devshop root containing the project
skeleton. Root simplified to devshop-only needs (no turbo, no pnpm-workspace).
`init-devshop.sh` moved to `kit/scripts/`. `/ak-init` replaced by
`/ak-new-project` (two-phase: create repo + setup) and `/ak-migrate-project`
(skeleton). Init checklist moved from GUIDE.md to per-project `INIT-TRACKER.md`.

### Standalone devcontainer for abra-kadabra

Open the abra-kadabra repo directly in a devcontainer for devshop-only work — no
project repo required. Currently the devcontainer assumes a project repo at
`/workspace`; opening abra-kadabra alone leaves `/workspace` empty and
`init-devshop.sh` fails.

Add a second devcontainer profile (e.g., `.devcontainer/devshop-only/`) that
mounts abra-kadabra as the workspace, skips project injection, and provides a
working Claude Code environment for editing devshop scripts, skills, docs, and
GUIDE.md without needing a sibling project repo.

Trigger: when devshop-only work sessions become frequent enough to justify the
setup.

Related: the devshop's root `CLAUDE.md` contains conventions that span both
devshop and project work (e.g., metrics, responsive, edge function rules). In
devshop-only sessions those project-oriented sections are harmless noise, but
over time consider splitting into universal devshop conventions vs.
project-template conventions — or just accepting the noise as low-cost.

### CODEOWNERS + branch protection

Add `CODEOWNERS` to both repos requiring review approval for changes to
`.devshopkit/`, `.claude/`, `.devcontainer/`, and hook files. Pair with GitHub
branch protection on `main` (require PR reviews, block direct pushes).

Currently all guards are local (hooks, file ownership, deny lists). A force
push to main bypasses everything. CODEOWNERS + branch protection adds
server-side enforcement that survives local bypass.

Not needed for solo development — the local guards handle the actual threat
model (Claude bypassing checks). Becomes relevant when a second contributor
joins or when the devshop is used across multiple projects with different
maintainers.

Trigger: when a second human contributor needs commit access.

### DNS wildcard firewall rules

Current firewall resolves each domain to IPs via `dig` + `ipset`. Every subdomain
needs its own entry (e.g., `sentry.io` and `o123456.ingest.sentry.io` resolve to
different IPs). This works but means more entries to maintain per project.

Alternative: use a DNS-aware proxy (e.g., `squid` or `dnsmasq` with filtering) that
supports wildcards like `*.supabase.co`. Fewer entries, survives subdomain changes.
Trade-off: adds a proxy process and config — more moving parts than the current
plain `iptables` + `ipset` approach.

Trigger: when the firewall domain list grows unwieldy across multiple projects.

### Self-correcting workflow patterns

The 2026-04-18 hook architecture migration (`kit/notes/roadmap/hook-migration-plan.md`) moved
workflow nudges from `PostToolUse Bash` (audience-confused, fires in subagents) to
the husky pre-push layer (agent-agnostic, blocking with adversarial review). That
fix solves the audience problem and strengthens enforcement, but it preserves the
existing pattern: hooks DETECT a problem, AGENT/HUMAN must ACT on it.

The deeper architectural reframe — deferred to v+ — is **self-correcting workflow**:
hooks (or skills) take the action themselves, with the agent/human just confirming
substantive decisions. Examples:

- **Auto-update PR description**: pre-push hook detects staleness, regenerates
  description from commit log via `gh pr edit`, asks user to confirm only if the
  diff is substantive (renames, removals, scope changes). Trivial appends auto-apply.
- **Auto-stage leftover files**: post-commit detects untracked/unstaged files, asks
  "stage these as a follow-up commit?" with one-key confirmation. Cleaner than
  warning + agent-must-remember.
- **Auto-invoke `/ak-release-devshop`**: post-merge to abra-kadabra `main` with
  `feat:`/`fix:` commits → automatically suggest the release skill via skill chain.
- **Auto-stash on dirty session start**: SessionStart detects WIP from prior session,
  offers to stash it under a labeled stash so the new session starts clean. Reversible
  via `git stash pop`.

**Why deferred from the 2026-04-18 migration**: each pattern is its own design
decision (substantive-vs-trivial threshold, confirmation flow, reversal-on-error,
edge cases like concurrent edits). Bundling all of them was multi-PR work that would
have delayed PR 3 of the lalista migration. The current adversarial-review pattern
captures most of B's enforcement value (LLM judges the bypass reason) without the
auto-action complexity.

**Why this is worth doing eventually**: the persistent failure mode of "agent
ignores advisory" remains, even with strong adversarial gates. Auto-action removes
the agent-discipline dependency entirely. Particularly valuable for high-frequency
workflow concerns where reading and acting on each warning is a tax.

**Structural concerns to design through**:

1. **Confirmation UX for auto-actions in git hooks**: husky hooks run during git
   operations. Interactive confirmation requires tty/stdin handling that's clunky
   in some shell contexts. Self-correcting actions are more naturally implemented
   in skills (where confirmation flows are first-class) than in pure git hooks.
   May lead to a hybrid: husky detects, signals to next skill invocation to act.
2. **Reversal**: every auto-action needs a clear undo path (`git restore --staged`,
   `git stash pop`, `gh pr edit` to revert description). Design must surface the
   undo at the moment of action.
3. **Substantive-vs-trivial threshold**: "auto-apply trivial, confirm substantive"
   only works if "substantive" is reliably detectable. Likely needs adversarial
   LLM review as the discriminator (matches existing pattern).
4. **Failure modes**: what if `gh pr edit` fails mid-update? What if auto-staging
   stages files the user didn't want? Each auto-action needs failure-safe defaults.

**Trigger**: when the persistent "agent ignores advisory" failure mode is observed
in practice often enough that adversarial-gate enforcement isn't sufficient. Or when
specific auto-action candidates (PR description sync, post-merge release prompts)
become high-frequency enough to justify per-pattern design work.

**Migration path from current**: each candidate auto-action can be implemented
incrementally — no need to do them all at once. Likely first candidate: auto-update
PR description on push (extends the existing pre-push staleness check from "block
with reason" to "regenerate + confirm if substantive").

Related: `kit/notes/roadmap/hook-migration-plan.md` § "Architectural shift" for the
why-not-now rationale.
