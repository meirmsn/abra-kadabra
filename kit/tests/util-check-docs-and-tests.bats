#!/usr/bin/env bats
# Tests for .claude/skills/devshop/check-docs-and-tests/SKILL.md — the audit-time
# orchestrator prompt. These are content-validation tests: the skill is a pure
# LLM prompt (no shell-script implementation), so we grep its required sections,
# frontmatter values, and parser one-liners. Behavior tests (running the LLM)
# are out of scope; this proves the prompt has the required shape.

setup() {
  load helpers/setup
  # Derive from TESTS_DIR (set by helpers/setup) so the tests pass from any
  # checkout — main worktree OR a linked worktree under .worktrees/<topic>.
  # Hardcoding `/devshop/...` made these tests silently bypass worktree edits.
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/check-docs-and-tests/SKILL.md"
  # Do NOT defensively skip when SKILL.md is missing — a rename/move/delete is
  # precisely the regression this file exists to catch. Let per-test assertions
  # fail naturally so the report says "SKILL.md exists at the expected path"
  # FAILED rather than "all tests skipped". Audit 1 finding (2026-05-07).
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

@test "frontmatter declares Agent in allowed-tools (parallel sub-skill dispatch)" {
  # Step 3 dispatches /ak-docs-review + /ak-tests-review as two parallel Agent
  # calls. Without `- Agent` in allowed-tools, the orchestrator can't fire them.
  grep -qE '^[[:space:]]*-[[:space:]]+Agent[[:space:]]*$' "$SKILL_FILE"
}

# === Sub-skill invocation ===

@test "behavior section names /ak-docs-review (sub-skill 1)" {
  grep -q '/ak-docs-review' "$SKILL_FILE"
}

@test "behavior section names /ak-tests-review (sub-skill 2)" {
  grep -q '/ak-tests-review' "$SKILL_FILE"
}

@test "sub-skill invocation is documented as parallel (Agent dispatch in one tool-use turn)" {
  # The two sub-skills are pure read-only analysis against the same SHA — no
  # ordering dependency. Step 3 dispatches them as two parallel Agent calls
  # in a single tool-use turn. The "sequential, not parallel" wording (pre-
  # ak-build-phase-decomposition) is gone; the canonical phrasing now names
  # parallelism explicitly.
  grep -qiE 'in parallel|parallel Agent|two parallel' "$SKILL_FILE"
  ! grep -q 'Sequential, not parallel' "$SKILL_FILE"
}

@test "Step 3 documents per-file sinks under gates/audit-N-{docs,tests}.md" {
  # The parallel-write race is resolved by per-file sinks: each Agent writes
  # to its own path under specs/<feature>/gates/. The orchestrator then
  # concatenates in Step 4. This is the parse contract.
  grep -qE 'audit-\$AUDIT_N-docs\.md' "$SKILL_FILE"
  grep -qE 'audit-\$AUDIT_N-tests\.md' "$SKILL_FILE"
  grep -qE 'gates/' "$SKILL_FILE"
}

@test "Step 3 instructs sub-agents to write their findings VERBATIM" {
  # The orchestrator never reads or writes finding bodies — it copies the
  # sub-skill's structured output through unchanged into the sink. Without
  # VERBATIM, an agent could re-summarize and break the parse contract.
  grep -q 'VERBATIM' "$SKILL_FILE"
}

@test "Step 4 concatenates from the per-file sinks (not from tempfiles)" {
  # Old behavior wrote to /tmp/{docs,tests}-review-findings.md; the new
  # contract reads from specs/<feature>/gates/audit-N-{docs,tests}.md.
  grep -qE '^### Step 4: Concatenate sinks' "$SKILL_FILE"
  ! grep -q '/tmp/docs-review-findings\.md' "$SKILL_FILE"
  ! grep -q '/tmp/tests-review-findings\.md' "$SKILL_FILE"
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

# === Step 5: commit appended section (audit-trail persistence) ===

@test "Step 5 commits the appended review.md section + the per-domain sinks" {
  grep -qE '^### Step 5: Commit the appended section \+ sinks' "$SKILL_FILE"
}

@test "Step 5 refuses on dirty tree containing paths other than review.md" {
  grep -qiE 'dirty.tree refusal' "$SKILL_FILE"
  grep -qE 'git status --porcelain' "$SKILL_FILE"
  grep -qE 'UNCOMMITTED:' "$SKILL_FILE"
}

@test "Step 5 never stashes / restores (would destroy operator work)" {
  grep -qE 'never .git stash' "$SKILL_FILE"
  grep -qE 'git restore' "$SKILL_FILE"
}

@test "Step 5 stages the audit file + per-domain sinks (no add -A / add .)" {
  # The commit's scope is exactly three paths: review.md plus the two
  # audit-N-{docs,tests}.md sinks from Step 3's Agent dispatch. The
  # SKILL.md typically wraps the `git add ...` command across multiple
  # markdown lines, so we collapse whitespace before grepping.
  tr '\n' ' ' < "$SKILL_FILE" | tr -s '[:space:]' ' ' \
    | grep -qE 'git add "\$FEATURE_DIR/review.md" "\$FEATURE_DIR/gates/audit-\$AUDIT_N-docs.md" "\$FEATURE_DIR/gates/audit-\$AUDIT_N-tests.md"'
  grep -qE 'never .git add -A' "$SKILL_FILE"
}

@test "Step 5 dirty-tree refusal permits the per-domain sinks alongside review.md" {
  # The dirty-tree refusal now whitelists the two audit-N-{docs,tests}.md
  # sinks. Before this fix, the per-domain sinks would have been flagged as
  # foreign paths and the audit commit would have been skipped.
  grep -qE 'audit-\$AUDIT_N-\{docs,tests\}\.md' "$SKILL_FILE"
}

@test "Step 5 commit subject shape documented (feature + Audit N + findings counts)" {
  grep -qE 'docs\(<feature>\): Audit N.*findings: high=H medium=M low=L' "$SKILL_FILE"
}

@test "Step 5 commit body carries Range + Stamp metadata" {
  grep -qE '^   Range: <RANGE>' "$SKILL_FILE"
  grep -qE '^   Stamp: <HEAD_SHA>' "$SKILL_FILE"
}

@test "Step 5 does NOT use --no-verify (commits under the gauntlet)" {
  # 'Do not\n pass `--no-verify`' wraps across two lines, so use tr+grep.
  tr '\n' ' ' < "$SKILL_FILE" | grep -qE 'Do not[[:space:]]+pass[[:space:]]+.--no-verify'
}

@test "Step 6 is the halt-or-continue step (renumbered from old Step 5)" {
  grep -qE '^### Step 6: Halt-or-continue' "$SKILL_FILE"
}

@test "Step 7 is idempotence (renumbered from old Step 6)" {
  grep -qE '^### Step 7: Idempotence' "$SKILL_FILE"
}

@test "Behavior summary mentions orchestrator commits the audit section" {
  grep -qiE 'orchestrator DOES commit' "$SKILL_FILE"
}
