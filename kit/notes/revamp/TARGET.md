# Target picture (draft — finalised with D-14)

One page: what the devshop should be when the revamp is done, and the scenario that
proves it. Every milestone review checks progress against this page and whether the
page itself is still right ([PROCESS.md § 5](PROCESS.md#milestone-review-each-m-exit--the-whole-picture-check)).

## What the owner experiences

1. Writes rough notes (or talks through an idea) for a project.
2. Claude turns them into product + design intent, then a spec with **decisions and
   acceptance criteria the owner approves** (locked thereafter).
3. Claude builds it — in a cloud session, unattended — using the right-sized tier
   (product / fix / patch / hotfix).
4. The PR arrives with: what changed, evidence that each acceptance item is tested,
   an advisory conformance review, green CI.
5. Owner reviews and merges; deploy happens via a protected environment the owner approves.
6. Owner never has to babysit tooling, and Claude **cannot** ship around the checks.

## What's true underneath

| Property                       | How                                                                                                                                  | Decision         |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------- |
| Agent can't weaken guardrails  | GitHub rulesets (no bypass), required CI, main-only environment secrets, least-privilege tokens, separate agent identity if possible | D-04, D-13       |
| Intent is checked, not assumed | Owner-locked decisions/acceptance; acceptance→test check in CI; advisory LLM conformance review (blocking only if measured ≥0.8)     | W6.1             |
| Same everywhere                | Pinned devshop version per project; cloud sessions first, local supported                                                            | D-01, D-02, D-12 |
| Any stack the owner picks      | Vendor code isolated; second stack added when a real project needs it                                                                | D-08             |
| Small enough to stay coherent  | Few short skills; one-entry docs; size targets                                                                                       | D-14, W0.2.3     |
| Learns without bloating        | Lessons → codification queue → automated only when proven                                                                            | PROCESS § 0      |

## North-star scenario (re-run at every milestone review)

On the fixture project, in a fresh cloud session:

1. Start from a two-line idea: "add a page that lists X with filter Y".
2. Spec with 2 decisions + 3 acceptance items; owner approves (lock recorded).
3. Implementation lands as a PR from the agent; CI runs the gate runner and the
   acceptance→test check; one acceptance item deliberately left untested on a first
   pass must **fail CI**.
4. Fix, re-run, green; advisory conformance comment present.
5. Attempts to bypass (`--no-verify`, direct push to `main`, editing a locked spec
   section, reading a deploy secret from a PR workflow) are **rejected**.
6. Owner merges; deploy waits for owner approval in the environment.
7. Record: wall-clock, owner touchpoints, tokens/CI minutes, anything manual.

At M0 most steps fail or are manual — that's the baseline. Each milestone should
turn more steps green; the walking skeleton (W3.5) makes the whole path exist early,
however crude.
