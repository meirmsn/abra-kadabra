### [domain: docs] [section: A] [severity: low]
**File**: (range) kit/scripts/reconcile-task-commits.sh
**What**: New `kit/scripts/**` script lands without an `**Existing projects:**` migration block in any per-commit body.
**Why**: `kit/scripts/**` is a propagation-relevant surface in the devshop coverage rubric. Per-commit bodies carry no migration block.
**Fix**: None required. Verified: the script is NOT in `kit/manifest.txt` (not synced/locked/scaffold) — it is a devshop-internal `/ak-build` orchestration helper that never reaches existing projects, so no project-side migration is needed. The migration-block enforcement for devshop is squash-surface-only (`/ak-merge-devshop` Phase 0.4.5), which is the appropriate place to add a "no migration needed" note at squash time if the squash diff trips the propagation-block check. Informational only.

### Coverage / adequacy / coherence summary (Sections A-D)

- **Coverage (A)**: Strong. The substantive code change (`reconcile-task-commits.sh`) is documented in three places: `build/SKILL.md` Step 0 rung 2 (full reconcile procedure + exit-code routing + Phase 2 re-entry), `build/SKILL.md` resume-artifact-map row 2 (validation column updated), and `implement/SKILL.md` Step 3 step-11 + Step 4 (done-means-committed invariant). `workflow.md` artifact-grain section updated to describe reconcile-on-resume. Tests cross-referenced (`util-reconcile-task-commits.bats`, `util-ak-build-skill.bats`).
- **Adequacy (B)**: Substantive, not stub. Named-mechanism claims empirically VERIFIED — ran the script: usage errors (missing arg, missing tasks.md) both exit 64 as documented; exit-code contract (0 = clean tree + impl≥done; 1 = dirty or impl<done; 64 = usage error) matches the script header and the SKILL.md prose verbatim. The script's own `// What/Why/Does NOT` header is present and accurate.
- **Coherence (C)**: All cited cross-references resolve. `devshop-mode.md § Phase 2.5` (cited from build/SKILL.md rung 2) exists at `.claude/skills/devshop/build/devshop-mode.md` with the `Phase 2.5 resume rung` anchor. `kit/scripts/reconcile-task-commits.sh` and `kit/tests/util-reconcile-task-commits.bats` paths cited in workflow.md + both SKILLs exist. No renamed/deleted files in range; no stale-path sweep hits. No contradictions with non-touched reference docs. The CRLF-strip rationale in the script comment matches the regression test (case 9).
- **Bypass trailers (D)**: No Docs-Coverage-Bypass trailers in range.
- **Section E (CLAUDE.md hygiene)**: skipped — devshop self-mode.

findings: high=0 medium=0 low=1
