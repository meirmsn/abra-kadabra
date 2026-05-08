#!/usr/bin/env bats
# Tests for .claude/skills/ak-merge-devshop/SKILL.md — the devshop merge skill
# (audit + squash-merge + push + cleanup).
#
# The skill is a pure LLM prompt (Markdown), so these are content-validation
# tests: grep its required sections, parser one-liners, and bash logic blocks
# to confirm the prose reflects the contract documented in `/devshop/CLAUDE.md
# § Devshop shipping flow`, `kit/docs/guide/architecture.md § Doing devshop
# work`, and `kit/docs/guide/workflow.md § Devshop Skill Map`.
#
# What's covered:
# - SKILL.md exists at the expected path (rename/move/delete catch).
# - Frontmatter description names the actual format the skill produces
#   (bullet-led summary + compressed per-commit bullet list, NOT verbatim).
# - Phase 0.1 hard preconditions present (on-main refusal, dirty-tree refusal,
#   ff-mergeability check).
# - Phase 0.2 FEATURE regex handles all six known type prefixes (feat, feature,
#   fix, docs, chore, refactor) and uses `#` as the sed delimiter (NOT `|`,
#   which would conflict with the alternation group — the bug the smoke test
#   surfaced and codified by Audit 1, 2026-05-07).
# - Phase 0.2 has the empty-FEATURE guard (fails loudly when branch has no
#   recognized prefix).
# - Phase 0.3 format spec describes bullet-led summary + compressed per-commit
#   bullets + SHA recoverability via `git reflog`.
# - Phase 0.5 AskUserQuestion gate offers approve/edit/cancel.
# - Phase 1 invokes /ak-check-docs-and-tests (NOT /ak-tests-review directly).
# - Phase 2 uses `git merge --squash` (NOT --ff-only).
# - Phase 2.1 has the post-squash tree-equality defense.
# - Phase 3 has workflow-scope detection (parallels /ak-build Phase 5.4).
# - Phase 4 force-deletes (`git branch -D`) and cleans up the remote
#   (`git push origin --delete`).
# - The verbatim-history framing is explicitly retired (only mentioned in the
#   explanatory § "Why compressed bullets, not verbatim bodies" section, which
#   contrasts the new shape against the old).
#
# Behavior tests (running the LLM end-to-end) are out of scope; this proves
# the prompt reflects the contract documented in CLAUDE.md and the smoke-test
# findings codified during Audit 1.

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/ak-merge-devshop/SKILL.md"
  # Do NOT defensively skip when SKILL.md is missing — a rename/move/delete is
  # precisely the regression this file exists to catch (peer pattern from
  # util-build-phase58-audit-parser.bats).
}

# === SKILL.md exists ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

# === Frontmatter ===

@test "frontmatter name is ak-merge-devshop (drives slash-command autocomplete)" {
  grep -qE '^name: ak-merge-devshop$' "$SKILL_FILE"
}

@test "frontmatter description names bullet-led summary (not 'prose summary')" {
  # The phrase "bullet-led" may wrap across lines in the YAML literal block —
  # grep with -z to ignore newlines, or just check for "bullet-led" alone.
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'bullet-led'
  ! awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'prose summary'
}

@test "frontmatter description names compressed per-commit bullet list (not 'verbatim per-commit history')" {
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'compressed per-commit bullet list'
  ! awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'verbatim per-commit history'
}

@test "frontmatter description names git reflog as the SHA recovery path" {
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'git reflog'
}

# === Phase 0.1: hard preconditions ===

@test "Phase 0.1 refuses on main / master" {
  awk '/### 0\.1:/,/### 0\.2:/' "$SKILL_FILE" | grep -qE 'BRANCH.*=.*main.*master|main.*master.*BRANCH'
}

@test "Phase 0.1 refuses on dirty working tree" {
  awk '/### 0\.1:/,/### 0\.2:/' "$SKILL_FILE" | grep -q 'git status --porcelain'
}

@test "Phase 0.1 verifies ff-mergeability via merge-base --is-ancestor" {
  awk '/### 0\.1:/,/### 0\.2:/' "$SKILL_FILE" | grep -q 'merge-base --is-ancestor origin/main HEAD'
}

# === Phase 0.2: FEATURE regex (the bug-surface) ===

@test "Phase 0.2 FEATURE regex handles all six known type prefixes" {
  # Single grep that requires every prefix to appear in the alternation.
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE 'feat\|feature\|fix\|docs\|chore\|refactor'
}

@test "Phase 0.2 sed uses # delimiter (not |) to avoid alternation conflict" {
  # The bug Audit 1 codified: sed -E 's|^(feat|feature|...)/||' parses the
  # inner | as the delimiter. The fix uses # instead.
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE "sed -E 's#\^.*\)/##'"
  # And does NOT contain the buggy form anywhere in 0.2.
  ! awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE "sed -E 's\|\^.*\)/\|\|'"
}

@test "Phase 0.2 has empty-FEATURE guard (fails loudly on unrecognized prefix)" {
  # The guard added during the smoke-test fix. Looks for the conditional that
  # exits 1 when FEATURE is empty or unchanged from BRANCH.
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE '\[ -z "\$FEATURE" \].*\[ "\$FEATURE" = "\$BRANCH" \]'
}

# === Phase 0.3: format spec ===

@test "Phase 0.3 format spec describes bullet-led summary sections" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q 'bullet-led'
}

@test "Phase 0.3 format spec mentions ## Squashed commits section header" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q '## Squashed commits'
}

@test "Phase 0.3 format spec mentions git reflog for SHA recovery" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q 'git reflog'
}

@test "Phase 0.3 explanatory section explicitly retires verbatim format" {
  # The "Why compressed bullets" subsection should exist and contrast against
  # verbatim. Its presence is what allows the word "verbatim" to appear in
  # SKILL.md without contradicting the spec.
  grep -qE '#### Why compressed bullets, not verbatim bodies' "$SKILL_FILE"
}

# === Phase 0.5: approval gate ===

@test "Phase 0.5 uses AskUserQuestion with approve/edit/cancel options" {
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -q 'AskUserQuestion'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Approve\*\*'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Edit\*\*'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Cancel\*\*'
}

# === Phase 1: audit ===

@test "Phase 1 invokes /ak-check-docs-and-tests (orchestrator, not /ak-tests-review directly)" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" | grep -qE 'ak-check-docs-and-tests'
}

@test "Phase 1 halts on high-severity findings" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" | grep -qE '[Hh]igh-severity.*halt|halt.*high'
}

# === Phase 2: squash-merge ===

@test "Phase 2 uses git merge --squash (NOT --ff-only)" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" | grep -qE 'git merge --squash'
  # The skill should NOT instruct ff-only on the feature branch. (It DOES use
  # --ff-only on origin/main lag-catch, which is fine — that's a different
  # operation.)
  ! awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" | grep -qE 'git merge --ff-only "\$BRANCH"|git merge --ff-only.*\$FEATURE_BRANCH'
}

@test "Phase 2 uses git commit -F to read the prepared message file" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" | grep -qE 'git commit -F'
}

@test "Phase 2.1 verifies post-squash tree equality between main and feature branch" {
  awk '/### 2\.1:/,/^## Phase 3:/' "$SKILL_FILE" | grep -qE 'git diff.*main.*BRANCH'
}

# === Phase 3: push + workflow-scope detection ===

@test "Phase 3 has workflow-scope detection mirroring /ak-build Phase 5.4" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" | grep -qE '\.github/workflows/'
}

# === Phase 4: cleanup ===

@test "Phase 4 force-deletes the local feature branch (git branch -D)" {
  awk '/^## Phase 4:/,/^## Phase 5:/' "$SKILL_FILE" | grep -qE 'git branch -D'
}

@test "Phase 4 cleans up the remote branch (git push origin --delete)" {
  awk '/^## Phase 4:/,/^## Phase 5:/' "$SKILL_FILE" | grep -qE 'git push origin --delete'
}

# === Phase 5: handoff ===

@test "Phase 5 surfaces release-candidate hint based on conventional-commit prefixes since last tag" {
  awk '/^## Phase 5:/,/^---$|^##.*Idempotence/' "$SKILL_FILE" | grep -qE 'feat|fix|BREAKING'
  awk '/^## Phase 5:/,/^---$|^##.*Idempotence/' "$SKILL_FILE" | grep -qE 'ak-release-devshop'
}
