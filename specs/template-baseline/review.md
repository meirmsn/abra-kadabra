# Review — template-baseline

## Audit 1: manual (2026-05-19)

<!-- audited-at: 8611f0be27b2bf0b2260a83d9eead03c53e1e8ff -->
<!-- range: origin/main..HEAD -->

findings: high=5 medium=5 low=3

### Docs findings

- [high] kit/docs/guide/ops.md:26 — `§ Where Things Happen § Auth` Route protection row still names `apps/web/middleware.ts`; should be `proxy.ts` per the rename in 8611f0b.
- [high] kit/docs/guide/README.md:51, 55, 73, 106 — Four stale `apps/web/middleware.ts` references in the context-aware routing index (Auth-domain trigger prose, Auth routing row, Pattern 8 trigger row, project-docs-coverage map). Line 73's Pattern-8 anchor link is also broken (Pattern 8 retitled to `Proxy allow-list…`).
- [high] .claude/skills/devshop/new-project/SKILL.md:854, 1388 — Skill prose contradicts the file actually shipped: 854 says Pattern 1 lives in `middleware.ts`, 1388 lists `apps/web/middleware.ts` as a `assertNotProdUrlInTestEnv` wiring target.
- [high] template/apps/web/next.config.ts:10 — `// Does NOT:` header points at `middleware.ts` for CSP headers per Pattern 2; (a) the file is `proxy.ts`, (b) Pattern 2 in supabase-ssr-boilerplate.md places the CSP `connect-src` builder in `next.config.ts` itself, not in middleware/proxy. Doubly stale.
- [medium] kit/docs/guide/conventions.md:747 — `## Project Docs Coverage` trigger row still reads `New apps/*/middleware.ts → CLAUDE.md`; add `apps/*/proxy.ts` (or replace).
- [medium] kit/docs/guide/conventions.md:726 — `## Test Presence` exempt-by-filename list includes `middleware.ts` but not `proxy.ts`; the paired script change in 8611f0b already added `proxy.ts` to EXEMPT_FILENAMES — doc and script diverge.
- [medium] (missing — kit/docs/guide/architecture.md / security.md / ops.md beyond ops.md:26) — Coverage rubric: ~21 new `template/apps/web/` files require at least one of those three guides to be staged; only the C-finding-grade ops.md edit is in scope. Optional: a sentence in architecture.md `§ What lives where` noting that `apps/web/` now ships as a tracked tree.
- [medium] (missing — kit/docs/guide/workflow.md) — Coverage rubric: `/ak-new-project § Step 12` rewrite is a workflow shift; workflow.md `§ Starting a New Project` may describe the old create-next-app step. Confirm + update or dismiss via `Docs-Coverage-Bypass:` on the next commit.
- [low] kit/docs/guide/supabase-ssr-boilerplate.md:79, 375 — Two Pattern-1 / Pattern-8 file-path headers carry the rename parenthetical `(renamed from middleware.ts in Next 16)`. Helpful mid-transition; drop later for closure-protocol clean imperative-present.
- [low] (range-wide) — No `Docs-Coverage-Bypass:` trailers in range. Expected for a branch the operator intends to ship in full-coverage shape.

### Tests findings

- [high] kit/tests/template-compose-isolation.bats:180-183 — **DRIFT ARTIFACT, NOT A REAL FINDING.** `git diff origin/main..HEAD` shows the env-var-form bats assertions as "removed" by our branch; in reality main has commit `07755ec fix(bats): unblock release — close 2 post-v1.29.0 regressions + 1 test infra bug` that our branch hasn't yet rebased onto. Phase 2's rebase brings those changes along; the test-suite assertion is intact post-rebase. Verified: `git log --oneline HEAD..origin/main` lists `07755ec` + `ef0b301` (release bump) on main but not in HEAD.
- [medium] kit/tests/structural-invariants.bats:608-625 — Same drift artifact as the high. The `repo_root=$(git rev-parse --show-toplevel)` worktree-aware resolution was added on main in `07755ec`; our branch predates it. Resolved by Phase 2's rebase.
- [low] template/apps/web/e2e/{sign-up,forgot-password}.spec.ts — Spec skeletons `page.goto('/sign-up' | '/sign-in' | '/forgot-password')` but the scaffold only ships `app/{layout,page,globals.css}`. `pnpm test:e2e` on a fresh scaffold will 404 at first goto with no signal it's expected. Mitigate via `template/apps/web/README.md` § "E2E baseline" subsection naming the contract, or `test.skip(!process.env.E2E_AUTH_ROUTES_READY, …)` guard. Spec headers + commit 5da8cec body acknowledge "worked example" intent.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-19)

<!-- audited-at: 220ccad7f20770ad702c75136d8f74c65e869750 -->
<!-- range: 8611f0be27b2bf0b2260a83d9eead03c53e1e8ff..HEAD -->

findings: high=0 medium=0 low=3

### Docs findings

- [low] .claude/skills/devshop/new-project/SKILL.md:822 — Step 12 narrative paragraph still names "Supabase SSR middleware with Pattern 1 .trim() defense"; ambiguous (middleware-as-role vs middleware.ts-file) but technically resolved two paragraphs later at line 855. Operator may tighten to "Supabase SSR proxy (proxy.ts)" or accept the role-vs-file distinction.
- [low] kit/docs/guide/hooks.md:150 — `check-docs-coverage-project.sh` row's Always-loaded trigger filename list still reads `middleware.ts`; should be `proxy.ts / middleware.ts` for transition. Partner-doc to the operator-deferred conventions.md:747 medium; co-ship when that medium is picked up.
- [low] (range-wide) — No Docs-Coverage-Bypass: trailers in range; closure-fix commit (220ccad) called out the 2 deferred medium findings via prose in the commit body rather than the formal bypass-trailer mechanism. Acceptable for small + explicitly-enumerated deferral sets.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Audit-1 closure verification

- ops.md:26 (audit-1 high #1) — CLOSED. Now reads `apps/web/proxy.ts (Supabase SSR session check; renamed from middleware.ts in Next 16)`.
- README.md:51, 55, 73, 106 (audit-1 high #2) — CLOSED. All four lines use the `proxy.ts (or legacy apps/web/middleware.ts)` transitional shape; Pattern-8 anchor link regenerated.
- SKILL.md:854, 1388 (audit-1 high #3) — CLOSED at lines 855 + 1390 post-edit (line numbers shifted by the prose insertion); a third occurrence at line 822 surfaced in audit-2 as a low.
- next.config.ts:10 (audit-1 high #4) — CLOSED. `// Does NOT:` header correctly states CSP headers belong in next.config.ts via Pattern 2's connect-src builder.

