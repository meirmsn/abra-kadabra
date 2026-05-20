### [domain: docs] [section: B] [severity: low]
**File**: PLAN.md:77,97
**What**: Top-level "19 fixes" / "closes 19 scaffold-time papercuts" doesn't reconcile with the sub-bundle breakdown `A (5 items) + B (2 items) + E (11 items)` = 18. The commit updated the top-level count (21 → 19) and the B sub-bundle (4 → 2) but left a residual one-row arithmetic gap.
**Why**: Internal inconsistency in a single tracker row — readers comparing the headline count against the sub-bundle line will hit a 1-row discrepancy. Predates this commit (the pre-state 21 vs 5+4+11=20 was already off-by-one), so this is a pre-existing arithmetic drift the hygiene pass could have closed but chose not to.
**Fix**: Either reconcile the top-level to 18 (matching A+B+E), or surface the missing item that bridges the gap (likely a top-level item not slotted into a sub-bundle — e.g., the security-flagged items A1+E4 may be double-counted or there's a standalone item). If the gap is intentional (an item outside the A/B/E taxonomy), name it in the bundle-internal line. Low-severity; tracker hygiene only, no operator-facing surface depends on the count.

---

**Section A (coverage)**: pass. Range contains a single chore commit (`0b2d49b`) touching only `PLAN.md`. No source surfaces touched — no devshop coverage trigger fires (`kit/scripts/**`, `kit/hooks/**`, `template/**`, `.devcontainer/**`, `.claude/skills/**/SKILL.md`, `kit/manifest.txt` — all untouched). PLAN.md is a tracker (peer to `kit/ROADMAP.md` / `kit/TODOS.md`), which is in the explicit carve-outs list for the coverage rubric. The three row closures (`latency-feedback-doc`, `template-ci-overhaul`, plus header counts on `home-os-skill-polish-batch`) are mechanical hygiene per the "Closing TODO / ROADMAP entries when a fix ships" convention — the actual ship commits for those rows are upstream of this commit's base (`05764265`) and were already audited at their respective ship moments. No coverage finding.

**Section B (adequacy)**: one low-severity finding above. Otherwise pass. The closures are substantive — full rows deleted (not whitespace-only); the `home-os-skill-polish-batch` row's Hook and Impact cells both update from "21 fixes" to "19 fixes" (paired edits, not stub); the `fault-injected-qa-gate` Deps cell drops the `ⓘ after latency-feedback-doc` cross-ref (correctly unwound, since the depended-on row is gone); the bundling-cheatsheet "Already-bundled internally" bullet for `template-ci-overhaul` is deleted (cross-ref correctly unwound). Table reflow (column-width changes on +21/-24 lines) is mechanical prettier output, not a no-stub concern. Source paths in remaining `Source` cells were not touched and were not required to be verified by this commit.

**Section C (cross-doc coherence)**: pass. Grep sweep for `latency-feedback-doc` and `template-ci-overhaul` across all `.md` files in the worktree returns only legitimate historical citations:
- `kit/ROADMAP.md:535` documents the shipped state of latency-feedback-doc (verbatim "SHIPPED via …").
- `kit/ROADMAP.md:641,1800` + `kit/docs/guide/conventions.md:162` + `.claude/skills/devshop/pre-ship/SKILL.md:251,382` all reference `template-ci-overhaul, 2026-05-19` as the ship-date provenance for the day-one-active slow-job invariant — these are the convention's audit trail, not stale Planned-row pointers.
- Historical references inside `specs/latency-feedback-doc/**` and `specs/template-ci-overhaul/**` are the feature dirs themselves (audit trail).
None of these are stale forward-looking references. PLAN.md internal grep is clean (zero hits for either slug inside PLAN.md after the commit). Renamed/deleted files: zero (single-file edit, no rename/delete diff).

**Section D (bypass trailers)**: No `Docs-Coverage-Bypass:` trailers in range.

**Section E (CLAUDE.md hygiene)**: SKIPPED — devshop self-mode (GIT_ROOT == `/devshop/.worktrees/plan-hygiene`, parent repo `/devshop`; CLAUDE.md hygiene gate is project-mode only).

---

**Summary**: high=0 medium=0 low=1
