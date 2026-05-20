### [domain: docs] [section: A] [severity: low]
**What**: Range covers two commits — ed7c0e2 (Audit 1 review artifact: adds specs/template-ci-overhaul/{review.md, gates/audit-1-docs.md, gates/audit-1-tests.md}) and 9850786 (Audit 1 fixes: .claude/skills/devshop/pre-ship/SKILL.md gate-2c rewrite, kit/docs/guide/conventions.md TOC anchors, kit/scripts/preship/{migration-rollback-roundtrip,slow-job-lifecycle-check}.sh chmod 755→644, kit/tests/preship-slow-job-lifecycle.bats rewrite, kit/tests/template-ci-yml-shape.bats hardening). Source surfaces touched in 9850786 and their coverage:
- `kit/scripts/preship/*.sh` chmod-only delta (no semantic change) — no required doc touch; the mode flip closes Audit 1 tests-review HIGH-3 (structural invariant #102 violation) and is mechanical bookkeeping. Coverage rubric does not fire.
- `.claude/skills/devshop/pre-ship/SKILL.md` IS the canonical user-facing doc; its edit closes Audit 1 docs-review HIGH-1.
- `kit/docs/guide/conventions.md` TOC update closes Audit 1 docs-review MEDIUM-1.
- `kit/tests/preship-slow-job-lifecycle.bats` and `kit/tests/template-ci-yml-shape.bats` rewrites are test-side (audit-time tests-review handles those).
**Why**: Coverage rubric satisfied for every source-surface touched in the range. No `Docs-Coverage-Bypass:` trailers; nothing left dangling.
**Fix**: No action — informational.

### [domain: docs] [section: B] [severity: low]
**File**: .claude/skills/devshop/pre-ship/SKILL.md:251,380-398
**What**: The gate-2c row + dedicated section rewrite (commit 9850786) is substantive — not whitespace/reflow. Row title flipped from "Slow-job CI enabled past Phase 1c/1g" to "Slow-job CI active + structurally intact"; scope from threshold-conditional `when *.integration.test.ts or apps/web/e2e/*.spec.ts files exist` to `always (regression guard; slow-job ships active from day one per template-ci-overhaul, 2026-05-19)`; section body enumerates the new check set inline (active stub, runtime-gate predicate `github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'`, edge-runtime retry, content-scoped hashFiles guards on Playwright + migration steps, unguarded `Start local Supabase`, `changes:` job + `runtime` output + slow-job `needs:`/`if:` wiring, branch protection includes `slow`). Outcome rows updated: `pass` describes the new invariant; `findings (N)` enumerates the new failure modes by Check number (Check 2 = rescoped pull_request gate, Check 4 = hashFiles guards, Check 4b = unguarded Start local Supabase, Check 6 = changes-job wiring, Check 7 = branch protection); `n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)` row deleted. Cross-ref to `kit/docs/guide/conventions.md § Slow-Job Lifecycle` retained at section head (links the parent section rather than the deeper `§ Structural enforcement (regression guard)` subsection that Audit 1's Fix-recipe suggested, but the parent-section pointer is functionally adequate — readers landing on the parent section see the subsection inline).
**Why**: Adequacy spot-check on Audit 1 HIGH-1 closure. The rewrite is substantive, the new check enumeration matches `kit/scripts/preship/slow-job-lifecycle-check.sh` behavior, the conventions cross-ref resolves.
**Fix**: No action — informational. Optional polish: deepen the cross-ref to `§ Slow-Job Lifecycle § Structural enforcement (regression guard)` so the gate-2c section anchors directly at the invariant list. Not blocking.

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/conventions.md:13-22
**What**: TOC entry update (commit 9850786) is substantive. Verified each new anchor against the file's current header set via `grep -n '^#' conventions.md`:
- `[Why active from day one](#why-active-from-day-one)` → matches `### Why active from day one` (line 162). PASS.
- `[Per-step empty-state guards](#per-step-empty-state-guards)` → matches `### Per-step empty-state guards` (line 166). PASS.
- `[Helper scripts](#helper-scripts)` → matches `### Helper scripts` (line 180). PASS.
- `[Extending the active stub](#extending-the-active-stub)` → matches `### Extending the active stub` (line 189). PASS.
- `[Structural enforcement (regression guard)](#structural-enforcement-regression-guard)` → matches `### Structural enforcement (regression guard)` (line 197). PASS.
- Dangling `[Uncommenting checklist](#uncommenting-checklist)` deleted (no longer present in TOC, and `grep -rn 'Uncommenting checklist\|#uncommenting-checklist' kit/docs/ .claude/skills/` returns zero hits across the whole repo — no other doc still references it).
**Why**: Adequacy spot-check on Audit 1 MEDIUM-1 closure. All five new TOC anchors resolve at HEAD; the stale entries are fully expunged.
**Fix**: No action — informational.

### [domain: docs] [section: C] [severity: low]
**What**: Section-C grep sweep for stale references to the removed `Uncommenting checklist` subsection across all reference-doc surfaces (`kit/docs/`, `.claude/skills/`, `CLAUDE.md`) returns zero hits. No cross-doc references to chase. The `### Structural enforcement` rename to `### Structural enforcement (regression guard)` is consumed by exactly one TOC entry (line 18, this same file) which the audit-fixes commit updated; no other doc embeds the old anchor.
**Why**: Coherence sweep clean.
**Fix**: No action — informational.

### [domain: docs] [section: D] [severity: low]
**What**: No `Docs-Coverage-Bypass:` trailers in commit range (5fb1abc..HEAD, 2 commits).
**Why**: Bypass-trailer mechanism is informational for now; absence is not a finding.
**Fix**: No action.

## Bypass trailer harvest

No Docs-Coverage-Bypass trailers in range.

## Summary

- **Section A (Coverage)**: 0 findings. Every touched source surface in this range has either matching doc edits or is mechanical bookkeeping that doesn't trigger the coverage rubric (chmod-only `.sh` mode flips closing Audit 1 tests-review HIGH-3).
- **Section B (Adequacy)**: 0 findings. Both Audit 1 high+medium docs-review fixes are substantive — the pre-ship SKILL.md gate-2c row + section rewrite matches the gate's actual behavior, and the conventions.md TOC anchors all resolve at HEAD.
- **Section C (Coherence)**: 0 findings. Cross-doc grep sweep for removed `Uncommenting checklist` references returns zero hits; the `Structural enforcement` heading rename has its sole consumer (conventions.md TOC) updated.
- **Section D (Bypass trailers)**: 0 trailers in range.
- **Section E (CLAUDE.md hygiene)**: SKIPPED — devshop self-mode (GIT_ROOT == /devshop/.worktrees/template-ci-overhaul, parent repo /devshop).

All Audit 1 high + medium docs findings closed. No new docs findings raised in the audit-fixes commit.

high=0 medium=0 low=5
