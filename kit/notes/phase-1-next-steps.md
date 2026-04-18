# lalista — Phase 1 Next Steps (self-contained handoff)

**Paste this whole file into a fresh Claude Code session to continue
the Swift → React/Next.js migration.** The new session doesn't need to
read any other file to start — everything critical is inline below.
Pointers to deeper-context docs appear in § "Related docs" at the
bottom, for when a specific detail needs fuller history.

**Source of truth for the 4-PR migration plan:**
`/home/node/.claude/plans/we-decided-to-do-scalable-shore.md` — created
via plan-mode at session start; defines the strategy we're executing.
This file is the operational handoff; that file is the strategic one.

---

## TL;DR

lalista is migrating from native iOS (Swift/SwiftUI) to a Next.js 16 web
app with Supabase backend, deployed on Vercel. The migration is split
into **4 staged PRs** so each lands reviewable:

| PR                | Scope                                                                                                                                                                                                | Status                                                                            |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| PR 1 — Foundation | Archive Swift, finish design system (fonts, Text/Card/Input/Divider), API wrappers (auth, households, items, stores, addItem, realtime) in `@lalista/core`, edge fn `getUser()` check, PWA icons     | **Merged to main** as `ade6dff`                                                   |
| PR 2 — Auth       | Sign-in screen (email + signup fallback), household onboarding (RSC + client form), @supabase/ssr middleware, PostHog auth events, Playwright happy-path E2E                                         | **Open, ready for review** — PR #10 at https://github.com/meirmsn/lalista/pull/10 |
| PR 3 — Core flows | **NEXT** — list view (items grouped by store, realtime, mark-bought RPC), add-item flow + disambiguation, item detail, settings (sign out + household name), sync error banner, theme auto-detection | Not started                                                                       |
| PR 4 — Ship       | CI slow job (Supabase service + Playwright + type-drift + pg_dump), carry-forward fixes, docs                                                                                                        | Not started                                                                       |

**The new session's job: drive PR 3 once PR 2 is merged.**

---

## Current state (exact, as of handoff)

### Lalista (`/workspace`)

- Git remote: `https://github.com/meirmsn/lalista.git` (private)
- Default branch: `main`
- Active feature branch: `feature/auth`
- Latest commit on `feature/auth`: `6618141 fix(auth): Tailwind workspace scan + touch target + layout centering + E2E email TLD`
- PR #10 (auth): open, ready for review, CI green, Vercel preview Ready at `https://lalista-git-feature-auth-meirs-projects-4803a76a.vercel.app`
- Main is at: `ade6dff PR 1: lalista web foundation (design system, core API, edge fn auth) (#9)` + a small BUILD-LOG housekeeping commit (`8d0a31e`). Squash-merge is the repo's merge policy.
- Working tree: clean.

### Devshop (`/devshop` — the abra-kadabra repo)

- Git remote: `git@github.com:meirmsn/abra-kadabra.git` (SSH; lalista's PAT can't write here)
- Active feature branch: `feature/pre-ship-hardening`
- **6 commits ahead of `main`, all local, NOT yet pushed** — the user needs to push from their host (SSH keys there):
  ```
  git -C <local-devshop-path> push -u origin feature/pre-ship-hardening
  ```
- Commits (oldest first):
  1. `c316d71 feat(hardening): pre-ship blocked outcome + new-project .env.local + template Playwright deps`
  2. `978808e docs(notes): session handoff notes for PR 2 (lalista auth) + devshop follow-ups`
  3. `d20bfd2 feat(pre-ship): Chromium symlink, screenshot convention + TODOS`
  4. `7ae05f2 docs(notes): pr2-subagents handoff + current pr2-auth-resume`
  5. `f0c5f86 docs(skills): route around missing Checks permission on fine-grained PATs`
  6. `49eb4e6 feat(ak-build): PR body conventions + phase-by-phase checkbox timing`
- Working tree: should be clean, **unless** the user hasn't reverted the two hook-script files from the session's softening experiment. Verify at session start with `git -C /devshop status --short kit/scripts/`.

### Environment

- Devcontainer rebuilt with Playwright Chromium shared libraries (Dockerfile ships them now).
- `/workspace/apps/web/.env.local` exists (gitignored), points at hosted Supabase, has the `NEXT_PUBLIC_*` prefixed names.
- Shell env (from `.devcontainer/.env`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ACCESS_TOKEN`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`, `GITHUB_TOKEN`.
- Playwright chromium at `/home/node/.cache/ms-playwright/chromium-1217/chrome-linux/chrome` — version 147. `/ak-pre-ship` preflight auto-symlinks `chromium-1208` if the gstack `browse` daemon expects the old path.
- Next.js dev server is **not running** (I killed it at the end of the parent session). Restart with `cd /workspace/apps/web && pnpm dev` (background).

---

## Prerequisites before PR 3 can start

Do these in order:

1. **Push the devshop hardening branch from host**:

   ```
   git -C <local-devshop-path> push -u origin feature/pre-ship-hardening
   ```

   Then open a PR on `abra-kadabra` however you normally do. The branch contains pre-ship-gate improvements that will be used by PR 3's `/ak-build` run.

2. **Review lalista PR #10** and merge. Three things to eyeball on the Vercel preview (full details in the PR body):
   - Visual 4-combo audit (`375/1440 × light/dark`) on `/sign-in` + `/onboarding`. **Note**: dark mode is unreachable in shipped code — `.dark` class defined, nothing toggles it. Dark-mode screenshots confirm light renders correctly under a forced `.dark`; they don't promise dark mode ships.
   - Live QA walkthrough — fresh sign-up (use `@example.com`, not `.local` — Supabase rejects `.local` TLD) → onboarding → home; wrong password → inline error (no fallback signup); refresh cookie round-trip; sign-out via devtools `localStorage.clear()` → reload; direct-nav `/onboarding` while authed-with-household → `/`.
   - Middleware p95 post-deploy — Vercel function metrics; target `< 50ms`. If exceeded, `specs/auth/review.md § Gate 10` has the `getSession()`-vs-`getUser()` mitigation.

3. **Revert the softened hook scripts if still dirty.** During the parent
   session a softened version of both hook scripts was briefly applied
   before being split off to `subagent-hook-scope.md`. If the working tree
   shows them as modified:

   ```
   sudo chmod 644 /devshop/kit/scripts/check-dirty-after-commit.sh /devshop/kit/scripts/check-pr-description.sh
   ```

   If the diff is actually content-different (not just mode), restore HEAD
   versions: `git -C /devshop show HEAD:kit/scripts/check-dirty-after-commit.sh > /tmp/orig1.sh && sudo cp /tmp/orig1.sh /devshop/kit/scripts/check-dirty-after-commit.sh` — same for the other file.

4. **Consider closing the PR 2 evidence gap first (optional).** Four manual-review checkboxes on PR #10 stayed `[ ]`. See `/devshop/kit/notes/pr2-pending-checks.md` for why, and Paths A/B/C for how to handle. Recommended: **Path C** — defer the 4-combo matrix and full happy-path walk to PR 3's pre-ship, which will re-exercise the same screens plus add more.

---

## PR 3 — Core flows — detailed scope

**From `/workspace/PRODUCT-ROADMAP.md § v0 § 1e` and `/devshop/kit/notes/bootstrap/v0-web.md § 1e`.**

For each screen: implement → write tests (unit + E2E) → instrument metrics → mark done. Do NOT move to next screen until tests pass (this is the `/ak-implement` convention).

### Screens

1. **List view** (`apps/web/app/(list)/page.tsx`; replaces the current `apps/web/app/page.tsx` placeholder):
   - Items grouped by store — core UX differentiation, never flatten. Store label styled with `<Text variant="micro">` (uppercase 13px).
   - Each row shows item name, brand (if any), quantity. Buy button on each row calls `markItemBought(client, entryId)` from `@lalista/core` (which uses the `mark_item_bought` RPC — never direct write to `purchase_history`; RLS blocks that).
   - Loading / empty / error states.
   - Subscribes to Realtime channel via `subscribeToList(client, householdId, cb)` from `@lalista/core`. On every update, refetch via `fetchListEntries`. Subscribe on mount, unsubscribe on unmount.
   - Sync error banner (see below) appears when Realtime channel errors OR an RPC/query fails.

2. **Add item flow** — likely a FAB or sticky bar on the list view:
   - Text input + submit button. Fires `invokeAddItem(client, { utterance, householdId })` from `@lalista/core`.
   - On response: if `needs_followup === false`, optimistic insert into list (Realtime will confirm). If `needs_followup === true`, show a **disambiguation sheet** — this is a **first-class flow, not an edge case**. It fires whenever the edge function's NLP confidence is below threshold.
   - Disambiguation sheet:
     - `followup_type === 'item'`: user picks from `followup_options` (list of candidate items). On pick: call `invokeAddItem` again with `candidateItemId` set.
     - `followup_type === 'store'`: user picks from available stores. On pick: `confirmedStoreId` set.
     - `followup_type === 'brand'`: brand confirmation.
     - `followup_type === 'quantity'`: already-on-list prompt ("want to increase quantity?").
   - Reference Swift implementation: `ios-archive/ios/Sources/Views/List/DisambiguationSheet.swift` (bottom-sheet UI pattern, 4 variants).

3. **Item detail** (`apps/web/app/(list)/item/[id]/page.tsx`):
   - Name, store, brand, quantity.
   - Edit: name, store (picker from `fetchStores`), brand.
   - Delete: calls `deleteListEntry`.

4. **Settings** (`apps/web/app/settings/page.tsx`):
   - Sign out (calls `signOut(client)` from `@lalista/core` → middleware will redirect to `/sign-in` on next request).
   - Household name display (read-only for v0; rename deferred).

5. **Sync error banner** — a persistent top-banner component shown when the Supabase connection is unhealthy. Fires on Realtime channel error or when a query fails with a network error. Dismissible but re-appears on next error.

### E2E — Playwright happy path

Extend `apps/web/e2e/auth.spec.ts` or add a new `e2e/list.spec.ts`:

- Sign in → create household (if not yet) → add "leche" via text input → assert row appears → mark bought → assert row disappears from active list.
- Mobile 375 + desktop 1440 viewports (existing `playwright.config.ts` handles both).

### Theme auto-detection E2E test

One Playwright test that does `page.emulateMedia({ colorScheme: 'dark' })` and asserts `<html>` has the `dark` class applied. **This test will fail as-written** until the theme auto-detection is wired — currently `.dark` class isn't added anywhere. Two options:

- **Option A**: include the theme-detection bootstrap in PR 3 (adds a `ThemeProvider` client component in `app/layout.tsx` that reads `prefers-color-scheme` and sets `classList.add('dark')` on `<html>`). Then the E2E test passes. This is the cleaner scope decision.
- **Option B**: document the test as `.skip()` with a TODO pointing to a theme-bootstrap PR. Ship core flows without it.

Spec writer (whoever runs `/ak-spec`) should ask the user to pick at the start of PR 3.

### Metrics

Add to `METRICS.md` (with user confirmation from `/ak-spec`):

| Event                  | Fires on                                                                                                          | Properties                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `item_added`           | `invokeAddItem` success, `needs_followup === false`                                                               | `{ store_id, was_disambiguated: boolean, input_language: 'es'\|'en' }` |
| `item_bought`          | `markItemBought` resolves                                                                                         | `{ time_on_list_seconds: number }` (compute from `added_at` → now)     |
| `disambiguation_shown` | `invokeAddItem` returns `needs_followup === true`                                                                 | `{ candidate_count: number, followup_type: string }`                   |
| `store_routed`         | Edge fn resolved a store from purchase history (embed this in the server response and the client fires the event) | `{ store_name: string, confidence_score: number }`                     |
| `error_displayed`      | Sync error banner appears                                                                                         | `{ error_type: 'realtime' \| 'query', screen: string }`                |

Instrument via `posthog.capture()` — pattern already in `apps/web/app/providers.tsx` and `apps/web/lib/analytics.ts` from PR 2.

### Unit tests

For each screen — React Testing Library + Vitest — assert:

- Component renders initial state correctly (loading, empty, populated).
- Actions call the right `@lalista/core` wrapper with the right args.
- Disambiguation sheet selection round-trips into a follow-up `invokeAddItem` call.
- Error states render correctly.

---

## How to kick off PR 3

**Assumptions before running `/ak-build`:**

- PR 2 is merged (or you're comfortable branching from `feature/auth`; reviewers will see PR 2's diff as part of PR 3's diff until PR 2 merges).
- Devshop hardening branch is merged (so `/ak-pre-ship` has the preflight + blocked outcome + screenshot convention; `/ak-build` has PR body conventions). **If NOT merged yet**, the hardening changes are still readable in `/devshop/.claude/skills/` even without a push — they're committed locally.
- Dev server is NOT running (or at least is restartable). `/ak-implement` may need it for component tests; `/ak-pre-ship` will use it for browser gates.

**Recommended flow** — one of:

### Option 1: `/ak-build core-flows` (full pipeline)

From `/workspace` on `main` (after PR 2 merges):

```
git checkout main && git pull
```

Then in Claude Code:

```
/ak-build

Feature name: core-flows

Scope: PR 3 of the lalista web migration — list view + add-item flow
with disambiguation + item detail + settings + sync error banner +
theme auto-detection E2E test. Full details in
/devshop/kit/notes/phase-1-next-steps.md § "PR 3 — Core flows —
detailed scope". Follow the conventions in
/devshop/kit/notes/bootstrap/v0-web.md § 1e.

On theme bootstrap: before implementing, ask the user whether to
include a ThemeProvider in this PR (Option A in the note) or ship a
.skip'd test and defer the theme wiring (Option B).

Open questions to resolve during /ak-spec (with user):
- ThemeProvider scope (A or B above)
- Whether add-item uses a FAB or sticky bar
- Whether the disambiguation sheet renders as a bottom sheet (Swift
  parity) or an inline dropdown (web idiom)
- What METRICS.md events to add (confirm the proposed 5)
```

### Option 2: Manual spec-first, build later

If the feature feels too underspecified to autonomous-build, do `/ak-spec core-flows` first, review the generated `specs/core-flows/spec.md`, iterate, then later `/ak-build` with the resume-at-Phase-2 flow.

---

## Known gaps carried from PR 2 (don't get re-surprised)

### 1. Tailwind v4 + workspace packages

`apps/web/app/globals.css` contains:

```css
@import 'tailwindcss';
@source "../../../packages/ui/src/**/*.{ts,tsx}";
```

The `@source` directive is **required** — without it, Tailwind v4 strips all token utilities (`bg-primary`, `border-border`, etc.) that are only used inside `packages/ui/**`. If you add new workspace packages that ship styled components (e.g. a future `packages/icons`), add a matching `@source` line. Forgetting = unstyled output.

### 2. Button primitive includes `min-h-[44px]` for touch target

Per `DESIGN.md § Interactive minimums`. Don't remove it. If you add new Button variants, inherit the min-height.

### 3. Auth shell uses `min-h-screen`, not `min-h-full`

`apps/web/app/(auth)/layout.tsx` uses `min-h-screen` because body is flex-column and percentage min-heights on flex items are ambiguous. Any new shell layouts that want to fill viewport should use `min-h-screen` too (or flex-1 in an appropriate parent).

### 4. E2E emails use `@example.com` (RFC 2606), never `@*.local`

Supabase's email validator rejects `.local` TLD. For `supabase.auth.signUp` or `.signIn` from an E2E test, use `@example.com`. The seeded users (`alice@test.local`, `bob@test.local` in `supabase/seed.sql`) are fine because `seed.sql` inserts directly into `auth.users` and bypasses the validator.

### 5. Supabase rate-limits new signups aggressively on the hosted project

Observed during PR 2 pre-ship: after 1–2 `signUp` attempts, all subsequent calls with any email domain return "email rate limit exceeded" for ~30 minutes. For local QA / hero screenshots, **start local Supabase** (`supabase start`) and use the seeded users. Remember to:

- Temporarily point `apps/web/.env.local` at `http://localhost:54321` + the local anon key
- Revert `.env.local` when done (hosted Supabase for normal dev)
- `supabase stop` at end of session to release the Docker containers

### 6. Dark mode is unreachable in shipped code

`.dark` class CSS exists in `apps/web/app/globals.css:35`. Nothing adds the class. No `ThemeProvider`, no `prefers-color-scheme` listener. This is a deferred gap from PR 1's design system. If PR 3 wires dark mode (Option A above), this gap closes — otherwise it stays deferred to a future theme PR.

### 7. `add-item` edge function already has `getUser()` auth check

Landed in PR 1 (`supabase/functions/add-item/index.ts`). Returns 401 without a valid Bearer token. Don't re-add or "improve" without reading what's there.

### 8. `mark_item_bought` RPC is the ONLY way to mark bought

RLS blocks direct client inserts to `purchase_history`. `@lalista/core`'s `markItemBought(client, entryId)` uses `supabase.rpc('mark_item_bought', { p_entry_id: entryId })`. Don't call `purchase_history.insert` directly anywhere.

### 9. Realtime is enabled for `list_entries` — use `subscribeToList`

`@lalista/core` `api/realtime.ts` exports `subscribeToList(client, householdId, callback) → unsubscribe`. It wraps a Supabase Realtime channel filtered by `household_id=eq.<id>`. Use this for the list view's live updates — never poll.

### 10. Disambiguation is a first-class flow, not an edge case

`invokeAddItem` returns `needs_followup: true` whenever the edge function's NLP/matching confidence is below threshold. That's common, not rare. The disambiguation sheet must be designed and tested as part of the happy path, not as an error case.

### 11. Private repo image URL in PR bodies

`raw.githubusercontent.com` URLs require auth tokens and silently 404 for viewers. Repo-relative paths (`specs/auth/hero/signin.png`) don't resolve in PR bodies. Use `https://github.com/<owner>/<repo>/raw/<branch>/<path>` — GitHub handles auth for authenticated viewers. This is codified in `/ak-build` v1.2.0's PR body conventions.

### 12. PR body checkbox discipline

Pre-push gates `[x]` at PR creation. CI gates `[x]` when their signal lands (Phase 5.3 of `/ak-build`). Human-review items **never** auto-checked. Phase 6 reconciles. Full table in `/devshop/.claude/skills/devshop/build/SKILL.md § PR body conventions`.

### 13. Chromium symlink auto-heal

`/ak-pre-ship` Phase 0 preflight symlinks `chromium-1208` → whatever's installed. This exists because the gstack `browse` daemon is pinned to the older version. If you invoke `browse` outside of `/ak-pre-ship` and it fails with "Executable doesn't exist at chromium-1208", re-run the preflight logic manually:

```bash
LATEST=$(ls -d /home/node/.cache/ms-playwright/chromium-* | grep -v headless_shell | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium-1208 ] && ln -sf "$LATEST" /home/node/.cache/ms-playwright/chromium-1208
LATEST_HS=$(ls -d /home/node/.cache/ms-playwright/chromium_headless_shell-* | sort -V | tail -1)
[ ! -e /home/node/.cache/ms-playwright/chromium_headless_shell-1208 ] && ln -sf "$LATEST_HS" /home/node/.cache/ms-playwright/chromium_headless_shell-1208
```

### 14. Subagent hooks scope — separate session

Parent-agent git/commit hooks fire inside subagent bash calls and may hijack subagents with "BLOCKING" demands outside their scope. This is tracked in `/devshop/kit/notes/subagent-hook-scope.md` as its own follow-up. If PR 3's `/ak-build` subagents get tripped up by hooks, you have two options: (a) push through ignoring the hooks (they're informational; you have explicit scope from the parent), or (b) pause and pick up the subagent-hook-scope session to fix it properly.

### 15. Fine-grained PAT lacks Checks permission

The lalista PAT can't access the Check Runs API (GitHub removed the Checks permission from fine-grained PATs — see community discussion #129512). `gh pr checks` returns partial data. Use `gh run list --branch <branch> --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch --exit-status` for CI monitoring. Covered by `Actions: Read` which the PAT has.

### 16. Devshop + project clean-tree cross-check

Pre-commit hooks in both repos check the OTHER repo's tree is clean. If you're mid-work on both sides simultaneously, use `git stash push -u` on the non-committing side first, commit, then pop. Or use the documented `git -c devshop.dirtyTreeReason="..."` escape hatch (expects a thorough reason; has an adversarial reviewer that rejects weak justifications).

### 17. Devshop docs-drift + docs-consistency adversarial reviewers

When committing changes to `/devshop/.claude/skills/` or `/devshop/kit/`, two separate pre-commit guards may fire:

- `docs-drift` — expects a `git -c devshop.docsVerified="..."` flag listing which of the 7 top-level docs (MODEL.md, OVERVIEW.md, kit/docs/guide/, CLAUDE.md, FAQ.md, CLAUDE.md project, README.md) you reviewed and why they don't need updates (or which ones you updated).
- `doc-consistency` — expects `git -c devshop.docSyncReason="..."` when `kit/docs/guide/*` files could be affected.

Both have adversarial reviewers that read your reason and reject weak ones. Write thorough reasons covering every doc.

---

## Artifacts you can lean on

### Already in place

- **`packages/core`** exports (all usable as-is):
  - Auth: `signInWithPassword`, `signUpWithPassword`, `signOut`, `getSession`, `getUser`, `onAuthStateChange`
  - Households: `fetchUserHouseholds`, `fetchUserMemberships`, `createHousehold`
  - Items: `fetchListEntries(client, householdId, status)`, `markItemBought(client, entryId)`, `deleteListEntry`
  - Stores: `fetchStores`
  - Add-item: `invokeAddItem(client, { utterance, householdId, candidateItemId?, confirmedStoreId?, confirmedBrand? })` → returns typed `AddItemResponse`
  - Realtime: `subscribeToList(client, householdId, cb) → unsubscribe`
  - Supabase client factory: `createClient({ supabaseUrl, supabaseAnonKey })`
  - Types: `Item`, `Store`, `Household`, `HouseholdMember`, `ListEntry`, `HydratedListEntry`, `DisambiguationCandidate`, `AddItemResponse`

- **`packages/ui`** exports:
  - `Button` (44px min-height, primary color, focus ring)
  - `Text` (semantic type scale: display, display-italic, heading-lg, heading-md, body-lg, body, caption, micro)
  - `Card` (surface bg, border, default radius)
  - `Input` (focus ring, error state)
  - `Divider` (1px border-token horizontal rule)
  - Design tokens: `colors`, `spacing`, `radius`, `fonts`, `fontScale`, `breakpoints`, `duration`
  - Snapshot tests for each component (update with `vitest -u` when styling changes)

- **Web scaffolding**:
  - `apps/web/lib/supabase/{client,server}.ts` — @supabase/ssr-wrapped factories; use these instead of creating clients inline
  - `apps/web/lib/analytics.ts` — `trackSignedIn`, `trackSignedOut` + event-name constants; extend with `trackItemAdded`, `trackItemBought`, etc. as you add PR 3 events
  - `apps/web/middleware.ts` — route protection (unauth → /sign-in, authed-no-household → /onboarding); matcher regex excludes `_next/static`, `_next/image`, `favicon.ico`, `manifest.json`, `icons/*`
  - `apps/web/app/providers.tsx` — PostHog init + `onAuthStateChange` subscription

- **Design system**:
  - `DESIGN.md` at project root — frozen reference. No new colors, no new type-scale items. Use tokens from `@lalista/ui`.
  - Fraunces (display) + Plus Jakarta Sans (body) loaded via `next/font/google`.

- **Supabase**:
  - Schema migrations 001–007 in `supabase/migrations/`
  - Edge function `add-item` at `supabase/functions/add-item/index.ts` — deployed; has `getUser()` auth check; returns the `AddItemResponse` shape
  - Seed data in `supabase/seed.sql` — production catalog (stores, items) + test fixtures (`alice@test.local` / `password123`, `bob@test.local` / `password123`, 2 households, 2 pending list entries). Fixed UUIDs for deterministic RLS tests.
  - RPCs: `mark_item_bought(p_entry_id)`, `find_item_by_trgm`, `find_item_alternatives`, `route_item_to_store`, `current_household_id`, `my_household_ids`

- **Observability**:
  - Sentry wired via `@sentry/nextjs` — config in `apps/web/sentry.{client,server}.config.ts`, `instrumentation.ts`
  - PostHog wired via `posthog-js` in `apps/web/app/providers.tsx`
  - METRICS.md has `auth_signed_in` and `auth_signed_out` — add the PR 3 events here

- **CI**:
  - `.github/workflows/ci.yml` runs a fast job on every push (lint + typecheck + test:unit + build)
  - Slow job placeholder (Supabase service + Playwright + type drift + pg_dump) is commented out; wiring it is PR 4 scope
  - GitHub Actions secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `NEXT_PUBLIC_POSTHOG_KEY`

### Tests green as of handoff

- `packages/core`: 36 tests — all wrappers mocked
- `packages/ui`: 21 tests — snapshot tests for primitives
- `apps/web`: 31 tests — middleware matrix, sign-in fallback paths, onboarding redirects, analytics events, Supabase helpers

Total: **88 passing**. Whatever PR 3 adds should bring this up, not break existing.

---

## Dev environment — quick-start commands

```bash
# Install deps (should already be done)
cd /workspace && pnpm install

# Generate local .env.local (auto-done on new project per /ak-new-project Step 13b)
# Already exists for this project; verify:
cat /workspace/apps/web/.env.local   # should show NEXT_PUBLIC_* vars

# Start the Next dev server (background)
cd /workspace/apps/web && pnpm dev
# Wait for "Ready in Xms", curl http://localhost:3000/ → 307 to /sign-in

# Run unit tests
pnpm turbo run test:unit

# Full gate suite (lint + typecheck + test:unit + build)
pnpm turbo run lint typecheck test:unit build

# Parse Playwright specs (doesn't execute)
pnpm --filter @lalista/web exec playwright test --list

# Execute Playwright (if browser + Supabase ready — see next section)
pnpm --filter @lalista/web exec playwright test
```

### For PR 3 pre-ship — likely need local Supabase

Host Supabase rate-limits signups. For the 4-combo matrix + live QA walkthrough in `/ak-pre-ship`, use local Supabase:

```bash
supabase start   # starts Docker containers for Postgres, Auth, Realtime, etc.
supabase status  # prints the local API URL + anon key — use these
```

Temporarily edit `/workspace/apps/web/.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
NEXT_PUBLIC_POSTHOG_KEY=<keep hosted>
NEXT_PUBLIC_SENTRY_DSN=<keep hosted>
```

Restart the dev server to pick up the new vars. Use `alice@test.local` / `password123` (or `bob@test.local`) for sign-in — they bypass the email validator.

When done:

```bash
# Revert .env.local to hosted
# (or keep local for iteration; just don't push it — gitignored)
supabase stop  # release Docker containers
```

### For hero screenshots

Gstack's `browse` skill + the ak-pre-ship preflight symlink work together. Basic capture:

```bash
# Make sure browse is up
cd /workspace/.claude/skills/gstack/browse/dist && ./browse status

# Capture
./browse goto http://localhost:3000/sign-in
./browse screenshot /workspace/specs/core-flows/hero/signin.png --full-page
```

For dark-mode shots under the unreachable-dark-mode gap:

```bash
./browse exec "document.documentElement.classList.add('dark')"
./browse screenshot /workspace/specs/core-flows/hero/signin-dark.png --full-page
```

---

## Session kickoff prompt (copy-paste)

Use this as the first message in a new Claude Code session:

> I'm continuing the lalista migration — PR 3 (core flows). Read
> `/devshop/kit/notes/phase-1-next-steps.md` in full first; it's
> self-contained and has everything you need.
>
> After reading, briefly confirm you understand:
>
> 1. Current state (PR 2 status, devshop branch push status)
> 2. PR 3 scope (5 screens + E2E + metrics)
> 3. The 17 known gaps carried forward
>
> Then tell me which of the 3 prerequisites need addressing before
> starting PR 3. Do NOT start implementing yet — wait for my
> go-ahead.

After alignment, the session should invoke `/ak-build` with the scope
block from § "Option 1" above.

---

## Related docs (for deeper dives)

- **`/home/node/.claude/plans/we-decided-to-do-scalable-shore.md`** — the 4-PR plan written at session start. Strategic frame; consult when scope questions arise.
- **`/devshop/kit/notes/bootstrap/v0-web.md § Phase 1`** — the original migration blueprint. Has more detail on each sub-phase (1a–1h) than this handoff; some references are slightly outdated relative to the devshop's current state (skill names have `ak-` prefix now; hardening is new). Treat as historical + directional.
- **`/devshop/kit/notes/subagent-hook-scope.md`** — standalone handoff for the subagent-hook-scope problem (parent-agent hooks firing inside subagent bash). Full investigation protocol + softened-script fallback inline. Run its Session kickoff prompt in a separate session when you want to tackle that problem.
- **`/devshop/kit/notes/pr2-pending-checks.md`** — retrospective on the four manual-review checkboxes on PR #10 that stayed unchecked. Documents what wasn't done, why, and the 3 paths (A close gap, B accept, C defer to PR 3).
- **`/workspace/PRODUCT-ROADMAP.md § v0`** — project-level roadmap; mirrors v0-web.md § Phase 1. The 1e section is your scope for PR 3.
- **`/workspace/specs/auth/spec.md`** — PR 2's implementation spec. Pattern to emulate for PR 3's spec.
- **`/workspace/specs/auth/review.md`** — PR 2's pre-ship review. Pattern for PR 3's review.
- **`/workspace/CLAUDE.md`** — project-specific conventions + deploy config. Covers where things happen (Auth, Data, Edge functions, Design, Testing, CI/CD, Observability, PWA).
- **`/devshop/CLAUDE.md`** — devshop conventions. Covers non-negotiables, confidence calibration, workflow.
- **`/devshop/.claude/skills/devshop/build/SKILL.md`** — `/ak-build` skill (v1.2.0, includes PR body conventions). Read before your first `/ak-build` invocation in the new session.
- **`/devshop/.claude/skills/devshop/pre-ship/SKILL.md`** — `/ak-pre-ship` skill (v3.2.0, includes preflight + blocked outcome + screenshot convention). Read before expecting specific pre-ship behavior.
- **`/devshop/kit/TODOS.md`** — devshop tactical backlog. Tracks the 4 unfixed items from the parent session (digest pin, gstack browse autodetect, routing init-tracker, Checks permission restoration) + pre-existing items.

---

## Questions the new session should be ready to ask the user

At the start of `/ak-spec` for `core-flows`:

1. **ThemeProvider in PR 3 or defer?** (see "Theme auto-detection E2E test" above)
2. **FAB or sticky input bar for add-item?** Swift was a FAB; web has different idioms.
3. **Disambiguation sheet UI form?** Bottom sheet (Swift parity) vs. inline dropdown vs. modal.
4. **Confirm the 5 new METRICS.md events?** (`item_added`, `item_bought`, `disambiguation_shown`, `store_routed`, `error_displayed`) — the user must confirm before `/ak-spec` appends them per the devshop convention.
5. **Sign-out surface location?** Settings page only, or also a menu/header affordance?
6. **Should PR 3 close any PR 2 manual-review gaps?** (see `/devshop/kit/notes/pr2-pending-checks.md` Path C) — doing the 4-combo matrix + happy-path against local Supabase as part of PR 3's `/ak-pre-ship` is the cleanest way.
