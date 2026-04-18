# PR 2 Pending Checks + Pre-ship QA Reliability Fix-Plan

**What this doc is.** Two purposes braided together:

1. **Close-out actions** for the four manual-review checkboxes that
   stayed `[ ]` on lalista PR #10 (auth).
2. **A systemic fix-plan** for the real underlying problem: pre-ship
   QA was unreliable during PR 2 in ways that affect every future PR
   unless the devshop enforces something stronger. Four concrete
   `/ak-pre-ship` + `/ak-build` edits, each with design + implementation
   - verification.

Pointers: forward-looking migration handoff
`/devshop/kit/notes/phase-1-next-steps.md`; subagent-hook split
`/devshop/kit/notes/subagent-hook-scope.md`.

---

## Part 1 — PR #10 unchecked boxes: close-out actions

From lalista PR #10 body § "Manual review call-outs":

| #   | Item                                                                                                                   | State                                                              | Action to close                                                                                                                                    |
| --- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Visual 4-combo audit (`375/1440 × light/dark`) on `/sign-in` + `/onboarding`                                           | 1 of 4 captured (1440×light only, as `specs/auth/hero/signin.png`) | Run the Path-A or Path-C flow below.                                                                                                               |
| 2   | Live QA walkthrough — fresh sign-up → onboarding → home, plus wrong-password, refresh, sign-out, direct-nav edge cases | Never attempted end-to-end (Supabase rate-limit in the session)    | Same (Path A or C).                                                                                                                                |
| 3   | Middleware p95 post-deploy                                                                                             | Post-merge only                                                    | Reviewer checks Vercel function metrics after merge. If > 50ms, `specs/auth/review.md § Gate 10` has the `getSession()` vs `getUser()` mitigation. |
| 4   | Onboarding hero screenshot                                                                                             | Blocked on same rate-limit                                         | Included in Path A/C.                                                                                                                              |

### Path A — close the gap before PR 2 merges

~30 minutes total. Run in the same or a fresh Claude Code session with
`/workspace` on `feature/auth`:

1. **Start local Supabase:** `cd /workspace && supabase start`. Wait for
   API + Studio URLs to print. This avoids the hosted-project rate-limit
   that blocked the session.
2. **Point apps/web at local Supabase** — temporarily edit
   `apps/web/.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<local anon key from `supabase status`>
   NEXT_PUBLIC_POSTHOG_KEY=<keep hosted>
   NEXT_PUBLIC_SENTRY_DSN=<keep hosted>
   ```
3. **Force alice through onboarding** (`supabase/seed.sql` inserts her
   with a household; delete the membership to reach the onboarding
   path):
   ```
   psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
     "DELETE FROM household_members WHERE user_id='11111111-1111-1111-1111-111111111111';"
   ```
4. **Restart dev server:** `cd /workspace/apps/web && pnpm dev`.
5. **Walk the happy path via browse:**
   - `http://localhost:3000/` → assert 307 → `/sign-in`.
   - Sign in as `alice@test.local` / `password123` → assert `/onboarding`.
   - Fill "Casa QA", submit → assert `/`.
   - Hard-refresh `/` → assert still authed.
   - `localStorage.clear()` in devtools, reload → assert `/sign-in`.
6. **Capture 4-combo matrix** at `/sign-in` empty, `/onboarding` empty:
   - 1440×900 light → `specs/auth/hero/signin.png` (overwrite), `onboarding.png` (new).
   - 375×667 light → `signin-375.png`, `onboarding-375.png`.
   - Dark variants: run `document.documentElement.classList.add('dark')`
     in browse first (dark-mode toggle is not yet wired — known gap), then capture.
7. **Commit** hero additions + any spec notes as a single commit on
   `feature/auth`. Mark the 4 checkboxes `[x]` in the PR body using the
   `github.com/<owner>/<repo>/raw/<branch>/<path>` URL form (private-repo
   safe; raw.githubusercontent.com 404s without auth tokens).
8. **Revert `apps/web/.env.local`** to hosted Supabase.
9. **`supabase stop`** to release the Docker containers.

### Path C — defer to PR 3's pre-ship

PR 3 (core flows) re-exercises the same screens _plus_ adds list view +
add-item + item detail + settings. Doing the matrix once during PR 3's
`/ak-pre-ship` produces richer evidence and avoids duplicating work.
PR 2 ships with the single 1440×light hero + a note on PR #10 pointing
to PR 3 for the full matrix.

**Recommended path.** Rationale: PR 2's functional logic is covered by
88 passing unit tests, styling is verified by the existing hero, Vercel
preview deploys correctly. The matrix + happy-path walk are
higher-leverage when run against a more complete UI surface.

---

## Part 2 — Root causes (why QA was unreliable)

Five root causes fired during PR 2's pre-ship. Each needs either a
workflow fix or explicit acceptance. Annotated with current state:

| #   | Root cause                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Current status                                                                                                                                                                                                                                                   |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Hosted Supabase rate-limits signups aggressively** (after 1–2 attempts, ~30-min cooldown on all new-user calls). The subagent hit this trying `@example.com`, `@gmail.com`, `@test.com` in sequence and reported the walk as `blocked`.                                                                                                                                                                                                                                    | **No workflow fix yet.** Fix A below closes this — local Supabase as the default for Gate 9.                                                                                                                                                                     |
| 2   | **Missing Chromium in devcontainer** meant browser gates silently skipped with a cheerful "all passed 7/8" summary.                                                                                                                                                                                                                                                                                                                                                          | ✅ Fixed in the hardening PR (`feature/pre-ship-hardening`): template Dockerfile installs 14 shared libs; `/ak-pre-ship` Phase 0 preflight treats missing browser as `blocked` (not `skipped`); `/ak-build` refuses to advance to `/ship` on any `blocked` gate. |
| 3   | **Parent-agent hooks interfere with subagents.** `check-dirty-after-commit.sh` + `check-pr-description.sh` fired ~8× inside the pre-ship subagent with `MANDATORY`/`BLOCKING` demands that contradicted the subagent's scope.                                                                                                                                                                                                                                                | **Fix tracked in `subagent-hook-scope.md`** (separate session).                                                                                                                                                                                                  |
| 4   | **Agent scope-cut.** When the subagent hit rate-limit on Gate 9 and captured 1 of 4 screenshots for Gate 3, the parent agent accepted partial evidence rather than switching strategies (e.g., to local Supabase). The pattern was "stopped at localhost styling verified; handed off functional verification to Vercel preview." That's below the project's quality bar — Vercel preview should be a reality-check against shipped evidence, not the first functional test. | **No workflow fix yet.** Fixes B + C + D below remove the option to cheerfully-terminate.                                                                                                                                                                        |
| 5   | **Dark mode unreachable in shipped code** — `.dark` class CSS exists, nothing toggles it. Dark-mode screenshots require a forced-class workaround.                                                                                                                                                                                                                                                                                                                           | Documented in `phase-1-next-steps.md § Known gaps #6`. Theme bootstrap is a future PR (PR 3 may absorb it, or a dedicated theme PR). **Not a QA-reliability fix per se** — more a "what to test" question.                                                       |

Fixes B, C, D below address root cause #4 (scope-cut) by making it
structurally impossible for a gate to `pass` without the required
evidence. Fix A addresses #1 directly.

---

## Part 3 — Systemic fix-plan (4 changes)

Each fix below is a concrete edit to `/devshop/.claude/skills/devshop/`
files. Together they convert pre-ship QA from
"recommended + report back" into "evidence-first, no
quietly-terminated runs."

**Scope of implementation session.** A single devshop PR can land all
four. They share tests (integration + a dry-run against lalista's auth
spec) and cross-reference each other. Expected size: ~200 lines of
SKILL.md edits + 1 new script + doc updates.

### Fix A — Local Supabase as the default for Gate 9

**Problem.** Gate 9 (`/qa`) hits Supabase for real signups to walk the
happy path. Hosted Supabase rate-limits aggressively; Gate 9 gets
`blocked` on a third-party dependency that isn't the PR's fault. Session
agents work around this by declaring the walk blocked and moving on,
which loses coverage.

**Design.**

`/ak-pre-ship` Phase 0 preflight gains a Supabase-availability check:

1. Is `supabase start` available (CLI installed + Docker running)? If
   no → `blocked` with fix recipe.
2. Is local Supabase already running? (`supabase status` returns API
   URL) → reuse.
3. Else → `supabase start` (takes ~45s first time, ~10s warm).
4. Regenerate `apps/web/.env.local` to point at local (keeps a backup
   of the original to restore on exit).
5. Verify schema + seed loaded: query `auth.users` for the seeded
   `alice@test.local` and `bob@test.local` → should both exist.

At the end of `/ak-pre-ship` (success or failure), preflight's exit
handler restores the backed-up `apps/web/.env.local` and `supabase stop`s
the local instance. Idempotent; safe to re-run.

**Implementation plan.**

- Edit `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` § Phase 0:
  extend "Tooling checks" with a `supabase start` availability block
  mirroring the current Chromium block (blocking if UI PR; non-blocking
  otherwise).
- Create `/devshop/kit/scripts/preship-supabase-bootstrap.sh`: the
  start/verify/env-rewrite/restore logic, invoked from the preflight.
  Root-owned, NOPASSWD-sudo entry added to `.claude/settings.json`
  (user action required; scripts alone can't modify settings.json).
- Update `/ak-new-project/SKILL.md` Step 13b: mention that `.env.local`
  is now rewritten automatically by `/ak-pre-ship`; the human should
  set it to hosted Supabase for dev but not worry about toggling during
  pre-ship.

**Verification.**

- Run `/ak-pre-ship` on lalista's `feature/auth` with hosted Supabase
  unreachable (simulate by pointing `.env.local` at a bad URL). Without
  the fix: Gate 9 fails or is blocked. With the fix: preflight spins up
  local, Gate 9 walks `alice@test.local`, passes.
- Re-run. On second run: local Supabase already up, preflight reuses.
- Intentionally crash mid-pre-ship (`kill -9` the dev server). Verify
  the exit handler still restores `.env.local` and stops Supabase.

### Fix B — Gate 3 enforces the 4-combo evidence matrix

**Problem.** Gate 3 (Responsive + theme) says "verify at 4 combos" but
doesn't check that 4 screenshots actually exist in
`specs/<feature>/screenshots/`. A gate that takes 1 of 4 shots and
reports `pass` hides the other 3 failures.

**Design.**

After all verification work inside Gate 3, inspect
`specs/<feature>/screenshots/` for the expected filename pattern:
`<screen>-{375,1440}-{light,dark}.png` for each primary screen. Primary
screens are derived from the PR's changed files — any new
`apps/web/app/**/page.tsx` is a primary screen.

- If all 4 combos × each primary screen exist → `pass`.
- If any missing, check `review.md § Gate 3` for an explicit blocker
  mentioning the specific screen + combo (e.g., "375×dark for /sign-in
  skipped because dark-mode bootstrap deferred — see
  phase-1-next-steps.md § Known gaps #6"). If the blocker reason is
  present → `findings (N) [blocker documented]`. Otherwise → `blocked`.

Never silently `pass` when evidence is incomplete.

**Implementation plan.**

- Edit `pre-ship/SKILL.md` § Gate 3: add an "Evidence enforcement" subsection at the end.
  Inline the filename pattern and the blocker-documentation escape.
- Add a helper to the new `preship-supabase-bootstrap.sh` (or a separate
  `preship-evidence-check.sh`) that takes the primary-screen list +
  `$FEATURE_DIR` and emits `pass`/`findings`/`blocked` on stdout.

**Verification.**

- Dry-run against `feature/auth` at the single-hero state: Gate 3 should
  return `blocked` because the `375/1440 × dark` files don't exist and
  the blocker isn't documented.
- Add the blocker doc to `specs/auth/review.md § Gate 3` ("dark-mode
  bootstrap deferred — see phase-1-next-steps.md") → Gate 3 returns
  `findings (N) [blocker documented]`.
- Capture all 4 combos → Gate 3 returns `pass`.

### Fix C — Gate 9 must complete a happy path or report `blocked`

**Problem.** Same shape as Fix B, but for the end-to-end flow. Gate 9
currently has no structural requirement that the walk complete. The
session pattern "walk fails, document it, `pass` on inferred-OK" can't
happen if `pass` requires positive evidence of a completed walk.

**Design.**

Gate 9 emits one of:

- `pass` — happy-path walk completed end-to-end. Evidence: a
  Playwright trace or a structured log in `specs/<feature>/qa-walk.log`
  showing the full sequence (URL → assertion → next URL → ...) with
  timestamps.
- `findings (N) fixed` / `findings (N) pending` — walk found issues.
- `blocked (<reason>)` — walk couldn't complete. Requires an explicit
  reason (tooling gap, external dependency unreachable, etc.). Writes
  the fix recipe to `review.md § Gate 9`.
- Never `skipped` — `skipped` is no longer a Gate 9 outcome.
  (Same vocabulary discipline that Fix B's hardening introduced.)

The evidence file (`qa-walk.log`) is produced by the same script that
drives the walk — see Fix A's browse-driven sequence. It's gitignored
by default (belongs with `screenshots/` under `specs/*/screenshots/` or
a sibling `specs/*/evidence/`).

**Implementation plan.**

- Edit `pre-ship/SKILL.md` § Gate 9: introduce the three outcomes
  explicitly. Require the evidence file.
- Add the walk script as part of Fix A's bootstrap (shared infrastructure
  reads session state from preflight's local-Supabase bootstrap).

**Verification.**

- With local Supabase up and alice-with-no-household: run the walk →
  produces `qa-walk.log` → `pass`.
- Kill local Supabase mid-walk → walk fails fast → Gate 9 returns
  `blocked (local Supabase crashed)` with the fix recipe.
- Remove the happy-path script → Gate 9 returns `blocked (walk script
missing)` — doesn't silently `pass`.

### Fix D — Evidence-first PR body reconciliation

**Problem.** PR body checkboxes can drift from reality: a box can be
`[x]` when the evidence doesn't exist, or `[ ]` when it does. During
PR 2 both happened at different points.

**Design.**

`/ak-build` Phase 6 (final sweep) already reconciles checkbox state
against the gate outcomes (added in `feature/pre-ship-hardening`'s
last commit). Extend that sweep to also check **evidence-on-disk**:

- For every `[x]` in the PR body that maps to an artifact (hero shot,
  qa-walk log, test-plan item), verify the artifact exists in
  `specs/<feature>/` (or is referenced by an absolute URL in the PR
  body, e.g., the Vercel preview URL for the preview-deploy box).
- Emit a sweep report listing any `[x]` with missing evidence.
- Phase 6 fails (pipeline halts) if evidence is missing for any `[x]`.

This closes the last loophole: you can't open a PR in a cheerful-all-
green state that isn't actually all-green.

**Implementation plan.**

- Edit `build/SKILL.md` § Phase 6 checkbox verification: extend the
  existing reconciliation table with an "Evidence present?" column
  mapping each checkbox type to the file or URL that must exist for
  `[x]` to be legitimate.
- Emit a diff block in the audit comment listing any discrepancies.

**Verification.**

- Manually toggle a checkbox `[x]` before `/ak-build` Phase 6 runs,
  with no evidence file → Phase 6 halts with "evidence missing" error.
- Remove the evidence file on disk after Phase 5.3's auto-check →
  Phase 6's sweep catches it.

---

## Part 4 — Why these four together, not one-at-a-time

Each fix on its own partially closes the reliability gap. All four
together close it:

| Without this fix, a session can...                    | Fix that prevents it                                                      |
| ----------------------------------------------------- | ------------------------------------------------------------------------- |
| Cheerfully-skip a gate because tooling is unavailable | Already-landed `blocked` outcome + Fix A (tooling provisioned by default) |
| Claim Gate 3 `pass` with 1 of 4 screenshots           | Fix B (enforced 4-combo matrix)                                           |
| Claim Gate 9 `pass` without walking the happy path    | Fix C (positive evidence required)                                        |
| Ship a PR with `[x]` that doesn't match reality       | Fix D (body sweep cross-checks artifacts)                                 |

Fix A supplies the local Supabase that Fix C needs to complete the
walk. Fix B and Fix C share the same pattern (evidence file → gate
outcome) — writing one template informs the other. Fix D depends on
Fixes B and C being live because it's cross-checking the artifacts they
produce. Splitting them across PRs means multiple rounds of reviewer
context; bundling gives one coherent change.

---

## Part 5 — Session kickoff prompt (copy-paste)

For a fresh Claude Code session to implement this:

> I want you to implement the pre-ship QA reliability fix-plan in
> `/devshop/kit/notes/pr2-pending-checks.md § Part 3`. Read that file
> first — it's self-contained.
>
> Start by reading the file. Then:
>
> 1. Confirm you understand each of the 4 fixes (A — local Supabase
>    in Gate 9 preflight; B — Gate 3 evidence enforcement; C — Gate 9
>    completion requirement; D — Phase 6 evidence-on-disk sweep).
> 2. Propose a branch name on the devshop (`feature/preship-qa-reliability`
>    or similar) and the commit structure — one commit per fix, or
>    one bundled commit. I prefer one per fix for reviewability.
> 3. Verify each fix with the verification steps in the doc. Use
>    lalista's `feature/auth` (already in `/workspace`) as the target
>    of the dry-run, since it's a real spec with real artifacts.
>
> **Do NOT start implementing until I confirm the branch name and
> commit structure.**
>
> Follow the devshop commit conventions (docs-drift + docs-consistency
> adversarial reviewers will fire; have the `docsVerified` /
> `docSyncReason` reasons ready). Ping me if either review rejects your
> reason so we can refine together.

---

## Files referenced

Absolute paths from the container:

| Path                                                   | What                                                                                                                                                                                                                  |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`    | `/ak-pre-ship` definition — Phase 0 preflight, Gates 1–11. Fixes A/B/C edit Phase 0, Gate 3, Gate 9.                                                                                                                  |
| `/devshop/.claude/skills/devshop/build/SKILL.md`       | `/ak-build` definition — Phases 1–8. Fix D extends Phase 6.                                                                                                                                                           |
| `/devshop/.claude/skills/devshop/new-project/SKILL.md` | `/ak-new-project` — update Step 13b's `.env.local` guidance to note pre-ship's local-Supabase rewriting.                                                                                                              |
| `/devshop/kit/scripts/`                                | Destination for new `preship-supabase-bootstrap.sh` + `preship-evidence-check.sh`. Root-owned; adding new scripts needs sudo cp + a `.claude/settings.json` entry (user action).                                      |
| `/devshop/.claude/settings.json`                       | Root-owned, write-denied. A NOPASSWD entry for the new preship-supabase script goes here (user action).                                                                                                               |
| `/devshop/kit/TODOS.md`                                | No existing entry about Gate-3/Gate-9 evidence enforcement. Fix B and Fix C replace the need for one. If the implementation session wants to break this up, adding a TODOS entry per fix for later iteration is fine. |
| `/workspace/specs/auth/`                               | PR 2's spec folder — the natural target for the dry-run verification of each fix.                                                                                                                                     |
| `/workspace/apps/web/e2e/auth.spec.ts`                 | Playwright happy-path spec — Fix C's walk script can either reuse this or invoke playwright directly.                                                                                                                 |

---

## Related docs

- `/devshop/kit/notes/phase-1-next-steps.md` — the forward-looking migration handoff (PR 3 + beyond). References this file from § Prerequisites.
- `/devshop/kit/notes/subagent-hook-scope.md` — a different reliability concern (hooks firing inside subagents). Independent; can land in any order relative to this fix-plan.
- `/devshop/kit/notes/bootstrap/v0-web.md` — original migration blueprint; § 1g (Testing pass) and § 1e's per-screen "implement → test → metric → done" pattern are the spec-level ancestors of these fixes.
