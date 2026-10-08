# Devshop Revamp — start here

> Living plan + tracker for the 2026-Q4 revamp of abra-kadabra. Built from the
> analysis session of 2026-10-07/08 (see [LOG.md](LOG.md) entry #1).
> Read top-down: this page (1 screen) → [PLAN.md](PLAN.md) (workstreams + milestones)
> → `workstreams/Wn-*.md` (epics → tasks) → [FINDINGS.md](FINDINGS.md) (evidence).

## Why a revamp

The devshop's intent is sound — idea → product/design docs → spec → tasks →
tested code → adversarial verification → deploy, with guardrails Claude cannot
weaken. The implementation has outgrown itself:

- **Guardrails leak.** Several verified ways for the agent to bypass hooks, reach
  secrets, or get root; the LLM reviewer passes by default. (`F-SEC-*`, `F-HOOK-*`, `F-REV-*`)
- **The core promise is not checked.** Nothing verifies a change against its spec;
  reviews judge bypass excuses, not intent. (F-PIPE-12)
- **One size fits all.** Every change runs a 19-gate pipeline; fix/patch/hotfix
  have no path. (F-PIPE-13)
- **Local-only and version-blind.** Runs only in a local devcontainer; every
  project runs the devshop's live checkout — no real per-project versions. (F-VER-01)
- **Stack-locked.** Next.js + Supabase + Vercel are baked into gates, setup, template. (F-STACK-01)
- **Too heavy to stay consistent.** ~250k words of docs + ~90k words of skills,
  restating facts that have drifted apart. (F-DOC-01, F-PIPE-18)

## Target in one paragraph

A **stack-agnostic core** (pipeline, spec/tasks, conformance reviews, hooks,
docs rules) plus **recipes** per service (Supabase, Vercel, Cloudflare, …) chosen
by the project's `stack.yaml`; **pinned per project** (a versioned install into
the project's `.devshop/` + `.claude/`), so it runs identically in **Claude Code
cloud sessions** and locally; **security boundary outside the agent's VM**
(git proxy, GitHub protections, network allowlist, secrets that never enter the
VM); **deterministic orchestration** with LLM judgement spent on one thing —
independent **spec-conformance** review; **workflow tiers** (product / fix /
patch / hotfix); **one-entry-point docs**.

## Milestones (status roll-up)

| #   | Milestone             | Outcome                                                                 | Status      |
| --- | --------------------- | ----------------------------------------------------------------------- | ----------- |
| M0  | Groundwork            | Decisions made, baseline recorded, tests run anywhere, devshop CI       | not started |
| M1  | Close the holes       | Verified security + correctness fixes, each with a regression test      | not started |
| M2  | Cloud-native & pinned | Fixture project runs the devshop at a pinned version in a cloud session | not started |
| M3  | Verifies intent       | Spec-conformance gate + workflow tiers + gstack upgraded                | not started |
| M4  | Stack-agnostic        | Existing stack runs via recipes; second recipe passes contract tests    | not started |
| M5  | Lean & legible        | One-entry docs, slim skills, deletions done, size targets met           | not started |

Update this table when a milestone's exit criteria are verified (see [PROCESS.md](PROCESS.md)).

## Files

| File                         | Purpose                                                                                                 | Changes when            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------- |
| [PLAN.md](PLAN.md)           | Principles, milestones, workstreams → epics (one line each), plan changelog                             | Plan is revised         |
| `workstreams/Wn-*.md`        | Epics → tasks with findings, done-when, verification, **status**                                        | Every task state change |
| [FINDINGS.md](FINDINGS.md)   | Evidence register: every issue/opportunity with ID, source, task mapping                                | New discovery           |
| [DECISIONS.md](DECISIONS.md) | Decisions needing the owner; options + recommendation + outcome                                         | Decision made/revisited |
| [PROCESS.md](PROCESS.md)     | How we work: task lifecycle, definition of done, verification levels, replanning, review-session agenda | Rarely                  |
| [LOG.md](LOG.md)             | Dated journal: what was done, evidence, surprises                                                       | Every work session      |

## Next action

**Plan review session** — agenda in [PROCESS.md § Plan review session](PROCESS.md#plan-review-session).
Its outputs: decisions D-01…D-06 made, priorities confirmed, coverage check passed, M0 green-lit.
