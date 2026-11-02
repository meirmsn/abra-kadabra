# Spike: a runner for a skills regression eval

The owner, 2026-11-02: "A simple practical no nonsense way to be confident when we make
modifications to the skills that they are not regressing." Mechanical checks first, model-graded
ones only if needed; not in CI, run when the skills change. This spike answers the one question the
design rests on: can a driver run the devshop's skills, as a branch has them, in a real devshop
session, and what does a case cost? Exit criterion: `spec-check.py --go` executed inside the
runner, and one build case priced in dollars and minutes. **Met.** Raw transcripts were not kept in
the repo: they carry session ids and paths.

## How the runner reaches the skills under test

- The skills reach a session only through the plugin's SessionStart hook
  (`install/plugin/devshop/hooks/dispatch.sh`): it extracts the pinned `runtime/` from the local
  devshop copy (`/opt/devshop.git`) and points `/opt/devshop-current` at it; the plugin's `skills`
  is a symlink into it. A pin may be a commit SHA in that copy.
- So the driver fetches the branch's HEAD into the copy (`refs/eval/head`), writes that SHA to the
  scratch project's `.devshop-version`, and runs `claude -p` there. The child's line said `using
  90a54f5f680d… from project .devshop-version`, and its init listed all seven devshop skills and
  gstack's (`spec`, `office-hours`). No `claude plugin eval` is needed, and the fallback was not
  tried: the real environment, hooks and dcg included, is what the cases should run in.
- Owner turns are `claude -p "<words>" --resume <session id> --output-format stream-json
  --verbose`; each turn's `result` event carries its cost, turns and time, and the init event the
  CLI version (2.1.316 here).
- The child must drop the variables that tie it to the calling session, as `review.sh` does
  (`SESSION_TIE_PATTERNS`); the plain test call without that reported this session's id.

## Results

| Run                                                                                 | What the session did                                                                                                                                                   | Cost  | Time  | Calls refused |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ----- | ------------- |
| Turn 1, a repo with a pin and no devshop files: "Add a --shout flag to cli.js …"   | edited `cli.js` directly; said it skipped the spec and go "because it's this small"; no `devshop:intent`                                                               | $0.41 | 18 s  | 0             |
| Turn 1, the same request in a project placed by `project-files.py` (contract met)   | `devshop:intent`, said the kind, a spec passing `spec-check.py`, a `Plan` helper's adversarial review, the one screen with questions; no code                          | $0.71 | 118 s | 3             |
| Turn 2: "go. Add the CI test step in this change."                                   | `**Go:**` line, `spec-check.py --go` run, `devshop:build`, `stack-homes.sh`, code and tests named `shout-flag AC-<n>`, commit; stopped before `devshop:pr` (no remote) | $1.22 | 89 s  | 6             |

One run each, so nothing here is a rate. The two turn-1 runs differ in the repo, and in the model's
draw; F-NEW-145 logs the first as a sighting.

## What it changes in the design

- **The scratch project must be a real one:** placed by `project-files.py init` (from a release,
  as init refuses a SHA), then its devshop copies re-applied at the branch's SHA (`apply`), so
  `check` and `contract-check.py` pass. A bare repo is not what the skills meet in a project.
- **Permissions shape behaviour:** running the child with permissions bypassed was refused by this
  session's auto mode, so the child ran with `--permission-mode acceptEdits` and this
  `--allowedTools` list: `Skill Read Write Edit Glob Grep Agent TodoWrite`, and Bash for `git:*`,
  `node:*`, `npm test:*`, `/opt/devshop-current/scripts/*`, `python3 /opt/devshop-current/scripts/*`,
  `ls:*` and `cat:*`; each turn also had `--max-budget-usd 8`. The driver itself was not kept: slice
  1 builds the runner as a tested script. The 9 refused calls (`scripts/check-fast.sh`, the project's `scripts/*.py`, a broken-test
  demonstration) made the build skip the fast tier and say so. A case's allowlist is part of the
  case; refused calls are printed and fail a case whose rule needs them.
- **The shared runtime moves:** the child's hook re-points `/opt/devshop-current` for every session
  in the container, the caller's hooks included (F-NEW-144). The runner runs cases one at a time
  and restores the link on exit.
- **Transcripts name the caller:** paths under the calling session's scratch directory carry its
  id, so the runner works under a fresh `mktemp -d` and never writes results into the repo.
- **What `claude -p` can't reach:** `ship.sh` needs a GitHub origin, so `pr` is graded up to its
  body file (`pr-body-check.py`) and the `ship.sh` call; § 3–5 (findings after a pass, subscribe,
  approval and merge, PR comments, `change-metrics.sh post`) stay with a north-star run. The
  `upgrade` skill names the installed plugin's scripts by absolute path, so a branch's change to
  those scripts is not what a case would run; slice 3 has to solve that first.
- **Price:** about $0.70 for an intent case and $2 for a one-flag change through build, against
  $14 and 54 minutes for a real build (ns-2). A 5-run intent tier is about $3.50; build cases run
  fewer times, with a lower bar.

## The brief, checked

- Findings F-NEW-69, 70, 78, 88, 91 and 115 are "rule present, not followed". F-NEW-79 was a
  missing rule (nothing in `runtime/` named the design skills then; `split` § 2 and `ui.md` do
  now). F-NEW-122 was the skill text out of step with TARGET (fixed by PR #170): a review matter,
  not a behaviour a case can catch.
- No skill holds F-NEW-88's rule (a skipped question is asked again): neither `intent` nor `split`
  says it, so a hostile owner who skips a question has no skill line to quote. Adding the rule is
  the owner's call; until then that case can't be graded (rule 6 of the brief).
- The reviewer-eval gaps are as stated: runs 2–3 are not held out (its README says so), the five
  planted types are all spec and test plants, the W10.6.9 severity rule is proven only on the
  prompt's text, `check.sh` needs a clone of an external fixture repo, and there are three suites
  with no single command. Logged as F-NEW-142 and F-NEW-143.

## Finding → case

Each case grades what its rule's skill line says, quoted in the grader.

| Finding   | The skill line now                                                                                                      | Case (owner turns scripted)                                                 | Mechanical grader                                                                          | Slice |
| --------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ----- |
| F-NEW-91  | intent § 4 "before the owner sees it"; § 5 "On "go", record it"                                                         | hostile owner: "go" in the first turn, before any spec                      | no `**Go:**` line before the `Plan` call; `spec-check.py --go` only after the screen        | 1     |
| F-NEW-78  | intent § 2 "A feature gets gstack's `/spec --file-only --no-gate` interview"                                            | a feature-sized request                                                     | a `spec` Skill call before the first write under `specs/`                                  | 1     |
| (trigger) | intent: "Every request starts here"                                                                                     | the spike's small change                                                    | `devshop:intent` loaded before any edit; spec passes `spec-check.py`; no code before go    | 1     |
| F-NEW-88  | none                                                                                                                    | hostile owner who skips one question                                        | none until the owner adds the rule                                                         | —     |
| F-NEW-69  | build § 4 "A later round … is built here under § 3, then `devshop:pr` again"                                             | after the build, an owner turn asking for a code change                     | `devshop:pr` loaded again after the new commit, before `ship.sh`                           | 2     |
| F-NEW-70  | pr § 5 "one that changes a decision or acceptance item is recorded in the spec as changed after the go"; intent § 5      | after the build, an owner question that would change an item if taken as one | the spec's items unchanged in that turn; changed only after a second turn that decides     | 2     |
| F-NEW-79  | split § 2 "A UI with no `DESIGN.md`: the design direction is the second slice"                                           | a whole-app request with a UI, no `DESIGN.md`, approved split              | the roadmap PR's second `R-<n>` entry is the design direction                              | 2     |
| F-NEW-115 | new-project § 2 "Ask the owner for their GitHub user name"                                                              | a new repo with a local bare origin                                         | no `.github/CODEOWNERS` written before an owner turn has given the name                    | 3     |
| F-NEW-122 | (text out of step with TARGET)                                                                                          | none: not behaviour                                                         | —                                                                                          | —     |

Build's own artifacts join slice 2: tests named `<spec> AC-<n>` (`spec-check.py --tests`), the
`STACKS:` line in the PR body's engineering details, `DESIGN.md` read before the first edit of a
page, and the PR body passing `pr-body-check.py`.
