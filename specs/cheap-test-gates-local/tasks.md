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
- Commit: 047136b
- Notes: Created `kit/scripts/preship/path-classifier.sh` with `classify` + `diff-needs-stack` subcommands; D4's hardcoded glob table; exit codes 0 (stack-needing in diff) / 1 (no match) / 2 (git error). Modified `supabase-bootstrap.sh` to inject `emit_degraded_outcome` helper that reads `git config devshop.requireHealthyLocalStack` (unset → `when-relevant` → consult classifier; `never` → always pass-with-note; `always` → always blocked) — the previously-unconditional `echo "blocked: ..."` callsites in the `up` mode now route through this helper. Fail-safe: classifier missing OR git-error → emit `blocked:` (legacy behavior). 39 BATS tests added: 25 in `util-path-classifier.bats` (D4 table + ambiguous paths + diff-needs-stack exit codes), 14 in `preship-supabase-bootstrap-classifier.bats` (full D6 decision matrix). All 19 existing supabase-bootstrap tests still pass. Documented in `kit/docs/guide/conventions.md § Local Pre-Push Test Gates` (this is the bulk of Task 6's conventions.md slice — landed early because the docs-coverage hook required a paired guide-doc update on this commit's preship-surface changes).

## Task 3 — `localTestSkipReason` adversarial-review check-type

- [x]
- Commit: a2d605b
- Notes: Added `localTestSkipReason)` case to `kit/scripts/adversarial-review.sh` (after `testReviewSkipReason)`); routes to Sonnet (joins the high-blast-radius judgment group); appended rule #10 to the prompt mirroring `testReviewSkipReason`'s (a)-(d) shape. Context block enumerates the four gate categories (parse-check / changed E2E / changed integration / smoke set), surfaces the diff against origin/main (or HEAD~1 fallback), and includes branch + HEAD SHA. 13 BATS tests added in `kit/tests/util-adversarial-review-localTestSkipReason.bats`. Updated `kit/docs/guide/hooks.md`'s three bypass-flag enumerations to add `localTestSkipReason` (Task 6's hooks.md slice — landed alongside Task 3 because the docs-coverage hook treats `kit/scripts/*` as a "scripts" surface).

## Task 4 — Wire new gate at #2d in `ak-pre-ship/SKILL.md`

- [ ]
- Commit:
- Notes:

## Task 5 — BATS test coverage

- [x]
- Commit: 4ad6ae4 (changed-tests-local), 047136b (path-classifier + bootstrap-classifier), a2d605b (localTestSkipReason)
- Notes: All four BATS files from spec § Tests landed alongside their respective tasks (1, 2, 3) because the devshop pre-commit `check-tests-coverage-devshop.sh` requires every new kit/scripts file to have a paired test in the same commit. Total new BATS coverage: `util-path-classifier.bats` (25 tests), `preship-changed-tests-local.bats` (10 tests), `util-adversarial-review-localTestSkipReason.bats` (13 tests), `preship-supabase-bootstrap-classifier.bats` (14 tests) = 62 new tests. Full BATS suite at HEAD: 660/660 pass.

## Task 6 — Doc updates

- [x]
- Commit: 4ad6ae4 (workflow.md slice), 047136b (conventions.md `## Local Pre-Push Test Gates` + cross-ref from `## Slow-Job Lifecycle`), a2d605b (hooks.md `localTestSkipReason` enumerations), (CLAUDE.md Tier-1 entry — pending)
- Notes: Most doc updates landed alongside the surface changes that triggered docs-coverage hook requirements. Final piece: `/devshop/CLAUDE.md` Tier-1 entry naming both `devshop.localTestSkipReason` (gate bypass) and `devshop.requireHealthyLocalStack` (preflight promotion control), with cross-reference to conventions.md § Local Pre-Push Test Gates for the full convention.

## Task 7 — Roadmap bookkeeping

- [x]
- Commit: (pending)
- Notes: Marked `kit/ROADMAP.md § Shift cheap test gates from CI-only to local pre-push` as `[SHIPPED 2026-05-06 — feature/cheap-test-gates-local]` with a one-line ship note. Appended three new v1 entries: (1) sub-fix 2 stage 2 (per-project `.devshop/test-impact.json` path-pattern map), (2) sub-fix 2 stage 3 (import-graph match via `tsc --listFiles` / `madge`), (3) Lalista adoption PR (validation ground for the new gate firing on a real diff + bypass flow + degraded-stack `blocked` promotion).

## Task 8 — Seed `PLAN.md` + `BUILD-LOG.md` in the devshop repo

- [x]
- Commit: (pending)
- Notes: Created `/devshop/PLAN.md` from `template/PLAN.md` with this branch's row in `## Active`; created `/devshop/BUILD-LOG.md` from `template/BUILD-LOG.md` (intro + `_No builds yet._` placeholder). PROACTIVE seed per spec § Task 8 — defuses the docs-only-first-commit edge case in /ak-build Phase 5.6 / 5.7. Reference paths in PLAN.md adjusted from project-template defaults (PRODUCT-ROADMAP.md / TODOS.md) to devshop-side equivalents (kit/ROADMAP.md / kit/TODOS.md).

## Decisions (judgment calls made during implementation)

### D-impl-1: Merge Task 1 + Task 4 into a single commit

Decision: Land `changed-tests-local.sh` (Task 1) together with the `ak-pre-ship/SKILL.md` wiring (Task 4) in one commit.

Rationale: The devshop pre-commit hook (`check-docs-coverage-devshop.sh`) treats `kit/scripts/preship/*.sh` as a "preship" surface that requires either `.claude/skills/devshop/pre-ship/SKILL.md` OR any `kit/docs/guide/*.md` to be staged in the same commit. The spec's atomic-commits-per-task ordering would have Task 1 ship the script alone, which the hook blocks. Two clean options: (a) bypass with `devshop.docsCoverageReason` (forbidden — operator boundary forbids hook bypass flags); (b) merge Task 1 + Task 4 since they are logically linked (the gate body is meaningless without the gate definition). Picked (b) — preserves the spec's intent (one atomic, reviewable commit per logical surface) while satisfying the hook's docs-coverage contract. Task 4's commit-message-line is preserved as part of the merged commit's body so the audit trail still reads the same.

This pattern is likely to recur for Tasks 2 and 3 (their respective surfaces are also `kit/scripts/preship/*` or `kit/scripts/*`); each will land together with its enabling doc/SKILL update where needed.
