#!/usr/bin/env bats
# Tests for .claude/skills/devshop/tests-review/SKILL.md — the audit-time tests
# sub-skill prompt. **Highest-priority** in the PR-A test plan: this file
# enforces that all 11 sub-sections from the prior /ak-test-review SKILL.md
# survived the rebuild into /ak-tests-review (note the rename — singular →
# PLURAL is load-bearing). One @test per sub-section so a failure message
# names exactly which sub-section regressed.
#
# Recovery: if you need the original /ak-test-review content as reference,
# it lived at .claude/skills/devshop/test-review/SKILL.md before the rebuild.
# Find the SHA with:
#   git log --all --oneline -- .claude/skills/devshop/test-review/SKILL.md
# Then read the body with:
#   git show <SHA>:.claude/skills/devshop/test-review/SKILL.md

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/tests-review/SKILL.md"
  [ -f "$SKILL_FILE" ] || skip "SKILL.md not found at $SKILL_FILE"
}

# === File presence + frontmatter (rename is load-bearing) ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "frontmatter declares name: ak-tests-review (PLURAL — rename is load-bearing)" {
  grep -q '^name: ak-tests-review$' "$SKILL_FILE"
  # Defensive: explicitly assert the singular form is NOT the name.
  ! grep -q '^name: ak-test-review$' "$SKILL_FILE"
}

# === Three top-level sections ===

@test "Section A — Coverage of new behavior header present" {
  # Tolerant of em-dash (multi-byte UTF-8) or hyphen between "Section X" and title.
  grep -qE '^## Section A .* Coverage of new behavior' "$SKILL_FILE"
}

@test "Section B — Test quality header present" {
  grep -qE '^## Section B .* Test quality' "$SKILL_FILE"
}

@test "Section C — Bypass trailer audit header present" {
  grep -qE '^## Section C .* Bypass trailer audit' "$SKILL_FILE"
}

# === Section B preserves all 11 quality sub-sections (CRITICAL) ===

@test "Section B preserves: Weak assertions" {
  grep -qE '^### Weak assertions' "$SKILL_FILE"
}

@test "Section B preserves: Missing error/invalid input tests" {
  grep -qE '^### Missing error.*invalid input tests' "$SKILL_FILE"
}

@test "Section B preserves: Untested auth boundaries (RLS)" {
  grep -qE '^### Untested auth boundaries' "$SKILL_FILE"
  grep -q 'RLS' "$SKILL_FILE"
}

@test "Section B preserves: Implementation detail tests" {
  grep -qE '^### Implementation detail tests' "$SKILL_FILE"
}

@test "Section B preserves: Missing boundary conditions" {
  grep -qE '^### Missing boundary conditions' "$SKILL_FILE"
}

@test "Section B preserves: Shape-only assertions (must pair with user-visible output)" {
  grep -qE '^### Shape-only assertions' "$SKILL_FILE"
  grep -qi 'user-visible' "$SKILL_FILE"
}

@test "Section B preserves: WebKit form-state hydration race" {
  grep -qE '^### WebKit form-state hydration race' "$SKILL_FILE"
}

@test "Section B preserves: Realtime test missing publication migration" {
  grep -qE '^### Realtime test missing publication migration' "$SKILL_FILE"
}

@test "Section B preserves: Wrapper API design — lifecycle events not just data" {
  grep -qE '^### Wrapper API design' "$SKILL_FILE"
  grep -qi 'lifecycle events' "$SKILL_FILE"
}

@test "Section B preserves: Runtime validation at LLM / edge-function boundaries" {
  grep -qE '^### Runtime validation at LLM' "$SKILL_FILE"
  grep -qi 'edge-function bound' "$SKILL_FILE"
}

@test "Section B preserves: Skipped tests audit" {
  grep -qE '^### Skipped tests audit' "$SKILL_FILE"
}

# === Quick-scan command code blocks for surveys ===

@test "Quick scan command for wrapper API survey is preserved (git diff --diff-filter=AM)" {
  # The wrapper API quick-scan greps for .subscribe / .on / .addEventListener.
  grep -q 'git diff --diff-filter=AM' "$SKILL_FILE"
  grep -qE '\\.\(subscribe\|on\|addEventListener\)' "$SKILL_FILE"
}

@test "Quick scan command for runtime validation survey is preserved" {
  # Runtime-validation quick-scan greps for .functions.invoke< or .json() as.
  grep -q 'git diff --diff-filter=AM' "$SKILL_FILE"
  grep -qE '\\.functions\\.invoke<|\\.json\\(\\) as' "$SKILL_FILE"
}

# === Bypass trailer audit ===

@test "Tests-Coverage-Bypass trailer harvest one-liner present" {
  grep -q 'Tests-Coverage-Bypass:' "$SKILL_FILE"
  grep -q "git log --format='%H%n%B%n---'" "$SKILL_FILE"
}

# === Output format + severity rules ===

@test "output format includes [domain: tests] tag" {
  grep -q '\[domain: tests\]' "$SKILL_FILE"
}

@test "severity rules: high → halt audit, medium → surface, low → noted" {
  grep -qiE 'high.*halt' "$SKILL_FILE"
  grep -qE '`?medium`?' "$SKILL_FILE"
  grep -qE '`?low`?' "$SKILL_FILE"
}

# === Pre-existing escape-hatch / bypass language survives ===

@test "shape-only escape hatch language survives (pure reducer / no render path)" {
  grep -qi 'pure reducer' "$SKILL_FILE"
  grep -qi 'no render path' "$SKILL_FILE"
}

@test "wrapper API fire-and-forget bypass language survives" {
  grep -qi 'fire-and-forget' "$SKILL_FILE"
}

@test "runtime validation PostgREST bypass language survives" {
  grep -qi 'PostgREST' "$SKILL_FILE"
}
