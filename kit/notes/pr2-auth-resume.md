# PR 2 Auth — Resume Notes

**Original plan**: `/home/node/.claude/plans/we-decided-to-do-scalable-shore.md`
**PR**: https://github.com/meirmsn/lalista/pull/10 (draft=false, ready for review)
**Branch**: `/workspace` on `feature/auth`, last committed SHA `b6b274c`, CI green
**Devshop PR (separate)**: `/devshop` on `feature/pre-ship-hardening`, SHA `c316d71`, **committed locally, NOT pushed** — user must push from host

---

## Where we left off mid-session

We were fixing three findings discovered by actually running the 4 previously-skipped browser gates. The fix is staged in the working tree; we had just restarted the dev server and were about to browser-verify the fix before committing.

### Working-tree state (uncommitted, fix-in-flight)

```
 M .gitignore                          # revert rogue .gstack/ add; ignore specs/*/screenshots/
 M apps/web/app/globals.css            # add @source "../../../packages/ui/src/**/*.{ts,tsx}"
 M apps/web/e2e/auth.spec.ts           # @test.local → @example.com
 M apps/web/next-env.d.ts              # noise — Next regenerates on dev-server start; stash always
 M specs/auth/spec.md                  # doc fix matching the e2e email TLD change
?? specs/auth/screenshots/             # gitignored per the new rule
```

**Once browser-verified**, these should be committed as one commit (drop `next-env.d.ts` via stash) with message like:

```
fix(auth): Tailwind workspace scan + E2E email TLD

- globals.css: add @source for packages/ui so token utilities aren't stripped
- e2e: @test.local TLD is rejected by Supabase validator → @example.com
- .gitignore: ignore pre-ship evidence screenshots; drop the erroneous .gstack/ addition (conflicts with MEMORY.md rule)
```

Then also commit an updated `specs/auth/review.md` with real findings (the current file says "skipped — no browser" which is now inaccurate).

---

## Immediate pending steps

1. **Browser-verify Tailwind fix** — dev server at `http://localhost:3000`. Hit `/sign-in`, confirm:
   - Button bg-color is `#d4603a` (terracotta), not transparent
   - Button height ≥ 44px (touch target)
   - Input has `bg-surface` + token-based border
   - Use gstack `browse` skill. Chromium path: `/home/node/.cache/ms-playwright/chromium-1217/chrome-linux/chrome`. Note: browse daemon may still be pinned to 1208 paths and need a symlink (`ln -sf /home/node/.cache/ms-playwright/chromium-1217 /home/node/.cache/ms-playwright/chromium-1208` + same for `chromium_headless_shell`). The previous subagent did this successfully.

2. **Capture 2 hero screenshots** (the "after" / passing versions):
   - `specs/auth/screenshots/hero-signin-1440-light.png`
   - `specs/auth/screenshots/hero-onboarding-1440-light.png`
   - These are committed (exempted from `specs/*/screenshots/` via... actually the current gitignore catches them too; either change the pattern to `specs/*/screenshots/evidence/` or git-force-add the hero files. Recommend: change pattern and put hero shots in `specs/auth/screenshots/hero/`.)

3. **Update `specs/auth/review.md`** with real findings + fix evidence. The summary line at the top should change from "7 pass, 3 skipped, 1 n/a" to "8 pass, 1 findings (fixed), 1 n/a" (or similar after the full re-run). Per-gate:
   - **Gate 3 (Responsive + theme)**: findings (1 critical, fixed — `@source` directive in `globals.css`). Reference hero screenshots.
   - **Gate 8 (/design-review)**: pass (after Gate 3 fix — UI actually renders with tokens).
   - **Gate 9 (/qa)**: findings (1 medium, fixed — email TLD). Happy path now walks sign-up → onboarding → home correctly with `@example.com`.
   - **Gate 10 (/benchmark)**: pass. Record LCP / FID / CLS from the benchmark run.

4. **Commit the fix** (5 files, drop next-env.d.ts via stash).

5. **Push `feature/auth`, watch CI** via `gh run watch` on the new commit. Expected: fast job green in ~1m20s.

6. **Commit hero screenshots separately** (or bundle into the same commit). Push again, CI again.

7. **Attach hero screenshots to PR #10** description + re-post audit comment with the real outcomes. The audit comment template is in the current PR body / earlier comments.

8. **Task list cleanup**: mark 28 / 29 / 30 as completed.

---

## Critical findings from this session (DO NOT LOSE)

### CRITICAL — Tailwind v4 not scanning `packages/ui`

- **Root cause**: Tailwind v4 auto-detects classes in the project root but does NOT descend into workspace packages. `apps/web/app/globals.css` had only `@import 'tailwindcss';` with no `@source` directive for `packages/ui`.
- **Symptoms**: Token utilities (`bg-primary`, `border-border`, `rounded-default`, `px-md`, `py-sm`, `focus:ring-primary`, `text-white`, `text-text-tertiary`, `border-error`, `hover:bg-primary-pressed`, etc.) were all stripped. Button, Input, Card rendered effectively unstyled. Button height: 24px (fails 44px touch target). Button bg-color: `rgba(0,0,0,0)` (transparent).
- **Verification artifact**: live stylesheet at `http://localhost:3000/_next/static/chunks/%5Broot-of-the-server%5D__00-s9mx._.css` only had 4 custom classes (`.bg-background`, `.text-error`, `.text-text-primary`, `.text-text-secondary`).
- **Fix** (staged): add `@source "../../../packages/ui/src/**/*.{ts,tsx}";` immediately after `@import 'tailwindcss';` in `apps/web/app/globals.css`.

### MEDIUM — Supabase rejects `.local` TLD

- **Root cause**: Supabase's default email validator (enabled on new projects) marks `user@*.local` as invalid. `.local` is not in the RFC 2606 reserved-for-testing TLDs.
- **Symptom**: E2E sign-up flow 500's with `"Email address 'e2e-...@test.local' is invalid"`.
- **Fix** (staged): switch E2E to `@example.com` in `apps/web/e2e/auth.spec.ts:12` and update the matching description in `specs/auth/spec.md:155`.
- **Note**: Seeded users `alice@test.local` / `bob@test.local` in `supabase/seed.sql` continue to work because the seed inserts directly into `auth.users` and bypasses the validator.

### HIGH — Dark mode is unreachable (DEFERRED)

- `.dark` class CSS exists in `globals.css:35` but nothing adds the class at runtime. No theme toggle, no `prefers-color-scheme` media query / listener, no layout bootstrap.
- **Scope decision**: deferred. This predates PR 2 — it's a gap from PR 1's design-system. Target: PR 3 (settings page toggle) or a dedicated theme-bootstrap PR.
- Do NOT fix in the PR 2 scope; it would expand beyond "auth".

---

## Devshop-side state (separate PR, separate tree)

### Branch + commit

- Repo: `/devshop`
- Branch: `feature/pre-ship-hardening`
- Local SHA: `c316d71`
- Status: committed locally, **NOT pushed** — user needs to `git -C /devshop push -u origin feature/pre-ship-hardening` from their host (lalista PAT lacks write access to `abra-kadabra`; SSH keys on host are needed).

### Scope (4 files, coherent unit)

1. `template/.devcontainer/Dockerfile` — new RUN block installing 14 Chromium shared libs.
2. `.claude/skills/devshop/pre-ship/SKILL.md` — version `3.0.0 → 3.1.0`. Adds Phase 0 preflight + formal `blocked` outcome category + Gates 3/8/9/10 emit `blocked` (not `skipped`) when Chromium unavailable + Output requires explicit counts.
3. `.claude/skills/devshop/build/SKILL.md` — version `1.0.0 → 1.1.0`. Phase 3 refuses to advance to `/ship` if `blocked > 0`. Phase 6 audit-comment template uses new outcome vocabulary.
4. `.claude/skills/devshop/new-project/SKILL.md` — version `1.0.0 → 1.1.0`. New Step 13b generates `apps/web/.env.local` from shell env.

### Skill-edit permission gotcha

The harness sometimes denies edits to `/devshop/.claude/skills/ak-*/SKILL.md` based on cached conversation context interpreting "ak-\*" as gstack. These skills are **devshop** (not gstack). If denied mid-session, have the user restate: `"Yes, edit /devshop/.claude/skills/ak-pre-ship/SKILL.md, /devshop/.claude/skills/ak-build/SKILL.md, and /devshop/.claude/skills/ak-new-project/SKILL.md — these are devshop, not gstack."`

### Cross-repo commit gotcha

Both repos' pre-commit guards do a clean-tree check on the SIBLING repo. When both are dirty simultaneously: `git stash push -u` in the side that doesn't need to commit first, commit the other, pop the stash, commit. Do NOT use `git -c devshop.crossRepoReason=` unless truly stuck — the adversarial reviewer is strict about the reason being comprehensive.

---

## Devshop follow-up backlog (NEW PRs after current hardening lands)

1. **Screenshot convention** (`/ak-pre-ship` + `/ak-build`):
   - Gate 3 captures evidence to `specs/<feature>/screenshots/evidence/` (gitignored)
   - When Gate 8 passes, capture 1–2 hero shots to `specs/<feature>/screenshots/hero-*.png` (committed)
   - `/ak-build` Phase 6 audit-comment template embeds hero screenshots via repo-relative markdown
   - Files to touch: `/devshop/.claude/skills/devshop/pre-ship/SKILL.md`, `/devshop/.claude/skills/devshop/build/SKILL.md`

2. **`browse` daemon Chromium version tolerance**:
   - Currently pinned to `chromium-1208` / `chromium_headless_shell-1208` paths; Playwright ships `1217`.
   - Subagent had to manually `ln -sf` to make browse work.
   - Fix: browse daemon should discover the highest-version dir under `~/.cache/ms-playwright/` and use it.

3. **Subagent hook scope**:
   - Parent-process hooks (PR review, dirty tree block) fired inside subagents doing isolated read-only gate work and forced them to bail early.
   - Subagents don't own the PR lifecycle; these hooks shouldn't apply to subagent-scoped bash.
   - Fix location: wherever the hooks are registered (`.husky/pre-commit`? settings.json hooks block? need to trace).

4. **Base image digest pin**:
   - Currently: `FROM mcr.microsoft.com/devcontainers/javascript-node:20` in template Dockerfile.
   - Pin to digest: `FROM mcr.microsoft.com/devcontainers/javascript-node:20@sha256:<digest>`.
   - Requires registry access to resolve (not available from sandbox); user should resolve from host.

---

## Environment state

- **Dev server**: http://localhost:3000 (bg task `brm1vspk6`). 307 redirect for unauth → `/sign-in` working.
- **Chromium**: `/home/node/.cache/ms-playwright/chromium-1217/chrome-linux/chrome --version` → `Chromium 147.0.7727.0`.
- **Dockerfile fix applied**: `.devcontainer/Dockerfile` (root-owned) has the 14-lib apt block and is committed on `feature/auth` as `b6b274c`.
- **`.env.local`**: `/workspace/apps/web/.env.local` exists, gitignored, maps shell env to `NEXT_PUBLIC_*` names.

## Key file pointers

- Plan: `/home/node/.claude/plans/we-decided-to-do-scalable-shore.md`
- Spec: `/workspace/specs/auth/spec.md`
- Tasks log: `/workspace/specs/auth/tasks.md`
- Review (stale — needs update): `/workspace/specs/auth/review.md`
- Evidence screenshots: `/workspace/specs/auth/screenshots/signin-{375,1440}-{light,dark}.png`
- PR body last saved: `/tmp/pr10-body.md` (may be gone after rebuild)

## Active task IDs (check `TaskList` for latest status)

- 25 pending — Commit + push devshop PR (user action: push from host)
- 28 in_progress — Run 4 gates (partially done; mid-fix)
- 29 pending — Update review.md, commit, push, watch CI
- 30 pending — Re-post audit comment on PR #10

## Resume protocol

1. `TaskList` to see live task state
2. `git -C /workspace status --short` to see tree state
3. `git -C /workspace log --oneline -3` to confirm branch tip
4. `git -C /devshop status --short && git -C /devshop log --oneline -3` for devshop tree
5. `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/` to see if dev server is still up (restart if not: `cd /workspace/apps/web && pnpm run dev` in background)
6. Continue from "Immediate pending steps" list above
