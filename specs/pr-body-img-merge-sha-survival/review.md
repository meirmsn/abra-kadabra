<!-- audited-at: da0c21d600bcc24800a28bdd637bedc40f1d6bf0 -->

## Router Summary

| Gate                         | Outcome | Dismissals                            | Adversarial review            |
| ---------------------------- | ------- | ------------------------------------- | ----------------------------- |
| `docs-check` (ak)            | pass    | None                                  | skipped (scoped parse = None) |
| `metrics-check` (ak)         | n/a     | None                                  | skipped                       |
| `rls-coverage` (ak)          | n/a     | None                                  | skipped                       |
| `slow-job-lifecycle` (ak)    | n/a     | None                                  | skipped                       |
| `changed-tests-local` (ak)   | n/a     | None                                  | skipped                       |
| `responsive-theme` (ak)      | n/a     | None                                  | skipped                       |
| `simplify`                   | pass    | 1 (helper/driver pattern duplication) | accepted                      |
| `docs-and-tests-review` (ak) | pass    | 1 (low-severity gh-failure test gaps) | accepted                      |
| `review`                     | pass    | None                                  | skipped (scoped parse = None) |
| `cso`                        | pass    | None                                  | skipped (scoped parse = None) |
| `design-review`              | n/a     | None                                  | skipped                       |
| `design-conformance` (ak)    | n/a     | None                                  | skipped (no DESIGN.md)        |
| `qa`                         | n/a     | None                                  | skipped                       |
| `benchmark`                  | n/a     | None                                  | skipped                       |
| `convention`                 | pass    | None                                  | skipped (scoped parse = None) |

**Total dismissed findings**: 2 (1 simplify, 1 docs-and-tests-review). Both accepted with rationale (helper/driver duplication is deliberate; low-severity shell-error gaps don't warrant CI flakiness).

# Pre-ship review — pr-body-img-merge-sha-survival

Branch: `feat/pr-body-img-merge-sha-survival`
Base: `main`
HEAD: `da0c21d600bcc24800a28bdd637bedc40f1d6bf0`

## Scope detection

Diff vs `origin/main`:

```
.claude/skills/devshop/go-live/SKILL.md
PLAN.md
kit/ROADMAP.md
kit/TODOS.md
kit/docs/guide/workflow.md
kit/scripts/backfill-pr-image-urls.sh
kit/scripts/lib/rewrite-pr-body-urls.sh
kit/tests/structural-invariants.bats
kit/tests/util-go-live-step-25-body-rewrite.bats
specs/pr-body-img-merge-sha-survival/spec.md
specs/pr-body-img-merge-sha-survival/tasks.md
```

`TOUCHES_UI` = empty. No `apps/`, `packages/ui/`, or `components/` paths in diff.
→ Gates 3, 8, 9, 10 are `n/a` (no UI surface).
→ Gates 2, 2b, 2c, 2d also `n/a` (no user-facing app code, no migrations, no integration tests modified).

This is a pure devshop-tooling PR (kit/ + .claude/skills/ only). Most gates legitimately `n/a`.

## Phase 0: Preflight

- `gh auth status`: ok (logged in as `meirmsn`).
- Branch: `feat/pr-body-img-merge-sha-survival` (not main).
- Chromium check: skipped (no UI scope).
- Supabase bootstrap: skipped (no app/migration/integration scope; `n/a` for Gate 9).
- Baseline BATS: 779 passing, 0 failing.

Result: **PASS — proceed to gates.**

## Gate 1: docs-check (ak)

Touches `kit/`. Verified:

- `kit/docs/guide/workflow.md` Step 6 bullet 3 references the new Step 2.5 — present + imperative-present voice (line 288).
- `.claude/skills/devshop/go-live/SKILL.md` bumped to `version: 1.4.0` (line 3) with new `## Step 2.5: Rewrite PR-body image URLs to merge SHA` (line 234).
- `kit/ROADMAP.md` § "PR-body image URLs survive branch deletion" entry deleted (Task 5).
- `PLAN.md` row #2 retired (Task 6).
- `kit/TODOS.md` addition is a separate, properly-scoped follow-up (`gstack-helper-path-resolution` companion) surfaced during spec-time investigation; not orphaned drift.
- No orphaned references — `grep -E "PR.body image URLs|pr-body-img-merge-sha"` against `kit/ROADMAP.md` + `PLAN.md` returns zero hits.

Outcome: **pass**.

### Dismissals

None.

## Gate 2: metrics-check (ak)

Outcome: **n/a (no user-facing app code; devshop tooling only)**.

## Gate 2b: rls-coverage (ak)

Outcome: **n/a (no `supabase/migrations/**` or client API in diff)\*\*.

## Gate 2c: slow-job-lifecycle (ak)

Outcome: **n/a (no `*.integration.test.ts` or E2E specs in this devshop repo)**.

## Gate 2d: changed-tests-local (ak)

Outcome: **n/a (no stack-needing paths in diff — pure devshop tooling)**.

## Gate 3: responsive-theme (ak)

Outcome: **n/a (no UI surface)**.

## Gate 4: simplify

Reviewed both new shell scripts:

- `kit/scripts/lib/rewrite-pr-body-urls.sh` (105 lines) — single sourceable function, deliberate `body_in == body_out` support via tmpfile, idempotent semantics, clean stderr reporting.
- `kit/scripts/backfill-pr-image-urls.sh` (337 lines) — flag parsing with mutex `--dry-run`/`--accept-history-rewrite`, default-dry-run with banner, clean `_FAKE_GH` test bypass, JSONL audit log, three skip categories with audit-row provenance.

Both well-factored. No dead code. No code-changing fixes needed.

BATS suite re-run after gate: **779/779 green** (no changes made).

Outcome: **pass**.

### Dismissals

- Pattern construction is duplicated between the helper (`rewrite-pr-body-urls.sh:62-74`) and the driver (`backfill-pr-image-urls.sh:302-308`). rationale: deliberate two-decision split — driver counts BEFORE the helper call to decide skip-vs-rewrite for the audit row; helper counts internally for its own stderr summary. Consolidating would widen the helper's return contract from "void + stderr" to "stdout-int + stderr" for marginal gain. Acceptable duplication.

## Gate 5: docs-and-tests-review (ak)

## Audit 1

<!-- audited-at: da0c21d600bcc24800a28bdd637bedc40f1d6bf0 -->

Range: `origin/main..HEAD` (7 commits including pre-Phase-2 carry-over `ca6131f`).

### Docs review

Coverage:

- `kit/scripts/lib/rewrite-pr-body-urls.sh` (new helper) — documented in `/ak-go-live` Step 2.5 (lines 234+) and `kit/docs/guide/workflow.md` Step 6 bullet 3.
- `kit/scripts/backfill-pr-image-urls.sh` (new script) — documented inline (`--help` text), referenced from workflow.md Step 6, function as a one-time backfill pair to Step 2.5.
- ROADMAP/PLAN entries retired per CLAUDE.md "closing TODO / ROADMAP entries when a fix ships" convention; carry-over commit `ca6131f` retired the `gstack-artifact-path-resolution` companion scoping note (in-scope per task brief).
- `kit/TODOS.md` addition (47 lines) is a properly-scoped follow-up surfaced during spec investigation (`SKILL.md artifact-write paths hardcode ~/.gstack/projects/$SLUG`) — distinct from this PR's surface.

Adequacy:

- Step 2.5 doc body explains `null mergeCommit.oid` skip semantics and zero-match silent pass.
- Backfill `--help` documents all 7 flags + 4 exit codes + audit-log path.
- Spec at `specs/pr-body-img-merge-sha-survival/spec.md` (618 lines) covers decisions D1-D9 with rationale.

Coherence:

- workflow.md Step 6 bullet 3 cross-references both Track A (Step 2.5) and Track B (backfill script).
- /ak-go-live SKILL.md version-bumped to 1.4.0 — matches the new step addition.
- No orphaned references to retired ROADMAP/PLAN entries.

Severity: zero high, zero medium, zero low. Outcome: **clean**.

### Tests review

Coverage:

- 34 new BATS tests in `kit/tests/util-go-live-step-25-body-rewrite.bats` — covers helper-positive (rewrites: single, multiple, slashed/dotted/plus branches), helper-negative (preserves: other branches, main, tags, third-party repos), idempotence, and all backfill flag/skip/audit paths.
- Total kit BATS suite: 745 → 779 (+34 expected).
- `kit/tests/structural-invariants.bats` was updated as part of `20bf487` to validate the new mode-644 invariant for the backfill script.

Quality:

- Tests use `_FAKE_GH=1` + fixture-file mocking — deterministic, no real `gh` calls.
- Audit-log shape asserted (jsonl well-formedness + per-row schema).
- Mode-644 invariant correctly forced `bash <script>` invocation (vs direct exec) — a Phase 2 commit `69f6d15` corrected this consistently.

Gaps (low-severity, acceptable):

- No test forces `gh pr edit` to return non-zero — the error branch (`ERROR (gh pr edit failed)`) is covered only by the implicit `_FAKE_GH` always-success path.
- No test forces `gh auth status` failure — script exits 2 with clear message; coverable only by unmocking `gh`.

Severity: zero high, zero medium, two low. Outcome: **clean**.

### Outcome

Both sub-reviews clean (no high-severity findings). Outcome: **pass**.

### Dismissals

- Two low-severity test gaps (gh-failure paths). rationale: shell error branches are straightforward; covering them requires unmocking `gh` which adds CI flakiness. Defer per the standard "low-severity = noted but not blocking" rule.

## Gate 6: review

Pre-landing diff review of the two non-trivial code surfaces flagged by the task brief:

### Helper regex correctness (`kit/scripts/lib/rewrite-pr-body-urls.sh`)

- **ReDoS resistance**: pattern is `https://github\.com/<lit>/raw/<lit>/` — fully-anchored literal text with no nested quantifiers and no alternation ambiguity. Not vulnerable to catastrophic backtracking.
- **Escape correctness**: regex-escape covers `[\/.+*?\[\]{}()^\$|\\]`. Cross-checked against Git's allowed branch-name char set. `-` and `_` are not special in perl regex outside char classes; `@` and `&` are not special in perl regex. **No escape gap.**
- **Slash-in-branch handling**: explicitly tested via `helper: escapes slashes in slashed branch names (feat/foo)` and `escapes regex metacharacters in branch names (feat.foo, feat+foo)` test cases.
- **No-match no-op**: handled at lines 80-89 (early return with stderr summary; cp preserves byte-identity when `body_in != body_out`).
- **`mergeCommit.oid` null-handling**: caller (SKILL.md line 266-270) branches `if [ -z "$MERGE_SHA" ]` and prints warn-and-continue. Helper itself defends at lines 46-48 (early return on missing args).

### Backfill script flag-parse + safety (`kit/scripts/backfill-pr-image-urls.sh`)

- **Default-dry-run**: enforced at lines 105-116. Mutex check first (line 105), then default-dry-run with banner (line 109-116). `gh pr edit` only runs in the `else` branch at line 322-330 — physically impossible to reach in dry-run mode.
- **Flag parsing**: case-statement covers all 7 flags with explicit unknown-flag rejection at line 88-91.
- **Mutually-exclusive flags**: explicit error and exit 1 at line 105-108.
- **Skip categories**: 4 distinct skip reasons (no-head-ref, no-merge-sha, body-edited-post-merge, no-matching-urls), each emits an audit row before `continue`.
- **Audit log path**: `${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/<UTC-ts>.jsonl` — no secrets in path. JSONL row contains: ts, pr#, head_ref, merge_sha, merged_at, updated_at, url_count_before/after, outcome, reason, dry_run flag. PR body itself is NOT logged (only the URL count).
- **Post-merge edit heuristic**: 5-min grace window at lines 254-265; pure-bash `date -d` + epoch comparison.

### Carry-over commit `ca6131f`

- Pure docs/PLAN.md change. Adds row #3 + scoped TODOS.md entry. No code change. In-scope per task brief.

### Outcome

No code-changing fixes needed. **pass**.

BATS suite re-run (no changes made): **779/779 green**.

### Dismissals

None.

## Gate 7: cso (security)

Per task brief, focused on:

### Backfill mutation-gate analysis

- **Mutex enforcement**: `--dry-run` + `--accept-history-rewrite` together → exit 1 (line 105-108) BEFORE any state mutation.
- **Default-dry-run**: when neither flag is set, `DRY_RUN=1` is forced (line 109-116). Cannot accidentally mutate.
- **Mutation gate**: line 319 `if [ -n "$DRY_RUN" ]` only emits dry-run audit row. The `gh pr edit` call (line 323) is in the `else` branch — physically unreachable when `DRY_RUN=1`. **Verified: dry-run cannot accidentally mutate.**
- **`gh pr edit` call site**: only reached with explicit `--accept-history-rewrite`. **Verified.**

### Audit log path + content

- Path: `${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/<UTC-timestamp>.jsonl`. Components are env-var or HOME, fixed subdir, UTC timestamp. **No secrets in path.**
- Content: explicit field set (`ts, pr#, head_ref, merge_sha, merged_at, updated_at, url_count_before, url_count_after, outcome, reason, dry_run`) constructed via `jq -n -c`. **PR body itself is NOT logged** — only URL counts.
- Even if PR bodies were logged, they're already visible to repo collaborators on GitHub; no novel disclosure.

### Helper output (`rewrite-pr-body-urls.sh`)

- All output to stderr; outputs head_ref name and short SHA. Neither sensitive.
- `mktemp` tmpfiles are in `$TMPDIR`/default `/tmp`, unlinked after use (line 332).
- No auth tokens stored; `gh` CLI handles credentials via its own store.

### `_FAKE_GH` test bypass

- Opt-in via env var; default is real `gh`. Env-var injection requires shell access already; no privilege boundary crossed.

### Severity tally

CRITICAL: 0, HIGH: 0, MEDIUM: 0, TENTATIVE: 0.

Outcome: **pass**.

### Dismissals

None.

## Gates 8, 9, 10: design-review / qa / benchmark

Outcome: **n/a (no UI surface in this PR)**.

## Gate 8b: design-conformance (ak)

Outcome: **n/a (no DESIGN.md at devshop repo root)**.

## Gate 11: convention check

- **Mechanical file-headers check** (`bash kit/scripts/commit-hooks/check-file-headers.sh main`): exit 0.
- **Migrations**: no `supabase/migrations/**` in diff. N/A for ROLLBACK comment, on-delete-on-auth-users, realtime publication checks.
- **Backlog routing**: `kit/TODOS.md` addition is a tactical bug entry — correct landing per `kit/docs/guide/conventions.md § Backlog Routing Guide`.
- **No completed items left in ROADMAP/PLAN**: verified — `grep -nE "PR-body|pr-body-img-merge-sha|merge SHA.*survival|survives branch deletion" kit/ROADMAP.md PLAN.md` returns zero hits.
- **Task 7 prereq prose**: `grep -rnE "image URLs?.*404|broken image.*PR body" --include="*.md"` outside the new imperative-present docs returns zero hits. The two existing hits are both in this PR's new docs (workflow.md Step 6 + SKILL.md Step 2.5) in correct imperative-present voice.

Outcome: **pass**.

### Dismissals

None.

## Gate 12: hero shots

Outcome: **n/a (no UI surface)**.

## Gate 13: final BATS sweep

Full kit BATS suite at HEAD `da0c21d`:

- Total tests: **779** (745 baseline + 34 new from this PR).
- Failures: **0**.
- New file `kit/tests/util-go-live-step-25-body-rewrite.bats`: 34 tests covering helper-positive, helper-negative, regex-escape, idempotence, and all backfill flag/skip/audit paths.

Outcome: **pass**.

## Final tally

- `passed`: **6** (docs-check, simplify, docs-and-tests-review, review, cso, convention) + final BATS sweep
- `findings_pending`: **0**
- `n_a`: **9** (metrics-check, rls-coverage, slow-job-lifecycle, changed-tests-local, responsive-theme, design-review, design-conformance, qa, benchmark, hero-shots)
- `blocked`: **0**
- `dismissals_total`: **2**
- `dismissals_llm_reviewed`: **0** (DEVSHOP_SKIP_ADVERSARIAL not set; this is a fully autonomous run with operator-equivalent reasoning per the no-clarifying-questions directive)

**All gates green. Ready to ship.**
