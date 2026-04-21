# lalista Migration — Resume Doc (post-hook-migration handoff)

**Read this doc first if you're continuing the lalista Swift → Next.js migration.**
This is **self-contained**. No need to read the three predecessor docs (`phase-1-next-steps.md`, `pr2-pending-checks.md`, `subagent-hook-scope.md`) — every still-relevant detail from them is inlined below. Predecessor docs can be referenced for historical context only.

**Authoring date**: 2026-04-18. **Last updated**: 2026-04-20 (Step 2 in progress — see "UPDATE 2026-04-20 — Step 2 IN PROGRESS" below).

**Predecessor docs** (historical — content inlined here):

- `/devshop/kit/notes/phase-1-next-steps.md` — original migration handoff (PR 3 + beyond)
- `/devshop/kit/notes/pr2-pending-checks.md` — PR 2 close-out + 4-fix systemic plan
- `/devshop/kit/notes/subagent-hook-scope.md` — RESOLVED by roadmap/hook-migration-plan.md

---

## Core principles (READ FIRST — this drives every decision in the migration)

The migration's whole purpose is to get the devshop into a good state, with lalista as the byproduct. NOT "ship lalista fast and fix devshop later." Rushing inline fixes defeats the purpose — every gap lalista surfaces is an opportunity to refine devshop so the next project inherits the fix.

### 1. Triage every finding at discovery time

Every finding has exactly one origin. Classify at the moment it surfaces:

- **A. Pure project** — product feature or UX decision (design tokens, specific layouts, business-logic-unique-to-this-product). **Always fix inline**; no devshop implication.
- **B. Pure devshop** — QA gap, tooling missing, reusable convention that spans projects. **Always route to devshop**; don't patch lalista ad-hoc.
- **C. Both** — the most common case for auth / deploy / data / testing patterns. Needs an entry in both homes.

### 2. For Category C: ASK the user before choosing

On every Category C finding, stop and ask:

> "This is Category C. Implement the devshop fix now (slower, proves devshop works on lalista), or capture in ROADMAP + fix lalista inline (faster but accrues verification debt)?"

**Bias toward "implement now."** Deferring is a real choice with a real cost — the devshop helper stays untested until a future project surfaces the same gap. The point of this migration is to close those gaps now, while lalista is actively forcing them.

### 3. Time-box rule (default for ambiguous cases)

- Devshop fix **< 1 day** → implement devshop FIRST, then apply to lalista (adopt the new helper/convention). This is the preferred path.
- Devshop fix **≥ 1 day** → capture in ROADMAP with shape + trigger + prior-art references; fix lalista inline; **verification debt is owed** (see principle 4).

### 4. Verification = refactor-to-adopt (NOT rebuild-from-scratch)

When a Category C finding is fixed inline (principle 3's ≥1 day branch), the devshop implementation still needs to be validated. The verification isn't rebuilding lalista from scratch — it's refactor-to-adopt:

1. A future devshop session implements the convention/helper per the ROADMAP entry
2. A future lalista session **replaces** the inline lalista code with imports from the new helper (delete the inline version)
3. Verify identical behavior: existing unit tests pass, `pnpm test:qa-walk` passes, manual UX check matches
4. If identical → devshop is proven; any future project using the same helper gets the same behavior for free
5. If different → the devshop implementation is wrong; iterate until identical

This is how each ROADMAP entry gets discharged — not "we wrote the helper," but "lalista successfully adopted it with no regression."

**Inline fixes that owe verification** (as of 2026-04-20):

| Lalista commit | Inline fix                                      | Devshop ROADMAP entry                       | Verification owed                                                                                                                  |
| -------------- | ----------------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `31b5637`      | `awaitingConfirmation` UI + `friendlyAuthError` | `kit/ROADMAP.md § v1 § Auth UX conventions` | After v1 ships: delete inline, import `AwaitingConfirmationCard` + `friendlyAuthError` from the helper; tests + qa-walk still pass |
| `e1ceb9c`      | `identities.length === 0` existing-user check   | same entry (added to same v1 scope)         | Same flow — the identities-check should live in the helper, not in lalista's page                                                  |

### 5. Stop criterion — when to let devshop be

Tied to PR milestones, not calendar time. Don't over-optimize devshop for problems the project hasn't hit yet.

| Milestone     | Stop signal (devshop is "v1-ready" for this phase)                                                                    |
| ------------- | --------------------------------------------------------------------------------------------------------------------- |
| After PR 2    | Devshop has: auth, RLS, RPC, QA-walk patterns                                                                         |
| After PR 3    | Devshop has: realtime, edge-fn, item-UX, theme-auto-detect patterns                                                   |
| After PR 4    | Devshop has: CI slow job, type-drift, rollback validation, deploy boundary docs                                       |
| **Post-PR 4** | STOP routing small findings to devshop. New findings go to ROADMAP with trigger = "next project surfaces this again." |

Heuristic to know you're done: post-PR 4, if you're still finding >1 devshop gap per PR, devshop isn't done. If you find zero per PR for two PRs in a row, you're done.

### How to ASK (principle 2) — exact phrasing

When a Category C finding surfaces mid-session, present it like this:

> "Category C finding: <description>. Options:
>
> **A.** Implement devshop now (shape: <1-line>, est: <hours/days>). Paired lalista change: <what adopts it>. Proves the devshop helper works.
> **B.** Capture in ROADMAP + fix lalista inline (est: <hours>). Fastest today; verification debt owed (devshop side untested until the refactor-to-adopt step).
>
> Bias is toward A unless you tell me otherwise. Which?"

This forces the triage to be explicit and auditable, rather than drifting to inline fixes by default.

---

## UPDATE 2026-04-20 — Step 1 DONE, Step 2 IMPLEMENTATION COMPLETE (awaiting ff-merge + release)

**Latest status (2026-04-20 evening)** — pick up here after a context reset:

- **Step 1 fully wrapped**: PR #10 merged as squash commit `41b3eaa` on lalista `main`; BUILD-LOG housekeeping PR #12 merged as `81b2638`; `/ak-go-live` deploy complete; canary verified.
- **Step 2 IMPLEMENTATION COMPLETE**: all 10 commits landed on devshop branch `feature/preship-qa-reliability`. Awaiting the devshop landing flow (see § "Devshop shipping flow (no PRs)" below — **NOT** a PR on abra-kadabra; devshop uses ff-merge). **Fresh-session resume sequence**:
  1. `git -C /devshop checkout feature/preship-qa-reliability`
  2. `git -C /devshop log --oneline main..HEAD` — should show the 10 Step 2 commits (listed below under "Step 2 commits landed").
  3. If tree is clean and main is still behind: `git -C /devshop checkout main && git -C /devshop merge --ff-only feature/preship-qa-reliability` — ff-merge is a pointer move, not a commit, so Claude's main-commit block doesn't fire.
  4. Run `/ak-release-devshop` from main. Skill proposes bump level (minor — multiple `feat:` commits; `v1.10.3 → v1.11.0`), asks user to confirm, then `release.sh` writes kit/version, generates CHANGELOG entry, commits the bump, tags `v1.11.0`, pushes, creates GitHub release.
- **⚠ PR-flow trap**: past sessions (including this one) wasted cycles trying to open a PR on abra-kadabra. Don't. DEVSHOP_GITHUB_TOKEN lacks Pull Requests: Write scope AND devshop explicitly uses ff-merge (see `/devshop/CLAUDE.md § Devshop shipping flow (no PRs)` + the § "Devshop shipping flow" section in this doc — formerly misnamed "Devshop conventions for these PRs" which seeded the confusion).
- **Step 2 commits landed on feature/preship-qa-reliability** (10 total, in reverse chronological order):
  1. `f5ff43b` — feat(ak-build): Fix D — Phase 6 evidence-on-disk sweep
  2. `0c22e8b` — feat(pre-ship): Fix C — Gate 9 user-state matrix + friendly-error
  3. `4875a0c` — feat(pre-ship): Fix B — Gate 3 evidence-matrix enforcement
  4. `f01c89b` — feat(pre-ship): Fix A — preship-supabase-bootstrap.sh
  5. `2869a51` — docs(guide): Deploy Boundaries + Supabase Hardening + ON DELETE
  6. `0c854e1` — feat(ak-new-project): Step 17b Supabase auth hardening
  7. `7c86ed6` — feat(ak-build,ak-go-live,ak-spec): BUILD-LOG flow restructure
  8. `8acd25f` — feat(ak-build): Phase 7 deploy-hint nudge
  9. `6699692` — chore(commands): /ak-clean-branches rename + remote-delete
  10. `b38b09d` — docs(notes+todos): Step 2 status + migration 009 → PR 3 + infra TODOs
- **Branch pushed to origin** (via the devshop-token HTTPS URL — `git@github.com:…` is SSH and doesn't work from this container). Feature branch is visible at `github.com/meirmsn/abra-kadabra/tree/feature/preship-qa-reliability`, but that's informational; the actual land is via ff-merge to main, not via a PR on that branch.
- **Locked-in decisions 2026-04-20**:
  - **Lalista migration 009 (ON DELETE FK cascades)** → **folded into PR 3**, not standalone PR 2.1. Rationale: avoids a one-commit interstitial PR; co-located with the new write paths PR 3 introduces; the devshop `ON DELETE` FK convention landing in Step 2 guides the migration shape. See § "Pending lalista work § standalone § Migration 009".
- **Lalista main tip**: `81b2638`. Working tree clean. No active feature branches on lalista.
- **Devshop main tip**: `2aa4db1` until ff-merge lands; then `f5ff43b` (tip of feature branch); then `Bump devshop version to 1.11.0` after `/ak-release-devshop`.

### Step 1 — PR #10 close-out: ✅ DONE

Closing commit on `feature/auth`: **`23b9795 fix(auth): atomic household RPC + QA walk evidence closing PR 2`**. CI green on that commit; PR #10 mergeable; all 4 manual-review checkboxes now `[x]`.

**Bug found + fixed along the way** — would have blocked every new user at onboarding:

- Root cause: `createHousehold` did `.insert({name}).select('*').single()`. PostgREST requires the SELECT RLS policy to pass on the RETURNING row; `households_select` gates on membership, which doesn't exist until the second insert. Every first-household create got 403, second insert never ran.
- Missed because unit tests mock the Supabase chain (RLS never runs) and Gate 9's original walk was rate-limited before reaching this step.
- Fix: migration `008_create_household_with_owner_rpc.sql` — SECURITY DEFINER RPC that wraps both inserts atomically, binds owner to `auth.uid()` server-side. Client then SELECTs (now a member, passes RLS). Grants: `authenticated` + `service_role` only (revoked from `anon` + `public`). **Migration already applied to hosted via Management API** — verified grants + function body.

**New machinery** (reusable for Steps 2-4):

- `apps/web/e2e/helpers/test-user.ts` — admin-API lifecycle for `preship-qa@lalista-test.invalid` (RFC 2606 reserved `.invalid` TLD, unroutable). Idempotent delete + cascade-aware cleanup. Safety assertion rejects any non-test email.
- `apps/web/e2e/qa-walk.spec.ts` + `pnpm --filter @lalista/web test:qa-walk` — Playwright-driven happy-path walk against hosted, captures 8-shot 4-combo hero matrix.
- `apps/web/playwright.config.ts` has a dedicated `qa-walk` project with explicit `executablePath` (devcontainer firewall blocks the Playwright CDN's smaller headless-shell binary; full chromium works).

**Remaining for Step 1**:

- User merges PR #10 (deliberate handoff — no auto-merge)
- User runs `/ak-go-live` post-merge to trigger deploy + canary

### Admin-API workaround changes urgency of Step 2's Fix A

Fix A (auto-bootstrap local Supabase in `/ak-pre-ship` Phase 0) was the original answer to hosted rate-limits. **Admin API bypasses rate-limits entirely** and works against hosted today (no docker needed). Fix A is still valuable (true local-only workflow, no hosted-DB pollution during dev), but **less urgent**. Rebuild of devcontainer.json with `--privileged` flag is required for docker-in-docker to actually run (currently defined-but-inert) — painful; could be deferred.

Known Gap #5 (hosted rate-limit) now has a workaround: use admin API from service role. Document this in Gap #5 when Step 2 lands.

### Step 2 scope expanded — bundle several devshop changes

Original: Fixes A–D on `feature/preship-qa-reliability` branch. Added to the same bundle:

- **Rename `/clean-branches` → `/ak-clean-branches` + extend to delete remote branches** — devshop-provided slash commands should follow the `ak-` prefix convention (`/devshop/.claude/commands/clean-branches.md` is currently the odd-one-out). Note: `release-devshop` skill is fine — its frontmatter is already `ak-release-devshop`; directory name un-prefixed is consistent with other devshop skill dirs.
  - **Enhancement beyond the rename**: extend the command to delete the matching branches on `origin` (the remote) too, not just local branches + stale tracking refs. Current behavior only runs `git remote prune origin`, which cleans stale tracking refs LOCALLY but doesn't delete branches that still exist on GitHub (e.g., when the repo doesn't have "auto-delete branches after merge" enabled, or when a merge was done via external tooling). Surfaced when lalista's `feature/auth` stayed on `origin` after PR #10 merged despite local cleanup.
  - **Proposed logic**: for each merged PR (`gh pr list --state merged --limit 50 --json headRefName,mergeCommit`), check `git ls-remote origin <headRefName>` — if the ref still exists on origin AND the PR is merged, offer to delete it with `git push origin --delete <branch>`. Show the list with user confirmation before deleting (same pattern as the existing local-delete confirmation).
  - **Edge cases to handle**: skip `main` / `master` / any protected default branch; skip branches whose PRs were closed-without-merge (those might be intentional drafts); surface the count of merged-but-undeleted refs as a stat (useful for repo hygiene audits); **if the currently-checked-out branch matches a deletion target, checkout `main` first** (git refuses to delete the branch you're HEAD of — the current command silently no-ops on this case, which confused the user 2026-04-20 when `chore/close-auth-build-log` wasn't removed).
  - **Edit target**: rename the file `/devshop/.claude/commands/clean-branches.md` → `/devshop/.claude/commands/ak-clean-branches.md` and update the logic inside. Update any docs that reference `/clean-branches`.
- **`/ak-build` Phase 6 handoff nudge** — after printing the PR-ready link, also print the next-step hint:
  - Diff touches runtime code (`apps/web/**`, `packages/**`, `supabase/migrations/**`, `supabase/functions/**`) → `"Next step after you merge: run /ak-go-live to deploy + canary-check."`
  - Diff is docs-only (`docs/`, `README.md`, `BUILD-LOG.md`, `kit/`, `.github/**`, `specs/*/review.md`) → `"/ak-go-live not needed — no runtime changes."` (explicit, not silent skip).
  - Edit target: `/devshop/.claude/skills/devshop/build/SKILL.md § Phase 6`.
- **`/ak-build` Phase 7 + `/ak-go-live` Step 2b — restructure BUILD-LOG flow so no second PR is needed**. Current flow: Phase 7 tries to commit BUILD-LOG update to `main` after merge; on projects with the "main-is-PR-only" block (lalista has this via `check-branch-not-main.sh`), Phase 7 silently no-ops and `/ak-go-live` Step 2b opens a second PR (example: lalista PR #12 from 2026-04-20) just to write history. That's cruft — every project with a main-commit guard will hit it.
  - **Fix**: write the BUILD-LOG entry on the feature branch BEFORE the user merges, so merge brings it into main via the feature PR itself.
  - **New Phase 5.x** in `/ak-build` (after `/ship` creates the PR and PR number is known): finalize the BUILD-LOG entry — move the Phase 1 "In Flight" stub into `## Log`, fill in PR number + final commit list + quality gates + summary. Commit on the feature branch as `chore(build-log): record <feature>`. Push, amend the PR body if needed. The PR now carries its own history.
  - **Phase 7 goes away entirely.** No post-merge Claude-on-main commit; no PR-only violation.
  - **`/ak-go-live` Step 2b reduces to branch cleanup + In-Flight placeholder restore** (no BUILD-LOG update, no second PR).
  - **Edit targets**: `/devshop/.claude/skills/devshop/build/SKILL.md` (add Phase 5.x, delete Phase 7 BUILD-LOG step); `/devshop/.claude/skills/devshop/go-live/SKILL.md § Step 2b` (remove BUILD-LOG append; keep only branch cleanup + In-Flight placeholder). Cross-ref `/devshop/.claude/skills/gstack/ship/SKILL.md` if it references post-merge BUILD-LOG writing.
  - **Verification during Step 2**: dry-run on a fresh feature branch. Confirm: (a) Phase 5.x writes entry with correct PR number, (b) PR includes the entry in the diff, (c) after merge, main has the entry, (d) `/ak-go-live` Step 2b runs without attempting any commit on main.
- **`/ak-new-project` Phase B — Supabase auth hardening** — Supabase's free-tier defaults are too weak for any serious project (`password_min_length: 6`, CAPTCHA off, `rate_limit_email_sent: 2/hour`). `/ak-new-project` should patch these at setup time so no project ships with them by accident. Concretely:
  - **Target file**: `/devshop/.claude/skills/devshop/new-project/SKILL.md` — new sub-step inside Phase B, right after the Supabase project-linking step. Token (`SUPABASE_ACCESS_TOKEN`) is already in the shell env at that point.
  - **Mandatory patch (non-interactive)**: Management API call to `PATCH https://api.supabase.com/v1/projects/{ref}/config/auth` with `{"password_min_length": 8}`. Verify with a follow-up `GET` + grep.
  - **Interactive CAPTCHA step**: prompt "paste your hCaptcha secret (or blank to skip)"; if provided, `PATCH` with `{"security_captcha_enabled": true, "security_captcha_provider": "hcaptcha", "security_captcha_secret": "<paste>"}`. If skipped, log "captcha deferred — add before public launch" to `BUILD-LOG.md` so it surfaces at next status check.
  - **Document the hardening defaults**: short section in `kit/docs/guide/conventions.md` under a new `## Supabase Hardening Defaults` (between Screenshot Routing and Confidence Calibration) listing what `/ak-new-project` sets and why, so projects know what they inherited.
  - **Do NOT touch**: `rate_limit_email_sent` (leave as free-tier default 2/hour — tightening is a production-launch concern, not a setup-time concern; raising requires custom SMTP which is per-project). `disable_signup` (leave as false — invite-code alternative is a separate roadmap item; see `kit/ROADMAP.md § Invite-code signup control`).
  - **Verification during Step 2**: dry-run against a fresh test project OR against lalista's current hosted config (apply `password_min_length: 8` via Management API and confirm existing users aren't locked out). Mark complete when `curl ... /config/auth | jq .password_min_length` returns `8`.

All sit in the same "close evidence→action gap" theme as Fixes A-D. One version bump, one adversarial-review cycle. The paired bigger-picture entry for invite-code signup lives in `kit/ROADMAP.md § v1 § Invite-code signup control`.

- **Fix C expansion — Gate 9 user-state matrix**. The current `apps/web/e2e/qa-walk.spec.ts` uses the admin API with `email_confirm: true` and exercises a single user-state: already-confirmed, has-correct-password, no-household. That's the reason it missed lalista's onboarding 403 AND the sign-in silent-bounce bug. Fix C must enforce that Gate 9 exercises the matrix of user states that real users actually hit:

  | User-state                           | Why it matters                                                            | How to exercise                                                                                   |
  | ------------------------------------ | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
  | **Unconfirmed signup**               | Default Supabase config; new users ALWAYS hit this first                  | Create user with admin API `email_confirm: false`; walk until UI surfaces "check your email"      |
  | **Wrong password for existing user** | Real users mistype passwords constantly                                   | Existing confirmed user + intentionally wrong password; assert friendly error, no silent fallback |
  | **Rate-limited signup**              | Free-tier default `rate_limit_email_sent: 2/hour` trips easily in testing | Trigger 3 signups in rapid succession; 3rd must show friendly rate-limit message                  |
  | **Existing user, correct password**  | The canonical happy path (currently covered)                              | Already covered by current harness                                                                |
  | **Session expired mid-onboarding**   | Supabase tokens expire; RSC `getUser()` returns null                      | Create user, sign in, admin-delete session, attempt onboarding; assert redirect to `/sign-in`     |
  - **Edit target**: `/devshop/.claude/skills/devshop/pre-ship/SKILL.md § Gate 9` (per Step 2's existing Fix C plan) — add the matrix as mandatory evidence. Harness helpers live in each project's `e2e/helpers/` (or, post-convention, `@devshop-template/auth-ux`).
  - **Cross-ref to `kit/ROADMAP.md § v1 § Auth UX conventions`** — the QA-side matrix and the UX-side convention are paired. Projects implement the UX patterns; Gate 9 verifies they handle each user-state correctly.
  - **Verification during Step 2**: update lalista's `qa-walk.spec.ts` to exercise all 5 rows, watch it catch a regressing of the sign-in-silent-bounce bug if I intentionally break the fix.
  - **Friendly-error coverage** — add a case for the existing-user-via-signup-fallback pattern. Supabase's user-enumeration-prevention returns `data.user.identities: []` (empty) when signup hits an already-confirmed email; sign-in pages MUST check this before falling into "awaiting confirmation" UI. Concrete prior art in lalista `31b5637` (the initial awaiting-confirmation fix) and `e1ceb9c` (the identities-check follow-up).

- **`guide/conventions.md § Deploy Boundaries`** — new short section documenting what each deploy target covers. Every Supabase-backed project hits this question; a single place to point at saves repeated explanations.
  - **Content**: 4-row table — Next.js app (Vercel, auto on push), Supabase migrations (`supabase db push` / Management API, manual), Supabase edge functions (`supabase functions deploy`, manual), Supabase auth config (Management API or dashboard, manual). Plus a "when you ship a feature that touches both" pointer — migrations land first, then app deploy, then edge-fn deploy if applicable.
  - **Edit target**: `/devshop/kit/docs/guide/conventions.md` — new `## Deploy Boundaries` section (position: after Screenshot Routing, before Supabase Hardening Defaults when that lands from the earlier bullet).
  - **Why it belongs in Step 2**: discovered while closing out PR #10 — user asked "does Vercel deploy include Supabase changes?" — answer is no, migrations/functions/auth-config need separate deployment. That confusion will hit every next project; docs now, not later.
  - **Size**: ~20 lines of markdown; no code.

- **`/ak-new-project` Phase B — Supabase auth-hardening ADDITION: `site_url` + `uri_allow_list`** (extends the earlier hardening bullet). Free-tier defaults are `site_url: http://localhost:3000` and empty `uri_allow_list` — which silently breaks every email-based auth flow (password recovery, magic link, email change) the moment a user clicks a link from a real inbox. Surfaced 2026-04-20 when a recovery email link hung trying to load localhost:3000.
  - **Mandatory patch**: `PATCH /v1/projects/{ref}/config/auth` with `{"site_url": "<production_url>", "uri_allow_list": "<production_url>/**,https://<project>-<team>.vercel.app/**,http://localhost:3000/**"}`. Production URL comes from the `/setup-deploy` step earlier in `/ak-new-project`; Vercel wildcard is derived from the Vercel project name.
  - **Interactive confirmation**: read back the config after PATCH, show the 3 URLs, confirm with user they match the deploy targets. Misconfigured `site_url` is a silent failure mode — make it loud.
  - **Covers email-based auth flows** that projects otherwise have to debug in production: password recovery, magic-link sign-in, email change, signup confirmation.
  - **Paired with the v1 "Auth UX conventions" password-reset sub-pattern** — the code-side helpers (`PasswordResetCard`, `/auth/callback`, `/reset-password`) depend on these config values being correct. Hardening step sets the config; convention ships the routes.

- **`guide/conventions.md § Supabase Hardening Defaults` ADDITION: mandatory ON DELETE on auth.users FK references**. Any schema table that references `auth.users(id)` MUST specify `ON DELETE CASCADE`, `ON DELETE SET NULL` (with the column made nullable), or `ON DELETE RESTRICT` — explicitly. The Postgres default (`NO ACTION`) silently blocks user deletion as soon as any dependent row exists, which Supabase's built-in Authentication UI surfaces as the opaque "Database error deleting user." Surfaced 2026-04-20 when trying to delete a test user from the dashboard after they'd added 2 `list_entries`. Content for the convention section:
  > Every schema reviewer / `/ak-pre-ship` migration gate should reject a migration where a `references auth.users(id)` lacks an explicit `on delete` clause. Recommended defaults per column meaning: `added_by` / audit columns → `set null` (preserve history, lose attribution); tight ownership columns → `cascade`. Never use the default `no action` — it's a latent bug, not a design choice.
  - **Size**: ~10 lines of markdown inside the existing `guide/conventions.md § Supabase Hardening Defaults` section. No new section.
  - **Paired with lalista migration 009 (see § "Pending lalista work § standalone" below)** — the convention adds the rule; migration 009 retroactively fixes lalista's two offending FKs (`list_entries.added_by`, `purchase_history.added_by`).

### Pending lalista work (scheduled into the migration, NOT floating TODOs)

Items discovered during Step 1 that are lalista-side but not yet fixed. Each has a specific scheduling home (PR 2.1, PR 3, or refactor-after-v1-ships). These are migration work, not backlog — every item has a concrete next-session action.

#### Standalone (no dependency on devshop v1 helper)

- **Migration 009 — add `ON DELETE` to `auth.users` FK references**. Lalista's migration 001 declares `list_entries.added_by references auth.users(id)` and `purchase_history.added_by references auth.users(id)` with no explicit `on delete` clause — default `NO ACTION`. Result: any user who has added a list entry can't be deleted from the Supabase dashboard ("Database error deleting user"). Surfaced 2026-04-20. Schedule: **folded into PR 3** (decided 2026-04-20 — avoids a one-commit interstitial PR; co-located with the new write paths PR 3 introduces; the devshop `ON DELETE` FK convention landing in Step 2 guides the migration shape). Apply as the first migration in PR 3, before `/add-item` write paths land. Shape:
  ```sql
  -- 009_cascade_auth_user_fks.sql
  alter table list_entries
    drop constraint list_entries_added_by_fkey,
    add constraint list_entries_added_by_fkey
      foreign key (added_by) references auth.users(id) on delete set null;
  -- added_by becomes nullable to match; existing rows unaffected
  alter table list_entries alter column added_by drop not null;
  -- same for purchase_history
  alter table purchase_history
    drop constraint purchase_history_added_by_fkey,
    add constraint purchase_history_added_by_fkey
      foreign key (added_by) references auth.users(id) on delete set null;
  alter table purchase_history alter column added_by drop not null;
  ```
  Rationale for `SET NULL` over `CASCADE`: `added_by` is audit data; preserving the entry (with unknown attribution) is more useful than deleting history when a user leaves. `household_id` FKs already `CASCADE` and handle household dissolution.
  **Paired with the devshop convention** in Step 2's `guide/conventions.md § Supabase Hardening Defaults` (see above) — the convention prevents this in future projects; migration 009 retroactively fixes lalista.

#### Blocked on devshop v1 "Auth UX conventions" helper (refactor-to-adopt)

These are Category C finds that need the devshop v1 helper before they can be refactored cleanly; inline fix on lalista would just duplicate future work.

- **`/auth/callback` route** — handle Supabase's recovery / signup-confirm / email-change redirect tokens. Currently missing → all email-based auth flows hang. Status: NOT present in lalista yet; shipped as part of the v1 helper's route pattern.
- **`/reset-password` form** — landed on after a recovery-link callback. Calls `supabase.auth.updateUser({ password })`.
- **`PasswordResetCard` surface on `/sign-in`** — "Forgot password?" link that triggers `resetPasswordForEmail(..., { redirectTo: <callback URL> })`.
- **Verification** (once v1 helper ships + lalista adopts it): manually request a recovery email from Supabase dashboard → click link → land on `/reset-password` → set new password → signed in → land on `/`.

### Devshop infrastructure findings (pre-Step-2 reading)

Two container/firewall issues surfaced during Step 1 close-out that aren't already in Step 2 scope but WILL block Step 2 work if not addressed. Capture into `kit/TODOS.md` at Step 2 start:

1. **`sudo /usr/local/bin/init-firewall.sh` hangs the Claude Code session when re-run mid-session.** Container rebuild is the only known recovery. Root cause hypothesis (unconfirmed): iptables/ipset rebuild drops the session's own established API connection; when Claude Code reconnects against the new network state, commands stall indefinitely. Observed twice during 2026-04-20 lalista session. **Workaround**: never re-init the firewall during a session. If outbound HTTPS to a new domain fails mid-session (CDN IPs rotate), treat it as infrastructure TODO, don't try to hot-patch. **Proper fix** (Step 2 polish or later): investigate whether the firewall script can be made connection-preserving (e.g., atomic ipset swap instead of destroy-and-recreate), or run in a separate network namespace.
2. **gstack `browse` daemon's chromium chain is unreliable** because the fix requires re-running init-firewall (see #1). Playwright's CDN (`playwright.download.prss.microsoft.com`, `cdn.playwright.dev`) is in the firewall allowlist by domain name, but the CDN's edge IPs rotate and the ipset's resolved IPs go stale within hours. Mid-session `pnpm exec playwright install chromium` fails with `ENOTFOUND` / `EHOSTUNREACH` against the current IPs. **Proper fix** (Step 2, high-leverage): bake apt-installed `chromium + chromium-driver` into the devcontainer template Dockerfile, set `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` in `containerEnv`, drop the Playwright download step. Aligned with the existing `/home/node/.claude/projects/-workspace/memory` virtiofs note that already prescribes this for the Chromium install. **Prerequisite for**: `/canary` working reliably in `/ak-go-live` (currently falls back to curl-based health checks per the 2026-04-20 Step 1 session). **Edit target**: `/devshop/template/.devcontainer/Dockerfile` + `/devshop/template/.devcontainer/devcontainer.json`.

Both of these were observed but NOT committed to `kit/TODOS.md` during Step 1 close-out (context constraints). First task for a Step 2 session: append them as TODO entries.

### Current state (supersedes § "State at this handoff" below)

**Lalista** (`/workspace`):

- `main` tip: **`81b2638 chore: close auth in BUILD-LOG (#12)`** — PR #10 merged as squash `41b3eaa`; BUILD-LOG housekeeping merged as `81b2638`; `feature/auth` branch deleted locally + remotely.
- **PR #10**: **merged** 2026-04-20 (squash). 4 review checkboxes `[x]`, CI green, Vercel deploy complete via `/ak-go-live`.
- **PR #12** (BUILD-LOG close): merged. Unblocks the `main-is-PR-only` guard for future feature PRs.
- No active feature branches during Step 2 (all Step 2 work lives on devshop). Next lalista work is PR 3 after Step 2 lands.
- Working tree: clean
- Test counts at PR #10 merge: 35 web + 36 core + 21 UI = **92 unit tests pass**; `pnpm test:qa-walk` green against hosted Supabase
- Inline fixes with verification debt (see Core Principles § 4): `31b5637` and `e1ceb9c` owe a refactor-to-adopt once v1 Auth UX conventions ship

**Devshop** (`/devshop`, abra-kadabra):

- `main` tip: **`2aa4db1 docs(notes): /ak-clean-branches edge case — checkout main first if HEAD matches target`** (pushed)
- Latest tag: `v1.10.3` (behind main by a growing run of docs-only commits — no re-release needed until Step 2 lands implementation)
- Recent docs-only commits on `main` since `v1.10.3` (all captured in this doc's Step 2 scope; no implementation yet):
  - `2aa4db1` — `/ak-clean-branches` edge case: checkout main first if HEAD matches a target
  - `a85915a` — extend `/ak-clean-branches` scope to delete remote branches
  - `90f113c` — capture two devshop infra findings from Step 1 close-out (firewall re-init hang + Playwright CDN flakiness)
  - `44bb0fd` — Step 2: restructure `/ak-build` BUILD-LOG flow (Phase 5.x on branch, delete Phase 7)
  - `98379eb` — PR 3 /ak-spec question: restore public landing + move authed home to `/list`
  - `99adf23` — schedule migration 009 (auth.users FK cascades) into migration plan
  - `097e4d2` — capture password-reset flow gaps surfaced by PR #10 testing
  - `c93630a` — add Core Principles section + sync current state
  - `85cbfd6` — Deploy Boundaries section to Step 2
  - `982e28e` — Auth UX conventions (v1 ROADMAP) + Fix C user-state matrix expansion
  - `d4f9a42` — Supabase auth hardening (Step 2) + Invite-code signup (v1 ROADMAP)
- Working tree: clean
- **Implementation branch for Step 2**: `feature/preship-qa-reliability` (to be created from `main`)

**Hosted Supabase** (shared state — record so future sessions don't rediscover):

- Project ref: `nzfdfjctpotjyuxdfcpw`
- Migration `008_create_household_with_owner_rpc.sql` applied (not via CI; applied manually via Management API in this session — verified via `pg_policy` + `routine_privileges` queries)
- Auth config: defaults (free-tier) — `password_min_length: 6`, `rate_limit_email_sent: 2/hour`, `security_captcha_enabled: false`, `mailer_autoconfirm: false`, `disable_signup: false`, no custom SMTP. These are what Step 2's `/ak-new-project` auth-hardening step will tighten for future projects; lalista's hosted project can optionally be patched mid-Step-2 as a dry-run
- No orphan test users — admin-API `preship-qa@lalista-test.invalid` test user is created + deleted by `qa-walk.spec.ts`'s beforeAll/afterAll; all `*@lalista-test.invalid` diagnostic users cleaned up at end of this session

**Next actions (Step 2 now in progress)**:

1. ✅ Merge PR #10 (done — squash commit `41b3eaa`)
2. ✅ `/ak-go-live` (done — Vercel deploy + canary complete)
3. ✅ BUILD-LOG housekeeping PR #12 (done — `81b2638`)
4. **→ Execute Step 2 on devshop `feature/preship-qa-reliability` branch.** Full checklist in § "Step 2 scope expanded" above. Fresh-session resume: check `git -C /devshop log --oneline main..feature/preship-qa-reliability` to see completed commits; pick up at the next uncommitted item.

**If context resets during Step 2**: read § Core Principles, then this UPDATE section (you're here), then § "Step 2 scope expanded". Check branch progress before doing anything. Keep folded-into-PR-3 items (migration 009, Auth UX conventions refactor-to-adopt) in scope awareness but don't work on them during Step 2.

### Unchanged from the original plan

Steps 3 (PR 3 core flows) and 4 (PR 4 CI slow job) — scope + questions-for-ak-spec + CI matrix all stand as written below. Known Gaps 1-17 all still apply except Gap #5 (rate-limit has admin-API workaround now) and Gap #6 (dark mode) which is still deferred but was exercised during QA-walk by injecting `classList.add('dark')` — so the visual regression surface is covered even pre-ThemeProvider.

---

## TL;DR

lalista is migrating from native iOS (Swift/SwiftUI) to a Next.js 16 web app with Supabase backend, deployed on Vercel. The migration is split into **4 staged PRs** so each lands reviewable:

| PR                | Scope                                                                                                                                                                                            | Status                                                                                                                                               |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| PR 1 — Foundation | Archive Swift, finish design system (fonts, Text/Card/Input/Divider), API wrappers (auth, households, items, stores, addItem, realtime) in `@lalista/core`, edge fn `getUser()` check, PWA icons | **Merged to main** as `ade6dff`                                                                                                                      |
| PR 2 — Auth       | Sign-in screen (email + signup fallback), household onboarding (RSC + client form), `@supabase/ssr` middleware, PostHog auth events, Playwright happy-path E2E                                   | **Open as PR #10**, ready for review, CI green, Vercel preview Ready, but 4 manual-review checkboxes unchecked (close-out plan in this doc § Step 1) |
| PR 3 — Core flows | List view, add-item flow + disambiguation, item detail, settings, sync error banner, theme auto-detection                                                                                        | Not started — see § Step 3                                                                                                                           |
| PR 4 — Ship       | CI slow job (Supabase service + Playwright + type-drift + pg_dump), carry-forward fixes, docs                                                                                                    | Not started — see § Step 4                                                                                                                           |

**The next session's job**: execute the 4-step sequence in § "Sequence to execute" below.

**Devshop side**: the hook architecture migration (`/devshop/kit/notes/roadmap/hook-migration-plan.md`) should already be merged. If not yet, that's the prerequisite — see § "Prerequisites" below.

---

## State at this handoff (verify if stale)

### Lalista (`/workspace`)

- **Git remote**: `https://github.com/meirmsn/lalista.git` (private)
- **Default branch**: `main`
- **Active feature branch**: `feature/auth` (PR 2)
- **Latest commit on `feature/auth`** (as of handoff): `6618141 fix(auth): Tailwind workspace scan + touch target + layout centering + E2E email TLD`
- **PR #10 (auth)**: open, ready for review, CI green, Vercel preview at `https://lalista-git-feature-auth-meirs-projects-4803a76a.vercel.app`. Four manual-review checkboxes still unchecked — see § Step 1.
- **Main is at** (as of handoff): `ade6dff PR 1: lalista web foundation (design system, core API, edge fn auth) (#9)` + a small BUILD-LOG housekeeping commit (`8d0a31e`). Squash-merge is the repo's merge policy.
- **Working tree**: should be clean. Verify with `git -C /workspace status` at session start.

### Devshop (`/devshop` — abra-kadabra repo)

- **Git remote**: `git@github.com:meirmsn/abra-kadabra.git` (SSH; lalista's PAT can't write here)
- **Hook architecture migration** (`feature/hook-architecture-migration` branch): **should be merged** as a prerequisite for PR 3. If not merged yet, see § Prerequisites.
- **Verify** at session start: `git -C /devshop log -5 --oneline` and check that the migration commit is present.

### Environment

- Devcontainer has Playwright Chromium shared libraries (Dockerfile ships them).
- `/workspace/apps/web/.env.local` exists (gitignored), points at hosted Supabase, has `NEXT_PUBLIC_*` prefixed names.
- Shell env (from `.devcontainer/.env`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ACCESS_TOKEN`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`, `GITHUB_TOKEN`.
- Playwright chromium at `/home/node/.cache/ms-playwright/chromium-1217/chrome-linux/chrome` (version 147). `/ak-pre-ship` preflight auto-symlinks `chromium-1208` if the gstack `browse` daemon expects the older path.
- Next.js dev server is **not running**. Restart with `cd /workspace/apps/web && pnpm dev` (background).

---

## Prerequisites

Verify these before starting the 4-step sequence.

### 1. Hook architecture migration merged on devshop

`feature/hook-architecture-migration` (per `/devshop/kit/notes/roadmap/hook-migration-plan.md`) should be merged to abra-kadabra `main`. Check:

```bash
git -C /devshop log --oneline -10 | grep -i hook
ls /devshop/.husky/pre-push  # should exist
ls /devshop/.claude/skills/devshop/release-devshop/  # should exist
```

If NOT merged: pause and merge that PR first (per `roadmap/hook-migration-plan.md`). PR 3's `/ak-build` will use subagents heavily; without the hook migration, every subagent invocation gets hijacked by parent-scope hook noise.

### 2. Working tree clean (both repos)

```bash
git -C /workspace status --short  # should be empty
git -C /devshop status --short    # should be empty
git -C /workspace stash list      # should be empty
git -C /devshop stash list        # should be empty
```

If anything is dirty/stashed: address it first (commit, stash, or `.gitignore`). The new session-start hook will warn about this; honor the warning.

### 3. PR #10 status

Check PR #10's current state:

```bash
gh pr view 10 --json state,mergeable,reviewDecision,statusCheckRollup
```

If still open (expected at handoff): proceed to Step 1.
If already merged: skip to Step 2 (Fixes A-D) since PR 2's close-out is moot.

---

## Sequence to execute (4 steps)

### Step 1: Re-run PR 2 pre-ship cleanly → close PR #10's 4 unchecked boxes

**Goal**: close out PR #10 properly with full evidence (the 4 manual-review checkboxes) before merging.

**Why this is now feasible**: pre-PR 2 ran into hook noise + Supabase rate-limit + missing Chromium. The hook migration solved the hook noise. Chromium is shipped. Supabase rate-limit is solved by using LOCAL Supabase (per § Local Supabase workflow below).

**The 4 unchecked boxes on PR #10**:

| #   | Item                                                                         | What's needed                                                       |
| --- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1   | Visual 4-combo audit (`375/1440 × light/dark`) on `/sign-in` + `/onboarding` | 8 screenshots total (4 combos × 2 screens)                          |
| 2   | Live QA walkthrough — fresh sign-up → onboarding → home + edge cases         | E2E walk via browse, log to `qa-walk.log`                           |
| 3   | Middleware p95 post-deploy                                                   | Reviewer checks Vercel function metrics after merge (target < 50ms) |
| 4   | Onboarding hero screenshot                                                   | Captured as part of #1                                              |

**Path** (~30-45 min total):

1. **Start local Supabase**: `cd /workspace && supabase start`. Wait for API + Studio URLs.
2. **Point apps/web at local Supabase** — temporarily edit `/workspace/apps/web/.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
   NEXT_PUBLIC_POSTHOG_KEY=<keep hosted>
   NEXT_PUBLIC_SENTRY_DSN=<keep hosted>
   ```
3. **Force alice through onboarding** (`supabase/seed.sql` inserts her with a household; delete the membership to reach the onboarding path):
   ```bash
   psql "postgresql://postgres:postgres@localhost:54322/postgres" -c \
     "DELETE FROM household_members WHERE user_id='11111111-1111-1111-1111-111111111111';"
   ```
4. **Restart dev server**: `cd /workspace/apps/web && pnpm dev` (background).
5. **Walk the happy path via browse**:
   - `http://localhost:3000/` → assert 307 → `/sign-in`
   - Sign in as `alice@test.local` / `password123` → assert `/onboarding`
   - Fill "Casa QA", submit → assert `/`
   - Hard-refresh `/` → assert still authed
   - `localStorage.clear()` in devtools, reload → assert `/sign-in`
   - Wrong-password path: enter `alice@test.local` / `wrongpass` → assert inline error (no fallback signup)
   - Direct-nav `/onboarding` while authed-with-household → assert redirect to `/`
6. **Capture 4-combo matrix** at `/sign-in` (empty), `/onboarding` (empty):
   - 1440×900 light → `specs/auth/hero/signin-1440-light.png`, `onboarding-1440-light.png`
   - 375×667 light → `signin-375-light.png`, `onboarding-375-light.png`
   - Dark variants: run `document.documentElement.classList.add('dark')` in browse first (dark-mode toggle is not yet wired — see Known Gap #6), then capture: `signin-1440-dark.png`, `onboarding-1440-dark.png`, `signin-375-dark.png`, `onboarding-375-dark.png`.
7. **Commit hero additions** as a single commit on `feature/auth`. Include the qa-walk evidence (e.g., `specs/auth/qa-walk.log`).
8. **Mark the 4 checkboxes** `[x]` in PR #10's body via `gh pr edit 10 --body "..."`. Use the `https://github.com/<owner>/<repo>/raw/<branch>/<path>` URL form for hero shots (raw.githubusercontent.com 404s for private repos — see Known Gap #11).
9. **Revert `apps/web/.env.local`** to hosted Supabase (or keep local for iteration; just don't push — gitignored).
10. **`supabase stop`** to release Docker containers.

**After Step 1 completes**: PR #10 is ready to merge. Either merge directly or wait for human review approval.

---

### Step 2: Implement Fixes A, B, C, D — pre-ship QA reliability fix-plan

**Source**: this is the systemic fix-plan from the original `pr2-pending-checks.md` Parts 2-5. Inlined below.

**Goal**: convert pre-ship QA from "recommended + report back" into "evidence-first, no quietly-terminated runs." These four fixes together close the reliability gaps that produced PR 2's unchecked boxes in the first place.

**Branch**: `feature/preship-qa-reliability` on devshop (abra-kadabra). Commit structure: one bundled commit per the doc's recommendation, OR one commit per fix for reviewability — implementer's call.

**Estimated scope**: ~200 lines of SKILL.md edits + 1-2 new scripts + doc updates. One devshop feature branch, landed via ff-merge + single `/ak-release-devshop` invocation (**no PR on abra-kadabra** — see § "Devshop shipping flow (no PRs)" below).

#### Fix A — Local Supabase as the default for Gate 9

**Problem**: Gate 9 (`/qa`) hits Supabase for real signups to walk the happy path. Hosted Supabase rate-limits aggressively (~30-min cooldown after 1-2 attempts). Gate 9 currently gets `blocked` on a third-party dependency that isn't the PR's fault. Session agents work around this by declaring the walk blocked and moving on, which loses coverage.

**Design**:

`/ak-pre-ship` Phase 0 preflight gains a Supabase-availability check:

1. Is `supabase start` available (CLI installed + Docker running)? If no → `blocked` with fix recipe.
2. Is local Supabase already running? (`supabase status` returns API URL) → reuse.
3. Else → `supabase start` (~45s first time, ~10s warm).
4. Regenerate `apps/web/.env.local` to point at local (back up the original to restore on exit).
5. Verify schema + seed loaded: query `auth.users` for `alice@test.local` and `bob@test.local` → both should exist.

At end of `/ak-pre-ship` (success or failure), preflight's exit handler restores backed-up `apps/web/.env.local` and `supabase stop`s the local instance. Idempotent; safe to re-run.

**Implementation**:

- Edit `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` § Phase 0: extend "Tooling checks" with a `supabase start` availability block mirroring the current Chromium block (blocking if UI PR; non-blocking otherwise).
- Create `/devshop/kit/scripts/preship-supabase-bootstrap.sh`: the start/verify/env-rewrite/restore logic, invoked from preflight. Root-owned; user installs via sudo. Add NOPASSWD-sudo entry to `.claude/settings.json` if needed.
- Update `/ak-new-project` Step 13b to mention `.env.local` is now rewritten automatically by `/ak-pre-ship`; human sets it to hosted Supabase for dev.

**Verification**:

- Run `/ak-pre-ship` on lalista's `feature/auth` with hosted Supabase unreachable (simulate by pointing `.env.local` at bad URL). Without fix: Gate 9 fails or is blocked. With fix: preflight spins up local, Gate 9 walks `alice@test.local`, passes.
- Re-run. On second run: local Supabase already up, preflight reuses.
- Intentionally crash mid-pre-ship (`kill -9` dev server). Verify exit handler restores `.env.local` and stops Supabase.

#### Fix B — Gate 3 enforces the 4-combo evidence matrix

**Problem**: Gate 3 (Responsive + theme) says "verify at 4 combos" but doesn't check that 4 screenshots actually exist in `specs/<feature>/screenshots/`. A gate that takes 1 of 4 shots and reports `pass` hides the other 3 failures.

**Design**:

After all verification work inside Gate 3, inspect `specs/<feature>/screenshots/` for filename pattern `<screen>-{375,1440}-{light,dark}.png` for each primary screen. Primary screens are derived from PR's changed files — any new `apps/web/app/**/page.tsx` is a primary screen.

- All 4 combos × each primary screen exist → `pass`.
- Any missing → check `review.md § Gate 3` for explicit blocker mentioning the specific screen + combo (e.g., "375×dark for /sign-in skipped because dark-mode bootstrap deferred — see Known Gap #6"). If blocker reason present → `findings (N) [blocker documented]`. Otherwise → `blocked`.

Never silently `pass` when evidence is incomplete.

**Implementation**:

- Edit `pre-ship/SKILL.md` § Gate 3: add an "Evidence enforcement" subsection at the end. Inline the filename pattern and the blocker-documentation escape.
- Add helper to `preship-supabase-bootstrap.sh` (or separate `preship-evidence-check.sh`) that takes primary-screen list + `$FEATURE_DIR` and emits `pass`/`findings`/`blocked` on stdout.

**Verification**:

- Dry-run against `feature/auth` at single-hero state: Gate 3 returns `blocked` because `375/1440 × dark` files don't exist and blocker isn't documented.
- Add blocker doc to `specs/auth/review.md § Gate 3` ("dark-mode bootstrap deferred — see Known Gap #6") → Gate 3 returns `findings (N) [blocker documented]`.
- Capture all 4 combos → Gate 3 returns `pass`.

#### Fix C — Gate 9 must complete a happy path or report `blocked`

**Problem**: Same shape as Fix B but for end-to-end flow. Gate 9 currently has no structural requirement that the walk complete. The session pattern "walk fails, document it, `pass` on inferred-OK" can't happen if `pass` requires positive evidence.

**Design**:

Gate 9 emits one of:

- `pass` — happy-path walk completed end-to-end. Evidence: a Playwright trace OR structured log in `specs/<feature>/qa-walk.log` showing full sequence (URL → assertion → next URL → ...) with timestamps.
- `findings (N) fixed` / `findings (N) pending` — walk found issues.
- `blocked (<reason>)` — walk couldn't complete. Requires explicit reason (tooling gap, external dependency unreachable, etc.). Writes fix recipe to `review.md § Gate 9`.
- Never `skipped` — `skipped` is no longer a Gate 9 outcome.

The evidence file (`qa-walk.log`) is produced by the same script that drives the walk — see Fix A's browse-driven sequence. Gitignored by default.

**Implementation**:

- Edit `pre-ship/SKILL.md` § Gate 9: introduce three outcomes explicitly. Require evidence file.
- Add walk script as part of Fix A's bootstrap (shared infrastructure reads session state from preflight's local-Supabase bootstrap).

**Verification**:

- Local Supabase up, alice-with-no-household → walk produces `qa-walk.log` → `pass`.
- Kill local Supabase mid-walk → walk fails fast → Gate 9 returns `blocked (local Supabase crashed)` with fix recipe.
- Remove happy-path script → Gate 9 returns `blocked (walk script missing)` — doesn't silently `pass`.

#### Fix D — Evidence-first PR body reconciliation

**Problem**: PR body checkboxes can drift from reality: a box can be `[x]` when evidence doesn't exist, or `[ ]` when it does. During PR 2 both happened.

**Design**:

`/ak-build` Phase 6 (final sweep) already reconciles checkbox state against gate outcomes. Extend to also check **evidence-on-disk**:

- For every `[x]` in PR body that maps to an artifact (hero shot, qa-walk log, test-plan item), verify artifact exists in `specs/<feature>/` (or is referenced by absolute URL — e.g., Vercel preview URL for preview-deploy box).
- Emit sweep report listing any `[x]` with missing evidence.
- Phase 6 fails (pipeline halts) if evidence missing for any `[x]`.

**Implementation**:

- Edit `/devshop/.claude/skills/devshop/build/SKILL.md` § Phase 6 checkbox verification: extend existing reconciliation table with "Evidence present?" column mapping each checkbox type to file or URL that must exist for `[x]` to be legitimate.
- Emit diff block in audit comment listing discrepancies.

**Verification**:

- Manually toggle checkbox `[x]` before `/ak-build` Phase 6 runs, with no evidence file → Phase 6 halts with "evidence missing" error.
- Remove evidence file on disk after Phase 5.3's auto-check → Phase 6's sweep catches it.

#### Why these four together, not one-at-a-time

| Without this fix, a session can...                    | Fix that prevents it                                                      |
| ----------------------------------------------------- | ------------------------------------------------------------------------- |
| Cheerfully-skip a gate because tooling is unavailable | Already-landed `blocked` outcome + Fix A (tooling provisioned by default) |
| Claim Gate 3 `pass` with 1 of 4 screenshots           | Fix B (enforced 4-combo matrix)                                           |
| Claim Gate 9 `pass` without walking the happy path    | Fix C (positive evidence required)                                        |
| Ship a PR with `[x]` that doesn't match reality       | Fix D (body sweep cross-checks artifacts)                                 |

Fix A supplies the local Supabase that Fix C needs. Fix B and Fix C share the same evidence-file pattern. Fix D depends on B and C being live (cross-checks the artifacts they produce). Splitting across PRs means multiple rounds of reviewer context; bundling gives one coherent change.

**After Step 2 completes**: re-run `/ak-pre-ship` on lalista — should now pass with full evidence by construction.

---

### Step 3: PR 3 — lalista core flows

**Source**: detailed scope from `/workspace/PRODUCT-ROADMAP.md § v0 § 1e` and `/devshop/kit/notes/bootstrap/v0-web.md § 1e`. Inlined below.

**Goal**: ship the core lalista flows — list view (with realtime), add-item flow (with disambiguation), item detail, settings, sync error banner, optionally theme auto-detection.

**Workflow**: for each screen → implement → write tests (unit + E2E) → instrument metrics → mark done. Don't move to next screen until tests pass (this is `/ak-implement` convention).

**Recommended kickoff**: `/ak-build core-flows`. Detailed prompt in § "Session kickoff prompts" below.

#### Screens

**1. List view** (`apps/web/app/(list)/page.tsx`; replaces current `apps/web/app/page.tsx` placeholder):

- Items grouped by store — core UX differentiation, never flatten. Store label styled with `<Text variant="micro">` (uppercase 13px).
- Each row shows item name, brand (if any), quantity. Buy button on each row calls `markItemBought(client, entryId)` from `@lalista/core` (uses `mark_item_bought` RPC — never direct write to `purchase_history`; RLS blocks that — see Known Gap #8).
- Loading / empty / error states.
- Subscribes to Realtime channel via `subscribeToList(client, householdId, cb)` from `@lalista/core`. On every update, refetch via `fetchListEntries`. Subscribe on mount, unsubscribe on unmount.
- Sync error banner (see #5 below) appears when Realtime channel errors OR an RPC/query fails.

**2. Add item flow** — likely a FAB or sticky bar on list view (decision at /ak-spec time):

- Text input + submit button. Fires `invokeAddItem(client, { utterance, householdId })` from `@lalista/core`.
- On response: if `needs_followup === false`, optimistic insert into list (Realtime confirms). If `needs_followup === true`, show **disambiguation sheet** — first-class flow, not edge case (see Known Gap #10).
- Disambiguation sheet:
  - `followup_type === 'item'`: user picks from `followup_options` (candidate items). On pick: call `invokeAddItem` again with `candidateItemId` set.
  - `followup_type === 'store'`: user picks from available stores. On pick: `confirmedStoreId` set.
  - `followup_type === 'brand'`: brand confirmation.
  - `followup_type === 'quantity'`: already-on-list prompt ("want to increase quantity?").
- Reference Swift implementation: `ios-archive/ios/Sources/Views/List/DisambiguationSheet.swift` (bottom-sheet UI pattern, 4 variants).

**3. Item detail** (`apps/web/app/(list)/item/[id]/page.tsx`):

- Name, store, brand, quantity.
- Edit: name, store (picker from `fetchStores`), brand.
- Delete: calls `deleteListEntry`.

**4. Settings** (`apps/web/app/settings/page.tsx`):

- Sign out (calls `signOut(client)` from `@lalista/core` → middleware redirects to `/sign-in` on next request).
- Household name display (read-only for v0; rename deferred).

**5. Sync error banner** — persistent top-banner component shown when Supabase connection is unhealthy. Fires on Realtime channel error OR query fails with network error. Dismissible but re-appears on next error.

#### E2E — Playwright happy path

Extend `apps/web/e2e/auth.spec.ts` or add new `e2e/list.spec.ts`:

- Sign in → create household (if not yet) → add "leche" via text input → assert row appears → mark bought → assert row disappears from active list.
- Mobile 375 + desktop 1440 viewports (existing `playwright.config.ts` handles both).

#### Theme auto-detection E2E test

One Playwright test that does `page.emulateMedia({ colorScheme: 'dark' })` and asserts `<html>` has `dark` class applied. **Will fail as-written** until theme auto-detection is wired (see Known Gap #6).

Two options:

- **Option A**: include theme-detection bootstrap in PR 3 (adds `ThemeProvider` client component in `app/layout.tsx` that reads `prefers-color-scheme` and sets `classList.add('dark')` on `<html>`). Then E2E test passes. Cleaner scope decision.
- **Option B**: document test as `.skip()` with TODO pointing to a theme-bootstrap PR. Ship core flows without it.

Spec writer (whoever runs `/ak-spec`) should ask user to pick at start of PR 3.

#### Metrics

Add to `METRICS.md` (with user confirmation from `/ak-spec`):

| Event                  | Fires on                                                                                    | Properties                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `item_added`           | `invokeAddItem` success, `needs_followup === false`                                         | `{ store_id, was_disambiguated: boolean, input_language: 'es'\|'en' }` |
| `item_bought`          | `markItemBought` resolves                                                                   | `{ time_on_list_seconds: number }` (compute from `added_at` → now)     |
| `disambiguation_shown` | `invokeAddItem` returns `needs_followup === true`                                           | `{ candidate_count: number, followup_type: string }`                   |
| `store_routed`         | Edge fn resolved store from purchase history (embed in server response, client fires event) | `{ store_name: string, confidence_score: number }`                     |
| `error_displayed`      | Sync error banner appears                                                                   | `{ error_type: 'realtime' \| 'query', screen: string }`                |

Instrument via `posthog.capture()` — pattern in `apps/web/app/providers.tsx` and `apps/web/lib/analytics.ts` from PR 2.

#### Unit tests

For each screen — React Testing Library + Vitest — assert:

- Component renders initial state correctly (loading, empty, populated).
- Actions call the right `@lalista/core` wrapper with right args.
- Disambiguation sheet selection round-trips into a follow-up `invokeAddItem` call.
- Error states render correctly.

#### Questions to ask user at /ak-spec time for PR 3

These should be resolved before locking the spec:

1. **ThemeProvider in PR 3 or defer?** (Option A or B above)
2. **FAB or sticky input bar for add-item?** Swift was a FAB; web has different idioms.
3. **Disambiguation sheet UI form?** Bottom sheet (Swift parity) vs. inline dropdown vs. modal.
4. **Confirm the 5 new METRICS.md events?** (`item_added`, `item_bought`, `disambiguation_shown`, `store_routed`, `error_displayed`) — user must confirm before `/ak-spec` appends them per devshop convention.
5. **Sign-out surface location?** Settings page only, or also a menu/header affordance?
6. **PR 3 close-out gates**: Step 1 already closed PR #10's matrix gap. PR 3's `/ak-pre-ship` exercises richer UI surface; confirm pre-ship targets (which screens get the 4-combo matrix, etc.).
7. **Information architecture — restore the landing page at `/` and move the authed home to `/list`?** Surfaced 2026-04-20: the current `/` page renders a `lalista` wordmark + "say leche. it handles the rest." + "Get started" button (the landing content), but `middleware.ts` redirects every unauth request from `/` to `/sign-in`, making the landing unreachable. PR 3 is the natural place to resolve this because it replaces the `/` placeholder with the list view anyway. Proposed IA for v0 (confirm at `/ak-spec`):
   - `/` → **public landing** (unauth allowed; shows wordmark + tagline + "Get started" button → `/sign-in`; authed-with-household users see a "Go to your list" CTA or redirect to `/list`)
   - `/list` (new path) → authed home, the grouped-by-store list view — PR 3's main deliverable
   - `/sign-in`, `/onboarding` — unchanged from PR 2
   - Middleware matcher needs two edits: remove `/` from auth-required, add `/list` as auth+household-required, update authed-`/sign-in` redirect destination to `/list` (currently `/onboarding` which handles the household gate on its own)
   - Open sub-question: is `/` content purely marketing (sparse), or a dashboard-y "overview" for authed users? Depends on what product value exists beyond the list.

---

### Step 4: PR 4 — CI slow job + carry-forward fixes + docs

**Source**: phase-1-next-steps.md § PR 4 + ROADMAP.md "CI slow job expansion" entry.

**Goal**: wire up the slow CI job that's been deferred from PR 1.

#### Scope

- Uncomment `slow` job in `.github/workflows/ci.yml`. Currently `needs: fast`, `if: github.event_name == 'pull_request'`.
- Add (Trigger 1 — DB-backed feature, satisfied by PR 2/3):
  - `supabase/setup-cli` GitHub Action
  - `supabase start` (GitHub Actions has native Docker — no DinD needed)
  - Load `seed.sql` via `psql` against local Supabase Postgres
  - Integration test step: `pnpm turbo run test`
  - Type drift check: `supabase gen types typescript` → `git diff --exit-code packages/core/src/supabase.types.ts` → fail if drifted
  - Rollback SQL validation: for each new migration, extract `-- ROLLBACK` block and parse against local Postgres (e.g., `EXPLAIN` wrapper). Fail on syntax errors.
  - Mask secrets: `echo "::add-mask::$SUPABASE_SERVICE_ROLE_KEY"`
- Add (Trigger 2 — E2E-testable flow, satisfied by PR 3):
  - Install browsers: `npx playwright install --with-deps chromium`
  - Build + start app: `pnpm turbo run build --filter apps/web` then `npx next start` against local Supabase
  - Run E2E at both viewports: `npx playwright test --project=mobile --project=desktop`
  - Upload trace artifacts on failure via `actions/upload-artifact`
  - Cache Playwright browsers using lockfile hash
- Update branch protection to require `slow` as required status check alongside `fast`.

**Additional GitHub Secrets needed**: `SUPABASE_SERVICE_ROLE_KEY` (integration tests need admin), `ANTHROPIC_API_KEY` (if edge function integration tests call Anthropic).

**Caching** (both jobs): pnpm store (`actions/cache`), Turborepo outputs, Playwright browsers. Cache keys use lockfile hash.

**Expected CI minutes**: ~260 min/month for 10 PRs (20 fast × 4 min + 10 slow × 15 min). Free tier: 2000 min/month.

#### Carry-forward fixes

Whatever's still pending from earlier PRs after Step 3 completes. Survey current state at start of PR 4. Likely candidates:

- Theme auto-detection bootstrap (if Option B was chosen in PR 3 and not done since)
- Any deferred items from PR 3's `/ak-pre-ship` close-out
- Any "future PR" notes added to specs/

#### Docs

- Update `BUILD-LOG.md` with PR 3 + PR 4 entries
- Update `README.md` if any user-facing details changed
- Update project `CLAUDE.md` "Where Things Happen" section as new paths get added

---

## Known gaps to carry forward

These are non-obvious gotchas from PR 2's implementation. Don't get re-surprised.

### 1. Tailwind v4 + workspace packages

`apps/web/app/globals.css` contains:

```css
@import 'tailwindcss';
@source "../../../packages/ui/src/**/*.{ts,tsx}";
```

The `@source` directive is **required** — without it, Tailwind v4 strips all token utilities (`bg-primary`, `border-border`, etc.) only used inside `packages/ui/**`. If you add new workspace packages that ship styled components (e.g., a future `packages/icons`), add a matching `@source` line. Forgetting = unstyled output.

### 2. Button primitive includes `min-h-[44px]` for touch target

Per `DESIGN.md § Interactive minimums`. Don't remove it. If you add new Button variants, inherit the min-height.

### 3. Auth shell uses `min-h-screen`, not `min-h-full`

`apps/web/app/(auth)/layout.tsx` uses `min-h-screen` because body is flex-column and percentage min-heights on flex items are ambiguous. New shell layouts that want to fill viewport should use `min-h-screen` too (or flex-1 in appropriate parent).

### 4. E2E emails use `@example.com` (RFC 2606), never `@*.local`

Supabase's email validator rejects `.local` TLD. For `supabase.auth.signUp` or `.signIn` from E2E, use `@example.com`. Seeded users (`alice@test.local`, `bob@test.local` in `supabase/seed.sql`) work because seed.sql inserts directly into `auth.users` and bypasses validator.

### 5. Supabase rate-limits new signups aggressively on hosted project

Observed during PR 2 pre-ship: after 1-2 `signUp` attempts, all subsequent calls with any email domain return "email rate limit exceeded" for ~30 minutes. For local QA / hero screenshots, **start local Supabase** (`supabase start`) and use seeded users (see § Local Supabase workflow below).

### 6. Dark mode is unreachable in shipped code

`.dark` class CSS exists in `apps/web/app/globals.css:35`. Nothing adds the class. No `ThemeProvider`, no `prefers-color-scheme` listener. Deferred gap from PR 1's design system. PR 3 may close this (Option A in § Step 3 Theme test) or defer to future theme PR.

### 7. `add-item` edge function already has `getUser()` auth check

Landed in PR 1 (`supabase/functions/add-item/index.ts`). Returns 401 without valid Bearer token. Don't re-add or "improve" without reading what's there.

### 8. `mark_item_bought` RPC is the ONLY way to mark bought

RLS blocks direct client inserts to `purchase_history`. `@lalista/core`'s `markItemBought(client, entryId)` uses `supabase.rpc('mark_item_bought', { p_entry_id: entryId })`. Don't call `purchase_history.insert` directly anywhere.

### 9. Realtime is enabled for `list_entries` — use `subscribeToList`

`@lalista/core` `api/realtime.ts` exports `subscribeToList(client, householdId, callback) → unsubscribe`. Wraps Supabase Realtime channel filtered by `household_id=eq.<id>`. Use this for list view's live updates — never poll.

### 10. Disambiguation is a first-class flow, not an edge case

`invokeAddItem` returns `needs_followup: true` whenever edge function's NLP/matching confidence is below threshold. That's common, not rare. Disambiguation sheet must be designed and tested as part of happy path, not as error case.

### 11. Private repo image URL in PR bodies

`raw.githubusercontent.com` URLs require auth tokens and silently 404 for viewers. Repo-relative paths (`specs/auth/hero/signin.png`) don't resolve in PR bodies. Use `https://github.com/<owner>/<repo>/raw/<branch>/<path>` — GitHub handles auth for authenticated viewers. Codified in `/ak-build` v1.2.0 PR body conventions.

### 12. PR body checkbox discipline

Pre-push gates `[x]` at PR creation. CI gates `[x]` when their signal lands (Phase 5.3 of `/ak-build`). Human-review items **never** auto-checked. Phase 6 reconciles. Full table in `/devshop/.claude/skills/devshop/build/SKILL.md § PR body conventions`.

### 13. Chromium symlink auto-heal

`/ak-pre-ship` Phase 0 preflight symlinks `chromium-1208` → whatever's installed. This exists because gstack `browse` daemon is pinned to older version. If you invoke `browse` outside `/ak-pre-ship` and it fails with "Executable doesn't exist at chromium-1208", re-run preflight logic manually:

```bash
LATEST=$(ls -d /home/node/.cache/ms-playwright/chromium-* | grep -v headless_shell | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium-1208 ] && ln -sf "$LATEST" /home/node/.cache/ms-playwright/chromium-1208
LATEST_HS=$(ls -d /home/node/.cache/ms-playwright/chromium_headless_shell-* | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium_headless_shell-1208 ] && ln -sf "$LATEST_HS" /home/node/.cache/ms-playwright/chromium_headless_shell-1208
```

### 14. ~~Subagent hooks scope — separate session~~ **RESOLVED 2026-04-18**

Resolved by hook architecture migration. See `/devshop/kit/notes/roadmap/hook-migration-plan.md`. Workflow nudges moved to git layer (husky pre-push) — agent-agnostic by construction. PostToolUse Bash workflow hooks deleted entirely.

### 15. Fine-grained PAT lacks Checks permission

Lalista PAT can't access Check Runs API (GitHub removed Checks permission from fine-grained PATs — see community discussion #129512). `gh pr checks` returns partial data. Use:

```bash
gh run list --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch --exit-status
```

For CI monitoring. Covered by `Actions: Read` which the PAT has.

### 16. Devshop + project clean-tree cross-check

Pre-commit hooks in both repos check the OTHER repo's tree is clean. If you're mid-work on both sides simultaneously, use `git stash push -u` on non-committing side first, commit, then pop. Or use `git -c devshop.dirtyTreeReason="..."` escape hatch (adversarially reviewed).

After hook architecture migration: the new pre-push hook adds another layer — pushing while either repo is dirty also blocks (with `dirtyPushReason` bypass). Same pattern.

### 17. Devshop docs-drift + docs-consistency adversarial reviewers

When committing changes to `/devshop/.claude/skills/` or `/devshop/kit/`, two separate pre-commit guards may fire:

- `docs-drift` — expects `git -c devshop.docsVerified="..."` listing which of 7 top-level docs (MODEL.md, OVERVIEW.md, kit/docs/guide/, CLAUDE.md, FAQ.md, project CLAUDE.md, README.md) you reviewed and why they don't need updates (or which ones you updated).
- `doc-consistency` — expects `git -c devshop.docSyncReason="..."` when `kit/docs/guide/*` files could be affected.

Both have adversarial reviewers that read your reason and reject weak ones. Write thorough reasons covering every doc.

---

## Artifacts already in place

Don't re-implement these — they're done.

### `packages/core` exports (all usable as-is)

- **Auth**: `signInWithPassword`, `signUpWithPassword`, `signOut`, `getSession`, `getUser`, `onAuthStateChange`
- **Households**: `fetchUserHouseholds`, `fetchUserMemberships`, `createHousehold`
- **Items**: `fetchListEntries(client, householdId, status)`, `markItemBought(client, entryId)`, `deleteListEntry`
- **Stores**: `fetchStores`
- **Add-item**: `invokeAddItem(client, { utterance, householdId, candidateItemId?, confirmedStoreId?, confirmedBrand? })` → returns typed `AddItemResponse`
- **Realtime**: `subscribeToList(client, householdId, cb) → unsubscribe`
- **Supabase client factory**: `createClient({ supabaseUrl, supabaseAnonKey })`
- **Types**: `Item`, `Store`, `Household`, `HouseholdMember`, `ListEntry`, `HydratedListEntry`, `DisambiguationCandidate`, `AddItemResponse`

### `packages/ui` exports

- `Button` (44px min-height, primary color, focus ring)
- `Text` (semantic type scale: display, display-italic, heading-lg, heading-md, body-lg, body, caption, micro)
- `Card` (surface bg, border, default radius)
- `Input` (focus ring, error state)
- `Divider` (1px border-token horizontal rule)
- Design tokens: `colors`, `spacing`, `radius`, `fonts`, `fontScale`, `breakpoints`, `duration`
- Snapshot tests for each component (update with `vitest -u` when styling changes)

### Web scaffolding

- `apps/web/lib/supabase/{client,server}.ts` — `@supabase/ssr`-wrapped factories; use these instead of creating clients inline
- `apps/web/lib/analytics.ts` — `trackSignedIn`, `trackSignedOut` + event-name constants; extend with `trackItemAdded`, `trackItemBought`, etc. as you add PR 3 events
- `apps/web/middleware.ts` — route protection (unauth → /sign-in, authed-no-household → /onboarding); matcher excludes `_next/static`, `_next/image`, `favicon.ico`, `manifest.json`, `icons/*`
- `apps/web/app/providers.tsx` — PostHog init + `onAuthStateChange` subscription

### Design system

- `DESIGN.md` at project root — frozen reference. No new colors, no new type-scale items. Use tokens from `@lalista/ui`.
- Fraunces (display) + Plus Jakarta Sans (body) loaded via `next/font/google`.

### Supabase

- Schema migrations 001–007 in `supabase/migrations/`
- Edge function `add-item` at `supabase/functions/add-item/index.ts` — deployed; has `getUser()` auth check; returns `AddItemResponse` shape
- Seed data in `supabase/seed.sql` — production catalog (stores, items) + test fixtures (`alice@test.local` / `password123`, `bob@test.local` / `password123`, 2 households, 2 pending list entries). Fixed UUIDs for deterministic RLS tests.
- RPCs: `mark_item_bought(p_entry_id)`, `find_item_by_trgm`, `find_item_alternatives`, `route_item_to_store`, `current_household_id`, `my_household_ids`

### Observability

- Sentry wired via `@sentry/nextjs` — config in `apps/web/sentry.{client,server}.config.ts`, `instrumentation.ts`
- PostHog wired via `posthog-js` in `apps/web/app/providers.tsx`
- METRICS.md has `auth_signed_in` and `auth_signed_out` — add PR 3 events here

### CI

- `.github/workflows/ci.yml` runs fast job on every push (lint + typecheck + test:unit + build)
- Slow job placeholder commented out; wiring is PR 4 scope (see § Step 4)
- GitHub Actions secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`

### Tests green at PR 2 handoff

- `packages/core`: 36 tests — all wrappers mocked
- `packages/ui`: 21 tests — snapshot tests for primitives
- `apps/web`: 31 tests — middleware matrix, sign-in fallback paths, onboarding redirects, analytics events, Supabase helpers

Total: **88 passing**. Whatever PR 3 adds should bring this up, not break existing.

---

## Dev environment — quick-start commands

```bash
# Install deps
cd /workspace && pnpm install

# Verify env file
cat /workspace/apps/web/.env.local   # should show NEXT_PUBLIC_* vars

# Start Next dev server (background)
cd /workspace/apps/web && pnpm dev
# Wait for "Ready in Xms", curl http://localhost:3000/ → 307 to /sign-in

# Run unit tests
pnpm turbo run test:unit

# Full gate suite
pnpm turbo run lint typecheck test:unit build

# Parse Playwright specs (doesn't execute)
pnpm --filter @lalista/web exec playwright test --list

# Execute Playwright (if browser + Supabase ready)
pnpm --filter @lalista/web exec playwright test
```

---

## Local Supabase workflow (for QA / pre-ship)

Hosted Supabase rate-limits signups (Known Gap #5). For 4-combo matrix, happy-path walks, hero screenshots, etc., use local Supabase:

```bash
supabase start     # starts Docker containers for Postgres, Auth, Realtime, etc.
supabase status    # prints local API URL + anon key — use these
```

Temporarily edit `/workspace/apps/web/.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
NEXT_PUBLIC_POSTHOG_KEY=<keep hosted>
NEXT_PUBLIC_SENTRY_DSN=<keep hosted>
```

Restart dev server to pick up new vars. Use `alice@test.local` / `password123` (or `bob@test.local`) for sign-in — they bypass email validator.

When done:

```bash
# Revert .env.local to hosted (or keep local for iteration; gitignored either way)
supabase stop
```

After Fix A (§ Step 2) lands, this becomes automatic — `/ak-pre-ship` Phase 0 preflight handles bootstrap + restore.

---

## Hero screenshot workflow

gstack's `browse` skill + `/ak-pre-ship` preflight symlink work together.

```bash
# Make sure browse is up
cd /workspace/.claude/skills/gstack/browse/dist && ./browse status

# Capture
./browse goto http://localhost:3000/sign-in
./browse screenshot /workspace/specs/<feature>/hero/signin.png --full-page
```

For dark-mode shots under unreachable-dark-mode gap (Known Gap #6):

```bash
./browse exec "document.documentElement.classList.add('dark')"
./browse screenshot /workspace/specs/<feature>/hero/signin-dark.png --full-page
```

---

## Devshop shipping flow (no PRs)

**Critical** — the devshop (abra-kadabra) uses a different landing flow than projects like lalista. Source of truth: `/devshop/CLAUDE.md § "Devshop shipping flow (no PRs)"`. This section restates the flow in migration-doc terms so Step 2 / Step 3 / Step 4 sessions don't re-discover the trap.

**The flow is branch → ff-merge → `/ak-release-devshop`. NOT a PR.**

1. **Branch**: `feature/<descriptive-name>`. Commit as usual; pre-commit guards (cross-repo clean-tree, docs-drift, doc-consistency, kit tests, gitleaks) are the quality gate. Iterate commits on the branch until guards pass.
2. **Land with fast-forward**: from main, `git merge --ff-only feature/<name>` — no new commit, just a pointer move. Claude CAN do this: the main-commit block (`check-branch-not-main.sh`) applies to `git commit`, not `git merge --ff-only`. If main has diverged (a different branch landed in the meantime), rebase the feature branch first: `git rebase main <branch>` then ff-merge.
3. **Release**: `/ak-release-devshop` from main. The skill categorizes commits since last tag, proposes a bump (patch/minor/major), asks for confirmation, then runs `kit/scripts/release.sh` which writes `kit/version`, generates a CHANGELOG entry, creates the bump commit (this is the ONE legitimate main commit — release.sh wraps it so the PreToolUse hook doesn't see a bare `git commit` on main), tags, pushes via the DEVSHOP_GITHUB_TOKEN HTTPS URL, and creates a GitHub release. The `release-coverage` adversarial review fires at the bump-commit step.

**⚠ Do NOT**:

- Open a PR on abra-kadabra. There isn't a reviewer; it's single-developer + private. The DEVSHOP_GITHUB_TOKEN doesn't have Pull Requests: Write scope anyway, so `gh pr create` / `curl POST /pulls` both fail with 403 — past sessions have wasted cycles retrying this.
- Push to `origin/main` manually before running `/ak-release-devshop`. Let the release script do the push so the version bump + tag + push + release are atomic.
- Push directly to `main` from any command other than release.sh. The PreToolUse branch-not-main guard + pre-push protections exist to catch this.

**Still applies** (these are commit-time, not PR-time):

- **Cross-repo clean-tree**: husky pre-commit blocks if the OTHER repo is dirty. Use `git stash push -u` on the non-committing side, OR `git -c devshop.dirtyTreeReason="..."` (adversarially reviewed).
- **docs-drift / doc-consistency**: when changing `kit/` or `kit/docs/guide/`, both adversarial reviewers may fire. Have `docsVerified` / `docSyncReason` reasons ready covering each of the 7 top-level docs where relevant.
- **Pre-push `prDescStaleReason`**: `.husky/pre-push` can adversarially review PR-description freshness if an open PR exists on the pushed branch. For devshop work no PR exists, so this check short-circuits in practice. Pushes to `main` itself also short-circuit (per `/devshop/CLAUDE.md` line 82). Safe to push.
- **Pre-push `dirtyPushReason`**: blocks push to non-main branches when the working tree is dirty or has stashes; bypass via `git -c devshop.dirtyPushReason="..."`.

**PR-specific conventions** (e.g., PR body image URLs, checkbox timing) apply to **lalista** PRs — not to abra-kadabra work. See `/devshop/.claude/skills/devshop/build/SKILL.md § "PR body conventions"` for the project-side rules.

---

## Session kickoff prompts

### For Step 1 (PR #10 close-out)

> I'm continuing the lalista migration. The hook architecture migration on devshop is merged. PR #10 (auth) is open with 4 unchecked manual-review boxes. I want to close them out via the local-Supabase workflow per `/devshop/kit/notes/lalista-migration-resume.md § Step 1`.
>
> Read that doc first. Then:
>
> 1. Verify prerequisites (hook migration merged, both repos clean).
> 2. Spin up local Supabase, point apps/web at it, force alice through onboarding.
> 3. Walk the happy path + edge cases via browse, log evidence to `specs/auth/qa-walk.log`.
> 4. Capture the 4-combo matrix (8 hero shots).
> 5. Commit + update PR #10 body to mark all 4 boxes `[x]`.
> 6. Revert `.env.local` to hosted and `supabase stop`.

### For Step 2 (Fixes A-D devshop feature branch)

> I want to implement the pre-ship QA reliability fix-plan in `/devshop/kit/notes/lalista-migration-resume.md § Step 2`. Four fixes (A: local Supabase Gate 9 preflight; B: Gate 3 evidence enforcement; C: Gate 9 completion requirement; D: Phase 6 evidence-on-disk sweep).
>
> Branch: `feature/preship-qa-reliability` on devshop. Landing flow is **ff-merge + /ak-release-devshop — not a PR** (see § "Devshop shipping flow (no PRs)" in the resume doc).
>
> Read the doc first. Then propose commit structure (one bundled commit or one per fix; prefer one per fix for reviewability). Verify each fix with the verification steps in the doc. Use lalista's `feature/auth` (already in /workspace) as target of dry-run, since it's a real spec with real artifacts.
>
> Devshop adversarial reviewers will fire (docs-drift + doc-consistency). Have `docsVerified` and `docSyncReason` reasons ready.

### For Step 3 (PR 3 lalista core flows)

> I'm continuing the lalista migration — PR 3 (core flows). PR 2 is merged and closed out. Devshop hardening (hook migration + Fixes A-D) is merged. Now I want to start PR 3.
>
> Read `/devshop/kit/notes/lalista-migration-resume.md § Step 3` for the detailed scope (5 screens + E2E + metrics). Then run `/ak-build core-flows`.
>
> At /ak-spec time, ask me the 6 open questions in § Step 3 → "Questions to ask user at /ak-spec time for PR 3".

### For Step 4 (PR 4 CI slow job)

> PR 3 is merged. Now wire up the CI slow job per `/devshop/kit/notes/lalista-migration-resume.md § Step 4`. Add Supabase service + Playwright + type drift + rollback SQL validation steps to `.github/workflows/ci.yml`. Update branch protection to require `slow` as required check.

---

## References (historical, for deeper dives)

- `/devshop/kit/notes/phase-1-next-steps.md` — original migration handoff (this doc supersedes for forward work; consult for original phrasing/context)
- `/devshop/kit/notes/pr2-pending-checks.md` — original PR 2 close-out + 4-fix design (this doc inlines § Step 1 = Part 1 Path A; § Step 2 = Parts 2-5)
- `/devshop/kit/notes/subagent-hook-scope.md` — RESOLVED. Original investigation. Resolution path differed from both proposed approaches; see roadmap/hook-migration-plan.md.
- `/devshop/kit/notes/roadmap/hook-migration-plan.md` — the implementation plan for the architectural fix that resolved Known Gap #14. Should be merged before Step 1.
- `/home/node/.claude/plans/we-decided-to-do-scalable-shore.md` — strategic 4-PR plan written at session start (parent of phase-1-next-steps.md)
- `/devshop/kit/notes/bootstrap/v0-web.md § Phase 1` — original migration blueprint; § 1e is PR 3 scope ancestor; § 1g is PR 4 ancestor
- `/workspace/PRODUCT-ROADMAP.md § v0` — project-level roadmap; mirrors v0-web.md § Phase 1
- `/workspace/specs/auth/spec.md` — PR 2's implementation spec. Pattern to emulate for PR 3.
- `/workspace/specs/auth/review.md` — PR 2's pre-ship review. Pattern for PR 3.
- `/workspace/CLAUDE.md` — project conventions + deploy config. "Where Things Happen" section.
- `/devshop/CLAUDE.md` — devshop conventions. Non-negotiables, confidence calibration, workflow.
- `/devshop/.claude/skills/devshop/build/SKILL.md` — `/ak-build` skill (v1.2.0+). Read before first invocation.
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` — `/ak-pre-ship` skill (v3.2.0+). Will be modified by Step 2 (Fixes A-D).
- `/devshop/kit/TODOS.md` — devshop tactical backlog. Lines 76, 77, 78 should be `[x]` after hook migration.
- `/devshop/kit/ROADMAP.md` — strategic backlog. "Self-correcting workflow patterns" entry under v+ is the deferred Alt B from hook migration discussion.

---

## Verification at session start

Before doing anything substantive:

```bash
# 1. State check
git -C /workspace status --short    # should be empty
git -C /workspace branch --show-current  # should be feature/auth or main
git -C /devshop  status --short    # should be empty
git -C /devshop  log -5 --oneline  # confirm hook migration is in
gh pr view 10 --json state,reviewDecision  # confirm PR #10 status

# 2. Tooling check
ls /devshop/.husky/pre-push                                   # should exist
ls /devshop/.claude/skills/devshop/release-devshop/SKILL.md   # should exist
which supabase                                                # should resolve
ls /home/node/.cache/ms-playwright/chromium-* | head -1       # should exist
```

If any of these fail, read § Prerequisites and address before proceeding.
