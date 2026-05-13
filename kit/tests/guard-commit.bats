#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/commit-guard.sh
# After PR-C of the audit-time docs+tests migration (kit/ROADMAP.md § PR-C),
# this script holds only one check:
#   mixed-commit       (DETERMINISTIC, project repo only)
#                      devshop + project files staged together → block
#
# What used to live here:
#   docs-reviewed      → audit-time `/ak-docs-review` (orchestrated by
#                        `/ak-check-docs-and-tests`); Layer 1 file-pairing
#                        moved to check-docs-coverage-{project,devshop}.sh
#   release-coverage   → audit-time `/ak-tests-review` running per-merge

setup() {
  load helpers/setup
  setup_mock_bin
  GUARD="$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
}

# Create a wrapper with optional GIT_ROOT override.
make_wrapper() {
  local git_root_override="${1:-}"
  WRAPPER="$BATS_TEST_TMPDIR/guard-wrapper.sh"
  cp "$GUARD" "$WRAPPER"
  if [ -n "$git_root_override" ]; then
    sed -i "s|GIT_ROOT=\$(git rev-parse --show-toplevel.*|GIT_ROOT=\"$git_root_override\"|" "$WRAPPER"
  fi
  chmod +x "$WRAPPER"
}

setup_project_repo() {
  TEST_REPO="$BATS_TEST_TMPDIR/project"
  mkdir -p "$TEST_REPO/.devshopkit/scripts" "$TEST_REPO/.claude/skills" "$TEST_REPO/src"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
  make_wrapper "/workspace"
  # Force project-mode detection in detect-mode.sh: sed-rewriting GIT_ROOT to
  # /workspace isn't enough on its own when this suite runs from the devshop
  # devcontainer (where /workspace/kit is a real bind-mounted dir → auto
  # detection would say devshop-self). The override is the test-only escape
  # hatch documented in kit/scripts/sync/lib/detect-mode.sh.
  export DEVSHOP_FORCE_MODE=project
}

setup_devshop_repo() {
  # Devshop-mode tests rely on auto detection (the test repo's kit/ is created
  # below as a real dir), but make the intent explicit via override so the
  # test isn't environment-coupled — same pattern as setup_project_repo.
  export DEVSHOP_FORCE_MODE=devshop-self
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/docs/guide"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  echo "# OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  echo "# CLAUDE" > "$TEST_REPO/CLAUDE.md"
  echo "1.0.0" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
  # kit/ is a real dir (not symlink) — triggers devshop-self detection
  make_wrapper
}

run_guard() {
  run bash -c "cd '$TEST_REPO' && bash '$WRAPPER'"
}

# === mixed-commit (project repo only) ===

@test "mixed-commit: blocks mixed devshop + project files in project repo" {
  setup_project_repo
  stage_file ".claude/skills/new-skill.md" "skill"
  stage_file "src/index.ts" "code"
  run_guard
  assert_failure 1
  assert_output --partial "Mixed commit"
}

@test "mixed-commit: allows project-only files in project repo" {
  setup_project_repo
  stage_file "src/index.ts" "code"
  stage_file "src/utils.ts" "utils"
  run_guard
  assert_success
}

@test "mixed-commit: allows devshop-only files in project repo (no docs review fires here)" {
  setup_project_repo
  stage_file ".claude/skills/new-skill.md" "skill"
  # Devshop-only files in project repo no longer trigger any commit-guard.sh
  # check (docs-reviewed moved to audit-time `/ak-docs-review` per PR-C);
  # mixed-commit only fires when BOTH classifications are staged together.
  run_guard
  assert_success
}

@test "mixed-commit: detects .dcg.toml as devshop file" {
  setup_project_repo
  stage_file ".dcg.toml" "[packs]"
  stage_file "src/index.ts" "code"
  run_guard
  assert_failure 1
  assert_output --partial "Mixed commit"
}

@test "mixed-commit: detects .devshopkit/ files as devshop in project repo" {
  setup_project_repo
  stage_file ".devshopkit/scripts/guard.sh" "#!/bin/bash"
  stage_file "src/index.ts" "code"
  run_guard
  assert_failure 1
  assert_output --partial "Mixed commit"
}

# === Devshop repo (no docs/release-coverage commit-time checks remain after PR-C) ===

@test "devshop repo: a kit/scripts change passes commit-guard.sh (docs-coverage moved to its own Layer 1 hook)" {
  # Pre-PR-C this fired commit-guard.sh's docs-reviewed check (semantic, LLM).
  # Post-PR-C: commit-guard.sh has no devshop-side check; the file-pairing
  # check lives in check-docs-coverage-devshop.sh which is invoked separately
  # by kit/hooks/pre-commit.sh.
  setup_devshop_repo
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  run_guard
  assert_success
}

@test "devshop repo: a kit/version bump passes commit-guard.sh (release-coverage moved to audit-time)" {
  # Pre-PR-C this fired commit-guard.sh's release-coverage check, which ran
  # an adversarial review of test coverage at release time. Post-PR-C:
  # release.sh writes the bump + tag and the audit pipeline judges coverage
  # at audit time (not per-release).
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_guard
  assert_success
  refute_output --partial "Release coverage:"
}

# === Edge cases ===

@test "passes with no staged files" {
  setup_devshop_repo
  run_guard
  assert_success
}
