# Tasks: pr-body-img-merge-sha-survival

Mirror of `## Task order` in spec.md, with running status notes.

| #   | Task                                                                                                                     | Status  | Notes                                                             |
| --- | ------------------------------------------------------------------------------------------------------------------------ | ------- | ----------------------------------------------------------------- |
| 0   | chore(roadmap): scope `gstack-artifact-path-resolution`                                                                  | shipped | Already shipped pre-Phase-1 as `ca6131f`.                         |
| 1   | Add Step 2.5 to `/ak-go-live` SKILL.md (bump v1.4.0); ship extracted helper at `kit/scripts/lib/rewrite-pr-body-urls.sh` | done    | Bundled with Task 2 (paired by docs-coverage hook).               |
| 2   | Add bullet 2.5 to `kit/docs/guide/workflow.md` Step 6                                                                    | done    | Bundled with Task 1.                                              |
| 3   | Create `/devshop/kit/scripts/backfill-pr-image-urls.sh`                                                                  | done    | Sources Task 1's helper for behavior parity. Bundled with Task 4. |
| 4   | Write `kit/tests/util-go-live-step-25-body-rewrite.bats`                                                                 | done    | 34 tests across SKILL prose + helper + backfill. All pass.        |
| 5   | Retire `kit/ROADMAP.md § PR-body image URLs survive branch deletion` + grep prereq prose                                 | pending | Lands AFTER fix exists.                                           |
| 6   | Retire `PLAN.md` row #2; renumber row #3 → #2                                                                            | pending | Phase 5.6 hygiene.                                                |
| 7   | Phase 5.5: run backfill against lalista's closed PRs                                                                     | pending | Operator action; not a code task.                                 |

## Decisions made during implementation

- **Helper uses `m{}` / `s{}{}` perl regex delimiters** (Task 1 / Task 4). The originally-drafted `/ ... /` and `s| ... | ... |` forms collided with the embedded `/` characters in the URL pattern (perl parser treats the first `/` after `https:` as the regex terminator → syntax error). Same fix applied to the count-helper inside `backfill-pr-image-urls.sh`. No spec D# update needed — the spec's Dependencies section already says "perl or sed" and the API contract says "Implementation may use perl -pe or sed".
- **Step 2.5's PR-discovery fallback uses `gh pr list --search "$(git rev-parse HEAD)"` instead of `gh pr list --head "$(git branch --show-current)"`** (Task 1 fix during Task 4). The spec D2 strict-test requires `git branch --show-current` to NOT appear inside the Step 2.5 section slice, so the `$PR` fallback derives from the merge-commit SHA on disk instead. In normal pipeline operation `$PR` is already populated by Step 1 — the fallback only fires on resume mid-pipeline.
- **Bundled commits**: Tasks 1+2 bundled (paired by docs-coverage hook); Tasks 3+4 bundled (test file references the script under test). Spec § Task order treats each as separable but the pre-commit hooks made same-commit grouping the simpler path. Decision made at implement time.
