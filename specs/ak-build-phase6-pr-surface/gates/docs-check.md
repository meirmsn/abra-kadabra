## Gate 1: docs-check

**Outcome:** findings (3) fixed

**Scope:** devshop tooling/skill-prose change. Reference docs checked: `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`, `kit/docs/FAQ.md`, `CLAUDE.md`, and the `.claude/skills/devshop/**/SKILL.md` skill docs. The diff makes `/ak-build` Phase 6 stop posting the audit-trail PR comment (gate results stay in committed `review.md`) and makes Part D Gate A autonomous, plus a cross-reference sweep.

### What I checked

1. **Comment-removal framing** — ran `grep -rnE 'audit comment|audit-trail comment|Phase 6.*comment'` across the target docs. Two surviving hits in `kit/docs/`:
   - `kit/docs/guide/workflow.md:323` — phrased "PRs that pre-date the comment's removal" / "current /ak-build no longer posts them". **Correct historical reference — kept** (explicitly allowed by the gate contract).
   - `kit/docs/guide/conventions.md:593` — the lalista PR 18 worked-incident, references comments posted historically. **Correct — kept.**
   - The diff's own rewrites (workflow.md:140/155/186/304/371, OVERVIEW.md:278, FAQ.md:123/97, claude-md.md:151, docs-review/tests-review/pre-ship/go-live/devshop-mode skill hunks) all correctly reframe Phase 6 to "records in / verifies the PR surface against `review.md`". Doc footprint for the comment-removal half is **complete**.

2. **Autonomous-Gate-A framing** — the diff's D3 sweep was scoped to the *comment* framing and missed three sibling references that still described Gate A as an **operator-confirmation** step (the same partial-cleanup class of bug the feature itself fixes). Found via `grep -rniE 'Gate A.*operator|operator.*Gate A|operator confirm'`:

### Findings (all fixed in commit `6b89ecc`)

- **F1 — `kit/docs/guide/conventions.md:445`** (`§ PR body structure`): "Operator verifies at Phase 6 Gate A; automated Gate B cross-checks" → rewritten to "Phase 6 Gate A verifies the blurbs against the diff autonomously (escalating to the operator only on a genuine claim-vs-diff product-judgment mismatch)". Described old behavior.
- **F2 — `kit/docs/guide/conventions.md:488`** (`§ Product update style`): "verified at Phase 6 Gate A (operator) + Gate B" → "verified at Phase 6 Gate A (autonomous — operator only on a genuine claim-vs-diff product-judgment mismatch) + Gate B". Described old behavior.
- **F3a — `.claude/skills/devshop/build/SKILL.md:2829`** (Part D preamble, in the edited file itself): "Part D pairs an automated cross-check (Gate B) with an operator-attention beat (Gate A) … when the operator is already reviewing the PR" → "with an autonomous review (Gate A) … escalating to the operator only on a genuine claim-vs-diff product-judgment mismatch". Residual old framing the D2 rewrite left behind (contradicts the correct autonomous tables at 2916/2918 in the same file).
- **F3b — `.claude/skills/devshop/spec/SKILL.md:376`** (`§ Verification at Phase 6`): "Phase 6 Part D presents both blurbs side-by-side with the diff and asks the operator 'does each blurb still describe what shipped?' Yes/edit per blurb" → "reviews both blurbs against the diff autonomously (Gate A) — classifying each into Accurate / Edit-and-self-resolve / Escalate, and prompting the operator only on a genuine claim-vs-diff product-judgment mismatch". Described old always-ask behavior.

### Verification

- Post-fix re-greps for both old-behavior patterns (comment-posting frame AND operator-Gate-A frame) return only the legitimate historical / "posts nothing" matches.
- `kit/tests/lib/bats-core/bin/bats kit/tests/util-product-update-blurb.bats` — **39/39 pass** (includes the new "Phase 6 posts no audit-trail PR comment" assertion and the rewritten autonomous-Gate-A assertions).
- Fix committed atomically on the feature branch as `6b89ecc` (`docs: align Gate A operator-verification framing with autonomous behavior`); pre-commit guards passed with no bypass.
- Lines that legitimately reference Phase 6 doing other work (CI-green watch, evidence sweep, Part B status-comment read, `spec/SKILL.md:442` neutral "verified against the diff at Phase 6 Gate A", `build/SKILL.md:2453` "Phase 6 does NOT run") were judged accurate and left unchanged.

## Dismissals

- `kit/docs/guide/workflow.md:323` — rationale: legitimate *historical* reference to comments on PRs that pre-date the comment's removal ("current /ak-build no longer posts them"); the gate contract explicitly preserves this framing.
- `kit/docs/guide/conventions.md:593` — rationale: lalista PR 18 worked-incident describing comments posted historically; not a description of current Phase 6 behavior.
- `kit/docs/guide/workflow.md:304` ("posts nothing") — rationale: matched the comment-grep only on the word "posts"; it is the new correct framing asserting Phase 6 posts nothing.
- `.claude/skills/devshop/spec/SKILL.md:442` — rationale: neutral "verified against the diff at Phase 6 Gate A" with no operator-confirmation claim; stays accurate under the autonomous model.
