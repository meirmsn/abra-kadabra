# /ak-build — devshop mode

When `/ak-build` detects `MODE=devshop` (§ Step 0 mode detection), this file
governs Phase 3 gate selection, Phase 4.5 transport, and terminal handoff.
Phases 0–2 and 4.0 run from the shared SKILL.md; Phases 4.1–7 are skipped
entirely — `/ak-merge-devshop` subsumes them.

## Pipeline shape (devshop mode)

```
/ak-build MODE=devshop (main context — thin orchestrator)
  ├─ Phase 0 (main ctx)        → 3-section preview + user approval +
  │                               spec.md skeleton + tracker start
  │                               Sources: kit/ROADMAP.md, kit/TODOS.md
  ├─ Phase 0.6 (main ctx)      → staleness check against PLAN row's Source
  ├─ Agent → /ak-spec           → expands specs/<name>/spec.md
  ├─ Agent → /ak-implement      → writes specs/<name>/tasks.md + code + tests
  ├─ Agent → Phase 2.5          → fresh-eyes verification (devshop only)
  ├─ Phase 3 (orchestrator)     → 6 gates dispatched + 13 pre-composed
  │                               carve-outs (see § Gate applicability)
  ├─ Phase 4.0 (main ctx)      → BUILD-LOG entry + PLAN row closure
  └─ Skill → /ak-merge-devshop → audit + squash + ff-merge + push + cleanup
                                  (subsumes project-mode Phases 4.1–7)
```

After Phase 4.5, the pipeline is done. No Phase 5 (CI watch), no Phase 6
(PR-surface verification), no Phase 7 (notification). `/ak-merge-devshop` handles the
audit (its Phase 1), the squash commit body (the audit trail), the pre-push
hooks (the devshop's CI equivalent), and the push.

## Resume check adaptations (devshop mode)

When `MODE=devshop`, replace project-mode rung 1 (open PR check) with:

1. **Already merged to main?** — `$FEATURE` appears in a commit on `main`
   AND no local feature branch exists → "Feature already shipped. Nothing
   to do." Exit cleanly.
2. **Phase 3 + 4.0 ran, merge pending?** — `$FEATURE_DIR/review.md` exists
   AND `$FEATURE_DIR/tasks.md` has all tasks `done` AND `BUILD-LOG.md`
   contains an entry for `$FEATURE` → skip to Phase 4.5
   (`/ak-merge-devshop` invocation).

Rungs 2–6 (tasks.md all done, tasks.md partial, spec.md with/without
`## Task order`, fresh start) are identical to project mode — no
adaptation needed.

**Phase 2.5 resume rung** (inserted between "tasks.md all done" and
"skip to Phase 3"): when `$FEATURE_DIR/tasks.md` has all tasks `done`
AND `$FEATURE_DIR/verification.log` does NOT exist → run Phase 2.5
before advancing to Phase 3. When `verification.log` exists → skip
Phase 2.5 (already ran).

## Phase 0 source routing (devshop mode)

When `MODE=devshop`, section 0.1 reads:

- `kit/ROADMAP.md` section for this feature (matched via Source column in
  `PLAN.md`) — primary scope and the enumerated decisions.
- `kit/TODOS.md` entries the feature closes, if any.
- `PLAN.md` row for this feature — scope summary and source pointer.
- Prior shipped spec (`specs/<prior-feature>/spec.md`) as a
  style/structure reference.

Do NOT read: `PRODUCT-ROADMAP.md` (project-side), `DESIGN.md` (no UI),
`.gstack/projects/` artifacts (no gstack plan for devshop features).

### Phase 0 fix-assessment — root-cause vs bandaid

When the feature is a **fix** (a `fix/` branch, or any feature whose Source
blurb in `kit/ROADMAP.md` / `kit/TODOS.md` / `kit/FRICTION-LOG.md` describes a
bug, corruption, or failure class), the Phase 0.2 Decisions table MUST carry an
explicit **root-cause-vs-bandaid** row before the operator approves:

1. Read the tracker blurb's *described* remedy and the codebase. Classify the
   in-flight approach on the bandaid spectrum
   (`kit/docs/guide/conventions.md § Root-cause over bandaid`):
   avoid-the-blast-radius / detect-and-repair / containment (tiers 1–3,
   mitigation) vs. source-elimination (tier 4, root cause). The blurb itself is
   often written as a tier-1–3 mitigation — do not inherit its framing; assess
   the *actual* trigger.
2. Bias to the root-cause fix (remove the trigger so the bug class becomes
   structurally impossible), **unless** it is disproportionately large or
   nonsensical for the payoff.
3. When the root-cause fix is materially bigger than a mitigation, surface
   **both** — with their cost/risk tradeoff — as a Decisions-table row (mark it
   `[USER MUST DECIDE]` in the Proposed-answer column) so the operator picks the
   depth at the Phase 0 `AskUserQuestion`. Do not silently default to the
   bandaid, and label honestly which tier each option is.

This is the operational home of the ambient "bias fixes toward root cause" value
kept in `CLAUDE.md § Implementation Approach` — the kernel states the value; this
step is where `/ak-build` actually applies it. The bandaid spectrum + worked
example live in the shared guide (`kit/docs/guide/conventions.md § Root-cause over
bandaid`), so a project-mode fix can apply the same assessment via its Phase 0.2
Decisions table; the explicit step is documented here (devshop mode) because the
devshop is where fixes-to-fixes most often originate.

### Tracker hierarchy (devshop mode)

The Phase 0.2 tracker omits project-only phases:

```
Phase 1: Spec
Phase 2: Implement
Phase 2 / Task 1: <first implementation task>
…
Phase 2 / Task N: <last>
Phase 3: Pre-ship (devshop gate set)
Phase 4.0: BUILD-LOG + PLAN closure
Phase 4.5: /ak-merge-devshop
```

### Product blurbs

Devshop features still author Headline + Detail blurbs at Phase 0.2.
They route through:

- `BUILD-LOG.md` — Headline → `Headline:` field, Detail → `Summary:` field
- `/ak-merge-devshop` squash commit body — the commit message composer reads
  `spec.md § Product update` as an input

For pure infrastructure features (no project-facing user-visible impact),
the Headline reads: `Infrastructure update — no user-visible change.`
Same convention as project-mode infra PRs.

## Phase 1 note (devshop mode)

Add to the spec subagent prompt:
> This is devshop-self-mode. There is no METRICS.md; skip the metrics-
> confirmation step. The test surface is bats (kit/tests/), not
> vitest/Playwright.

## Phase 2.5: Verification (devshop only)

After Phase 2 completes (all tasks done, bats green), spawn a **fresh
subagent** with zero implementation context to verify the changes work.

**Why this exists.** Over ~10 devshop features (2026-05-17 to 2026-05-27),
operator-prompted "test the changes" consistently caught real bugs that the
implementation agent and its bats tests missed: stale doc cross-references
(7 in lint-staged-rename-symlink), wrong file permissions (rollback-prose-
lint), format mismatches between script parsers and their real inputs
(local-env-pillar), incomplete doc updates after new check-types landed
(phase3-blocked-halt), dead code branches (cheap-test-gates-local). The
common thread: the implementation agent can't see its own blind spots.
A fresh context with no implementation bias catches them.

**Why devshop only.** Project mode runs 18+ gates including `/qa` (full
app QA), `/design-review` (visual audit), `/cso` (security), and
`changed-tests-local` (E2E against real app). The devshop's reduced
6-gate set skips all of those — Phase 2.5 partially closes the gap.

### Dispatch

```
Agent {
  description: "Phase 2.5: verify changes",
  subagent_type: "general-purpose",
  prompt: """
    You did NOT write this code. Your job is to test the changes on
    this branch to make sure they work.

    Working directory: $TARGET (the worktree or /devshop).
    Feature: $FEATURE
    Spec: $FEATURE_DIR/spec.md

    Start by reading the spec and the diff (git diff origin/main..HEAD).
    Then test the changes — run the scripts, check the docs, verify
    cross-references resolve, confirm file permissions are correct,
    make sure test fixtures match the real formats they parse.

    If you find issues:
    - Fix them and commit atomically per fix.
    - Run `kit/tests/lib/bats-core/bin/bats kit/tests/` after each fix.
    - Use the docsReviewed bypass as needed for commits.

    If you find something you can't fix (design-level, needs operator
    input), note it as an escalation.

    Write your findings to $FEATURE_DIR/verification.log:
      <N> findings fixed, <M> escalated
      - fixed: <one-line per fix with commit SHA>
      - escalated: <one-line per escalation>
    (or "0 findings — all changes verified clean" if nothing found)

    Return: the contents of verification.log.
  """
}
```

### Orchestrator behavior after return

- **0 findings** → proceed to Phase 3.
- **N fixed, 0 escalated** → run `bats kit/tests/` as a regression
  check (same shape as Gate 2d between code-changing gates), then
  proceed to Phase 3.
- **Escalations > 0** → surface to operator via `AskUserQuestion`:
  fix in-branch and re-invoke, or proceed with the escalation noted
  in `verification.log` (recorded in the merge audit trail).

### Exit artifact

`$FEATURE_DIR/verification.log` — must exist before Phase 3 starts.
The resume check uses its presence to skip Phase 2.5 on re-invocation.

## Phase 3: Pre-ship — devshop gate set

### Gate applicability matrix

| # | Name | Disposition | Rationale |
|---|------|------------|-----------|
| 1 | `docs-check` | **dispatch** | docs coverage for the diff |
| 2 | `metrics-check` | `n/a` | no METRICS.md in devshop |
| 2b | `rls-coverage` | `n/a` | no supabase |
| 2c | `slow-job-lifecycle` | `n/a` | no slow-job CI |
| 2d | `fast-job-local` | **dispatch (adapted)** | run `bats kit/tests/` |
| 2e | `migration-rollback-roundtrip` | `n/a` | no migrations |
| 2f | `changed-tests-local` | `n/a` | bats run in Gate 2d covers this |
| 2g | `advisor-clean` | `n/a` | no supabase |
| 3 | `responsive-theme` | `n/a` | no UI surface |
| 4 | `/simplify` | **dispatch** | code quality pass |
| 5 | `docs-and-tests-review` | **dispatch** | /ak-check-docs-and-tests audit |
| 6 | `/review` | **dispatch** | code review (always applies) |
| 7 | `/cso` | `blocked (n/a per scope)` | no auth boundary, no RLS, no third-party APIs |
| 8 | `/design-review` | `blocked (n/a per scope)` | no UI surface |
| 8b | `design-conformance` | `n/a` | no DESIGN.md |
| 9 | `/qa` | `blocked (n/a per scope)` | no UI surface; bats invariants run in Gate 2d |
| 10 | `/benchmark` | `blocked (n/a per scope)` | no perf surface |
| 10b | `preflight-final` | `n/a` | bats recheck in Gate 2d covers this |
| 11 | `convention` | **dispatch (adapted)** | devshop convention check |

**6 gates dispatched**, **13 gates pre-composed carve-outs**.

### Pre-composed carve-out sinks

Write these directly to `$FEATURE_DIR/gates/<name>.md` without spawning a
sub-agent. Each sink follows the standard gate format:

For **non-LLM-mediated gates** (2, 2b, 2c, 2e, 2f, 2g, 3, 8b, 10b):

```markdown
## Gate <#>: <name>

- Result: n/a (devshop-self-mode: <rationale from matrix above>)

## Dismissals

None
```

For **LLM-mediated gates** (7, 8, 9, 10) — must use `blocked`, never bare `n/a`:

```markdown
## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None
```

```markdown
## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None
```

```markdown
## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None
```

```markdown
## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None
```

### Structural carve-out advance-log handling

The LLM-mediated carve-outs (Gates 7, 8, 9, 10) use the `blocked` outcome
which normally triggers the Phase 3 → 4 `AskUserQuestion` halt. In devshop
mode, these are **structural inapplicabilities** — "the devshop has no UI"
is not a fixable tooling gap. The orchestrator bypasses the interactive halt
for these gates:

1. After concatenating gate sinks into `review.md`, count `blocked` outcomes.
2. Partition into **structural** (matching `blocked (n/a per scope: devshop-self-mode`)
   and **real** (all others).
3. For structural blocked gates, write advance-log entries directly to
   `$FEATURE_DIR/review.md` with a `STRUCTURAL` stamp:

   ```markdown
   ## Phase 3 → 4 advance log

   ### <timestamp> — Gate 7: /cso

   **Gate:** Gate 7: /cso
   **Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
   **Follow-up tracker:** n/a — structural; no tooling gap to close
   <!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ <timestamp> -->
   ```

   Repeat for Gates 8, 9, 10.

4. The `STRUCTURAL` stamp is distinct from `PASS` (Sonnet-reviewed) and
   `pending` (not yet reviewed). It signals the override was never submitted
   to adversarial review because the gate is architecturally impossible to
   satisfy, not practically blocked.

5. **Advance condition**: `findings_pending == 0` AND `real_blocked == 0`
   AND no LLM-mediated gate marked bare `n/a`. Structural blocked gates
   are excluded from the halt count.

### Stabilize-HEAD pass (sequential — 4 gates)

Dispatch in this order, one Agent call at a time:

**Gate 1: docs-check** — same scope predicate as project mode. For devshop,
"reference docs" are `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`,
`CLAUDE.md`. Prompt the sub-agent per `pre-ship/SKILL.md § Gate 1`.

**Gate 2d: fast-job-local (adapted)** — instead of
`pnpm turbo run lint typecheck test:unit build`, run:

```bash
bats kit/tests/
```

The bats suite is the devshop's equivalent of the project's turbo pipeline.
Timeout: 5 minutes (suite currently runs ~1200 tests in ~60–90s). Prompt
the sub-agent: `"Run bats kit/tests/ as the deterministic test gate. This
is devshop-self-mode — bats is the test suite, not turbo. Report findings
per gate contract."`.

**Gate 4: /simplify** — same gstack skill invocation. After this gate, run
`bats kit/tests/` as the test checkpoint (not `pnpm turbo run test:unit`).

**Gate 11: convention (adapted)** — check devshop conventions from
`kit/docs/guide/conventions.md`. For devshop, the convention check verifies:
- SKILL.md files have proper frontmatter
- Shell scripts have the expected structure
- Guide docs are linked in the routing index (`kit/docs/guide/README.md`)
- Bats test files exist for new scripts under `kit/scripts/`

### Analysis pass (parallel — 2 gates)

Dispatch in a single tool-use turn:

**Gate 5: docs-and-tests-review** — invoke `/ak-check-docs-and-tests`.
The sub-skill is already repo-aware and handles devshop self-mode.

**Gate 6: /review** — invoke `/review` (gstack). Code review always applies.

### No hero screenshots

Skip `§ 3.1b: Hero-screenshot capture` entirely. Devshop features have no
UI surface.

### Concatenation + handoff

After both passes, concatenate all 19 gate sinks (6 real + 13 carve-out)
into `$FEATURE_DIR/review.md` in canonical gate order. Same logic as
project mode § 3.3.

Apply the structural carve-out advance-log handling (§ above) before
evaluating the Phase 3 → 4 handoff condition.

## Phase 4.5: /ak-merge-devshop

After Phase 4.0's bookkeeping commit, invoke `/ak-merge-devshop`:

```
Skill({
  skill: "ak-merge-devshop"
})
```

No arguments needed — the skill auto-detects from git state (feature branch
ahead of main, clean tree after Phase 4.0's commit).

### What /ak-merge-devshop handles

- **Phase 0**: Pre-flight + squash commit message composition + approval gate
- **Phase 1**: Rebase onto `$ANCHOR` (Phase 1.0), then audit via
  `/ak-check-docs-and-tests --range "$ANCHOR..HEAD"` (Phase 1.1, equivalent of
  project-mode Phase 5.8). **Idempotent**: if the Phase 1.0 rebase was a no-op
  (branch already on top of `$ANCHOR`) AND Phase 3 Gate 5 already ran the audit
  at the current HEAD, the `<!-- audited-at: <SHA> -->` stamp causes the audit
  to no-op. If the rebase rewrote HEAD (stale-base worktree), the prior stamp no
  longer matches and the audit re-runs against the rebased HEAD — which is the
  point of rebasing first. Either way the double-audit is correct by
  construction.
- **Phase 2**: Squash on the feature branch
- **Phase 3**: Fast-forward main + push (pre-push hooks = CI equivalent)
- **Phase 4**: Verify + cleanup (branch deletion, worktree teardown if applicable)

### Orchestrator behavior after /ak-merge-devshop returns

- **Success**: update TaskCreate tracker (mark Phase 4.5 `completed`),
  print terminal handoff (§ below).
- **Halt** (Phase 1 high-severity findings, operator cancel, etc.): surface
  the halt reason. Do NOT retry. The operator re-invokes `/ak-build` after
  fixing; Step 0's resume check picks up at the right phase.

## Terminal handoff

Replaces project-mode Phase 7. Print to terminal:

```
Pipeline complete.

  Feature:   $FEATURE
  Branch:    $BRANCH (squashed to 1 commit on main)
  BUILD-LOG: entry recorded
  PLAN:      row removed from Active

Next step:
  → Run /ak-release-devshop if feat:/fix: commits have accumulated
    since the last tag.
  → Or: nothing — the feature is shipped.
```

## Phase 0.6: Staleness check

Fires after Phase 0.3 (spec skeleton committed) and before Phase 1.
Applies to both modes but is defined here as it ships with devshop-mode.

**Purpose**: before spending tokens on spec expansion and implementation,
verify the PLAN row's Source entry still applies.

**Steps**:

1. Read the Source column from the PLAN row for `$FEATURE`.
2. Follow the pointer to `kit/ROADMAP.md` or `kit/TODOS.md`.
3. Read the Problem / Trigger / Deps paragraphs.
4. Compare key assertions against:
   - `git log --oneline -20` (recent history)
   - File existence checks for referenced paths
   - Deps status (has the blocking feature shipped?)

**Surface concerns when**:
- The Problem statement references a constraint that no longer exists
  (e.g., "X isn't available" but X shipped recently)
- Recent commits partially or fully subsume the planned work
- Deps/Trigger conditions haven't been met yet

**Output**: if concerns found, surface via `AskUserQuestion`:

```
header: "Staleness check"
question: "The PLAN row's Source entry may be stale. Concerns: <list>. How to proceed?"
options:
  1. Proceed anyway — the entry still applies (Recommended)
  2. Rescope — update the Source entry and restart Phase 0
  3. Drop — delete the PLAN row; the work is no longer needed
```

If no concerns, continue silently. The check is advisory (~10s, read-only).

## Escalation chain (devshop mode)

Shorter than project mode — no PR comment surface:

1. **Self-fix**: stuck protocol (/ak-implement), test checkpoints (bats),
   gate fix loops
2. **AskUserQuestion**: if user is present in the session (blocking)
3. **Terminal output**: if unsure whether user is watching

## Context pressure (devshop mode)

Same as project mode:
- Heavy work runs in subagents
- Critical state survives in files: `specs/<name>/spec.md`, `tasks.md`,
  `review.md`, git commits
- On resume, Step 0 reads file state
- If context exhausted mid-pipeline, user starts new session, `/ak-build`
  resumes via Step 0
