# Review — ak-check-docs-orphan-stubs

Phase 3 pre-ship gauntlet (devshop gate set: 6 dispatched + 13 carve-outs). Gate sinks concatenated in canonical order; the Gate 5 docs+tests audit is the `## Audit 1` section below.

## Gate 1: docs-check

- Result: pass

Deterministic docs-coverage check (devshop self-mode). Verified that every source
surface in the diff (`origin/main...HEAD`) is paired with a substantive,
accurate doc update.

### Source surfaces touched

- `kit/scripts/preship/audit-tracker-only.sh` (new) — tracker-only range
  classifier helper.
- `.claude/skills/devshop/check-docs-and-tests/SKILL.md` (modified) — Step 1
  wires a tracker-only short-circuit before the substep-6 review.md scaffold.

### Doc pairing — `kit/docs/guide/workflow.md`

Both surfaces are documented by the workflow.md note added in this branch. Two
distinct, substantive additions (not a stub):

1. **Phase 5.8 prose** — the existing 5.8 paragraph now states: "Step 1 first
   runs `kit/scripts/preship/audit-tracker-only.sh "$RANGE"` and short-circuits
   (exit 0, no scaffold, no sub-skill dispatch) when the range is tracker-only
   — so a doc-only / tracker-only delta does not manufacture an orphan
   `review.md` stub." Accurately names the helper, the exit-0 contract, the
   "no scaffold / no sub-skill dispatch" behavior, and the orphan-stub
   motivation.
2. **Devshop Skill Map table row** (`/ak-check-docs-and-tests`) — adds a
   **Tracker-only short-circuit** clause naming the helper path, enumerating
   the tracker set (PLAN/TODOS/BUILD-LOG/PRODUCT-ROADMAP/DEPS-WATCH `.md`,
   `kit/{TODOS,ROADMAP,notes,version}`, `kit/docs/CHANGELOG.md`,
   `kit/FRICTION-LOG.md`), and explicitly noting guide docs + tests are
   deliberately excluded ("those ARE auditable") — which matches the helper's
   `case` arms and its header comment exactly. Describes the exit-0 print +
   no-scaffold/no-dispatch/no-append behavior and the orphan-stub fix.

### Accuracy cross-check (doc vs. code)

- Tracker set in the doc matches the `case` patterns in
  `audit-tracker-only.sh` (lines 57-66) verbatim.
- "guide docs + tests deliberately excluded" matches the helper's
  "Deliberately NOT trackers" comment (lines 25-27).
- Exit-code semantics (0 short-circuit / 1 audit / 64 usage) in the helper
  header align with the doc's stated 0-short-circuit / fall-through-to-audit
  behavior.
- The SKILL.md Step 1 edit (substep 5 short-circuit precedes substep 6
  scaffold) is the behavior the workflow note describes.

The helper is `kit/scripts/preship/**` — a script-internal classifier whose
operator-facing contract is the workflow.md note + the SKILL.md Step 1 prose;
no additional standalone doc surface is required.

## Dismissals

None

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

- Result: pass (bats kit/tests/ — 1621 tests, 0 failures)

Devshop test surface is bats, not turbo. Full suite green at HEAD
(verified repeatedly post-rebase + post-Phase-2.5-fix).

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

- Result: pass (no changes applied)

Reviewed the changed code for reuse / simplification / efficiency / altitude.
Primary surface: `kit/scripts/preship/audit-tracker-only.sh` (~25 lines of code
under a documentation-heavy header). Secondary: the SKILL.md Step 1 prose
addition (descriptive docs, not refactorable code).

### Reuse

No existing helper performs git-range tracker classification — nothing to
deduplicate against. The `case`-glob tracker set is the single source of truth;
it is mirrored (not duplicated as code) in the workflow.md note.

### Simplification — candidates considered and rejected

- **Collapse the `while`/`case` loop into a `grep -vE` regex one-liner.**
  Rejected: the header deliberately chose `case` globbing "so dash-sourcing is
  safe" (no regex engine, mawk/dash-clean). A regex rewrite would trade that
  guarantee for terseness and complicate the empty-diff and diff-failure
  branches. Not a genuine win.
- **Drop the explicit `if ! CHANGED=$(git diff ...)` capture.** Load-bearing:
  `set -e` does NOT catch a failure inside command-substitution used as
  heredoc input, so the explicit check is what produces the safe exit-1 on an
  unresolvable range (covered by the bats case at line 83). Cannot remove.
- **Pipe `$CHANGED` into the loop instead of the `<<EOF` heredoc.** Rejected:
  a pipe runs the loop in a subshell, so `exit 1` would exit the subshell, not
  the script — silently breaking the first-source-path short-circuit. The
  heredoc is the correct POSIX form here.

### Efficiency

Single `git diff` invocation; early `exit 1` on the first non-tracker path
(no full-scan). Already optimal for the task.

### Altitude

Single responsibility (classify → exit code), no audit/scaffold/dispatch logic
leaking in (the "Does NOT" header enforces this). Appropriately scoped — no
over-abstraction, no premature generalization.

Conclusion: the helper already sits at the boring-solution baseline the
convention prescribes. No behavior-preserving simplification exists that
wouldn't sacrifice dash-safety or correctness. No commit made; bats not re-run
(no code change).

## Dismissals

None

## Gate 5: docs-and-tests-review

Result: PASS (no halt) — findings: high=0 medium=0 low=1. Audit 1 (pre-polish) committed at `22d0973`.

Pointer: the full audit record lives in `specs/ak-check-docs-orphan-stubs/review.md § Audit 1` (not in this gates/ sink). Per-domain sinks: `gates/audit-1-docs.md`, `gates/audit-1-tests.md`.

### Findings summary

- **Docs**: 0/0/0 — Clean. Coverage satisfied (workflow.md skill-map row + Phase 5.8 prose both name `audit-tracker-only.sh`, pairing the `kit/scripts/preship/**` + `.claude/skills/**/SKILL.md` surfaces). Two Docs-Coverage-Bypass trailers (`bcfd847` exit-1 fix, `34c7d55` mode-bit) both VERIFIED. Section E (CLAUDE.md hygiene) is project-mode-only — skipped in devshop self-mode.
- **Tests**: 0/0/1 — one **low**: the classifier's tracker prefix-globs (`kit/TODOS*`/`kit/ROADMAP*`/`kit/version*`) lack a negative boundary test for prefix-adjacent non-tracker paths. Latent (no such file exists), `kit/version*` prefix deliberate. Non-blocking. One Tests-Coverage-Bypass trailer (`411a3c1`, worktree-blind tests-coverage hook) VERIFIED — the paired bats exists + 9/9 green.

### Dogfood note (this diff modifies the audited skill)

The diff HAS source surface (`audit-tracker-only.sh`, two `.bats`, the SKILL.md Step-1 wiring), so the new tracker-only short-circuit correctly did **NOT** fire — the classifier returned exit 1 on the preliminary `origin/main..HEAD` range and the full audit ran (sub-skills dispatched, `## Audit 1` appended + committed). No short-circuit short-cut. No HIGH-severity dogfood finding.

## Dismissals

None.

## Gate 6: /review

Result: findings (1) fixed — the one P2 informational finding below (tracker prefix over-match) was cross-confirmed by Gate 5's tests-review and fixed by the orchestrator at commit `664602f` (exact-anchor file trackers `kit/TODOS.md|kit/ROADMAP.md|kit/version`; `kit/notes/*` stays a dir prefix). Boundary regression bats cases added (`kit/versioning.md`, `kit/ROADMAPER` → exit 1; `kit/notes/**` → exit 0). No remaining pending findings; no critical. Original gate disposition (PASS, 1 informational pending) retained below for the audit trail.

Scope check: CLEAN. Intent (commits + spec) = add a tracker-only range classifier (`audit-tracker-only.sh`) wired into the audit orchestrator's Step 1 to skip orphan `review.md` stubs on tracker-only ranges. Delivered = exactly that (helper + 9-case bats + SKILL.md Step-1 wiring + workflow.md note + kit/TODOS closure + FRICTION-LOG entry). No scope creep, no missing requirements. Diff is bash + markdown only — no SQL, no LLM trust boundary, no shell-injection surface, no auth/RLS, no migrations, no CI/CD publish changes.

### Findings by severity

**Critical (P0/P1):** none.

**Informational (P2):**

- [P2] (confidence: 7/10) `kit/scripts/preship/audit-tracker-only.sh:59` — Tracker prefix-globs `kit/TODOS*`, `kit/ROADMAP*`, `kit/version*` over-match. Empirically confirmed: a hypothetical non-tracker path `kit/versioning.md` (or `kit/TODOS-archive.md`, `kit/ROADMAPS/x.md`) classifies as tracker-only (exit 0) and would skip its audit. Risk is latent — no such file exists today, and `kit/version*` is a deliberate prefix because `kit/version` has no extension (documented at script line 22). `kit/notes/*` is correctly path-anchored (`/`), so only the three extension-less/prefix forms are loose.
  Recommended fix (operator decision; NOT auto-applied): tighten to `kit/TODOS.md|kit/ROADMAP.md|kit/version` exact-match where an extension exists, keeping the prefix only for the genuinely extension-less `kit/version`; OR add a negative boundary bats case asserting a prefix-adjacent non-tracker path resolves to exit 1; OR record the over-match as an accepted trade-off in the spec. Same edge the Gate 5 tests-review flagged as low.

### Verification performed (empirical, this gate)

- Exit-code contract: tracker-only/empty → 0; source/mixed/guide-doc/test-only → 1; usage (no arg) → 64; git-diff failure on unresolvable range → 1 (safe "audit" direction, message to stderr). All confirmed by probe in a scratch repo.
- Glob anchoring: `kit/docs/guide/ops.md` → exit 1 (guide docs ARE auditable, NOT short-circuited); `kit/docs/RANDOM.md` → exit 1; only `kit/docs/CHANGELOG.md` exact → tracker. Confirmed.
- `set -e` / git-diff-failure handling: `if ! CHANGED=$(git diff ...)` captures the failure in command position (verified: set -e does not swallow it into a false empty-diff exit-0). `bash -x` trace confirms the classify loop short-circuits to exit 1 on first source path.
- Whitespace-in-filename: `IFS= read -r path` over a heredoc handles a `kit/scripts/spaced file.sh` source path correctly (exit 1). No word-splitting bug.
- Deleted-tracker path: classified by path, not git status (exit 0). Correct.
- SKILL.md Step-1 preliminary-range parse (`audited-at` marker → `<SHA>..HEAD`, else `origin/main..HEAD`) is consistent with Step 2's documented parse contract.

## Dismissals

- **Empty `origin/main..HEAD` short-circuits (exit 0) on a fresh feature with no review.md.** Considered as a possible "skips scaffolding when it shouldn't" path. Dismissed: an empty diff genuinely has nothing to audit, so exit 0 / no-scaffold is correct. The dogfood run proved the non-empty source path scaffolds + audits normally.
- **`Enum & Value Completeness` cross-consumer trace.** N/A — the diff adds no enum/status/tier constant; the case-glob tracker set is self-contained and its consumers (SKILL Step 1, workflow.md) are all in-diff.
- **gstack onboarding / telemetry / learnings plumbing** in the skill preamble — not run; out of scope for a read-only audit gate inside a subagent.

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

Devshop convention check (self-mode, adapted — no supabase/UI/metrics surface).
All four sub-checks pass; no violations, no fixes needed.

### (a) SKILL.md frontmatter intact

`.claude/skills/devshop/check-docs-and-tests/SKILL.md` frontmatter block is
well-formed: opening `---` at line 1, closing `---` at line 25, with
`name: ak-check-docs-and-tests`, `version: 2.0.0`, and a `description:` block
present. The Step 1 edit is in the body, below the frontmatter — untouched.

### (b) New shell script: header + `set -euo pipefail` + tracked 644

`kit/scripts/preship/audit-tracker-only.sh`:

- 3-line What/Why/Does NOT header present (lines 2-9): `# What:` (classify a
  git range tracker-only vs source-surface), `# Why:` (orphan review.md stub
  avoidance), `# Does NOT:` (no audit / no scaffold / no sub-skill call — only
  an exit-code verdict). Shebang `#!/usr/bin/env bash` on line 1.
- `set -euo pipefail` present (line 33).
- Tracked mode: `git ls-files -s` reports `100644` — NOT 755. Matches every
  peer in `kit/scripts/preship/` (all 16 are 100644), consistent with the
  devshop script-lock convention. The branch's commit `34c7d55`
  (`fix(preship): track audit-tracker-only.sh as 644`) already corrected this.

### (c) Bats test file exists for the new script

`kit/tests/util-audit-tracker-only.bats` exists (2589 bytes, 9 tests) and
covers the full D2 matrix: tracker-only → 0, mixed/pure-source → 1,
guide-doc-only → 1, test-only → 1, friction-log-only → 0, empty diff → 0,
usage error → 64, and unresolvable-range → 1 (no false short-circuit).

### (d) workflow.md note linked/placed sensibly

The note lives in two sensible locations in `kit/docs/guide/workflow.md`:

- the **Phase 5.8** prose paragraph (where `/ak-check-docs-and-tests` is
  described in the pipeline flow), and
- the **Devshop Skill Map** table row for `/ak-check-docs-and-tests`.
  Both name the helper by path and describe the short-circuit contract. Placement
  is co-located with the skill they document — correct.

### Reuse posture (no duplication)

`kit/scripts/preship/path-classifier.sh` answers a different question (does the
diff need the local Supabase stack — stack-needing vs not), with a different
classification set. The new helper's tracker-only-vs-source-surface concern
does not overlap it, so a separate helper is correct, not a duplication.

bats not re-run (no code change made by this gate); the green baseline (1621
tests, exit 0) established at gate-suite start stands.

## Dismissals

None

## Audit 1: pre-polish (2026-05-31)

<!-- audited-at: bcfd847c9adcdc6ed6016c4390683c91bcc42f1f -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

Bypass-trailer audit (docs): `bcfd847` Docs-Coverage-Bypass (exit-1-on-unresolvable-range; no doc-text change to an already-documented helper) — VERIFIED. `34c7d55` Docs-Coverage-Bypass (mode-bit 755→644 only) — VERIFIED. No CLAUDE-MD-Bypass trailers in range. Section E (CLAUDE.md hygiene) skipped — devshop self-mode.

### Tests findings

- [low] kit/tests/util-audit-tracker-only.bats (D2 matrix) — tracker prefix-globs (`kit/TODOS*`/`kit/ROADMAP*`/`kit/version*`) have no negative boundary test proving they don't over-match a prefix-adjacent non-tracker path. Risk is latent (no such file exists today); `kit/version*` prefix is deliberate (no extension). Non-blocking.

### Bypass trailer audit

- 411a3c1 Tests-Coverage-Bypass: "util-audit-tracker-only.bats IS staged and pairs the script (8 green); check-tests-coverage-devshop.sh hardcodes TESTS_DIR=/devshop/kit/tests and can't see worktree-only bats — hook worktree-awareness gap, not a missing test." — VERIFIED (test present + 9/9 green at HEAD; bypass load-bearing, documented in FRICTION-LOG + kit/TODOS).
- No Docs-Coverage-Bypass trailers escalated (both VERIFIED above).

## Phase 3 → 4 advance log

### 2026-06-01T05:27:16Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T05:27:16Z -->

### 2026-06-01T05:27:16Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T05:27:16Z -->

### 2026-06-01T05:27:16Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T05:27:16Z -->

### 2026-06-01T05:27:16Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T05:27:16Z -->

## Audit 2: manual (2026-05-31)

<!-- audited-at: cd030af5c1a3f68853174e30eb53c79e7ce33ef2 -->
<!-- range: 66f5fa6e86aced81386e001f016bd6bdafe43bf9..cd030af5c1a3f68853174e30eb53c79e7ce33ef2 -->

findings: high=0 medium=1 low=2

### Docs findings

### [domain: docs] [section: B] [severity: low]

**File**: .claude/skills/devshop/check-docs-and-tests/SKILL.md:302-304, 426-427
**What**: Incidental indentation regression — the `git add` continuation lines in Step 5 substep 2 and the "Audit N § Tests findings" continuation in the Notes section lost their 3-space leading indent (now at column 0), breaking their association with the surrounding numbered/bulleted list item.
**Why**: Formatting churn introduced by this range, not the intended change. In `66f5fa6` (base) these continuation lines were indented `   "$FEATURE_DIR/...` to stay inside list item `2.`; the diff hunks (`-   "$FEATURE_DIR/...` → `+"$FEATURE_DIR/...`) dedented them to column 0, which a Markdown renderer reads as a list-item break. Cosmetic stub-edit churn co-staged with the substantive short-circuit edit; no behavior impact.
**Fix**: Re-indent the three continuation lines (`"$FEATURE_DIR/review.md" ...`, `"$FEATURE_DIR/gates/audit-$AUDIT_N-tests.md"`, and `Audit N § Tests findings`) back to their list-item indentation (3 spaces for the numbered item, 2 for the bullet) to match the unchanged sibling lines.

---

Coverage (Section A): clean. Source surfaces in range — new `kit/scripts/preship/audit-tracker-only.sh` (rubric: `kit/scripts/preship/**` → pre-ship SKILL.md OR `kit/docs/guide/*`; satisfied by `kit/docs/guide/workflow.md` Phase 5.8 prose + skill-map row) and `.claude/skills/devshop/check-docs-and-tests/SKILL.md` (rubric: `.claude/skills/**/SKILL.md` → `workflow.md` OR `CLAUDE.md`; satisfied by workflow.md). `kit/tests/**`, `kit/FRICTION-LOG.md`, `kit/TODOS.md`, `BUILD-LOG.md`, and `specs/**` are all carve-outs. No missing-doc coverage findings.

Adequacy (Section B): workflow.md edits are substantive (skill-map row gains a "Tracker-only short-circuit" clause naming the helper + the exact tracker set + the `✓ audit short-circuited` message; Phase 5.8 prose names the Step 1 short-circuit). SKILL.md Step 1 substep 5 is a substantive new clause (preliminary-range computation, classifier invocation from `$GIT_ROOT_AUDIT`, exit-0/exit-1 branches, ordering-before-scaffold guarantee). Named-mechanism empirical verification (cheap): ran `audit-tracker-only.sh` against a temp two-commit fixture — tracker-only→exit 0, guide-doc change→exit 1, `kit/versioning.md` over-match guard→exit 1, unresolvable range→exit 1 (does NOT false short-circuit), no-arg→exit 64. All five documented exit-code claims match actual behavior. Cited paths verified to exist at HEAD: `kit/scripts/preship/audit-tracker-only.sh` (mode 644, matching the `34c7d55` mode-fix bypass). The workflow.md tracker list matches the script's `case` arms exactly.

Coherence (Section C): clean. No renamed/deleted files in range (`--diff-filter=DR` empty), so no stale-reference sweep triggered. workflow.md edits do not contradict OVERVIEW.md/FAQ.md.

Bypass trailers (Section D): 3 `Docs-Coverage-Bypass:` trailers harvested (664602f exact-anchor tightening, bcfd847 exit-1-on-unresolvable-range, 34c7d55 644 mode-fix). All three VERIFIED — each is a behavior-tightening / bug-fix / mode-fix on the helper whose documentation (workflow.md skill-map note + Phase 5.8 prose) already shipped paired in `411a3c1` within this same branch; no new doc surface. `grep 'audit-tracker-only'` confirms the helper is referenced only in workflow.md + check-docs-and-tests SKILL.md, matching the per-doc NOT-AFFECTED claims in the bypass rationales. No `CLAUDE-MD-Bypass:` trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode (`$GIT_ROOT` is a worktree of `/devshop`); Section E is project-mode only.

### Tests findings

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/util-audit-tracker-only.bats` (covers `kit/scripts/preship/audit-tracker-only.sh:62-65`)
**What**: The classifier's `case` statement has four distinct tracker arms, but several individual tracker paths in the D2 contract are never exercised by any test. Tested: `PLAN.md`, `kit/TODOS.md`, `kit/version`, `kit/notes/*`, `kit/FRICTION-LOG.md`. **Never tested**: `BUILD-LOG.md`, `PRODUCT-ROADMAP.md`, `DEPS-WATCH.md` (the top-level docs arm — only `PLAN.md` from this 5-token arm is exercised), `kit/ROADMAP.md`, and most notably `kit/docs/CHANGELOG.md` (its own dedicated `case` arm at line 64, never hit).
**Why**: A regression that dropped or mistyped any of these arms would silently re-introduce orphan `review.md` stubs for that merge type (e.g. a CHANGELOG-only or PRODUCT-ROADMAP-only doc merge would stop short-circuiting and scaffold an orphan again) and CI would stay green. The `kit/docs/CHANGELOG.md` arm is the highest-value gap: the spec (`spec.md § D2`, lines 25, 367-368) flags it as the single trickiest boundary — it is the ONLY `kit/docs/` path treated as a tracker ("NOT all of `kit/docs/`"). The suite tests the non-tracker side of that boundary (`kit/docs/guide/workflow.md` → exit 1) but never the tracker side (`kit/docs/CHANGELOG.md` → exit 0), so a regression collapsing or widening the CHANGELOG arm is invisible.
**Fix**: Add tracker-side assertions for the unexercised arms, e.g.:

```bash
@test "kit/docs/CHANGELOG.md is a tracker (NOT all of kit/docs/) → exit 0" {
  two_commit_diff kit/docs/CHANGELOG.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "remaining top-level + kit trackers → exit 0" {
  two_commit_diff BUILD-LOG.md PRODUCT-ROADMAP.md DEPS-WATCH.md kit/ROADMAP.md
  run_audit "HEAD~1..HEAD"
  assert_success
}
```

### [domain: tests] [section: C] [severity: low]

**File**: commit `411a3c1` (`feat(preship): classify tracker-only audit ranges to skip orphan stubs`)
**What**: Carries a `Tests-Coverage-Bypass:` trailer claiming the test file `kit/tests/util-audit-tracker-only.bats` IS staged and pairs `audit-tracker-only.sh`, but `check-tests-coverage-devshop.sh` hardcodes `TESTS_DIR=/devshop/kit/tests` and can't see worktree-only bats files (a hook worktree-awareness gap, not a missing test).
**Why / verdict**: **VERIFIED.** `git show --stat 411a3c1` confirms `util-audit-tracker-only.bats` (+81 lines) was co-committed with `audit-tracker-only.sh` (+62 lines) in the same commit — the trailer's factual claim is accurate. The pairing test exists, is present in the final tree, and all 12 of its cases pass (re-ran the suite: 46/46 green across both bats files). The bypass was load-bearing (the worktree-blind hook would otherwise have blocked the commit) and remains valid given the current diff — no escalation. The underlying hook worktree-awareness gap is already recorded in `kit/FRICTION-LOG.md` (eb023b9) and is out of scope for this tests audit.

---

**Summary: high=0 medium=1 low=1**

Coverage of the verdict logic is solid: exact exit-code assertions (`assert_success` / `assert_failure 1` / `assert_failure 64`), output-content checks (`--partial "short-circuit"`, `--partial "Usage:"`), a real failure-path test (unresolvable/rewritten-history SHA → exit 1, guards against false short-circuit), and four regression guards beyond the spec's 8-case matrix (prefix-boundary over-match on `kit/versioning.md` / `kit/ROADMAPER` / `kit/TODOS-archive.md`, and `kit/notes/**` dir-prefix). No weak assertions, no `.only` / `.skip`, no shape-only concerns (bash CLI helper, no UI surface). The SKILL.md tracker-only short-circuit change is covered by a new `util-check-docs-and-tests.bats` doc-contract test (helper name, message, no-scaffold ordering). The one real gap is per-arm coverage of the D2 tracker set — most acutely the `kit/docs/CHANGELOG.md` boundary the spec itself names as the trickiest.

## Audit 3: manual (2026-05-31)

<!-- audited-at: 716261fdde611644ae10c4cc1123f5f4653eb43f -->
<!-- range: cd030af..716261fdde611644ae10c4cc1123f5f4653eb43f -->

findings: high=0 medium=1 low=0

**Resolution note (orchestrator):** Audit 3 re-audited the Audit-2 fix range. Tests: clean (high=0 medium=0 low=0) — the Audit-2 medium coverage gap is closed (CHANGELOG.md + remaining D2 tracker arms now exercised). Docs: 1 medium — commit `716261f`'s subject + `Docs-Coverage-Bypass` trailer claim a SKILL.md indentation fix that did not land. **Root cause:** `lint-staged` runs `prettier --write` on `*.md`; prettier normalizes those numbered-list continuation lines to column-0, so the manual 3-space re-indent was reverted by the commit hook (verified: `prettier --write` on a 3-space copy reverts to column-0). Column-0 IS prettier-canonical — the Audit-2 low "indentation regression" finding was a false positive against prettier's own output (CLAUDE.md: "Prettier owns all formatting"). **Disposition:** do NOT re-attempt the re-indent (prettier owns it). The misleading per-commit subject/trailer is corrected at the squash boundary — the `/ak-merge-devshop` squash subject replaces `716261f`'s, the squash message accurately describes only the real change (bats coverage), and constituent `Docs-Coverage-Bypass` trailers are not carried forward into the squash. So the false claim never reaches `main`. Resolved-by-squash; no code/doc fix warranted.

### Docs findings

### [domain: docs] [section: D] [severity: medium]

**File**: commit `716261f` (`test(preship): cover remaining D2 tracker arms + fix SKILL.md indentation`)
**What**: The commit's `Docs-Coverage-Bypass:` trailer (and its subject "+ fix SKILL.md indentation") claims it "re-indent[ed] two dedented markdown continuation lines in check-docs-and-tests SKILL.md (Step 5 git-add block + cross-skill Notes) back into their list items." That edit was never made — `git show --stat 716261f` shows the commit changed ONLY `kit/tests/util-audit-tracker-only.bats` (+21 lines). `.claude/skills/devshop/check-docs-and-tests/SKILL.md` is untouched by the entire range.
**Why**: ESCALATE — a bypass rationale and commit subject asserting a documentation edit that does not exist. The dedented continuation lines flagged by the Audit-2 docs finding (`gates/audit-2-docs.md` § Section B) are still at column 0 at HEAD — SKILL.md:303-304 (`"$FEATURE_DIR/review.md" "$FEATURE_DIR/gates/audit-$AUDIT_N-docs.md"` / `"$FEATURE_DIR/gates/audit-$AUDIT_N-tests.md"`, the Step 5 substep-2 `git add` continuation) and SKILL.md:429 (`Audit N § Tests findings`, the cross-skill Notes continuation) both break out of their list item in a Markdown renderer. The Audit-2 low finding this commit purports to close remains open, and `git log` now misrepresents what shipped (a teammate scanning the subject two months out would believe the indentation was fixed). The bats half of the trailer is accurate and VERIFIED; only the SKILL.md half is false.
**Fix**: Either (a) actually apply the re-indent — restore SKILL.md:303-304 to 3-space list-item indentation and SKILL.md:429 to 2-space bullet-continuation indentation, matching their unchanged sibling lines — in a follow-up commit; or (b) if deferring, amend/replace the misleading subject + trailer so `git log` no longer claims a fix that did not land. Do not leave the subject asserting "fix SKILL.md indentation" while the file is unchanged.

---

Coverage (Section A): clean. The only source surface in range is `kit/tests/util-audit-tracker-only.bats` (a `kit/tests/**` carve-out — no firing). All other changed paths (`specs/ak-check-docs-orphan-stubs/review.md`, `specs/ak-check-docs-orphan-stubs/gates/audit-2-docs.md`, `specs/ak-check-docs-orphan-stubs/gates/audit-2-tests.md`) are `specs/**` carve-outs. No reference docs (`CLAUDE.md`, `kit/docs/OVERVIEW.md`, `kit/docs/FAQ.md`, `kit/docs/guide/*.md`) touched; the `REFERENCE_DOCS_TOUCHED` grep returned empty. No source change in range requires a doc edit per the devshop coverage rubric. No missing-doc coverage findings. (The SKILL.md edit the bypass trailer _claims_ was made would itself have been a `kit/docs/`/skill carve-out anyway — its absence is a Section D integrity problem, not a Section A coverage gap.)

Adequacy (Section B): no reference docs were touched in range, so there are no substantive-vs-stub doc edits to assess. N/A.

Coherence (Section C): clean. `--diff-filter=DR` is empty (no renamed/deleted files), so no stale-reference sweep triggered. No reference docs touched, so no cross-doc contradiction surface.

Bypass trailers (Section D): 1 `Docs-Coverage-Bypass:` trailer harvested (`716261f`). Split verdict — claim (1) "add bats coverage for the unexercised D2 tracker arms" is **VERIFIED** (the diff adds two `@test` blocks covering `kit/docs/CHANGELOG.md` and the BUILD-LOG/PRODUCT-ROADMAP/DEPS-WATCH/kit/ROADMAP arms, exactly matching the Audit-2 tests finding's suggested fix). Claim (2) "re-indent two dedented continuation lines in check-docs-and-tests SKILL.md" is **ESCALATE** — the edit is absent from the commit and from the whole range; escalated to the medium finding above. No `CLAUDE-MD-Bypass:` trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode (`$GIT_ROOT` is `/devshop`, this run is in a linked worktree of it); Section E is project-mode only.

### Tests findings

- (none)
