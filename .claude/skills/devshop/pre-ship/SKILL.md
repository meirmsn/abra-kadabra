---
name: ak-pre-ship
version: 3.2.0
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

**Supabase availability check** (advisory — Gate 9 degrades gracefully):

Gate 9 (`/qa`) walks the happy path against a Supabase instance. Hosted Supabase rate-limits signups aggressively (~30-min cooldown after 1-2 attempts), so the preferred backend is local Supabase. If Docker-in-Docker isn't available in the devcontainer (currently inert without a `--privileged` rebuild), Gate 9 falls back to admin-API against hosted — which bypasses rate limits entirely but pollutes the hosted DB with test data.

```bash
# Bootstrap local Supabase if possible; otherwise report the fallback.
bash /devshop/kit/scripts/preship-supabase-bootstrap.sh up
# Outputs one of:
#   ok: local Supabase up; .env.local rewritten (backup at .preship-backup)
#   reused: local Supabase already running
#   unavailable: Docker not running — local Supabase cannot start; Gate 9 must use admin-API against hosted
```

`ok` / `reused` / `unavailable` are all exit 0. Non-zero exits (2-5) indicate hard failures (CLI missing, `supabase start` failed, seed fixtures missing) — blocking if `$TOUCHES_UI`; warn otherwise.

At the end of the pre-ship run (success or failure), call the teardown:

```bash
bash /devshop/kit/scripts/preship-supabase-bootstrap.sh down
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

If preflight passes, proceed to Gate 1.

## Gate 1: Devshop docs check

If the PR touches `kit/` or reference docs (`kit/docs/OVERVIEW.md`, `kit/docs/guide/`):

- Verify both reference docs are in sync
- Pause if they've drifted

## Gate 2: Metrics check

If the PR touches user-facing code (components, API wrappers, edge functions):

- Verify `posthog.capture()` calls exist for events in this feature's spec
- Cross-reference against `METRICS.md`
- **Pause if missing** — don't auto-advance on a user-facing PR without metrics

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

| State                                                                                                                                                                                                       | Gate 3 outcome                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| All 4 combos × each primary screen present                                                                                                                                                                  | `pass`                              |
| Any combo missing, AND `review.md § Gate 3` has an explicit blocker entry naming the specific screen + combo (e.g. "375×dark for /sign-in skipped because dark-mode bootstrap deferred — see Known Gap #6") | `findings (N) [blocker documented]` |
| Any combo missing, no blocker doc                                                                                                                                                                           | `blocked (evidence incomplete)`     |

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

Prior art: lalista commit `31b5637` (`awaitingConfirmation` UI + `friendlyAuthError` helper) + `e1ceb9c` (identities-check follow-up) — both flagged as verification debt in `lalista-migration-resume.md § Core Principles § 4` awaiting the v1 "Auth UX conventions" helper. Once that helper ships, this matrix row is how Gate 9 verifies the helper did its job.

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
bash kit/scripts/check-file-headers.sh main
```

Review any flagged files — skip config-like or trivial files (single export, <50 lines). Then verify:

- File headers (`// What:` / `// Why:` / `// Does NOT:`) exist on non-trivial files (>1 export or >50 lines) under `src/` or `app/`
- JSDoc on exported functions
- Every new migration file has a `-- ROLLBACK` comment block — **pause if missing**
- Backlog items appear to be in the correct file per routing guide in `kit/docs/guide/ § Shared Conventions`
- No completed items left in `PRODUCT-ROADMAP.md` or `kit/ROADMAP.md` — if this PR ships a roadmap item, remove the entry and log the completion in `BUILD-LOG.md`

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
- `findings_pending: N` — gates with unresolved findings
- `n_a: N` — gates that did not apply
- **`blocked: N`** — gates that could not run due to missing tooling

The caller uses `blocked` as a hard signal. If `blocked > 0`, `/ak-build` must NOT
advance to `/ship`. Emit the preflight fix recipe verbatim so the user can copy it
out of the orchestrator's report.

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
