#!/usr/bin/env bats
# Tests for .claude/skills/devshop/sync-from-devshop/SKILL.md — the devshop
# sync skill (pre-flight + version detection → from-devshop.sh → propagation
# review → commit).
#
# The skill is a pure LLM prompt (Markdown), so these are content-validation
# tests: grep its required phases, the version-case table, the sync invocation,
# the semver propagation filter, and the version-range commit message to
# confirm the prose reflects the contract documented in
# `kit/docs/guide/workflow.md § Devshop Skill Map` and the session-start
# drift-message handoff.
#
# Sections:
#   A — Existence + symlink (SKILL.md at canonical path, ak-sync-from-devshop
#       symlink resolves for /-autocomplete discovery).
#   B — Frontmatter (name: drives slash-command autocomplete).
#   C — Phase contract (1 pre-flight + version cases, 2 sync, 3 propagation
#       semver filter, 4 version-range commit message).
#
# Behavior tests (running the LLM end-to-end) are out of scope; this proves
# the prompt reflects the contract.

setup() {
  load helpers/setup
  # Canonical location: /devshop/.claude/skills/devshop/<short-name>/SKILL.md
  # (symlinked to /devshop/.claude/skills/ak-<short-name> for /-autocomplete
  # discovery via kit/scripts/sync/create-devshop-symlinks.sh).
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/sync-from-devshop/SKILL.md"
  SYMLINK="$TESTS_DIR/../../.claude/skills/ak-sync-from-devshop"
  # Do NOT defensively skip when SKILL.md is missing — a rename/move/delete is
  # precisely the regression this file exists to catch.
}

# === Section A — Existence + symlink ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "symlink .claude/skills/ak-sync-from-devshop resolves to devshop/sync-from-devshop" {
  [ -L "$SYMLINK" ]
  [ "$(readlink "$SYMLINK")" = "devshop/sync-from-devshop" ]
}

# === Section B — Frontmatter ===

@test "frontmatter name is ak-sync-from-devshop (drives slash-command autocomplete)" {
  grep -qE '^name: ak-sync-from-devshop$' "$SKILL_FILE"
}

# === Section C — Phase contract ===

@test "Phase 1 version detection documents the three version cases" {
  awk '/^## Phase 1 /,/^## Phase 2 /' "$SKILL_FILE" | grep -qiE 'First sync'
  awk '/^## Phase 1 /,/^## Phase 2 /' "$SKILL_FILE" | grep -qiE 'Upgrade'
  awk '/^## Phase 1 /,/^## Phase 2 /' "$SKILL_FILE" | grep -qiE 'Already current'
}

@test "Phase 1 has a dirty working tree pre-flight guard" {
  awk '/^## Phase 1 /,/^## Phase 2 /' "$SKILL_FILE" \
    | grep -qiE 'uncommitted changes|dirty working tree|git status --porcelain'
}

@test "Phase 2 runs from-devshop.sh with --yes (skill owns confirmation)" {
  awk '/^## Phase 2 /,/^## Phase 3 /' "$SKILL_FILE" \
    | grep -qE 'from-devshop\.sh --yes'
}

@test "Phase 3 parses ## v{x.y.z} headers and filters by semver (upgrade case)" {
  awk '/^## Phase 3 /,/^## Phase 4 /' "$SKILL_FILE" \
    | grep -qE '## v\{x\.y\.z\}'
  awk '/^## Phase 3 /,/^## Phase 4 /' "$SKILL_FILE" \
    | grep -qiE 'filter by semver|semver'
}

@test "Phase 4 builds the version-range commit message (chore: sync from devshop)" {
  awk '/^## Phase 4 /,/^## Output conventions/' "$SKILL_FILE" \
    | grep -qE 'chore: sync from devshop'
}
