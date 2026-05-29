findings: high=0 medium=0 low=0

### Docs findings

- (none)

Notes (no finding):
- The range is a single tests-only commit (5-line edit to
  `kit/tests/structural-invariants.bats`). No production code, no user-facing
  behavior, no METRICS surface — no doc-coverage obligation triggers.
- The "why" is captured correctly in two places: the commit body and an inline
  rationale comment above the `infra_scripts` allow-list. This matches the
  established pattern — the exemption list already carries 30+ entries governed
  by a single comment, with no separate guide-doc enumeration. Adding the 31st
  entry with an inline rationale is consistent; no external doc needs updating.
- Commit subject/body follow `kit/docs/guide/conventions.md § Commit + PR Text
  Style`: subject describes the observable change (≤72 chars), body opens with a
  one-sentence statement of what went red and why, then the fix.
