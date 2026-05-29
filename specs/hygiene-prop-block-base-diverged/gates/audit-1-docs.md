### [domain: docs] [section: C] [severity: low]
**File**: kit/docs/guide/workflow.md:488
**What**: The `/ak-merge-devshop` row documents the Phase 1.0 rebase as the remedy for base-divergence two-dot phantom findings (the 2026-05-28 `go-live-prod-url-extraction` incident), but does not note that the Phase 0.4.5 squash-hygiene check — which fires BEFORE the Phase 1.0 rebase — has its own base-divergence exposure that this commit fixed independently (dimension (d) PROP_SURFACES two-dot → three-dot). A reader could infer the rebase alone covers all base-divergence phantom findings.
**Why**: Incomplete coherence — the doc describes one of two complementary fixes for the same bug class (stale-base two-dot phantom surfaces). The dimension-(d) hygiene check runs at Phase 0.4.5, upstream of the Phase 1.0 rebase the row credits, so it needed its own three-dot fix; the prose doesn't surface that the pre-rebase hygiene surface is separately hardened.
**Fix**: Optional one-clause addition to the workflow.md:488 base-divergence sentence (or the hooks.md § Dual-surface check-types squash row) noting that Phase 0.4.5's dimension-(d) propagation-surface precompute diffs three-dot (merge-base delta) so a base-diverged branch isn't phantom-FAILed before the Phase 1.0 rebase resolves the divergence. Behavior-only; not blocking.

### [domain: docs] [section: A] [severity: low]
**File**: kit/scripts/adversarial-review.sh:370
**What**: The range touches a `kit/scripts/**.sh` surface (the devshop coverage rubric asks for any `kit/docs/guide/*.md` OR `CLAUDE.md` edit) with no doc edit in range. Assessed as doc-neutral: the fix corrects the implementation to match behavior the docs already describe (dimension (d) "FAILs when the squash diff touches a propagation surface" — hooks.md, conventions.md § Enforcement, CLAUDE.md footgun line 115, merge-devshop SKILL.md:388 all describe (d) behaviorally and none asserted the now-corrected two-dot basis). Rationale for the load-bearing detail (the diff basis) is captured in a substantive 13-line inline comment (lines 357-369). The `**Existing projects:** none — <why>` migration block is present and correct.
**Why**: A bug fix that brings implementation in line with already-documented behavior, with thorough in-code rationale, does not create a doc-coverage gap. Noted only to record that the script-surface trigger fired and was assessed, not silently skipped.
**Fix**: None required. The inline comment is the correct home for the diff-basis rationale; no guide-doc edit is warranted because no documented behavior changed.

---

Section B (adequacy): no doc edits in range to assess. The inline comment added at adversarial-review.sh:357-369 is substantive and empirically accurate — verified the three-dot claim by running the suite: `kit/tests/util-adversarial-review-narrowing.bats` is 23/23 green including the new test 18 ("dimension d uses three-dot diff — no phantom surface on base-diverged branch"), and the commit-message "Test:" claim that it FAILs on two-dot / passes on three-dot is consistent with the test's `assert_failure` on the phantom `template/.gitignore` grep. No stubs, no dangling references.

Section C (coherence): no reference doc contradicts the fix. The `origin/main..$DEVSHOP_HYGIENE_BRANCH` two-dot references in hooks.md (lines 222, 493, 495) and merge-devshop SKILL.md (line 348 in script / line 302) describe the CONSTITUENT-COMMIT `git log` basis, which the fix deliberately leaves two-dot ("the right basis for listing a branch's commits") — those are accurate, not stale. The dimension-(d) propagation-surface diff that changed is documented only behaviorally (no diff-basis assertion) in CLAUDE.md:115, conventions.md § Existing-Project Migration Block § Enforcement, and SKILL.md:388 — all consistent with the new three-dot basis. No renamed/deleted files in range.

Section D (bypass trailers): No Docs-Coverage-Bypass trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode ($GIT_ROOT = /devshop worktree), project-only section.
