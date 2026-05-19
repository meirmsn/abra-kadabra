#!/usr/bin/env bats
# Tests for .claude/skills/devshop/implement/SKILL.md — content-validation tests
# on the stuck-protocol contract. The skill is a pure LLM prompt, so we grep for
# the required structural language. Behavior tests (running the LLM) are out of
# scope; this proves the prompt has the shape the orchestrator depends on.

setup() {
  load helpers/setup
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/implement/SKILL.md"
}

# === File presence + frontmatter ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "frontmatter declares name: ak-implement" {
  grep -q '^name: ak-implement$' "$SKILL_FILE"
}

@test "frontmatter declares Agent in allowed-tools (stuck protocol dispatches sub-agents)" {
  # Attempts 2 + 3 spawn fresh Agent invocations with the already-tried log;
  # attempt 3 also spawns a devil's-advocate sub-sub-agent. Without `- Agent`
  # in allowed-tools, the dispatch can't happen.
  grep -qE '^[[:space:]]*-[[:space:]]+Agent[[:space:]]*$' "$SKILL_FILE"
}

@test "frontmatter version is 3.0.0+ (bumped for stuck-protocol refinement)" {
  grep -qE '^version: ([3-9]|[1-9][0-9])\.[0-9]+\.[0-9]+' "$SKILL_FILE"
}

# === Stuck-protocol contract ===

@test "stuck protocol names a per-task log at task-attempts/T<N>.md" {
  grep -qE 'task-attempts/T<N>\.md' "$SKILL_FILE"
}

@test "Attempt 1 appends a structured `## Attempt 1` section to the log on failure" {
  grep -qE '## Attempt 1 — <one-line failure classification>' "$SKILL_FILE"
  grep -qE '^[[:space:]]*-[[:space:]]+Hypothesis:' "$SKILL_FILE"
  grep -qE '^[[:space:]]*-[[:space:]]+Tried:' "$SKILL_FILE"
  grep -qE '^[[:space:]]*-[[:space:]]+Why ruled out:' "$SKILL_FILE"
  grep -qE '^[[:space:]]*-[[:space:]]+Ruled out for next attempt:' "$SKILL_FILE"
}

@test "Attempt 2 is a fresh Agent sub-invocation with the already-tried log" {
  # The whole point of fresh-agent-per-attempt is breaking inherited bias from
  # the prior failed reasoning chain. The dispatch must be a fresh Agent call,
  # and the agent must read T<N>.md before doing anything else.
  tr '\n' ' ' < "$SKILL_FILE" | tr -s '[:space:]' ' ' \
    | grep -qE 'Attempt 2.*fresh.*Agent.*sub-agent'
  grep -q 'READ IT FIRST' "$SKILL_FILE"
}

@test "Attempt 2 agent must not repeat a ruled-out approach without justification" {
  # The whole purpose of the log is preventing the repeat. The agent must
  # explicitly justify why a prior ruling-out was wrong if it wants to re-try.
  grep -qE "Do not repeat any" "$SKILL_FILE"
  grep -qE "Ruled out for next attempt" "$SKILL_FILE"
}

@test "Attempt 3 layers two meta-checks: spec re-read + devil's-advocate critic" {
  grep -qE 'Spec re-read' "$SKILL_FILE"
  grep -qiE "[Dd]evil.s.advocate critic" "$SKILL_FILE"
}

@test "Attempt 3 spawns a separate devil's-advocate sub-sub-Agent" {
  # The devil's-advocate critic is a separate Agent call writing to T<N>.md
  # as `## Devil's advocate (attempt 3)` — not the same agent doing both
  # the critique and the fix.
  grep -qE "Devil.s advocate — T<N>" "$SKILL_FILE"
  grep -qE "## Devil.s advocate \(attempt 3\)" "$SKILL_FILE"
}

@test "Attempt 3 right-sizing escape hatch: PROPOSE SPLIT" {
  # Recognition that a stuck task may actually be 2–3 latent sub-tasks
  # pretending to be one. The agent surfaces this rather than continuing
  # to bang on the original framing.
  grep -q 'PROPOSE SPLIT' "$SKILL_FILE"
  grep -qE 'right-sized' "$SKILL_FILE"
}

@test "PROPOSE SPLIT routes through AskUserQuestion (operator decides split vs override)" {
  grep -q 'AskUserQuestion' "$SKILL_FILE"
}

@test "Attempt 3 unresolved → existing escalation behavior preserved" {
  # The 3-attempt cap + 'mark task blocked + ping user' rail must survive.
  grep -qE 'mark task .blocked. in tasks.md' "$SKILL_FILE"
  grep -qiE 'ping user' "$SKILL_FILE"
}

# === Loop integration (Step 3 implementation loop still calls stuck protocol) ===

@test "Step 3 implementation loop still calls stuck protocol on test failure" {
  # The Step 3 loop's step 9 ('Tests fail: enter stuck protocol') wires the
  # loop into the refined stuck protocol below. If the loop step ever silently
  # drops the stuck-protocol entrypoint, the refinement becomes dead code.
  grep -qE 'Tests fail.*stuck protocol' "$SKILL_FILE"
}

# === Anti-regression: the underspecified pre-refinement prose is gone ===

@test "pre-refinement prose 'Attempts 1-2: read the error, hypothesize root cause' is gone" {
  # The old shape collapsed attempts 1 + 2 into a single bullet without the
  # fresh-agent isolation. If that prose reappears, the refinement was
  # reverted and the bias-carry-forward failure mode comes back.
  ! grep -qE 'Attempts 1.2.+read the error, hypothesize root cause, fix, rerun' "$SKILL_FILE"
}

@test "pre-refinement /investigate dispatch at attempt 3 is gone (replaced by spec re-read + devil's advocate)" {
  # The old shape ran /investigate via Skill tool at attempt 3 inside the
  # same agent context. The refined shape replaces that with the
  # spec-re-read + devil's-advocate combination.
  ! grep -qE "Attempt 3 .same error.: invoke ./investigate." "$SKILL_FILE"
}
