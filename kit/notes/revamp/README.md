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

| #   | Milestone                      | Status      |
| --- | ------------------------------ | ----------- |
| M0  | Stop the bleeding + groundwork | in progress |
| M1  | Walking skeleton → go/no-go    | planned     |
| M2  | Pilot: lalista web on v2       | coarse      |
| M3  | iOS stack + Mac                | coarse      |
| M4  | Complete & retire v1           | coarse      |

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

## Next action

M0 has two steps waiting on the owner ([W0](workstreams/W0-groundwork.md)): push the
`v1-final` tag (**W0.4.1**) and give the agent access to lalista + home-os so their history
scan can run (**W0.7.1**). M1 ([W10](workstreams/W10-v2.md)): the lessons harvest
(**W10.3.1**) is next and needs no owner input.
