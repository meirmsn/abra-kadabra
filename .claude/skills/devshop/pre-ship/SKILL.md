---
name: ak-pre-ship
version: 4.0.0
description: |
  Quality gates before shipping. Pauses on findings, auto-advances on clean passes.
  After each code-changing gate, verifies tests still pass (stuck protocol if not).
  Does NOT ship or create a PR — use /ak-build for the full pipeline, or /ship after this.
  Runs: preflight → docs → metrics → fast-job-local → changed-tests-local → responsive →
  /simplify → /ak-check-docs-and-tests → /review → /cso → /design-review → /qa → /benchmark →
  /preflight (final) → convention check → capture hero shots.
  Preflight blocks if required tooling (e.g. Chromium for browser gates) is missing,
  so gates can never silently turn a missing-tool into a cheerful "skipped", and
  auto-creates Playwright Chromium symlinks for the gstack browse daemon.
  Hero screenshots for committed evidence are captured after all gates pass.
  Use when asked to "pre-ship", "quality check", or "check before shipping". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
---

# Pre-Ship

Chain quality gates before shipping. Pause on findings; auto-advance on clean passes.

**Key principle**: after every gate that changes code, verify tests still pass before
moving to the next gate. If tests fail, use the stuck protocol (see bottom of this file).

## Audit trail

Each gate writes its results to a **per-gate file sink** at
`specs/<feature>/gates/<canonical-gate-name>.md` using the canonical name from
`§ Gates (canonical order + named IDs)` below. The shard file holds exactly one
`## Gate <#>: <name>` section plus its mandatory `## Dismissals` block. The
orchestrator (`/ak-build § Phase 3.3`) concatenates the shards into
`specs/<feature>/review.md` after each pass + aggregates the `## Dismissals`
into the single top-of-file `## Router Summary` block.

The per-gate sink scheme replaces the prior "accumulate results in memory and
write `review.md` once at the end" shape. Two consequences:

- A crashed-mid-run agent loses at most one gate's work (the gate it was
  executing when the socket dropped); other gates' shards are durable.
- A re-run of a single gate (e.g. after fixing tooling that made the original
  invocation `blocked`) overwrites just that one shard, not the whole file.

For each gate's shard, record:

- Gate name + canonical # from § Gates table
- Result: `pass` | `findings (N)` | `n/a (reason)` | `blocked (reason)`
- If findings were found and fixed: what was found, which commit fixed it
- `## Dismissals` sub-section (mandatory; body either `None` or a bulleted
  list with per-bullet `rationale:` fields — see § Dismissal Log below)

### Outcome semantics (important — do not conflate)

- **`pass`** — gate ran and either found no issues, or findings were fixed during the run.
- **`findings (N)`** — gate ran and surfaced N issues that still need action. Pipeline
  usually pauses here.
- **`n/a`** — gate does not apply to this PR (e.g. docs check when no docs changed,
  benchmark on a non-UI PR). An expected no-op; does not indicate a problem. **Not legal
  for LLM-mediated gates — see next subsection.**
- **`blocked`** — gate could NOT run because required tooling was missing or misconfigured
  (e.g. Chromium unavailable for design-review). This is a failure mode, not a no-op.
  `/ak-pre-ship` MUST report blocked gates explicitly to the caller. `/ak-build` MUST
  refuse to advance to `/ship` if any gate is blocked.

Never use `blocked` when you mean `n/a`, and never use `n/a` when the real reason is
missing tooling. The orchestrator relies on this distinction.

#### `n/a` is not legal for LLM-mediated gates

Gates 6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa` MUST emit one of `pass`,
`findings (N)`, or `blocked (reason)` — never `n/a`. These gates produce the
judgment evidence the caller relies on; an `n/a` outcome on any of them looks like
"the gate ran and decided nothing applied" when the actual semantics are "the gate
didn't run." That ambiguity is what lalista PR #65 shipped on: the orchestrator
pre-classified `/qa` and `/design-review` as `n/a` for a logic-only PR; the
subagent obeyed; the live walk never ran; adjacent-flow regression risk shipped
without evidence.

Scope exemptions still exist — a non-UI PR genuinely doesn't need `/design-review`,
a docs-only PR genuinely doesn't need `/qa`. The correct outcome for that case is:

```
Result: blocked (n/a per scope: <specific file-path reason>)
```

`blocked` is the literal outcome string. The `n/a per scope:` rationale is the
audit trail. The adversarial-review chain (`dismissalLog` check-type) judges
whether the rationale is credible. The Phase 3 → 4 handoff parser counts this as
`blocked` for halt purposes, which is the right thing: a `blocked (n/a per scope:
...)` rationale that doesn't hold up is exactly what the caller needs to halt on.

Gates with a documented `n/a` path that fall under this rule must use the
`blocked (n/a per scope: ...)` shape — see Gate 8 `/design-review` below.

When the caller is `/ak-build`, the Phase 3 → 4 handoff converts `blocked >
0` into a mechanical halt: the orchestrator fires `AskUserQuestion` with
three options (resolve / override / abort), captures any operator override
to `specs/<feature>/review.md § Phase 3 → 4 advance log`, and invokes the
`blockedGateOverride` adversarial reviewer (Sonnet) on the override
reason. Silent autonomous advance past `blocked` is no longer reachable
from `/ak-build`. See `.claude/skills/devshop/build/SKILL.md § Phase 3 →
Phase 4 handoff § Rung 2` for the full protocol.

## Phase 0: Preflight

Before running any gate, verify the tooling this pre-ship depends on. This exists
specifically so a missing browser (or any other tool) can't silently degrade a gate
into a cheerful "skipped" result. If tooling is missing and a required gate depends
on it, the whole pre-ship aborts with a `blocked` status and a one-line fix.

### Scope detection

Decide which gates this PR actually needs, so preflight only fails on genuinely
required tooling:

```bash
git diff --name-only origin/main...HEAD > /tmp/preship-changed.txt
TOUCHES_UI=$(grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt | head -1)
```

- If `$TOUCHES_UI` is non-empty → Gates 3, 8, 9, 10 apply (browser required).
- Otherwise → those gates are `n/a`; browser preflight is advisory only.

### Tooling checks

Always (warn only — non-blocking):

- `gh auth status` — GitHub CLI authenticated.
- `[ "$(git branch --show-current)" != "main" ]` — not on main.

If `$TOUCHES_UI` (blocking if any of these fail):

```bash
# Try the Playwright-bundled Chromium first, then any system chrome
CHROMIUM=$(ls /home/node/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
CHROMIUM=${CHROMIUM:-$(which chromium 2>/dev/null)}
CHROMIUM=${CHROMIUM:-$(which chrome 2>/dev/null)}
"$CHROMIUM" --version >/dev/null 2>&1 || BLOCK_REASON="Chromium not available"

# Browse daemon Chromium version reconciliation (workaround until the upstream
# daemon auto-detects the installed version — tracked in /devshop/kit/TODOS.md).
# gstack's compiled browse daemon is pinned to chromium-1208 paths; when
# Playwright fetches a newer version (e.g. chromium-1217), the daemon fails to
# launch with "Executable doesn't exist". Create symlinks so the pinned paths
# resolve to whatever is actually installed. Idempotent.
if [ -n "$CHROMIUM" ]; then
  LATEST_CHROMIUM_DIR=$(ls -d /home/node/.cache/ms-playwright/chromium-* 2>/dev/null \
    | grep -v headless_shell | sort -V | tail -1)
  LATEST_HEADLESS_DIR=$(ls -d /home/node/.cache/ms-playwright/chromium_headless_shell-* \
    2>/dev/null | sort -V | tail -1)
  if [ -n "$LATEST_CHROMIUM_DIR" ] \
     && [ ! -e /home/node/.cache/ms-playwright/chromium-1208 ]; then
    ln -sf "$LATEST_CHROMIUM_DIR" /home/node/.cache/ms-playwright/chromium-1208
  fi
  if [ -n "$LATEST_HEADLESS_DIR" ] \
     && [ ! -e /home/node/.cache/ms-playwright/chromium_headless_shell-1208 ]; then
    ln -sf "$LATEST_HEADLESS_DIR" /home/node/.cache/ms-playwright/chromium_headless_shell-1208
  fi
fi
```

**Supabase availability check** (hard `blocked` if no local stack reachable, never falls back to hosted):

Gate 9 (`/qa`) walks the happy path against a Supabase instance. Hosted Supabase has two failure modes for this: (a) rate-limits signups aggressively (~30-min cooldown after 1-2 attempts), and (b) every signup leaves a real account on the production project — which the bootstrap historically did when Docker wasn't available. As of the dev-side prod-isolation interlude, the hosted fallback is removed: if no local stack is reachable, Gate 9 reports `blocked` and the pipeline halts.

The bootstrap auto-detects three reachability shapes (compose isolation = template default since v1.23.0; docker-bind = legacy single-container shape; Host Supabase = supabase runs on macOS host) and routes lifecycle commands accordingly. See [`/devshop/kit/docs/guide/local-supabase-compose-isolation.md`](../../../kit/docs/guide/local-supabase-compose-isolation.md) for the operator-facing architecture.

```bash
# Bootstrap local Supabase or report blocked.
bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up
# Outputs one of:
#   ok: local Supabase up; .env.local rewritten (backup at .preship-backup)
#   reused: local Supabase already running [(via cmd-relay)|(Host Supabase shape — lifecycle managed from macOS terminal)]
#   blocked: <shape-specific reason> — Refusing hosted-Supabase fallback (would pollute prod). Fix: <shape-specific recipe>
```

Shape-specific `blocked` messages:

- **compose isolation**: "cmd-relay on supabase-runner:9000 unreachable. Fix: from a macOS terminal, restart the runner (`docker restart <project>_devcontainer-supabase-runner-1`), or rebuild the devcontainer."
- **none reachable**: "no local Supabase reachable. Detection fell through (no compose.yml + supabase-runner/, no docker daemon, no listener at host.docker.internal:54321). Fix: rebuild the devcontainer with one of the supported shapes — compose isolation (template default), Host Supabase (`brew install supabase/tap/supabase` on macOS host), or run on a machine with Docker."

`ok` / `reused` are exit 0. `blocked` is also exit 0 (the script reports the situation; pre-ship's gate dispatcher decides the outcome). Non-zero exits (2-5) indicate hard failures (CLI missing, relay-driven `supabase start` failed, seed fixtures missing, env vars missing) — blocking if `$TOUCHES_UI`; warn otherwise.

**If preflight reads `blocked:` from the bootstrap script's stdout**:

1. Record `blocked (<shape-specific reason> — see fix recipe below)` against Gate 9.
2. Report back to the caller immediately with the script's full stdout as the fix recipe.
3. Do NOT run subsequent gates that depend on Gate 9 evidence (qa-walk artifacts).
4. `/ak-build` MUST refuse to advance to `/ship` with any `blocked` gate (existing contract — see Outcome semantics).

At the end of the pre-ship run (success or failure), call the teardown:

```bash
bash /devshop/kit/scripts/preship/supabase-bootstrap.sh down
```

`down` restores the original `.env.local` and stops local Supabase. Idempotent — safe to call even if `up` didn't run.

If pre-ship exits abnormally without `down` running, the operator can run `down` manually to recover. The sentinel file `apps/web/.env.local.preship-backup` indicates a partial state; its `.created` variant indicates `up` created `.env.local` from scratch (down deletes instead of restoring).

If blocked:

1. Record `blocked (Chromium not available — run the fix below)` against the four
   browser gates (3, 8, 9, 10).
2. Report back to the caller immediately with a fix recipe:

   ```
   Preflight failed: Chromium cannot launch.
   Likely missing: shared libraries (libnspr4, libnss3, libatk1.0-0t64, ...).

   Fix one of:
     - Rebuild devcontainer — template Dockerfile installs these libs.
     - Or: sudo pnpm --dir apps/web exec playwright install-deps chromium

   Blocking /ak-pre-ship. Re-run after the fix.
   ```

3. Do NOT run Gates 1–11. Exit here with the `blocked` summary.

### Deploy boundaries reminder

If `git diff --name-only origin/main...HEAD` shows changes under `supabase/migrations/**` or `supabase/functions/**`, the merge will trigger Supabase's auto-deploy workflows in parallel with the Vercel app deploy. Surface this reminder before gates run so the test plan flags any backwards-incompatible change:

- **Schema-mutating migrations** (rename, drop, NOT NULL without default, type change) race the app deploy. The PR description / test plan must either (a) mark the migration backwards-incompatible and gate `/ak-go-live` on the deploy-migrations workflow finishing first, or (b) split into two PRs (additive PR with dual-shape code paths first, mutating PR after). Default to (b) for prod-impact migrations.
- **Edge function changes** auto-deploy on push:main but the local-vs-deployed function code can diverge if the slow-job didn't exercise the path. The test plan must include either a slow-job E2E exercising the new path, or an explicit deploy-verification step.
- **Auth config changes** still need manual deploy via Management API or dashboard. Not auto-triggered by `git push`.

Full surface table + rollback semantics: `kit/docs/guide/conventions.md § Deploy Boundaries`. This is a reminder, not a gate — the structural enforcement lives in `/ak-spec` (which decides the test plan) and `/ak-go-live` (which orchestrates the merge).

If preflight passes, proceed to the gate sequence (canonical list below).

## Gates (canonical order + named IDs)

**This table is the single source of truth for pipeline ordering.** Code, docs, and
`review.md` entries SHOULD reference gates by **name** (e.g. `qa`, `design-review`) —
the position number is a label that re-enumerates here when the pipeline changes. When
a new gate is inserted (Phase 2 added `design-conformance` (ak) between `design-review`
and `qa`), update this one table; downstream refs using names stay stable.

**Gate naming convention**: the `Owner` column marks gates as `ak` (devshop-owned: a
devshop-native check or a devshop-authored skill like `/ak-check-docs-and-tests` /
`/ak-design-conformance`) or `—` (wraps a gstack skill invoked verbatim). Narrative
prose elsewhere in the devshop renders the same split inline as `docs-and-tests-review (ak)`
vs `review` so readers can tell at a glance which gates come from where.

| #   | Name                           | Owner | Title                                             | Scope                                                                                                                                           |
| --- | ------------------------------ | ----- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `docs-check`                   | ak    | Devshop docs diff review                          | when `kit/` or reference docs touched                                                                                                           |
| 2   | `metrics-check`                | ak    | Metrics coverage                                  | user-facing code PRs                                                                                                                            |
| 2b  | `rls-coverage`                 | ak    | RLS policy coverage for client writes             | when `supabase/migrations/**` or client API touched                                                                                             |
| 2c  | `slow-job-lifecycle`           | ak    | Slow-job CI active + structurally intact          | always (regression guard; slow-job ships active from day one per template-ci-overhaul, 2026-05-19)                                              |
| 2d  | `fast-job-local`               | ak    | CI fast-job equivalent (lint + tc + unit + build) | when `turbo.json` exists                                                                                                                        |
| 2e  | `migration-rollback-roundtrip` | ak    | Migration rollback round-trip                     | when diff touches `supabase/migrations/**`                                                                                                      |
| 2f  | `changed-tests-local`          | ak    | Cheap local test gates (parse + changed + smoke)  | when diff includes `apps/**`, `packages/{core,ui}/**`, `*.integration.test.ts`, `apps/*/e2e/*.spec.ts`, or `supabase/{migrations,functions}/**` |
| 2g  | `advisor-clean`                | ak    | DB hardening advisor lints (9 lints, pg_catalog probe) | when diff touches `supabase/migrations/**` or `supabase/functions/**`; requires project's `pnpm db:advisor` script (template-shipped 2026-05-20) |
| 3   | `responsive-theme`             | ak    | Responsive + theme capture                        | UI PRs only                                                                                                                                     |
| 4   | `simplify`                     | —     | `/simplify` pass                                  | always                                                                                                                                          |
| 5   | `docs-and-tests-review`        | ak    | `/ak-check-docs-and-tests`                        | always                                                                                                                                          |
| 6   | `review`                       | —     | `/review` (+ Greptile triage)                     | always                                                                                                                                          |
| 7   | `cso`                          | —     | `/cso` (security)                                 | always                                                                                                                                          |
| 8   | `design-review`                | —     | `/design-review`                                  | UI PRs only                                                                                                                                     |
| 8b  | `design-conformance`           | ak    | `/ak-design-conformance`                          | runs regardless of UI scope                                                                                                                     |
| 9   | `qa`                           | —     | `/qa` (functional walk)                           | always                                                                                                                                          |
| 10  | `benchmark`                    | —     | `/benchmark`                                      | UI PRs only                                                                                                                                     |
| 10b | `preflight-final`              | ak    | `/preflight` re-run (final attestation)           | when Gate 2d ran (same scope predicate)                                                                                                         |
| 11  | `convention`                   | ak    | Convention headers + hook-coverage                | always                                                                                                                                          |

## Dismissal Log (every gate, mandatory)

Every gate's output MUST include a `## Dismissals` section with exactly one of:

- Body `None` — the gate considered zero findings worth dismissing (default; most common).
- A bulleted list — findings the gate considered but chose not to act on, each with a
  `rationale:` field explaining why in one line.

**Why this exists**: gstack gates are advisory by design — they produce reports for human
judgment. Our autonomous pipeline used to treat "gate said pass" as sufficient, which let
silent dismissals slip through (e.g. `/qa` walking every screen but never exercising the
add-item flow, `/design-review` checking tokens without cross-referencing DESIGN.md §
Voice). The Dismissal Log forces each gate to make triage explicit: every finding
the gate saw is either fixed, escalated to `findings (N) pending`, or dismissed with
rationale. Silent "I didn't think this mattered" is no longer a path to `pass`.

Pre-ship aggregates all gates' Dismissals into `## Router Summary` at the top of
`review.md` before returning to the caller (see `## Router Summary aggregation` near the
end of this file).

### When adversarial review fires

Dismissal Log invokes the adversarial reviewer (via `kit/scripts/adversarial-review.sh`
with check-type `dismissalLog`) **only when a gate's `## Dismissals` body resolves to
something other than `None`**. The "is it `None`?" check is a **scoped section parse**
handled by `kit/scripts/preship/router-shim.sh`:

```bash
body=$(awk '/^## Dismissals$/{f=1; next} f && /^## /{exit} f' "$GATE_REPORT" \
       | tr -d '[:space:]')
[ "$body" = "None" ] && skip_adversarial_review=true
```

The scoped parse is mandatory — a bare `grep '^None$'` could false-positive on lines
anywhere else in the report (e.g. a finding description "None of the viewports failed").
Only the `## Dismissals` section body, whitespace-normalized, equalling exactly `None`
skips adversarial review. Everything else (including edge cases like a bulleted list
with the word "None" in a rationale) invokes the reviewer.

Rejection (weak / generic / suspicious rationale) fails the gate with outcome
`findings (N) pending` — the pipeline pauses like any other pending state.

### Escape hatches + tuning

- **`DEVSHOP_SKIP_ADVERSARIAL=1`** env var bypasses adversarial review entirely.
  Intended for tight iteration loops where a human is actively reviewing the output.
  Never set in CI or release pipelines. Single design point — do not add per-gate
  escape hatches.
- **`PRESHIP_ADVERSARIAL_TIMEOUT`** env var — per-call timeout for pre-ship adversarial
  calls. Default 120s (the commit-guard's 90s is tuned for a single bypass per commit;
  pre-ship may fire up to 11, so the per-call budget is distinct).

### Structured-output shortcut (parser shim)

Gates whose output is already structured in a way that mechanically categorizes findings
(notably `/cso` emitting JSON with
`severity: CRITICAL | HIGH | MEDIUM | TENTATIVE`) get an implicit dismissal mapping
via `kit/scripts/preship/router-shim.sh`:

- CSO `TENTATIVE` findings → auto-dismissed with `rationale: TENTATIVE per /cso
confidence tier (self-verified only)`.
- `/benchmark` metrics within threshold → not surfaced as findings at all (no mapping
  needed — the skill already filters).

The shim produces a rendered `## Dismissals` body that pre-ship treats like any other
gate's — adversarial review can still challenge the mechanical mapping if an explicit
gate run chooses to override it.

### Forward-compatibility (Phase 4)

`rationale:` is free-text today. Phase 4 (Finding Router — deferred) will add a
`disposition:` field adjacent to it (`fix-now` | `fix-before-ship` | `TODO` |
`spec-amendment` | `ignore`). Dismissal Log entries written now will extend, not
migrate — today's `rationale:` stays; `disposition:` adds.

## Gate 1: Devshop docs check

If the PR touches `kit/` or reference docs (`kit/docs/OVERVIEW.md`, `kit/docs/guide/`):

- Verify both reference docs are in sync
- Pause if they've drifted

## Gate 2: Metrics check

If the PR touches user-facing code (components, API wrappers, edge functions):

- Verify `posthog.capture()` calls exist for events in this feature's spec
- Cross-reference against `METRICS.md`
- **Pause if missing** — don't auto-advance on a user-facing PR without metrics

This gate is the validation step in the four-stage flow `/ak-spec` drafts → `/ak-implement` instruments → this gate validates → user confirms new events. Full canonical taxonomy: `kit/docs/guide/conventions.md § Metrics Lifecycle`.

## Gate rls-coverage (ak): RLS policy coverage for client writes

Mechanical check that every table written-to by client code through PostgREST (`from('table').insert/update/delete/upsert`) has a matching `CREATE POLICY` for that operation when the table has RLS enabled. Catches the silent class of failures lalista PR 5 hit (`items` had RLS enabled but no `for insert` policy, so the force-create flow's writes succeeded as zero-row no-ops at the client and produced no error — invisible in unit tests, invisible in `/cso`).

- Scope: runs when the diff against `origin/main` touches `supabase/migrations/**`, `packages/core/src/api/**`, `apps/web/app/**`, or `supabase/functions/**`. Otherwise `n/a (no migration or client API change)`.
- Out of scope: `WHERE` / `WITH CHECK` predicate semantics (an integration test against a live DB is the right tool), `SECURITY DEFINER` RPCs (intentionally bypass RLS — see `mark_item_bought` as the canonical example in `CLAUDE.md § Principle of least privilege`), and tests/E2E (admin client bypasses RLS).

Invocation:

```bash
bash /devshop/kit/scripts/preship/rls-coverage-check.sh "$(git rev-parse --show-toplevel)"
```

Outcomes:

- `pass` — every RLS-enabled table written by client code has a matching policy for the operation in use.
- `findings (N)` — N gaps. Stdout enumerates `<table> <op> (RLS enabled, no '<op>' policy)` and prints the canonical fix recipe (add the policy in a new migration, or reroute through a `SECURITY DEFINER` RPC, or use the service-role admin client as last resort).
- `n/a (no supabase/migrations directory)` — projects without Supabase, or pure-frontend changes.

**⚠ May change code (operator-applied fix in a new migration).** If the gate emits findings and the operator adds a migration, run `pnpm turbo run test:unit` after; if any integration tests exist they should be re-run too. The gate itself is read-only.

## Gate slow-job-lifecycle (ak): Slow-job CI active + structurally intact

Regression guard for the day-one-active slow-job (since `template-ci-overhaul`, 2026-05-19). Mechanical check that the project's `.github/workflows/ci.yml` slow-job hasn't been re-commented or hollowed out, and that the per-step empty-state guards / unguarded ambient signal / changes-job wiring stay in canonical shape. See `kit/docs/guide/conventions.md § Slow-Job Lifecycle` for the convention this gate enforces.

- Scope: always runs (no gating on threshold). The slow-job ships active from the template, so the invariant — and this gate — applies to every project that has a `.github/workflows/ci.yml`.
- Out of scope: actually running the slow job, validating test content, repairing the workflow YAML. Read-only check; operator applies fixes.

Invocation:

```bash
bash /devshop/kit/scripts/preship/slow-job-lifecycle-check.sh "$(git rev-parse --show-toplevel)"
```

Outcomes:

- `pass` — slow-job is active (uncommented); `if:` predicate carries both `github.event_name == 'pull_request'` and the `needs.changes.outputs.runtime == 'true'` gate; edge-runtime retry pattern wired; per-step `hashFiles()` guards present on Playwright + migration steps when the matching content is missing; `Start local Supabase` is unguarded (ambient health signal); `changes:` job wired with the `runtime` output + slow-job's `needs:` + `if:` consuming it; branch protection includes `slow`.
- `findings (N)` — N misconfigurations. Stdout enumerates each gap with the canonical fix recipe inline. Common gaps: stub re-commented, `if:` predicate missing the pull_request gate (rescoped Check 2 detects this even when the `changes:` job's `if:` matches elsewhere), retry pattern stripped, hashFiles guard absent on a content-less project (Check 4 — content-scoped), hashFiles guard accidentally added to `Start local Supabase` (Check 4b), `changes:` job missing or its `runtime` output not wired (Check 6), branch protection missing `slow` (Check 7).
- `n/a (no .github/workflows/ci.yml)` — projects without GitHub Actions CI.

**⚠ Branch-protection check is best-effort.** When `gh` CLI auth is missing or the repo isn't on GitHub yet, the protection check silently degrades (no finding emitted for that sub-check). Operators on a fresh devcontainer should re-run the gate after `gh auth login` to surface a real protection-state finding if any.

## Gate fast-job-local (ak): CI fast-job equivalent (lint + typecheck + unit + build)

Runs the project's CI fast-job locally so deterministic failures (a type error, a broken unit test, a lint regression) surface in the iterate-fix loop instead of after a CI round-trip. Pairs with `changed-tests-local` (next gate) — together they are the two layers of the standalone `/preflight` skill.

Position rationale: runs before `changed-tests-local` because lint/typecheck/unit are the cheapest deterministic checks; if they're red, no point spending another 5 min running Playwright. Runs before all LLM-mediated gates (`/simplify` onward) so 5 min of cheap fail-fast checks don't get hidden behind 25 min of ceremony.

- Scope: runs when `turbo.json` exists at the project root. Otherwise `n/a (no turbo.json — fast-job script assumes a turbo monorepo)`. Stack assumption (pnpm + turbo) matches the rest of the pre-ship infra.
- Out of scope: integration tests, E2E specs, dev-server lifecycle, or the slow-job matrix. Deferred to `changed-tests-local` (Layer 2) and CI.

Invocation:

```bash
bash /devshop/kit/scripts/preship/fast-job-local.sh "$(git rev-parse --show-toplevel)"
```

The gate runs four turbo tasks in sequence, each wallclock-bounded via `timeout --kill-after=10s`:

1. **lint** (cap: 120s) — `pnpm turbo run lint`
2. **typecheck** (cap: 120s) — `pnpm turbo run typecheck`
3. **test:unit** (cap: 180s) — `pnpm turbo run test:unit`
4. **build** (cap: 300s) — `pnpm turbo run build`

Combined floor cap: ~12 min wallclock total. In practice turbo's cache + parallelism shrinks this to ~1–3 min on warm caches.

Outcomes:

- `pass` — every step ran cleanly within budget.
- `findings (N)` — N steps surfaced failures. Each step's failure appears as a bullet with the canonical re-run command (`pnpm turbo run <task>`).
- `findings (N) [budget exceeded]` — at least one step hit its wallclock cap; CI fast-job will exercise it.
- `n/a (no turbo.json …)` — non-turbo project; pre-Phase-1 stub repos.
- `pass (skipped — adversarially reviewed)` — `git config devshop.fastJobSkipReason "<reason>"` is set and adversarial review (check-type `fastJobSkipReason`, Sonnet-routed) accepted the reason.
- `findings (1) pending` — bypass flag set but adversarial review FAILed the reason.

**Bypass:** `git config devshop.fastJobSkipReason "<why these are OK to skip locally>"` short-circuits the gate after adversarial review. Default REJECT — symmetric with `changed-tests-local`'s `devshop.localTestSkipReason`.

## Gate migration-rollback-roundtrip (ak): Migration rollback round-trip against local Supabase

Mechanical check that every migration's `-- ROLLBACK:` block applies cleanly against the local Postgres AND the forward migration re-applies on top of the rolled-back state. Catches the silent class home-os PR #26 (2026-05-16, migration 010 `tool_name` stray UPDATE) + #27 (2026-05-17, migration 011 `'decide'::card_state` cast against narrowed enum) both hit: rollback bugs invisible to `pnpm db:reset` / forward-apply gates because those don't exercise the rollback comment block. CI's slow-job catches them at ~10 min; this gate catches them in ~30s locally.

Position rationale: runs after `fast-job-local` (deterministic lint/typecheck/unit/build are cheaper fail-fast checks) and BEFORE `changed-tests-local`, so a rollback bug doesn't poison the test database mid-walk (changed-tests-local's E2E + integration specs read from the same local Postgres this gate round-trips).

- Scope: runs when `git diff --name-only --diff-filter=AM origin/main...HEAD` touches `supabase/migrations/**`. Otherwise `n/a (no migration changes in diff)`. Also `n/a` when no `supabase/migrations/` directory exists or when the directory is empty. Markerless migrations are NOT an n/a path — they surface as findings (see marker mandate in the loop below) per parity with `template/scripts/ci-rollback-explain.sh` (the `n/a (rollback convention not adopted)` path was dropped 2026-05-19 once the marker convention became mandatory devshop-wide).
- Out of scope: validating `WHERE` / `WITH CHECK` predicate semantics (integration tests do that), running against a remote DB, installing or starting the local stack (Phase 0's `supabase-bootstrap.sh` handles that — this gate assumes the stack is up).

Invocation:

```bash
bash /devshop/kit/scripts/preship/migration-rollback-roundtrip.sh "$(git rev-parse --show-toplevel)"
```

The gate probes both candidate DB endpoints — `host.docker.internal:54322` (compose isolation + host Supabase shapes) and `localhost:54322` (docker-bind legacy shape) — and uses the first that responds. Then, for each migration in lexicographic apply-order:

1. Migrations without a `-- ROLLBACK:` block → finding (mirrors `template/scripts/ci-rollback-explain.sh` loud-fail contract — markerless migrations get cascade-dropped by upstream rollbacks without re-apply, breaking the rest of CI). Migrations with nothing to undo can carry a `-- noop: forward is idempotent` body; the gate detects `noop:` and skips the rollback apply step but still re-applies forward, which is what closes the cascade-loss hole.
2. Migrations with an empty `-- ROLLBACK:` block → finding (recipe surfaces the noop escape hatch).
3. Apply the rollback SQL via `psql -v ON_ERROR_STOP=1` against the discovered DB URL.
4. Re-apply the forward migration via `psql -f` to verify the rollback is a true inverse.

Failures are collected (not short-circuited) so the operator sees every broken rollback in one pass.

Outcomes:

- `pass` — every migration with a rollback block round-tripped cleanly.
- `findings (N) — migration rollback round-trip failed` — N migrations have broken rollback or non-invertible state. Stdout enumerates each failure (`<file> rollback FAILED: <psql ERROR line>` or `<file> forward re-apply FAILED after rollback: <psql ERROR line>`) plus the fix recipe (make rollback defensive against iterative-rollback-and-reapply cascades; use `IF EXISTS`; survive narrowed enums; etc.).
- `n/a (no supabase/migrations directory)` — projects without Supabase.
- `n/a (no migration changes in diff)` — diff doesn't touch `supabase/migrations/**`.
- `n/a (no migration files in supabase/migrations/)` — empty migrations directory.
- `blocked (local Supabase Postgres unreachable …)` — Phase 0 should have started the stack; fix recipe: re-run `supabase-bootstrap.sh up` or restart the supabase-runner container from a macOS terminal.

**⚠ Read-only against the DB across the round-trip.** Each migration's rollback + reapply leaves the schema in the same state it started in (modulo Postgres txn isolation). No bypass flag — the gate is a 30-second deterministic check and rollback bugs are a known recurring class; resolving findings means editing the migration's `-- ROLLBACK:` block, not skipping the gate.

## Gate changed-tests-local (ak): Cheap local test gates (parse + changed + smoke)

Runs the cheap halves of integration + E2E test execution locally so a developer discovers a broken Playwright spec or a degraded local Supabase stack 30 seconds before pushing instead of 8–10 minutes after. The CI slow-job still runs the full matrix; this gate is the early-warning floor that fails fast on the subset of failures that don't need full multi-viewport / multi-project coverage. See `kit/docs/guide/conventions.md § Local Pre-Push Test Gates` for the convention this gate ships.

- Scope: runs when the diff against `origin/main` includes any of `apps/**`, `packages/core/**`, `packages/ui/**`, `*.integration.test.ts` (added/modified), `apps/*/e2e/*.spec.ts` (added/modified), `supabase/migrations/**`, or `supabase/functions/**`. Otherwise `n/a (no stack-needing paths in diff)`. Path classification is the same hardcoded table used by `path-classifier.sh classify` / `diff-needs-stack` and by `supabase-bootstrap.sh`'s D6 promotion logic — single source of truth.
- Out of scope: replacing the CI slow-job, running the full multi-viewport matrix, or managing `pnpm dev` lifecycle (delegated to Playwright's `webServer` block in the project's `playwright.config.ts`).

Invocation:

```bash
bash /devshop/kit/scripts/preship/changed-tests-local.sh "$(git rev-parse --show-toplevel)"
```

The gate runs four steps in order, each wallclock-bounded via `timeout --kill-after=10s`:

1. **Parse-check** (cap: 30s) — `pnpm exec playwright test --list` from the project's Playwright config root. Parse failure short-circuits before execution steps fire (no point running a config that won't load). This is the only place in the pipeline where the parse-check claim from `kit/ROADMAP.md` is actually wired.
2. **Changed E2E execution** (cap: 2 min) — collects `apps/*/e2e/*.spec.ts` files in `git diff --name-only --diff-filter=AM origin/main...HEAD`, runs them with `--project=chromium --max-failures=1 --workers=1` against the project's existing `webServer` block.
3. **Changed integration execution** (cap: 1 min) — collects `*.integration.test.ts` files in the diff, runs with `VITEST_INTEGRATION=1 pnpm vitest run <files>` against the local Supabase stack already brought up by preflight.
4. **Smoke set** (cap: 2 min) — when the diff touches `apps/**` or `packages/{core,ui}/**`, runs the convention-based smoke set: union of `apps/web/e2e/*-qa-walk.spec.ts` and `apps/web/e2e/qa-walk.spec.ts`. On budget hit, emits the triage line `found N specs; M ran, K deferred to CI` per `conventions.md § Local Pre-Push Test Gates`.

Combined floor cap: ~5 min wallclock total across all steps.

Outcomes:

- `pass` — every step ran cleanly within budget OR every step was a no-op (no changed specs and smoke set didn't apply).
- `findings (N)` — N steps surfaced failures. Each step's failure appears as a bullet with the canonical re-run command.
- `findings (N) [budget exceeded]` — at least one step hit its wallclock cap; the triage line `found N specs; M ran, K deferred to CI` appears as a bullet, and the deferred specs are recorded under `## Dismissals` with rationale `wallclock budget exceeded; CI will exercise these in slow-job`.
- `n/a (no stack-needing paths in diff)` — diff is pure-docs / outside the classifier's stack-needing globs.
- `pass (skipped — adversarially reviewed)` — `git config devshop.localTestSkipReason "<reason>"` is set and adversarial review (check-type `localTestSkipReason`, Sonnet-routed) accepted the reason.
- `findings (1) pending` — bypass flag set but adversarial review FAILed the reason; gate emits the reviewer's verdict.

**Bypass:** `git config devshop.localTestSkipReason "<why these are OK to skip locally>"` short-circuits the gate after invoking adversarial review on the reason. Same shape as `devshop.testReviewSkipReason` / `devshop.dirtyPushReason`. Default REJECT — passes require per-category engagement, no core-flow dismissal, plausible follow-up commitment, no security-boundary skips.

**Preflight contract:** the preflight Supabase bootstrap (`kit/scripts/preship/supabase-bootstrap.sh up`) reads the same path-classifier and `git config devshop.requireHealthyLocalStack` (default `when-relevant`) — when the diff is stack-needing AND the local stack is degraded, preflight promotes the legacy `pass-with-note` outcome to `blocked`, which halts the pipeline before this gate runs. Set `devshop.requireHealthyLocalStack never` to opt out (legacy `pass-with-note` behavior preserved).

## Gate advisor-clean (ak): DB hardening advisor lints

Mechanical replica of 9 Supabase Advisor lints against `pg_catalog` on the local stack. Catches the class of DB-hardening gaps codified in `kit/docs/guide/security.md § DB hardening — SQL conventions for Supabase projects`: `SECURITY DEFINER` functions without pinned `search_path`, RLS policies that call bare `auth.uid()` (per-row evaluation instead of initplan), unindexed foreign keys, multiple permissive policies for the same {role, op}, security-definer views, RLS-enabled tables with zero policies, RLS-disabled tables in `public`, extensions installed in `public`, and duplicate indexes.

Position rationale: runs after `changed-tests-local` (2f) — the slow-job preview gates already exercised the DB; the advisor probe is the last mechanical check before the LLM-mediated ceremony. Probing pg_catalog is cheap (~1s wall-clock vs the ~5 min tests above it); the slight ordering inefficiency vs running earlier is outweighed by the smaller table-renumber blast radius on insertion.

- Scope: runs when `git diff --name-only --diff-filter=AM origin/main...HEAD` touches `supabase/migrations/**` or `supabase/functions/**`. Otherwise `n/a (no migration or function changes in diff)`. Also `n/a` when the project has no `supabase/migrations/` directory, no `package.json`, or no `db:advisor` script (pre-2026-05-20 projects need the backfill recipe in `kit/docs/guide/security.md § DB hardening`).
- Out of scope: replicating Supabase's hosted-advisor billing/usage lints; validating data-shape constraints (integration tests do that); running against remote DB; installing or starting the local stack (Phase 0's `supabase-bootstrap.sh` handles that — this gate assumes the stack is up).

Invocation:

```bash
bash /devshop/kit/scripts/preship/advisor-clean.sh "$(git rev-parse --show-toplevel)"
```

Outcomes:

- `pass` — every lint returned zero findings (or the finding's lint name is annotated as `ADVISOR-EXEMPT(<lint_name>)` somewhere under `supabase/migrations/`).
- `findings (N)` — N gaps. Stdout enumerates each lint, the object(s) it flagged, and the canonical fix hint. Below the findings, a fix recipe pointer to `kit/docs/guide/security.md § DB hardening`.
- `n/a (no supabase/migrations directory)` / `n/a (no db:advisor script in package.json — backfill from template per ...)` / `n/a (no migration or function changes in diff)` — scope short-circuits.
- `blocked (local Supabase Postgres unreachable on ...)` — preflight's stack bootstrap didn't bring Postgres up. Fix: re-run `bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up` or restart `supabase-runner` from a macOS terminal.
- `blocked (advisor-probe failed): ...` — the probe itself errored (e.g. `pg` not installed in `node_modules`, or pg_catalog query syntax error against an unexpectedly-old Postgres). Fix: re-run `pnpm install` to restore the `pg` devDep; if it still fails, surface the probe error to the operator.
- `pass (skipped — adversarially reviewed)` — `git config devshop.advisorBypassReason "<reason>"` is set and adversarial review (check-type `advisorBypassReason`, Sonnet-routed) accepted the reason.
- `findings (1) pending` — bypass flag set but adversarial review FAILed the reason; gate emits the reviewer's verdict.

**Bypass:** `git config devshop.advisorBypassReason "<per-finding rationale + TODOS pointer>"` short-circuits the gate after adversarial review. Default REJECT — passes require per-finding engagement (which lint, which object, why the deviation is intentional, where the deferral is tracked). Generic "extension-in-public is fine" or "we'll fix it later" reasons fail. For per-migration exemptions, annotate the migration directly with `-- ADVISOR-EXEMPT(<lint_name>): <reason>` (markers are scanned from `supabase/migrations/**`) — that scopes the exemption to one lint instead of the whole repo.

## Gate 3: Responsive + theme check (UI PRs only)

- If PR doesn't touch UI files (`components/`, `app/`, `packages/ui/`) → record `n/a (no UI changes)` and skip.
- If Phase 0 preflight flagged Chromium as unavailable → this is `blocked` (not `skipped`, not `n/a`). See preflight recovery.

Verify the app at 4 combos:

- 375px light, 375px dark, 1440px light, 1440px dark

**Capture evidence screenshots** to `specs/<feature>/screenshots/` — one per combo per primary screen. File convention: `<screen>-<viewport>-<theme>.png`, e.g. `signin-1440-light.png`. This directory is gitignored (see root `.gitignore § specs/*/screenshots/`) — it holds per-gate audit evidence, regenerable on every pre-ship run. The corresponding _hero_ shots, which are committed, come later (see "Capture hero screenshots" at the bottom of this file).

Check for:

- Overflow/scroll issues
- Unreadable text
- Untappable buttons (min 44px touch target)
- Hardcoded colors not using theme tokens
- Broken layouts

**Pause if any issues found.**

### Evidence enforcement (mandatory before declaring `pass`)

A gate that runs one of four combo-captures and reports `pass` hides the other three failures. Gate 3 MUST verify evidence on disk before returning `pass`.

**Primary screens** — derived from the PR's diff against `origin/main`:

```bash
# Any new page.tsx under apps/web/app/ is a primary screen.
# Strip the (route-group) folders (like "(auth)") to get the canonical slug.
PRIMARY_SCREENS=$(git diff --name-only --diff-filter=A origin/main...HEAD \
  | grep -E '^apps/web/app/.*/page\.tsx$' \
  | sed -E 's|apps/web/app/\(\w+\)/||;s|/page\.tsx$||;s|^/||' \
  | grep -v '^$')
```

For each primary screen, require all 4 combos in `specs/<feature>/screenshots/`:

- `<screen>-375-light.png`
- `<screen>-375-dark.png`
- `<screen>-1440-light.png`
- `<screen>-1440-dark.png`

**Outcome mapping**:

| State                                                                                                                                                                                                                                               | Gate 3 outcome                      |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| All 4 combos × each primary screen present                                                                                                                                                                                                          | `pass`                              |
| Any combo missing, AND `review.md § Gate 3` has an explicit blocker entry naming the specific screen + combo (e.g. "375×dark for /sign-in skipped because the project's dark-mode bootstrap is deferred — tracked in PLAN.md / PRODUCT-ROADMAP.md") | `findings (N) [blocker documented]` |
| Any combo missing, no blocker doc                                                                                                                                                                                                                   | `blocked (evidence incomplete)`     |

Never silently `pass` when evidence is incomplete. The blocker-documented escape is for genuine deferrals (e.g. dark-mode bootstrap not yet wired), not for "ran out of time."

**Implementation sketch** (embed in the gate's verification script):

```bash
MISSING=""
while IFS= read -r screen; do
  [ -z "$screen" ] && continue
  for vp in 375 1440; do
    for theme in light dark; do
      path="specs/$FEATURE/screenshots/${screen}-${vp}-${theme}.png"
      [ -f "$path" ] || MISSING+="  $path\n"
    done
  done
done <<< "$PRIMARY_SCREENS"

if [ -n "$MISSING" ]; then
  # Check for blocker documentation in review.md § Gate 3
  BLOCKER=$(awk '/^## Gate 3/,/^## Gate [0-9]+/' "specs/$FEATURE/review.md" 2>/dev/null \
    | grep -i 'blocker\|deferred\|skipped' || true)
  if [ -n "$BLOCKER" ]; then
    echo "findings (evidence incomplete — blocker documented in review.md)"
  else
    echo "blocked (evidence incomplete — capture missing shots or document blocker in review.md § Gate 3)"
    echo -e "Missing:\n$MISSING"
    exit 1
  fi
else
  echo "pass"
fi
```

## Gate 4: /simplify

Invoke `/simplify` via Skill tool. Code quality pass (reuse, efficiency, dead code).

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 5: /ak-check-docs-and-tests

Invoke `/ak-check-docs-and-tests` via the Skill tool. Audit-time docs + tests review.

This gate is the **first audit moment** in the canonical two-audit model
(per `CLAUDE.md § Non-Negotiables` — "Adversarial Layer 2 reviews fire at
audit moments, not per commit"). The orchestrator computes the commit range from
`specs/<feature>/review.md`'s latest `## Audit N` section's
`<!-- audited-at: <SHA> -->` stamp, dispatches `/ak-docs-review` and
`/ak-tests-review` as parallel `Agent` calls with per-file sinks under
`specs/<feature>/gates/audit-N-{docs,tests}.md`, concatenates them into a
new `## Audit N` section with structured findings. First-time runs default
to `origin/main..HEAD` and emit `## Audit 1`.

Outcome mapping:

- `pass` — orchestrator reports zero high-severity findings (medium / low
  may exist; they record but don't halt).
- `findings (N) pending` — at least one high-severity finding. Pipeline
  pauses. Operator fixes (or escalates) before continuing.
- `n/a` — never applies; the gate runs on every PR.

Report only — does not change code. Sub-skills do not auto-fix; the
operator decides what to do with each finding.

## Gate 6: /review

Invoke `/review` via Skill tool. Staff engineer code review.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 7: /cso

Invoke `/cso` via Skill tool. Security audit. Reports findings, pauses for user to decide fixes.

**⚠ May change code** (user-directed fixes). After any fixes:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 8: /design-review (UI PRs only)

- If PR doesn't touch UI files → `blocked (n/a per scope: no UI files in diff —
apps/**, packages/ui/**, components/** all untouched)`. The `blocked` outcome is
  load-bearing — see § Outcome semantics § `n/a` is not legal for LLM-mediated
  gates. The rationale is checked by `dismissalLog` adversarial review when the
  caller dismisses the resulting `blocked` count; generic "logic-only PR" without
  a path-glob claim FAILs.
- If Phase 0 preflight flagged Chromium as unavailable → `blocked (Chromium not
available — see preflight recovery)`.

Invoke `/design-review` via Skill tool.
Visual audit with fix loop — finds issues, fixes in source, commits atomically.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate design-conformance (ak): DESIGN.md contract check

**Rule** (see `kit/docs/guide/conventions.md § DESIGN.md as Contract`): treat DESIGN.md as a contract. Extraction failure (no normative claims surfaced because DESIGN.md is absent or purely aspirational) is **non-blocking** and resolves to `n/a`. A claim violated by the implementation is **blocking** and resolves to `findings (N) pending`. Extraction is cached by `sha256(DESIGN.md)` in `specs/<feature>/design-claims.json.sha256`; when DESIGN.md changes, re-extract and adversarially review the diff so claim drift stays auditable.

- If no `DESIGN.md` at project root → `n/a (no DESIGN.md)`.
- Runs regardless of `$TOUCHES_UI` — a non-UI PR can still contradict a
  DESIGN.md claim (e.g. an error message that violates the voice doctrine).

Invoke `/ak-design-conformance` (devshop skill — see
`/devshop/.claude/skills/devshop/design-conformance/SKILL.md`). Covers axes
`/design-review` skips: voice/copy canonical-example matching, explicit
token values, imperative rules, component-contract claims.

Orchestrated via:

```bash
bash /devshop/kit/scripts/preship/design-conformance.sh run \
  --feature "$FEATURE" \
  --design  DESIGN.md
```

The script extracts normative claims from DESIGN.md (LLM, cached by
sha256), verifies each against the implementation (grep for explicit
values, LLM-judgment for copy/imperative claims), and writes a report to
`specs/$FEATURE/design-conformance-report.md` including a `## Dismissals`
section per the Phase 3 contract.

Outcome mapping:

- `pass` — all claims honored.
- `findings (N) pending` — one or more claims need human review (copy
  judgment) or code changes (missing token value).
- `n/a` — no DESIGN.md, OR DESIGN.md contains only aspirational prose and
  the extractor returned zero normative claims.

**⚠ May surface findings in copy/code.** If the gate emits
`findings (N) pending`, the pipeline pauses; a human (or follow-up agent
loop) resolves each. No test:unit checkpoint — this gate inspects contract
conformance, it doesn't change code directly.

Cross-ref: `/ak-design-conformance` vs `/design-review` (gstack) — the
latter covers visual hierarchy / spacing / AI-slop; this gate covers
DESIGN.md as a contract. Different axes, different findings; both run.

## Gate 9: /qa

- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.
- Phase 0's Supabase bootstrap determines which backend Gate 9 uses:
  - `ok` / `reused` → local Supabase; use seeded fixtures (`alice@test.local` / `bob@test.local` / etc.).
  - `unavailable` → admin-API against hosted; create test users with `email_confirm: true` to bypass Supabase's email-rate-limit. Clean up in `afterAll`.

Invoke `/qa` via Skill tool. Browser-based QA — discovers bugs, fixes source code, commits per bug, re-tests. Has its own internal fix loop.

Runs AFTER /design-review so it browser-tests the visually polished code. This is the final "does this actually work in a browser" pass before /ship.

**Form-fill technique on WebKit**: when the walk targets a WebKit project AND fills a controlled input (login, sign-up, password reset — anything `<input value={state} onChange=…>`), use `pressSequentially + toHaveValue` instead of `fill` — bare `fill` resolves before React syncs the DOM value and the form submits empty on WebKit. Full pattern + rationale: `kit/docs/guide/conventions.md § Playwright + controlled inputs on WebKit`. `/ak-tests-review` flags new specs that use bare `.fill()` against controlled inputs.

### Outcome contract (three outcomes — `skipped` is not one of them)

Gate 9 MUST emit exactly one of:

- **`pass`** — happy-path walk completed end-to-end. Evidence: a Playwright trace OR a structured log at `specs/<feature>/qa-walk.log` showing the full sequence (URL → assertion → next URL → ...) with timestamps. Without evidence, `pass` is not available.
- **`findings (N) fixed`** / **`findings (N) pending`** — walk found issues; `/qa` fixed what it could. Each finding recorded in `review.md § Gate 9` with repro + commit.
- **`blocked (<reason>)`** — walk couldn't complete. Requires an explicit reason (tooling gap, external dependency unreachable, harness not yet written). Writes fix recipe to `review.md § Gate 9` so the next run knows how to clear the block.

Never `skipped`. If Gate 9 simply wasn't exercised, the correct outcome is `blocked` with the reason. `pass` on an unexercised gate is the failure mode that landed lalista PR #10's Gate 9 in a false-positive state.

### No synthetic-harness substitution

If the local stack is degraded — auth schema errors, missing migrations, supabase-runner unreachable — the correct outcome is **`blocked`**, with the shape-specific fix recipe surfaced to the caller. Phase 0 preflight already routes degraded-stack-on-stack-needing-diff to `blocked` per the `requireHealthyLocalStack` config (default `when-relevant`); if you reach Gate 9 with the stack still degraded, that's the contract failing and you must report `blocked` to the caller, not improvise around it.

**Do NOT**:

- Inject the component's DOM directly into a page that doesn't normally render it (e.g. mounting the success-toast on the public landing because `/list` requires auth).
- Spin up an ephemeral Playwright spec that bypasses the live data path with stubs / fixtures / `JSON.stringify` mocks of API responses, then claim that spec satisfies Gate 9.
- Self-report `pass` with a "substituted with synthetic harness" note in `review.md` — that's the exact failure mode this section forbids.

**Why**: synthetic harnesses look like evidence in screenshots and qa-walk logs but exercise zero of the real code path under test. They produce captures that mislead reviewers (toast rendering on the wrong page, fixture data instead of server-resolved state) and let regressions ship — the whole point of /qa is the live walk, not a re-render of the component.

The honest path on a degraded stack is to:

1. Surface `blocked` with the bootstrap script's full stdout as the fix recipe.
2. Let `/ak-build` halt before `/ship` (existing contract).
3. Resume after the operator clears the block (`pnpm db:start`, devcontainer rebuild, etc.).

If the operator deliberately wants to bypass the live walk for a low-risk diff (CSS-only token change, docs-only PR), that's what `git config devshop.requireHealthyLocalStack never` is for — explicit opt-out at the project level, judged by the adversarial-review chain. Inventing a substitute and self-reporting `pass` is not the supported path.

Codified from lalista PR 53 (2026-05-08): the initial pre-ship subagent encountered "Database error querying schema" (turned out: stack was simply down, not corrupted), substituted a DOM-injection harness mounting `ConfirmationToast` on the public landing page, and self-reported `pass`. The user caught it on review when the hero PNGs showed the toast on the marketing page. The follow-up commit replaced synthetic captures with authentic /list captures after `pnpm db:start` brought the stack up cleanly.

### Core user story artifact assertion (mandatory per spec)

`/ak-spec` requires every spec to declare a `## Core user story` section (2–4
imperative verbs describing the product's primary flow end-to-end, or `N/A`
with reason for non-user-facing PRs). Gate 9 enforces that **every verb in
the declared story produces a verifiable artifact** proving the action
completed — not just that it was attempted.

**Why this exists**: the lalista core-flows PR shipped with a qa-walk trace
reading _"add-sheet open+Escape"_ — `/qa` opened the add-item sheet and hit
Escape without completing the core flow, but the gate reported `pass`
because no assertion was broken. The story/artifact contract closes this
"silent no-op" failure mode by requiring observable-outcome evidence per
verb.

**Artifact location + format** (the qa-walk harness must emit these):

- Path: `specs/<feature>/qa-walk/verb-<N>-<slug>.<ext>`
- `<N>` = 1-based verb index from the spec's `## Core user story` list
- `<slug>` = short filesystem-safe label derived from the verb (caller's choice)
- `<ext>` = one of `png` (screenshot), `json` (structured state capture)

**Capture via the gstack `browse` daemon**:

```bash
$B screenshot "specs/<feature>/qa-walk/verb-${N}-${slug}.png"
# OR structured state:
$B js "JSON.stringify({test: ...})" > "specs/<feature>/qa-walk/verb-${N}-${slug}.json"
```

**Enforcement** (runs BEFORE reporting Gate 9's outcome):

```bash
bash /devshop/kit/scripts/preship/verify-story.sh verify-all \
  --feature "$FEATURE" --spec "specs/$FEATURE/spec.md"
```

`preship-verify-story.sh verify-all` parses the spec's `## Core user story`
section, walks each verb, and checks that the matching artifact exists AND
is non-empty AND (for screenshots) differs from the pre-action baseline.
Missing / empty / unchanged artifact → exit non-zero → Gate 9 outcome
`blocked (core user story verb N not exercised — missing artifact
specs/<feature>/qa-walk/verb-N-<slug>.png)`.

**When the spec's Core user story is `N/A`**:
The script recognizes `N/A` / `N/A — <reason>` bodies and skips artifact
assertion for that PR. Example: a migration-only PR with body
`N/A — database migration only; no user flow added or modified.` → Gate 9
emits `pass` (or `n/a`) without artifact requirement.

The N/A rationale is adversarially reviewed (`coreUserStoryNaReason`) —
interpretive prose ("no visible UI change", "cosmetic only") fails;
verifiable file/path claims ("diff is `supabase/migrations/**` only", "no
`.tsx` files modified") pass. On reject, `verify-story.sh` propagates the
reviewer's `FAIL: …` verdict on stdout and returns non-zero, so Gate 9
surfaces `blocked` with the rejection text as the fix recipe in
`review.md § Gate 9`.

**Outcome mapping** (adds to the Outcome contract above):

| State                                                                                         | Gate 9 outcome                                               |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| All verbs have artifacts (present, non-empty, screenshot diffs from baseline)                 | `pass` (if other contract items also met)                    |
| Any verb missing an artifact                                                                  | `blocked` with specific verb call-out + fix recipe           |
| Spec has no `## Core user story` section                                                      | `blocked (spec missing Core user story — rerun /ak-spec)`    |
| Spec's `## Core user story` is `N/A — <reason>`                                               | Skip artifact assertion; outcome follows the normal contract |
| Spec declares N verbs but the qa-walk log doesn't mention any of them by name (narrative gap) | Gate 9 surfaces as `findings (1)` to flag the mismatch       |

### Fault-injection sub-step (Tier A2 surfaces)

Happy-path `/qa` only exercises the success path. Banner / Retry / Undo
affordances that render under failure (Tier A2 surfaces per
[`kit/docs/guide/latency-feedback.md`](../../../../kit/docs/guide/latency-feedback.md))
can have overlay-intercept, z-index, or focus regressions that ship past
this gate. Worked incident: lalista PR #49's `AddItemSheet` overlay
intercepted the Undo button under banner state — invisible to `/qa`'s
happy-path walk, only caught by Playwright slow-job CI after merge.

For each detected Tier A2 surface, force the target network call to fail
via `page.route(<pattern>, r => r.abort())` and assert the banner +
Retry + Undo render and are clickable. Implementation lives at
`kit/scripts/preship/fault-injected-qa.sh`; bats coverage at
`kit/tests/preship-fault-injected-qa.bats`.

**Detection** (two-tier):

1. **Primary** — parse the spec's `## Surface mapping` table (per
   `latency-feedback.md § Applying the framework to your project`) for rows where
   `Tier == A2`. Use this whenever the spec is convention-compliant.
2. **Fallback** — when the spec table is absent or has zero A2 rows,
   heuristic-grep the diff (or `apps/**` + `packages/**`) for
   `useOptimisticMutation({ failureMode: 'banner', … })` call sites.
   Each call site becomes one detected surface; slug derived from
   filename.

Spec-table presence suppresses the fallback (spec is authoritative).

**Harness convention** — each detected slug expects a Playwright spec at
`apps/web/e2e/fault-injected/<slug>.spec.ts`. Recipe (drop-in template,
adapt selectors + route per surface):

```ts
// What: Fault-injected coverage for <surface-name> (Tier A2).
// Why: happy-path /qa never exercises the banner state — overlay /
//      z-index regressions ship past Gate 9 without this.
import { expect, test } from "@playwright/test";

test("<surface> shows banner + clickable Retry/Undo on RPC abort", async ({ page }) => {
  // Sign in / navigate to the surface as the QA walk would.
  await page.goto("/...");

  // Abort the target route BEFORE triggering the mutation.
  await page.route("**/<route-from-spec-Notes-column>", (r) => r.abort());

  // Trigger the optimistic mutation (form submit, button click, etc.).
  await page.getByRole("button", { name: "Save" }).click();

  // Banner renders.
  const banner = page.getByRole("alert").filter({ hasText: /could not save/i });
  await expect(banner).toBeVisible();

  // Retry + Undo are CLICKABLE (not just visible — `.click()` would throw
  // if an overlay intercepted; `trial: true` is the safest assertion).
  await banner.getByRole("button", { name: /retry/i }).click({ trial: true });
  await banner.getByRole("button", { name: /undo/i }).click({ trial: true });
});
```

The `trial: true` assertion is the load-bearing check — Playwright runs
the full actionability cascade (visible, stable, receives events) and
throws if anything intercepts the click. That's the lalista PR #49 bug
detector.

**Outcome mapping** (additive to the Outcome contract above):

| Sub-step result                          | Gate 9 effect                                                                |
| ---------------------------------------- | ---------------------------------------------------------------------------- |
| `pass (no Tier A2 surfaces in scope)`    | No effect — Gate 9 outcome stands on the happy-path walk                     |
| `blocked (missing harness: <slug-list>)` | Gate 9 escalates to `blocked` with the harness recipe in `review.md § Gate 9` |
| `pass`                                   | No effect — Gate 9 outcome stands                                            |
| `findings (N) — failed: <slug-list>`     | Gate 9 outcome at least `findings`, count adds to any existing findings      |

The `pass (no Tier A2 surfaces in scope)` outcome is deterministically
computed (spec-table parse + grep yield zero rows) — it's not operator
prose. The convention forbidding `n/a` on LLM-mediated gates applies to
Gate 9 itself; this sub-step's scope-exempt `pass` rolls up cleanly to
the parent gate's contract.

There is no bypass flag. If a Tier A2 surface is in the diff and no
harness exists yet, the right move is to write the harness (15-line
recipe above) — `blocked` is the correct outcome until then.

### User-state matrix (mandatory for auth-touching PRs)

A walk that only exercises one user-state (existing-confirmed-user with correct password) hides every other failure mode real users hit. For PRs touching auth (`apps/web/app/(auth)/`, sign-in/sign-up/onboarding code paths, Supabase auth config), Gate 9 MUST exercise all five rows below — or document in `review.md § Gate 9` why a specific row is deferred to a later PR.

| User-state                       | Why it matters                                                     | How to exercise                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| Unconfirmed signup               | Default Supabase config; new users ALWAYS hit this first           | Create user with admin API `email_confirm: false`; walk until UI surfaces "check your email" awaiting-confirmation state.     |
| Wrong password for existing user | Real users mistype passwords constantly                            | Existing confirmed user + intentionally wrong password; assert friendly error, no silent fallback into signup or other flows. |
| Rate-limited signup              | Free-tier default `rate_limit_email_sent: 2/hour` trips in testing | Trigger 3 signups in rapid succession; 3rd must show a friendly rate-limit message (not a raw Supabase error or silent hang). |
| Existing user, correct password  | The canonical happy path                                           | Existing confirmed user + correct password → sign-in success → lands on expected destination (onboarding or home).            |
| Session expired mid-onboarding   | Supabase tokens expire; RSC `getUser()` returns null               | Create user, sign in, admin-delete session, attempt to continue onboarding; assert clean redirect to `/sign-in`.              |

Each row's harness lives in the project's `e2e/helpers/` (or, post-convention, `@devshop-template/auth-ux`). Harness helpers use the admin API to set up each state deterministically — no relying on hosted Supabase's email-confirmation timing or rate-limit cooldowns.

### Friendly-error coverage — existing-user-via-signup-fallback

Supabase's user-enumeration-prevention returns `data.user.identities: []` (empty array) when a signup attempt hits an already-confirmed email. Naïve sign-in pages fall into "awaiting confirmation" UI — which is misleading for an existing-user-with-wrong-password scenario.

Gate 9 MUST include a case where the test signs up with an email that already has a confirmed account (using the wrong password), and asserts:

- The UI does NOT show "check your email" awaiting-confirmation state.
- The UI surfaces a friendly "account already exists — try signing in or reset your password" message.
- `data.user.identities.length === 0` is checked in the app code before branching into awaiting-confirmation UI.

Prior art: lalista commits `31b5637` (`awaitingConfirmation` UI + `friendlyAuthError` helper) + `e1ceb9c` (identities-check follow-up) — both carried as `[verification-debt]` in lalista's `TODOS.md` awaiting the v1 "Auth UX conventions" helper, per the refactor-to-adopt pattern in `kit/notes/dual-goal-project-principles.md § 4`. Once that helper ships, this matrix row is how Gate 9 verifies the helper did its job.

### Cross-reference to ROADMAP

`kit/ROADMAP.md § v1 § Auth UX conventions` defines the project-side patterns (awaiting-confirmation card, friendly error helper, identities-check, password-reset route). Gate 9's matrix above is how pre-ship verifies those patterns handle each user-state correctly. The two are paired — the convention ships the UI; the gate verifies it works.

### Evidence requirements recap

- **`pass`** needs `specs/<feature>/qa-walk.log` (structured trace) OR a Playwright trace artifact. The log format mirrors the walk sequence — each line is `<ISO timestamp> <URL> <action> <assertion> <result>`.
- **`findings (N)`** needs per-finding entries in `review.md § Gate 9` with repro steps.
- **`blocked`** needs the reason + fix recipe in `review.md § Gate 9`.

Phase 6's final sweep (Fix D) cross-checks these artifacts against any Gate-9-related checkboxes in the PR body.

## Gate 10: /benchmark (UI PRs only)

- If PR doesn't touch UI files → `n/a (no UI changes)`.
- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.

Invoke `/benchmark` via Skill tool.
Performance regression check (Core Web Vitals + load time). Report only.

## Gate preflight-final (ak): /preflight re-run as end-of-chain attestation

Runs `/preflight` (= `fast-job-local` Gate 2d + `changed-tests-local` Gate 2f) one more time, after all code-changing gates (`/simplify`, `/review`, `/cso`, `/design-review`, `/qa`) have finished editing.

**Why a second run is needed.** Each code-changing gate already self-verifies via the stuck protocol (`pnpm turbo run test:unit` after the gate's edits — see "Stuck protocol" below). That covers unit-test breakage from the gate's own changes. What it doesn't cover:

- **Integration / E2E regressions.** Stuck-protocol unit re-checks don't run integration or Playwright specs; a `/design-review` tweak that breaks an E2E spec wouldn't surface until CI's slow-job.
- **Cross-gate interaction breakage.** `/simplify` change A may individually pass; `/design-review` change B may individually pass; A+B together may break a test neither gate verified.

The end-of-chain `/preflight` closes both gaps with one ~5–10 min run against the final composed state.

- Scope: runs when Gate 2d (`fast-job-local`) ran — same predicate (`turbo.json` exists). Otherwise `n/a`.
- Out of scope: introducing new findings unrelated to test status (covered by earlier gates); replacing CI's slow-job.

Invocation: invoke `/preflight` via the Skill tool. The skill emits an aggregated outcome across both underlying scripts and a combined `## Dismissals` body.

Outcomes:

- `pass` — final-state attestation succeeded.
- `findings (N)` — N findings; pipeline pauses. Operator decides whether to fix-in-place (then re-run /preflight) or revert the offending code-changing-gate commit.
- `findings (N) [budget exceeded]` — deferred to CI; emits the same triage line as Gate 2f.
- `n/a` — Gate 2d was `n/a`; this gate is symmetric.

**No bypass at this gate.** The earlier `fast-job-local` and `changed-tests-local` gates accept `devshop.fastJobSkipReason` / `devshop.localTestSkipReason` for the front-of-chain runs; the final attestation is non-skippable because it's the last deterministic safety net before convention check + hero shots. If you must bypass, do so at the earlier gates — both bypasses also suppress this gate's re-run (Layer 1 or Layer 2 skipped → /preflight reports `pass (skipped — adversarially reviewed)` for the matching layer here).

## Gate 11: Convention check

Run the mechanical check first, then apply judgment:

```bash
bash kit/scripts/commit-hooks/check-file-headers.sh main
```

Review any flagged files — skip config-like or trivial files (single export, <50 lines). Then verify:

- File headers (`// What:` / `// Why:` / `// Does NOT:`) exist on non-trivial files (>1 export or >50 lines) under `src/` or `app/` (see `kit/docs/guide/conventions.md § Code Structure`)
- JSDoc on exported functions
- Every new migration file has a `-- ROLLBACK` comment block — **pause if missing**
- Every new migration that references `auth.users(id)` has an explicit `ON DELETE` clause (`CASCADE` / `SET NULL` / `RESTRICT`) — implicit `NO ACTION` silently blocks user deletion. Mechanical grep of staged `supabase/migrations/**` for `references auth.users` lines lacking `on delete`. **Pause if missing.** See `kit/docs/guide/conventions.md § ON DELETE on auth.users FK references`.
- Every PR that adds a `subscribeTo<X>` helper or `postgres_changes` listener also adds the corresponding table to `supabase_realtime` publication via a migration (`alter publication supabase_realtime add table <name>;`). Without it, cross-session delivery silently no-ops. **Pause if missing.** See `kit/docs/guide/conventions.md § Realtime publication setup`.
- Backlog items appear to be in the correct file per routing guide in `kit/docs/guide/ § Shared Conventions`
- No completed items left in `PRODUCT-ROADMAP.md` or `kit/ROADMAP.md` — if this PR ships a roadmap item, remove the entry and log the completion in `BUILD-LOG.md`

## Router Summary aggregation

After all gates run (pass or findings), BEFORE capturing hero screenshots, aggregate
every gate's `## Dismissals` section into a single `## Router Summary` block at the top
of `specs/<feature>/review.md`. Prepend an `audited-at` stamp on the very first line —
substitute the current HEAD SHA inline (`git rev-parse HEAD`), do not write the literal
`$(...)` to the file. The stamp is the contract `/ak-build` Phase 5.8's
range-determination step reads: it tells 5.8 which commits landed AFTER pre-ship and
must therefore be re-audited for test-coverage. Without the stamp, 5.8 halts loudly
("review.md missing 'audited-at' frontmatter — re-run /ak-pre-ship to regenerate").

```markdown
<!-- audited-at: 80485cb1234567890abcdef1234567890abcdef -->

## Router Summary

| Gate                      | Dismissals                      | Adversarial review            |
| ------------------------- | ------------------------------- | ----------------------------- |
| `docs-check` (ak)         | None                            | skipped (scoped parse = None) |
| `metrics-check` (ak)      | None                            | skipped                       |
| `design-review`           | 1 polish-tier finding           | accepted                      |
| `design-conformance` (ak) | 1 voice drift                   | accepted                      |
| `qa`                      | 2 low-severity nits             | accepted                      |
| `cso`                     | 3 auto (TENTATIVE, parser shim) | skipped (mechanical mapping)  |
| _...all other gates..._   |                                 |                               |

**Total dismissed findings**: 6 (3 LLM-reviewed, 3 shim-mapped, 0 rejected).
```

- `Dismissals` column: short description of what was dismissed, or `None`.
- `Adversarial review` column: `skipped` (scoped parse = None or shim-mapped), `accepted`,
  `rejected (see gate)`, or `bypassed (DEVSHOP_SKIP_ADVERSARIAL)`.
- If **any** adversarial review returned `rejected`, pre-ship reports `findings (N)
pending` to the caller for that gate — the Router Summary is the audit trail, not
  the verdict.

This section is the provenance trail for what the pipeline chose NOT to surface as a
pending finding — a reviewer reading the PR later can grep here to see each dismissal
and its reasoning.

## Capture hero screenshots

After all gates pass (or findings fixed), capture 1–2 **hero** screenshots per primary screen to `specs/<feature>/hero/`. These are committed with the feature and surface in the PR body + `BUILD-LOG.md` as the durable visual record.

**Screenshot Routing** (see `kit/docs/guide/conventions.md § Screenshot Routing` for the full decision flow):

| Location                       | Tracked? | Who writes       | Purpose                                                     |
| ------------------------------ | -------- | ---------------- | ----------------------------------------------------------- |
| `specs/<feature>/hero/`        | ✅       | this gate, human | Durable PR-body + BUILD-LOG shots; 1–2 per primary screen   |
| `specs/<feature>/screenshots/` | ❌       | gates 3, 8, 10   | Per-gate regenerable evidence (4 viewport/theme combos)     |
| `specs/<feature>/qa-walk/`     | ❌       | Gate 9           | Per-verb artifacts proving each Core user story verb worked |
| `/screenshots/` (repo root)    | ❌       | human            | Dev-context shots shared in chat / Slack / bug reports      |

Never write gate-produced screenshots to repo root; `/Screenshot*.png` is gitignored to catch macOS default-named drops without polluting `git status`.

**Defaults:** `1440×light` for each key user-facing screen in the PR (sign-in, onboarding, list view, etc.). Filename convention: `<screen>.png` (no viewport/theme suffix — they're all 1440×light by default; deviate with a suffix when needed, e.g. `list-dark.png` if dark mode is the feature).

**When to skip:** non-UI PRs (API-only, infrastructure, docs), and UI PRs where the happy-path can't be reached from the workspace because of a real external constraint (e.g. hosted Supabase rate-limits a signup flow when the local stack is unavailable, or the screen requires a third-party redirect the firewall blocks). Document the reason in `review.md` instead of leaving a gap. "Workspace can't run Playwright / `pnpm dev`" is no longer a valid skip reason — Chromium ships baked-in via apt (`/usr/bin/chromium`, set as `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`) and `fonts.googleapis.com` is firewall-allowlisted. Treat browser-gate blocks as real tooling-broken signals worth fixing, not expected outcomes.

**Capture mechanics** (via the gstack `browse` skill + the `capture-screenshot.sh` wrapper):

```bash
# Navigate, capture — repeat per screen. Wrapper creates the hero dir.
browse goto http://localhost:3000/<path>
bash /devshop/kit/scripts/capture-screenshot.sh \
  /workspace/specs/<feature>/hero/<screen>.png --full-page
```

**Why the wrapper, not `browse screenshot` directly:** the gstack browse daemon
validates screenshot output paths against `[TEMP_DIR, process.cwd()]` and
rejects writes to `<git-root>/specs/<feature>/hero/` unless its cwd happens to
be a parent. The wrapper screenshots to `/tmp/` (always inside the allow-list),
then `cp`s to the final path. Devshop cannot extend the daemon's allow-list at
source because gstack is upstream-owned (`.claude/skills/gstack/**` — see
CLAUDE.md § gstack); the wrapper is the devshop-side fix that sits outside that
tree. Wrapper also creates the destination dir, so no separate `mkdir -p` is
needed.

Add the paths to the pre-ship audit trail under Gate 3 / 8. `/ak-build` Phase 6 embeds them into the audit PR comment via repo-relative markdown (GitHub renders them inline).

## Output

After all gates complete, report the accumulated audit trail to the caller.
Do NOT ship, push, create a PR, or post comments — that's `/ak-build`'s job (or the user
runs `/ship` manually). `/ak-pre-ship` is quality gates only.

### Required summary fields

When you return to the caller, include these counts explicitly (not buried in prose):

- `passed: N` — gates that ran and passed
- `findings_pending: N` — gates with unresolved findings (including dismissals whose
  adversarial review was rejected)
- `n_a: N` — gates that did not apply
- **`blocked: N`** — gates that could not run due to missing tooling
- `dismissals_total: N` — findings the gates dismissed with rationale (sum across gates)
- `dismissals_llm_reviewed: N` — of the above, how many went through `dismissalLog`
  adversarial review (as opposed to shim-mapped or `DEVSHOP_SKIP_ADVERSARIAL` bypass)

The caller uses `blocked` as a hard signal. If `blocked > 0`, `/ak-build` must NOT
advance to `/ship`. Emit the preflight fix recipe verbatim so the user can copy it
out of the orchestrator's report.

`dismissals_*` are informational for the `/ak-build` audit comment — not a hard gate,
but a pipeline-health signal worth surfacing to the human reviewer.

## Stuck protocol (for test failures between gates)

**Scope split.** Two distinct stuck-protocols exist; they fire at different
boundaries:

- **Per-gate stuck protocol** (inside the gate sub-agent): when an
  iterative-fix gate's fix breaks something the gate itself surfaces (e.g. a
  `/simplify` refactor that breaks a `/qa` assertion), the gate sub-agent runs
  its own try-fix × 2 → `/investigate` → escalate loop inside its own scope.
  The gate's sink records the stuck-protocol outcome.
- **Orchestrator-boundary stuck protocol** (between gates): when
  `pnpm turbo run test:unit` fails between two code-changing gates in the
  Stabilize-HEAD pass (i.e. a previous gate's fix regressed the unit suite),
  the orchestrator — NOT the next gate sub-agent — runs the stuck protocol.
  This is what this section describes.

When `pnpm turbo run test:unit` fails after a code-changing gate at the
orchestrator boundary:

1. **Attempt 1–2**: read the error, identify which gate's change caused it
   (the most recent commit's `chore`/`fix`/etc. is the likely culprit), fix,
   rerun.
2. **Attempt 3** (same error): invoke `/investigate` via Skill tool — wait for
   root-cause analysis.
3. **Still stuck**: stop, ping user with: which gate caused the regression,
   the error, what was tried.

The orchestrator-boundary stuck-protocol stays a simple in-context retry
because the unit-suite regression is typically a narrow signal (one gate's
fix broke one test); the per-gate stuck protocol (which is where the more
ambiguous failures live) uses the refined fresh-agent-per-attempt shape in
`/ak-implement § Step 3 § Stuck protocol`.

## Behavior

After each gate:

- **Findings**: pause, show findings, wait for resolution before proceeding
- **Clean pass**: auto-advance to next gate (don't show six green checkmarks)
- **User can skip**: if asked to skip a gate, skip it and note in the audit trail
