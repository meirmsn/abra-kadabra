<!-- generated-by: hand-written (devshop feature, not via /ak-spec) -->
<!-- feature: ak-build-phase-decomposition -->
<!-- date: 2026-05-19 -->

# Spec: ak-build-phase-decomposition

**Sources:**

- `/devshop/kit/ROADMAP.md § /ak-build pipeline — per-gate sub-agent decomposition` — primary scope (deliverables B–E; deliverable A shipped on 2026-05-17 via `a257f34`)
- `/devshop/.claude/skills/devshop/build/SKILL.md` — Phase 3 (line 587), Phase 5.4 (line 1179), tracker conventions
- `/devshop/.claude/skills/devshop/pre-ship/SKILL.md` — Outcome semantics, gate gauntlet, Router Summary, Stuck protocol
- `/devshop/.claude/skills/devshop/check-docs-and-tests/SKILL.md` — Step 3 sub-skill dispatch
- `/devshop/.claude/skills/devshop/implement/SKILL.md` — Step 3 implementation loop, Stuck protocol
- Triggering incident: home-os feature/decide-state on 2026-05-17 — Phase 3 subagent crashed at Gate 6/13 after ~2h / 207 tool uses. Documented in commit `0488ec3` (devshop).

---

## Product update

### Headline (user-facing)

Pre-ship gauntlet runs as per-gate sub-agents — a dropped socket or runaway context costs one gate, not the whole 2-hour pass.

### Detail (team-facing)

`/ak-build` Phase 3 used to run all 13 quality gates inside one continuous sub-agent context. When that agent's socket dropped or context filled up partway through (as happened on home-os 2026-05-17 at Gate 6/13 after ~2h), every completed gate's work was at risk and recovery required hand-stitching state. Phase 5's CI fix-loop and Phase 2's stuck-protocol shared the same monolithic-context shape on a smaller scale, and Phase 5.8's docs+tests audit ran two read-only sub-skills sequentially when they could run in parallel.

This PR decomposes all four into the shapes that match what the work actually is:

- **Phase 3** splits into a Stabilize-HEAD pass (sequential per-gate sub-agents that may commit fixes) and an Analysis pass (parallel read-only sub-agents). Each gate sub-agent writes to its own file under `specs/<feature>/gates/<gate-name>.md`; the orchestrator concatenates into `review.md` after each pass.
- **Phase 5.4** dispatches each CI fix attempt as a fresh sub-agent. Each attempt appends a structured "already-tried" section to `specs/<feature>/fix-attempts.md`; the next attempt reads it before doing anything else — clean inference, persistent learning.
- **Phase 5.8** parallelizes `/ak-docs-review` and `/ak-tests-review` with the same per-file-sink pattern.
- **`/ak-implement` stuck protocol** refines attempt 2 (fresh sub-agent + already-tried log) and attempt 3 (fresh + log + spec re-read + devil's-advocate critic).

Failure isolation, parallelism on read-only analysis (~10–15 min saved per Phase 3 with findings; ~½ off Phase 5.8), and a live tracker that shows which gate / attempt is firing instead of a 2-hour static spinner.

---

## Decisions (resolved at spec time)

### D1: Per-gate file path scheme

**Decision:** Each gate sub-agent writes to `specs/<feature>/gates/<gate-name>.md` using the canonical gate name from `pre-ship/SKILL.md § Gates (canonical order + named IDs)` (e.g. `docs-check.md`, `cso.md`, `qa.md`). The Phase 5.8 audit pair writes `specs/<feature>/gates/audit-N-docs.md` and `specs/<feature>/gates/audit-N-tests.md` where N is the audit number.

**Rationale:** Names are stable across pipeline-ordering changes (the canonical table re-numbers when gates are added; names don't). The `gates/` subdirectory keeps `specs/<feature>/` scannable — without it, 13+ per-gate files would clutter alongside `spec.md` / `tasks.md` / `review.md`. The orchestrator concatenates these into `review.md` at the end of each pass; the shards are kept on disk (not deleted) so a crashed-mid-concat resume can re-read them.

### D2: Concatenation policy + idempotence

**Decision:** After each pass returns, the orchestrator reads every `specs/<feature>/gates/<gate-name>.md` written by gates in that pass and concatenates them into `review.md` as `## Gate <#>: <name>` sections (numbering from the canonical gates table). Phase 5.8 concatenates audit pair into a single `## Audit N` section, with `### Docs findings` / `### Tests findings` sub-sections. Concatenation is idempotent — re-running pass replaces, doesn't duplicate, existing sections.

**Rationale:** Phase 6's PR audit comment template already reads `review.md`; preserving that interface means Phase 6 doesn't change. The gate shards are the new internal artifact; `review.md` remains the public surface.

### D3: Fix-attempts artifact

**Decision:** `specs/<feature>/fix-attempts.md` (one file per fix loop). Each attempt appends a `## Attempt N — <one-line classification>` section with: Hypothesis, Tried (commit SHA), Why ruled out, Ruled-out for next attempt. File is created on first failed attempt; cleared (truncated to header) at the start of each new Phase 5 run for the same feature. Survives the 3-attempt cap as durable record.

**Rationale:** Per the ROADMAP entry's structured format. Cleared per Phase-5-run because each new Phase 5 attempt-set is a fresh investigation (a new push triggered a new CI run; prior attempts on prior CI failures aren't applicable diagnostics for the new failure).

### D4: Task-attempts artifact

**Decision:** `specs/<feature>/task-attempts/T<N>.md` where `<N>` is the task index from `tasks.md`. Same section format as `fix-attempts.md`. Created on first failed test run; cleared at start of next task.

**Rationale:** Per-task isolation — task 5's stuck history isn't relevant to task 7. Lives under a subdirectory because 10+ tasks generate 10+ artifacts; keeps `specs/<feature>/` scannable.

### D5: Halt-on-find vs iterative-fix dispatch routing

**Decision:** Inherited from existing per-gate behavior. Sub-agent prompt is the same for both classes; routing happens in the orchestrator AFTER the sub-agent returns:

- **Iterative-fix gates** (`simplify`, `design-review`, `qa`, `convention`, `benchmark`): sub-agent fixes + commits atomically per fix. Same posture as today's monolithic pre-ship.
- **Halt-on-find gates** (`review`, `cso`, `docs-and-tests-review`/Audit 1): sub-agent surfaces findings, returns. Orchestrator routes by severity. High → escalate to operator; medium → list in Phase 6 audit comment; low → note + proceed; mechanical/obvious → orchestrator dispatches a focused fix sub-agent (deliverable B, separate sub-agent).

**Rationale:** Preserves the existing trust boundary on security/SQL-critical findings (don't auto-fix without operator read). The orchestrator owns the routing decision because severity classification can change as a function of the findings text — the gate sub-agent shouldn't have to know how its findings will be triaged.

### D6: Test:unit checkpoint placement

**Decision:** Between every code-changing gate sub-agent in the Stabilize-HEAD pass, the orchestrator runs `pnpm turbo run test:unit` (turbo cache; typically ~1s when nothing changed). On failure, the orchestrator invokes the stuck protocol (try-fix × 2 → `/investigate` → escalate) at the orchestrator boundary, NOT inside the next gate sub-agent.

**Rationale:** The roadmap entry specifies this. Keeping the checkpoint at the orchestrator boundary means the per-gate sub-agent context is bounded to its own scope — it doesn't inherit knowledge of test failures from a previous gate.

### D7: Backward compatibility

**Decision:** When a `specs/<feature>/gates/` directory does not exist (older features), `review.md` reading still works against the legacy monolithic `review.md` format. Phase 6 audit comment template reads `review.md` only — it doesn't need to know about the shards. No migration of historical features.

**Rationale:** Existing features have shipped — their `review.md` is historical record. The new shape is forward-only.

### D8: Phase 5.4 fix-loop fresh-agent — what does "fresh" mean concretely

**Decision:** Each attempt is a separate `Agent` tool invocation (subagent_type: general-purpose) with a prompt that includes:

1. The CI failure log/artifacts (per existing 5.4 tier-escalation rules).
2. The contents of `fix-attempts.md` (empty on attempt 1, populated on attempt 2+).
3. An instruction to read `fix-attempts.md` first and avoid ruled-out approaches without explicitly justifying why a prior ruling-out was wrong.
4. An instruction to append its `## Attempt N` section to `fix-attempts.md` as the LAST step before returning (so the log persists across the agent boundary).

**Rationale:** The Agent tool is the right primitive — it produces a fresh inference context per invocation. The agent reads/writes the file inside its own context, so the orchestrator doesn't need to marshal state.

### D9: Devil's-advocate critic at attempt 3 (deliverable E)

**Decision:** When `/ak-implement` Step 3 hits attempt 3 on a stuck task, the main agent spawns a single sub-sub-agent (Agent tool with prompt: "Given the contents of `specs/<feature>/task-attempts/T<N>.md`, enumerate what's structurally wrong with the approach class. Propose 2-3 fundamentally different tactics, not variations of what already failed."). The output is appended to `T<N>.md` as a `## Devil's advocate (attempt 3)` section. The main agent then attempts the fix using this critique as input.

**Rationale:** The "step back" moment is what the existing stuck protocol underspecifies. Forcing a structurally-different-tactic enumeration before attempting the third fix is the cheapest way to surface "we've been variations-of-wrong all along."

---

## In scope

1. Rewrite `/ak-build/SKILL.md § Phase 3` for per-gate sub-agent dispatch + per-file sinks + halt-on-find routing.
2. Rewrite `/ak-build/SKILL.md § Phase 5.4` for fresh-agent-per-attempt + `fix-attempts.md` artifact.
3. Update `/ak-pre-ship/SKILL.md § Outcome semantics` documenting the per-gate-file sink convention; clarify Stuck protocol scope (per-gate vs orchestrator-boundary).
4. Rewrite `/ak-check-docs-and-tests/SKILL.md § Step 3` for parallel sub-skill dispatch + per-file sinks (`audit-N-docs.md` / `audit-N-tests.md`).
5. Refine `/ak-implement/SKILL.md § Step 3` stuck protocol: attempt 2 fresh + log; attempt 3 fresh + log + devil's-advocate critic + spec re-read.
6. Update `kit/docs/guide/workflow.md` Phase 3 / Phase 5.4 / Phase 5.8 prose mirrors.
7. Bats regression tests for: gate-name extraction, per-file-sink path scheme, concatenation idempotence, fresh-agent attempt cap, stuck-protocol attempt-3 dispatch.
8. Close `kit/ROADMAP.md § /ak-build pipeline — per-gate sub-agent decomposition` + PLAN row + bundling-cheatsheet note (per CLAUDE.md § Closing TODO/ROADMAP entries when a fix ships).

## Out of scope

- Sibling row `ak-build-phase3-blocked-halt` — independent ship per PLAN cheatsheet.
- Phase 1 (`/ak-spec`) decomposition — single-narrative, leave monolithic per ROADMAP entry's generalization-question call-out.
- Phase 5.9 visual refresh decomposition — shared browse daemon makes captures serial; leave monolithic.

## Files to create/modify

| Path                                                            | Change                                                                                                                              |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/devshop/build/SKILL.md`                         | Rewrite § Phase 3 + § Phase 5.4 for per-gate / fresh-agent shape; bump version frontmatter                                          |
| `.claude/skills/devshop/pre-ship/SKILL.md`                      | Document per-gate-file sink + clarify Stuck-protocol scope                                                                          |
| `.claude/skills/devshop/check-docs-and-tests/SKILL.md`          | Parallel dispatch in § Step 3 + per-file sinks                                                                                      |
| `.claude/skills/devshop/implement/SKILL.md`                     | Refined § Step 3 stuck protocol (attempts 2 + 3)                                                                                    |
| `kit/docs/guide/workflow.md`                                    | Mirror prose for Phase 3 / 5.4 / 5.8 / stuck protocol                                                                               |
| `kit/tests/` (new bats files)                                   | Regression tests on the structural conventions                                                                                      |
| `kit/ROADMAP.md`                                                | Delete § `/ak-build pipeline — per-gate sub-agent decomposition`                                                                    |
| `PLAN.md`                                                       | Remove Active row (after promoting from Planned at start of feature); remove bundling-cheatsheet "absorbed sub-deliverables" line   |
| `BUILD-LOG.md`                                                  | Append ship entry at squash time (via `/ak-merge-devshop`)                                                                          |
| `specs/ak-build-phase-decomposition/spec.md`                    | This file                                                                                                                           |
| `specs/ak-build-phase-decomposition/tasks.md`                   | Phase 2 / `/ak-implement`-equivalent task list (written below by hand)                                                              |
| `specs/ak-build-phase-decomposition/review.md`                  | Phase 3 / `/ak-pre-ship`-equivalent audit trail                                                                                     |

## Tests

Each deliverable carries bats regression tests in `kit/tests/` covering the structural conventions:

- **D**: parallel-dispatch shape (start-stamp ordering shows both sub-skills started before either finished); per-file sink paths match `audit-N-{docs,tests}.md`; concatenation idempotence.
- **E**: stuck protocol attempt-2 reads `task-attempts/T<N>.md`; attempt-3 includes devil's-advocate section in the log; escalation still fires after attempt 3.
- **C**: fix-loop attempt-N reads `fix-attempts.md`; appends `## Attempt N` section; 3-attempt cap enforced; Phase 5.5 escalation fires.
- **B**: gate-name extraction maps to canonical names; per-file sink paths match `gates/<gate-name>.md`; halt-on-find vs iterative-fix routing by gate name; test:unit checkpoint between code-changing gates fires at the orchestrator boundary.

Snapshot tests on the canonical SKILL.md phrases (catch wording reverts) per the precedent set by commit `a257f34` (deliverable A's 20 mutation-verified bats tests).

## Task order

1. **D — Phase 5.8 parallelize** (~1 hr). Smallest deliverable; exercises the per-file-sink pattern in isolation; validates the orchestrator-concatenates pattern before applying it to the larger Phase 3.
2. **E — `/ak-implement` stuck protocol refinement** (~2 hr). Self-contained surface; uses the fresh-agent-per-attempt pattern on a smaller artifact.
3. **C — Phase 5.4 fix-loop fresh-agent** (~2 hr). Applies the same fresh-agent-per-attempt pattern to the CI fix loop; pairs naturally with E.
4. **B — Phase 3 per-gate decomposition** (~3-5 hr). The substantive refactor; sits on top of the patterns validated by D + E + C.
5. **Docs sweep** — `kit/docs/guide/workflow.md` mirror prose; cross-reference audit.
6. **Tracker closure** — delete ROADMAP entry + PLAN row + bundling-cheatsheet line; PLAN row promoted at task 0 (Active) gets removed at this step.

## Out-of-band deploy items

None — pure SKILL.md + guide-doc + bats-test change. No migration, no env var, no third-party API.

## Manual review

None expected.

## Test plan

- [ ] Bats regression suite passes locally (`kit/tests/run.sh` or equivalent).
- [ ] Snapshot tests on canonical SKILL.md phrases pass.
- [ ] Manual smoke: read each modified SKILL.md end-to-end and confirm the orchestration prose is coherent (sub-agent dispatch language, per-file sink convention, concatenation step, halt-on-find routing).

## Engineering details (TL;DR for the squash-commit body)

Per-gate sub-agent decomposition across the four monolithic-context surfaces in `/ak-build`: Phase 3 gauntlet (B), Phase 5 fix-loop (C), Phase 5.8 audit pair (D), and `/ak-implement` stuck protocol (E). Each gate / attempt becomes its own `Agent` tool invocation writing to a per-file sink (`specs/<feature>/gates/<name>.md`, `fix-attempts.md`, `task-attempts/T<N>.md`); the orchestrator concatenates into the existing `review.md` interface after each pass. Phase 3 splits into a Stabilize-HEAD pass (sequential, may commit fixes) and an Analysis pass (parallel, read-only). Bats regression tests cover the structural conventions per the precedent set by deliverable A (`a257f34`). Closes `kit/ROADMAP.md § /ak-build pipeline — per-gate sub-agent decomposition`.
