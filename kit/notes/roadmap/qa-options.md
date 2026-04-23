# QA Backend Isolation — Options and Current State

**Status:** active reference. **Authored:** 2026-04-23 (post PR 5 ship, pre `/ak-build ship` PR 4). **Projects:** lalista (triggering example); generalizable to any devshop project on Supabase.

## TL;DR

Gate 9 of `/ak-pre-ship` has been falling back to "admin-API against hosted Supabase" because Docker-in-Docker is inert in the devcontainer (runArgs lacks `--privileged`). Real users + households + items are being created on prod during every pre-ship walk. The fix is a devcontainer change (socket bind-mount for DiD) plus a script change (`preship-supabase-bootstrap.sh` must refuse the hosted fallback). The CI side is handled separately by PR 4 (GitHub Actions has native Docker, so `supabase start` in CI "just works"). Full rationale below.

---

## Why this exists

The question that surfaced during PR 5 → PR 4 transition: _are we doing QA on the hosted production Supabase?_

Yes — and the evidence is explicit:

- `specs/auth/qa-walk.log` (PR 2): admin-API created a test user, wrote a household to hosted Supabase (`https://nzfdfjctpotjyuxdfcpw.supabase.co`), cleanup only deleted the user. Household likely orphaned.
- `specs/core-flows/qa-walk.log` (PR 3): same pattern.
- `BUILD-LOG.md:16`: _"migration 008 applied via Management API (not via `supabase db push` — local docker-in-docker unavailable in the devcontainer)."_
- `.devcontainer/init-firewall.sh:77-105`: the egress allowlist explicitly includes `api.supabase.com`, `aws-0-us-west-2.pooler.supabase.com`, and the prod host.
- `.claude/skills/ak-pre-ship/SKILL.md:118`: _"If Docker-in-Docker isn't available in the devcontainer (currently inert without a --privileged rebuild), Gate 9 falls back to admin-API against hosted — which bypasses rate limits entirely but pollutes the hosted DB with test data."_
- `/devshop/kit/scripts/preship-supabase-bootstrap.sh:30-33`: the fallback path is explicit — `unavailable: Docker not running — local Supabase cannot start; Gate 9 must use admin-API against hosted`.

It's not catastrophic — test data doesn't corrupt real user data — but it inverts the invariant "test before shipping to prod." Migrations are being applied to prod so QA can pass, rather than QA proving migrations work before prod ever sees them.

---

## The three questions

1. **How do we prevent QA from hitting prod Supabase?** Simple, reliable.
2. **Where in the devshop workflow does QA happen, and how should each place be approached?**
3. **Higher-level testing approach — reliability as we iterate, and autonomy of `/ak-build` (tests must validate the spec, not just the code shape)?**

---

## Q1 — Alternatives for the QA backend

Six backend choices, ranked by isolation strength × cost. The enforcement layer (firewall, credential split, code guards) is orthogonal and stacks on any of them.

| #   | Approach                                                                 | Cost               | Isolation                           | Realism                                                                              | Fit                                                                                                               |
| --- | ------------------------------------------------------------------------ | ------------------ | ----------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| 1   | **Local Supabase via Docker** (`supabase start`)                         | $0                 | Per-dev hermetic                    | High — same stack as prod (Postgres, GoTrue, Realtime, Edge runtime)                 | Best for dev box. Today blocked by DiD (see Current State). Fix: socket bind-mount in `devcontainer.json`.        |
| 2   | **Supabase Preview Branches** (Pro plan $25/mo/org + per-branch compute) | Low                | Per-PR ephemeral                    | Highest — managed by Supabase, same infra as prod                                    | Best for team scale. Solves dev-laptop bottleneck + per-PR isolation in one move. Defer until second contributor. |
| 3   | **Dedicated staging Supabase project**                                   | Free tier possible | Per-project (shared across devs/CI) | High                                                                                 | Fine while solo. Risk: flakes when two QA runs step on each other.                                                |
| 4   | **Testcontainers Postgres** (ephemeral pg via `testcontainers-node`)     | $0                 | Per-test hermetic                   | Low — Postgres only. No GoTrue (`auth.users` absent), no Realtime, no Edge Functions | Useful for pure DB-layer tests (RLS, triggers). Can't do browser QA with real auth.                               |
| 5   | **Mock Supabase client** (MSW intercepting `*.supabase.co`)              | $0                 | N/A                                 | Very low — fixtures drift from real API; RLS / edge-fn / migration bugs invisible    | Fine for inner unit loop. Defeats the purpose at pre-ship.                                                        |
| 6   | **Hybrid**: local for dev, staging / preview branch for CI slow-job      | As #1 + (#2 or #3) | Strongest                           | High                                                                                 | Where most teams land.                                                                                            |

### Enforcement layer (stacks on any backend)

1. **Egress firewall allowlist** — remove prod Supabase hosts from `.devcontainer/init-firewall.sh`. Network-layer deny, immune to code-level bugs.
2. **Credential split** — prod `SUPABASE_SERVICE_ROLE_KEY` lives only in Vercel's production env + the GitHub Actions workflow that runs `supabase db push` on merge to main. Dev `.env.local` gets local/staging keys. Service role never in dev.
3. **Runtime URL guard** in `packages/core/src/supabase.ts` — throw if `NODE_ENV !== 'production'` and URL contains the prod project ref. Blunt but impossible to miss.
4. **CI branch-protection rule** — `main` requires slow-job green. Slow-job runs against non-prod. Merging becomes the only path to touching prod schema.

### Industry standard

Option 6 (hybrid): local for inner loop, managed non-prod for CI. Preview Branches are the emerging best practice on Supabase specifically.

### Lalista-specific recommendation

- **Now**: option 1 + enforcement layers 1–3. Zero cost, one afternoon of devcontainer + script work. Covers ~90% of the risk. Scope is PR 5 bullet (d).
- **Triggered by PR 4**: CI slow-job uses `supabase start` inside GitHub Actions (native Docker, no DiD needed). Covers the CI side of enforcement #4.
- **When a second contributor joins**: add option 2 (Preview Branches) for per-PR isolation in CI.

---

## Q2 — Where QA happens in the devshop

Five distinct QA surfaces in the pipeline, each with a different risk profile. The fix for each is different — don't one-size-fits-all.

| #   | Surface                                                | Runs                                                                               | Backend                                                                                    | Prod risk today                                                                                                                                  | Fix                                                                                                                                                                                                                                      |
| --- | ------------------------------------------------------ | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `/ak-implement` per task                               | `pnpm turbo run test:unit` (vitest)                                                | Env vars present at import; tests generally don't call DB                                  | **Low-silent** — imports `createClient`, no call. One accidental call hits prod.                                                                 | Audit `packages/**/*.test.ts` for `from('…')` / `.rpc(` calls. Add URL guard in `supabase.ts` (enforcement #3).                                                                                                                          |
| 2   | `/ak-pre-ship` Gates 3, 8, 9, 10                       | Browser against `http://localhost:3000`; dev server + Playwright hit real Supabase | Hosted prod (via `preship-supabase-bootstrap.sh` `unavailable → admin-API against hosted`) | **High-active** — `specs/auth/qa-walk.log` + `specs/core-flows/qa-walk.log` prove it. Creates users, households, items on prod via service role. | **The main fix**: enable local Supabase (DiD via `/var/run/docker.sock` socket bind-mount) → make bootstrap refuse the hosted fallback (report `blocked`, let `/ak-build` halt). Swap `.env.local` → `.env.local.preship` for gate runs. |
| 3   | CI fast-job (`.github/workflows/ci.yml`)               | `lint typecheck test:unit build`                                                   | `secrets.SUPABASE_URL` — likely prod per `BUILD-LOG.md:16`                                 | **Medium** — same as #1, but runs on every PR push.                                                                                              | Rotate CI secrets to staging (or local via `supabase/setup-cli`). Remove `SUPABASE_SERVICE_ROLE_KEY` from fast-job — unit tests don't need admin API. **This is PR 4 § 1g item 4 (post-merge manual action).**                           |
| 4   | CI slow-job (commented out TODO in ci.yml; PR 4 scope) | Planned: integration, E2E, Lighthouse                                              | Not yet wired                                                                              | N/A today, but this is where the next accident happens.                                                                                          | Wire correctly from the start: `supabase/setup-cli@v1` → `supabase start` in the job → tests point at `http://127.0.0.1:54321`. **This is PR 4 in scope.** Alternative when needed: Preview Branches.                                    |
| 5   | `/ak-go-live` → `/canary`                              | Screenshots + console + perf vs baseline                                           | Prod URL (read-only observer — no forms, no auth, no writes)                               | **OK** — intentional, read-only. `/canary` contract is observation.                                                                              | Document invariant "canary never submits forms or creates data" in SKILL.md. Current skill is naturally read-only (`goto` / `snapshot` / `console` / `perf` only).                                                                       |

### Priority order

#2 → #3 → #4 → #1 → #5. #2 is the only one that has actively polluted prod; fixing it is a one-afternoon devcontainer change.

### Timing

- **PR 4 (in flight)**: fixes #4 end-to-end. Also adds the post-merge action for #3.
- **PR 5 (queued)**: fixes #2 (the big one) via bullet (d) — dev-side prod isolation.
- **Follow-up narrow PR** (not yet scheduled): fixes #1 via a 3-line URL guard in `supabase.ts`.
- **#5**: no change needed.

---

## Q3 — Higher-level testing recommendations

Seven shifts, ordered by leverage. The goal: trustworthy autonomous `/ak-build` — tests validate the spec, not just the code shape.

1. **Fill the integration-test middle layer.** Today the pyramid is ~95% unit / 0% integration / 5% E2E. The missing layer is integration tests against local Supabase — verify RLS policies, RPCs (`mark_item_bought`, `create_household_with_owner`), migration forward/rollback, edge-function auth. These catch the bugs the agent can't see in code because they're semantic, not syntactic. Target: 80% unit / 15% integration / 5% E2E.

2. **One runner per layer, one env per layer, one guard per layer.**
   - Unit → vitest `node` env, network blocked (MSW erroring on unexpected call, or `--no-network`).
   - Integration → vitest + local Supabase, per-test seed.
   - E2E → Playwright + local Supabase or preview branch.
   - Canary → gstack browse against prod URL only.

   The guard matters: a unit test that silently calls Supabase is invisible today. Make that impossible.

3. **Tests as spec grammar.** `/ak-spec` produces `## Core user story` (verbs). Map 1:1 to Playwright test titles, with the artifact contract enforcing evidence per verb (already half-built at Gate 9 after the PR 3 "open-sheet-press-Escape-reported-pass" incident). Push further: `core-flows-qa-walk.spec.ts` should be mechanically derivable from the verb list. `/ak-implement` should write the failing test first (red), then code (green), then commit. Red-green-commit is what turns "agent thinks it's done" into "here's the test that proves it."

4. **RLS and migration tests are first-class.** RLS bugs are silent until a real user sees someone else's data. Per-policy cross-user probe (user A reads user B's row → must fail). Per-migration forward + rollback + re-apply verification. Gate 11 already enforces `-- ROLLBACK` comments exist; make CI actually run them. Migration 009's `ON DELETE SET NULL` for `added_by` is a 3-line integration test — catches prod schema bugs pre-push.

5. **Hermetic by default.** Every test sets up + tears down its own state. No shared fixtures. With vitest's `beforeEach` + `supabase db reset` (or per-test txn rollback), nearly free for integration layer. `createTestUser` / `deleteTestUser` in `apps/web/e2e/helpers/` is the right pattern — extend to household / items.

6. **Observability of the test suite itself.** Test count + duration + flake rate published per PR (vitest + Playwright emit JUnit XML; GitHub handles natively). Weekly trend: if suite drops from 120 → 110 tests, flag it. "Deleted during refactor" is the #1 way suites silently erode.

7. **Required checks on `main` branch protection.** Once slow-job lands (PR 4), make it required. Then the structural guarantee is real: the only path to merging is CI passing against non-prod Supabase; the only path to prod migrations is the `main`-push workflow. That's how you stop worrying about dev processes touching prod — you make the workflow physically incapable of it.

### Through-line

Reliability of autonomous `/ak-build` ≈ coverage of the integration layer. Unit tests give the agent confidence its functions work; browser E2E gives it confidence users can click through; integration tests against real DB + RLS + RPCs are what tell it the _system_ works. Without them, "tests pass" means nothing when a migration fails or an RLS policy leaks.

The highest-leverage single change is shift #1 (add the integration layer) paired with Q2 fix #2 (local Supabase for Gate 9). Both are unblocked by the same DiD fix.

---

## Current state (lalista @ 2026-04-23)

### Already in place

- Fast-job CI (lint / typecheck / test:unit / build) — runs on every PR push.
- `apps/web/e2e/` with Playwright at `baseURL: http://localhost:3000`; `webServer: pnpm run dev` auto-starts.
- Per-verb artifact contract enforced at Gate 9 (added after PR 3 "open-sheet-press-Escape-reported-pass" incident surfaced the silent-no-op failure mode).
- `createTestUser` / `deleteTestUser` helpers in `apps/web/e2e/helpers/test-user.ts`.
- `preship-supabase-bootstrap.sh` with an explicit `unavailable` fallback path — which is _why_ Gate 9 hits prod today. Fix removes the fallback.

### Blocked today

- **Local Supabase in the devcontainer** — the `docker-in-docker` feature is declared in `.devcontainer/devcontainer.json` but inert because `runArgs` lacks `--privileged`. Manifests as `bootstrap.sh` reporting `unavailable` → hosted fallback activates.
- **RLS tests, migration rollback tests** — no integration layer exists to run them (Q3 shift #1).
- **CI slow-job** — commented out with TODO in `.github/workflows/ci.yml` (in-scope for PR 4).

### In scope for PR 4 (ship, CI slow-job wiring)

Source: `PRODUCT-ROADMAP.md § v0 § 1g`.

- `supabase/setup-cli` + `supabase start` in GitHub Actions (native Docker — no DiD needed).
- Seed.sql loaded via psql against local Supabase Postgres in CI.
- Integration tests + type drift check + rollback SQL validation + edge-function deploy in slow-job — all against local Supabase.
- Branch protection: slow-job as required check on `main`.
- Playwright E2E in slow-job (mobile + desktop projects).
- **Post-merge manual action** (new, added at this session): rotate `SUPABASE_URL` / `SUPABASE_ANON_KEY` GitHub Secrets off prod for fast-job. Slow-job is immune; fast-job isn't.

### In scope for PR 5 (devshop-preship-hardening)

Originally three pre-ship-side improvements:

- (a) **RLS coverage pre-ship gate** — would have caught the `items_insert` policy gap that bit PR 5 Bug #1.
- (b) **`/ak-spec` render-condition matrix** — would have caught PR 5 Bugs #2 + #3 (add-new row shown across state combinations the spec didn't enumerate).
- (c) **`/plan-design-review` standing prompt** for "input duplicates existing data."

Expanded at this session with a fourth bullet:

- (d) **Dev-side prod isolation**:
  - DiD via `/var/run/docker.sock` bind-mount in `.devcontainer/devcontainer.json` (swap out the inert `docker-in-docker` feature).
  - `preship-supabase-bootstrap.sh` refuses the hosted fallback (reports `blocked` instead of `unavailable → hosted`), lets `/ak-build` halt cleanly.
  - Strip `api.supabase.com`, `aws-0-us-west-2.pooler.supabase.com`, and the prod project host from `.devcontainer/init-firewall.sh` allowlist.
  - Remove `SUPABASE_SERVICE_ROLE_KEY` from dev `.env.local`.

### Deferred

- **Supabase Preview Branches** ($25/mo) — deferred until a second contributor joins.
- **Integration-test middle layer** (Q3 shift #1) — likely follows PR 5 as a narrow PR or gets woven into PR 6/7 feature specs.
- **Runtime URL guard in `packages/core/src/supabase.ts`** — tiny (3 lines) but deserves its own narrow PR with proper verification, not mixed into PR 4 or 5.

---

## Decision log

Session on 2026-04-23, after PR 5 ship, before `/ak-build ship`:

- **Run PR 4 as scoped.** Don't broaden it to absorb dev-side fixes. Roadmap § 1g covers CI-side isolation end-to-end.
- **Add a post-merge secrets-rotation item to § 1g.** Fast-job `SUPABASE_URL` / `SUPABASE_ANON_KEY` should rotate off prod.
- **Expand PR 5 scope** to include dev-side prod isolation as bullet (d). Keeps devshop-side concerns in a single devshop-side interlude.
- **Preview Branches stay deferred** — single-contributor today, bootstrapping cost not justified.
- **URL guard** gets its own tiny PR later, not folded into 4 or 5.

---

## References

- `/workspace/CLAUDE.md § Gotchas` — edge-function deploy, RLS-bypass writes, information architecture.
- `/workspace/PRODUCT-ROADMAP.md § v0 § 1g` — PR 4 canonical scope (includes post-merge secrets-rotation item 4).
- `/workspace/PRODUCT-ROADMAP.md § v0 § 1h` — carry-forward items (also PR 4 scope).
- `/workspace/PLAN.md § Planned` — rows 1 (PR 4) and 2 (PR 5 devshop-preship-hardening, bullets a–d).
- `/workspace/.claude/skills/ak-pre-ship/SKILL.md § Gate 9` — Supabase backend fallback contract.
- `/devshop/kit/scripts/preship-supabase-bootstrap.sh` — the fallback mechanism (to be refused).
- `/workspace/.devcontainer/devcontainer.json` — the DiD runArgs gap (inert `docker-in-docker` feature).
- `/workspace/.devcontainer/init-firewall.sh:77-105` — prod-Supabase allowlist entries (to be stripped).
- `/workspace/specs/auth/qa-walk.log` + `/workspace/specs/core-flows/qa-walk.log` — smoking-gun evidence of hosted writes.
- `/workspace/BUILD-LOG.md:16` — Management API migration note (explicit "local DiD unavailable" admission).
- `/devshop/kit/notes/dual-goal-project-principles.md` — the dual-goal principle that informs how devshop patterns graduate from project-specific fixes.
