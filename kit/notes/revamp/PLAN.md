# Revamp plan

Level 1 (workstreams) and Level 2 (epics, one line each). Tasks and their status
live in `workstreams/Wn-*.md`. Evidence lives in [FINDINGS.md](FINDINGS.md).
Adversarial review of this plan: [REVIEW-1.md](REVIEW-1.md).

> **Status after REVIEW-1:** M0 is path-independent and concrete. **M1–M5 are
> provisional** until **D-14 (thin devshop vs incremental revamp)** is decided —
> under the thin path, M1+ is re-planned (deletions move earlier, W5 shrinks, W6
> moves into CI). Planning is rolling-wave: the next milestone is detailed, later
> ones stay coarse.

## Principles

1. **Intent over ceremony.** Keep the artifact chain (product → design → spec →
   tasks → code); spend LLM judgement on _does the change do what the spec says_.
2. **Enforce where the agent can't reach.** Required checks run in CI; the boundary
   is GitHub rulesets + credentials (D-04, D-13). In-VM hooks are feedback.
3. **Deterministic where possible, LLM where necessary**, and LLM verdicts are
   advisory until their precision is measured.
4. **Pinned and portable.** A project runs one explicit devshop version, the same
   way in cloud sessions and locally — mechanism per D-01/D-12 _(assumes a fetchable
   source; see spike W4.2.0)_.
5. **Vendor code isolated, not abstracted prematurely** (D-08): stack-specific parts
   live under `stack/<vendor>/`; a general recipe contract only when a second stack is real.
6. **Right-sized workflows.** Product / fix / patch / hotfix.
7. **One fact, one home.** Docs have one entry point and link instead of restating.
8. **Verified increments**, and **delete as early as the replacement is proven**.
9. **Build the devshop the way it should build apps** — by hand with the target
   process (assumptions first, check first, walking skeleton, whole-picture review),
   then codify only what proved itself ([PROCESS.md § 0](PROCESS.md#0-the-loop--the-same-one-the-devshop-should-run-when-it-builds-apps)).

## Milestones and exit criteria

| #      | Milestone                             | Workstreams                        | Exit criteria (demonstrated, not asserted)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------ | ------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M0** | Stop the bleeding + groundwork        | W0, W3.1, W3.2, W3.3.1–2, W4.1     | Review session held; **D-14, D-12, D-13, D-04, D-09, D-15, D-03** decided; live projects pinned to `v1-frozen` (W0.4); exposed credentials rotated (W0.5); no-bypass rulesets on abra-kadabra/lalista/home-os `main` verified by a rejected direct push (W0.6); gitleaks detects a planted token (W0.7); CLAUDE.md revamp-mode section merged (W0.8); old backlogs triaged (W0.9); baseline in LOG; full bats suite green in GitHub Actions from a clean clone **and** in a cloud session; fixture location decided + scenario runner in CI; [TARGET.md](TARGET.md) + north-star scenario agreed and run once as baseline (W0.10); assumptions the M1 work rests on tested ([ASSUMPTIONS.md](ASSUMPTIONS.md)) |
| **M1** | Close the live holes _(provisional)_  | W1 (filtered), W2 (filtered), W3.3 | Each **M1 finding** below closed with a regression test or scenario; **in-VM** attack scenarios blocked; **outside-VM** scenarios (`--no-verify`, push to `main`, merge without checks) rejected by GitHub on the fixture repo; fresh template project passes its own CI; `v1` security patch cherry-picked; **walking skeleton (W3.5) runs end-to-end on the fixture in a cloud session** and confirms or revises D-14. M1 findings: F-SEC-01/02/03/05/09/12/13/14/15/18, F-HOOK-01/02/03/05, F-REV-01/02/03/04, F-PIPE-01/03/06, F-INFRA-01/02, F-TPL-01/02/03, F-NEW-01/02/04/06/07/12                                                                                                                     |
| **M2** | Cloud-native & pinned _(provisional)_ | W4, W3.3                           | Spike W4.2.0 answered; fixture project at a pinned devshop version runs hooks + a patch-tier change end-to-end in a cloud session; upgrade between two tagged versions (e.g. v2.0.0-rc1 → rc2) demonstrated; rollback to v1 demonstrated; pilot on the project named in D-09                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **M3** | Verifies intent _(provisional)_       | W6, W7                             | Acceptance→test check is a required CI check; spec-conformance reviewer measured on ≥5 seeded violations + ≥5 honest branches (precision/recall recorded; blocking only if both ≥0.8); product/fix/patch tiers each exercised once; gstack ≥1.91.13 with router-shim + `/ship` adapted                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **M4** | Stack isolation _(conditional)_       | W5                                 | Vendor code under `stack/<vendor>/`, core free of vendor names (lint). Full recipe contract only if a real project has committed to a second stack — otherwise M4 closes after the directory move                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **M5** | Lean & legible _(provisional)_        | W8, W9, W3.4                       | README lint: one entry, every other doc reachable from it ≤3 links; link + count lint green; size targets agreed in W0.2.3 met; deletions done. Removal of v1 machinery tracked separately (depends on D-09 migrations), not a blocker for M5                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |

## Capacity and cut line

- Rough effort for the full incremental plan (REVIEW-1 R3, S=0.5/M=1.5/L=4 days,
  corrected sizes): **~100–130 agent-days**, plus **~40 owner-hours** (≈47 epic PRs,
  ~15 decisions, human-only steps, milestone demos). Under D-14 B the estimate is
  expected to drop substantially — to be measured in the D-14 comparison.
- Owner capacity: _to be stated in the review session_ (hours/week), plus an agent
  token/$ budget.
- **Cut line:** M4 beyond the directory move and anything in M5 except deletions and
  the single-entry README are "only if a project needs it".

## Workstreams → epics

Priority is **within a milestone**: P0 first. Size: S ≤½ day · M 1–2 days · L 3+ days.
⚠ = may be throwaway; do only if the risk is live before its replacement lands (see task notes).

### W0 — Stop the bleeding + groundwork · [workstreams/W0-groundwork.md](workstreams/W0-groundwork.md)

- **W0.1** Revamp scaffolding + plan review session — P0 · M0 · S
- **W0.2** Baseline metrics + agreed targets — P0 · M0 · S
- **W0.3** Decisions (D-14, D-12, D-13, D-04, D-09, D-15, D-03 first) — P0 · M0 · S
- **W0.4** Freeze v1 for live projects — P0 · M0 · S
- **W0.5** Rotate exposed credentials (owner) — P0 · M0 · S
- **W0.6** No-bypass rulesets + secret hygiene on the real repos — P0 · M0 · M
- **W0.7** Make gitleaks actually detect secrets — P0 · M0 · S
- **W0.8** CLAUDE.md "revamp mode" section — P0 · M0 · S
- **W0.9** Triage old backlogs (ROADMAP, TODOS, FRICTION-LOG, PLAN rows) — P1 · M0 · S
- **W0.10** Target picture + north-star scenario agreed; baseline run — P0 · M0 · S

### W1 — Security hardening _(provisional; filtered by D-02/D-04/D-14)_ · [workstreams/W1-security.md](workstreams/W1-security.md)

- **W1.1** Git hooks: errexit, public-safe hooks, no env/FS bypass (in-VM hygiene) — P0 · M1 · M
- **W1.2** Reviewer fail-closed + locked-down (or deleted under D-14 B) — P0 · M1 · M
- **W1.3** Container root-escalation paths + secrets out of env (while local is used) — P0 · M1 · L
- **W1.4** Permission rules correct; security docs truthful — P0 · M1 · S
- **W1.5** Template GitHub-side controls + CI secret hygiene + pins — P0 · M1 · M

### W2 — Correctness fixes _(filtered: live-impact only)_ · [workstreams/W2-correctness.md](workstreams/W2-correctness.md)

- **W2.1** Pipeline/skill bugs hurting live projects (parsers, preflight, Rung-2 halt) — P1 · M1 · M
- **W2.2** Infra script bugs (session-start, release) — P1 · M1 · S
- **W2.3** Hook correctness (partial staging) ⚠ — P2 · M1 · S
- **W2.4** Template passes its own CI on a fresh project — P1 · M1 · L

### W3 — Verification foundation · [workstreams/W3-verification.md](workstreams/W3-verification.md)

- **W3.1** Devshop CI (bats + shellcheck) — P0 · M0 · S
- **W3.2** Tests run anywhere (self-locating scripts, deps, no silent skips) — P0 · M0 · M
- **W3.3** Fixture project + scenario runner (M0) + attack suites in-VM / outside-VM (M1) — P0 · M0→M1 · L
- **W3.4** Test-suite triage (prose-grep → behaviour) — P1 · before W6/W8 rewrites · M
- **W3.5** Walking skeleton of the target, re-run after every epic — P0 · M1 · M

### W4 — Cloud-native & pinned distribution _(provisional)_ · [workstreams/W4-cloud-distribution.md](workstreams/W4-cloud-distribution.md)

- **W4.1** Cloud environment for the devshop repo — P0 · M0 · S
- **W4.2** Distribution spike (W4.2.0) + pinned install/upgrade/rollback per D-01 — P1 · M2 · L+
- **W4.3** Project cloud environment + boundary checklist — P1 · M2 · M
- **W4.4** Local parity (shared install script) per D-02 — P1 · M2 · M
- **W4.5** Move project state out of the devshop — P1 · M2 · S
- **W4.6** Devshop release flow without agent commits on main — P1 · M2 · S
- **W4.7** Notifications, routines, PR auto-fix mapping — P2 · M2 · S

### W5 — Stack isolation _(conditional, D-08)_ · [workstreams/W5-recipes.md](workstreams/W5-recipes.md)

- **W5.1** Move vendor code under `stack/<vendor>/`; one `stack:` selector; vendor-name lint — P2 · M4 · M
- **W5.2** Second stack (contract + resolver from two real examples) — only when a project needs it · L
- **W5.3** Adopt existing non-devshop apps (detection + real `/ak-migrate-project`) — only when needed · M

### W6 — Pipeline: verify intent, tiers, orchestration _(provisional)_ · [workstreams/W6-pipeline.md](workstreams/W6-pipeline.md)

- **W6.1** Spec lock + acceptance→test CI check + advisory conformance reviewer (measured) — P1 · M3 · L
- **W6.2** Traceability: tasks `Implements:`, tests ↔ acceptance — P1 · M3 · S
- **W6.3** Workflow tiers (product / fix / patch / hotfix) — P1 · M3 · M
- **W6.4** Gate runner as required CI check; thin skills (D-06) — P1 · M3 · L
- **W6.5** Check taxonomy cleanup (LLM→script, dedupe) — P1 · M3 · M
- **W6.6** Greenfield chain + `/ak-new-project` fixes — P2 · M3 · M
- **W6.7** Resolve skill contradictions (`/ak-spec`, `/ak-implement`) — P1 · M3 · S
- **W6.8** Model routing + native advisor (replace hand-rolled stuck/pre-done reviews if A/B supports it) — P1 · M3, pilot from M1 · S

### W7 — gstack upgrade · [workstreams/W7-gstack.md](workstreams/W7-gstack.md)

- **W7.1** Pinned upgrade to ≥1.91.13 (D-07) — P1 · M3 (may start after M1) · L
- **W7.2** router-shim for `/cso` v3 — P1 · with W7.1 · S
- **W7.3** `/ship` interplay — P1 · with W7.1 · S
- **W7.4** Remove obsolete workarounds — P2 · M3 · S
- **W7.5** Link missing skills; fix design path — P1 · M3 · S
- **W7.6** Decide overlaps — P2 · M3 · S

### W8 — Documentation restructure · [workstreams/W8-docs.md](workstreams/W8-docs.md)

- **W8.1–W8.4, W8.6** single entry, OVERVIEW/WORKFLOWS, guide split, generated counts, CLAUDE.md/skills size — P2 · M5 · M
- **W8.5** Link lint + fix broken links — P1 · M1 · S
- **W8.7** Template/project docs public-safe — P2 · with W4.2 · S

### W9 — Simplify & delete · [workstreams/W9-simplify.md](workstreams/W9-simplify.md)

- **W9.1–W9.5** retire v1 machinery, CLAUDE.md-placement machinery, n/a artifacts, evaluate sandbox, size targets — P2 · M5 (under D-14 B: M1) · M

## Dependencies (critical path)

```
Review session ─▶ D-14/D-12/D-13/D-04/D-09/D-15/D-03 ─▶ W0.4–W0.9 + W3.1/W3.2/W3.3.1–2 + W4.1 ─▶ (M0)
(M0) ─▶ re-plan M1+ per D-14 ─▶ (M1) ─▶ W4.2.0 spike ─▶ D-01 ─▶ W4.2… ─▶ (M2) ─▶ W6 (+W7) ─▶ (M3) ─▶ (M4) ─▶ (M5)
```

## Codification queue

Steps done by hand during the revamp that proved useful and are candidates for the
devshop to automate when it builds apps ([PROCESS.md § 0](PROCESS.md#codification-queue)).
Add a row when a manual step caught a real problem or repeated ≥ 3 times.

| Manual step                                                                                                  | Evidence it's worth it                                               | Automate as                                                                                                     | Status    |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------- |
| Adversarial plan review by independent fresh-context reviewers (fact-check, architecture, plan, feasibility) | REVIEW-1 caught 3 falsified load-bearing assumptions before any code | A pre-build "plan review" step in the product tier (spec + design reviewed adversarially before implementation) | candidate |
| Assumptions register with cheapest falsifying test                                                           | A-01…A-03 falsified in minutes by docs/one command                   | Spec section "Assumptions" + spike step before implementation                                                   | candidate |

## Changelog

| Date       | Change                                                                                                                                                                                                                                                    | Why                                                        |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 2026-10-08 | Plan created from analysis session                                                                                                                                                                                                                        | LOG #1                                                     |
| 2026-10-08 | Adversarial review: M0 expanded with stop-the-bleeding items (W0.4–W0.9); M1+ provisional pending D-14; D-12/D-13/D-14/D-15 added; D-01/D-03/D-04/D-06/D-08/D-09 revised; exit criteria made testable; capacity + cut line; ⚠ throwaway filter; W5 shrunk | [REVIEW-1.md](REVIEW-1.md), LOG #2                         |
| 2026-10-08 | Added the build-loop: ASSUMPTIONS.md, TARGET.md + north-star scenario, walking skeleton W3.5 (M1 exit), whole-picture milestone review, codification queue, principle 9                                                                                   | Owner: test continuously + check the whole picture; LOG #3 |
| 2026-10-08 | Added W6.8 model routing + advisor (O-11/O-12, A-17 validated, A-18 A/B)                                                                                                                                                                                  | Owner proposal evaluated; LOG #4                           |
