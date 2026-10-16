# Revamp plan

Milestones and epics. Tasks and their status live in `workstreams/`. Target picture:
[TARGET.md](TARGET.md). Evidence: [FINDINGS.md](FINDINGS.md). Decisions: [DECISIONS.md](DECISIONS.md).

> **Status after the plan review session (2026-10-09, LOG #5):** target agreed top-down
> (TARGET L0–L2); **D-14 = thin rewrite in this repo** (revisited 2026-10-10: no new repo), `v1-final` tag as reference, go/no-go at
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

| #      | Milestone                                             | Work                                    | Exit criteria (demonstrated, not asserted)                                                                                                                                                                                                                                                                                                               |
| ------ | ----------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M0** | Stop the bleeding + groundwork                        | W0                                      | Review session held, decisions recorded (done 2026-10-09); history scanned with a working gitleaks config (W0.7); no-bypass protection on abra-kadabra + lalista verified by rejected pushes (W0.6); `v1-final` tagged (W0.4); CLAUDE.md revamp note merged (W0.8). Owner steps W0.5.2/W0.5.3/W0.6.2/W0.6.3 moved to M4                                  |
| **M1** | Walking skeleton → go/no-go                           | [W10](workstreams/W10-v2.md) (detailed) | **Done 2026-10-15 (D-17):** declared met on north-star runs 1 and 2 under D-16's rule; go/no-go = go ([REVIEW-2.md](REVIEW-2.md)). Close-out tasks in W10.9                                                                                                                                                                                              |
| **M2** | First real project: the owner's website on Cloudflare | W10 (coarse)                            | The site is live on the owner's domain; at least five changes shipped through v2 with the owner's touchpoints being decisions, the go and the approval only; the Lighthouse bar holds on the live site; the Cloudflare stack home exists and the fixture's rules moved into it; the reviewer judges UI in a browser; the owner publishes the link (D-17) |
| **M3** | First real app: lalista web on v2                     | W10 (coarse)                            | Precondition: lalista's paid plans or a move to Cloudflare (F-NEW-18/19). lalista's next five features ship through v2 only; v1 retired for it; no change caused a production incident; the Next.js + Supabase + Vercel stack home grown from it; canary job and next-day check on a real app                                                            |
| **M4** | iOS stack + Mac; retire v1                            | W10 (coarse)                            | Dedicated Mac (Claude non-admin); iOS stack home; lalista's voice-input iOS work through v2 with a native preview substitute and the version → testing-track flow; production-data grant mechanism; v1 archived read-only; deferred M0 owner steps done (W0.5.2/W0.5.3 credentials, W0.6.2 CI secrets, W0.6.3 home-os archive)                           |

## Capacity

- No hours target.
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
- **W10.4** v2 bootstrap in this repo (CI, rulesets, agent identity, install) — P0 · M1 · S
- **W10.5** Fixture project — P0 · M1 · S
- **W10.6** Skeleton end to end — P0 · M1 · M
- **W10.7** Go/no-go (owner) — P0 · M1 · S

### W1–W9 — v1 workstreams (superseded by D-14)

[W1](workstreams/W1-security.md) · [W2](workstreams/W2-correctness.md) · [W3](workstreams/W3-verification.md) · [W4](workstreams/W4-cloud-distribution.md) · [W5](workstreams/W5-recipes.md) · [W6](workstreams/W6-pipeline.md) · [W7](workstreams/W7-gstack.md) · [W8](workstreams/W8-docs.md) · [W9](workstreams/W9-simplify.md) — tasks marked `[-]`; kept as reference for the harvest (W10.3).

## Dependencies (critical path)

```
M0: W0.5 → W0.7 → W0.6 → W0.4 → W0.8
M1: W10.1 spikes ─┬─▶ W10.4 boot ─┐
    W10.2 L3 ─────┤               ├─▶ W10.6 skeleton ─▶ W10.7 go/no-go ─▶ W10.9 close-out ─▶ M2 website ─▶ M3 lalista ─▶ M4 iOS
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

## After the revamp

Agreed for after M4, not before. On v2's roadmap, the root [ROADMAP.md](../../../ROADMAP.md), as R-9
since 2026-10-16 (v1's `kit/ROADMAP.md` is frozen and leaves `main` with W10.4.1).

- **Air-gapped adversarial reviewer as a required check** (owner, 2026-10-11, LOG #19). Today's
  reviewer runs in the session, where a rogue agent could disable it ([TARGET § Verify](TARGET.md#verify)).
  Make it a wall: (1) its code and prompt live in a repo only the owner can change; (2) it runs
  where the agent has no access (GitHub's runners, not the session); (3) its verdict is posted by an
  identity the agent doesn't hold (not the agent identity — so not a Claude cloud environment) and is
  required to merge. Same script as the in-session reviewer. Costs: a reviewer repo + workflow, a
  Claude credential as a secret in that environment, tokens per run (on ready-for-review and later
  pushes). Residual risk: the PR content can try to talk the reviewer into passing — test it with
  planted violations and injection attempts before relying on it. Revisits D-06 (AI review as a
  separate required check; project CI stays plain); check first whether Anthropic's hosted Claude
  Code Review can fill the role.

## Changelog

| Date       | Change                                                                                                                                                                                                                                                                                                                                                                                                                    | Why                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 2026-10-08 | Plan created from analysis session                                                                                                                                                                                                                                                                                                                                                                                        | LOG #1                                                     |
| 2026-10-08 | Adversarial review: M0 expanded with stop-the-bleeding items (W0.4–W0.9); M1+ provisional pending D-14; D-12/D-13/D-14/D-15 added; D-01/D-03/D-04/D-06/D-08/D-09 revised; exit criteria made testable; capacity + cut line; ⚠ throwaway filter; W5 shrunk                                                                                                                                                                 | [REVIEW-1.md](REVIEW-1.md), LOG #2                         |
| 2026-10-08 | Added the build-loop: ASSUMPTIONS.md, TARGET.md + north-star scenario, walking skeleton W3.5 (M1 exit), whole-picture milestone review, codification queue, principle 9                                                                                                                                                                                                                                                   | Owner: test continuously + check the whole picture; LOG #3 |
| 2026-10-08 | Added W6.8 model routing + advisor (O-11/O-12, A-17 validated, A-18 A/B)                                                                                                                                                                                                                                                                                                                                                  | Owner proposal evaluated; LOG #4                           |
| 2026-10-09 | Plan review session: target agreed top-down (TARGET L0–L2); D-14 thin rewrite in a new repo; D-12/D-13/D-04/D-09/D-15/D-03/D-02/D-06/D-08 decided, D-11 obsolete; M0 reordered (credentials → history scan → rulesets → tag → CLAUDE.md); M1+ re-planned as W10 (M1 walking skeleton + go/no-go detailed; M2 pilot lalista web, M3 iOS + Mac, M4 retire v1 coarse); W1–W9 superseded; pacing rule replaces capacity hours | LOG #5                                                     |
| 2026-10-10 | D-14/D-12 revisited: rewrite **in this repo** (tag `v1-final`; first v2 PR removes v1 from `main`) instead of a new repo; going public later gated on W0.7 scan + W0.5 rotation + owner read of notes                                                                                                                                                                                                                     | Owner: the revamp fixes what the notes expose; LOG #6      |
| 2026-10-11 | D-05 decided (GitHub Pro, Claude Pro/Max); D-13 revisited — machine user (the agent identity) instead of a GitHub App; `main` protected + CODEOWNERS, verified as the agent; ruleset B deferred ("approval ships"); PLATFORM.md platform analysis with proposed TARGET/D-01 changes pending owner agreement; W10.1 spikes done except W10.1.2                                                                             | LOG #7–#10                                                 |
| 2026-10-11 | Owner deferred W0.5.2, W0.5.3, W0.6.2, W0.6.3 to the end of the revamp: removed from M0 exit, added to M4 exit                                                                                                                                                                                                                                                                                                            | LOG #14                                                    |
| 2026-10-11 | D-12 revisited: no history cleanup before going public — re-scan for secrets and rotate hits only; W10.3.1 seeded with "never project identifiers in the devshop"                                                                                                                                                                                                                                                         | LOG #14                                                    |
| 2026-10-11 | M0 exit review: M0 done; M1 in progress; A-25 added (tags/releases come from CI, not the session)                                                                                                                                                                                                                                                                                                                         | LOG #15                                                    |
| 2026-10-11 | L3 agreed for all nine pillars; D-07 + D-10 decided; A-26 + F-NEW-17 added; Cloudflare home with the owner's personal website (M2, parallel); D-01 revisited (one cloud environment per project) (TARGET § L3); W10.2 in progress; air-gapped reviewer added under After the revamp                                                                                                                                       | LOG #19                                                    |
| 2026-10-12 | North-star rewritten for all nine pillars; M1 exit = steps 1–6 (minus next-day check + rollback drill); W10.2 done                                                                                                                                                                                                                                                                                                        | LOG #20                                                    |
| 2026-10-12 | North-star hardened after adversarial review; fixture moves to Cloudflare (F-NEW-18/19, A-27); W10.5.3 + W10.6.5 added; lalista plan check = M2 precondition                                                                                                                                                                                                                                                              | LOG #20                                                    |
| 2026-10-12 | Verify 2 and 7: the PR opens only after the reviewer passes (no draft-to-ready gate; A-23 obsolete); the verdict goes on the PR as one comment per review, and a deterministic check shows a missing or stale one. Commit statuses ruled out: the session's GitHub access refuses status writes (HTTP 403)                                                                                                                | Owner, W10.6.6                                             |
| 2026-10-13 | First north-star run (W10.6.4): M1 exit not met. D-16: step 1 graded on the spec process, not a question count; only gaps that let a wrong change reach production or make a run untrustworthy block M1 (4 for run 2), the rest fixed in passing or deferred as known limits; W10.6.9 narrowed, W10.6.10 (run 2) added                                                                                                    | LOG #53, D-16                                              |
| 2026-10-15 | Adversarial review of PR 117's plan (LOG #72): W10.10 reordered (walls and a numeric quality bar before the first change; the first change is the design direction to `DESIGN.md`; the stack home written from what shipped; the separate preview-only account kept), W10.9.1 given a mechanism, W10.9.6 first, stale TARGET dates revised                                                                                | LOG #72                                                    |
| 2026-10-15 | Review 2 and D-17: M1 declared met (go); the per-run exam retired for a plain run; the ledger keeps its grades and loses its linter; skill cap back to a warning; M2 = the owner's website on Cloudflare, M3 = lalista web, M4 = iOS + Mac + retire v1; close-out tasks W10.9                                                                                                                                             | [REVIEW-2.md](REVIEW-2.md), D-17, LOG #70–#71              |
| 2026-10-15 | Devshop findings from project sessions reach the ledger through the owner and a devshop session, as the method; the `finding`-issues route and A-26 dropped (TARGET Shape 8, north-star step 9). W10.10.1's owner steps make squash the only merge method (F-NEW-76)                                                                                                                                                      | Website session findings, 2026-10-15                       |
