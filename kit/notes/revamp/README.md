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
| M3  | First real app: lalista web on v2                     | coarse                                                                                    |
| M4  | iOS stack + Mac; retire v1                            | coarse                                                                                    |

## Files

| File                             | Purpose                                                                                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| [REVIEW-1.md](REVIEW-1.md)       | Adversarial review: errors found, critiques accepted/deferred, new decisions                                                                 |
| [REVIEW-2.md](REVIEW-2.md)       | Whole-picture review 2 (2026-10-14): diagnosis after two north-star runs, what is noise, the path to a real project, decisions for the owner |
| [TARGET.md](TARGET.md)           | Target picture, agreed top-down (L0 sentence → L1 paragraph → L2 pillars) + north-star                                                       |
| [ASSUMPTIONS.md](ASSUMPTIONS.md) | Load-bearing assumptions and the cheapest test for each                                                                                      |
| [PLAN.md](PLAN.md)               | Principles, milestones + exit criteria, capacity, epics, codification queue, changelog                                                       |
| `workstreams/Wn-*.md`            | Epics → tasks with status: W0 (M0), W10 (v2, M1+); W1–W9 superseded v1 reference                                                             |
| [FINDINGS.md](FINDINGS.md)       | Findings ledger: a Fix queue graded by Leverage, a Watch list counted by sessions, Closed                                                    |
| [DECISIONS.md](DECISIONS.md)     | Owner decisions, in the order to make them                                                                                                   |
| [PROCESS.md](PROCESS.md)         | Light process: lifecycle, done, verification, replanning, reviews                                                                            |
| [LOG.md](LOG.md)                 | Per-session journal                                                                                                                          |
| [lessons.md](lessons.md)         | v1 + home-os lessons that carry into v2, by pillar and by stack (W10.3.1–2)                                                                  |

## Next action

M1 is done (D-17, [REVIEW-2.md](REVIEW-2.md), LOG #71). Next, in order:

- **Claude:** the M1 close-out tasks W10.9 (small PRs: merge on approval and comment-as-question in
  the `pr` skill; the screenshot table; the skill cap back to a warning; the ledger's linter removed
  and the findings re-sorted per REVIEW-2 § 2), then the plain run on the fixture (W10.9.5), then
  M2's first task: scaffold the website repo (W10.10.1).
- **Owner:** allow the fixture's preview and production hosts in its environment (for the plain run)
  and pick the plain run's change; before M3, lalista's plan check (F-NEW-18/19).

Tasks marked `[!]` "deferred to the M4 exit" are not raised before then.
