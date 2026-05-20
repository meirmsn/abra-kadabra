# Tasks: ak-build-phase-decomposition

Hand-authored task list (this is a devshop feature; `/ak-spec` doesn't apply directly).

## Tasks

### T1: Deliverable D — parallelize `/ak-check-docs-and-tests` sub-skills [todo]

Rewrite `.claude/skills/devshop/check-docs-and-tests/SKILL.md § Step 3` to:

- Dispatch `/ak-docs-review` and `/ak-tests-review` in parallel (single tool-use turn with two Agent calls).
- Each sub-skill writes to `specs/<feature>/gates/audit-N-docs.md` and `specs/<feature>/gates/audit-N-tests.md`.
- Orchestrator concatenates both into the `## Audit N` section of `review.md` after both return.

Bats tests:

- `kit/tests/skills/check-docs-and-tests-parallel.bats` — confirm canonical prose (per-file sink convention, parallel-dispatch language); mutation-verify by removing the parallel phrase.

### T2: Deliverable E — `/ak-implement` stuck protocol refinement [todo]

Rewrite `.claude/skills/devshop/implement/SKILL.md § Step 3 § Stuck protocol`:

- Attempt 1: natural (unchanged).
- Attempt 2: fresh `Agent` sub-agent invocation reading `specs/<feature>/task-attempts/T<N>.md` first; appends its own `## Attempt 2` section before returning.
- Attempt 3: fresh sub-agent + `T<N>.md` log + spec re-read (instruction to re-read `spec.md` and consider whether the task is right-sized) + devil's-advocate sub-sub-agent (separate Agent call enumerating "what's wrong with the approach class?"); appends `## Attempt 3` + `## Devil's advocate (attempt 3)` sections.
- Attempt 3 fail: existing escalation behavior unchanged (block + ping user).

Bats tests:

- `kit/tests/skills/ak-implement-stuck-protocol.bats` — canonical-prose snapshot for attempts 2 + 3, devil's-advocate dispatch phrase.

### T3: Deliverable C — Phase 5 fix-loop fresh-agent-per-attempt [todo]

Rewrite `.claude/skills/devshop/build/SKILL.md § Phase 5.4`:

- Each iteration of the `while CI is failing` loop now dispatches a fresh `Agent` invocation.
- Each attempt reads `specs/<feature>/fix-attempts.md` first (empty on attempt 1).
- Each attempt writes a `## Attempt N — <classification>` section as its final action before returning.
- Preserve 3-attempt cap + Phase 5.5 escalation prose.
- Preserve artifact-pull tier-escalation rules verbatim (attempt 1 log-based, attempt 2+ trace.zip).
- Preserve workflow-scope detection (PAT can't push `.github/workflows/`).

Bats tests:

- `kit/tests/skills/ak-build-fix-loop.bats` — canonical-prose snapshot for fresh-agent dispatch, fix-attempts.md log shape, 3-attempt cap.

### T4: Deliverable B — Phase 3 per-gate decomposition [todo]

Rewrite `.claude/skills/devshop/build/SKILL.md § Phase 3`:

- Stabilize-HEAD pass: sequential per-gate sub-agent dispatch (preflight → docs-check → metrics-check → fast-job-local → changed-tests-local → migration-rollback-roundtrip → responsive-theme → simplify → design-review → design-conformance → qa → hero shots). Each gate is one `Agent` call. Test:unit checkpoint between code-changing gates at the orchestrator boundary.
- Analysis pass: parallel per-gate sub-agent dispatch (docs-and-tests-review/Audit 1 || review || cso || convention || preflight-final). Single tool-use turn with N Agent calls.
- Per-gate file sink: each gate sub-agent writes to `specs/<feature>/gates/<canonical-gate-name>.md` (gate names from `pre-ship/SKILL.md § Gates (canonical order + named IDs)`).
- Concatenation: after each pass returns, orchestrator reads every `gates/<name>.md` written in that pass and concatenates into `review.md` as `## Gate <#>: <name>` sections. Idempotent on re-run.
- Halt-on-find vs iterative-fix routing: orchestrator inspects each gate's return; iterative-fix gates' sub-agents have already committed their fixes (status: `findings (N) fixed`); halt-on-find gates' sub-agents return findings only (status: `findings (N) pending`) and orchestrator routes by severity.
- Preserve existing Phase 3 → Phase 4 handoff (Rung 1 / 2 / 3 outcomes).

Update `.claude/skills/devshop/pre-ship/SKILL.md`:

- § Outcome semantics: add the per-gate-file sink convention statement ("each gate sub-agent writes its output to `specs/<feature>/gates/<canonical-gate-name>.md`; the orchestrator concatenates into `review.md`").
- § Stuck protocol: clarify scope ("inside each gate sub-agent for code-change fix-loops; orchestrator-boundary between code-changing gates for test:unit-regression checks").

Bats tests:

- `kit/tests/skills/ak-build-phase3-decomposition.bats` — canonical-prose snapshots for Stabilize-HEAD vs Analysis pass language; per-file-sink path scheme; halt-on-find routing prose. Mutation-verify by removing "Stabilize-HEAD" phrase.

### T5: Docs sweep [todo]

Mirror new prose into `kit/docs/guide/workflow.md`:

- Phase 3 paragraph — describe the two-pass shape (Stabilize-HEAD sequential + Analysis parallel).
- Phase 5 paragraph — describe fresh-agent-per-attempt + `fix-attempts.md` log.
- Phase 5.8 paragraph — describe parallel sub-skill dispatch with per-file sinks.
- Stuck protocol — mention the attempt 2/3 refinement.

Run `grep -rE "ak-build-phase-decomposition|gates/audit-|fix-attempts.md|task-attempts/T" /devshop/kit /devshop/.claude /devshop/CLAUDE.md` and verify any hits are coherent / non-stale.

### T6: Tracker closure [todo]

Per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`:

- Delete `kit/ROADMAP.md § /ak-build pipeline — per-gate sub-agent decomposition` section in full (lines 14-122 of current ROADMAP).
- Delete PLAN.md Active row for `ak-build-phase-decomposition`.
- Delete bundling-cheatsheet line "`ak-build-phase-decomposition` absorbs sub-deliverables B (per-gate decomp) + …".
- Rewrite any prose elsewhere that references the "monolithic Phase 3" or "single-agent fix loop" from conditional ("would benefit from") to imperative present ("Phase 3 runs as per-gate sub-agents").

### T7: Audit + land [todo]

Run audit-time review on the branch (manual `/ak-check-docs-and-tests`-style review since the skill itself is mid-refactor in this PR). Then land via `/ak-merge-devshop` from `/devshop` main.

## Decisions

(Populated as judgment calls are made during implementation. None yet.)
