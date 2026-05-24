#!/usr/bin/env bats
# Smoke test for the /ak-tests-review SKILL.md prompt content.
# Verifies the Test Assertion Depth rule (shape-vs-text) text is present so
# silent edits to the SKILL.md can't accidentally drop the rule.
# LLM-behavior testing requires real Sonnet calls and is intentionally out of
# scope here — see kit/docs/guide/conventions.md § Test Assertion Depth for
# the canonical rule statement that this smoke test guards.
#
# Renamed from /ak-test-review (singular) to /ak-tests-review (plural) in PR-A
# of the audit-time migration (see kit/ROADMAP.md § Move adversarial Layer 2
# reviews from per-commit to audit-time). The Shape-only sub-section is now
# under "## Section B — Test quality" but the heading text and rule body are
# preserved verbatim.

setup() {
  load helpers/setup
  SKILL_MD="/devshop/.claude/skills/devshop/tests-review/SKILL.md"
  CONVENTIONS_MD="/devshop/kit/docs/guide/conventions.md"
}

@test "skill: SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "skill: rule heading present" {
  grep -qE '^### Shape-only assertions' "$SKILL_MD"
}

@test "skill: shape→text rule names the catalysts (state shape, length, mock-call count)" {
  grep -qE 'state shape.*array length.*mock-call count' "$SKILL_MD"
}

@test "skill: rule names the user-visible-output assertions" {
  grep -q 'getByText' "$SKILL_MD"
  grep -q 'getByRole' "$SKILL_MD"
}

@test "skill: escape-hatch comment marker documented" {
  grep -qE '// shape-only:' "$SKILL_MD"
}

@test "skill: bypass-rejection guidance present (rejects boilerplate)" {
  grep -q 'REJECT' "$SKILL_MD"
}

@test "skill: Test Assertion Depth rules inlined in Section B" {
  grep -q 'Weak assertions' "$SKILL_MD"
  grep -q 'Shape-only assertions' "$SKILL_MD"
}

@test "conventions: § Test Assertion Depth section exists" {
  grep -qE '^### Test Assertion Depth' "$CONVENTIONS_MD"
}

@test "conventions: escape-hatch comment marker documented" {
  grep -qE '// shape-only:' "$CONVENTIONS_MD"
}
