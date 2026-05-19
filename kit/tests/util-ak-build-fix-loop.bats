#!/usr/bin/env bats
# Tests for .claude/skills/devshop/build/SKILL.md § Phase 5.4 — the fresh-agent
# fix-loop refinement (deliverable C of ak-build-phase-decomposition).
#
# Each fix attempt now runs as a separate Agent tool invocation reading
# specs/<feature>/fix-attempts.md first and writing its own `## Attempt N`
# section as its final action. Same pattern as /ak-implement § Step 3's per-task
# stuck protocol (task-attempts/T<N>.md).
#
# These are content-validation tests on the SKILL.md prose. Behavior tests
# (running the LLM) are out of scope; this proves the prompt has the shape
# the orchestrator depends on.

setup() {
  load helpers/setup
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/build/SKILL.md"
}

# === Phase 5.4 section header reflects the refinement ===

@test "Phase 5.4 header names the fresh-agent-per-attempt shape" {
  grep -qE '^### 5\.4:.*[Ff]resh-agent-per-attempt' "$SKILL_FILE"
}

# === Already-tried log artifact + path ===

@test "Phase 5.4 names the already-tried log at fix-attempts.md" {
  grep -qE 'specs/<feature>/fix-attempts\.md|\$FEATURE_DIR/fix-attempts\.md' "$SKILL_FILE"
}

@test "Phase 5.4 documents fix-attempts.md lifecycle (cleared per Phase 5 run)" {
  # The log is reset at the start of each new Phase 5 invocation — a new push
  # triggered a new CI run, so prior attempts on prior failures aren't
  # applicable diagnostics for the new failure.
  grep -qiE 'cleared.*truncated|truncated.*header' "$SKILL_FILE"
}

# === Fresh-agent dispatch ===

@test "Phase 5.4 dispatches each attempt as a fresh Agent invocation" {
  # The block opens with `Agent { … }` — the canonical fresh-agent dispatch
  # marker. If the block ever collapses back to in-context retry, this test
  # catches the regression.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'Agent \{'
}

@test "Phase 5.4 agent prompt instructs READ FIRST on fix-attempts.md" {
  # Without 'READ FIRST', the fresh agent has no memory of what was tried —
  # it can repeat the same failed approach.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'READ FIRST'
}

@test "Phase 5.4 agent prompt forbids repeating ruled-out approaches without justification" {
  # The whole purpose of the log is preventing the repeat. The agent must
  # explicitly justify why a prior ruling-out was wrong if it wants to re-try.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE "Do not repeat any approach class"
}

@test "Phase 5.4 agent FINAL action appends the `## Attempt N` section" {
  # If the section isn't written by the agent's final action, the log won't
  # persist across the context boundary — the whole point of the refinement.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'FINAL action'
}

@test "Phase 5.4 documents the `## Attempt N — <classification>` section shape" {
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE '## Attempt N — <one-line failure classification>'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'Hypothesis:'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'Tried:'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'Why ruled out:'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'Ruled out for next attempt:'
}

# === Cap + escalation preserved ===

@test "Phase 5.4 preserves 3-attempt cap (MAX_ATTEMPTS=3)" {
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'MAX_ATTEMPTS=3'
}

@test "Phase 5.5 escalation preserved (gh pr comment + @user on max-attempts fail)" {
  grep -qE '^### 5\.5: Escalation after max attempts' "$SKILL_FILE"
  awk '/^### 5\.5:/,/^### 5\.6:/' "$SKILL_FILE" \
    | grep -qE 'gh pr comment'
}

# === Agent-return semantics ===

@test "Phase 5.4 agent return values include workflow-blocked (no increment)" {
  # Workflow-scope detection is preserved: the devcontainer PAT can't push
  # .github/workflows/, so when the fix touches one of those, the loop must
  # exit without incrementing FIX_ATTEMPTS.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'workflow-blocked'
}

@test "Phase 5.4 agent return values include timeout-retry (no increment)" {
  # Empty-commit retries on timeout/flaky failures aren't real fix attempts —
  # they shouldn't count against the 3-attempt cap.
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'timeout-retry'
}

# === Anti-regression: the pre-refinement in-context loop is gone ===

@test "pre-refinement in-context loop shape (FIX_ATTEMPTS += 1 inside loop) does not collapse fresh-agent" {
  # The old shape had `10. FIX_ATTEMPTS += 1` as the second-to-last step of
  # the in-context loop. The refined shape moves that to the orchestrator
  # side AFTER the agent returns. If FIX_ATTEMPTS += 1 ever shows up as an
  # in-agent-prompt step again, the fresh-agent isolation is broken.
  # Check by ensuring the in-agent-step list does not contain a bare
  # 'FIX_ATTEMPTS += 1' line.
  ! awk '/^  Inside-the-sub-agent steps:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE '^[[:space:]]+10\.[[:space:]]+FIX_ATTEMPTS \+= 1'
}

# === Artifact tier-escalation preserved (attempt 1 vs 2+) ===

@test "Phase 5.4 preserves attempt-1 log-based / attempt-2+ artifact-based tier escalation" {
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qiE 'Attempt #1.*log-based inference'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qiE 'Attempt #2\+.*artifact-based investigation'
}

@test "Phase 5.4 preserves trace.zip extraction recipe (load-bearing on attempt 2+)" {
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'trace\.zip'
  awk '/^### 5\.4:/,/^### 5\.5:/' "$SKILL_FILE" \
    | grep -qE 'unzip'
}
