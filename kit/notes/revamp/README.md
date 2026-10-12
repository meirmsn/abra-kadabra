# Devshop Revamp — start here

> Living plan + tracker for the 2026-Q4 revamp of abra-kadabra. Built from the
> analysis session of 2026-10-07/08 ([LOG.md](LOG.md) #1) and stress-tested by an
> adversarial review ([REVIEW-1.md](REVIEW-1.md), LOG #2).
> Read top-down: this page → [REVIEW-1.md](REVIEW-1.md) (what changed and why) →
> [PLAN.md](PLAN.md) (milestones + epics) → `workstreams/Wn-*.md` (tasks) →
> [FINDINGS.md](FINDINGS.md) (evidence) · [DECISIONS.md](DECISIONS.md) (your calls).

## Why a revamp

The devshop's intent is sound — idea → product/design docs → spec → tasks →
tested code → adversarial verification → deploy, with guardrails Claude cannot
weaken. The implementation has outgrown itself:

- **Guardrails leak.** Verified ways for the agent to bypass hooks, read secrets, or
  get root; the LLM reviewer passes by default; **the secret scanner detects nothing**
  (F-SEC-20, reproduced); the agent can push `main` (F-CLOUD-03 corrected).
- **The core promise is not checked.** Nothing verifies a change against its spec
  (0/72 acceptance boxes ever ticked). (F-PIPE-12)
- **One size fits all.** Every change runs a 19-gate pipeline. (F-PIPE-13)
- **Local-only and version-blind.** Every project runs the devshop's live checkout. (F-VER-01)
- **Stack-coupled.** Supabase/Vercel/Next baked into gates, setup, template. (F-STACK-01)
- **Too heavy to stay consistent.** ~225k words of docs + ~90k words of skills that
  have drifted apart. (F-DOC-01, F-PIPE-18)

## Where it's heading (agreed 2026-10-09 — [TARGET.md](TARGET.md))

> You say what you want — from a whole app to a one-line fix — and Claude helps you
> sharpen it, specs it, and builds it, iterating against adversarial review until what's
> built is verified against your intent (tested, documented, security-checked); then you
> review the PR and its preview and steer until you approve. Claude works inside walls it
> can't move — cloud by default, a scoped local Mac when the cloud can't do the job.

**How we get there (D-14):** a lean rewrite **in this repo** (v1 kept at the `v1-final` tag as
the reference) and a lessons harvest first; a walking skeleton on a fixture project, then
an explicit go/no-go; lalista is the pilot (web, then iOS).

## Milestones (status roll-up — criteria in [PLAN.md](PLAN.md))

| #   | Milestone                      | Status                                                           |
| --- | ------------------------------ | ---------------------------------------------------------------- |
| M0  | Stop the bleeding + groundwork | done                                                             |
| M1  | Walking skeleton → go/no-go    | in progress — W10.1 spikes + W10.2 design done; W10.3–W10.7 open |
| M2  | Pilot: lalista web on v2       | coarse                                                           |
| M3  | iOS stack + Mac                | coarse                                                           |
| M4  | Complete & retire v1           | coarse                                                           |

## Files

| File                             | Purpose                                                                                |
| -------------------------------- | -------------------------------------------------------------------------------------- |
| [REVIEW-1.md](REVIEW-1.md)       | Adversarial review: errors found, critiques accepted/deferred, new decisions           |
| [TARGET.md](TARGET.md)           | Target picture, agreed top-down (L0 sentence → L1 paragraph → L2 pillars) + north-star |
| [ASSUMPTIONS.md](ASSUMPTIONS.md) | Load-bearing assumptions and the cheapest test for each                                |
| [PLAN.md](PLAN.md)               | Principles, milestones + exit criteria, capacity, epics, codification queue, changelog |
| `workstreams/Wn-*.md`            | Epics → tasks with status: W0 (M0), W10 (v2, M1+); W1–W9 superseded v1 reference       |
| [FINDINGS.md](FINDINGS.md)       | Evidence register (117 findings + 10 opportunities), each mapped to work               |
| [DECISIONS.md](DECISIONS.md)     | Owner decisions, in the order to make them                                             |
| [PROCESS.md](PROCESS.md)         | Light process: lifecycle, done, verification, replanning, reviews                      |
| [LOG.md](LOG.md)                 | Per-session journal                                                                    |
| [lessons.md](lessons.md)         | v1 + home-os lessons that carry into v2, by pillar and by stack (W10.3.1–2)            |

## Next action

M0 is done (review: [LOG.md](LOG.md) #15). M1 ([W10](workstreams/W10-v2.md)):

- **Claude:** W10.3.3 FINDINGS disposition (W10.3.1 v1 and W10.3.2 home-os harvests done:
  [lessons.md](lessons.md)); respect the pacing rule (≤ ~2 devshop PRs waiting on the owner).
- **Owner, when ready:** W10.5.1 — create the fixture repo, Cloudflare account + scoped deploy
  token, and the fixture's cloud environment (checklist in [W10](workstreams/W10-v2.md)); then a
  session for W10.5.2–3 with the fixture attached. Before M2: check lalista's Vercel and Supabase
  plans (F-NEW-18/19).
- **Claude, in parallel:** W10.4 v2 bootstrap in this repo (W10.4.1 first).
- Done: W10.2 — L3 agreed for all nine pillars + north-star rewritten and hardened (LOG #19,
  #20); fixture on Cloudflare. D-01 decided 2026-10-11 (option D; built in W10.4.4).

Tasks marked `[!]` "deferred to the M4 exit" are not raised before then.
