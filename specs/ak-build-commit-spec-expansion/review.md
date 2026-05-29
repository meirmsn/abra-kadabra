# Review — ak-build-commit-spec-expansion

<!-- audited-at: c64de2c7f698221fb93a561a764716f1e0500c60 -->

## Router Summary

- Gates dispatched: 6 (docs-check, fast-job-local, simplify, docs-and-tests-review, review, convention)
- Carve-outs: 13 (9 `n/a` non-LLM-mediated, 4 structural `blocked` LLM-mediated)
- Outcome: passed (non-blocking). findings_pending=0, real_blocked=0, structural_blocked=4, n/a=9.
- Dismissals: 1 total — Gate 2d (pre-existing `structural-invariants.bats` reconcile-task-commits wiring failure, routed to kit/TODOS.md).

---

## Gate 1: docs-check

**Verdict: pass.**

The diff is a SKILL.md-internal mechanics change (new Phase 1.1 commit step +
resume-check reads tightened to committed state), plus bats assertions and a
`kit/TODOS.md` routing entry. Verified that no reference doc beyond SKILL.md
itself describes Phase 1's artifacts/commits at a grain that the change makes
stale.

### What was checked

Grepped `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`, and `CLAUDE.md` for
references to Phase 1 / "expand spec" / spec.md commits / "Task order" /
"skeleton commit" / Phase 0.3. Inspected every hit that touches the /ak-build
spec pipeline:

- **`kit/docs/guide/workflow.md`** — the canonical pipeline description.
  - ASCII diagram Phase 0 box (lines 58-59) and Phase 1 box (lines 64-68)
    describe Phase 1 as "expands in place → full spec … flips PLAN.md row
    Planned → Active." It does NOT enumerate per-phase commits. The new Phase
    1.1 commit step is below this grain; the box stays accurate.
  - Prose (lines 210-221): "reads the Phase 0 skeleton and expands it in place
    into a full spec … The `## Task order` section is the discriminator the
    resume check uses to tell 'skeleton' from 'complete spec.'" Still accurate
    — `## Task order` remains the discriminator. The change only moves *where*
    the resume check reads it from (committed `spec.md` via `git show HEAD:`
    rather than the working tree); workflow.md never specified the read source,
    so no sentence is falsified. No edit required.
  - Other Phase-1 hits (lines 487-488, the `/ak-merge-devshop` /
    `/ak-sync-from-devshop` rows) refer to those skills' own internal "Phase 1"
    numbering, unrelated to /ak-build's spec phase.

- **`kit/docs/OVERVIEW.md`** line 278 — describes `spec.md` as "seeded by
  /ak-build Phase 0 as a Decisions skeleton, expanded by /ak-spec into the full
  spec." High-grain artifact description with no commit-granularity claim. Not
  made inaccurate by adding a Phase 1.1 commit. No edit required.

- **`CLAUDE.md`** — no pointer to Phase 1's commit behavior or the resume
  discriminator's read source. The closest reference ("Pipeline path (Phase 4.1
  → Phase 6 Part D verification)") is unrelated. No edit required.

- **`kit/docs/guide/hooks.md`, `conventions.md`, `architecture.md`,
  `ops.md`** — Phase-1 hits all refer to other skills' phase numbering or to
  CI slow-job phases, none to /ak-build's spec-commit behavior. Untouched by
  this change.

### Self-documentation within the diff

The SKILL.md change is self-consistent: the new `### 1.1: Commit the expanded
spec` subsection, the Phase-exit artifact registry row 1 (Producer flipped to
"Phase 1.1 (commit step)", check shape `git show HEAD:… | grep`), resume rungs
4/5, and the discriminator paragraph (lines 325-328) were all updated together,
so the SKILL.md cross-references stay coherent.

### Tracker entry

`kit/TODOS.md` gained one routing entry (pre-existing `structural-invariants.bats`
wiring failure surfaced during the full-sweep) — correct TODO-protocol routing,
not a doc-coverage gap. The TODOS entry this PR closes ("/ak-build Phase 1
doesn't commit the expanded spec.md") is slated for removal in Phase 4.0
bookkeeping, per gate instructions — not flagged here.

## Dismissals

None.

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

- Result: pass-with-note

Devshop test surface is bats (kit/tests/), not turbo. Ran:
- Targeted `util-ak-build-skill.bats`: 46/46 pass (incl. new Section G: G1–G4).
- Full sweep `kit/tests/`: 1561/1562 pass. The single failure is
  `structural-invariants.bats` "wiring: every non-exempt kit script is wired"
  flagging `reconcile-task-commits.sh` — **pre-existing on `main`** (introduced
  by `ca4bc76`, confirmed by running the test against origin/main HEAD 48eed4a),
  out of this change's scope (diff touches only SKILL.md + util-ak-build-skill.bats).
  Routed to `kit/TODOS.md` in this branch per the TODO protocol.

## Dismissals

- `structural-invariants.bats` reconcile-task-commits wiring failure — rationale: pre-existing on main, unrelated to this diff, routed to kit/TODOS.md for a separate fix.

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

**Verdict: pass.** No genuine simplifications found in the branch diff
(`.claude/skills/devshop/build/SKILL.md` Phase 1.1 shell snippet + prose,
`kit/tests/util-ak-build-skill.bats` Section G). Quality-only review across
reuse / simplification / efficiency / altitude. Suite green (46/46) at review
time.

### Shell snippet (Phase 1.1) — simplest correct form

```bash
git add "$FEATURE_DIR/spec.md"
if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then
  git commit -m "docs($FEATURE): expand spec (Phase 1)"
fi
```

- **Canonical idempotence pattern.** Stage first, then `git diff --cached
  --quiet` to detect whether staging produced a delta. This is the simplest
  correct guard. The obvious "shorter" alternative — `git commit ... || true` —
  is rejected correctly: it would swallow *real* commit errors, not just the
  "nothing to commit" no-op. The explicit guard is right, not over-engineered.
- **The `-- "$FEATURE_DIR/spec.md"` pathspec on the diff is load-bearing, not
  redundant.** Scoping the guard to the same file keeps it from sweeping any
  unrelated staged change a prior phase might have left in the index. Defensive-
  correct; keep it.
- **Mirrors the Phase 0.3 skeleton-commit precedent** (`chore($FEATURE): Phase 0
  spec skeleton`) — reuse, not reinvention.
- The 3-line idempotence comment is dense but every clause is load-bearing
  (explains *why* the guard exists for resume re-run safety). Valuable in a
  SKILL.md an LLM orchestrator reads top-to-bottom; not a trim target.

### bats Section G (G1–G4) — non-redundant, minimal

- Each assertion guards a **distinct surface**: G1 subsection header exists; G2
  commit-step content + no-push (scoped via `awk '/^## Phase 1: Spec/,/^## Phase
  2:/'`); G3 registry row; G4 resume rungs (scoped via `awk '/^### Resume
  check/,/^## Phase 0/'`, the same boundary Section F uses).
- **No overlap with existing assertions.** Section F guards rung 2 / reconcile —
  a different concern; no `committed` / `git show HEAD` / `## Task order`
  assertions pre-existed Section G.
- Reuses the established file patterns exactly: `awk ... > /tmp/...txt` region
  scoping, `grep -qF` for literal strings, `grep -c ... -ge N` for count. The
  G2 negative assertion (`! grep -q 'git push'`) is meaningful — the awk region
  boundary is verified correct (Phase 1 region contains no `git push`).

### Prose edits — tight

- Registry row 1, rungs 4/5, and the discriminator-paragraph amendment are
  minimal, accurate, and consistently phrased against committed state. The
  one-clause append to the discriminator paragraph (lines ~325–327) is exactly
  the light touch the spec prescribed, not a rewrite.
- The Phase 1.1 prose carries a mild intro/outro overlap on the resume-check
  rationale (the commit "so Step 0's resume check sees a complete spec" appears
  before the code block and again after as "so a session crash + restart finds
  the full spec"). Judged **acceptable-as-is, not a finding**: the text was
  approved verbatim at spec time (Edit region A), the two mentions anchor
  distinct decisions (commit-now vs no-push-yet), and trimming would diverge
  from approved spec scope. The repetition reinforces a load-bearing crash-
  safety rationale in a doc LLMs read sequentially.

## Dismissals

None.

## Gate 5: docs-and-tests-review

- Result: findings (0 high, 0 medium, 1 low) — see `## Audit 1` section below for the full report (committed at 059d2ba). Low finding (SKILL.md preamble committed-state clause) fixed in commit 26233da.

## Dismissals

None

## Gate 6: /review

**Diff reviewed:** `git diff origin/main..HEAD` — `.claude/skills/devshop/build/SKILL.md` (Phase 1.1 commit step + registry row 1 + resume rungs 4/5 + discriminator paragraph), `kit/tests/util-ak-build-skill.bats` (Section G), `kit/TODOS.md` (pre-existing-failure note). Devshop-self-mode: no app code, so the review targets the correctness of the instructional shell logic the orchestrator follows at runtime.

**Verdict: pass.** No findings. The shell logic is idempotent, the committed-state reads degrade safely on every edge case I exercised, the cross-region wording is internally consistent, and all 46 bats (incl. 4 new G-section) pass.

### What I verified (and why each is safe)

1. **Phase 1.1 commit snippet — idempotent + safe on first-run AND resume.** `git add "$FEATURE_DIR/spec.md"` then `if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then git commit ...; fi`.
   - First run: spec expanded → staged diff is non-empty → commits. Correct.
   - Resume re-entry where spec is already committed at HEAD: re-running the spec agent reproduces identical content → `git add` stages nothing new → `git diff --cached --quiet` is true → guard skips the commit (no "nothing to commit" error). Idempotent as designed (D4). Correct.
   - `$FEATURE_DIR` unset: not a real risk here — it is set once at Step 0 (line 252, `FEATURE_DIR="specs/$FEATURE"`) and used unquoted-safely throughout; the snippet quotes it (`"$FEATURE_DIR/spec.md"`), matching the existing Phase 0.3 precedent (line 665).
   - Wrong-branch / pre-commit interaction: the bare `git commit` relies on the orchestrator already being on the feature branch — identical to the Phase 0.3 skeleton commit (line 666), which has shipped without issue. A `docs()` commit of a single `spec.md` file clears the clean-tree / docs-coverage / mixed-commit guards the same way the Phase 0.3 `chore()` commit of the same single file does. The spec's Gotchas address this with the Phase 0.3 precedent; reasoning is sound.

2. **Committed-state reads (registry row 1 + rungs 4/5) — `git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'`.** Exercised the three states in a throwaway repo:
   - **Uncommitted (working-tree only) / unborn HEAD:** `git show HEAD:...` exits 128 ("invalid object name 'HEAD'" / path-not-in-HEAD), but piped into `grep -q` the pipeline's exit status is grep's (1) → rung evaluates false. Both rungs 4 and 5 fall through to **rung 6 (start from Phase 0)**, which is idempotent (re-runs the decisions preview + re-commits the skeleton). Safe — no error surfaced, correct routing.
   - **Crash-before-1.1-commit (HEAD = skeleton, working tree = expansion with `## Task order`):** rung 4 false (HEAD lacks the header), rung 5 true (skeleton committed, lacks header) → re-run Phase 1; the spec agent reads the working-tree file, preserves Decisions, re-expands, and 1.1 commits. This matches rung 5's "(or crashed before its 1.1 commit)" comment exactly. Verified empirically. Correct.
   - **Committed + expanded:** rung 4 true → skip to Phase 2. Correct.

3. **Registry row 0 vs row 1 read-state asymmetry is intentional, not a defect.** Row 0 (Phase 0 skeleton) still checks "file exists" (working tree); row 1 now checks committed state. A working-tree-only skeleton that never committed is caught by rung 6 (restart Phase 0, idempotent), so no scenario mis-routes.

4. **Cross-region consistency.** The discriminator paragraph (lines 325–330) was reworded to read against committed state (`git show HEAD:…`), matching rungs 4/5. The rung-5 producer attribution flipped to "Phase 0.3 committed the skeleton" — accurate (line 666). No dangling reference to the old working-tree `grep -q` shape remains.

5. **Pipe-escaping + bats.** Registry row 1 escapes the pipe as `\|` inside the markdown cell (line 146); G3's regex matches the escaped/rendered form. G4 asserts `committed at HEAD` count ≥ 2 (actual: 2) and the rung-4 inline `git show HEAD:` pipe. G2 scopes to the Phase 1 region and asserts the canonical message, the `git diff --cached --quiet` guard, and `! grep -q 'git push'`. All 46 tests pass (`kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-build-skill.bats`).

### Notes (non-blocking, no action required)

- The `kit/TODOS.md` entry correctly files the pre-existing `structural-invariants.bats:267` failure (`reconcile-task-commits.sh` not wired to a hook) as out-of-scope for this PR — it is unrelated to the SKILL.md/bats edits and predates this branch. Routing is per the TODO Protocol (devshop, fix-soon → `kit/TODOS.md`). No action in this gate.

## Dismissals

None.

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

- Result: findings (1) fixed

SKILL.md frontmatter intact; no new scripts/guide-docs; Section G bats coverage
(4 tests) green (46/46); all cross-refs resolve; prose follows house style; all
commit subjects conventional-commit, ≤72 chars, observable-change.

Finding (FIXED): `kit/TODOS.md` still carried the open entry "`/ak-build` Phase 1
doesn't commit the expanded `spec.md`" — the exact bug this branch fixes —
violating CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships". Closed
in commit `c64de2c`: deleted the TODOS entry (+ its trailing metadata tag) and
removed the `ak-build-commit-spec-expansion` PLAN row. No other cross-references
to the entry exist (verified via repo-wide grep).

## Dismissals

None

## Phase 3 → 4 advance log

### 2026-05-29T09:21:30Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — no auth boundary, no RLS, no third-party APIs — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:21:30Z -->

### 2026-05-29T09:21:30Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — no UI surface — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:21:30Z -->

### 2026-05-29T09:21:30Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — no UI surface; bats invariants are the test surface (Gate 2d) — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:21:30Z -->

### 2026-05-29T09:21:30Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — no perf surface — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:21:30Z -->

## Audit 1: pre-polish (2026-05-29)

<!-- audited-at: 7011a1aa1debeef94cb7f54c32996539b0ad319f -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] .claude/skills/devshop/build/SKILL.md:14 — Skill-description header still says "a spec.md lacking `## Task order` signals Phase 0 finished but Phase 1 didn't" without noting the signal is now read from committed state. Accurate as a semantic statement (the discriminator is unchanged), so not a correctness defect — but a one-clause "(read from the committed spec.md)" would keep the header consistent with the lines 325–330 discriminator paragraph that WAS updated. Cosmetic; optional.

Coverage assessment (no high/medium findings):

- The SKILL.md change is internally coherent. All three edit regions landed as the spec specified: Phase 1.1 commit subsection (line 783), registry row 1 reworded to committed state with pipe-escaped `git show HEAD:` (line 146, Producer flipped to "Phase 1.1 (commit step)"), and resume rungs 4+5 reworded to "committed at HEAD" (lines 306–307). The lines 325–330 discriminator paragraph was correctly amended to read against committed state.
- No stale cross-reference left behind. Checked the only sibling file, devshop-mode.md: its resume-rung adaptation (lines 43–45) delegates rungs 2–6 to project mode verbatim ("identical to project mode — no adaptation needed"), so the SKILL.md reword propagates automatically — no duplicate working-tree wording to fix. devshop-mode.md lines 457–459 ("Critical state survives in files: spec.md … git commits") remains accurate and is in fact reinforced by the change. The spec's Phase 1 verification finding (no other ak-build file references the Phase 1 commit / registry / rungs) is confirmed.
- The new Phase 1.1 push note (line 801) and the pre-existing Phase 0.3 push note (line 669) are consistent — both correctly say the feature-branch push stays in Phase 4 / 4.5. No conflicting ownership of push.
- No `**Existing projects:**` propagation block required: the diff touches `.claude/skills/**`, not template/kit-scripts/hooks/devcontainer/manifest — correctly noted in spec § Rollout.
- TODOS.md entry added (kit/TODOS.md) correctly routes the pre-existing structural-invariants.bats failure to the devshop tactical backlog with a precise fix recipe — good doc hygiene, not in this change's scope.

### Tests findings

- (none high/medium)

Coverage assessment:

- Section G (G1–G4) added to kit/tests/util-ak-build-skill.bats is adequate coverage for the SKILL.md behavior change. The change is LLM-orchestrator prose, so the only meaningful test surface is structural assertions against the SKILL.md text — exactly what Sections A–F already do, and what Section G extends.
- The assertions pin the ACTUAL new text, not tautologies. Verified each against the pre-change strings:
  - G1 pins `^### 1.1: Commit the expanded spec` — the new subsection header.
  - G2 scopes to the Phase-1 region via `awk '/^## Phase 1: Spec/,/^## Phase 2:/'` and asserts the canonical `git add "$FEATURE_DIR/spec.md"`, the `git diff --cached --quiet` idempotence guard, and the `docs($FEATURE): expand spec (Phase 1)` message all appear, plus a meaningful NEGATIVE assert that no `git push` exists in the region (confirmed the region genuinely contains zero `git push` — so the negative assert can actually fail if a push leaks in).
  - G3 (`grep -qE '\| 1 \|.*committed.*## Task order.*git show HEAD:'`) genuinely detects the change: confirmed it does NOT match the old row (`contains '## Task order' … grep -q`), so it is a real regression guard, not a tautology.
  - G4 scopes to the resume region with the same `awk '/^### Resume check/,/^## Phase 0/'` boundary Section F uses, requires `committed at HEAD` count ≥ 2 (confirmed exactly 2 in the region; old rungs had 0) AND a literal `git show HEAD:$FEATURE_DIR/spec.md | grep -q`. Both rungs are pinned.
- All 46 tests in util-ak-build-skill.bats pass (including 43–46 = G1–G4). The registry-row reword did not break any existing Section A–F assertion.
- Nothing material untested. The four observable units of the change (commit step present; idempotence guard present; registry row 1 committed-state; resume rungs 4/5 committed-state) each map to a dedicated assertion. The "no push in Phase 1" invariant — the one behavior most likely to silently regress — is explicitly guarded by G2's negative assert.
- One known pre-existing full-sweep failure (structural-invariants.bats reconcile-task-commits wiring) is already routed to kit/TODOS.md and is out of scope for this change — not a finding.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-29)

<!-- audited-at: 5cd3cb4fc58c629efedaf0e4fc6dcc8c3714f494 -->
<!-- range: 48eed4abce1e38952ba278e8a4cbcb45fc5339fd..5cd3cb4fc58c629efedaf0e4fc6dcc8c3714f494 -->

findings: high=0 medium=0 low=1

Audit range covers the 6 commits added since Audit 1's stamp (7011a1a): the
Phase 1.1 commit step + Step 0 committed-state resume tightening (957447c,
7011a1a, the 26233da preamble committed-state clause), Gate 5 Audit 1 record
(059d2ba), tracker closure (c64de2c), Phase 3 review artifacts (9eca720), and
the BUILD-LOG entry (5cd3cb4). The only production file in the whole branch is
`.claude/skills/devshop/build/SKILL.md`; tests are `kit/tests/util-ak-build-skill.bats`.

### Docs findings

- [low] kit/docs/guide/workflow.md:218 — The SKILL.md resume-discriminator change (now reads committed state via `git show HEAD:…`; Phase 1.1 commits the expansion) has no paired workflow.md edit, but the existing Phase 1 prose ("the `## Task order` section is the discriminator the resume check uses to tell skeleton from complete spec") is implementation-agnostic and stays accurate — it never asserted WHERE the discriminator is read from. No operator-facing flow changed; the commit step is an internal robustness improvement. Recording informationally, not a coverage gap. Optional precision: append "(read from the committed spec.md on resume)" to that line. Not load-bearing.

Coherence (section C): verified — no renamed/deleted files in range; no stale path/section references introduced. The SKILL.md updated row 1, resume rungs 4/5, and the discriminator-explainer paragraph consistently within one file (working-tree `grep` → `git show HEAD:` in all three call sites), so the file is internally coherent. Tracker hygiene correct: the TODOS.md entry this feature implements ("`/ak-build` Phase 1 doesn't commit the expanded spec.md") was deleted in the same range (c64de2c) per CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships"; the new structural-invariants.bats TODOS entry is correctly routed out-of-scope, not stale.

### Tests findings

- (none)

Coverage (section A): `.claude/skills/devshop/build/SKILL.md` is covered by `util-ak-build-skill.bats` Section G (4 new tests G1–G4), satisfying the devshop rubric. Each piece of the diff has a matching guard: G1 (Phase 1.1 subsection exists), G2 (commit step: `git add`, `git diff --cached --quiet` idempotence guard, canonical message, region-scoped no-`git push` negative assert), G3 (registry row 1 committed-state), G4 (resume rungs 4/5 committed-state, ≥2 `committed at HEAD` + literal `git show HEAD:` discriminator). Quality (section B): assertions pin actual new text (not tautologies); G2/G4 region-scope via `awk` boundaries to prevent false passes; Section G header carries a rationale comment naming each guarded regression. Verified all four assertions pass against the live SKILL.md, and ran the full suite in the worktree: 46/46 ok (G1–G4 = tests 43–46). No `test.skip`/`.only` in the diff. The one known pre-existing full-sweep failure (structural-invariants.bats reconcile-task-commits wiring) is routed to kit/TODOS.md and out of scope — not a finding.

### Bypass trailer audit

- (none) — no Docs-Coverage-Bypass or Tests-Coverage-Bypass trailers in range.
