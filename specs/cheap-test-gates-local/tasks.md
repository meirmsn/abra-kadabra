# Tasks: cheap-test-gates-local

Source spec: /devshop/specs/cheap-test-gates-local/spec.md

## Task 1 — `changed-tests-local.sh` helper + diff/spec/glob plumbing

- [x]
- Commit: (pending)
- Notes: Created `kit/scripts/preship/changed-tests-local.sh` with the four-step gate body (parse-check → changed E2E → changed integration → smoke set), wallclock-bounded via `timeout --kill-after=10s`, env-overridable budgets per spec D5, canonical stdout contract (outcome line + indented findings + `## Dismissals` section), bypass-flag handling via `devshop.localTestSkipReason` invoking adversarial-review.sh's localTestSkipReason check-type. Path-classifier has an inline fallback so the script is self-contained when the helper isn't yet on disk (Task 2 ships it).

## Task 2 — Path classifier + `supabase-bootstrap.sh` integration (sub-fix 3)

- [ ]
- Commit:
- Notes:

## Task 3 — `localTestSkipReason` adversarial-review check-type

- [ ]
- Commit:
- Notes:

## Task 4 — Wire new gate at #2d in `ak-pre-ship/SKILL.md`

- [ ]
- Commit:
- Notes:

## Task 5 — BATS test coverage

- [ ]
- Commit:
- Notes:

## Task 6 — Doc updates

- [ ]
- Commit:
- Notes:

## Task 7 — Roadmap bookkeeping

- [ ]
- Commit:
- Notes:

## Task 8 — Seed `PLAN.md` + `BUILD-LOG.md` in the devshop repo

- [ ]
- Commit:
- Notes:

## Decisions (judgment calls made during implementation)

### D-impl-1: Merge Task 1 + Task 4 into a single commit

Decision: Land `changed-tests-local.sh` (Task 1) together with the `ak-pre-ship/SKILL.md` wiring (Task 4) in one commit.

Rationale: The devshop pre-commit hook (`check-docs-coverage-devshop.sh`) treats `kit/scripts/preship/*.sh` as a "preship" surface that requires either `.claude/skills/devshop/pre-ship/SKILL.md` OR any `kit/docs/guide/*.md` to be staged in the same commit. The spec's atomic-commits-per-task ordering would have Task 1 ship the script alone, which the hook blocks. Two clean options: (a) bypass with `devshop.docsCoverageReason` (forbidden — operator boundary forbids hook bypass flags); (b) merge Task 1 + Task 4 since they are logically linked (the gate body is meaningless without the gate definition). Picked (b) — preserves the spec's intent (one atomic, reviewable commit per logical surface) while satisfying the hook's docs-coverage contract. Task 4's commit-message-line is preserved as part of the merged commit's body so the audit trail still reads the same.

This pattern is likely to recur for Tasks 2 and 3 (their respective surfaces are also `kit/scripts/preship/*` or `kit/scripts/*`); each will land together with its enabling doc/SKILL update where needed.
