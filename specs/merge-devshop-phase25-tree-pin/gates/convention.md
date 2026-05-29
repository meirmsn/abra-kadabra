## Gate 11: convention

**Verdict: pass.** No convention violations in the feature delta. No changes made.

Scope checked: `git diff origin/main...fix/merge-devshop-phase25-tree-pin`, feature files only
(SKILL.md Phase 2.5, kit/tests/util-ak-merge-devshop.bats §G2, kit/TODOS.md). Merge-commit content
from origin/main ignored.

### Checks

- **SKILL.md frontmatter intact** — `name: ak-merge-devshop` present; YAML block well-formed.
- **Heading structure intact** — `## Phase 2.5: Full bats suite` (line 1017) and `## Phase 3:
  Fast-forward main + push` (line 1146) both present and in order. The bats §G2 awk range
  `/^## Phase 2\.5:/,/^## Phase 3:/` resolves to a non-empty 130-line section, so the grep-based
  content tests bind correctly.
- **New bats tests follow file style** — 5 new tests appended in a `# === Section G2 ===`-style
  block before `# === Section H — Phase 3 ===`. Same idioms as existing tests: `awk` range slice +
  `grep -qE`, line-ordering assertions via `grep -n | cut -d: -f1`, leading `#` rationale comments,
  `$SKILL_FILE` shared var. Consistent with the file's established structure.
- **kit/TODOS.md closure follows the convention** — the HEAD-race entry (`Phase 2.5 can test the
  wrong tree under parallel merges`) was hard-deleted (no strikethrough, no "shipped" footnote). The
  surviving entry in its place is a genuinely distinct concern — the *doc/SKILL.md edit drifts a
  bats-asserting test* prevention sub-point, which this PR does NOT fix (it needs a
  `structural-invariants.bats` mapping or conventions note). Correctly retained as still-open, not a
  zombie of the deleted entry.
- **No new kit/scripts/ file** — `git diff --name-status` on `kit/scripts/` is empty. No
  new-script-needs-bats-test obligation.
- **Commit + PR text style** — substantive subject `fix(ak-merge-devshop): pin Phase 2.5 bats gate
  to the tested commit` describes the observable change, ≤72 chars, no internal jargon. Remaining
  subjects are conventionally-scoped pipeline chores (spec skeleton/expansion, TODO drop).
- **Tests green** — `kit/tests/util-ak-merge-devshop.bats`: 103 passed, 0 failed (includes the 5 new
  §G2 tests).

### Dismissals

- **PLAN.md line 76 cross-reference to the deleted kit/TODOS.md HEAD-race section** — `n/a (handled
  downstream)`. PLAN.md is NOT in this branch's delta. The orphan-looking pointer lives inside the
  feature's own `## Planned (v0)` row, whose final column cites
  `kit/TODOS.md § /ak-merge-devshop Phase 2.5 can test the wrong tree under parallel merges` — the
  section this PR deleted. This is intentional, not a missed unwind: (a) tasks.md's closure-task
  "Done when" explicitly scopes the grep to exclude `PLAN.md row`; (b) the PLAN.md lifecycle rule
  (PLAN.md line 52) deletes the entire Planned row at ship time (Phase 4.0: BUILD-LOG + PLAN
  closure, currently pending), which removes the orphan reference with the row. Unwinding the column
  now would leave a dangling row; the pipeline removes the whole row instead. No action at this gate.
