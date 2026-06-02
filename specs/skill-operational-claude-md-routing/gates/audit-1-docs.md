### [domain: docs] [section: A] [severity: medium]

**File**: (commit bodies) c90bd3d, 21588ff:Existing-projects block
**What**: Commits touching `kit/scripts/**` (a propagation-relevant surface per the migration-block rule) carry no `**Existing projects:**` block in their bodies.
**Why**: Missing migration-block coverage on a propagation surface — a future operator doing project catch-up has no explicit signal that these script changes need no project-side migration. The rule fires even for the no-op variant precisely so "author considered the question" is recorded.
**Fix**: The `/ak-merge-devshop` squash commit (the actual `main`-landing transport for devshop) MUST carry the block, tagged `[auto]` — e.g. `**Existing projects:** [auto] — kit/scripts/{adversarial-review.sh,commit-hooks/check-claude-md-classification.sh} propagate live via the .devshopkit symlink; no project-side migration needed.` Squash-time gate (Phase 0.4.5 `prTextHygieneReason` dimension (d)) is the structural backstop and will FAIL the squash if the block is absent or untagged, so this is recoverable at merge.

### [domain: docs] [section: C] [severity: low]

**File**: CLAUDE.md:48, kit/docs/guide/conventions.md:653 (vs claude-md.md:100, hooks.md, adversarial-review.sh)
**What**: The relocated `devshop-mode.md` file is cited two ways across the docs: `.claude/skills/ak-build/devshop-mode.md` (CLAUDE.md, conventions.md) and `.claude/skills/devshop/build/devshop-mode.md` (claude-md.md, hooks.md, adversarial-review.sh, the 21588ff classification trailer).
**Why**: Cosmetic inconsistency only — `ak-build` is a symlink to `devshop/build`, so both paths resolve to the same file (verified: `ls -la .claude/skills/ | grep ak-build` → `ak-build -> devshop/build`; `Phase 0 fix-assessment` heading present at line 67). Neither is a dangling reference. A future reader grepping for one form misses the other half of the cross-references.
**Fix**: Optional — pick one canonical form (the symlinked `ak-build/` form matches the `/ak-build` skill name used in prose; the `devshop/build/` form matches on-disk layout) and use it consistently. Not blocking.

---

Verified clean (no findings) in these dimensions:

- **Section A coverage (rest)**: `kit/scripts/commit-hooks/**` → `hooks.md` staged ✓; `kit/scripts/adversarial-review.sh` (`kit/scripts/**.sh`) → guide docs + CLAUDE.md staged ✓; bats test under carve-out (`kit/tests/**`); spec/review/gates/verification.log under `specs/` (outside rubric).
- **Section B adequacy**: All relocations substantive (not stubs). Named-section claims verified by grep to exist at HEAD: `devshop-mode.md § Phase 0 fix-assessment` (line 67), `claude-md.md § Reachability split` (line 17), `claude-md.md § Layer B` (line 125), `conventions.md § Root-cause over bandaid` (line 626), `CLAUDE.md § Implementation Approach` (line 42). Named-mechanism empirical verification: hooks.md cites "rule 15(c)" and "rule 15(f)" of the `claudeMdClassification` reviewer — confirmed in `adversarial-review.sh`: rule 15 is the `claudeMdClassification` check-type (line 1226), the relocation-target-staged requirement lands under (c) (line 1241), the skill-operational sub-test under (f) Reachability split (line 1273). Worked-example commit `f2c1e34` verified as the actual mis-homing commit ("docs(claude-md): bias fixes toward root-cause over bandaid"), and the operational mechanic confirmed fully removed from `CLAUDE.md § Implementation Approach` (no residual "Phase 0 decisions"/"detect-and-repair"/AskUserQuestion in that directive). bats Test 3c pins the skill-operational guidance string in the gate output.
- **Section C coherence (rest)**: No renamed/deleted files in range (`--diff-filter=DR` empty). No stale ownership claim left in any doc asserting CLAUDE.md still owns the surface-the-tradeoff mechanic. conventions.md and CLAUDE.md correctly repoint the mechanic at the skill as operational owner; claude-md.md routing row + reachability section + worked-examples row are mutually consistent with the hook/reviewer.
- **Section D bypass**: 1 `Docs-Coverage-Bypass:` trailer in range (`c6ed8a3`) → **VERIFIED** (verification.log is a `specs/` verification artifact, not a doc-surface change; `specs/` is outside the coverage rubric regardless). 0 `CLAUDE-MD-Bypass:` trailers.
- **Section E**: Skipped — devshop self-mode (`$GIT_ROOT == /devshop`); Section E is project-mode only.
