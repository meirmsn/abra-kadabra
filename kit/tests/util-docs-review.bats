#!/usr/bin/env bats
# Tests for .claude/skills/devshop/docs-review/SKILL.md — the audit-time docs
# sub-skill prompt. Content-validation: greps SKILL.md for required sections,
# repo-branching language (devshop self-mode vs project mode), bypass-trailer
# harvest one-liner, severity rules, and output format tags.

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/docs-review/SKILL.md"
  [ -f "$SKILL_FILE" ] || skip "SKILL.md not found at $SKILL_FILE"
}

# === File presence + frontmatter ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "frontmatter declares name: ak-docs-review" {
  grep -q '^name: ak-docs-review$' "$SKILL_FILE"
}

# === Section headers (all four present, in order) ===

@test "Section A — Coverage header present" {
  # Match em-dash (—) or hyphen between "Section A" and "Coverage" — be tolerant
  # of formatting (em-dash byte sequence is multi-byte, so use a permissive .*).
  grep -qE '^## Section A .* Coverage' "$SKILL_FILE"
}

@test "Section B — Adequacy header present" {
  grep -qE '^## Section B .* Adequacy' "$SKILL_FILE"
}

@test "Section C — Cross-doc coherence header present" {
  grep -qE '^## Section C .* Cross-doc coherence' "$SKILL_FILE"
}

@test "Section D — Bypass trailer audit header present" {
  grep -qE '^## Section D .* Bypass trailer audit' "$SKILL_FILE"
}

@test "the four sections appear in order A, B, C, D" {
  # Use awk to record line numbers of each section header.
  local lines
  lines=$(grep -nE '^## Section [ABCD]' "$SKILL_FILE" | awk -F: '{print $1}')
  local a b c d
  a=$(echo "$lines" | sed -n '1p')
  b=$(echo "$lines" | sed -n '2p')
  c=$(echo "$lines" | sed -n '3p')
  d=$(echo "$lines" | sed -n '4p')
  [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] && [ "$c" -lt "$d" ]
}

# === Repo branching: devshop self-mode vs project mode ===

@test "repo branching documented via \$GIT_ROOT" {
  grep -q '\$GIT_ROOT' "$SKILL_FILE"
}

@test "devshop self-mode section names /devshop and CLAUDE.md + kit/docs/OVERVIEW.md + kit/docs/guide/" {
  grep -qi 'devshop self-mode' "$SKILL_FILE"
  grep -q '/devshop' "$SKILL_FILE"
  grep -q 'CLAUDE.md' "$SKILL_FILE"
  grep -q 'kit/docs/OVERVIEW.md' "$SKILL_FILE"
  grep -q 'kit/docs/guide/' "$SKILL_FILE"
}

@test "project mode section names CLAUDE.md, METRICS.md, OVERVIEW.md, ARCHITECTURE.md" {
  grep -qi 'project mode' "$SKILL_FILE"
  grep -q 'CLAUDE.md' "$SKILL_FILE"
  grep -q 'METRICS.md' "$SKILL_FILE"
  grep -q 'OVERVIEW.md' "$SKILL_FILE"
  grep -q 'ARCHITECTURE.md' "$SKILL_FILE"
}

@test "project mode references per-package READMEs" {
  grep -qE 'apps/\*?/README\.md|packages/\*?/README\.md' "$SKILL_FILE"
  grep -q 'supabase/functions/README.md' "$SKILL_FILE"
}

# === Bypass trailer harvest one-liner ===

@test "Docs-Coverage-Bypass trailer harvest one-liner is documented" {
  grep -q 'Docs-Coverage-Bypass:' "$SKILL_FILE"
  grep -q "git log --format='%H%n%B%n---'" "$SKILL_FILE"
}

# === Severity rules ===

@test "severity rules: high → halt audit" {
  grep -qiE '\*\*high\*\*.*halt|high.*→.*halt' "$SKILL_FILE"
}

@test "severity rules: medium and low documented" {
  grep -qE '\*\*medium\*\*' "$SKILL_FILE"
  grep -qE '\*\*low\*\*' "$SKILL_FILE"
}

# === Output format ===

@test "output format includes [domain: docs] tag" {
  grep -q '\[domain: docs\]' "$SKILL_FILE"
}

@test "output format includes [section: A|B|C|D] tag" {
  grep -qE '\[section: A\|B\|C\|D\]' "$SKILL_FILE"
}

@test "output format includes [severity: high|medium|low] tag" {
  grep -qE '\[severity: high\|medium\|low\]' "$SKILL_FILE"
}

@test "0/0/0 clean-case sentence preserved" {
  grep -qi 'Clean.*no docs findings' "$SKILL_FILE"
}
