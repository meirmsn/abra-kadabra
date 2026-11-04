# The skills eval

How to know a change to the devshop's skills (`runtime/skills/*`, the plugin's `upgrade`) didn't
make them worse ([spec](../../specs/skills-eval.md), R-16; how it was priced:
[the spike](../../kit/notes/revamp/spikes/skills-eval-runner/README.md)). Two tiers.

- **Free, in CI:** `scripts/skills-check.py --rules tests/skills-eval/rules.txt`, run by
  `tests/skills-check.test.sh`. Every section reference between the skills (and into the
  guidelines) must name a heading that exists, and every line in [rules.txt](rules.txt) must still
  be in its skill. A PR that renumbers a section or drops or rewords a listed rule fails until it
  fixes the reference or edits the list, so the owner sees which rule moved.
- **Model, by hand:** `tests/skills-eval.sh [runs] [case]` runs the real skills, as the checked-out
  commit has them, in a real devshop session on a scratch project, and grades each run with
  [grade.py](grade.py). Run it after committing a skill change, in a cloud session where `claude`
  is logged in. Not in CI (no LLM jobs there, D-06). It moves the container's shared runtime link
  while a case runs (F-NEW-144), so don't run other devshop work in the same container meanwhile;
  the link is restored at the end, and after a crash at the next run.

A PR that changes a skill gives the free tier's result (CI) and the model tier's lines for the cases
of the skills it touches (CLAUDE.md). Today only `intent` has a case.

## Cases

The scratch project is the [greeter app](../fixtures/skills-eval/greeter/README.md), placed fresh
for each run; [grade.py](grade.py)'s tests run on the hand-written streams in
`tests/fixtures/skills-eval/streams/` and [a spec that passes](../fixtures/skills-eval/shout-flag.md).

| Case      | Owner turns                                                            | Passes when                                                                                                            | Cost, time (one run) |
| --------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `trigger` | "Add a --shout flag to cli.js that prints the greeting in upper case." | `devshop:intent` is loaded before any Write or Edit; nothing outside `specs/` changed; the spec passes `spec-check.py` | about $0.50, 1.5 min |

Outcomes: PASS, FAIL, or CNR (could-not-run: the session ran another devshop version, didn't start,
didn't finish, or its stream can't be read; never a pass). Exit 1 on any FAIL, else 2 on any CNR.

## Past findings → what catches them

| Finding   | What went wrong                                                         | Caught by                                                                                             |
| --------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| F-NEW-91  | the go recorded before the spec existed, the spec review skipped        | rules.txt (intent § 4–5 lines); a case is R-17                                                        |
| F-NEW-78  | the `/spec` interview skipped on a feature                              | rules.txt (intent § 2 line); a case is R-17                                                           |
| F-NEW-88  | a skipped question filled with a default                                | nothing yet: no skill holds the rule (R-19)                                                           |
| F-NEW-69  | a later round skipped the hand-over to `devshop:pr`                     | rules.txt (build § 4 line); a case needs a reviewer fail, which needs GitHub                          |
| F-NEW-70  | an owner question applied as a spec change                              | rules.txt (pr § 5 line); no case: the owner changed the rule on 2026-10-16, and it needs a PR comment |
| F-NEW-79  | no `DESIGN.md`, no design direction                                     | rules.txt (split § 2 line); a case is R-18                                                            |
| F-NEW-115 | the GitHub user name for `CODEOWNERS` filled in, not asked              | rules.txt (new-project § 2 line); no case: the runner's pin stops `new-project`                       |
| F-NEW-122 | `intent`'s text out of step with TARGET                                 | nothing: a review matter, not behaviour                                                               |
| (any)     | a section renumbered or a heading renamed under another skill's pointer | the section-reference check                                                                           |
| (trigger) | a request handled without `intent`                                      | the `trigger` case                                                                                    |

## Coverage per rule line

Each line of [rules.txt](rules.txt), and whether a run shows it followed, not only present.

| Skill           | Rule line (why)                                | Present (free tier) | Followed (model tier)                       |
| --------------- | ---------------------------------------------- | ------------------- | ------------------------------------------- |
| intent          | "Every request starts here" (trigger)          | checked             | 3 of 3 with `--plugin-dir` only (F-NEW-147) |
| intent          | "nothing is built before the "go"" (trigger)   | checked             | 3 of 3 with `--plugin-dir` only (F-NEW-147) |
| intent          | "Run … spec-check.py … until it passes"        | checked             | 3 of 3 with `--plugin-dir` only (F-NEW-147) |
| intent          | the kind said in the first reply               | checked             | no case                                     |
| intent          | the `/spec` interview for a feature (F-NEW-78) | checked             | R-17                                        |
| intent          | the `Plan` helper's review (F-NEW-91)          | checked             | R-17                                        |
| intent          | the go on the `**Go:**` line (F-NEW-91)        | checked             | R-17                                        |
| build           | tests named `<spec> AC-<n>`                    | checked             | R-18                                        |
| build           | the `STACKS:` line in the PR                   | checked             | R-18                                        |
| build           | `DESIGN.md` read first for a page change       | checked             | no case                                     |
| build           | the hand-over to `devshop:pr`                  | checked             | no case (needs GitHub)                      |
| build           | a later round back to `devshop:pr` (F-NEW-69)  | checked             | no case (needs GitHub)                      |
| pr              | `ship.sh` through the reviewer                 | checked             | no case (needs GitHub)                      |
| pr              | a spec change after the go recorded (F-NEW-70) | checked             | no case                                     |
| pr              | subscribe to the PR                            | checked             | no case (needs GitHub)                      |
| split           | the walking skeleton first                     | checked             | no case                                     |
| split           | the design direction second (F-NEW-79)         | checked             | R-18                                        |
| new-project     | ask for the GitHub user name (F-NEW-115)       | checked             | no case                                     |
| new-project     | never pin a branch or a SHA                    | checked             | no case                                     |
| devshop-version | quote the `DEVSHOP:` line word for word        | checked             | no case                                     |
| upgrade         | show the plan first                            | checked             | no case                                     |
| upgrade         | hand the PR to `devshop:pr`                    | checked             | no case                                     |

## The first run

2026-11-04, on this repo's commit `af9efff82278`, Claude Code 2.1.318, the CLI's default model,
permission mode `auto`.

| Run                                                                                              | Result                                                                                                                                                                                     | Cost  |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| 3 × `trigger`, the plugin as installed                                                           | 3 CNR: "devshop:intent isn't among the session's skills". The installed plugin loads none of the runtime's skills on this CLI (F-NEW-147); the first session built the change with no spec | $1.17 |
| 3 × `trigger`, with `--plugin-dir /opt/devshop-plugin/devshop` added by hand (not in the runner) | 3 PASS, 90–108 s each, 0 refused calls                                                                                                                                                     | $1.49 |
| 1 × a plant: intent's first line says "edit the code directly", the rest unchanged               | PASS: the rest of the skill still says spec first, and the session followed it. One contradictory line is below what this case can see                                                     | $0.44 |
| 1 × a plant: intent's whole body says "edit the code directly"                                   | FAIL: "changed outside specs/ before any go: README.md, cli.js, tests/cli.test.js"                                                                                                         | $0.23 |

The last three rows ran with one line added to the runner by hand, passing `--plugin-dir`, so the
skills loaded despite F-NEW-147; whether the runner keeps that option is the owner's call.

What it taught: the model tier's first find was not a skill edit but the environment, a CLI update
that drops the skills (logged high). The trigger case catches a skill that stops asking for a spec,
not a single stray line; the free tier is what catches a deleted or reworded line. The shared link
was back at its start after every run.
