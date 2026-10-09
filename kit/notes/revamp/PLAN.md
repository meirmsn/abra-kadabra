# Revamp plan

Milestones and epics. Tasks and their status live in `workstreams/`. Target picture:
[TARGET.md](TARGET.md). Evidence: [FINDINGS.md](FINDINGS.md). Decisions: [DECISIONS.md](DECISIONS.md).

> **Status after the plan review session (2026-10-09, LOG #5):** target agreed top-down
> (TARGET L0–L2); **D-14 = thin rewrite in a new repo**, frozen v1 as reference, go/no-go at
> the walking skeleton. M0 = stop the bleeding; **M1 = walking skeleton (detailed in
> [W10-v2.md](workstreams/W10-v2.md))**; M2–M4 coarse. The v1 workstreams W1–W9 are
> superseded (kept as reference; findings dispositioned by W10.3.3).

## Principles

1. **Intent over ceremony.** Every change is checked against the product intent and the spec; ceremony only where it buys that.
2. **Enforce where the agent can't reach.** GitHub rules, CI, credentials, protected deploys (D-04). In-session checks are feedback.
3. **PR CI stays plain** — tests and deterministic checks only; the adversarial review runs independently of the builder, in-session (D-06).
4. **No skip knobs.** A check passes or the work stops and asks the owner; "not done" is a finding, not a note.
5. **Pinned and portable.** A project pins a devshop version; near-zero footprint in the project (D-01, D-12).
6. **One home per stack**, added when a real project needs it (D-08).
7. **Lean, not minimal.** Every part earns its place; one fact, one home; reliability beats line count.
8. **Assumptions first, walking skeleton, whole-picture review** — and build the devshop the way it should build apps ([PROCESS.md § 0](PROCESS.md#0-the-loop--the-same-one-the-devshop-should-run-when-it-builds-apps)).

## Milestones and exit criteria

| #      | Milestone                      | Work                                    | Exit criteria (demonstrated, not asserted)                                                                                                                                                                                                                                                                             |
| ------ | ------------------------------ | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M0** | Stop the bleeding + groundwork | W0                                      | Review session held, decisions recorded (done 2026-10-09); exposed credentials rotated (W0.5); history scanned with a working gitleaks config (W0.7); no-bypass rulesets on abra-kadabra + lalista verified by rejected pushes, home-os archived (W0.6); `v1-final` tagged (W0.4); CLAUDE.md revamp note merged (W0.8) |
| **M1** | Walking skeleton → go/no-go    | [W10](workstreams/W10-v2.md) (detailed) | Spikes answered (W10.1); L3 agreed + north-star rewritten (W10.2); lessons harvest done and every finding dispositioned (W10.3); new repo + fixture with plain required CI and rulesets (W10.4–5); skeleton runs end to end in a fresh cloud session and is recorded (W10.6); owner go/no-go (W10.7)                   |
| **M2** | Pilot: lalista web on v2       | W10 (coarse)                            | All nine pillars at working strength for web + Supabase + Vercel; lalista works only through v2; north-star re-run green                                                                                                                                                                                               |
| **M3** | iOS stack + Mac                | W10 (coarse)                            | Dedicated Mac set up (Claude non-admin); iOS stack home; lalista's voice-input iOS work built through v2 with a native preview substitute and the version → testing-track flow                                                                                                                                         |
| **M4** | Complete & retire v1           | W10 (coarse)                            | Reviewer measured; production-data grant mechanism; lessons loop proven; docs lean; v1 archived read-only                                                                                                                                                                                                              |

## Capacity and pacing

- **Pacing rule (owner, 2026-10-09):** at most ~2 devshop PRs waiting on the owner at once; the agent starts new work only when that queue has room. No hours target.
- Rough effort (agent-days, to be re-estimated at each milestone review): M0 ~3 (+ owner steps) · M1 ~15–20 · M2 ~15–20 · M3 ~15 · M4 ~10. Calendar time follows the owner's review pace.

## Workstreams → epics

### W0 — Stop the bleeding + groundwork · [workstreams/W0-groundwork.md](workstreams/W0-groundwork.md)

- **W0.1** Scaffolding + plan review — done · **W0.2** targets — done · **W0.3** decisions — done
- **W0.5** Rotate credentials (owner) — P0 · M0 · S
- **W0.7** History secret scan with a working config — P0 · M0 · S
- **W0.6** No-bypass rulesets on abra-kadabra + lalista; archive home-os — P0 · M0 · M
- **W0.4** Tag `v1-final` — P0 · M0 · S
- **W0.8** CLAUDE.md revamp-mode note — P0 · M0 · S

### W10 — The new devshop (v2) · [workstreams/W10-v2.md](workstreams/W10-v2.md)

- **W10.1** Spikes: agent identity, private-repo distribution, rulesets, reviewer stability — P0 · M1 · S each
- **W10.2** L3 design pass + north-star rewrite (owner) — P0 · M1 · M
- **W10.3** Lessons harvest + findings disposition — P0 · M1 · M
- **W10.4** New repo bootstrap — P0 · M1 · S
- **W10.5** Fixture project — P0 · M1 · S
- **W10.6** Skeleton end to end — P0 · M1 · M
- **W10.7** Go/no-go (owner) — P0 · M1 · S

### W1–W9 — v1 workstreams (superseded by D-14)

[W1](workstreams/W1-security.md) · [W2](workstreams/W2-correctness.md) · [W3](workstreams/W3-verification.md) · [W4](workstreams/W4-cloud-distribution.md) · [W5](workstreams/W5-recipes.md) · [W6](workstreams/W6-pipeline.md) · [W7](workstreams/W7-gstack.md) · [W8](workstreams/W8-docs.md) · [W9](workstreams/W9-simplify.md) — tasks marked `[-]`; kept as reference for the harvest (W10.3).

## Dependencies (critical path)

```
M0: W0.5 → W0.7 → W0.6 → W0.4 → W0.8
M1: W10.1 spikes ─┬─▶ W10.4 repo ─┐
    W10.2 L3 ─────┤               ├─▶ W10.6 skeleton ─▶ W10.7 go/no-go ─▶ M2 pilot ─▶ M3 iOS ─▶ M4
    W10.3 harvest ┘   W10.5 fixture┘
```

## Codification queue

Steps done by hand during the revamp that proved useful and are candidates for the
devshop to automate when it builds apps ([PROCESS.md § 0](PROCESS.md#codification-queue)).
Add a row when a manual step caught a real problem or repeated ≥ 3 times.

| Manual step                                                                                                  | Evidence it's worth it                                               | Automate as                                                                                                     | Status    |
| ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------- |
| Adversarial plan review by independent fresh-context reviewers (fact-check, architecture, plan, feasibility) | REVIEW-1 caught 3 falsified load-bearing assumptions before any code | A pre-build "plan review" step in the product tier (spec + design reviewed adversarially before implementation) | candidate |
| Assumptions register with cheapest falsifying test                                                           | A-01…A-03 falsified in minutes by docs/one command                   | Spec section "Assumptions" + spike step before implementation                                                   | candidate |
| Top-down alignment (one sentence → paragraph → one line per pillar → details) before decisions               | Session 5: dissolved D-14/D-04/D-02/D-08/D-11 into agreed pillars    | The Intent step for apps/big features: agree L0/L1 with the owner before the spec                               | candidate |

## Changelog

| Date       | Change                                                                                                                                                                                                                                                                                                                                                                                                                    | Why                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 2026-10-08 | Plan created from analysis session                                                                                                                                                                                                                                                                                                                                                                                        | LOG #1                                                     |
| 2026-10-08 | Adversarial review: M0 expanded with stop-the-bleeding items (W0.4–W0.9); M1+ provisional pending D-14; D-12/D-13/D-14/D-15 added; D-01/D-03/D-04/D-06/D-08/D-09 revised; exit criteria made testable; capacity + cut line; ⚠ throwaway filter; W5 shrunk                                                                                                                                                                 | [REVIEW-1.md](REVIEW-1.md), LOG #2                         |
| 2026-10-08 | Added the build-loop: ASSUMPTIONS.md, TARGET.md + north-star scenario, walking skeleton W3.5 (M1 exit), whole-picture milestone review, codification queue, principle 9                                                                                                                                                                                                                                                   | Owner: test continuously + check the whole picture; LOG #3 |
| 2026-10-08 | Added W6.8 model routing + advisor (O-11/O-12, A-17 validated, A-18 A/B)                                                                                                                                                                                                                                                                                                                                                  | Owner proposal evaluated; LOG #4                           |
| 2026-10-09 | Plan review session: target agreed top-down (TARGET L0–L2); D-14 thin rewrite in a new repo; D-12/D-13/D-04/D-09/D-15/D-03/D-02/D-06/D-08 decided, D-11 obsolete; M0 reordered (credentials → history scan → rulesets → tag → CLAUDE.md); M1+ re-planned as W10 (M1 walking skeleton + go/no-go detailed; M2 pilot lalista web, M3 iOS + Mac, M4 retire v1 coarse); W1–W9 superseded; pacing rule replaces capacity hours | LOG #5                                                     |
