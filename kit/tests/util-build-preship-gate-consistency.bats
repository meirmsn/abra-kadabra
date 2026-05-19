#!/usr/bin/env bats
# Cross-skill invariant tests between .claude/skills/devshop/build/SKILL.md and
# .claude/skills/devshop/pre-ship/SKILL.md.
#
# The decomposed Phase 3 dispatches per-gate sub-agents that write to
# specs/<feature>/gates/<canonical-gate-name>.md. The canonical names come
# from pre-ship/SKILL.md § Gates (canonical order + named IDs) — a markdown
# table whose Name column is the load-bearing identifier.
#
# Drift between the two files (build references a name that doesn't exist in
# pre-ship; pre-ship adds a new gate that build's pass lists don't enumerate)
# breaks the orchestrator silently: the sub-agent writes to a sink path the
# concatenator doesn't read, OR the orchestrator dispatches a gate with no
# sub-skill prompt source.
#
# These tests pin that contract.

setup() {
  load helpers/setup
  BUILD_SKILL="$TESTS_DIR/../../.claude/skills/devshop/build/SKILL.md"
  PRESHIP_SKILL="$TESTS_DIR/../../.claude/skills/devshop/pre-ship/SKILL.md"
}

# Extract canonical gate names from the pre-ship gates table. The table rows
# look like `| 2b  | `rls-coverage`               | ak    | ...` — the second
# column (backtick-quoted) is the name. We strip `|` separators + backticks +
# trim whitespace.
canonical_gate_names() {
  awk '
    /^\| --- /     { in_table=1; next }
    in_table && /^\|/ {
      # Field 3 is the Name column (1st pipe is leading, 2 is #, 3 is name)
      n=split($0, f, "|"); if (n < 4) next
      name=f[3]; gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/`/, "", name)
      print name
    }
    in_table && /^[^|]/ { in_table=0 }
  ' "$PRESHIP_SKILL"
}

@test "pre-ship/SKILL.md § Gates table parses cleanly (at least 15 rows)" {
  count=$(canonical_gate_names | wc -l)
  # As of 2026-05-19 the table has 18 rows. Floor at 15 catches catastrophic
  # mangling (mis-tabled markdown, header drift) without being brittle to
  # adding new gates.
  [ "$count" -ge 15 ]
}

@test "every gate referenced in build/SKILL.md § Phase 3 pass lists exists in pre-ship § Gates table" {
  # Pull the canonical names into a lookup table.
  CANONICAL=$(canonical_gate_names | sort -u)

  # Extract gate names from build/SKILL.md § Phase 3 — specifically the
  # `Stabilize-HEAD gates` and `Analysis-pass gates` enumeration. The lines
  # look like `  - `1 docs-check` → `2 metrics-check` → …`. We strip the
  # leading number/version + the backticks + the routing arrows.
  REFS=$(awk '/^### 3\.1: Stabilize-HEAD/{exit} /^\*\*Why two passes/,/^### 3\.1: Stabilize-HEAD/' "$BUILD_SKILL" \
    | grep -oE '`[0-9]+[a-z]?[[:space:]]+[a-z-]+`' \
    | tr -d '`' \
    | awk '{print $NF}' \
    | sort -u)

  # Bail if extraction failed — we'd silently pass otherwise.
  [ -n "$REFS" ]

  # Every REF must be in CANONICAL. Print any orphans so the failure message
  # names what's missing.
  ORPHANS=""
  for ref in $REFS; do
    # Skip the `/simplify`, `/qa`, etc. variants — they live in pre-ship
    # without the leading slash.
    name=$(echo "$ref" | sed 's|^/||')
    if ! echo "$CANONICAL" | grep -qFx "$name"; then
      ORPHANS="$ORPHANS $name"
    fi
  done

  if [ -n "$ORPHANS" ]; then
    echo "Orphan gate references in build/SKILL.md § Phase 3 pass lists:"
    echo " - $ORPHANS"
    echo "Canonical names from pre-ship § Gates table:"
    echo "$CANONICAL" | sed 's/^/   /'
    return 1
  fi
}

@test "build/SKILL.md § Phase 3 does NOT enumerate 'preflight' as a per-gate dispatch" {
  # preflight is Phase 0 of pre-ship — a tooling check that runs once before
  # the gate loop fires, not as one of the per-gate sub-agents. If build's
  # Phase 3 pass list ever includes `preflight` (without the `-final`
  # suffix), the orchestrator would try to Agent-dispatch it and fail to
  # find a Gate section in pre-ship.
  ! awk '/^\*\*Why two passes/,/^### 3\.1c:/' "$BUILD_SKILL" \
    | grep -qE '`[0-9]+[a-z]?[[:space:]]+preflight`'
  # `preflight-final` (Gate 10b) is allowed — it's distinct from Phase 0
  # preflight. The boundary regex above requires a leading number, which
  # `10b preflight-final` satisfies; the negative assertion above only
  # rejects bare `preflight`.
}

@test "Phase 0 (preflight) is documented as an orchestrator-side step BEFORE the per-gate loop" {
  # Sanity check the carve-out exists. The wording was added when the agent-
  # review surfaced that bare `preflight` had been listed as a Stabilize-HEAD
  # gate, which would dispatch it as a per-gate sub-agent with no source
  # gate section.
  grep -qE 'Phase 0 \(preflight\) runs first, before either pass' "$BUILD_SKILL"
}

@test "Hero-screenshot capture is documented as an orchestrator-side step, NOT a gate" {
  # Hero capture has no canonical gate name in pre-ship's table — it's
  # post-gates work. If build's Phase 3 pass list ever lists `hero shots` as
  # a gate (lowercase, no leading number), the orchestrator would try to
  # dispatch a sub-agent for a non-existent gate section.
  grep -qE '^### 3\.1b: Hero-screenshot capture' "$BUILD_SKILL"
  # Hero capture is NOT a per-gate sub-agent dispatch.
  awk '/^### 3\.1b:/,/^### 3\.1c:/' "$BUILD_SKILL" \
    | grep -qE 'NOT a gate'
}

@test "Focused-fix sub-agent has a concrete prompt template (3.1c)" {
  # The agent-review's medium finding #6 was that 'orchestrator dispatches a
  # focused fix sub-agent' had no prompt template. § 3.1c adds it.
  grep -qE '^### 3\.1c: Focused-fix sub-agent' "$BUILD_SKILL"
  awk '/^### 3\.1c:/,/^### 3\.2:/' "$BUILD_SKILL" \
    | grep -qE 'Agent \{'
  awk '/^### 3\.1c:/,/^### 3\.2:/' "$BUILD_SKILL" \
    | grep -qE 'prompt:'
}

@test "Mechanical/obvious vs escalate heuristic is concretely specified" {
  # The agent-review's medium finding #5 was that the routing said
  # 'mechanical → fix; everything else → escalate' but never drew the line.
  # The added heuristic names four concrete criteria.
  tr '\n' ' ' < "$BUILD_SKILL" | tr -s '[:space:]' ' ' \
    | grep -qE 'What counts as .mechanical/obvious.'
  grep -qE 'Single-file diff' "$BUILD_SKILL"
  grep -qE 'When in doubt, escalate' "$BUILD_SKILL"
}

@test "Sub-agent prompt mandates `## Gate <#>: <name>` heading shape (parse contract)" {
  # The agent-review's medium finding #3 was that sub-agents told to follow
  # pre-ship's gate sections may mimic pre-ship's heading style (e.g.
  # `## Gate fast-job-local (ak): ...`) instead of `## Gate 2d: fast-job-local`,
  # breaking the FORBIDDEN_NA awk parse contract.
  tr '\n' ' ' < "$BUILD_SKILL" | tr -s '[:space:]' ' ' \
    | grep -qE 'heading MUST use the shape .## Gate <#>: <name>.'
}

@test "Phase 3.3 concatenation order is concretely enumerated (not hand-wave)" {
  # The agent-review's medium finding #4 was that 'canonical-gate order' was
  # hand-wave with no script + no listing. The fix adds the explicit list.
  awk '/^### 3\.3:/,/^### Phase 3 → Phase 4/' "$BUILD_SKILL" \
    | grep -qE '^1 docs-check'
  awk '/^### 3\.3:/,/^### Phase 3 → Phase 4/' "$BUILD_SKILL" \
    | grep -qE '^11 convention'
}

@test "implement/SKILL.md has a `### Stuck protocol` heading (cross-ref target)" {
  # /ak-pre-ship § Stuck protocol cross-refs '/ak-implement § Step 3 §
  # Stuck protocol'. For grep-anchor resolution, that section must exist
  # as a heading, not as bold prose.
  IMPL_SKILL="$TESTS_DIR/../../.claude/skills/devshop/implement/SKILL.md"
  grep -qE '^### Stuck protocol' "$IMPL_SKILL"
}
