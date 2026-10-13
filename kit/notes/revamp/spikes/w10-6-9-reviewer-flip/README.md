# W10.6.9 reviewer flip (F-NEW-40)

In north-star run 1 the reviewer passed fixture commit `1337cc0` and then failed the same commit a
minute later (LOG #53). The fail was right: the "Go back" script kept `history.length > 1`, a check
the spec's decision had rejected. This folder measures how often the outcome flips on identical
input, before and after the owner-chosen fix. 2026-10-13, LOG #55.

## Result

| Set (5 runs each, identical input)        | Before: outcome                   | After: outcome                     |
| ----------------------------------------- | --------------------------------- | ---------------------------------- |
| Honest, 5 changes                         | 25/25 pass, 0 flips               | 25/25 pass, 0 flips                |
| Planted, 15 changes (seed-1 plants)       | 75/75 fail, 0 flips; 75 name plant | 74/74 fail, 74 name plant; 1 could-not-run ¹ |
| Run-1 commit, with PR words               | **3 pass, 2 fail: flips**         | 5/5 fail                           |
| Run-1 commit, no PR words                 | **2 pass, 3 fail: flips**         | 5/5 fail                           |
| Rejected check graded ≥ `medium`, of 10   | 1 (7 `low`, 2 not mentioned)       | **10**                             |
| Cost                                      | $7.33 for 110                     | $7.65 for 110                      |

¹ `p-starred-reworded-acceptance` run 3: the model's reply covered 5 of the spec's 7 items, and
`review.sh` failed closed (could-not-run, never a pass). 1 in 220 reviews here; not a flip, and not
changed by this fix.

- **The flip is in severity, not in seeing the problem.** The run-1 pass verdict itself listed the
  rejected check as a `low` "harmless extra guard". Over 10 runs, 8 saw it, 7 of those called it
  `low`. A second judgement call flipped the same way: whether the `/`-with-no-items state row was
  tested enough (`medium` in 4 of 10). Neither is a plant; both are a real, small departure from the
  spec, which is where the prompt gave no severity rule.
- **Plants never flipped** (0 in 75 before), and no honest change ever failed (0 in 25 before and 25
  after). A-12's numbers stand; the gap was outside the plant types.

## Options measured (the run-1 commit, 10 runs each, both PR-word variants)

| Variant                          | Fails | Rejected check ≥ `medium` | $ / review | Notes                                     |
| -------------------------------- | ----- | ------------------------- | ---------- | ----------------------------------------- |
| As shipped (`a86ad4b`)           | 5/10  | 1/10                      | 0.11       |                                           |
| V1: prompt rule (chosen)         | 10/10 | 10/10                     | 0.11       | honest set 10/10 pass                     |
| V2: `--effort high`              | 10/10 | 2/10                      | 0.16       | fails on other items; still guesses `low` |
| V3: Opus                         | 10/10 | 2/10                      | 0.48       | same as V2, 4× the cost                   |
| Review twice, fail if either     | ≈ 75% | —                         | 2×         | estimated from the 5/10 rate              |

Owner's call (2026-10-13): V1. It names the cause (no rule for how serious a departure from the spec
is, so the model guessed) instead of lowering the odds of a bad guess.

## The fix

`runtime/reviewer/prompt.md`: code that departs from a decision is at least `medium` however
harmless it looks, including a condition the decision rejected kept as an extra guard; a state row
whose tests check only part of what it says is at least `medium`; a departure from the spec is never
`low`. `tests/reviewer.test.sh` checked for the lines first and failed on the old prompt; 4 of 4
mutants (each line removed) are killed.

## How it was run

- Fixture attached read-only (owner's OK); nothing pushed. `prepare.sh` from the W10.6.5 spike
  rebuilt the eval branches; the run-1 commit is the local branch `eval/ns1` (and `eval/ns1-nopr`) at
  `1337cc0`, base `baseline-3`.
- PR words: the PR's body was edited after `1337cc0` (counts, the revert), so
  `../w10-6-5-reviewer-eval/pr/ns1.json` is the body cut back to what that commit does. The no-words
  case isolates the spec judgement.
- `measure.sh <out> <tag> <reps>` runs the eval set and the two run-1 cases, one process per rep;
  `probe.sh` runs the variants (`variants/` has the two `review.sh` diffs; V1 is the shipped prompt
  change). Both drive `../w10-6-5-reviewer-eval/run.sh`, which gained the `ns1` cases, `--reviewer`,
  and unique worktree names (two parallel probe runs collided on git's worktree name and were re-run).
- `flip.sh <dir>...` groups `<case>-r<k>` verdicts: outcomes per case, flips, and each blocking item
  with its severities across runs. `names-plant.sh <records> <dir>...` checks each planted fail's
  blocking items name the plant's file or item (exit 1 on any that don't; tested on a known-bad
  verdict).
- Verdicts: `before/`, `after/` (run ids tagged `-b`), `probe/`. The "after" run is on the prompt as
  merged with `main` (it also gained the PR-screenshots paragraph, W10.6.11 (now W10.6.9d), which none of these
  changes exercise). A first "after" start was stopped and discarded: `main` changed `prompt.md`
  under it.

## Limits

- One real case. The rule is general, but the evidence that it fixes the flip is 10 runs of one
  commit; run 2 (W10.6.10) is the next test.
- Stricter is not free: on that commit the fixed reviewer also raises other test-coverage gaps at
  `medium` in some runs (state rows, AC-8's text-only check of the script). The builder added tests
  for the empty-list row in run 1 (`d26089a`), so they read as real, but a rule like this can turn
  honest small gaps into blocks. The honest set (25/25 pass) shows no
  false alarm on these five changes.
