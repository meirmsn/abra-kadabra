# Review — ak-merge-rebase-before-audit

## Router Summary

All gates dismissed zero findings. Gate 5 (docs+tests audit) recorded
`high=0 medium=1 low=1`: the low (Phase 0.2 `$ANCHOR` forward-ref) was
fixed in-branch; the medium (TODOS/PLAN closure) is scheduled for Phase 4.0
(deletes the `kit/TODOS.md` entry + PLAN Active row before the Phase 4.5
squash, net-zero against origin/main). The four LLM-mediated gates
(7 /cso, 8 /design-review, 9 /qa, 10 /benchmark) are **structural**
carve-outs — devshop self-mode has no auth/UI/perf surface — recorded in the
Phase 3 → 4 advance log with `STRUCTURAL` stamps (not submitted to
adversarial review; architecturally inapplicable, not practically blocked).

## Gate 1: docs-check

- Result: pass

The behavior change (rebase-before-audit in /ak-merge-devshop) carries its doc
updates in the same branch:

- `kit/docs/guide/workflow.md` — /ak-merge-devshop skill-map row updated to the
  rebase-before-audit ordering + `--range "$ANCHOR..HEAD"`.
- `.claude/skills/devshop/build/devshop-mode.md` — § "What /ak-merge-devshop
  handles" Phase 1 summary + idempotence note updated (Phase 2.5 catch).
- `.claude/skills/devshop/merge-devshop/SKILL.md` — self-documenting (the skill
  IS the doc); Phase 0.2 table, Phase 1.0/1.1, Phase 2, Idempotence all updated.
- CLAUDE.md references "/ak-merge-devshop Phase 1" generically (audit is still in
  Phase 1, now as 1.1) — no stale ordering claim (verified Phase 2.5).

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase / RLS surface)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass

Adapted for devshop (bats is the test surface, not turbo). Full suite:
`kit/tests/lib/bats-core/bin/bats kit/tests/` → 1503 passed, 0 failed.
Targeted `util-ak-merge-devshop.bats` → 96 passed, 0 failed.

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

- Result: n/a (devshop-self-mode: no supabase advisor surface)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

- Result: pass

/code-review (medium effort) found no correctness bugs and no mechanical fixes to apply. The diff is pure Markdown + bats: grep anchors all match real SKILL.md content, awk range boundaries (`### 1.0:`/`### 1.1:`/`## Phase 2:`/`## Phase 3:`) all exist, the ordering test correctly resolves rebase (line 671) before audit (line 809), and the negated-pipeline regression guard (`! awk ... | grep -qE '^\$GIT_CMD rebase'`) correctly confirms the rebase is gone from Phase 2. Documented procedure (rebase-before-audit, virtiofs merge fallback, transient-commit discard via soft-reset) is logically sound. Baseline confirmed 96/96 passing. One advisory (NOT applied): the Phase 2 "documents rebase ran in 1.0" test (bats line 479) has a 3-way alternation whose middle branch `rebased .* onto .ANCHOR` matches zero lines — but it's a deliberately-tolerant multi-shape matcher (the other two branches match); narrowing it would make the test more brittle, so leaving as-is. No prose rewrites suggested.

## Dismissals

None

## Audit 1: pre-ship (2026-05-28)

<!-- audited-at: e9949746b8f4433da34b451134fcf2586780630c -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=1

### Docs findings

- [medium] `kit/TODOS.md:10` — the `/ak-merge-devshop audits before rebasing` TODO is still open (`[ ]`) at HEAD although this branch ships the fix (`9e9c511`); per CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships" the entry + its PLAN.md:72 cross-ref must be deleted in this PR. `tasks.md` defers this to Phase 4.0 bookkeeping (still `pending`); MUST land before the Phase 4.5 squash merge.
- [low] `.claude/skills/devshop/merge-devshop/SKILL.md:286` — the new Phase 0.2 audit-status row displays `$ANCHOR` in its operator-facing message, but `$ANCHOR` is only computed in Phase 1.0 (0.2 computes only `$BASE_DIVERGED`). Reword to drop the forward-reference or note where `$ANCHOR` is selected. Cosmetic (markdown display-logic table, not an executable block).

Informational: coverage otherwise solid — the restructure is reflected in `kit/docs/guide/workflow.md` + `.claude/skills/devshop/build/devshop-mode.md`; no stale "Phase 2 rebase" claims remain in `kit/docs/` / `CLAUDE.md` / `architecture.md` (surviving SKILL.md hits are intentional historical/dependency prose). No `Docs-Coverage-Bypass:` / `CLAUDE-MD-Bypass:` trailers. Section E (CLAUDE.md hygiene) skipped — devshop self-mode.

### Tests findings

- (none)

Informational: Section F2 adds 5 new bats assertions pinning every new invariant (rebase-before-audit ordering via line-number comparison, Phase 1.0 rebase + anchor-select + phantom-fallback, Phase 1.1 explicit `--range`); Section G adds a regression guard that Phase 2 no longer rebases. Assertions are concrete (literal-token greps + actual line-number ordering + negative regression guard), no `.only`/`.skip`. Empirically verified: `kit/tests/util-ak-merge-devshop.bats` → 96/96 passing, all grep anchors resolve against live SKILL.md. No `Tests-Coverage-Bypass:` trailers.

### Bypass trailer audit

- (none)

## Gate 6: /review

- Result: pass

Pure Markdown + bats diff (no runtime/app code). All CRITICAL checklist categories
(SQL & Data Safety, Race Conditions, LLM Output Trust Boundary, Shell Injection,
Enum & Value Completeness) are N/A — no application code, SQL, auth, migrations, or
LLM trust boundaries in the diff. INFORMATIONAL categories likewise N/A.

Verified the load-bearing logic of the restructured skill (the only logic-bearing
surface in a Markdown skill change):

- **Ordering invariant holds.** The sole `^$GIT_CMD rebase "$ANCHOR"` command sits
  at `.claude/skills/devshop/merge-devshop/SKILL.md:671` (Phase 1.0), before the
  `/ak-check-docs-and-tests` invocation at :809 (Phase 1.1). The bats line-order
  assertion (`grep ... | head -1`) correctly picks the Phase 1.0 rebase, not the
  merge-fallback or `--abort` lines. Phase 2 (`:893`) contains no `^$GIT_CMD rebase`
  — only prose references — matching the regression-guard test.
- **Anchor detection is consistent across phases.** Phase 1.0 (:661-669) and Phase 2
  (:922-924) recompute `$ANCHOR` identically via `git rev-list --count origin/main..main`.
  Bare `git` (not `$GIT_CMD`) for the ref-count is correct: linked worktrees share the
  parent repo's ref store, so `origin/main`/`main` resolve identically from a worktree.
- **`--range $ANCHOR..HEAD` consumed verbatim.** `/ak-check-docs-and-tests § Step 2`
  (:114) uses an explicit `--range` verbatim and passes it to both sub-skills; the
  idempotence no-op (audited-at == HEAD) still applies. Matches the skill's claim.
- **Merge-fallback edge case reasoning is sound.** When Phase 1.0 falls back to
  `git merge "$ANCHOR"`, `$ANCHOR..HEAD` (diff form) shows exactly the branch's delta
  (merging an ancestor adds no net tree content); the transient merge commit is
  discarded by Phase 2's soft-reset. Doc's "merge commit adds no phantom content" is
  accurate.
- **Anchor-mismatch race documented, not engineered around** (:904-408 prose): if main
  moves between Phase 1.0 and Phase 2, Phase 3's `git merge --ff-only` catches the
  divergence and refuses. Appropriate for a single-dev devshop.
- **Cross-doc coherence clean.** devshop-mode.md:368, workflow.md:488, and SKILL.md all
  describe rebase-before-audit + `--range $ANCHOR..HEAD` consistently.
- **Tests green at HEAD.** `kit/tests/util-ak-merge-devshop.bats`: 96/96 ok, 0 failures.
  New Section F2 assertions (ordering, anchor-select, phantom fallback, `--range`) and
  the updated Section G (Phase 2 no-rebase regression guard) all pass.

Scope check: CLEAN. Intent (rebase before audit to kill phantom-revert findings) matches
delivered diff. One INFORMATIONAL note below; non-blocking.

- low — PLAN.md:69 / kit/TODOS.md:10 — The PLAN Active row is added and the closed
  `kit/TODOS.md § /ak-merge-devshop audits before rebasing` entry is still present in
  this branch. spec.md defers PLAN/TODOS closure to Phase 4.0 (currently `pending`),
  which runs after this Gate 6. Expected interim state, not a defect.
  Fix: ensure Phase 4.0 deletes the PLAN Active row + the closed TODOS entry before the
  /ak-merge-devshop squash, so the net delta against origin/main is net-zero per the
  spec's Acceptance criterion. No code change required at this gate.

## Dismissals

None

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

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

- Result: pass

Devshop convention check:

- SKILL.md frontmatter intact (`name: ak-merge-devshop`, description, allowed-tools).
- No new scripts under `kit/scripts/` → no new bats-for-scripts requirement.
  The changed bats file (`util-ak-merge-devshop.bats`) already covers the skill.
- Guide-doc routing unaffected (no new guide doc; `workflow.md` already indexed).
- Markdown-only + bats diff; no shell-script structure changes.
- Commit + PR text style: feature-branch commits use observable-change subjects
  (`fix(ak-merge-devshop): rebase before auditing to kill phantom revert findings`).

## Dismissals

None

## Phase 3 → 4 advance log

### 2026-05-28T08:56:44Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T08:56:44Z -->

### 2026-05-28T08:56:44Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T08:56:44Z -->

### 2026-05-28T08:56:44Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T08:56:44Z -->

### 2026-05-28T08:56:44Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-28T08:56:44Z -->

## Audit 2: manual (2026-05-28)

<!-- audited-at: e059f7f723649b093f674942af4660f8063c0ed1 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

Re-audit over `origin/main..HEAD` (the branch is not diverged — origin/main is
an ancestor of HEAD, so the two-dot range is the true delta). Audit 1 stamped at
`e994974`; HEAD has since advanced to `e059f7f` via `dad908d` (Phase 3 pre-ship
gate results + the SKILL.md Phase 0.2 reword that fixed Audit 1's low) and
`e059f7f` (BUILD-LOG entry + TODOS/PLAN closure that resolved Audit 1's medium).
Both Audit 1 findings are now resolved; this re-audit is clean.

### Docs findings

- (none)

Informational: Audit 1's low (Phase 0.2 `$ANCHOR` forward-ref) is fixed in
`dad908d` — the display row now names the rebase target in plain terms. Audit 1's
medium (TODOS/PLAN closure) is resolved in `e059f7f` — the closed `kit/TODOS.md`
entry is deleted and the PLAN `## Active` row is restored to `_No work in
progress._`, net-zero against origin/main per CLAUDE.md § "Closing TODO / ROADMAP
entries when a fix ships". Coverage otherwise solid: rebase-before-audit ordering
is reflected in `kit/docs/guide/workflow.md` + `.claude/skills/devshop/build/devshop-mode.md`;
all cited SKILL.md anchors resolve (rebase :671, audit :810, soft-reset :926;
exactly one rebase command, in Phase 1.0). Section E (CLAUDE.md hygiene) skipped —
devshop self-mode.

### Tests findings

- (none)

Informational: the sole behavior-bearing surface (`merge-devshop/SKILL.md`) is
pinned by `kit/tests/util-ak-merge-devshop.bats § Section F2` (+6 assertions:
ordering via line-number comparison, Phase 1.0 rebase + anchor-select + phantom
fallback, Phase 1.1 explicit `--range`, Phase 2 no-rebase regression guard).
Concrete assertions, no `.only`/`.skip`. Empirically verified at HEAD:
`util-ak-merge-devshop.bats` → 96 ok / 0 not-ok, all grep anchors resolve. The
remaining range commits (specs/ gate artifacts, bookkeeping) touch no executable
surface.

### Bypass trailer audit

- `dad908d` Docs-Coverage-Bypass: "SKILL.md edit is a 1-line display-string reword
  in merge-devshop Phase 0.2's audit-status table … guide-doc coverage already
  shipped (workflow.md @ 9e9c511 + devshop-mode.md @ e994974)" — **VERIFIED**.
  dad908d's only non-specs change IS the Phase 0.2 display-row reword; both guide
  docs carry the rebase-before-audit ordering; the NOT-AFFECTED catalog claim
  holds. Load-bearing and valid given the diff.
