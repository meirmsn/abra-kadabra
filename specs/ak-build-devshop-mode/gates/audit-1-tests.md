# Tests Review — Audit 1

Range: `origin/main..HEAD` (2 commits: `f23bb1b`, `4e7354f`)
Feature: `ak-build-devshop-mode`

## Section A — Coverage of new behavior

### [domain: tests] [section: A] [severity: medium]

**File**: `.claude/skills/devshop/build/devshop-mode.md` (new file, 375 lines)
**What**: New skill sub-file `devshop-mode.md` has no corresponding bats test coverage. The existing `util-ak-build-skill.bats` covers SKILL.md content but has not been extended to validate the devshop-mode sub-file's key structural invariants: gate applicability matrix (6 dispatched / 13 pre-composed), Phase 4.5 section, resume-check adaptations, tracker hierarchy, and structural carve-out advance-log handling.
**Why**: Content-validation tests are the devshop's defense against silent prose drift in pure-LLM-prompt skill files. Without tests pinning the gate count, disposition labels, and phase structure, a future edit could silently break the orchestrator's devshop-mode dispatch (e.g., adding a gate to the matrix without updating the "6 dispatched" headline, or removing the Phase 4.5 section that the resume-check references).
**Fix**: Extend `util-ak-build-skill.bats` (or create a new `util-ak-build-devshop-mode.bats`) with content-validation tests covering at minimum: (1) `devshop-mode.md` file existence, (2) gate applicability matrix row count and dispatch/carve-out counts, (3) Phase 4.5 section header, (4) devshop-mode tracker hierarchy shape, (5) mode-detection bash block in SKILL.md contains `MODE="devshop"`. Pattern: follow `util-ak-build-skill.bats § Section D` which pins Phase 4.0 structural invariants via `grep -qE` on distinctive phrases.

### [domain: tests] [section: A] [severity: medium]

**File**: `.claude/skills/devshop/build/SKILL.md:88-103` (mode detection block)
**What**: The new mode-detection bash block in SKILL.md (`GIT_ROOT=$(git rev-parse --show-toplevel)` / `MODE="devshop"` / `MODE="project"`) is not covered by any content-validation or behavioral test. The existing `util-ak-build-skill.bats § Section C` demonstrates the pattern — it extracts and executes the branch-prefix heuristic bash block from SKILL.md against fixture repos.
**Why**: A future edit could break the mode-detection conditional (e.g., changing the path comparison from `/devshop` to something else) with no test catching it. The mode detection is the single branch point that routes the entire pipeline.
**Fix**: Add a content-validation test asserting the mode-detection block's distinctive phrases (`MODE="devshop"`, `MODE="project"`, `GIT_ROOT`) are present in SKILL.md. Optionally, add a behavioral test (Section C style) that extracts the block and runs it against a fixture repo whose `git rev-parse --show-toplevel` returns `/devshop` vs `/workspace`.

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/tests/util-build-preship-gate-consistency.bats` (not updated)
**What**: The cross-skill invariant test between `build/SKILL.md` and `pre-ship/SKILL.md` validates that project-mode Phase 3 gate references exist in the pre-ship canonical table. The new devshop-mode gate applicability matrix in `devshop-mode.md` introduces a parallel gate roster that is not validated against the same canonical table. A gate name typo or a gate added to pre-ship but not enumerated in devshop-mode's matrix would go undetected.
**Why**: The same class of silent-orchestrator-break that `util-build-preship-gate-consistency.bats` was created to prevent (build references a gate name that doesn't exist in pre-ship) applies equally to the devshop-mode matrix.
**Fix**: Extend `util-build-preship-gate-consistency.bats` with a test that extracts gate names from `devshop-mode.md`'s applicability matrix and verifies each exists in `pre-ship/SKILL.md § Gates` canonical table. Pattern: reuse the existing `canonical_gate_names()` helper + a new `devshop_mode_gate_names()` extractor.

## Section B — Test quality

No new test code was introduced in this diff. Nothing to evaluate.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the commit range.

## Summary

| Severity | Count |
|----------|-------|
| high     | 0     |
| medium   | 3     |
| low      | 0     |

All three medium findings are coverage gaps for the new devshop-mode skill sub-file and its structural invariants. No test code was introduced alongside the 500+ lines of new skill prose, which is the primary gap. The existing test files (`util-ak-build-skill.bats`, `util-ak-build-phase3-decomposition.bats`, `util-build-preship-gate-consistency.bats`) demonstrate the exact patterns needed — the work is extension, not invention.
