# Tasks: cheap-test-gates-local

Source spec: /devshop/specs/cheap-test-gates-local/spec.md

## Task 1 — `changed-tests-local.sh` helper + diff/spec/glob plumbing

- [x]
- Commit: 4ad6ae4 (merged with Task 4 + workflow.md slice of Task 6 — see D-impl-1)
- Notes: Created `kit/scripts/preship/changed-tests-local.sh` with the four-step gate body (parse-check → changed E2E → changed integration → smoke set), wallclock-bounded via `timeout --kill-after=10s`, env-overridable budgets per spec D5, canonical stdout contract (outcome line + indented findings + `## Dismissals` section), bypass-flag handling via `devshop.localTestSkipReason` invoking adversarial-review.sh's localTestSkipReason check-type. Path-classifier has an inline fallback so the script is self-contained when the helper isn't yet on disk (Task 2 ships it). Wired the gate at #2d in ak-pre-ship/SKILL.md and added the #2d row to workflow.md § Pipeline at a Glance — the docs-coverage hook required both surfaces to be updated alongside the script.

## Task 4 — Wire new gate at #2d in `ak-pre-ship/SKILL.md`

- [x]
- Commit: 4ad6ae4 (merged with Task 1 — see D-impl-1)
- Notes: Added `## Gate changed-tests-local (ak)` body between slow-job-lifecycle (#2c) and Gate 3, and added the row to the canonical-order table at the same time. Documented the four steps + wallclock budgets + outcomes + bypass + preflight contract.

## Task 2 — Path classifier + `supabase-bootstrap.sh` integration (sub-fix 3)

- [x]
- Commit: (pending)
- Notes: Created `kit/scripts/preship/path-classifier.sh` with `classify` + `diff-needs-stack` subcommands; D4's hardcoded glob table; exit codes 0 (stack-needing in diff) / 1 (no match) / 2 (git error). Modified `supabase-bootstrap.sh` to inject `emit_degraded_outcome` helper that reads `git config devshop.requireHealthyLocalStack` (unset → `when-relevant` → consult classifier; `never` → always pass-with-note; `always` → always blocked) — the previously-unconditional `echo "blocked: ..."` callsites in the `up` mode now route through this helper. Fail-safe: classifier missing OR git-error → emit `blocked:` (legacy behavior). 39 BATS tests added: 25 in `util-path-classifier.bats` (D4 table + ambiguous paths + diff-needs-stack exit codes), 14 in `preship-supabase-bootstrap-classifier.bats` (full D6 decision matrix). All 19 existing supabase-bootstrap tests still pass.

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
