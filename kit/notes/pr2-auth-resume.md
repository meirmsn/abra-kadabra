# PR 2 Auth — Resume Notes

**Status:** mostly closed out. Lalista PR 2 is ready for review;
the devshop hardening branch has 3 commits locally and needs a push.
One problem (subagent hook scope) is split off into its own session —
see `/devshop/kit/notes/pr2-subagents.md`.

**Original plan:** `/home/node/.claude/plans/we-decided-to-do-scalable-shore.md`
**PR:** https://github.com/meirmsn/lalista/pull/10

---

## Current state

### Lalista (`/workspace`)

- Branch: `feature/auth`
- Latest commit: `6618141 fix(auth): Tailwind workspace scan + touch target + layout centering + E2E email TLD`
- CI green on that commit (fast job ~1m)
- PR #10 description has the `specs/auth/hero/signin.png` embed + a
  Post-implementation fixes bullet + the full Evidence section
- PR #10 has a "revised audit trail" comment reflecting the
  real gate outcomes (`6 pass, 4 findings fixed, 1 blocked, 1 n/a`)
- Tree clean
- Ready for your review on the Vercel preview

### Devshop (`/devshop`)

- Branch: `feature/pre-ship-hardening` (3 commits, **not yet pushed**)
- Commits (oldest first):
  - `c316d71` — Initial hardening: Phase 0 preflight, `blocked` outcome,
    `/ak-build` refuses to advance on blocked, `/ak-new-project` Step 13b
    (generate `apps/web/.env.local`), template Dockerfile Playwright libs
  - `978808e` — Session handoff notes (this file's predecessor)
  - `d20bfd2` — Follow-ups: Chromium symlink auto-heal, hero/evidence
    screenshot convention, `kit/TODOS.md` entries for base-image digest
    pin + gstack browse upstream, FAQ/OVERVIEW/workflow.md doc sync
- Tree may be dirty on `kit/scripts/check-*.sh` if the softened hooks
  were applied — **see "User actions" below** for the revert path.

### Lalista PR 2 scope closure

Items 1, 2, 3, 4 from the 4-item backlog at the end of the parent
session:

| #   | Item                                     | Done?        | Where                                                |
| --- | ---------------------------------------- | ------------ | ---------------------------------------------------- |
| 1   | Screenshot convention (evidence vs hero) | ✅           | devshop `d20bfd2`                                    |
| 2   | Chromium version tolerance               | ✅           | devshop `d20bfd2` (`/ak-pre-ship` preflight symlink) |
| 3   | Subagent hook scope                      | **deferred** | `kit/notes/pr2-subagents.md` — standalone session    |
| 4   | Base-image digest pin                    | ✅ as TODO   | devshop `d20bfd2` (`kit/TODOS.md` entry)             |

---

## User actions still pending

### A. Revert the softened hooks (keep PR 2 devshop PR clean)

The softened versions of `check-dirty-after-commit.sh` +
`check-pr-description.sh` were applied during the parent session, then
decided to be split off into its own PR. Run these to restore HEAD
versions (the originals were extracted to `/tmp/*.original.sh`):

```
sudo cp /tmp/check-dirty-after-commit.original.sh /devshop/kit/scripts/check-dirty-after-commit.sh && sudo chmod 755 /devshop/kit/scripts/check-dirty-after-commit.sh && sudo chown root:root /devshop/kit/scripts/check-dirty-after-commit.sh

sudo cp /tmp/check-pr-description.original.sh /devshop/kit/scripts/check-pr-description.sh && sudo chmod 755 /devshop/kit/scripts/check-pr-description.sh && sudo chown root:root /devshop/kit/scripts/check-pr-description.sh
```

After those run, `git -C /devshop status --short kit/scripts/` should
be empty.

If `/tmp/*.original.sh` are missing (container rebuilt), regenerate:

```
git -C /devshop show HEAD:kit/scripts/check-dirty-after-commit.sh > /tmp/check-dirty-after-commit.original.sh
git -C /devshop show HEAD:kit/scripts/check-pr-description.sh > /tmp/check-pr-description.original.sh
```

Then re-run the `sudo cp` commands above.

### B. Push the devshop branch (your host, not container)

Lalista's PAT can't write to `abra-kadabra`. From your host:

```
git -C <local-devshop-path> push -u origin feature/pre-ship-hardening
```

Then open a PR however you normally do. The branch has 3 commits + the
new `kit/notes/pr2-subagents.md` that this session adds.

### C. Review lalista PR #10

Vercel preview will have the hero screenshot's real rendering. Three
items called out in the PR description need eyes:

1. 4-combo visual audit (375/1440 × light/dark)
2. Live QA walkthrough (use `@example.com` — `@test.local` gets
   rejected by Supabase)
3. Middleware p95 post-deploy

### D. (Optional, next session) Subagent hook scope

See `/devshop/kit/notes/pr2-subagents.md`. That doc is self-contained
— a fresh Claude Code session can pick it up without needing this
file.

---

## Devshop follow-up backlog (tracked in `kit/TODOS.md`)

- Pin template base image by digest (`sha256:...`). Requires registry
  access to resolve; deferred.
- Upstream fix: gstack `browse` daemon Chromium autodetection. When
  that lands, remove the `/ak-pre-ship` preflight symlink workaround.
- Route `/ak-new-project` init tracker out of project `BUILD-LOG.md`
  (pre-existing item, unchanged).

---

## Key findings from the session (preserved for future reference)

These were surfaced by the actually-run `/ak-pre-ship` browser gates.
All three already addressed in lalista commit `6618141`.

### 1. Tailwind v4 wasn't scanning `packages/ui` (critical)

- `apps/web/app/globals.css` had only `@import 'tailwindcss';` — no
  `@source` directive for workspace packages.
- Every token utility used by `@lalista/ui` primitives was stripped
  from the generated CSS. Button + Input + Card rendered unstyled.
- Fix: `@source "../../../packages/ui/src/**/*.{ts,tsx}";` in
  globals.css. Post-fix: 87 class rules in generated CSS (was 4).

### 2. Button touch target below spec

- `packages/ui/src/Button.tsx` rendered at 38.5px; `DESIGN.md`
  requires 44pt iOS accessibility minimum.
- Fix: `min-h-[44px]` on the Button primitive. Snapshot updated.

### 3. Auth shell not vertically centered on desktop

- `apps/web/app/(auth)/layout.tsx` used `<main class="min-h-full">`
  inside a `<body class="min-h-full flex flex-col">`. Percentage
  min-heights on flex items are ambiguous — `<main>` shrunk to 330px.
- Fix: `min-h-screen` on `<main>` (anchors to 100vh directly).

### 4. Supabase rejects `.local` TLD emails

- E2E spec used `@test.local` which Supabase's email validator rejects
  as invalid.
- Fix: `@example.com` (RFC 2606 testing TLD).

### 5. Dark mode unreachable (**still deferred**)

- `.dark` class CSS exists in `globals.css`; nothing adds the class.
- Scope decision: this predates PR 2; it's a gap from PR 1's
  design-system work. Target: PR 3 or a dedicated theme-bootstrap PR.
- **Not fixed in PR 2.**

---

## Environment state

- Chromium: `/home/node/.cache/ms-playwright/chromium-1217/chrome-linux/chrome` — v147.
- Playwright evidence + hero screenshots: `specs/auth/hero/signin.png`
  committed; evidence grid was in `specs/auth/screenshots/` (gitignored,
  may be gone now after cleanup).
- Dev server: was running on `:3000` mid-session; may or may not be
  up now.
- `.env.local` at `/workspace/apps/web/.env.local` is gitignored and
  contains the `NEXT_PUBLIC_*` mapping of shell env vars.

---

## Resume protocol (for a fresh session)

1. `TaskList` to see live task state
2. `git -C /workspace status --short` + `log --oneline -3` for lalista
3. `git -C /devshop status --short` + `log --oneline -5` for devshop
4. `gh pr view 10` for PR state
5. If `/devshop/kit/scripts/check-*.sh` are dirty → follow "User
   actions A" above to revert
6. If devshop branch unpushed → ask user to push from host
7. For the subagent-hook problem → **don't continue in this session**,
   spin up a fresh one and point it at `kit/notes/pr2-subagents.md`
