# Review — plan-format

## Audit 1: manual (2026-05-17)

<!-- audited-at: bca7583c4e5df886d74b69946de6001ced8c0b14 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=2

### Docs findings

- [low] PLAN.md:67-94 (Source column, 26 rows) — Source column entries drop inline-code backticks and truncate ROADMAP `###` titles after the main concept; cited section names don't exactly match the actual ROADMAP headings. Pointers remain unambiguous via fuzzy match (verified each truncated form maps to exactly one ROADMAP heading). Pre-existing convention from the old PLAN.md, preserved on all 26 rows. Fix: cleanup-pass to copy exact ROADMAP heading text (preserving inline-code backticks), truncating only at natural delimiters (`—` or `→`). Not in scope for this PR.
- [low] commit `bca7583` Docs-Coverage-Bypass trailer — VERIFIED. Bypass declares the 2 SKILL.md edits as pure terminology-tracking (no behavior change) with all 11 catalog docs enumerated as NOT-AFFECTED. Spot-checked accurate: `grep -nE "PLAN(\.md)?( § #| #[0-9]|row #)"` against the 11 catalog docs returns zero matches; PLAN.md's `## How to add entries` preamble IS the operative convention doc for the affected concept (PLAN row identity). Skill diffs confirm wording-only changes (preserve Hook content not Notes; remove "renumber" instruction; use Feature slug in synthesis output instead of `#`). No follow-up needed.

### Tests findings

- (none)

### Bypass trailer audit

- `bca7583` Docs-Coverage-Bypass: VERIFIED (covered in Docs findings above).

## Dismissals

None.
