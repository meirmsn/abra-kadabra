- [low] kit/tests/util-ak-build-skill.bats:295 — anti-bias negative greps pin two
  specific forbidden phrasings (`assess pipeline applicability`, `Step 0.1`); a
  future scope-down gate reintroduced under different wording would slip past
  them. Inherent to prose-grep regression guards and acceptable, but worth noting
  as a coverage ceiling.

Notes (not findings — informational):
- New Section E (6 tests) covers the prohibition block well: header present,
  no-discretion + "every phase, every task" + "no matter how small" phrasing,
  AskUserQuestion template with all three ordered options (Recommended /
  reduced-flow-with-enumeration / Abort), the Phase 0 one-liner cross-ref, and
  the workflow.md coherence line.
- The load-bearing anti-bias pair is present and correct: positive greps assert
  deviation is framed as an EXCEPTION routed through AskUserQuestion; negative
  greps (`! grep`) assert no routine per-run applicability beat exists — exactly
  the bias the rule kills. Both directions pinned.
- All 6 tests pass (ok 31–36 in the full util-ak-build-skill.bats run).
- Test surface is bats (correct — the change is a skill prose edit; no
  vitest/Playwright surface applies).
