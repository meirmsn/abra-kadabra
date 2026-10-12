# How we work on the revamp

Small, verified steps. Nothing is "done" because it was written — only because it
was **shown to work**. Kept deliberately light (REVIEW-1: the old devshop drowned
in ceremony; the revamp process must not repeat that). If D-15 moves tracking to
GitHub Issues, §1–§2 apply to issues instead of markdown lines.

## 0. The loop — the same one the devshop should run when it builds apps

We build the devshop **by hand with the process we want it to automate**, then codify
only the steps that proved their worth. Four habits, at four scales:

| Scale     | Habit                                                                                                                                  | Artifact                                             |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| Decision  | **Assumptions first** — falsify the cheapest load-bearing assumption before building on it                                             | [ASSUMPTIONS.md](ASSUMPTIONS.md)                     |
| Task      | **Check first** — failing test / repro / attack before the change; run it after                                                        | PR evidence (§1)                                     |
| Milestone | **Walking skeleton, then thicken** — the thinnest end-to-end slice of the target runs early; each milestone thickens it and re-runs it | W3.5; north-star scenario in [TARGET.md](TARGET.md)  |
| Direction | **Whole-picture check** — does the system we have still lead to the target, and is the target still right?                             | Milestone review (§5) against [TARGET.md](TARGET.md) |

### Assumptions first

Before an epic builds on an assumption marked `untested` in ASSUMPTIONS.md, run the
cheapest experiment that could falsify it (usually ≤ 30 min, often a doc read + one
command in a cloud session). Falsified → replan (§4), never work around silently.
New design choices that rest on something unobserved get a new `A-nn` row.

### Walking skeleton

Within M1 (W3.5), the thinnest version of the **target** devshop runs end-to-end on the
fixture in a cloud session: pinned install (crude is fine) → one skill → a change →
PR → required CI gate (incl. acceptance→test check) → GitHub rules enforce → you
merge. Everything after thickens a part of that path and **re-runs the whole
skeleton** before the epic is done. A broken skeleton blocks new work.

### Codification queue

When a step done by hand during the revamp proves useful (it caught a real problem,
or it repeated ≥ 3 times), add it to [PLAN.md § Codification queue](PLAN.md#codification-queue)
as a candidate for the devshop to automate for apps. Don't codify on the first
occurrence — that's how today's devshop grew 90k words of skills from one-off incidents.

## 1. Task lifecycle

```
[ ] todo ──pick──▶ [~] doing ──verify──▶ [x] done (verified)
                      ├──▶ [!] blocked  (reason + what unblocks it)
                      └──▶ [-] dropped / obsolete by <task> (reason; findings re-mapped)
```

- Status lives on the task line in `workstreams/Wn-*.md` (single source). Milestone
  status in README is updated only at milestone exit.
- **Rolling-wave planning:** the current and next milestone have concrete tasks with
  done-when; later milestones stay coarse and are refined when they become next.
- **Picking:** next = first unblocked `[ ]` task in the lowest open milestone, P0
  before P1. ⚠ tasks are skipped unless their live-risk condition holds.
- **Parallel sessions:** mark `[~]` on `main` (tiny PR or direct note in the PR
  description of the claiming session) before starting, so two sessions don't pick
  the same task; prefer one active epic at a time.

### Per task

1. Mark `[~]`.
2. **Write the check first** (failing test, repro, or attack scenario).
3. Change the minimum; update docs that described the old behaviour in the same commit.
4. **Run the verification** (§3) in this session.
5. Mark `[x] — date · PR #n`; file discoveries (§4).

### Unit of delivery

One epic per branch/PR (small epics may share). The **PR body is the evidence
record**: task IDs, what was verified and how (commands + result summary), findings
closed. CI must be green; owner merges. PRs touching security tooling (W0.5–W0.7,
W1) also get a `/security-review` pass.

## 2. Definition of done

- **Task:** check written first; verification run and summarised in the PR; regression
  test kept where a bug/hole was fixed; docs updated; task line marked.
- **Epic:** all tasks done/dropped + its "Done when" re-checked once after the last task.
- **Milestone:** exit criteria in [PLAN.md](PLAN.md) demonstrated + a short review (§5).

## 3. Verification levels

| Level        | Means                                                                                                                                                                        | Typical for                      |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| **Static**   | lint, parse, link/count checks                                                                                                                                               | docs, config                     |
| **Test**     | automated test in CI that fails before the change and passes after (bats, scenario runner)                                                                                   | scripts, hooks                   |
| **Scenario** | scripted end-to-end in scratch repos; **attack scenarios** for security: in-VM ones must be blocked by hooks/scripts, outside-VM ones rejected by GitHub on the fixture repo | hooks, guards, install, rulesets |
| **Dogfood**  | run on the fixture project in a cloud session (and locally if D-02 keeps local); real-project pilot at M2                                                                    | pipeline, distribution           |

The existing V1–V5 labels in workstreams map as: V1 = Static, V2 = Test, V3 = Scenario,
V4/V5 = Dogfood. Rules:

- Security tasks need at least **Scenario**.
- "Tests pass" means the whole suite in CI.
- `[owner machine]` marks verification that needs the local devcontainer; until it is
  run there the task is `[!] blocked`, not done.
- If a verification can't be run, the task is `[!] blocked`, not done.

## 4. Discoveries and replanning

| Discovery                                  | Action                                                                                                                                        |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Small issue in code you're touching        | Fix in the current task; mention in the PR                                                                                                    |
| New issue elsewhere                        | `F-NEW-nn` row in [FINDINGS.md](FINDINGS.md) mapped to a task (or a new task)                                                                 |
| Task wrong/unnecessary                     | `[-]` with reason; re-map its findings                                                                                                        |
| Assumption behind an epic/milestone breaks | Stop; revisit/add a decision in [DECISIONS.md](DECISIONS.md) + [PLAN.md § Changelog](PLAN.md#changelog); ask the owner if scope/order changes |

Never silently drop scope: every finding ends fixed, mapped, or `won't fix` with a reason.
[LOG.md](LOG.md) gets an entry **per work session or milestone**, not per task:
what moved, surprises, next.

## 5. Reviews

### Plan review session (next)

_Held 2026-10-09 (LOG #5), run top-down through [TARGET.md](TARGET.md) instead of decision by decision — prefer that shape next time._

1. Read [README.md](README.md) → [REVIEW-1.md](REVIEW-1.md) → [PLAN.md](PLAN.md).
2. Decide **D-14** (thin vs incremental — half-day comparison), **D-12**, **D-13**,
   **D-04**, **D-09**, **D-15**, **D-03**; state owner capacity + budget (W0.2.3).
3. Gaps: anything expected that isn't there (projects in flight, deadlines, dislikes).
4. Green-light M0 "stop the bleeding" items (W0.4–W0.7) — useful under either path.
5. Claude re-plans M1+ per D-14, records outcomes in LOG + PLAN changelog, re-runs the
   scripted coverage check.

### Milestone review (each M exit) — the whole-picture check

1. **Re-run the north-star scenario** ([TARGET.md](TARGET.md)) on the fixture in a cloud
   session; record what worked, what broke, and owner touchpoints vs target.
2. **Assumptions:** any still `untested` that the next milestone builds on? Test them first.
3. **Direction:** does what we have still lead to TARGET.md? Is TARGET.md still right
   given what we learned? Changes go to DECISIONS + PLAN changelog.
4. Re-baseline metrics (W0.2); walk open findings; detail the next milestone.
5. A fresh adversarial review (like REVIEW-1) before M2 and M3, when architecture lands.

## 6. Ground rules during the revamp

- **Rewrite beside v1, don't patch it** (D-14): v1 is the reference; v2 is proven on a fixture, then on the pilot.
- **v1 takes security fixes only** (`v1-final`, W0.4); lalista is paused until it pilots v2 (D-09).
- **The revamp does not run through `/ak-build`** (it's being replaced); CLAUDE.md's
  revamp-mode section (W0.8) says so.
- **CI is the only gate whose result the agent can't change**; PR CI stays plain (D-06).
- **Pacing:** no cap on devshop PRs waiting on the owner (the ~2 cap was removed 2026-10-12, LOG #26).
- **Measure** before and after (W0.2).
