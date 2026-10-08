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

## Where it's heading (pending D-14)

**Enforcement where the agent can't reach** — GitHub rulesets with no bypass,
secrets only in main-gated environments, required CI checks, ideally a separate
agent identity (D-13); in-VM hooks are feedback. **Owner-locked intent** (decisions +
acceptance) checked deterministically in CI, with an LLM conformance review as
advisory until measured. **Pinned per project** and runnable in Claude Code cloud
sessions (mechanism after D-12 + spike). **Vendor code isolated** under
`stack/<vendor>/`; abstraction only when a second stack is real. **Right-sized
workflows**, **one-entry docs**, and — if D-14 picks the thin path — a much smaller
devshop built directly, deleting early.

## Milestones (status roll-up — criteria in [PLAN.md](PLAN.md))

| #   | Milestone                      | Status                       |
| --- | ------------------------------ | ---------------------------- |
| M0  | Stop the bleeding + groundwork | not started                  |
| M1  | Close the live holes           | provisional (re-plan @ D-14) |
| M2  | Cloud-native & pinned          | provisional                  |
| M3  | Verifies intent                | provisional                  |
| M4  | Stack isolation                | conditional                  |
| M5  | Lean & legible                 | provisional                  |

## Files

| File                             | Purpose                                                                                |
| -------------------------------- | -------------------------------------------------------------------------------------- |
| [REVIEW-1.md](REVIEW-1.md)       | Adversarial review: errors found, critiques accepted/deferred, new decisions           |
| [TARGET.md](TARGET.md)           | One-page target picture + north-star scenario re-run at every milestone                |
| [ASSUMPTIONS.md](ASSUMPTIONS.md) | Load-bearing assumptions and the cheapest test for each                                |
| [PLAN.md](PLAN.md)               | Principles, milestones + exit criteria, capacity, epics, codification queue, changelog |
| `workstreams/Wn-*.md`            | Epics → tasks with findings, done-when, verification, **status**                       |
| [FINDINGS.md](FINDINGS.md)       | Evidence register (117 findings + 10 opportunities), each mapped to work               |
| [DECISIONS.md](DECISIONS.md)     | Owner decisions, in the order to make them                                             |
| [PROCESS.md](PROCESS.md)         | Light process: lifecycle, done, verification, replanning, reviews                      |
| [LOG.md](LOG.md)                 | Per-session journal                                                                    |

## Next action

**Plan review session** ([PROCESS.md § 5](PROCESS.md#plan-review-session-next)):
decide D-14 → D-12 → D-13 → D-04 → D-09 → D-15 → D-03, state capacity, green-light
the M0 "stop the bleeding" items (freeze v1, rotate credentials, rulesets on the real
repos, fix gitleaks) — these are worth doing under either path.
