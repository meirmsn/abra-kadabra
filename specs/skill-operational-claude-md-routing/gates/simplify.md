## Gate 4: /simplify

Reviewed the changed code surface in `git diff origin/main...HEAD` for reuse / simplification / efficiency / altitude cleanups (quality only, no bug-hunting). Docs (`.md`) out of scope. The code surface:

- `kit/scripts/commit-hooks/check-claude-md-classification.sh` — added a 5-line `echo` guidance block (skill-operational routing) + extended the header `# Why:` and the relocation-destination echo line.
- `kit/scripts/adversarial-review.sh` — extended the rule-15 reviewer prompt string (relocation-target destination clause + a "Skill-operational sub-test" paragraph).
- `kit/tests/guard-claude-md-classification.bats` — new test 3c pinning the skill-operational routing guidance in the block message.

**Outcome: nothing to simplify (pass).**

## Dismissals

- **Duplication between hook guidance and reviewer prompt → keep both.** Both surfaces now describe the skill-operational routing rule, but they serve different consumers at different altitudes: the hook `echo` text is concise operator-facing teaching shown at commit time (and already points at `kit/docs/guide/claude-md.md` for the canonical routing table), while the reviewer prompt is the LLM judge's rubric — necessarily more detailed (near-tells, sub-test phrasing) because it makes a judgment rather than teaches a human. This mirroring is pre-existing: the trap/reference/convention classification lines are already duplicated across the same two surfaces. There is no sourced-fragment mechanism in this codebase, and inventing one for a handful of `echo` lines would add more complexity than it removes and break the established pattern. Not a worthwhile simplification.

- **bats test 3c structure → keep as-is.** Uses the same two-`echo`-append idiom and the same shape as its neighbors (tests 3, 3b). 14 lines including comments, comparable to 3b. Matching the established file style is correct; not over-long.

- **Hook echo "or owning skill's SKILL.md" addition to the relocation line (110-111) vs. the new definition block (95-99) → keep both.** The definition block and the relocation-destination enumeration do different jobs, consistent with how the existing text already restates "relocate to canonical home" in both the classify list and the relocation line. Not redundant.

Validation: `bash -n` clean on both touched scripts; all 12 tests in `kit/tests/guard-claude-md-classification.bats` pass.
