# Build Log

Devshop build history. One entry per merged feature branch, most-recent first. Written by `/ak-build` Phase 5.6 on the feature branch before merge, so the entry ships as part of its own commit.

For forward-looking plan: `PLAN.md`. For deferred/long-term work: `kit/ROADMAP.md`.

### context-aware-guideline-routing (2026-05-11)

- **Branch**: `feature/context-aware-guideline-routing` (merging via #33)
- **PR**: [#33](https://github.com/meirmsn/abra-kadabra/pull/33)
- **Spec**: `specs/context-aware-guideline-routing/spec.md`
- **Summary**: Promotes `kit/docs/guide/README.md` from flat ToC to a Hybrid routing index — logical groups (Data / Auth + security / Frontend + UI / Ops + deploy / Dev + meta) in the index, flat filesystem on disk. Splits `conventions.md` (943→750 lines) into 3 new topic guides (`migrations.md`, `database-queries.md`, `wrapper-boundaries.md`) per audit-gated D3 proportionality; left-behind pointers preserve external links. Per-file ToCs added to every guide (Layer 2). Layer 3 sub-ToCs adaptively on `conventions.md § Slow-Job Lifecycle` + `§ Non-Negotiables` (the two long-section + independently-routable cases the audit surfaced). Patches `/ak-spec` (new Step 1.5: spec-time routing-index consultation) + `/ak-implement` (Step 1 swaps to routing lookup with `conventions.md` fallback for pre-adoption projects). 3 new BATS invariants (link-resolution, completeness, real-world-grounding-against-lalista-specs; cross-boundary skip-with-reason). 12 routing rows shipped on the audit's proposed initial set + 10 expansion. Closes `kit/ROADMAP.md § Context-aware guideline routing for /ak-spec and /ak-implement`; files PR-B follow-on entry for lalista CLAUDE.md gotcha audit + lift into the new routing system.
- **Commits**: 18 atomic commits (Phase 0 spec skeleton + Phase 1 spec expand + 2 user-gate steps + 3 split commits + 9 implementation commits + Phase 2 tasks.md ledger + Phase 3 pre-ship review.md). Final SHA: `90d6baa`.
- **Quality gates**: all passed — 5 pass + 0 findings_pending + 10 n/a + 0 blocked. Audit 1 clean at HEAD. 745 BATS green (732 existing + 13 new routing tests).

### ak-go-live-arm-a-preflight (2026-05-10)

- **Branch**: `feat/ak-go-live-arm-a-preflight`
- **PR**: TBD
- **Spec**: `specs/ak-go-live-arm-a-preflight/spec.md`
- **Summary**: Adds `/ak-go-live` Step 1.8 — pending-tasks pre-flight surface. Reads the merging PR's body + latest `## Pre-ship audit trail` and `## Ready for review` comments via `gh pr view`, parses every `[ ]` checkbox grouped by section, annotates each `[manual]` (operator-action needed) / `[deferred]` (PR-review concern, post-merge) / `[!]` (CI checkbox `/ak-build` Phase 5.3's auto-marker should have flipped — bookkeeping skipped), and prints a "Pending tasks before live" view. Blocks the merge via `AskUserQuestion` only when `## Out-of-band deploy items` has unchecked items (deploy prereqs by definition); other surfaces are non-blocking reminders. Closes Arm A of `kit/ROADMAP.md § /ak-go-live post-merge prod-config sync` — the entry now narrows to "(Arm B — automation core)" and remains scoped (Management API integration + `SUPABASE_ACCESS_TOKEN` credential surface, deferred).
- **Commits**: 3 atomic commits (Phase 0 spec skeleton + Arm A bundle + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 4 pass + 0 findings_pending + 10 n/a + 0 blocked.

### qa-na-tightening (2026-05-10)

- **Branch**: `feature/qa-na-tightening`
- **PR**: TBD
- **Spec**: `specs/qa-na-tightening/spec.md`
- **Summary**: Tightens the residual self-attestation rung in Gate 9. When a spec declares `## Core user story: N/A — <reason>`, the rationale is now routed through `adversarial-review.sh` via a new `coreUserStoryNaReason` check-type (Sonnet 4.6, inlines `kit/docs/guide/workflow.md § Core user story requirement` + Rule #11 with verbatim ACCEPT/REJECT vocabulary from `kit/ROADMAP.md` lines 1973-1974). `kit/scripts/preship/verify-story.sh`'s `is_na_core_story` branch invokes the new check before emitting "skipped" — interpretive prose ("no visible UI change", "cosmetic only") fails; verifiable file/path claims ("diff is `supabase/migrations/**` only", "no `.tsx` files modified") pass. Closes the gap that previously let Gate 9's artifact-assertion bypass through on operator prose alone.
- **Commits**: 6 atomic commits (Phase 0 spec skeleton + Phase 1 spec expand + 3 implementation commits + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 6 pass + 0 findings_pending + 10 n/a + 0 blocked. Eat-your-own-dogfood live signal: this spec's own `## Core user story: N/A — devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff.` PASSed adversarial review (AC #6).

### slow-job-skip-on-docs-only (2026-05-08)

- **Branch**: `feature/slow-job-skip-on-docs-only` (merging via #29)
- **PR**: [#29](https://github.com/meirmsn/abra-kadabra/pull/29)
- **Spec**: `specs/slow-job-skip-on-docs-only/spec.md`
- **Summary**: Adds a commented `changes:` setup-job + per-job `if:` gate to `template/.github/workflows/ci.yml`'s slow-job stub so docs-only diffs (`**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`) skip the 8–10 min slow-job cycle once a project uncomments. ROADMAP's proposed `slow: paths-ignore:` is invalid at job level (verified empirically — actionlint v1.7.7 rejects it); the chosen shape uses an inline-bash classify step + `case`-glob match (no third-party action) and keeps the single-workflow-file structure. `slow-job-lifecycle-check.sh` extended with Check 6 to assert the filter is wired once the slow-job is uncommented; pass-fixtures updated so they don't regress under Check 6.
- **Commits**: 7 atomic commits (Phase 0 spec skeleton + Tasks 1–5 + pre-ship review.md + this bookkeeping commit)
- **Quality gates**: all passed — 8 pass + 0 findings_pending + 6 n/a + 0 blocked. Audit 1 clean.

### postgrest-null-and-tier-a2-retry-docs (2026-05-08)

- **Branch**: `feat/postgrest-null-and-tier-a2-retry-docs`
- **PR**: TBD
- **Spec**: prose-only, drafted from `kit/TODOS.md` entries (now deleted per closure protocol)
- **Summary**: Two prose-only conventions surfaced by lalista PR #49. (1) `kit/docs/guide/conventions.md § Database queries` + `template/CLAUDE.md` gotcha — PostgREST returns `data: null` + populated `error` on a non-existent column; downstream null-deref masks the typo. Convention requires `error`-first checks at every `.select()` call site (lalista PR #49 hit this twice: `items.name` typo + `purchase_history.list_entry_id` unmapped FK). (2) New `kit/docs/guide/testing.md` (Pattern 1) — Tier A2 retry-budget E2E tests use `page.clock.fastForward()` (Playwright 1.45+) instead of bumping `test.setTimeout()` past the backoff window; cites lalista's `add-item-banner.spec.ts` as the don't-do-this prior art. Closure deletes the two `[v0]` TODOS entries (no strikethrough, no shipped footnote) per the post-cleanup convention.
- **Commits**: 2 atomic commits (uncommitted-TODOs annotation + the two-doc ship + closure)
- **Quality gates**: `/ak-pre-ship` (prose-only docs, no test gates apply)

### cheap-test-gates-local (2026-05-06)

- **Branch**: `feature/cheap-test-gates-local` (merging via #27)
- **PR**: [#27](https://github.com/meirmsn/abra-kadabra/pull/27)
- **Spec**: `specs/cheap-test-gates-local/spec.md`
- **Summary**: Shift cheap test gates from CI-only to local pre-push. New devshop gate `changed-tests-local (ak)` at #2d (parse-check + changed-spec execution + convention-based smoke set). Sub-fix 3 promotes degraded local Supabase to `blocked` on stack-needing diffs. New `localTestSkipReason` adversarial-review check-type.
- **Commits**: 10 atomic commits (Phase 0 skeleton, Phase 1 spec, 4 implementation commits, 3 pre-ship fix commits, 1 doc-sync commit from /document-release)
- **Quality gates**: all passed — 3 pass + 3 findings_fixed + 9 n/a + 0 pending + 0 blocked. Audit 1 (pre-polish) clean.
