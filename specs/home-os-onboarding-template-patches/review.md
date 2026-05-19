# Review — home-os-onboarding-template-patches

## Audit 1: manual (2026-05-19)

<!-- audited-at: 09fbe40f11d6bb033ad0e1e4086050b0d0a079d8 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=0

### Docs findings

- (none)

Clean — no docs findings.

**Scope audited**: `origin/main..HEAD` (13 feature commits on `feat/home-os-onboarding-template-patches`). Files touched by feature commits: `.claude/skills/devshop/new-project/SKILL.md`, `CLAUDE.md`, `PLAN.md`, `kit/ROADMAP.md`, `kit/docs/guide/conventions.md`, `template/.devcontainer/firewall-extra-domains`, `template/packages/core/{src/supabase.ts, src/supabase.test.ts, vitest.config.ts, vitest.setup.ts}`. (The wider `git diff origin/main..HEAD` stat additionally shows `.claude/skills/devshop/{build,check-docs-and-tests,implement,pre-ship}/SKILL.md` + `kit/docs/guide/workflow.md` + various `kit/tests/*.bats` deletions + `specs/ak-build-phase-decomposition/**` removals — none touched by the 13 feature commits; they are branch-behind-origin/main artifacts from origin/main's `cb7301d` per-gate-sub-agents commit, out of scope for this audit.)

**Section A (coverage)**: pass. `template/**` and SKILL.md changes have paired docs — CLAUDE.md (gstack rule + Known Footgun), `/ak-new-project § Step 12.5/13a/13b` (vitest alias / vercel preview / .env.local local-stack default), inline file-level comments in supabase.ts/test.ts + firewall-extra-domains + vitest.setup.ts. `kit/docs/guide/conventions.md` gets the new "Long-running processes in the Claude Code harness" section with TOC entry. PLAN.md + kit/ROADMAP.md tracker closures correctly close the `home-os-onboarding-template-patches` row, unblock 3 downstream rows (`template-ci-overhaul`, `home-os-skill-polish-batch`, `ak-build-phase3-blocked-halt` Deps cleanup), and forward-file D3/D4 wrapper work to the new `gstack-symptom-wrappers` row + matching ROADMAP entry.

**Section B (adequacy)**: pass. All touched docs are substantive — no stub / whitespace-only edits. New CLAUDE.md gstack rule names symptom (`mv` + `rm -rf` silent wipe), root cause (vendored upgrade path), mitigation (file upstream or design wrapper), worked drop (`dc18aa3`). New `conventions.md § Long-running processes` provides canonical recipe + mechanism explanation (reparent to PID 1) + Next.js worked example with cwd gotcha + when-NOT-to-use. `/ak-new-project § Step 13b` rewrite cites home-os PR #15 prod-pollution incident inline.

**Section C (coherence)**: pass. All cited SHAs verified (`dc18aa3`, `bdb818b`, `3680582`, `2e417db`, `43baffb` all resolve). The `2e417db` "deleted in" claim verified — that commit removed the 154-line prior ROADMAP entry. `dc18aa3` revert touches files from BOTH `bdb818b` (Chromium fallback) AND `3680582` (screenshot allow-list) — CLAUDE.md's "both D3/D4 reverted in `dc18aa3`" claim is structurally accurate (commit subject only mentions Chromium fallback but file-level diff covers both). `/gstack-upgrade § Step 4` cross-reference verified (Step 4 = "Upgrade" with the clone + mv + rm-rf flow). `kit/scripts/populate-playwright-cache.sh` + `kit/scripts/rebuild-browse.sh` referenced and exist. `kit/docs/guide/conventions.md § Long-running processes` TOC link target matches the new heading anchor.

**Section D (bypass trailers)**: No Docs-Coverage-Bypass trailers in range.

**Section E (CLAUDE.md hygiene)**: Skipped — devshop self-mode (per skill spec: "Mode: project (skip in devshop mode)").

### Tests findings

- [medium] template/packages/core/src/supabase.test.ts:20-21 — `skipIf(!guardActive)` predicate is effectively dead under the new sentinel design. `guardActive = PROD_REF !== 'UNSCAFFOLDED'` evaluates to `true` in both the unscaffolded template (where `PROD_REF === 'PROJECT_REF_PLACEHOLDER'`) AND in every scaffolded project (where `PROD_REF` becomes a real ref like `'abc'`). The skip predicate never evaluates `false`, so the three `it.skipIf(!guardActive)` blocks always run — which is what we want, but the conditional-skip dressing is now misleading. The accompanying comment ("While the placeholder is unsubstituted, the guard self-disables, so the 'throws on prod URL' tests are skipped") describes pre-fix behavior: the new guard at supabase.ts:44 only self-disables when `PRODUCTION_PROJECT_REF === 'UNSCAFFOLDED'`, which is never true in either the template (placeholder) or a scaffolded project (real ref). Net coverage is FINE — tests run and pass in both contexts — but a future reader will be confused about when the skip branch fires (answer: never). Fix: either (a) drop `guardActive` + `skipIf(!guardActive)` and run the throw tests unconditionally (the URL substring check on line 45 of supabase.ts already handles the placeholder case by matching `PROJECT_REF_PLACEHOLDER.supabase.co`), or (b) update the comment to say the skip is reserved for a hypothetical future state where an operator hand-edits `PRODUCTION_PROJECT_REF` to `'UNSCAFFOLDED'` (and explain why anyone would).

### Bypass trailer audit

- (none)
