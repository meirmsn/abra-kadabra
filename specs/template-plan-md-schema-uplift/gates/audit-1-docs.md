# Docs Review — Audit 1

**Range**: `origin/main..HEAD` (4 commits: `09406d2`, `1c9f04a`, `34aa5cc`, `92f3654`)
**Feature**: `template-plan-md-schema-uplift`
**Date**: 2026-05-24

**Note on merge-base divergence**: `origin/main` advanced by 1 commit (`7e84aa6` — `existing-projects-commit-convention`) after this worktree branched from `e9c88ba`. The `origin/main..HEAD` diff shows deletions of that commit's artifacts (conventions.md section, structural-invariants.bats tests, docs-review/merge-devshop skill paragraphs, specs/existing-projects-commit-convention/ tree). These are merge-base divergence artifacts, NOT intentional changes by this branch. The actual branch changes (relative to `e9c88ba`) are 6 files: `template/PLAN.md`, `kit/scripts/session-start.sh`, `BUILD-LOG.md`, `PLAN.md`, `kit/TODOS.md`, `specs/template-plan-md-schema-uplift/spec.md`. This audit judges those 6 files only.

## Section A — Coverage

The devshop rubric triggers on two surfaces:

1. **`template/PLAN.md`** → rubric requires `kit/docs/guide/{architecture,security,ops}.md`. No guide doc was touched. However, the change is a content rewrite of the plan template (column schema from 3-column to 8-column, new prose block, adapted Source pointers). It does not change the template system architecture, security posture, or ops model. The guide docs describe PLAN.md at a schema-agnostic level (`workflow.md § Feature tracking` says "Active and Planned tables at the feature/PR grain" without specifying columns). No substantive guide doc update is warranted.

2. **`kit/scripts/session-start.sh`** → rubric requires `any kit/docs/guide/*.md OR CLAUDE.md`. No guide doc was touched. The change is a parser fix (switching from numbered-row regex to backtick-slug regex, plus stopping at HTML comments). `hooks.md` line 26 describes session-start.sh at a behavioral level ("context for Claude: README, BUILD-LOG, branch, PLAN next row") without specifying the parser format. `CLAUDE.md § Session Start` similarly describes the high-level injection ("Active + Planned") without parser details. No guide doc or CLAUDE.md update is warranted for this internal parser fix.

**Tracker housekeeping** (`BUILD-LOG.md`, `PLAN.md`, `kit/TODOS.md`) — carve-out applies per rubric.

No coverage findings.

## Section B — Adequacy

1. **`template/PLAN.md`** — the new template is self-documenting: includes column definitions, rating scale table, Deps glyphs, lifecycle rules, Source pointer format. The `<!-- Maintenance conventions: ... -->` block preserves editorial guidance. Content is substantive, not stub.

2. **`kit/scripts/session-start.sh`** — the parser change fixes a real bug (old parser expected `| 1 | feature |` which doesn't match the new `| \`feature\` | hook |` schema). Both devshop and project parsers now use the same pattern and both stop at HTML comments. The fix is verified by commit `34aa5cc`'s message describing the behavioral change.

3. **`specs/template-plan-md-schema-uplift/spec.md`** — well-structured spec with Decisions, In/Out of scope, Task order. All 6 decisions are recorded with rationale.

4. **`BUILD-LOG.md`** — entry has all required fields (Branch, Spec, Headline, Summary, Commits, Quality gates). Headline is user-facing, Summary is team-facing. Content matches what shipped.

5. **Commit `1c9f04a` includes an `**Existing projects:**` block** — correctly documents that `template/PLAN.md` is `[scaffold-once]` and won't auto-propagate, with a per-project migration recipe. This is exactly the pattern the convention calls for (ironic given the merge-base note above).

No adequacy findings.

## Section C — Cross-doc coherence

1. **Deleted files** (`specs/existing-projects-commit-convention/` tree) — merge-base divergence, not branch changes. Skipped.

2. **`kit/TODOS.md` cross-reference to PLAN row**: the TODOS entry at line 18 still says "Filed as PLAN row `existing-projects-commit-convention`." The PLAN row still exists on this branch (line 76). Consistent. (On main, `7e84aa6` deleted the PLAN row but also rewrote the TODOS entry — consistent there too. Merge reconciliation is `/ak-merge-devshop`'s concern.)

3. **`template/PLAN.md` Source column format**: references `PRODUCT-ROADMAP.md` and `TODOS.md` which are the correct project-side files. The format matches the devshop PLAN.md convention (backtick-wrapped file path + `§` + section heading).

No coherence findings.

## Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in the range. Zero rows to judge.

## Summary

| Severity | Count |
| --- | --- |
| high | 0 |
| medium | 0 |
| low | 0 |

Clean — no docs findings. The branch changes are well-documented, tracker entries properly closed, and the template is self-documenting. The merge-base divergence with `7e84aa6` (existing-projects-commit-convention) is a merge mechanics concern for `/ak-merge-devshop`, not a docs coverage gap.
