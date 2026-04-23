# Subagent Cleanup Pattern: Measure Drift, Then Codify

**Status**: NOT STARTED — instrumentation phase planned, implementation deferred until drift rate is measured.
**Tracked via**: `kit/TODOS.md` entry (points to this plan).
**Authoring date**: 2026-04-19
**Precondition**: 2026-04-19 hook architecture migration (landed v1.10.0). See `git log` for landing commit; the parent plan + verification plan for that migration were deleted per `kit/notes/README.md` convention after execution.

---

## Motivation

The hook migration moved dirty-tree and stash nudges from PostToolUse hooks (which hijacked subagent contexts) to:

- Git-layer blocking at commit/push (hard gates via `check-clean-tree.sh` and the `.husky/pre-push` `dirtyPushReason` check).
- SessionStart cross-repo WIP heads-up (soft, non-blocking reminder).

**What remains unsolved**: between gate points, state can accumulate. A subagent that spawns, does work, and returns can leave uncommitted files, lingering stashes, or orphan commits — and nothing forces resolution until the next commit/push in that repo. Across enough sessions, WIP compounds. SessionStart flags it but never enforces cleanup.

The architecturally clean fix is **parent-agent responsibility**: when a subagent returns, the parent asserts that the state is clean OR the subagent has provided a specific structural reason it must remain dirty. If dirty without a good reason, the parent re-engages the subagent via `SendMessage` to commit or better justify. Parent does any final cleanup at task completion.

**Critical constraint**: this must NOT be implemented as a `SubagentStop` hook that injects `"BLOCKING: commit your dirty tree"` into subagent context. That would recreate the exact bug the hook migration just eliminated — hook-injected parent-scope demands leaking into subagents. The pattern lives at the prompt / agent-to-agent layer.

---

## Phase 1 — Instrument (measure drift rate before investing)

**Goal**: determine how often subagents actually leave unexplained drift across real pipeline runs, before committing to a codified pattern.

### What to measure

- **Per-subagent drift events.** For each `Agent()` spawn inside a skill:
  - At spawn: snapshot `git status --porcelain`, `git stash list`, `git rev-parse HEAD`, and `git branch --show-current` for each affected repo.
  - At subagent return: snapshot again.
  - Log the delta, tagged with the spawning skill name and the subagent's `description` field.
- **Drift rate**: `spawns_with_delta / total_spawns`.
- **Drift-type distribution**: unstaged modifications, untracked files, new stashes, orphan commits, branch switches. This tells us what a cleanup check needs to cover.
- **Session-level accumulation**: of the drifts logged during a session, how many survive to the next session's SessionStart heads-up vs. get resolved in-session.

### How to instrument

**Option A — Lightweight bash logger** (recommended for Phase 1):

- New script `kit/scripts/subagent-drift-log.sh <event> <skill> <description> [agentId]` — appends one JSON line to `/devshop/kit/notes/metrics/subagent-drift.log` (gitignored) with timestamp, pre- or post-spawn snapshot, skill, description, agentId.
- Skills that spawn subagents call it immediately before and immediately after each `Agent(...)` invocation. For Phase 1, instrument `/ak-build` and `/ak-implement` only — highest volume of subagent spawns.
- Deterministic only. No LLM calls. No hook wiring. Roughly 30 LoC + 2 call-sites per skill.
- Overhead per spawn: ~10 ms (two `git status` runs + file append). Negligible.

**Option B — `PostToolUse` hook matching `Agent` tool** (rejected for Phase 1):

- Would fire automatically on every `Agent()` tool call. More robust coverage than A (no skill-level drift).
- Rejected because: (a) recreates the subagent-noise risk if the hook's output ever leaks into subagent context; (b) couples the instrumentation to tool-name matching which could change across Claude Code versions; (c) we are explicitly NOT reaching for hooks after the migration. If Phase 1 validates the pattern's value, revisit this option for Phase 2.

### Duration and sample size

- Run Option A for ~2 calendar weeks OR until ~20 full `/ak-build` runs + ~10 `/ak-implement` runs have been logged, whichever comes first.
- Minimum viable sample: **30 `Agent()` spawns** across both skills. Below that, the drift-rate estimate is noise.

### Decision gate (end of Phase 1)

Evaluate the log:

| Outcome                                                         | Action                                                                                                                           |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Drift rate < 5% AND no accumulation beyond 1 session            | **Skip Phase 2.** Write a short retro at `kit/notes/research/subagent-drift-measurement.md`, mark this plan complete, delete.    |
| Drift rate 5–15%, mostly resolved in-session                    | **Phase 2 light** — prompt block only, skip the helper script.                                                                   |
| Drift rate > 15% OR 2+ sessions of accumulation per drift event | **Phase 2 full** — helper script + prompt block + SKILL.md insertions.                                                           |
| Drift is rare but catastrophic (data loss, orphaned work)       | Phase 2 full regardless of rate, plus add a bats test that asserts every skill's `Agent(...)` block includes the prompt snippet. |

---

## Phase 2 — Codify (only if Phase 1 warrants it)

### Light path — prompt block only

A shared prompt block appended to the `Agent()` prompt in each work-delegating skill:

```
## Before reporting done

In each repo you touched, run:

  git status --porcelain
  git stash list

If either shows any output, do ONE of:

1. Commit what you changed — recommended default.
2. Include this block at the end of your final report:

     CLEAN STATE EXCEPTION: <list the specific files or stash entries>
     REASON: <structural reason it must remain — e.g., "scaffolding the
             parent agent will fill in", "tracked by open issue #X",
             "legitimate WIP for a branch the parent owns">

Do NOT use vague reasons like "WIP", "later", or "no time to commit".
The parent agent will verify the actual state and may ask you to revise
if the reason is weak.
```

**Location**: `kit/docs/guide/agents.md` (create if it doesn't exist — agents conventions have no dedicated home today). Each skill includes it verbatim in its `Agent()` prompt template.

**Cost**: ~1 hour to write + distribute across `/ak-build` and `/ak-implement`. ~100 tokens per subagent spawn in the parent prompt, ~50 tokens per subagent return in the report. No runtime script cost.

### Full path — helper script + prompt block

In addition to the prompt block above:

- `kit/scripts/snapshot-repo-state.sh <label>` — called by the parent immediately before `Agent()` to write a baseline snapshot for each affected repo to `/tmp/subagent-snapshot-<label>.json`.
- `kit/scripts/commit-hooks/check-subagent-cleanup.sh <label> [<repo>...]` — called after the subagent returns:
  - Reads the baseline snapshot.
  - Runs `git status --porcelain`, `git stash list`, `git log <baseline-head>..HEAD`, `git branch --show-current` on each listed repo (default: `/workspace` and `/devshop`).
  - Compares against baseline.
  - Emits one of:
    - `CLEAN` (exit 0) — nothing changed OR all deltas are explained commits.
    - `DRIFT:\n  <delta details>\nSUGGESTED_FOLLOWUP: <message for parent to send via SendMessage>` (exit 1).
  - Deterministic only — no LLM call.
- Bats tests for both scripts (devshop convention — `check-test-coverage.sh` enforces).
- Skill integration: every `Agent()` call in `/ak-build` and `/ak-implement` wrapped as `snapshot → spawn → check → optional SendMessage loop → next`.

**Cost**: 2–4 hours build + tests. Recurring: ~500–1000 tokens per pipeline run on the happy path (snapshot + report + deterministic check). ~500–2000 tokens per negotiation round, triggered only when drift is detected (rare by construction if the pattern works).

### Risks to mitigate during Phase 2

- **False positives** — subagents legitimately leave scaffolding for the parent. Mitigation: the structural-reason escape hatch in the prompt block, plus `check-subagent-cleanup.sh` reporting DRIFT with details rather than auto-blocking — parent still decides.
- **False negatives** — subagent writes outside snapshotted repos (e.g., `/tmp`, other paths) or commits to an unexpected branch. Mitigation: the snapshot includes HEAD + current branch + stash list, not just the working tree. Consider snapshotting branch list too if orphan branches are observed in Phase 1 logs.
- **Parallel subagents** — concurrent `Agent()` calls interleave state; a single-shot snapshot misattributes deltas. Mitigation: snapshot per subagent keyed by `agentId`; OR require parallel subagents to be read-only (encoded as a rule in `kit/docs/guide/agents.md`).
- **Pattern drift** — new skills may be written without the prompt block and silently skip the discipline. Mitigation: bats test that every skill containing `Agent(...)` also contains the clean-state prompt marker (e.g., a `## Before reporting done` anchor).
- **Hook regression** — someone later "improves" the prompt-layer pattern into a `SubagentStop` hook that injects cleanup demands into subagent context, recreating the hook-migration bug. Mitigation: call this out explicitly in `check-subagent-cleanup.sh`'s header comment AND in `kit/docs/guide/hooks.md` alongside the migration history. The guardrail is: **parent-initiated, subagent-consumed** messages are safe; **hook-initiated, subagent-consumed** injections are not.

---

## Out of scope (explicitly deferred)

- **Auto-dropping stashes by age marker** (`stash push -m "auto-drop-after-YYYY-MM-DD"` convention). Separate track — solves untracked/stash accumulation outside subagent flows. Revisit after Phase 1 data shows whether in-session cleanup via this pattern is sufficient.
- **Stop / SessionEnd-style hook** that blocks session termination on dirty state. Too invasive; the SessionStart heads-up at the next session is the agreed soft-surface replacement.
- **Cross-session drift tracking** via persistent marker file (e.g., `STALE-WIP-SEEN-COUNT=3` escalation). Reasonable enhancement but independent of subagent cleanup — file separately if Phase 1 surfaces cross-session accumulation as the dominant failure mode.

---

## Handoff

When picking this up in a fresh session:

1. Read this doc top to bottom.
2. Confirm Phase 1 instrumentation scope still matches the current skill inventory (new skills with `Agent()` calls may have been added since authoring).
3. Check if `kit/notes/roadmap/` has been touched since 2026-04-19 — this plan may need reconciliation with any intervening hook/skill changes.
4. Implement Option A logger + call-sites in `/ak-build` and `/ak-implement` SKILL.md files.
5. Run for the agreed sample window (~2 weeks or ~30 spawns).
6. Evaluate against the decision gate. Either delete this plan (skip Phase 2) or proceed to Phase 2 via the path the data selects.
