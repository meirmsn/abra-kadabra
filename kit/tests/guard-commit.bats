#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/commit-guard.sh
# Three checks: mixed-commit, docs-reviewed, release-coverage
# (docs-drift + doc-consistency merged into docs-reviewed in 2026-04-27;
#  cross-repo blocking check removed in v1.20.0 — see commit-guard.sh header.)

setup() {
  load helpers/setup
  setup_mock_bin
  GUARD="$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
}

# Create a wrapper with mocked adversarial-review, optional GIT_ROOT override.
make_wrapper() {
  local git_root_override="${1:-}"
  WRAPPER="$BATS_TEST_TMPDIR/guard-wrapper.sh"
  cp "$GUARD" "$WRAPPER"
  # Mock adversarial-review.sh
  sed -i "s|bash \"\$SCRIPT_DIR/../adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$WRAPPER"
  # Override GIT_ROOT if requested
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
}

setup_devshop_repo() {
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/docs/guide"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  echo "# OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  echo "# FAQ" > "$TEST_REPO/kit/docs/FAQ.md"
  echo "# CLAUDE" > "$TEST_REPO/CLAUDE.md"
  echo "# Workflow" > "$TEST_REPO/kit/docs/guide/workflow.md"
  echo "# CHANGELOG" > "$TEST_REPO/kit/docs/CHANGELOG.md"
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

@test "mixed-commit: allows devshop-only files in project repo (with docs review)" {
  setup_project_repo
  mock_adversarial_review PASS
  stage_file ".claude/skills/new-skill.md" "skill"
  # Devshop-only files still trigger docs-reviewed (merged check)
  git -C "$TEST_REPO" config devshop.docsReviewed "reviewed — new skill, no doc changes needed"
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

# === docs-reviewed (merged from former docs-drift + doc-consistency) ===

@test "docs-reviewed: blocks devshop file change without docs review notes" {
  setup_devshop_repo
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-reviewed: passes with review notes when adversarial accepts" {
  setup_devshop_repo
  mock_adversarial_review PASS
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  git -C "$TEST_REPO" config devshop.docsReviewed "reviewed all docs, no changes needed"
  run_guard
  assert_success
}

@test "docs-reviewed: blocks with review notes when adversarial rejects" {
  setup_devshop_repo
  mock_adversarial_review FAIL
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  git -C "$TEST_REPO" config devshop.docsReviewed "looks fine"
  run_guard
  assert_failure 1
  assert_output --partial "REJECTED"
}

@test "docs-reviewed: skips changelog-only commits" {
  setup_devshop_repo
  echo "## v1.0.1" >> "$TEST_REPO/kit/docs/CHANGELOG.md"
  git -C "$TEST_REPO" add kit/docs/CHANGELOG.md
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_guard
  assert_success
}

@test "docs-reviewed: triggers for project repo devshop file changes" {
  setup_project_repo
  # .devshopkit/ is a real dir (created in setup), so staging works
  stage_file ".devshopkit/scripts/new-guard.sh" "#!/bin/bash"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-reviewed: triggers for skill changes in devshop repo (.claude/skills/devshop/)" {
  setup_devshop_repo
  stage_file ".claude/skills/devshop/build/SKILL.md" "# Skill body"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-reviewed: triggers for root CLAUDE.md change in devshop repo" {
  setup_devshop_repo
  echo "new convention line" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-reviewed: triggers for .claude/settings change in devshop repo" {
  setup_devshop_repo
  stage_file ".claude/settings.json" '{"key":"value"}'
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

# === Reference-doc-staged sub-cases (cross-file coherence rule kicks in) ===

@test "docs-reviewed: blocks when ref doc staged without review notes" {
  setup_devshop_repo
  echo "# Updated OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  git -C "$TEST_REPO" add kit/docs/OVERVIEW.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
  assert_output --partial "Reference docs ALSO staged"
}

@test "docs-reviewed: passes when ref doc staged with single docsReviewed flag (one flag covers both coverage + coherence)" {
  setup_devshop_repo
  mock_adversarial_review PASS
  echo "# Updated OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  git -C "$TEST_REPO" add kit/docs/OVERVIEW.md
  git -C "$TEST_REPO" config devshop.docsReviewed "updated OVERVIEW; checked guide for cross-file coherence; no other docs affected"
  run_guard
  assert_success
}

@test "docs-reviewed: detects CLAUDE.md change in devshop repo" {
  setup_devshop_repo
  echo "# Updated CLAUDE" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
  assert_output --partial "Reference docs ALSO staged"
}

@test "docs-reviewed: detects guide/ changes" {
  setup_devshop_repo
  echo "# Updated workflow" > "$TEST_REPO/kit/docs/guide/workflow.md"
  git -C "$TEST_REPO" add kit/docs/guide/workflow.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
  assert_output --partial "Reference docs ALSO staged"
}

# === Combined: code + ref doc fires ONE check (formerly two) ===

@test "docs-reviewed: code change + ref doc fires single merged check" {
  setup_devshop_repo
  # Stage a kit/ file AND a ref doc — formerly fired docs-drift + doc-consistency
  # as two separate checks; now fires ONE merged docs-reviewed check.
  stage_file "kit/scripts/new-thing.sh" "#!/bin/bash"
  echo "# Updated OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  git -C "$TEST_REPO" add kit/docs/OVERVIEW.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
  assert_output --partial "Reference docs ALSO staged"
}

# === DEVSHOP_REGEX pattern coverage ===

@test "mixed-commit: detects .devshopkit/ files as devshop in project repo" {
  setup_project_repo
  stage_file ".devshopkit/scripts/guard.sh" "#!/bin/bash"
  stage_file "src/index.ts" "code"
  run_guard
  assert_failure 1
  assert_output --partial "Mixed commit"
}

# === Edge cases ===

@test "passes with no staged files" {
  setup_devshop_repo
  run_guard
  assert_success
}

@test "docs-reviewed: triggers for README.md in devshop repo (no tooling-allowlist)" {
  # In the devshop repo, every staged file is devshop by default — only
  # release artifacts (CHANGELOG + version) are excluded. README.md is a
  # reference doc; changes can have cross-ref implications, so the adversarial
  # docs review must judge them. See `docs-reviewed: skips changelog-only
  # commits` above for the opposite case.
  setup_devshop_repo
  stage_file "README.md" "# updated readme"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

# === release-coverage (devshop repo only) ===

@test "release-coverage: skips when kit/version not staged" {
  # Use a changelog-only stage so docs-reviewed skips too (the devshop-repo
  # docs regex matches everything except CHANGELOG/version). The intent here
  # is to verify release-coverage doesn't fire, not to test docs behavior.
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  stage_file "kit/docs/CHANGELOG.md" "## v1.0.1"
  run_guard
  assert_success
  refute_output --partial "Release coverage:"
}

@test "release-coverage: skips when no prior tag exists (first release)" {
  setup_devshop_repo
  # No tag created — v1.0.0 does not exist yet
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_guard
  assert_success
  refute_output --partial "Release coverage:"
}

@test "release-coverage: runs review when kit/version is bumped" {
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  mock_adversarial_review PASS
  run_guard
  assert_success
  assert_output --partial "Release coverage: adversarial review accepted"
}

@test "release-coverage: blocks when adversarial review rejects coverage" {
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  mock_adversarial_review FAIL
  run_guard
  assert_failure 1
  assert_output --partial "Pre-release test coverage review FAILED"
}

@test "release-coverage: passes with releaseReviewed bypass when reviewer accepts" {
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  git -C "$TEST_REPO" config devshop.releaseReviewed "changes are docs-only, no new test coverage needed"
  mock_adversarial_review PASS
  run_guard
  assert_success
  assert_output --partial "Release coverage: adversarial review accepted"
}

@test "release-coverage: blocks bypass when reviewer rejects justification" {
  setup_devshop_repo
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  git -C "$TEST_REPO" config devshop.releaseReviewed "looks fine"
  mock_adversarial_review FAIL
  run_guard
  assert_failure 1
  assert_output --partial "Your justification was rejected"
}
