# How we work on the revamp

Small, verified steps on a foundation that is proven at each step. Nothing is
"done" because it was written — only because it was **shown to work**.

## 1. Task lifecycle

```
[ ] todo ──pick──▶ [~] doing ──verify──▶ [x] done (verified)
                      │
                      ├──▶ [!] blocked  (reason + what unblocks it, in the task line)
                      └──▶ [-] dropped  (reason; finding re-mapped or marked won't fix)
```

Status lives **only** on the task line in `workstreams/Wn-*.md`. Epic status is
derived (all tasks `[x]`/`[-]` → epic done). Milestone status is updated in
[README.md](README.md) when its exit criteria are verified.

### Per task

1. **Pick** the next unblocked task (milestone order, then priority). Mark `[~]`.
2. **Write the check first.** Before changing behaviour, write the test/repro
   that demonstrates the problem (red). For security tasks, write the _attack_
   (e.g. `git commit -n` succeeds when it shouldn't).
3. **Change** the minimum needed. Update docs in the same commit if behaviour
   changed (existing devshop rule).
4. **Verify** at the task's declared level (§3). Run it; don't assume.
5. **Record** a LOG entry: task ID, what changed, verification commands + result
   summary, commit SHA, anything surprising.
6. **Mark** `[x]` with the date and commit: `- [x] **W1.1.1** … — 2026-10-09 · abc1234`.
7. **File discoveries** (§4) before moving on.

### Unit of delivery

One **epic per branch/PR** (small epics may share). The PR body lists the task
IDs, the verification evidence, and the findings closed. CI must be green; the
owner approves. One epic per session keeps context fresh; the next session
resumes from README → tracker → LOG tail.

## 2. Definition of done (task)

- [ ] Change committed on the epic branch
- [ ] Verification at the declared level executed **in this session**, evidence in LOG
- [ ] Regression test added where a bug/hole was fixed (red → green recorded)
- [ ] Docs that described the old behaviour updated (or removed) in the same commit
- [ ] Mapped findings updated if their status changed; new discoveries filed
- [ ] Task line marked `[x]` with date + commit

**Epic done** = all tasks done + the epic's "Done when" checked end-to-end once
more after the last task (catches interactions).

**Milestone done** = every epic done + milestone exit criteria demonstrated
(usually on the fixture project, §3 V4) + a short milestone review (§5).

## 3. Verification levels

Each task declares the **minimum** level. Higher is welcome.

| Level | Name            | What it means                                                                               | Typical for                  |
| ----- | --------------- | ------------------------------------------------------------------------------------------- | ---------------------------- |
| V1    | Static          | shellcheck, JSON/YAML parse, link/count lint pass                                           | docs, config                 |
| V2    | Unit            | bats test that fails before the change and passes after                                     | script fixes                 |
| V3    | Scenario        | scripted end-to-end in a scratch git repo (incl. **attack scenarios** that must be blocked) | hooks, guards, sync, install |
| V4    | Fixture dogfood | run on the fixture project (W3.3) in a **cloud session** (and locally if D-02 keeps local)  | pipeline, install, recipes   |
| V5    | Real pilot      | run on a real project (lalista / home-os)                                                   | milestone exits M2, M4       |

Rules:

- A security task is never done below V3.
- "Tests pass" means the **whole** suite in CI (W3.1), not just the new test.
- If a verification can't be run (missing tool/access), the task is `[!] blocked`,
  not done.

## 4. Discoveries and replanning

The plan is expected to change. Change it **explicitly**:

| Discovery                                           | Action                                                                                                                                                                |
| --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Small issue in the code you're touching (< ~15 min) | Fix in the current task; mention in LOG                                                                                                                               |
| New issue elsewhere                                 | Add `F-NEW-nn` to [FINDINGS.md](FINDINGS.md) (found during <task>); map to an existing task or add a new task in the right workstream                                 |
| A task turns out wrong/unnecessary                  | Mark `[-]` with reason; re-map its findings                                                                                                                           |
| Assumption behind an epic/milestone breaks          | Stop. LOG entry + new/revisited decision in [DECISIONS.md](DECISIONS.md) + [PLAN.md § Changelog](PLAN.md#changelog) entry; ask the owner if it changes scope or order |
| A decision needs the owner                          | Add/update in DECISIONS.md and ask; continue with unblocked tasks meanwhile                                                                                           |

Never silently drop scope: every finding ends mapped, fixed, or explicitly `won't fix`.

## 5. Reviews

### Plan review session

Goal: confirm the plan is complete, ordered right, and decisions are made before M0.

1. Read [README.md](README.md) → [PLAN.md](PLAN.md) (≈15 min).
2. **Decide** D-01 … D-06 (others can wait for their milestone). Record outcomes.
3. **Coverage check:** every row in FINDINGS maps to a task or `won't fix`; every
   task cites a finding or a decision (Claude runs this check and reports gaps).
4. **Gaps:** anything you expected that isn't there? (Product goals, projects in
   flight, budget/time constraints, things you dislike about today's workflow.)
5. **Order:** confirm milestone order and P0/P1 within M1.
6. **Process:** confirm verification levels and the epic-per-PR flow.
7. Green-light M0; Claude records outcomes in LOG + PLAN changelog.

### Milestone review (at each M exit)

- Demo the exit criteria (fixture project; real project at M2/M4).
- Re-baseline metrics (W0.2) and compare to targets.
- Walk open findings + decisions; adjust the next milestone; changelog entry.

## 6. Ground rules during the revamp

- **Strangle, don't big-bang.** Build the new path alongside the old; switch over
  per project; delete the old path only after the new one is verified (W9).
- **Freeze the old system:** no new features in v1.x; only security/correctness fixes.
- **Existing projects keep working** at every step (they stay on v1.x until migrated, D-09).
- **The revamp does not run through `/ak-build`** (it's the thing being replaced);
  it uses this lightweight process. The fixed pre-commit hooks (after W1.1) still apply.
- **Measure** before and after (W0.2): complexity targets are part of M5's exit.
