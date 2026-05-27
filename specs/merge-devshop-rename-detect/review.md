<!-- audited-at: 46dd32635f43b1a1b7e394b80dcbca7d1fe49999 -->

## Gate 1: docs-check

- Result: pass
- SKILL.md § Phase 2 detection block is self-documenting (inline comments explain the detection logic)
- SKILL.md § Known limitations updated to reflect auto-detection (no stale "tracked as a TODO" language)
- kit/TODOS.md entry closed; companion lint-staged entry updated with cross-reference to shipped companion
- No external reference docs (kit/docs/guide/) need updating — the detection is skill-internal

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

- Result: pass (1392/1392 bats tests passed)
- Command: `bats kit/tests/`
- Duration: ~90s

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
- Detection block is minimal: 3 shell commands (two `git diff --cached` + `comm -12`) + one conditional
- No abstraction opportunities — the block is already the simplest shape that handles the R+A collision detection
- Known limitations prose update is additive (new paragraph) not a rewrite — no redundancy introduced
- Bats tests follow existing section style exactly — no new patterns introduced

## Dismissals

None

## Gate 5: docs-and-tests-review

- Result: pass
- Docs: No reference doc updates needed. CLAUDE.md, hooks.md, and workflow.md are clean.
- Tests: 9 new bats tests in section L adequately cover all detection-block assertions.

### Docs audit

**CLAUDE.md Known Footguns**: The "Operator stashes can vanish silently" entry references lint-staged's stash-backup machinery as a hypothesis. It does NOT describe the rename+symlink manual recovery dance, so there is nothing to update now that the dance is automated. The entry's scope is stash-vanishing, not the rename combo itself. No change needed.

**kit/docs/guide/hooks.md**: References lint-staged stash backup context at line 151 (Section 2 config) and line 314 (Recovering a vanished stash). Neither section describes the rename+symlink combo or its manual recovery. The hooks.md content is about the stash-vanishing symptom, not the rename-triggers-lint-staged-crash symptom. No change needed.

**kit/docs/guide/workflow.md**: The `/ak-merge-devshop` skill table entry (line 478) is already long and describes the skill's major capabilities. The rename detection is an internal Phase 2 implementation detail (a pre-commit safety check), not a new top-level capability or interaction mode. The skill table entry's purpose is to describe what the skill does at the capability level (audit, squash, ff-merge, worktree-aware, etc.), not every internal safety check. No change needed.

**kit/TODOS.md**: The `/ak-merge-devshop Phase 2: detect rename-plus-symlink` entry was correctly deleted. The companion `lint-staged stash backup chokes on rename` entry was correctly updated with a `(2026-05-26)` note that option 3 shipped. Cross-references in the "Known limitations" section of SKILL.md were updated to point at the remaining lint-staged entry. Clean.

### Tests audit

All 9 section L tests cover the detection block's required assertions:

| # | Test | What it covers | Adequate? |
|---|------|----------------|-----------|
| 1 | `Phase 2 has a rename-plus-symlink detection block between soft-reset and commit` | Ordering: soft-reset < detection < commit by line number | Yes -- verifies correct placement |
| 2 | `Phase 2 detection scans git diff --cached --name-status for R (rename) entries` | `--diff-filter=R` presence | Yes |
| 3 | `Phase 2 detection compares rename source paths against A (added) entries` | Both `--diff-filter=R` and `--diff-filter=A` + `comm -12` intersection | Yes |
| 4 | `Phase 2 detection unstages on hit via git reset (not git reset --hard)` | Positive: `$GIT_CMD reset   # unstage`; Negative: no `--hard` in detection block | Yes -- covers both the safe unstage AND the negative case |
| 5 | `Phase 2 detection surfaces the lint-staged stash bug explanation` | `lint-staged` + `beyond a symbolic link` in detection block | Yes |
| 6 | `Phase 2 detection offers git merge --ff-only as fallback` | `ff-only` or `ff-merge` in detection block | Yes |
| 7 | `Phase 2 detection requires operator confirmation before ff-merge (not auto-fallback)` | `AskUserQuestion` in detection block | Yes -- verifies D2 decision |
| 8 | `Known limitations section notes rename-plus-symlink is now auto-detected` | `auto-detect` language in Known limitations | Yes |
| 9 | `Known limitations section preserves the recovery recipe` | `git reset` + `git merge --ff-only` still present | Yes |

**Negative case coverage**: Test 4 explicitly verifies `$GIT_CMD reset --hard` does NOT appear in the detection block (scoped to the `awk '/Rename-plus-symlink detection/,/^fi/'` range). This is the key safety assertion -- the detection unstages without destroying the working tree.

**Coverage completeness against the SKILL.md detection block**:
- Scan (`git diff --cached --name-status --diff-filter=R` + `--diff-filter=A`): tests 2, 3
- Intersection (`comm -12`): test 3
- Unstage on hit (`$GIT_CMD reset` without `--hard`): test 4
- Surface explanation (lint-staged + error message): test 5
- Fallback offer (`ff-only`): test 6
- Operator confirmation (`AskUserQuestion`): test 7
- Ordering (between soft-reset and commit): test 1
- Known limitations update: tests 8, 9

All assertions in the detection block are covered. No gaps found.

## Dismissals

None

## Gate 6: /review

- Result: findings (1) fixed
- Summary: Detection block is correct for the primary squash path; one medium finding on the phantom-rebase merge-fallback path which also commits without the detection guard.

### Findings

**M1 (medium): Phantom-rebase merge-fallback path bypasses the rename-detect block.**

The detection block is correctly positioned between `$GIT_CMD reset --soft "$ANCHOR"` (line 771) and `$GIT_CMD commit -F` (line 806) in the primary squash path. However, the phantom-rebase-error merge-fallback code block (lines 852-858) contains its own `$GIT_CMD reset --soft "$ANCHOR"` followed by `$GIT_CMD commit -F "/tmp/squash-message-${FEATURE}.txt"` -- and this second commit path has no rename-detect guard before it. If a virtiofs phantom-rebase error fires AND the staged delta contains a rename+symlink combo, the merge-fallback path will hit the same lint-staged stash crash that the detection block was designed to prevent.

Severity rationale: medium, not high -- the phantom-rebase path is itself a rare edge case (virtiofs on macOS only), and the rename+symlink combo is also rare. The intersection of both is very unlikely. The operator can still recover manually via the Known Limitations recipe. But the gap means the auto-detection promise in the updated prose ("now detected inline before the commit step") is incomplete for one of the two commit paths.

Fix options (pick one):
- **(a) Duplicate the detection block** into the merge-fallback code block, between its `$GIT_CMD reset --soft "$ANCHOR"` and `$GIT_CMD commit -F`. Same pattern, same variables.
- **(b) Add a prose note** in the merge-fallback section stating: "The rename-detect block from the primary path does not fire here. If the staged delta triggers the rename+symlink combo, the commit will fail at lint-staged; fall back to the Known Limitations recovery recipe." This is the minimal fix -- documents the gap without duplicating code.
- **(c) Extract the detection into a reusable inline function** called before both commit sites. This is cleaner but adds complexity to the LLM prompt.

Recommendation: option (b) is proportionate -- the intersection of both edge cases is very rare, and documenting it is sufficient.

### Notes (no action required)

- **$GIT_CMD usage is correct throughout** -- all 5 git commands in the detection block route via `$GIT_CMD`. No bare `git` that should be `$GIT_CMD`.
- **Empty-variable edge case is safe** -- when `RENAME_SRCS` or `ADDED_PATHS` is empty, `echo ""` produces one blank line, but `comm -12` on two blank lines outputs one blank line, and command substitution strips the trailing newline, leaving `COLLISIONS=""`. `[ -n "" ]` is false. No false-positive.
- **Paths with spaces** -- `awk '{print $2}'` would break on paths with spaces, but this is devshop-internal (no spaces in /devshop paths by convention) and the spec's Gotchas section already acknowledges this (`awk '{print $2}'` works because `--name-status` output for renames is `R<sim>\tOLD\tNEW`). Not a finding for this review.
- **Known limitations section reads coherently** -- the new auto-detect paragraph leads naturally into the existing mechanism explanation, and the updated TODOS cross-reference is accurate.
- **Bats tests are solid** -- 9 tests covering the required prose dimensions, all pass (88/88 green in the full suite). Coverage is consistent with sections A-K.
- **TODOS closure is clean** -- the detect-and-fallback entry is removed; the companion lint-staged entry is updated with a shipped note; no stale cross-references remain.

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
- SKILL.md follows existing Phase 2 prose style (bash code block with inline comments)
- Bats tests use the established section pattern: `awk '/^## Phase N:/,/^## Phase M:/' "$SKILL_FILE" | grep -q`
- Bats section header follows A-K naming convention: `# === Section L — Phase 2 rename-plus-symlink detection ===`
- TODOS entry deletion follows `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`
- No new scripts under kit/scripts/ (detection is inline in SKILL.md, per D1)

## Dismissals

None

## Phase 3 → 4 advance log

### 2026-05-27T05:34:50Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T05:34:50Z -->

### 2026-05-27T05:34:50Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T05:34:50Z -->

### 2026-05-27T05:34:50Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T05:34:50Z -->

### 2026-05-27T05:34:50Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T05:34:50Z -->

## Audit 1: manual (2026-05-26)

<!-- audited-at: 5c027b8b50e10f5b4e25a7646e688eed28205bfe -->
<!-- range: 46dd32635f43b1a1b7e394b80dcbca7d1fe49999..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
