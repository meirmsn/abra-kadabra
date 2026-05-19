#!/usr/bin/env bats
# Tests for .claude/skills/devshop/build/SKILL.md — Phase 5.8 + Phase 6 wiring
# of /ak-check-docs-and-tests after PR-B (audit-time docs+tests review
# migration). The skill is a pure LLM prompt (no shell-script implementation),
# so these are content-validation tests: grep its required sections, parser
# one-liners, and cross-references to confirm the prose reflects the
# post-PR-B contract.
#
# What's covered:
# - Step 0 resume rung 1a reads the latest `## Audit N` section's audited-at
#   from `review.md` (collapsed two-file model — no `test-review-followup.md`).
# - Phase 5.8 invokes `/ak-check-docs-and-tests` (orchestrator), not
#   `/ak-tests-review` directly.
# - Phase 5.8.5 idempotence reads the latest `## Audit N` section.
# - Phase 5.8 parser uses `tail -1` (latest stamp wins — sections append).
# - Phase 6 audit comment reads `review.md` only — no
#   `test-review-followup.md` references survive.
#
# Behavior tests (running the LLM) are out of scope; this proves the prompt
# reflects the parse contract documented in
# `.claude/skills/devshop/check-docs-and-tests/SKILL.md § Audit section
# format spec` and the migration plan in
# `kit/ROADMAP.md § PR-B`.

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/build/SKILL.md"
  # Do NOT defensively skip when SKILL.md is missing — a rename/move/delete is
  # precisely the regression this file exists to catch. Let per-test assertions
  # fail naturally so the report says "SKILL.md exists at the expected path"
  # FAILED rather than "all tests skipped". Audit 1 finding (2026-05-07).
}

# === Architecture diagram (top-of-file) ===

@test "architecture diagram references /ak-check-docs-and-tests for Phase 5.8" {
  # The ASCII pipeline diagram should call out the orchestrator, not
  # /ak-tests-review directly.
  grep -q '/ak-check-docs-and-tests' "$SKILL_FILE"
}

@test "architecture diagram references appending Audit 2 section to review.md" {
  # The diagram should explain the collapsed two-file model — no
  # test-review-followup.md.
  grep -qE 'Audit 2.*review\.md|review\.md.*Audit 2' "$SKILL_FILE"
}

@test "architecture diagram does not reference test-review-followup.md" {
  # Post-PR-B: the diagram must not produce or describe test-review-followup.md.
  ! grep -q 'test-review-followup\.md' "$SKILL_FILE"
}

# === Step 0 resume rung 1a ===

@test "resume rung 1a reads latest ## Audit N section's audited-at, not test-review-followup.md" {
  # Look for the rung 1a marker plus the ## Audit N parser language nearby.
  grep -qE '\*\*1a\.\*\*' "$SKILL_FILE"
  # The rung must mention `## Audit N` as the source of the SHA.
  awk '/\*\*1a\.\*\*/,/\*\*1b\.\*\*/' "$SKILL_FILE" | grep -q '## Audit N'
}

@test "resume rung 1a parser uses tail -1 (latest audit wins, sections append)" {
  # The append-and-grep model has the latest stamp at the bottom of the file
  # — `tail -1` is the right operator (vs `head -1` for a single-frontmatter
  # model).
  awk '/\*\*1a\.\*\*/,/\*\*1b\.\*\*/' "$SKILL_FILE" | grep -q 'tail -1'
}

# === Phase 5.8: orchestrator invocation ===

@test "Phase 5.8 spawn block invokes /ak-check-docs-and-tests, not /ak-tests-review directly" {
  # Slice from the spawn-subagent header (5.8.3) to the next subsection.
  awk '/### 5\.8\.3/,/### 5\.8\.4/' "$SKILL_FILE" | grep -q '/ak-check-docs-and-tests'
}

@test "Phase 5.8 spawn block passes --feature-dir and --label post-polish to the orchestrator" {
  # The orchestrator's input contract: `--feature-dir` + `--label`.
  awk '/### 5\.8\.3/,/### 5\.8\.4/' "$SKILL_FILE" | grep -q -- '--feature-dir'
  awk '/### 5\.8\.3/,/### 5\.8\.4/' "$SKILL_FILE" | grep -q -- '--label post-polish'
}

@test "Phase 5.8 range computation uses the audit-N parser one-liner (tail -1)" {
  # 5.8.2's pre-flight skip check mirrors the orchestrator's parser.
  # Both tokens must appear in the same code block; the multi-line
  # bash continuation is fine — just confirm both are inside 5.8.2.
  local section
  section=$(awk '/### 5\.8\.2/,/### 5\.8\.3/' "$SKILL_FILE")
  echo "$section" | grep -q 'audited-at'
  echo "$section" | grep -q 'tail -1'
}

@test "Phase 5.8 documents the latest-stamp rationale (sections append over time)" {
  # The why behind tail -1 should be explicit so a future editor doesn't
  # "fix" it back to head -1.
  awk '/### 5\.8\.2/,/### 5\.8\.3/' "$SKILL_FILE" \
    | grep -qE 'append over time|sections append|latest stamp'
}

# === Phase 5.8.5 idempotence ===

@test "Phase 5.8.5 idempotence reads latest ## Audit N section's audited-at" {
  awk '/### 5\.8\.5/,/## Phase 5\.9/' "$SKILL_FILE" | grep -qE 'audited-at.*tail -1|## Audit N'
}

@test "Phase 5.8.5 idempotence does not reference test-review-followup.md" {
  ! awk '/### 5\.8\.5/,/## Phase 5\.9/' "$SKILL_FILE" | grep -q 'test-review-followup'
}

# === Phase 6: audit comment generation ===

@test "Phase 6 audit comment reads from review.md § Audit N (collapsed two-file model)" {
  awk '/## Phase 6/,/### Phase 6 checkbox/' "$SKILL_FILE" \
    | grep -qE 'review\.md.*Audit (N|2)|Audit (N|2).*review\.md'
}

@test "Phase 6 audit comment does not reference test-review-followup.md" {
  ! awk '/## Phase 6/,/### Phase 6 checkbox/' "$SKILL_FILE" \
    | grep -q 'test-review-followup'
}

@test "Phase 6 quality-gates table references /ak-check-docs-and-tests (Audit 1, pre-polish)" {
  # Audit 1 row — replaces the prior `/ak-tests-review` row.
  grep -q '/ak-check-docs-and-tests (Audit 1, pre-polish)' "$SKILL_FILE"
}

@test "Phase 6 quality-gates table references /ak-check-docs-and-tests (Audit 2, post-polish)" {
  # Audit 2 row — replaces the prior `Post-pre-ship test-coverage` row.
  grep -q '/ak-check-docs-and-tests (Audit 2, post-polish)' "$SKILL_FILE"
}

# === File-wide invariants ===

@test "build/SKILL.md does not produce or reference test-review-followup.md" {
  # Final sweep: nothing in the skill prose should cause a test-review-followup.md
  # to be written or read after PR-B.
  ! grep -q 'test-review-followup\.md' "$SKILL_FILE"
}

@test "build/SKILL.md's version is at the PR-B floor (1.7+) or above" {
  # PR-B was a meaningful behavior change (Phase 5.8 invocation surface +
  # Phase 6 audit-comment reader); a version bump documents that. Subsequent
  # major-shape changes (e.g. ak-build-phase-decomposition's Phase 5.4 fresh-
  # agent fix-loop) bump to 2.x — both shapes satisfy "at the floor or above".
  grep -qE '^version: (1\.[7-9]|[2-9])\.' "$SKILL_FILE"
}
