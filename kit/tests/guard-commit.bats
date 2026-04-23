#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/commit-guard.sh
# Five checks: mixed-commit, docs-drift, doc-consistency, cross-repo, release-coverage

setup() {
  load helpers/setup
  setup_mock_bin
  GUARD="$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
}

# Create a wrapper with mocked adversarial-review, optional GIT_ROOT override,
# and cross-repo check disabled (OTHER_REPO="") unless explicitly testing it.
make_wrapper() {
  local git_root_override="${1:-}" disable_cross_repo="${2:-true}"
  WRAPPER="$BATS_TEST_TMPDIR/guard-wrapper.sh"
  cp "$GUARD" "$WRAPPER"
  # Mock adversarial-review.sh
  sed -i "s|bash \"\$SCRIPT_DIR/../adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$WRAPPER"
  # Override GIT_ROOT if requested
  if [ -n "$git_root_override" ]; then
    sed -i "s|GIT_ROOT=\$(git rev-parse --show-toplevel.*|GIT_ROOT=\"$git_root_override\"|" "$WRAPPER"
  fi
  # Disable cross-repo check to isolate tests from real /devshop state
  if [ "$disable_cross_repo" = "true" ]; then
    sed -i 's|if \[ -n "\$OTHER_REPO" \] \&\& \[ -d "\$OTHER_REPO/\.git" \]|if false|' "$WRAPPER"
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
  echo "# MODEL" > "$TEST_REPO/kit/docs/MODEL.md"
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
  # Devshop-only files still trigger docs-drift
  git -C "$TEST_REPO" config devshop.docsVerified "reviewed — new skill, no doc changes needed"
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

# === docs-drift ===

@test "docs-drift: blocks devshop file change without docs review notes" {
  setup_devshop_repo
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-drift: passes with review notes when adversarial accepts" {
  setup_devshop_repo
  mock_adversarial_review PASS
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  git -C "$TEST_REPO" config devshop.docsVerified "reviewed all docs, no changes needed"
  run_guard
  assert_success
}

@test "docs-drift: blocks with review notes when adversarial rejects" {
  setup_devshop_repo
  mock_adversarial_review FAIL
  stage_file "kit/scripts/new-guard.sh" "#!/bin/bash"
  git -C "$TEST_REPO" config devshop.docsVerified "looks fine"
  run_guard
  assert_failure 1
  assert_output --partial "REJECTED"
}

@test "docs-drift: skips changelog-only commits" {
  setup_devshop_repo
  echo "## v1.0.1" >> "$TEST_REPO/kit/docs/CHANGELOG.md"
  git -C "$TEST_REPO" add kit/docs/CHANGELOG.md
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_guard
  assert_success
}

@test "docs-drift: triggers for project repo devshop file changes" {
  setup_project_repo
  # .devshopkit/ is a real dir (created in setup), so staging works
  stage_file ".devshopkit/scripts/new-guard.sh" "#!/bin/bash"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-drift: triggers for skill changes in devshop repo (.claude/skills/devshop/)" {
  setup_devshop_repo
  stage_file ".claude/skills/devshop/build/SKILL.md" "# Skill body"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-drift: triggers for root CLAUDE.md change in devshop repo" {
  setup_devshop_repo
  echo "new convention line" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

@test "docs-drift: triggers for .claude/settings change in devshop repo" {
  setup_devshop_repo
  stage_file ".claude/settings.json" '{"key":"value"}'
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

# === doc-consistency ===

@test "doc-consistency: blocks when ref doc staged without sync reason" {
  setup_devshop_repo
  echo "# Updated MODEL" > "$TEST_REPO/kit/docs/MODEL.md"
  git -C "$TEST_REPO" add kit/docs/MODEL.md
  run_guard
  assert_failure 1
  assert_output --partial "Reference doc changed"
}

@test "doc-consistency: passes with sync reason when adversarial accepts" {
  setup_devshop_repo
  mock_adversarial_review PASS
  echo "# Updated MODEL" > "$TEST_REPO/kit/docs/MODEL.md"
  git -C "$TEST_REPO" add kit/docs/MODEL.md
  # MODEL.md is under kit/ so docs-drift triggers too — need both flags
  git -C "$TEST_REPO" config devshop.docsVerified "updated MODEL, checked all other docs"
  git -C "$TEST_REPO" config devshop.docSyncReason "updated MODEL, checked OVERVIEW and guide for consistency"
  run_guard
  assert_success
}

@test "doc-consistency: detects CLAUDE.md change in devshop repo" {
  setup_devshop_repo
  echo "# Updated CLAUDE" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_guard
  assert_failure 1
  assert_output --partial "Reference doc changed"
}

@test "doc-consistency: detects guide/ changes" {
  setup_devshop_repo
  echo "# Updated workflow" > "$TEST_REPO/kit/docs/guide/workflow.md"
  git -C "$TEST_REPO" add kit/docs/guide/workflow.md
  run_guard
  assert_failure 1
  assert_output --partial "Reference doc changed"
}

# === cross-repo ===

@test "cross-repo: passes when no other repo exists (devshop-self)" {
  setup_devshop_repo
  echo "## v1.0.1" >> "$TEST_REPO/kit/docs/CHANGELOG.md"
  git -C "$TEST_REPO" add kit/docs/CHANGELOG.md
  echo "1.0.1" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_guard
  assert_success
}

@test "cross-repo: blocks when other repo is dirty" {
  # Set up two repos: project + devshop
  setup_project_repo
  local other_repo="$BATS_TEST_TMPDIR/other-devshop"
  mkdir -p "$other_repo"
  git -C "$other_repo" init -q
  git -C "$other_repo" config user.email "test@test.com"
  git -C "$other_repo" config user.name "Test"
  echo "init" > "$other_repo/.gitkeep"
  git -C "$other_repo" add .
  git -C "$other_repo" commit -q -m "initial"
  # Make the other repo dirty
  echo "dirty" > "$other_repo/uncommitted.txt"

  # Rebuild wrapper: override GIT_ROOT and OTHER_REPO (keep cross-repo enabled)
  make_wrapper "/workspace" "false"
  sed -i "s|OTHER_REPO=/devshop|OTHER_REPO=$other_repo|" "$WRAPPER"

  stage_file "src/index.ts" "code"
  run_guard
  assert_failure 1
  assert_output --partial "uncommitted changes"
}

@test "cross-repo: passes when other repo is clean" {
  setup_project_repo
  local other_repo="$BATS_TEST_TMPDIR/other-devshop"
  mkdir -p "$other_repo"
  git -C "$other_repo" init -q
  git -C "$other_repo" config user.email "test@test.com"
  git -C "$other_repo" config user.name "Test"
  echo "init" > "$other_repo/.gitkeep"
  git -C "$other_repo" add .
  git -C "$other_repo" commit -q -m "initial"

  make_wrapper "/workspace" "false"
  sed -i "s|OTHER_REPO=/devshop|OTHER_REPO=$other_repo|" "$WRAPPER"

  stage_file "src/index.ts" "code"
  run_guard
  assert_success
}

# === Multiple simultaneous failures ===

@test "reports both docs-drift and doc-consistency failures together" {
  setup_devshop_repo
  # Stage a kit/ file (triggers docs-drift) AND a ref doc (triggers doc-consistency)
  stage_file "kit/scripts/new-thing.sh" "#!/bin/bash"
  echo "# Updated MODEL" > "$TEST_REPO/kit/docs/MODEL.md"
  git -C "$TEST_REPO" add kit/docs/MODEL.md
  run_guard
  assert_failure 1
  # Both checks should appear in output
  assert_output --partial "docs review required"
  assert_output --partial "Reference doc changed"
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

@test "docs-drift: triggers for README.md in devshop repo (no tooling-allowlist)" {
  # In the devshop repo, every staged file is devshop by default — only
  # release artifacts (CHANGELOG + version) are excluded. README.md is a
  # reference doc; changes can have cross-ref implications, so the adversarial
  # drift review must judge them. See `docs-drift: skips changelog-only
  # commits` above for the opposite case.
  setup_devshop_repo
  stage_file "README.md" "# updated readme"
  run_guard
  assert_failure 1
  assert_output --partial "docs review required"
}

# === release-coverage (devshop repo only) ===

@test "release-coverage: skips when kit/version not staged" {
  # Use a changelog-only stage so docs-drift skips too (the devshop-repo drift
  # regex matches everything except CHANGELOG/version). The intent here is
  # to verify release-coverage doesn't fire, not to test drift behavior.
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
