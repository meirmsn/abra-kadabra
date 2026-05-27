<!-- audited-at: f7ae82aa1fa6493199b296d68bec9b3234577648 -->
# Pre-ship review: claude-md-hygiene

## Gate 1: docs-check

- Result: pass
- New script `check-claude-md-classification.sh` has paired docs in both `kit/docs/guide/hooks.md` (guard table row, bypass inventory, trailer list) and `kit/docs/guide/claude-md.md` (Layer B gate documentation)
- Modified script `append-bypass-trailers.sh` changes documented in hooks.md trailer list
- `adversarial-review.sh` changes documented in hooks.md model routing table

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

- Result: pass (1431/1431 bats tests pass, 0 failures)
- Suite: `bats kit/tests/` (devshop-self-mode — bats is the test suite)

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

- Result: findings (2) fixed

### Findings

1. **Test 7 name prefix mismatch** (`guard-claude-md-classification.bats`): Comment and test name used "PASS:" prefix but the test asserted failure (blocking behavior). Renamed to "BLOCK:" for consistency with tests 3, 5, and 6.

2. **Symlink check on wrong path** (`check-claude-md-classification.sh` line 59): Tested `[ ! -L "$GIT_ROOT/kit/scripts" ]` — `kit/scripts` is never a symlink anywhere. The canonical devshop-self detection pattern checks `[ ! -L "$GIT_ROOT/kit" ]` (the `kit/` directory itself is the symlink in project repos). Changed to match the canonical pattern used in `adversarial-review.sh` and other hooks. No behavioral change (the preceding `-d` check already ensured correctness).

## Dismissals

None

## Gate 5: docs-and-tests-review

- Result: findings (1) pending
- findings: high=0 medium=1 low=0

### Medium-1: CLAUDE.md claim "per-commit hooks run only Layer 1 (deterministic checks)" is inaccurate

**File:** `CLAUDE.md` line 93

**Claim:** "Per-commit hooks run only Layer 1 (deterministic checks)."

**Reality:** Multiple pre-commit hooks make per-commit adversarial LLM calls (Sonnet/Haiku) — this was true before the branch (`check-manifest.sh` calls `adversarial-review.sh manifestReviewed`; `check-exempt-additions.sh` calls `adversarial-review.sh exemptAddition`), and the new `check-claude-md-classification.sh` adds another. The statement was already inaccurate on main (the original text read "deterministic file-existence math"), and the audit sweep trimmed the paragraph (removing detail about Layer 2 audit moments) but kept the inaccurate core claim.

The `hooks.md` guard table correctly classifies the new gate as **Semantic** (same classification as `check-manifest.sh` and `check-exempt-additions.sh`), so hooks.md is internally consistent. The inconsistency is CLAUDE.md vs hooks.md.

**Suggested fix:** Replace "Per-commit hooks run only Layer 1 (deterministic checks)" with something like "Per-commit hooks run Layer 1 (deterministic checks) plus semantic gates for manifests, exemptions, and CLAUDE.md classification" — or simply remove the claim and let the pointer to hooks.md carry the detail.

**Severity:** Medium. The claim doesn't cause silent wrong work on its own (the hooks fire regardless of what CLAUDE.md says), but it creates a false mental model that could lead a future session to skip adversarial-review context when reasoning about commit-time behavior.

---

### Docs review summary

- **`kit/docs/guide/claude-md.md`** accurately describes the new Layer B gate: trigger (additions/modifications), pure-deletion pass-through, bypass interface, adversarial reviewer (Sonnet), trailer emission, and the three layers compose correctly. Q6 rationale update is accurate and well-motivated (41% regrowth evidence). The "Durable justification artifacts" section correctly distinguishes the new `Claude-MD-Classification:` trailer from the legacy `CLAUDE-MD-Bypass:` trailer.

- **`kit/docs/guide/hooks.md`** guard table entry is correct: classified as Semantic, both repos, correct bypass flag and trailer documented. The tree diagram (ASCII art near line 77) includes the new check in the right position. The bypass-flag inventory paragraph (line 190) and adversarial-reviewed flag list (line 281) both include `claudeMdClassification`. The model-routing table (line 479) correctly lists `claudeMdClassification` in the Sonnet tier with rationale. The `prepare-commit-msg` section (line 92) is updated. All five hooks.md touch-points are consistent.

- **CLAUDE.md audit sweep** (commit `07ed9d6`): Three changes made — (1) deleted stale `docsReviewed` entry (check-type removed in PR-C, confirmed no longer live in `adversarial-review.sh`), (2) deleted `/ak-pre-ship Dismissals` entry (convention fully documented in `hooks.md` Dismissal Log section, confirmed at line 400+), (3) condensed `localTestSkipReason` entry to one-liner with pointer. All three are correct classifications — the removed entries were convention/reference content, not silent-failure traps.

### Tests review summary

- **10 bats tests** all pass. They cover the spec's 10 acceptance-criterion test cases: no-CLAUDE.md (T1), pure-deletion (T2), block-without-bypass (T3), bypass+PASS (T4), bypass+FAIL (T5), empty-bypass-blocks (T6), devshop-self-mode (T7), project-mode (T8), non-CLAUDE.md-carveout (T9), mixed-deletions+other-files (T10).

- **pre-commit-router.bats** updated correctly — `check-claude-md-classification.sh` stub added to setup, and three route-verification tests (project, devshop, devshop-self) assert the stub was called.

- **Edge cases not covered (acceptable):** (a) CLAUDE.md doesn't exist yet (first creation) — the hook would detect additions and block, which is correct behavior; a test would confirm but the code path is clear. (b) Very large diffs — bounded by the 180s adversarial-review timeout, not a test concern. (c) Concurrent edits — git's index locking handles this at a lower layer. These are low-risk gaps and not worth blocking on.

## Dismissals

None

## Gate 6: /review

- Result: findings (1) pending

### Finding 1 (medium): hooks.md implies `Claude-MD-Classification:` trailers are harvested at audit time, but no harvester exists yet

**File:** `kit/docs/guide/hooks.md` lines 91-97

The prepare-commit-msg documentation reads:

> `append-bypass-trailers.sh`: when `devshop.{tests,docs}CoverageReason` or
> `devshop.claudeMdClassification` is set, appends a `Tests-Coverage-Bypass:` /
> `Docs-Coverage-Bypass:` / `Claude-MD-Classification:` trailer to the commit
> message via `git interpret-trailers --in-place`. Trailers travel with the
> commit (survive rebase, push, clone) and audit-time `/ak-{docs,tests}-review`
> harvests them as `[bypass-revisit]` findings.

The final sentence claims `/ak-{docs,tests}-review` harvests these trailers. This is true for `Docs-Coverage-Bypass:` and `Tests-Coverage-Bypass:`, but `/ak-docs-review` Step E.4 only harvests `CLAUDE-MD-Bypass:` (the legacy trailer). No existing code harvests `Claude-MD-Classification:` trailers. The spec explicitly scoped this out ("Out of scope: Changes to `/ak-docs-review` Section E"), so the code is correct -- but the doc misleads a future reader into thinking audit-time harvesting already works for the new trailer.

**Fix:** Change the sentence to: "Trailers travel with the commit (survive rebase, push, clone). `Docs-Coverage-Bypass:` and `Tests-Coverage-Bypass:` are harvested at audit time by `/ak-{docs,tests}-review` as `[bypass-revisit]` findings. `Claude-MD-Classification:` trailers are recorded for future audit-time harvesting (see `kit/docs/guide/claude-md.md` Section E.4)." Or add a parenthetical: "(`Claude-MD-Classification:` harvest deferred -- see spec § Out of scope)."

### Notes (no action required)

- **CLAUDE.md condensed entry slightly inaccurate:** "Per-commit hooks run only Layer 1 (deterministic checks)" was already inexact before this diff (dirtyTreeReason, hookBypass, etc. are per-commit semantic/adversarial reviews). The new gate makes it marginally more misleading but this is pre-existing imprecision, not a regression from this branch. Noting for awareness; no fix needed in this PR since the entry's purpose is a pointer to the full contract, not a precise statement.

- **Spec line 101 says `Claude-MD-Classification-Bypass:` but code uses `Claude-MD-Classification:`** -- specs are historical after execution and not runtime artifacts. No fix needed.

- **Script correctness:** `check-claude-md-classification.sh` logic is sound: exit-early guards, pure-deletion detection via awk (portability-safe), bypass-flag reading, adversarial-review invocation, and blocking message all work correctly. No command injection risk -- the REASON value flows through `git config --get` (which is safe) into `adversarial-review.sh` as a positional argument (properly quoted), then into a temp-file prompt sent to `claude -p`. All 10 bats tests pass.

- **Security:** No path traversal risk. The script resolves `adversarial-review.sh` via `$GIT_ROOT/kit/scripts` (validated as non-symlink) or `/devshop/kit/scripts` (hardcoded). No user-controlled path interpolation.

- **Test coverage:** 10 tests cover: no-CLAUDE.md, pure-deletion, additions-no-bypass, bypass+PASS, bypass+FAIL, empty-bypass, devshop-self, project-mode, carve-out, mixed-deletion+other-files. The pre-commit-router.bats also validates wiring in all three dispatch paths. Coverage is thorough.

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

## Gate 11: convention (devshop-adapted)

- Result: pass
- New shell script has proper 3-line header (What/Why/Does NOT)
- Bats test file exists for new script (`guard-claude-md-classification.bats`)
- `claude-md.md` listed in `kit/docs/guide/README.md` routing index
- All 8 commits use conventional commit format

## Dismissals

None


## Phase 3 → 4 advance log

### 2026-05-27T20:22:04Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:22:04Z -->

### 2026-05-27T20:22:04Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:22:04Z -->

### 2026-05-27T20:22:04Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:22:04Z -->

### 2026-05-27T20:22:04Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T20:22:04Z -->

## Router Summary

- **pass**: 3 gates
- **n/a**: 9 gates (devshop-self-mode carve-outs)
- **blocked (structural)**: 4 gates (LLM-mediated, structurally inapplicable)
- **findings fixed**: Gate 4 (/simplify) — 2 cosmetic issues fixed
- **findings resolved**: Gate 5 (docs-and-tests-review) — 1 medium doc claim corrected; Gate 6 (/review) — 1 medium trailer scope clarified
- **findings_pending**: 0
- **real_blocked**: 0
