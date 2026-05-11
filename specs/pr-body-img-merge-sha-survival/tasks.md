# Tasks: pr-body-img-merge-sha-survival

Mirror of `## Task order` in spec.md, with running status notes.

| #   | Task                                                                                                                     | Status  | Notes                                               |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ------- | --------------------------------------------------- |
| 0   | chore(roadmap): scope `gstack-artifact-path-resolution`                                                                  | shipped | Already shipped pre-Phase-1 as `ca6131f`.           |
| 1   | Add Step 2.5 to `/ak-go-live` SKILL.md (bump v1.4.0); ship extracted helper at `kit/scripts/lib/rewrite-pr-body-urls.sh` | done    | Bundled with Task 2 (paired by docs-coverage hook). |
| 2   | Add bullet 2.5 to `kit/docs/guide/workflow.md` Step 6                                                                    | done    | Bundled with Task 1.                                |
| 3   | Create `/devshop/kit/scripts/backfill-pr-image-urls.sh`                                                                  | pending | Sources Task 1's helper for behavior parity.        |
| 4   | Write `kit/tests/util-go-live-step-25-body-rewrite.bats`                                                                 | pending | Content + behavior tests.                           |
| 5   | Retire `kit/ROADMAP.md § PR-body image URLs survive branch deletion` + grep prereq prose                                 | pending | Lands AFTER fix exists.                             |
| 6   | Retire `PLAN.md` row #2; renumber row #3 → #2                                                                            | pending | Phase 5.6 hygiene.                                  |
| 7   | Phase 5.5: run backfill against lalista's closed PRs                                                                     | pending | Operator action; not a code task.                   |

## Decisions made during implementation

(Recorded inline as work proceeds; spec § Decisions stays verbatim.)
