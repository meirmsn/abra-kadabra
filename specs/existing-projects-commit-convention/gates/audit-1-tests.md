# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (2 commits: `135b637`, `56d1505`)
**Feature**: `existing-projects-commit-convention`
**Date**: 2026-05-24

## Section A — Coverage of new behavior

No coverage gaps. The diff adds:

- New convention section in `kit/docs/guide/conventions.md` (documentation)
- New audit-time rubric paragraph in `.claude/skills/devshop/docs-review/SKILL.md` (skill instruction)
- New lead-in label in `.claude/skills/devshop/merge-devshop/SKILL.md` (skill instruction)
- Tracker housekeeping (`BUILD-LOG.md`, `PLAN.md`, `kit/TODOS.md`)
- 6 new structural-invariant bats tests in `kit/tests/structural-invariants.bats`

Per the devshop rubric, convention changes in `kit/docs/guide/` need matching `.bats` specs. The 6 tests pin: section existence, trigger table contents, both variant shapes, cross-references in docs-review and merge-devshop skills, and TOC entry. Coverage is complete.

No new `kit/scripts/**`, no new hooks, no new skill files (only edits to existing skills). No uncovered surfaces.

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/structural-invariants.bats:844` — test "convention: existing-project migration block section has trigger table"
**What**: The three `grep -q` calls (`\[locked\]`, `\[scaffold-once\]`, `\[sync\]`) search the entire `conventions.md` file, not just the Existing-Project Migration Block section. These lifecycle tag strings appear in other sections of `conventions.md` too (e.g., the TODOS entry cross-reference at the bottom, or future convention sections). The test would pass even if the trigger table were removed, as long as those strings exist elsewhere in the file.
**Why**: If the trigger table is accidentally deleted during a future refactor but the lifecycle tags remain referenced in other sections, this test silently passes — false confidence that the trigger table is intact.
**Fix**: Scope the grep to the section bounded by `## Existing-Project Migration Block` and the next `## ` heading. Example:
```bash
awk '/^## Existing-Project Migration Block/,/^## [^#]/' "$conventions" | grep -q '\[locked\]'
awk '/^## Existing-Project Migration Block/,/^## [^#]/' "$conventions" | grep -q '\[scaffold-once\]'
awk '/^## Existing-Project Migration Block/,/^## [^#]/' "$conventions" | grep -q '\[sync\]'
```

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the range. Zero rows to judge.

## Skipped tests audit

No `.skip`, `.only`, or no-arg `test.skip()` patterns found in the diff. Clean.

## Summary

| Severity | Count |
| --- | --- |
| high | 0 |
| medium | 0 |
| low | 1 |

Tests look solid — one low-severity scoping nit on the trigger-table assertion. No findings that block shipping.
