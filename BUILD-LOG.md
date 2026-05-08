# Build Log

Devshop build history. One entry per merged feature branch, most-recent first. Written by `/ak-build` Phase 5.6 on the feature branch before merge, so the entry ships as part of its own commit.

For forward-looking plan: `PLAN.md`. For deferred/long-term work: `kit/ROADMAP.md`.

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
