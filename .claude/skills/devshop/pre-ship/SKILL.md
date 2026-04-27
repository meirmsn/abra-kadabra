---
name: ak-pre-ship
version: 3.3.0
description: |
  Quality gates before shipping. Pauses on findings, auto-advances on clean passes.
  After each code-changing gate, verifies tests still pass (stuck protocol if not).
  Does NOT ship or create a PR — use /ak-build for the full pipeline, or /ship after this.
  Runs: preflight → docs → metrics → responsive → /simplify → /ak-test-review → /review
  → /cso → /design-review → /qa → /benchmark → convention check → capture hero shots.
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

As you run each gate, accumulate results in memory. You'll need them for the PR comment
at the end. For each gate, record:

- Gate name
- Result: `pass` | `findings (N)` | `n/a (reason)` | `blocked (reason)`
- If findings were found and fixed: what was found, which commit fixed it

### Outcome semantics (important — do not conflate)

- **`pass`** — gate ran and either found no issues, or findings were fixed during the run.
- **`findings (N)`** — gate ran and surfaced N issues that still need action. Pipeline
  usually pauses here.
- **`n/a`** — gate does not apply to this PR (e.g. docs check when no docs changed,
  design-review on a non-UI PR). An expected no-op; does not indicate a problem.
- **`blocked`** — gate could NOT run because required tooling was missing or misconfigured
  (e.g. Chromium unavailable for design-review). This is a failure mode, not a no-op.
  `/ak-pre-ship` MUST report blocked gates explicitly to the caller. `/ak-build` MUST
  refuse to advance to `/ship` if any gate is blocked.

Never use `blocked` when you mean `n/a`, and never use `n/a` when the real reason is
missing tooling. The orchestrator relies on this distinction.

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

**Supabase availability check** (hard `blocked` if Docker is missing, never falls back to hosted):

Gate 9 (`/qa`) walks the happy path against a Supabase instance. Hosted Supabase has two failure modes for this: (a) rate-limits signups aggressively (~30-min cooldown after 1-2 attempts), and (b) every signup leaves a real account on the production project — which the bootstrap historically did when Docker wasn't available. As of the dev-side prod-isolation interlude, the hosted fallback is removed: if Docker isn't reachable, Gate 9 reports `blocked` and the pipeline halts.

```bash
# Bootstrap local Supabase or report blocked.
bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up
# Outputs one of:
#   ok: local Supabase up; .env.local rewritten (backup at .preship-backup)
#   reused: local Supabase already running
#   blocked: Docker not running — local Supabase cannot start. Refusing hosted-Supabase fallback (would pollute prod). Fix: rebuild devcontainer with host docker socket bind-mount, or run on a machine with Docker.
```

`ok` / `reused` are exit 0. `blocked` is also exit 0 (the script reports the situation; pre-ship's gate dispatcher decides the outcome). Non-zero exits (2-5) indicate hard failures (CLI missing, `supabase start` failed, seed fixtures missing) — blocking if `$TOUCHES_UI`; warn otherwise.

**If preflight reads `blocked:` from the bootstrap script's stdout**:

1. Record `blocked (Docker unavailable — see fix recipe below)` against Gate 9.
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

If preflight passes, proceed to the gate sequence (canonical list below).

## Gates (canonical order + named IDs)

**This table is the single source of truth for pipeline ordering.** Code, docs, and
`review.md` entries SHOULD reference gates by **name** (e.g. `qa`, `design-review`) —
the position number is a label that re-enumerates here when the pipeline changes. When
a new gate is inserted (Phase 2 added `design-conformance` (ak) between `design-review`
and `qa`), update this one table; downstream refs using names stay stable.

**Gate naming convention**: the `Owner` column marks gates as `ak` (devshop-owned: a
devshop-native check or a devshop-authored skill like `/ak-test-review` /
`/ak-design-conformance`) or `—` (wraps a gstack skill invoked verbatim). Narrative
prose elsewhere in the devshop renders the same split inline as `test-review (ak)`
vs `review` so readers can tell at a glance which gates come from where.

| #   | Name                 | Owner | Title                                 | Scope                                                                |
| --- | -------------------- | ----- | ------------------------------------- | -------------------------------------------------------------------- |
| 1   | `docs-check`         | ak    | Devshop docs diff review              | when `kit/` or reference docs touched                                |
| 2   | `metrics-check`      | ak    | Metrics coverage                      | user-facing code PRs                                                 |
| 2b  | `rls-coverage`       | ak    | RLS policy coverage for client writes | when `supabase/migrations/**` or client API touched                  |
| 2c  | `slow-job-lifecycle` | ak    | Slow-job CI enabled past Phase 1c/1g  | when `*.integration.test.ts` or `apps/web/e2e/*.spec.ts` files exist |
| 3   | `responsive-theme`   | ak    | Responsive + theme capture            | UI PRs only                                                          |
| 4   | `simplify`           | —     | `/simplify` pass                      | always                                                               |
| 5   | `test-review`        | ak    | `/ak-test-review`                     | always                                                               |
| 6   | `review`             | —     | `/review` (+ Greptile triage)         | always                                                               |
| 7   | `cso`                | —     | `/cso` (security)                     | always                                                               |
| 8   | `design-review`      | —     | `/design-review`                      | UI PRs only                                                          |
| 8b  | `design-conformance` | ak    | `/ak-design-conformance`              | runs regardless of UI scope                                          |
| 9   | `qa`                 | —     | `/qa` (functional walk)               | always                                                               |
| 10  | `benchmark`          | —     | `/benchmark`                          | UI PRs only                                                          |
| 11  | `convention`         | ak    | Convention headers + hook-coverage    | always                                                               |

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

## Gate slow-job-lifecycle (ak): Slow-job CI is enabled past the Phase 1c/1g threshold

Mechanical check that the project's `.github/workflows/ci.yml` slow-job is correctly configured once the project ships integration tests (`*.integration.test.ts`) or Playwright E2E specs (`apps/web/e2e/*.spec.ts`). Catches the failure mode where a project crosses the Phase 1c / 1g threshold but leaves the slow-job stub commented out (uncommented but with the wrong `if:` predicate, or stripped of the lalista-PR-26 edge-runtime retry pattern, or branch protection still gating only on `fast`). See `kit/docs/guide/conventions.md § Slow-Job Lifecycle` for the convention this gate enforces.

- Scope: runs when `find packages/ apps/ -name '*.integration.test.ts'` finds any file, OR `find apps -path '*/e2e/*.spec.ts'` finds any file. Otherwise `n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)`.
- Out of scope: actually running the slow job, validating test content, repairing the workflow YAML. Read-only check; operator applies fixes.

Invocation:

```bash
bash /devshop/kit/scripts/preship/slow-job-lifecycle-check.sh "$(git rev-parse --show-toplevel)"
```

Outcomes:

- `pass` — slow-job is uncommented, `if:` predicate is `pull_request`, edge-runtime retry pattern is wired, branch protection includes `slow`, and the test glob matches at least one repo-resident file.
- `findings (N)` — N misconfigurations. Stdout enumerates each gap with the canonical fix recipe inline. Common gaps: stub still commented out, `if:` predicate wrong shape, retry pattern stripped, branch protection missing `slow` context, integration/E2E files exist but the slow job doesn't invoke them.
- `n/a (no .github/workflows/ci.yml)` — projects without GitHub Actions CI.
- `n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)` — pre-Phase-1c projects.

**⚠ Branch-protection check is best-effort.** When `gh` CLI auth is missing or the repo isn't on GitHub yet, the protection check silently degrades (no finding emitted for that sub-check). Operators on a fresh devcontainer should re-run the gate after `gh auth login` to surface a real protection-state finding if any.

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

## Gate 5: /ak-test-review

Invoke `/devshop:test-review` via Skill tool. Test quality review with fresh eyes.
Report only — does not change code.

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

- If PR doesn't touch UI files → `n/a (no UI changes)`.
- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.

Invoke `/design-review` via Skill tool.
Visual audit with fix loop — finds issues, fixes in source, commits atomically.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate design-conformance (ak): DESIGN.md contract check

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

### Outcome contract (three outcomes — `skipped` is not one of them)

Gate 9 MUST emit exactly one of:

- **`pass`** — happy-path walk completed end-to-end. Evidence: a Playwright trace OR a structured log at `specs/<feature>/qa-walk.log` showing the full sequence (URL → assertion → next URL → ...) with timestamps. Without evidence, `pass` is not available.
- **`findings (N) fixed`** / **`findings (N) pending`** — walk found issues; `/qa` fixed what it could. Each finding recorded in `review.md § Gate 9` with repro + commit.
- **`blocked (<reason>)`** — walk couldn't complete. Requires an explicit reason (tooling gap, external dependency unreachable, harness not yet written). Writes fix recipe to `review.md § Gate 9` so the next run knows how to clear the block.

Never `skipped`. If Gate 9 simply wasn't exercised, the correct outcome is `blocked` with the reason. `pass` on an unexercised gate is the failure mode that landed lalista PR #10's Gate 9 in a false-positive state.

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

**Outcome mapping** (adds to the Outcome contract above):

| State                                                                                         | Gate 9 outcome                                               |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| All verbs have artifacts (present, non-empty, screenshot diffs from baseline)                 | `pass` (if other contract items also met)                    |
| Any verb missing an artifact                                                                  | `blocked` with specific verb call-out + fix recipe           |
| Spec has no `## Core user story` section                                                      | `blocked (spec missing Core user story — rerun /ak-spec)`    |
| Spec's `## Core user story` is `N/A — <reason>`                                               | Skip artifact assertion; outcome follows the normal contract |
| Spec declares N verbs but the qa-walk log doesn't mention any of them by name (narrative gap) | Gate 9 surfaces as `findings (1)` to flag the mismatch       |

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

## Gate 11: Convention check

Run the mechanical check first, then apply judgment:

```bash
bash kit/scripts/commit-hooks/check-file-headers.sh main
```

Review any flagged files — skip config-like or trivial files (single export, <50 lines). Then verify:

- File headers (`// What:` / `// Why:` / `// Does NOT:`) exist on non-trivial files (>1 export or >50 lines) under `src/` or `app/`
- JSDoc on exported functions
- Every new migration file has a `-- ROLLBACK` comment block — **pause if missing**
- Backlog items appear to be in the correct file per routing guide in `kit/docs/guide/ § Shared Conventions`
- No completed items left in `PRODUCT-ROADMAP.md` or `kit/ROADMAP.md` — if this PR ships a roadmap item, remove the entry and log the completion in `BUILD-LOG.md`

## Router Summary aggregation

After all gates run (pass or findings), BEFORE capturing hero screenshots, aggregate
every gate's `## Dismissals` section into a single `## Router Summary` block at the top
of `specs/<feature>/review.md`. Shape:

```markdown
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

**Distinction from evidence:**

- `specs/<feature>/screenshots/` — gitignored, regenerable per-gate evidence (all 4 viewport/theme combos)
- `specs/<feature>/hero/` — committed, 1–2 hero shots that define the feature visually

**Defaults:** `1440×light` for each key user-facing screen in the PR (sign-in, onboarding, list view, etc.). Filename convention: `<screen>.png` (no viewport/theme suffix — they're all 1440×light by default; deviate with a suffix when needed, e.g. `list-dark.png` if dark mode is the feature).

**When to skip:** non-UI PRs (API-only, infrastructure, docs), and UI PRs where the happy-path can't be reached in this sandbox (e.g. Supabase rate-limits a signup flow). Document the reason in `review.md` instead of leaving a gap.

**Capture mechanics** (via the gstack `browse` skill):

```bash
# Ensure the hero dir exists
mkdir -p /workspace/specs/<feature>/hero

# Navigate, capture — repeat per screen
browse goto http://localhost:3000/<path>
browse screenshot /workspace/specs/<feature>/hero/<screen>.png --full-page
```

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

When `pnpm turbo run test:unit` fails after a code-changing gate:

1. **Attempt 1–2**: read the error, identify which gate's change caused it, fix, rerun
2. **Attempt 3** (same error): invoke `/investigate` via Skill tool — wait for root-cause analysis
3. **Still stuck**: stop, ping user with: which gate caused the regression, the error, what was tried

## Behavior

After each gate:

- **Findings**: pause, show findings, wait for resolution before proceeding
- **Clean pass**: auto-advance to next gate (don't show six green checkmarks)
- **User can skip**: if asked to skip a gate, skip it and note in the audit trail
