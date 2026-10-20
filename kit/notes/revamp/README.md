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

| #   | Milestone                                             | Status                                                                                    |
| --- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| M0  | Stop the bleeding + groundwork                        | done                                                                                      |
| M1  | Walking skeleton → go/no-go                           | done 2026-10-15 (D-17: met on runs 1–2 under D-16's rule; go). Close-out tasks W10.9 open |
| M2  | First real project: the owner's website on Cloudflare | next (W10.10)                                                                             |
| M3  | First real app: lalista web on v2                     | detailed (W10.11); lalista moves to Cloudflare (D-19)                                     |
| M4  | iOS stack + Mac; retire v1                            | coarse                                                                                    |

## Files

| File                                                                         | Purpose                                                                                                                                                                                   |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [REVIEW-1.md](REVIEW-1.md)                                                   | Adversarial review: errors found, critiques accepted/deferred, new decisions                                                                                                              |
| [REVIEW-2.md](REVIEW-2.md)                                                   | Whole-picture review 2 (2026-10-14): diagnosis after two north-star runs, what is noise, the path to a real project, decisions for the owner                                              |
| [REVIEW-3.md](REVIEW-3.md)                                                   | M2 milestone review (2026-10-20): M2's exit criterion by criterion, assumptions M3 rests on, metrics, the findings walk, M3 detailed, a fresh adversarial review, decisions for the owner |
| [TARGET.md](TARGET.md)                                                       | Target picture, agreed top-down (L0 sentence → L1 paragraph → L2 pillars) + north-star                                                                                                    |
| [ASSUMPTIONS.md](ASSUMPTIONS.md)                                             | Load-bearing assumptions and the cheapest test for each                                                                                                                                   |
| [PLAN.md](PLAN.md)                                                           | Principles, milestones + exit criteria, capacity, epics, codification queue, changelog                                                                                                    |
| `workstreams/Wn-*.md`                                                        | Epics → tasks with status: W0 (M0), W10 (v2, M1+); W1–W9 superseded v1 reference                                                                                                          |
| [FINDINGS.md](FINDINGS.md)                                                   | The findings archive, frozen 2026-10-16; live ones are in the root [FINDINGS.md](../../../FINDINGS.md)                                                                                    |
| [DECISIONS.md](DECISIONS.md)                                                 | Owner decisions, in the order to make them                                                                                                                                                |
| [PROCESS.md](PROCESS.md)                                                     | Light process: lifecycle, done, verification, replanning, reviews                                                                                                                         |
| [LOG.md](LOG.md)                                                             | Per-session journal                                                                                                                                                                       |
| [lessons.md](lessons.md)                                                     | v1 + home-os lessons that carry into v2, by pillar and by stack (W10.3.1–2)                                                                                                               |
| [project-contract-audit-2026-10-19.md](project-contract-audit-2026-10-19.md) | What the devshop expects a project to provide: 39 items, how each is enforced, where the website and the fixture differ; the survey behind R-13                                           |

## Next action

M1 is done (D-17, [REVIEW-2.md](REVIEW-2.md), LOG #71). M2's review is
[REVIEW-3.md](REVIEW-3.md) (LOG #87); the owner decided its § 9 (D-19, LOG #88), and M3 is detailed
as W10.11. Since 2026-10-16 the order of
work is the root [ROADMAP.md](../../../ROADMAP.md): the top `Open` entry is next, and the owner
reorders it.

- **Owner:** the W10.10.1 owner steps when that task starts (repo, Cloudflare account and tokens,
  cloud environment), guided by the session; before M3, lalista's walls and accounts in one sitting (W10.11.1, D-19).

## Driving the revamp from a new session

Open a session on this repo (the devshop's own environment) and say either **"where are we on the
devshop revamp plan?"** (the answer comes from this page's milestone table and Next action, and
the top `Open` entry of the root [ROADMAP.md](../../../ROADMAP.md)) or **"do the next step in
the devshop revamp plan"** (the session takes that task: writes the check first, makes the change,
ships one PR through `runtime/reviewer/ship.sh`, and tells the owner the link; CLAUDE.md and
[PROCESS.md](PROCESS.md) say so). The owner approves each PR; nothing merges otherwise. Tasks
marked `[owner]` list the steps only the owner can do, and the session walks through them one at
a time. For the website itself (W10.10), the owner starts a session in the website's own
environment and gives direction; the devshop skills (`intent`, `build`, `pr`) do the rest.

Tasks marked `[!]` "deferred to the M4 exit" are not raised before then.
