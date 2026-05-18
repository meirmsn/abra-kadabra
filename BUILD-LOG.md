# Build Log

Devshop build history. One entry per merged feature branch, most-recent first. Written by `/ak-build` Phase 4.0 on the feature branch before `/ship` pushes, so the entry ships in the original CI cycle. Phase 5.6 is a verify-only fallback for resume rungs where 4.0 didn't fire.

For forward-looking plan: `PLAN.md`. For deferred/long-term work: `kit/ROADMAP.md`.

### ak-pre-ship-migration-rollback-gate (2026-05-17, sub-fix B only)

- **Branch**: `feat/ak-pre-ship-migration-rollback-gate` (squashed to `7262fac` on main via `/ak-merge-devshop`)
- **Spec**: `specs/ak-pre-ship-migration-rollback-gate/review.md` (audit-only; no spec.md — ad-hoc devshop feature)
- **Summary**: Ships **sub-fix B** of the three-deliverable `ak-pre-ship-migration-rollback-gate` PLAN row — a new `/ak-pre-ship` Gate 2e that round-trips every migration's `-- ROLLBACK:` block against the local Postgres in ~30s, catching rollback bugs that `db:reset` / forward-apply don't exercise (the class home-os PR #26 + #27 both hit and only discovered at CI's slow-job ~10 min in). New `kit/scripts/preship/migration-rollback-roundtrip.sh` is diff-scoped to `supabase/migrations/**`, probes both candidate DB URLs (`host.docker.internal:54322` compose-shape + `localhost:54322` docker-bind legacy), per-migration applies the rollback SQL then re-applies the forward migration, collects every failure with psql ERROR line + fix-recipe pointing at `IF EXISTS` / enum-narrowing-safe casts. Gate 2e slots between `fast-job-local` (2d) and renumbered `changed-tests-local` (2f) so a broken rollback can't poison the local DB mid-test-walk. **Not shipped here**: sub-fix A (fix `ci-rollback-explain.sh` contract — require `-- ROLLBACK:` markers, fail loudly on marker-less migrations per home-os PR #28's 6-attempt CI fix-loop arc) and sub-fix C (`kit/docs/guide/migrations.md` + `kit/docs/guide/debugging-pgrst-cache.md` codifying the PGRST204 disambiguation recipe). The `kit/ROADMAP.md` entry was rewritten + the `PLAN.md` row reworded post-7262fac to reflect that A and C are still pending — row stays in `## Planned`.
- **Commits**: collapsed to 1 squash on `main` per `/ak-merge-devshop`; per-commit SHAs recoverable via `git reflog` for ~90 days. Final squash SHA: `7262fac`.
- **Quality gates**: 13 new bats invariants pin `n/a` (no migrations / empty dir / no rollback blocks / diff doesn't touch migrations), `blocked` (DB unreachable), `pass` (clean + multi-migration + mixed-with-no-rollback), `findings` (rollback parse error, forward re-apply failure, multi-finding count), `LOCAL_TESTS_BASE_REF` scope behavior. No `devshop.*SkipReason` wired — gate failures mean editing the migration's `-- ROLLBACK:` block, not skipping the gate.

### pipeline-correctness (2026-05-17)

- **Branch**: `feat/pipeline-correctness` (squashed to `fb18c8f` on main via `/ak-merge-devshop`)
- **Spec**: `specs/pipeline-correctness/review.md` (audit-only; no spec.md — ad-hoc devshop feature)
- **Summary**: Two bundled PLAN rows sharing the `/ak-build` + `/ak-check-docs-and-tests` + `/ak-go-live` SKILL surface, shipped in one merge for internal consistency. **(1) `/ak-check-docs-and-tests` Step 5** — orchestrator stages + commits the appended `## Audit N` section atomically per audit; refuses on dirty tree containing anything beyond the audit file, surfaces `UNCOMMITTED:` for the caller to route; never `git stash` / `git restore` (both destroy operator work silently). Closes the orchestrator-side gap home-os PR #10 (2026-05-13) tripped. **(2) `/ak-build` Phase 4.0** — composes + commits the BUILD-LOG entry + removes the `PLAN.md` Active row on the feature branch BEFORE `/ship` pushes, so bookkeeping rides in the original CI cycle. Phase 5.6 rewritten as verification-only (greps for `chore(build-log)` commit; common path no-ops, resume rungs run full procedure + re-watch CI). **Phase 5.7 deleted** — its "watch every push" guarantee folds into 5.3's preamble; Phase 5.8.1's polish-loop CI sanity check is the enforcement point. **Why bundle:** eliminates the ~5-min fixed-cost docs-only push the historic Phase 5.6 triggered (25–50 min/week saved on a small-PR cadence). New BUILD-LOG entry shape omits the explicit `**PR**:` row (PR# rides via squash-merge subject on main). 22 new bats invariants pin Step 5's commit shape, Phase 4.0 presence, Phase 5.6 verify-only rewrite, Phase 5.7 deletion, and 5.3's watch-every-push guarantee; test files switched from hardcoded `/devshop/...` paths to `TESTS_DIR`-relative so they actually validate worktree edits. Doc updates propagated to `workflow.md` diagram + prose + `/ak-go-live` cross-refs, `conventions.md` pointer, `CLAUDE.md` Non-Negotiable, plus a stale-pointer sweep across 5 sibling reference docs (`BUILD-LOG.md` intro, `template/BUILD-LOG.md` intro, `CLAUDE.md § Known Footguns` line citing the deleted Phase 5.7, `spec/SKILL.md` Step 4, `migrate-project/SKILL.md` lines 80 + 108) surfaced by `/ak-docs-review` Audit 1 inside `/ak-merge-devshop` Phase 1 and closed in the same branch. Closes `kit/TODOS.md` entries (orchestrator audit-commit gap, fold Phase 5.6 bookkeeping into `/ship`, `gh pr merge --delete-branch` silent local-cleanup swallow) + `PLAN.md` rows `ak-build-pipeline-correctness` + `fold-build-log-into-ship-push`.
- **Commits**: 3 constituent commits (`fe192d2` feat-shape, `e4c5800` audit-driven stale-pointer sweep, `bd79f17` Audit 1 record) collapsed to 1 squash on `main` per `/ak-merge-devshop`; SHAs recoverable via `git reflog` for ~90 days.
- **Quality gates**: Audit 1 clean (0/0/0) at `bd79f17` — recorded one `Docs-Coverage-Bypass:` trailer (Layer 1 over-fire on `template/**` for the single-line `template/BUILD-LOG.md` intro pointer-correction; verified). 893/893 BATS green at commit time (873 existing + 22 new pinning Phase 4.0/5.6/5.7 + Step 5 commit shape). Workflow note: this session surfaced the out-of-band-branch-switch failure mode (filed as `kit/TODOS.md § /ak-merge-devshop is not worktree-aware` and merged separately on `598bf48`).

### pr-body-img-merge-sha-survival (2026-05-11)

- **Branch**: `feat/pr-body-img-merge-sha-survival` (merging via #34)
- **PR**: [#34](https://github.com/meirmsn/abra-kadabra/pull/34)
- **Spec**: `specs/pr-body-img-merge-sha-survival/spec.md`
- **Summary**: Two-track fix for the broken-image-on-closed-PR bug. **Track A** — new `## Step 2.5: Rewrite PR-body image URLs to merge SHA` in `/ak-go-live` between `/land-and-deploy` (Step 2) and branch cleanup (Step 2b). Rewrites `/raw/${headRefName}/` URL slices in the PR body to `/raw/${mergeCommit.oid}/` so embedded hero / qa-walk / design evidence survives `--delete-branch`. Branch-name regex-escaped (slashes-in-branch handled). Skip-with-warning on null `mergeCommit.oid`; silent no-op on zero matches. Bumps `/ak-go-live` `version: 1.3.0 → 1.4.0`. **Track B** — new one-shot `kit/scripts/backfill-pr-image-urls.sh` for retroactive cleanup of historic closed PRs. `--dry-run` default; `--accept-history-rewrite` required for live mutation. Per-run JSONL audit log. Both call sites share one source of truth via extracted helper at `kit/scripts/lib/rewrite-pr-body-urls.sh`. Two post-Phase-3 polish iterations from the lalista backfill: (1) flipped the post-merge-edit conservatism to opt-in via `--skip-edited` (default-on caused PRs #60 / #61 to be mis-suppressed because `/ak-build` Phase 5.3 routinely edits PR bodies post-merge to mark CI checkboxes — those auto-edits trip the 5min heuristic without ever touching image URLs); (2) extended the script to ALSO rewrite issue comments authored by the gh-cli authenticated user, with `--bodies-only` opt-out (Phase 6 audit-trail comments routinely embed hero shots in `### Evidence` that go stale on `--delete-branch` exactly the same way as the body's; comments by other users are skipped via `not-our-comment` audit reason — gh API only allows self-edits). Audit log JSONL gains a `target` field discriminating `body` vs `comment:<id>`. Cumulative lalista backfill: 9 PR bodies + 8 PR comments = 17 surfaces, 73 URLs total. Idempotent re-run confirms no stale URLs remain. Closes `kit/ROADMAP.md § PR-body image URLs survive branch deletion` (deleted entirely — both tracks shipped).
- **Commits**: 11 atomic commits on the feature branch (will collapse to 1 squash on `main` per `/ak-merge-devshop`); per-commit SHAs preserved as compressed bullets in the squash message body, recoverable via `git reflog` for ~90 days. Final pre-merge SHA: `a3a77cd` (BUILD-LOG fix at `<this commit>` follows for Audit 2 cleanliness).
- **Quality gates**: all passed — 6 pass + 0 findings_pending + 9 n/a + 0 blocked. Audit 1 clean at `da0c21d`. Audit 2 (post-polish, this audit) — 1 medium finding (this entry's pre-polish staleness, fixed in same range). 785/785 BATS green (745 existing + 40 new tests across SKILL.md content + helper behavior + backfill body-and-comments behavior).

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

<!--
  Historical backfill (2026-05-11): the 12 entries below were written
  retroactively to cover the v1.22.0 → v1.25.0 window. Pre-v1.25.0 ships
  did not go through `/ak-build` Phase 5.6 (the convention that authors
  BUILD-LOG entries on the feature branch), so these entries are
  reconstructed from commit messages + PR diffs and use a minimal shape
  (PR, Summary, Commits, Note) — `Spec` and `Quality gates` rows are
  omitted because there is no `specs/<feature>/review.md` to cite. Forward-
  going discipline is healthy; this is a one-shot history-fix.
-->

### ak-check-docs-and-tests + ak-build phase 5.8/5.9 (2026-05-06)

- **PR**: no GitHub PR — squash-merged to main locally via `/ak-merge-devshop` over four feature branches (PR-A, PR-B, PR-C, post-polish), bundling `/ak-build` Phase 5.8/5.9 wiring with the underlying audit-time skill split.
- **Summary**: Moves adversarial Layer 2 docs/tests coverage review from per-commit hooks to **audit moments** (`/ak-pre-ship` Gate 5 + `/ak-build` Phase 5.8). New orchestrator `/ak-check-docs-and-tests` computes commit range from the latest `## Audit N` section's `<!-- audited-at: <SHA> -->` in `specs/<feature>/review.md`, invokes `/ak-docs-review` + `/ak-tests-review` in sequence, appends a new `## Audit N` section with structured findings — idempotent on unchanged HEAD. `/ak-tests-review` renamed from `/ak-test-review`; gains Section A (coverage of new behavior) and Section C (bypass trailer audit) on top of the 11 existing quality sub-sections. `/ak-docs-review` is brand-new — coverage + adequacy + cross-doc coherence + bypass-trailer audit, repo-aware (devshop self-mode vs project mode). Layer 1 surface symmetry rename: `check-test-coverage-project.sh → check-tests-coverage-project.sh`, `check-test-coverage.sh → check-tests-coverage-devshop.sh`, `check-docs-freshness-project.sh → check-docs-coverage-project.sh`; new `check-docs-coverage-devshop.sh`. Per-commit Layer 2 reviews (`docsReviewed`, `testCoverage`, `testCoverageProject`, `docsFreshnessProject`) are removed from the loop; coverage judgment lives exclusively in the audit-time orchestrator. New `prepare-commit-msg` hook emits `Docs-Coverage-Bypass:` / `Tests-Coverage-Bypass:` Git trailers when `git -c devshop.{docs,tests}CoverageReason="<why>"` accepts a bypass — trailers travel with the commit (rebase/push/clone-stable) and audit-time reviews harvest them as `[bypass-revisit]` findings. `/ak-build` SKILL.md bumped 1.5.0 → 1.7.0 (Phase 5.8 + 5.9 + resume rungs 1a/1b + Phase 6 audit-comment shape). `/ak-pre-ship` Gate 5 emits `<!-- audited-at: <SHA> -->` as the first line of `review.md` — the contract 5.8.2 reads to derive the audit range.
- **Commits**: `afad4fe` (5.8/5.9 wiring) + `b02d531` (PR-A audit-time skills) + `a0f1705` (PR-B Phase 5.8 wiring + two-file collapse) + `a2e1f34` (PR-C per-commit Layer 2 removal + bypass trailers) + `37c1074` (post-pr-c deferred-low fixes) + `7f18084` (Audit 1 record). Recorded under `specs/ak-check-docs-and-tests/`.
- **Note:** Historical backfill — pre-dates the convention that authors BUILD-LOG entries during `/ak-build` Phase 5.6.

### adversarial-review doc inlining + addition-drift sweep (2026-05-01)

- **PR**: no GitHub PR — squash-merged locally via `/ak-merge-devshop`.
- **Summary**: `adversarial-review.sh` gains a `GUIDES_TO_INCLUDE` map parallel to `CONVENTIONS_TO_INCLUDE` — when a staged diff touches a code area whose reference doc is a guide, the chapter body inlines with the headers (not just `## ` TOC entries). Routes: `kit/scripts/commit-hooks/`, `kit/hooks/`, `kit/scripts/preship/`, `template/.husky/`, `.claude/settings.json` → `hooks.md` FULL; `template/`, `kit/manifest.txt`, `init-devshop.sh`, `kit/scripts/sync/` → file-lifecycle sections of the right guide. Closes the structural blind spot where the reviewer could see "section called Husky pre-commit" but not the bypass table inside, so a missing row went unnoticed. Two drift cases backfilled the same turn: `check-test-coverage-project.sh`, `check-docs-freshness-project.sh`, and `check-security-files-freshness.sh` all shipped without rows in `hooks.md § 2`'s bypass table — added.
- **Commits**: `953e9a1`.
- **Note:** Historical backfill.

### docsReviewed unification across both repos (2026-05-01)

- **PR**: no GitHub PR — squash-merged locally via `/ak-merge-devshop`.
- **Summary**: Drops the parallel `docsFreshnessProject` check-type. One `docsReviewed` reviewer now serves both surfaces, branching internally on `REPO_MODE` (devshop = real `kit/` dir, project = otherwise). Same prompt rules apply to both; only the inlined doc catalog differs. Devshop branch reads `CLAUDE.md`/`OVERVIEW.md`/`README.md` FULL + `guide/*` + `FAQ.md` headers; project branch reads `CLAUDE.md`/`METRICS.md`/`OVERVIEW.md`/`ARCHITECTURE.md`/per-package READMEs FULL. Bypass-key rename `devshop.docsFreshnessReviewed → devshop.docsReviewed` propagates through `check-docs-freshness-project.sh`, `hooks.md § 2` bypass table, recipes, and conventions docs. Head-N truncations dropped (`CLAUDE.md` head-100, etc. → all FULL) — `§ Gotchas` (load-bearing, lives past line 100) is now visible to the reviewer. `MODEL.md` inline dropped (file folded into `OVERVIEW.md` upstream).
- **Commits**: `9b18f46` + `889c883`.
- **Note:** Historical backfill.

### project docs deeper hierarchy — OVERVIEW + ARCHITECTURE + per-package READMEs (#25, 2026-05-01)

- **Branch**: `feat/project-docs-deeper-hierarchy` (merged via #25)
- **PR**: [#25](https://github.com/meirmsn/abra-kadabra/pull/25)
- **Summary**: Adds Tier 2 (`OVERVIEW.md` product overview + `ARCHITECTURE.md` system overview, both opt-in via file existence) and Tier 3 (per-package READMEs at `apps/<x>/`, `packages/<x>/`, `supabase/functions/`, opt-in per package). Builds on the prior "Hierarchical docs scaffold in template" work. Trigger map extended in `check-docs-freshness-project.sh`; reviewer context inlines `OVERVIEW.md` head 150, `ARCHITECTURE.md` head 150, every per-package README at HEAD up to 80 lines. Templates added with `[scaffold-once]` manifest tracking. Robustness fixes to `adversarial-review.sh`: `COMMIT_TIMEOUT` 90 → 180s (PR #25's inlined guide-doc bodies made sonnet calls hit the prior limit on docsReviewed); backtick escape fix.
- **Commits**: `5c937a9`. 13 new BATS cases; full kit suite 495/495 pass.
- **Note:** Historical backfill.

### DEPS-WATCH.md session-start banner (#24, 2026-04-30)

- **Branch**: `feat/deps-watch` (merged via #24)
- **PR**: [#24](https://github.com/meirmsn/abra-kadabra/pull/24)
- **Summary**: `session-start.sh` now reads `$ROOT/DEPS-WATCH.md` (markdown table) and surfaces any row whose `recheck-on` date is past as a 🚨 banner in the user-visible session briefing. Silent if file is absent or no rows overdue. Adds `template/DEPS-WATCH.md` (empty stub) registered in `kit/manifest.txt` as `[scaffold-once]` so `/ak-new-project` delivers the file but bidirectional sync skips it (project owns its rows after creation). Use case: dependabot major-version PRs that can't merge until upstream ecosystem catches up (e.g. `eslint 10` needs `eslint-config-next` bump first) — operator runs `@dependabot ignore this major version` + adds a row to `DEPS-WATCH.md`; banner re-prompts on the chosen date. `guide/hooks.md` updated to list DEPS-WATCH alerts among session-start briefing components.
- **Commits**: `f38f3b7`.
- **Note:** Historical backfill.

### pre-push wrapper+symlink refactor (#22, 2026-04-30)

- **Branch**: `refactor/pre-push-wrapper-symlink` (merged via #22)
- **PR**: [#22](https://github.com/meirmsn/abra-kadabra/pull/22)
- **Summary**: Mirrors the existing `.hooks/pre-commit` wrapper+symlink pattern for `pre-push`. Single policy source at `kit/hooks/pre-push.sh`; `.husky/pre-push` wrappers (template + devshop) become ~10-line husky-shim bridges that exec the `.hooks/pre-push` symlink. Repo mode (project vs devshop) detected at runtime by probing whether `kit/` is a real directory at the repo root — same probe `kit/hooks/pre-commit.sh` uses. Closes the template-propagation wart: every prior devshop-side `template/.husky/pre-push` edit cost a per-project follow-up (PR G's content propagated into lalista as an unstaged change after container rebuild — second occurrence of the per-project alignment-PR pattern). Behavior is byte-for-byte unchanged: same checks, same bypass flags (`devshop.prDescStaleReason`, `devshop.dirtyPushReason`), same short-circuits, same hard-block-on-main-push.
- **Commits**: `b7de9df`. 18 pre-push bats cases pass (5 new).
- **Note:** Historical backfill.

### adversarial review of project exempt-file additions (#20, 2026-04-30)

- **Branch**: `feat/exempt-file-adversarial-review` (merged via #20)
- **PR**: [#20](https://github.com/meirmsn/abra-kadabra/pull/20)
- **Summary**: `check-exempt-additions.sh` runs in the project pre-commit chain BEFORE `check-test-coverage-project.sh` + `check-docs-freshness-project.sh`. Reviews additions to the two coverage-gate exempt files (`.devshop-test-coverage-exempt`, `.devshop-docs-freshness-exempt`): pre-flight (deterministic hard block — no adversarial bypass) parses each added line as `path  # reason` and rejects path-like tokens in the reason field (`*.ts`, `*.tsx`, `*.spec.ts`, `*.test.ts`); vague-reason scoring then routes the addition through adversarial review. Closes the gap identified in the original hook audit and deferred from PR #10's scope: operators (and Claude) can no longer silently exempt a path by citing covering specs/tests that don't actually exist.
- **Commits**: `c750698`.
- **Note:** Historical backfill.

### manifest-driven file lifecycle — annotation + init-devshop + sync (#12 + #14 + #15, 2026-04-30)

- **Branches**: `feat/manifest-lifecycle-foundation` (#12), `feat/manifest-driven-init-devshop` (#14), `feat/manifest-driven-sync-scripts` (#15)
- **PRs**: [#12](https://github.com/meirmsn/abra-kadabra/pull/12) + [#14](https://github.com/meirmsn/abra-kadabra/pull/14) + [#15](https://github.com/meirmsn/abra-kadabra/pull/15)
- **Summary**: Three-PR series that consolidates file-lifecycle classification into `kit/manifest.txt` as the single source of truth. (1) #12 — annotates each declared workspace path with an inline `[tag]` (`[sync]`, `[locked]`, `[locked-dir]`, `[symlink]`, `[scaffold-once]`) + ships shared parser at `kit/scripts/sync/lib/parse-manifest.sh`. Foundation only, no behavior change. (2) #14 — replaces `init-devshop.sh`'s hardcoded LOCKED file loop with a manifest-driven loop; `install -D -m 644 -o root -g root <template-source> <workspace-dest>` atomically refreshes content + chowns + chmods per `[locked]` entry. This is the line of code that actually fixes the `.husky/pre-push` propagation bug PR #8 surfaced (PR #8 added `template/.husky/pre-push` but no existing project picked it up — init-devshop's hardcoded list didn't include it). (3) #15 — `sync/from-devshop.sh` pulls only `[sync]` entries (skips `[locked]`, `[symlink]`, `[scaffold-once]`); `sync/to-devshop.sh` pushes only `[sync]` entries; `commit-hooks/check-security-files-freshness.sh` now verifies every manifest `[locked]` file against its template source (was: just `settings.json` + `.dcg.toml`) — catches Layer-2 erosion of any workspace-side locked file.
- **Commits**: `283590d` (#12) + `6c4f4b3` (#14) + `0cb378b` (#15).
- **Note:** Historical backfill. The three PRs ship sequentially but represent one logical consolidation effort — combined into a single entry per the grouping rule (one coherent feature = one BUILD-LOG entry).

### macOS host setup guide + /ak-new-project Step 0 gate (#13, 2026-04-30)

- **Branch**: `feat/new-project-macos-host-setup` (merged via #13)
- **PR**: [#13](https://github.com/meirmsn/abra-kadabra/pull/13)
- **Summary**: Lifts the four host-side prereqs that the Option 3 compose-isolation threat model assumes (Docker Desktop File Sharing restriction, Docker Engine JSON hardening, `/etc/hosts` loopback, Docker Desktop hygiene) out of per-project launch checklists into a canonical, per-Mac, one-time guide. (1) New `kit/docs/guide/macos-host-setup.md` — apply once before your first devshop project on a machine; every subsequent project inherits. (2) New Step 0 in `/ak-new-project` — single `AskUserQuestion` gate. "Yes" skips with optional `docker-info` sanity check; "no" reads the guide and walks through one numbered step at a time. Skill stays slim — guide loaded on demand only. (3) Step 2b's option-(b) end-of-Phase-B handoff: Step 4 creates `apps/web/.env.local` with `NEXT_PUBLIC_SUPABASE_URL` + anon JWT pulled from `pnpm db:status` — folds the old per-project item into normal scaffolding. Cross-link from `local-supabase-compose-isolation.md § Host-side prereqs` to the new guide.
- **Commits**: `a171b81`.
- **Note:** Historical backfill.

### /ak-handoff command + template gitignore (2026-04-29)

- **Branch**: (direct push to main, no GitHub PR)
- **Summary**: New project-scoped slash command `/ak-handoff` that writes a handoff doc to `.handoff/<name>.md` so a fresh-context Claude session can pick up where the current one left off. Detects the active session's slug, AI title, and permission mode by reading the JSONL transcript; auto-picks a handoff name (arg → existing `/rename` title → slugified AI title → fallback slug); emits a single copy-paste `claude -n <name>__continuation_<n>` bootstrap command for the next session plus a `/rename <name>` line for the current one. Gracefully reports — does not attempt to programmatically rename or enter plan mode. Template gitignore picks up `.handoff/` so future projects bootstrapped via `/ak-new-project` keep these transient docs out of git by default. Docs updated: `kit/docs/guide/workflow.md` standalone-skills list + skills table.
- **Commits**: `a799f91`.
- **Note:** Historical backfill.

### docsReviewed reviewer detects rename/move/delete drift (#11, 2026-04-29)

- **Branch**: `feat/docs-reviewed-rename-drift-prompt` (merged via #11)
- **PR**: [#11](https://github.com/meirmsn/abra-kadabra/pull/11)
- **Summary**: Replaces the closed PR #9 (deterministic `kit/scripts`-only linter) with an extension to the existing `docsReviewed` adversarial reviewer prompt. Same drift class — script renames, doc-section heading renames, CI job renames, skill renames, gate renames, roadmap renames — all surface the same way: an old name lingers in active docs after a rename or deletion. `adversarial-review.sh`'s context-gathering for `docsReviewed` adds a "Renamed/moved/deleted in this commit" section, populated via `git diff --cached --name-status --diff-filter=DR -M`. When empty, the section reads `(none — no files renamed, moved, or deleted in this commit)` so the reviewer knows the rule is trivially satisfied. Better trade-off than maintaining a per-class deterministic linter — one prompt rule covers the entire drift class.
- **Commits**: `3d3dfa2`.
- **Note:** Historical backfill.

### project-repo gates triplet — test-presence + docs-freshness + scaffold (2026-04-28)

- **Branch**: (direct push to main, no GitHub PR — pre-dates the project pre-push convention from PR #8)
- **Summary**: Three coupled additions that ship together so one project-side adoption flushes false-positive exempt lists for all three at once. (1) `kit/scripts/commit-hooks/check-test-coverage-project.sh` — Layer-1 deterministic test-presence hook for project repos. New file under `apps/*/{src,app,components,lib,hooks}/` or `packages/*/src/` without paired `.test.ts` → BLOCK. Source delete with paired test still present → BLOCK as orphan. Modify without staged test → WARN only. Per-project override at `.devshop-test-coverage-exempt`. (2) `kit/scripts/commit-hooks/check-docs-freshness-project.sh` — Layer-1 docs-freshness hook. New `apps/*/app/**/page.tsx`/`layout.tsx`/`route.ts`/`middleware.ts` and `packages/*/src/api/*.ts` → `CLAUDE.md` must be staged. New `posthog.capture(...)` / `Sentry.captureException(...)` call sites → `METRICS.md` staged. Source delete while doc still references the path → BLOCK on stale ref. Per-project override `.devshop-docs-freshness-exempt`. (3) `template/CLAUDE.md`, `template/TODOS.md`, `template/METRICS.md` — scaffold-once orientation skeletons completing the six-file hierarchy delivered by `/ak-new-project`.
- **Commits**: `e4e6abf`.
- **Note:** Historical backfill — pre-dates `/ak-build` Phase 5.6 and the project pre-push convention. The test-coverage script was later renamed to `check-tests-coverage-project.sh` (Layer 1 symmetry, see the `ak-check-docs-and-tests` entry above); the docs-freshness script was renamed to `check-docs-coverage-project.sh`.
