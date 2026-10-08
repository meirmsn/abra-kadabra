# W0 — Groundwork

Make the revamp trackable and measurable before changing anything.
Status markers: `[ ]` todo · `[~]` doing · `[x]` done (verified) · `[!]` blocked · `[-]` dropped.
Format of a done line: `- [x] **ID** text — YYYY-MM-DD · <commit>`.

## W0.1 Revamp scaffolding + plan review — P0 · M0 · S

Done when: the plan docs exist, the owner has reviewed them, and the coverage check passed.

- [x] **W0.1.1** Create `kit/notes/revamp/` (README, PLAN, FINDINGS, DECISIONS, PROCESS, LOG, workstreams) — verify V1: links resolve — 2026-10-08 · (this commit)
- [x] **W0.1.2** Add a pointer to the revamp in root `PLAN.md § Active` so session-start/`/ak-status` surface it — V1 — 2026-10-08 · (this commit)
- [ ] **W0.1.3** Plan review session with the owner ([PROCESS.md § Plan review session](../PROCESS.md#plan-review-session)); record outcomes in LOG + PLAN changelog
- [ ] **W0.1.4** Coverage check: every FINDINGS row → task or `won't fix`; every task → finding/decision; report gaps — V1 (scripted grep, output in LOG)

## W0.2 Baseline metrics + targets — P0 · M0 · S

Done when: a dated baseline table is in LOG and targets are agreed for M5.

- [ ] **W0.2.1** Record baseline: bats count/pass/fail/skip + runtime; words in always-loaded context (CLAUDE.md + injected files); words per devshop skill; total guide words; number of gates; `specs/` file count — V1 (commands in LOG)
- [ ] **W0.2.2** Record one timed end-to-end run of today's pipeline on a tiny change (time-to-PR, tool calls, tokens if visible) — V4 once fixture exists; else mark from history
- [ ] **W0.2.3** Agree targets (proposal: always-loaded context ≤ 3k words; largest skill ≤ 4k words; guides ≤ 40k words total; gates per patch-tier change ≤ 5; bats green in CI ≤ 10 min)

## W0.3 Decisions — P0 · M0 · S

Done when: D-01…D-06 have outcomes in [DECISIONS.md](../DECISIONS.md).

- [ ] **W0.3.1** D-01 distribution model
- [ ] **W0.3.2** D-02 local devcontainer fate
- [ ] **W0.3.3** D-03 devshop landing flow (and update CLAUDE.md "no PRs on devshop" accordingly)
- [ ] **W0.3.4** D-04 security boundary statement
- [ ] **W0.3.5** D-05 plan tier assumptions
- [ ] **W0.3.6** D-06 orchestration technology
