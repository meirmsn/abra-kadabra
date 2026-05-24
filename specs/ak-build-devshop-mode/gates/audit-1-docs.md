# Audit 1 — Docs findings

<!-- audited-at: 4e7354f -->

Range: `origin/main..HEAD` (2 commits)

## Section A — Coverage

No coverage findings. The diff touches `.claude/skills/devshop/build/SKILL.md` (skill file) and creates `.claude/skills/devshop/build/devshop-mode.md` (new sub-file). Per the devshop rubric, `.claude/skills/**/SKILL.md` requires a matching edit to `kit/docs/guide/workflow.md` OR `CLAUDE.md`. Both were touched: `workflow.md` gains a devshop-feature variant row + updated `/ak-build` description, and `CLAUDE.md` updates the devshop shipping flow step 2. Coverage satisfied.

No propagation-relevant surfaces touched (no `template/`, `kit/scripts/`, `kit/hooks/`, `.devcontainer/`, `kit/manifest.txt`), so the Existing-Project Migration Block convention does not fire.

## Section B — Adequacy

### [domain: docs] [section: B] [severity: medium]
**File**: `kit/docs/guide/workflow.md:362`
**What**: Stale gate count — "7 of 19 gates" but the authoritative matrix says 6 dispatched
**Why**: The fix commit `4e7354f` corrected the count in `devshop-mode.md` (7→6 dispatched) and the SKILL.md pipeline shape, but missed updating this sentence in `workflow.md`. A reader of workflow.md gets a wrong count.
**Fix**: Change "reduced gate set (7 of 19 gates)" to "reduced gate set (6 of 19 gates)" at line 362.

### [domain: docs] [section: B] [severity: medium]
**File**: `kit/docs/guide/workflow.md:362,464`
**What**: Path reference `build/devshop-mode.md` is ambiguous/dangling from workflow.md's location
**Why**: `workflow.md` lives at `kit/docs/guide/workflow.md`. The reference `build/devshop-mode.md` would resolve to `kit/docs/guide/build/devshop-mode.md` which does not exist. The actual file is `.claude/skills/devshop/build/devshop-mode.md`. A reader following the path finds nothing.
**Fix**: Change to `.claude/skills/devshop/build/devshop-mode.md` (repo-root-relative) at both lines 362 and 464.

## Section C — Cross-doc coherence

### [domain: docs] [section: C] [severity: medium]
**File**: `.claude/skills/devshop/build/SKILL.md:622` vs `.claude/skills/devshop/build/devshop-mode.md:15,321`
**What**: Phase numbering mismatch — SKILL.md calls the staleness check "0.6" while devshop-mode.md calls it "Phase 0.5"
**Why**: SKILL.md has `### 0.6: Staleness check (both modes)` (line 622) and explicitly references `devshop-mode.md § Phase 0.5: Staleness check` (line 625). The cross-reference lands correctly but the number disagrees. The pipeline shape diagram in devshop-mode.md (line 15) also says `Phase 0.5`. A reader sees two different numbers for the same step.
**Fix**: Align to a single number. Either rename SKILL.md's `### 0.6` to `### 0.5` (shifting the current `### 0.5: Remote-control nudge` to a different number), or rename devshop-mode.md's `## Phase 0.5` to `## Phase 0.6` and update the pipeline shape diagram. The latter is less disruptive since SKILL.md already has a `### 0.5: Remote-control nudge` at line 598.

### [domain: docs] [section: C] [severity: low]
**File**: `.claude/skills/devshop/build/devshop-mode.md:42`
**What**: Resume-check rung reference says "Rungs 3–7" but SKILL.md uses "rungs 2–6"
**Why**: devshop-mode.md line 42 says "Rungs 3–7 (tasks.md partial, spec.md with/without `## Task order`, fresh start) are identical to project mode". SKILL.md labels these shared rungs as 2–6 (lines 196–200). The off-by-one likely comes from the devshop-specific rungs (1d, 2d) being counted as occupying slots 1–2, pushing the shared rungs to 3–7. But the canonical numbering in SKILL.md is 2–6.
**Fix**: Change "Rungs 3–7" to "Rungs 2–6" in devshop-mode.md line 42, or add a parenthetical noting the mapping.

## Section D — Bypass trailer audit

No Docs-Coverage-Bypass trailers in range.

## Section E — CLAUDE.md hygiene

Skipped (devshop mode — Section E is project mode only per the skill contract).
