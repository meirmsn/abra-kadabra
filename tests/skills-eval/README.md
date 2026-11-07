# The skills eval

How to know a change to the devshop's skills (`runtime/skills/*`) didn't make them worse
([spec](../../specs/skills-eval.md), R-16; how it was priced:
[the spike](../../kit/notes/revamp/spikes/skills-eval-runner/README.md)). Two tiers.

- **Free, in CI:** `scripts/skills-check.py`, run by `tests/skills-check.test.sh`. Every section
  reference between the skills (`ak:pr` § 3, `intent`, step 5) and into the guidelines must name a
  heading that exists, so renumbering a section or renaming a heading another skill points at fails.
  It checks no wording.
- **Model, by hand:** `tests/skills-eval.sh [runs] [case]` runs the real skills, as the checked-out
  commit has them, in a real devshop session on a scratch project, and grades each run with
  [grade.py](grade.py) from what the session did and what it left in the repo. Run it after
  committing a skill change, in a cloud session where `claude` is logged in. Not in CI (no LLM jobs
  there, D-06). Each line shows the run's cost, so you can see what a check of a skill change costs.
  It moves the container's shared runtime link while a case runs (F-NEW-144), so don't run other
  devshop work in the same container meanwhile; the link is restored at the end, and after a crash
  at the next run.

A PR that changes a skill gives the free tier's result (CI) and the model tier's lines for the cases
of the skills it touches (CLAUDE.md). Today only `intent` has a case.

## Cases

The scratch project is the [greeter app](../fixtures/skills-eval/greeter/README.md), placed fresh
for each run; [grade.py](grade.py)'s tests run on the hand-written streams in
`tests/fixtures/skills-eval/streams/` and [a spec that passes](../fixtures/skills-eval/shout-flag.md).

| Case      | Owner turns                                                            | Passes when                                                                                                       | Cost, time (one run) |
| --------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------- |
| `trigger` | "Add a --shout flag to cli.js that prints the greeting in upper case." | `ak:intent` is loaded before any Write or Edit; nothing outside `specs/` changed; the spec passes `spec-check.py` | about $0.50, 1.5 min |

Outcomes: PASS, FAIL, or CNR (could-not-run: the session ran another devshop version, didn't load
`ak:intent`, didn't start, didn't finish, or its stream can't be read; never a pass). Exit 1 on any
FAIL, else 2 on any CNR.

## Past findings → what catches them

| Finding   | What went wrong                                                         | Caught by                                                                    |
| --------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| F-NEW-147 | the installed plugin loaded none of the runtime's skills (a CLI update) | the `trigger` case: could-not-run, "intent isn't among the session's skills" |
| (trigger) | a request handled without `intent`                                      | the `trigger` case                                                           |
| (any)     | a section renumbered or a heading renamed under another skill's pointer | the free tier                                                                |
| F-NEW-91  | the go recorded before the spec existed, the spec review skipped        | a case is R-17                                                               |
| F-NEW-78  | the `/spec` interview skipped on a feature                              | a case is R-17                                                               |
| F-NEW-79  | no `DESIGN.md`, no design direction                                     | a case is R-18                                                               |
| F-NEW-88  | a skipped question filled with a default                                | nothing yet: no skill holds the rule (R-19)                                  |
| F-NEW-69  | a later round skipped the hand-over to `ak:pr`                          | no case: it needs a reviewer fail, which needs GitHub                        |
| F-NEW-70  | an owner question applied as a spec change                              | no case: the owner changed the rule on 2026-10-16, and it needs a PR comment |
| F-NEW-115 | the GitHub user name for `CODEOWNERS` filled in, not asked              | no case: the runner's pin stops `new-project`                                |
| F-NEW-122 | `intent`'s text out of step with TARGET                                 | nothing: a review matter, not behaviour                                      |

## Coverage per rule

The rules a case shows followed, with the case's latest pass rate; every other rule has no case yet.

| Skill  | Rule                                                   | Case      | Followed                  |
| ------ | ------------------------------------------------------ | --------- | ------------------------- |
| intent | "Every request starts here": `ak:intent` loaded first  | `trigger` | see the latest run, below |
| intent | § 3, "nothing is built before the "go""                | `trigger` | see the latest run, below |
| intent | § 3, run `spec-check.py` on the spec "until it passes" | `trigger` | see the latest run, below |

## Runs

RUNS
