#!/usr/bin/env bats
# Tests for .claude/skills/devshop/check-docs-and-tests/SKILL.md — the audit-time
# orchestrator prompt. These are content-validation tests: the skill is a pure
# LLM prompt (no shell-script implementation), so we grep its required sections,
# frontmatter values, and parser one-liners. Behavior tests (running the LLM)
# are out of scope; this proves the prompt has the required shape.

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/check-docs-and-tests/SKILL.md"
  [ -f "$SKILL_FILE" ] || skip "SKILL.md not found at $SKILL_FILE"
}

# === File presence + frontmatter ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "frontmatter declares name: ak-check-docs-and-tests" {
  grep -q '^name: ak-check-docs-and-tests$' "$SKILL_FILE"
}

@test "frontmatter declares Skill in allowed-tools (orchestrator invokes sub-skills)" {
  # Inside the YAML frontmatter, allowed-tools list must include `- Skill`.
  grep -qE '^[[:space:]]*-[[:space:]]+Skill[[:space:]]*$' "$SKILL_FILE"
}

# === Sub-skill invocation ===

@test "behavior section names /ak-docs-review (sub-skill 1)" {
  grep -q '/ak-docs-review' "$SKILL_FILE"
}

@test "behavior section names /ak-tests-review (sub-skill 2)" {
  grep -q '/ak-tests-review' "$SKILL_FILE"
}

@test "sub-skill invocation is documented as sequential, not parallel" {
  grep -qiE 'sequential|sequentially' "$SKILL_FILE"
  grep -qi 'not parallel' "$SKILL_FILE"
}

# === Parser one-liners (the parse contract) ===

@test "parser one-liner for audited-at SHA harvest is documented" {
  # The latest-SHA harvest greps for the HTML-comment marker and tail -1's it.
  grep -q '<!-- audited-at:' "$SKILL_FILE"
  grep -q 'tail -1' "$SKILL_FILE"
}

@test "Audit N numbering pattern is documented" {
  # `grep -cP '^## Audit \d+'` is the canonical counter one-liner.
  grep -q "grep -cP '\^## Audit" "$SKILL_FILE"
}

@test "audit section format documents <!-- audited-at: --> marker as parse contract" {
  grep -q '<!-- audited-at: <HEAD_SHA> -->' "$SKILL_FILE"
}

@test "audit section format documents <!-- range: --> marker" {
  grep -q '<!-- range:' "$SKILL_FILE"
}

@test "audit section format documents findings count line (high/medium/low)" {
  grep -qE 'findings: high=.*medium=.*low=' "$SKILL_FILE"
}

# === Decision rules ===

@test "idempotence rule documented: latest audited-at SHA == HEAD → no-op" {
  grep -qiE 'idempoten' "$SKILL_FILE"
  grep -qi 'no-op' "$SKILL_FILE"
  grep -qi 'already audited' "$SKILL_FILE"
}

@test "branch=main rejection rule documented" {
  grep -qE 'current branch is `?main`?' "$SKILL_FILE"
  grep -qi 'feature branch' "$SKILL_FILE"
}

@test "rebase fallback documented: missing audited-at SHA → origin/main..HEAD with note" {
  grep -qi 'rebase' "$SKILL_FILE"
  grep -q 'origin/main\.\.HEAD' "$SKILL_FILE"
  grep -q '<!-- rebased:' "$SKILL_FILE"
}

@test "halt-on-high rule: high-severity findings → exit non-zero" {
  grep -qi 'high-severity' "$SKILL_FILE"
  grep -qi 'exit non-zero' "$SKILL_FILE"
}

@test "0/0/0 clean case is documented" {
  grep -qE '0/0/0|clean.*no findings' "$SKILL_FILE"
}
