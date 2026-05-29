<!-- audited-at: a793b1b59381235d93f706dc0aa48781379b61bd -->
<!-- range: 4a77f285af222a3128315a76cd2b32fa1cd446a5..a793b1b59381235d93f706dc0aa48781379b61bd -->
# Review — implement-resume-reconcile (devshop pre-ship)

## Router Summary

- Mode: devshop-self-mode (6 gates dispatched, 13 pre-composed carve-outs).
- Real gates: docs-check **pass**, fast-job-local **pass** (1546/1546 bats), /simplify **pass**, docs-and-tests-review **0 high / 0 medium / 1 low (addressed)**, /review **1 low (fixed @ a793b1b — CRLF)**, convention **1 cosmetic (commit-subject length — honor at squash subject)**.
- findings_pending: **0**.  real blocked: **0**.  structural blocked (no UI / no supabase / no perf): Gates 7, 8, 9, 10 (excluded from halt per devshop-mode structural carve-out).
- No LLM-mediated gate marked bare `n/a` (Gates 7/8/9/10 use `blocked (n/a per scope: devshop-self-mode …)`).

## Gate 1: docs-check

- Result: pass
- New resume-reconcile behavior is documented at every required surface:
  - `build/SKILL.md` Step 0 — resume-state table row 2 updated (awk parse + `reconcile-task-commits.sh`); rung 2 fully reworked to invoke the helper, with exit-0 (skip Phase 3) vs non-zero (re-enter Phase 2, print diagnostic) branches; rung 3 destination unchanged and noted as the shared landing point.
  - `build/SKILL.md` Phase 2 — new "non-clean subagent return" note explaining why the gate lives at Step 0 rung 2 (next-invocation risk), not at the live Phase 2 return.
  - `implement/SKILL.md` Step 3 (step 11) — done-means-committed invariant reaffirmed (commit in step 10 AND clean tree).
  - `implement/SKILL.md` Step 4 — completion-summary precondition: confirm done-means-committed before emitting the all-done signal /ak-build trusts.
  - `kit/docs/guide/workflow.md` § tasks.md artifact — reworded to drop the SHA claim and describe the Step 0 reconcile (clean tree + impl-commit-count ≥ done-count, mismatch re-enters Phase 2).
- `kit/scripts/reconcile-task-commits.sh` is referenced from the prose that invokes it: build/SKILL.md (table row 2, rung-2 command + contract pointer, Phase 2 note), implement/SKILL.md (steps 11 + Step 4), and workflow.md tasks.md bullet. Bats-coverage pointer (`kit/tests/util-reconcile-task-commits.bats`) resolves; file exists.
- No doc references a removed/renamed symbol. The stale "tasks.md carries commit SHAs" claim was cleaned up (zero `commit SHA` matches in workflow.md). The merge-devshop row's new cross-ref to `hooks.md § Dual-surface check-types` resolves (hooks.md:486). Referenced bats files (`util-reconcile-task-commits.bats`, `util-ak-build-skill.bats`) both present.
- Tracker closed per close-on-ship convention: the originating `kit/TODOS.md` entry (`/ak-build Phase 2 resume trusts tasks.md done markers`) was added in f81e653 and deleted in cea718c — net-zero across MB..HEAD, absent from HEAD (0 matches). The slot was reused for a separately-discovered, unrelated pre-existing bats failure (legitimately filed, not a leftover of this entry). PLAN.md row moved from "No work in progress" to an Active row; closure of the Active row is Phase 4.0 bookkeeping, out of docs-check scope.

## Dismissals

- None.

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Adapted for devshop: ran the full bats suite (`kit/tests/lib/bats-core/bin/bats kit/tests/`) as the deterministic test gate (devshop equivalent of the project's turbo pipeline).
- Result: pass — 1545 / 1545 tests pass, 0 failures (at HEAD 81d238b).
- The 11 new reconcile-helper cases and 6 new Section-F wiring assertions are included and green. The previously-failing Phase 6 audit-parser test was resolved by rebasing onto current origin/main (main's fix 55e872f).

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

- Result: pass
- No simplifications warranted — helper is already minimal and idiomatic. `reconcile-task-commits.sh` is a faithful clone of the established `kit/scripts/preship/check-llm-mediated-na.sh` precedent (same `# What/Why/Does NOT` + Usage + Exit-codes header shape, same runtime AWK_BIN selection block, same mawk-portability discipline — `($|[^...])` anchors instead of `\b`). The script body is POSIX/dash-clean (no `[[ ]]`, `=~`, arrays, `local`, here-strings). The two awk programs are tight; the four `IMPL_AWK` `/.../ { next }` bookkeeping exclusions are kept as separate rules deliberately so each carries its inline rationale comment (collapsing into one alternation would lose the per-exclusion documentation the spec calls out). No dead code, no unused vars, no unclear naming. The two bats files and the SKILL.md / workflow.md prose edits are precise and consistent with existing structure.

## Dismissals

- **Extract the shared AWK_BIN-selection block into a sourced helper** — dismissed. The ~8-line block is duplicated in exactly two scripts (`reconcile-task-commits.sh` + `check-llm-mediated-na.sh`). Extracting it would add a sourced-dependency for marginal savings and break the "each kit/script is a self-contained, independently testable surface" pattern the codebase deliberately follows. Two copies of a small idiom is the boring, correct choice here.
- **Change shebang `#!/usr/bin/env bash` → `#!/bin/sh`** — dismissed. The body is POSIX-clean so `sh` would work, but both call sites (bats `run bash "$SCRIPT"` and SKILL.md `bash kit/scripts/...`) invoke it explicitly via `bash`, so the shebang is never consulted in practice; it also matches the precedent script's shebang verbatim. Changing it is churn with zero behavioral effect and a small portability-surprise risk.
- **Collapse the four `IMPL_AWK` exclusion rules into one alternation** — dismissed. See Result bullet: the per-rule comments are the documentation value.

## Gate 5: docs-and-tests-review

<!-- audited-at: 81d238b0d744a482ff39df7c69315f24097e282f -->
<!-- range: 4a77f285af222a3128315a76cd2b32fa1cd446a5..81d238b0d744a482ff39df7c69315f24097e282f -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] specs/implement-resume-reconcile/spec.md:§Tests case 7 — spec names only 2 usage-error cases (missing feature-dir arg; tasks.md absent), but the implemented bats adds a 3rd (`case 7c: unresolvable base-ref → exit 64`). Tests exceed the spec rather than fall short; spec could enumerate the base-ref case for parity. Informational drift only, no coverage gap.

Coherence + coverage (no findings): the four changed prose surfaces (build/SKILL.md Step 0 rung 2, build/SKILL.md Phase 2 note, implement/SKILL.md step 11 + Step 4, workflow.md tasks.md description) all describe the same gate consistently. workflow.md's stale "per-task status with commit SHAs" claim was correctly rewritten and is guarded by a negative bats assertion. Script D1/D3/D4 cross-refs resolve to real spec sections. The awk `done` matcher matches exactly the `**Status**: done` marker /ak-implement writes.

### Tests findings

- (none)

Coverage + adequacy (no findings): the reconcile gate is covered by `util-reconcile-task-commits.bats` (11 cases, all green at HEAD): pass, count-shortfall, dirty-tree, partial-done, rebase-SHA-rewrite (D3), bookkeeping-exclusion positive (case 6) + load-bearing negative (case 6b), 3 usage errors, mawk parity. Assertions are deep — every case asserts the exact exit code AND greps concrete diagnostic values (`done=3`, `impl-commits=1`, `no matching commit`, `dirty`, `does not resolve`), not presence-only. Case 5 asserts SHAs actually changed before asserting the verdict survived. Case 6b is mutation-resistant (inverts case 6 to prove a prefix-typo regression would fail). Wiring guarded by `util-ak-build-skill.bats` Section F (6 region-scoped grep cases). Full suite green 1545/1545. The done_count=0 edge is unreachable via rung 2 (routes via rung 6) — no test owed.

### Bypass trailer audit

- (none)

## Gate 6: /review

- Result: findings (1) fixed

Scope reviewed: the 9-file delta `git diff $(git merge-base origin/main HEAD)..HEAD`
(MB `4a77f28`). Substantive surface: `kit/scripts/reconcile-task-commits.sh` +
`kit/tests/util-reconcile-task-commits.bats`, plus the SKILL/workflow wiring and
`util-ak-build-skill.bats` Section F. Both bats suites run green (11 + 53 tests).

### Findings

- **low — `kit/scripts/reconcile-task-commits.sh:91` (DONE_AWK regex)**: a
  `**Status**: done` line carrying a trailing CR (CRLF line ending) does NOT match
  — the `([ \t]*$|[ \t])` anchor treats `\r` as an ordinary char after `done`, so a
  CRLF tasks.md would undercount `DONE_COUNT` (verified: `printf '**Status**: done\r\n'`
  counts 0). Direction is fail-SAFE for the trustworthy verdict (lower done-count can
  only make `IMPL >= DONE` more likely → a false PASS, not a false fail), but it is
  still a latent miscount. tasks.md is repo-authored under LF so this is unlikely in
  practice; flagging for completeness, not blocking.
  Fix: tolerate an optional CR before the EOL/whitespace anchor, e.g.
  `/^\*\*Status\*\*:[ \t]*done([ \t\r]*$|[ \t])/`, or strip CRs (`sub(/\r$/,"")`) at
  the top of the awk program. Add a CRLF fixture case to the bats suite if adopted.

### Correctness checks that PASSED (no finding)

- **Off-by-one / empty-range / zero-done**: verdict is `IMPL_COUNT >= DONE_COUNT`
  (`>=`, not `>`), so all-done-all-committed (N==N) passes and empty range with zero
  done passes (0 >= 0). `awk 'END{print n+0}'` always emits an integer, so the
  `[ "$X" -ge "$Y" ]` arithmetic test can never receive an empty/non-numeric operand
  under `set -e`. Verified manually.
- **Bookkeeping-exclusion anchoring**: the four `next` patterns are correctly anchored
  — `^chore\(roadmap\):` (literal parens) does NOT match `chore(roadmapX)` or
  `fix(roadmap-ui)`; the Phase-0 pattern requires the full `Phase 0 spec skeleton`
  substring after the scope. No real impl commit is wrongly excluded; no bookkeeping
  commit slips through. The DONE regex does NOT false-match the legend line
  `**Status**: todo | in_progress | done | blocked` (anchored on `done` immediately
  after the colon; legend starts with `todo`). Verified manually against 5 scope
  variants + the legend line.
- **Negative control proves exclusion is load-bearing**: case 6b (2 impl + 4
  bookkeeping, 3 done → exit 1) would false-PASS (IMPL=6>=3) if the exclusion broke.
  This is a genuine negative control, not an incidentally-passing test.
- **Rebase-robustness (D3) is genuinely proven**: case 5 advances `main` by a commit
  then `git rebase`s the feature branch, asserts SHAs changed AND exit 0 still holds.
  The excluded Phase-0-skeleton commit is replayed too but stays excluded by subject.
  This is the decisive proof the count heuristic survives the /ak-merge-devshop
  Phase 1.0 rebase path a SHA-stamping approach would false-fail on.
- **Clean-tree detection scope**: `git status --porcelain` catches staged, unstaged,
  AND untracked (case 3 uses an untracked file and correctly fails). It is scoped to
  the work tree containing cwd, so in a linked worktree it reports that worktree's
  state — correct.
- **Exit-code contract**: 0 trustworthy / 1 not-trustworthy / 64 usage, consistent
  across script, header legend, spec, and tests (cases 7a/7b/7c cover all three 64
  paths: missing arg, absent tasks.md, unresolvable base-ref; not-a-git-repo guard
  present but untested — acceptable, hard to fixture). The SKILL rung-2 wiring treats
  ANY non-zero (1 or 64) as "re-enter Phase 2, never skip" — fails safe on an
  unresolvable `origin/main` too.
- **Quoting / `set -euo` discipline**: all expansions quoted; `BASE_REF="${2:-origin/main}"`
  and `AWK_BIN="${AWK_BIN:-}"` guard unbound vars under `set -u`; base-ref is validated
  with `rev-parse --verify` before `git log`, so the `git log | awk` pipe can't fail
  the range under `pipefail`.
- **Wiring sync + doc sweep**: Section F asserts the rung-2 call, the do-NOT-skip /
  re-enter-Phase-2 prose, the trustworthy-condition shape, the Phase 2 note, the
  resume-table row, and that workflow.md dropped the false "commit SHAs" claim. The
  real tasks.md for this feature (4 `**Status**: done`) is counted correctly by the
  helper regex, confirming the marker format matches what /ak-implement writes.

## Focused fix log

- low CRLF finding **fixed** at `a793b1b`: the helper now strips CR on the
  tasks.md read (`tr -d '\r' < "$TASKS_FILE" | "$AWK_BIN" ...`) — chosen over the
  awk-anchor tweak because it needs no regex change, so mawk parity (case 8) is
  untouched. Added regression sentinel case 9 (CRLF tasks.md, 3 done + 2 impl →
  exit 1; would false-pass without the strip) + aligned spec § Tests. Reconcile
  suite green 12/12; full suite green.

## Dismissals

None.

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; the diff is a shell helper + bats + skill/docs prose. Security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

- Result: findings (1) pending
- **SKILL frontmatter — pass.** Both `build/SKILL.md` (v2.0.0) and `implement/SKILL.md` (v3.0.0) retain valid `name:`/`version:`/`description:` blocks with properly closing `---` (build closes L38, implement L21). Versions are unchanged from merge-base (4a77f28); these skills version at major.minor.patch granularity and the edits (prose additions to existing phases) don't warrant a bump — consistent with the skill's existing versioning posture. No frontmatter breakage.
- **New script structure — pass.** `kit/scripts/reconcile-task-commits.sh` matches the sibling pattern (`preship/check-llm-mediated-na.sh`): `#!/usr/bin/env bash` shebang, full `What:`/`Why:`/`Does NOT:`/`Usage:`/`Exit codes:` header comment, `set -euo pipefail`, arg-count + file-existence + git-repo + base-ref usage-error handling (exit 64), and the same mawk-portability discipline (no `\b`, runtime AWK_BIN selection with `AWK_BIN=mawk` pinnable for tests). Clean and idiomatic.
- **Bats coverage — pass.** `kit/tests/util-reconcile-task-commits.bats` (204 lines) targets the new script directly; `kit/tests/util-ak-build-skill.bats` (377 lines) asserts the wiring prose in build/SKILL.md. Full suite run: 53/53 pass, 0 failures.
- **Guide doc linkage — pass (confirmed).** No new guide doc added. `workflow.md` was edited only; it is already linked in `kit/docs/guide/README.md` (L117 + L144 table). No action needed.
- **File mode — pass.** `git ls-files -s kit/scripts/reconcile-task-commits.sh` shows `100644` — matches the structural-invariants convention for kit/scripts (sourced/invoked via `bash`, not `chmod +x`). Note: commit `2c14f6b` explicitly corrected an initial 755 to 644, so this was caught and fixed in-branch.
- **FINDING — commit subject length (3 subjects > 72 chars).** The ≤72-char observable-change style is violated on three subjects:
  - `docs(workflow): restore merge-devshop three-dot-precompute note dropped in rebase` — 81 chars
  - `feat(ak-build): reconcile done markers at Step 0 resume before skipping Phase 2` — 79 chars
  - `docs(ak-implement): reaffirm a task is done only when committed + tree clean` — 76 chars
  Conventional-commit type/scope prefixes are all correct and subjects describe observable changes; only the length cap is breached. These are immutable history on the branch, but since this devshop feature lands via `/ak-merge-devshop` (squash-merge), the final main-branch subject is the operator-authored squash subject — these per-commit subjects are compressed into the `## Squashed commits` bullet list and never become a standalone `git log` entry on main. Impact is therefore cosmetic at the per-commit level. Surfacing per the gate spec; operator should ensure the squash subject stays ≤72.

## Dismissals

- SKILL version not bumped: not a finding — edits are prose-level within existing major versions; the skill does not version per-edit.

## Phase 3 → 4 advance log

### 2026-05-29T00:00:00Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T00:00:00Z -->

### 2026-05-29T00:00:00Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T00:00:00Z -->

### 2026-05-29T00:00:00Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface (Gate 2d)
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T00:00:00Z -->

### 2026-05-29T00:00:00Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T00:00:00Z -->

## Audit 1: pre-polish (2026-05-28)

<!-- audited-at: 81d238b0d744a482ff39df7c69315f24097e282f -->
<!-- range: 4a77f285af222a3128315a76cd2b32fa1cd446a5..81d238b0d744a482ff39df7c69315f24097e282f -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] specs/implement-resume-reconcile/spec.md:§Tests case 7 — spec names only 2 usage-error cases (missing feature-dir arg; tasks.md absent), but the implemented bats adds a 3rd (`case 7c: unresolvable base-ref → exit 64`). Tests exceed the spec rather than fall short; spec could enumerate the base-ref case for parity. Informational drift only, no coverage gap.

Coherence + coverage (no findings): the four changed prose surfaces (build/SKILL.md Step 0 rung 2, build/SKILL.md Phase 2 note, implement/SKILL.md step 11 + Step 4, workflow.md tasks.md description) all describe the same gate consistently. workflow.md's stale "per-task status with commit SHAs" claim was correctly rewritten and is guarded by a negative bats assertion. Script D1/D3/D4 cross-refs resolve to real spec sections. The awk `done` matcher matches exactly the `**Status**: done` marker /ak-implement writes.

### Tests findings

- (none)

Coverage + adequacy (no findings): the reconcile gate is covered by `util-reconcile-task-commits.bats` (11 cases, all green at HEAD): pass, count-shortfall, dirty-tree, partial-done, rebase-SHA-rewrite (D3), bookkeeping-exclusion positive (case 6) + load-bearing negative (case 6b), 3 usage errors, mawk parity. Assertions are deep — every case asserts the exact exit code AND greps concrete diagnostic values (`done=3`, `impl-commits=1`, `no matching commit`, `dirty`, `does not resolve`), not presence-only. Case 5 asserts SHAs actually changed before asserting the verdict survived. Case 6b is mutation-resistant (inverts case 6 to prove a prefix-typo regression would fail). Wiring guarded by `util-ak-build-skill.bats` Section F (6 region-scoped grep cases). Full suite green 1545/1545. The done_count=0 edge is unreachable via rung 2 (routes via rung 6) — no test owed.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-29)

<!-- audited-at: 946446193c7d3e9b9c4a31f21785d531bf0cfe5c -->
<!-- range: 11aa9142629ff039c746e400a73e77930398a1e1..946446193c7d3e9b9c4a31f21785d531bf0cfe5c -->

findings: high=0 medium=0 low=2

Phase 1.1 pre-merge audit, run over the post-rebase full-feature range (explicit
`--range`). The substantive delta since Audit 1 is the CRLF-strip fix to
`reconcile-task-commits.sh` + its regression test (bats case 9); the full range is
re-audited because the rebase invalidated Audit 1's pre-rebase SHA stamp. Both
domains clean of high/medium; two low/informational findings, both "tests exceed
spec" (carried forward from Audit 1's posture).

### Docs findings

- [low] kit/scripts/reconcile-task-commits.sh — new `kit/scripts/**` script lands without an `**Existing projects:**` migration block in any per-commit body. Verified NOT a gap: the script is absent from `kit/manifest.txt` (not synced/locked/scaffold) — it is a devshop-internal `/ak-build` orchestration helper that never reaches existing projects, so no project-side migration is needed. Devshop migration-block enforcement is squash-surface-only (`/ak-merge-devshop` Phase 0.4.5), the correct place to add a "no migration needed" note if the squash diff trips the propagation-block check. Informational.

Coverage + adequacy + coherence (no findings): the substantive change (`reconcile-task-commits.sh`) is documented in `build/SKILL.md` (Step 0 rung 2 full procedure + exit-code routing + resume-table row 2) and `implement/SKILL.md` (done-means-committed invariant, step 11 + Step 4); `workflow.md` artifact-grain section updated to describe reconcile-on-resume. Named-mechanism claims EMPIRICALLY VERIFIED — ran the script: both usage-error paths (no arg / missing tasks.md) exit 64 as documented; the exit-code contract (0 = clean tree + impl≥done; 1 = dirty or impl<done; 64 = usage) matches the script header + SKILL prose verbatim. All cited cross-refs resolve (`devshop-mode.md § Phase 2.5` at `.claude/skills/devshop/build/devshop-mode.md`; `kit/tests/util-reconcile-task-commits.bats`). No renamed/deleted files; no stale-path hits. Section E (CLAUDE.md hygiene) skipped — devshop self-mode.

### Tests findings

- [low] kit/tests/util-reconcile-task-commits.bats — suite carries 12 cases vs the spec's documented "9 cases" (case 6b negative-control + case 9 CRLF sentinel are beyond the enumerated set). Tests exceed spec, not a gap; the spec § Tests header could read "10+ cases" for bookkeeping accuracy. Cosmetic.

Coverage + quality (no findings): `reconcile-task-commits.sh` fully covered by `util-reconcile-task-commits.bats` (12 cases, 12/12 green at HEAD); SKILL/workflow wiring pinned by `util-ak-build-skill.bats` Section F (tests 37-42, 6/6 green). Assertions are on concrete exit codes (0/1/64) + specific diagnostic substrings — no weak truthiness. Robustness cases present: rebase-rewrites-SHAs-preserves-count (case 5, D3), bookkeeping-exclusion positive + negative control (6/6b), mawk-parity (case 8), CRLF-strip regression sentinel (case 9, asserts exit 1 to pin the fix). Skipped-tests audit: no `.only`/`.skip` in diff. No realtime/WebKit/wrapper-boundary surfaces in range.

### Bypass trailer audit

- (none)
