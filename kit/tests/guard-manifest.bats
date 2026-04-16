#!/usr/bin/env bats
# Tests for kit/scripts/check-manifest.sh
# Pre-commit guard: detects template/ file additions/removals not in manifest.txt

setup() {
  load helpers/setup
  setup_mock_bin
  CHECK="$SCRIPTS_DIR/check-manifest.sh"

  # Create a test repo that looks like the devshop (kit/ is a real dir)
  TEST_REPO="$BATS_TEST_TMPDIR/devshop-repo"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/docs" "$TEST_REPO/template"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"

  # Create a manifest with some entries
  cat > "$TEST_REPO/kit/manifest.txt" <<'MANIFEST'
# Synced files between devshop template/ and projects
turbo.json
eslint.config.mjs
.github/workflows/
.devcontainer/
MANIFEST

  # Initial commit with manifest and template files
  echo '{}' > "$TEST_REPO/template/turbo.json"
  mkdir -p "$TEST_REPO/template/.github/workflows"
  echo 'ci' > "$TEST_REPO/template/.github/workflows/ci.yml"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
}

# Helper: run the check inside the test repo, overriding DEVSHOP to point here
run_check() {
  run bash -c "cd '$TEST_REPO' && DEVSHOP='$TEST_REPO' bash '$CHECK'"
}

run_check_with_review() {
  local review_result="$1"
  mock_adversarial_review "$review_result"
  local wrapper="$BATS_TEST_TMPDIR/check-wrapper.sh"
  sed "s|bash \"\$SCRIPT_DIR/adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$CHECK" > "$wrapper"
  chmod +x "$wrapper"
  run bash -c "cd '$TEST_REPO' && DEVSHOP='$TEST_REPO' bash '$wrapper'"
}

@test "passes when no template/ changes are staged" {
  # Modify a non-template file
  echo "update" > "$TEST_REPO/kit/docs/README.md"
  git -C "$TEST_REPO" add kit/docs/README.md
  run_check
  assert_success
}

@test "passes when not in devshop repo (project repo)" {
  # Create a project-like repo (no kit/ dir, or kit/ is a symlink)
  local project="$BATS_TEST_TMPDIR/project-repo"
  mkdir -p "$project"
  git -C "$project" init -q
  git -C "$project" config user.email "test@test.com"
  git -C "$project" config user.name "Test"
  echo "init" > "$project/.gitkeep"
  git -C "$project" add .
  git -C "$project" commit -q -m "initial"

  run bash -c "cd '$project' && DEVSHOP='$TEST_REPO' bash '$CHECK'"
  assert_success
}

@test "passes when added file is covered by directory entry in manifest" {
  # .github/workflows/ is in manifest, so adding a file under it should pass
  echo "deploy" > "$TEST_REPO/template/.github/workflows/deploy.yml"
  git -C "$TEST_REPO" add "template/.github/workflows/deploy.yml"
  run_check
  assert_success
}

@test "passes when added file matches exact manifest entry" {
  # turbo.json is in manifest exactly
  echo '{"pipeline":{}}' > "$TEST_REPO/template/turbo.json"
  # This is a modification, not addition — we need a new exact-match file
  # Add eslint.config.mjs which is in manifest
  echo 'export default {}' > "$TEST_REPO/template/eslint.config.mjs"
  git -C "$TEST_REPO" add "template/eslint.config.mjs"
  run_check
  assert_success
}

@test "blocks when added file is NOT in manifest" {
  echo "new" > "$TEST_REPO/template/new-config.yml"
  git -C "$TEST_REPO" add "template/new-config.yml"
  run_check
  assert_failure 1
  assert_output --partial "new-config.yml"
  assert_output --partial "manifest"
}

@test "blocks when deleted file is in manifest" {
  git -C "$TEST_REPO" rm -q "template/turbo.json"
  run_check
  assert_failure 1
  assert_output --partial "turbo.json"
}

@test "passes with bypass reason when adversarial review accepts" {
  echo "new" > "$TEST_REPO/template/new-config.yml"
  git -C "$TEST_REPO" add "template/new-config.yml"
  git -C "$TEST_REPO" config devshop.manifestReviewed "new-config.yml is template-only, not synced"
  run_check_with_review PASS
  assert_success
  assert_output --partial "accepted"
}

@test "blocks with bypass reason when adversarial review rejects" {
  echo "new" > "$TEST_REPO/template/new-config.yml"
  git -C "$TEST_REPO" add "template/new-config.yml"
  git -C "$TEST_REPO" config devshop.manifestReviewed "whatever"
  run_check_with_review FAIL
  assert_failure 1
  assert_output --partial "REJECTED"
}
