#!/usr/bin/env bats
# Tests for .claude/skills/devshop/build/SKILL.md § Phase 3 (per-gate sub-agent
# decomposition, deliverable B of ak-build-phase-decomposition) +
# .claude/skills/devshop/pre-ship/SKILL.md § Audit trail / § Stuck protocol
# updates that accompany it.
#
# Phase 3 used to dispatch one Agent to run the entire 13-gate gauntlet inside
# one continuous context. The refined shape dispatches per-gate sub-agents in
# two ordered passes (Stabilize-HEAD sequential / Analysis parallel) with
# per-file sinks under specs/<feature>/gates/<gate-name>.md.
#
# These are content-validation tests on the SKILL.md prose. Behavior tests
# (running the LLM) are out of scope; this proves the prompt has the shape
# the orchestrator depends on.

setup() {
  load helpers/setup
  BUILD_SKILL="$TESTS_DIR/../../.claude/skills/devshop/build/SKILL.md"
  PRESHIP_SKILL="$TESTS_DIR/../../.claude/skills/devshop/pre-ship/SKILL.md"
}

# === Phase 3 section header reflects the refinement ===

@test "build/SKILL.md § Phase 3 names the per-gate sub-agent shape" {
  grep -qE '^## Phase 3: Pre-ship.*per-gate sub-agent gauntlet' "$BUILD_SKILL"
}

# === Two-pass shape ===

@test "Phase 3 splits into Stabilize-HEAD and Analysis passes" {
  grep -qE 'Stabilize-HEAD' "$BUILD_SKILL"
  grep -qiE 'Analysis pass|analysis-pass' "$BUILD_SKILL"
}

@test "Stabilize-HEAD pass is documented as sequential" {
  awk '/^### 3\.1: Stabilize-HEAD/,/^### 3\.2:/' "$BUILD_SKILL" \
    | grep -qiE 'sequential'
}

@test "Analysis pass is documented as parallel (single tool-use turn)" {
  awk '/^### 3\.2: Analysis pass/,/^### 3\.3:/' "$BUILD_SKILL" \
    | grep -qiE 'single tool-use turn|parallel'
}

@test "Analysis-pass parallel-write race is resolved by per-file sinks" {
  # The race exists because docs Audit 1 + /review + /cso etc. could all write
  # to review.md concurrently. The per-file-sink scheme makes each agent's
  # write target unique.
  awk '/^### 3\.2: Analysis pass/,/^### 3\.3:/' "$BUILD_SKILL" \
    | grep -qiE 'per-file-sink|race-free|unique'
}

# === Per-gate file sink path scheme ===

@test "Phase 3 documents per-gate file sinks under specs/<feature>/gates/<canonical-gate-name>.md" {
  grep -qE 'specs/<feature>/gates/<canonical-gate-name>\.md' "$BUILD_SKILL"
}

@test "Phase 3 references canonical gate names from pre-ship/SKILL.md § Gates" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qE "canonical name|pre-ship/SKILL\.md § Gates"
}

@test "Phase 3 names representative canonical gate files (docs-check, cso, qa)" {
  grep -qE 'docs-check\.md' "$BUILD_SKILL"
  grep -qE 'cso\.md' "$BUILD_SKILL"
  grep -qE 'qa\.md' "$BUILD_SKILL"
}

# === Halt-on-find vs iterative-fix dispatch routing ===

@test "Phase 3 documents the halt-on-find vs iterative-fix routing split" {
  grep -qE 'Halt-on-find vs iterative-fix dispatch' "$BUILD_SKILL"
}

@test "Iterative-fix gates documented: simplify, design-review, qa, design-conformance, convention" {
  awk '/Iterative-fix gates/,/Halt-on-find gates/' "$BUILD_SKILL" \
    | grep -qE '/simplify'
  awk '/Iterative-fix gates/,/Halt-on-find gates/' "$BUILD_SKILL" \
    | grep -qE '/design-review'
  awk '/Iterative-fix gates/,/Halt-on-find gates/' "$BUILD_SKILL" \
    | grep -qE '/qa'
  awk '/Iterative-fix gates/,/Halt-on-find gates/' "$BUILD_SKILL" \
    | grep -qE 'design-conformance'
  awk '/Iterative-fix gates/,/Halt-on-find gates/' "$BUILD_SKILL" \
    | grep -qE 'convention'
}

@test "Halt-on-find gates documented: review, cso, docs-and-tests-review, rls-coverage" {
  awk '/Halt-on-find gates/,/Deterministic gates/' "$BUILD_SKILL" \
    | grep -qE '/review'
  awk '/Halt-on-find gates/,/Deterministic gates/' "$BUILD_SKILL" \
    | grep -qE '/cso'
  awk '/Halt-on-find gates/,/Deterministic gates/' "$BUILD_SKILL" \
    | grep -qE 'docs-and-tests-review'
  awk '/Halt-on-find gates/,/Deterministic gates/' "$BUILD_SKILL" \
    | grep -qE 'rls-coverage'
}

@test "Halt-on-find findings route by severity (high → escalate, mechanical → focused fix dispatch)" {
  # Phrasing wraps across two markdown lines; collapse whitespace before
  # grepping. Tolerate optional `**` bold markdown around "mechanical/obvious".
  tr '\n' ' ' < "$BUILD_SKILL" | tr -s '[:space:]' ' ' \
    | grep -qE 'high → escalate to operator'
  tr '\n' ' ' < "$BUILD_SKILL" | tr -s '[:space:]' ' ' \
    | grep -qE '(\*\*)?mechanical/obvious(\*\*)? → orchestrator dispatches a focused fix sub-agent'
}

# === Test:unit checkpoints at the orchestrator boundary ===

@test "Phase 3 documents test:unit checkpoints between code-changing gates at the orchestrator boundary" {
  # Phrasing wraps across markdown lines; collapse whitespace before grepping.
  grep -qE 'Test:unit checkpoints between code-changing gates' "$BUILD_SKILL"
  tr '\n' ' ' < "$BUILD_SKILL" | tr -s '[:space:]' ' ' \
    | grep -qE 'NOT inside the next gate sub-agent'
}

# === Concatenation step (3.3) ===

@test "Phase 3.3 concatenates sinks into review.md in canonical-gate order" {
  grep -qE '^### 3\.3: Concatenate sinks → review\.md' "$BUILD_SKILL"
  awk '/^### 3\.3:/,/^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qiE 'canonical-gate order|canonical-gate-name'
}

@test "Phase 3.3 idempotent on re-run (overwrites prior sections, not duplicates)" {
  awk '/^### 3\.3:/,/^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qiE 'idempotent|overwrites'
}

@test "Phase 3.3 aggregates per-gate Dismissals into the top-of-file Router Summary" {
  awk '/^### 3\.3:/,/^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qE 'Router Summary'
}

@test "Phase 3.3 stamps review.md with <!-- audited-at: <SHA> --> for Phase 5.8 parse contract" {
  awk '/^### 3\.3:/,/^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qE '<!-- audited-at:'
}

# === Phase 3 → Phase 4 handoff preserved ===

@test "Phase 3 → Phase 4 handoff preserves Rung 1 / 2 / 3 prose (findings / blocked / forbidden n/a)" {
  grep -qE 'Phase 3 → Phase 4 handoff' "$BUILD_SKILL"
  grep -qE 'Rung 1' "$BUILD_SKILL"
  grep -qE 'Rung 2' "$BUILD_SKILL"
  grep -qE 'Rung 3' "$BUILD_SKILL"
}

# === pre-ship/SKILL.md companion edits ===

@test "pre-ship § Audit trail documents per-gate file sinks under specs/<feature>/gates/" {
  # Range-end uses `^## Phase 0:` (the next top-level heading) so the range
  # doesn't collapse to a single line by matching `^## Audit trail` itself.
  awk '/^## Audit trail/,/^## Phase 0:/' "$PRESHIP_SKILL" \
    | grep -qE 'specs/<feature>/gates/<canonical-gate-name>\.md'
}

@test "pre-ship § Audit trail explains failure isolation rationale (crashed agent loses one gate's work)" {
  awk '/^## Audit trail/,/^## Phase 0:/' "$PRESHIP_SKILL" \
    | grep -qiE 'crashed-mid-run|one gate.s work'
}

@test "pre-ship § Stuck protocol clarifies scope split (per-gate vs orchestrator-boundary)" {
  awk '/^## Stuck protocol/,/^## Behavior/' "$PRESHIP_SKILL" \
    | grep -qiE 'Per-gate stuck protocol'
  awk '/^## Stuck protocol/,/^## Behavior/' "$PRESHIP_SKILL" \
    | grep -qiE 'Orchestrator-boundary stuck protocol'
}

@test "pre-ship/SKILL.md version bumped to 4.x for per-gate decomposition" {
  grep -qE '^version: [4-9]\.' "$PRESHIP_SKILL"
}

# === Anti-regression: the monolithic "Launch Agent with prompt" header is gone ===

@test "Phase 3 no longer starts with the monolithic 'Launch Agent with prompt' shape" {
  # The pre-decomposition shape opened with `Launch **Agent** with prompt:` and
  # passed `/devshop:pre-ship for feature` to one giant sub-agent. The refined
  # shape opens with `Phase 3 runs the /ak-pre-ship gauntlet as a series of
  # per-gate sub-agent dispatches…`. If the monolithic header ever reappears,
  # the decomposition has been reverted.
  ! awk '/^## Phase 3:/,/^### 3\.1:|^## Phase 4:/' "$BUILD_SKILL" \
    | grep -qE '^Launch \*\*Agent\*\* with prompt:'
}
