---
name: preflight
version: 1.0.0
description: |
  Local pre-PR test gate. Runs the project's CI fast-job equivalent (lint +
  typecheck + test:unit + build) plus affected integration + E2E specs vs
  origin/main. ~5–10 min wallclock; mirrors what CI's fast-job runs plus a
  targeted subset of the slow-job.
  Run it as the iterate-fix loop after each batch of commits, before
  `/ak-pre-ship`. Collapses the "edit → push → wait 8 min → red CI → fix →
  push" loop to "edit → preflight → fix" — catches deterministic failures
  locally so CI rarely surprises.
  Use when asked to "preflight", "run the affected tests", "verify before PR",
  or as the front (Gate 2d) and end (Gate 10b) of `/ak-pre-ship`. (devshop)
allowed-tools:
  - Bash
---

# Preflight

The lightweight standalone twin of `/ak-pre-ship`'s `fast-job-local` (Gate 2d) and `changed-tests-local` (Gate 2e) gates. Run it as many times as you need during the iterate-fix loop; run `/ak-pre-ship` once at the end for the full LLM-mediated ceremony.

## When to use

- After committing a batch of work, before `gh pr create`.
- After every fix during stuck-protocol debugging, to verify nothing else broke.
- Whenever you want a 5–10 min "is this likely to survive CI" answer.

Avoid running `/ak-pre-ship` during the iterate-fix loop — its ceremony is 15–30 min and includes LLM-mediated gates (`/simplify`, `/review`, `/cso`, `/design-review`, `/qa`, `/benchmark`). `/preflight` is the cheap fast loop; `/ak-pre-ship` is the one-shot final check.

## What it runs

| Layer | What                                                            | Script                                       | Cap     |
| ----- | --------------------------------------------------------------- | -------------------------------------------- | ------- |
| 1     | lint + typecheck + test:unit + build                            | `kit/scripts/preship/fast-job-local.sh`      | ~10 min |
| 2     | parse-check → changed-E2E → changed-integration → qa-walk smoke | `kit/scripts/preship/changed-tests-local.sh` | ~5 min  |

Layer 1 mirrors CI's fast-job verbatim. Layer 2 mirrors a targeted subset of CI's slow-job — only specs added/edited vs `origin/main`, plus the convention-based `*-qa-walk` smoke set.

## Invocation

Run both scripts in sequence:

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
echo "=== Layer 1: fast-job-local ==="
bash /devshop/kit/scripts/preship/fast-job-local.sh "$PROJECT_ROOT"
echo
echo "=== Layer 2: changed-tests-local ==="
bash /devshop/kit/scripts/preship/changed-tests-local.sh "$PROJECT_ROOT"
```

Each script emits the canonical gate shape (outcome line + finding bullets + `## Dismissals` section). Aggregate both into a single report when reporting back to the caller.

## Outcomes

Report the combined outcome:

- `pass` — both layers passed (or layer is `n/a`).
- `findings (N)` — N findings total across both layers. Each finding includes the canonical re-run command.
- `findings (N) [budget exceeded]` — at least one step hit its wallclock cap; deferred work is listed under `## Dismissals` (CI will exercise it anyway).
- `n/a` — neither layer found in-scope work (e.g., pure-docs diff, no turbo.json, no stack-needing paths).

## Bypasses

Use sparingly. Default REJECT — adversarial review requires specific, time-bound rationale.

- `git config devshop.fastJobSkipReason "<why>"` — skip Layer 1.
- `git config devshop.localTestSkipReason "<why>"` — skip Layer 2.

## Relationship to /ak-pre-ship

`/ak-pre-ship` invokes the same two scripts as its `fast-job-local` (Gate 2d) and `changed-tests-local` (Gate 2e) front-side gates — running them at the start of the pipeline so 5 min of deterministic checks fail fast instead of after 25 min of LLM ceremony.

It also re-invokes `/preflight` as `preflight-final` (Gate 10b) after the heavy ceremony, before convention check and hero shots. That end-of-chain run catches cross-gate interaction breakage that the per-gate stuck-protocol unit re-checks (`pnpm turbo run test:unit` after each code-changing gate) would miss — namely, integration or E2E regressions introduced by the composition of `/simplify` + `/review` + `/cso` + `/design-review` + `/qa` edits.

When you've already run `/preflight` standalone and HEAD hasn't moved, `/ak-pre-ship` will still re-run both scripts. Idempotent and cheap; better than caching.
