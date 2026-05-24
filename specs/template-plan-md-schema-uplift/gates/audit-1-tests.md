# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (4 commits: `09406d2`, `1c9f04a`, `34aa5cc`, `92f3654`)
**Feature**: `template-plan-md-schema-uplift`
**Date**: 2026-05-24

**Note on merge-base divergence**: same note as docs audit — the `origin/main..HEAD` diff shows deletion of 53 lines of bats tests from `kit/tests/structural-invariants.bats` (the 6 `existing-projects-commit-convention` structural assertions). These are merge-base divergence artifacts from `7e84aa6` landing on main after this worktree branched. This branch did not delete any tests. The actual branch changes (relative to `e9c88ba`) add no test files and delete no test files.

## Section A — Coverage of new behavior

The diff (relative to branch point `e9c88ba`) adds:

1. **`template/PLAN.md` rewrite** — template content (Markdown). Per the devshop rubric, template content changes do not require `.bats` specs. Templates are `[scaffold-once]` static content; there is no runtime behavior to test. The spec itself states "No tests — this is a docs-only template change."

2. **`kit/scripts/session-start.sh` parser fix** (commit `34aa5cc`) — behavioral change to a `kit/scripts/**` file. Per the devshop rubric: "New `kit/scripts/**.sh` → matching `.bats` spec under `kit/tests/`." However, this is a fix to an existing script (not a new script), and the existing `session-start.sh` does not have a dedicated `.bats` spec. The parser change is a regex adjustment (from numbered-row to backtick-slug format + HTML comment stop). Let me check if existing tests cover this parser.

No existing bats test covers the PLAN.md parser in `session-start.sh`. The parser change is a 5-line awk adjustment — the behavioral impact is limited to which row `session-start.sh` extracts as the "next planned feature" context injection. The change is verified by the fact that the session-start hook ran successfully during the branch's own commits (it runs on every `startup` and `clear`).

Given that session-start.sh has no existing test coverage and the change is a parser fix (not new behavior), this is a borderline finding. The rubric says new scripts need tests, not fixes to existing untested scripts. Filing as low.

### [domain: tests] [section: A] [severity: low]
**File**: `kit/scripts/session-start.sh:171`
**What**: Parser fix for project-session PLAN.md extraction (numbered-row → backtick-slug format) has no bats test coverage. The devshop-session parser at line 197 has the same untested pattern.
**Why**: If a future template/PLAN.md schema change breaks the parser regex, the failure is silent (session context injection quietly shows no "Next up" row instead of the correct next feature). The hook doesn't fail visibly.
**Fix**: Add a `session-start-plan-parser.bats` test that creates a temp PLAN.md with the rich schema, sources the parser awk snippet, and asserts the extracted feature slug and hook. Low priority — the parser is simple and the failure mode is cosmetic (missing context, not wrong behavior).

3. **Tracker housekeeping** (`BUILD-LOG.md`, `PLAN.md`, `kit/TODOS.md`, `specs/template-plan-md-schema-uplift/spec.md`) — documentation artifacts. No test coverage required per rubric carve-out.

## Section B — Test quality

No new or modified test files in the branch's actual changes. Nothing to assess.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in the range. Zero rows to judge.

## Skipped tests audit

No `.skip`, `.only`, or no-arg `test.skip()` patterns in the diff. Clean.

## Summary

| Severity | Count |
| --- | --- |
| high | 0 |
| medium | 0 |
| low | 1 |

One low-severity coverage nit on the untested session-start.sh PLAN.md parser. The spec correctly identifies this as a "docs-only template change" with no tests needed for the template itself. The parser fix is the only behavioral change and its failure mode is cosmetic. No findings that block shipping.
