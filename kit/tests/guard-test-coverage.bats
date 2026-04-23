#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-test-coverage.sh
# Flags kit/scripts changes that lack corresponding tests

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/commit-hooks/check-test-coverage.sh"

  # Create a devshop-like repo with kit/scripts and kit/tests
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/tests"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"

  # Create an existing script and its test
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/existing-guard.sh"
  echo '@test "tests existing-guard.sh" { true; }' > "$TEST_REPO/kit/tests/guard-existing.bats"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
}

run_check() {
  run bash -c "cd '$TEST_REPO' && DEVSHOP='$TEST_REPO' bash '$CHECK'"
}

@test "passes when no scripts are staged" {
  echo "readme" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  run_check
  assert_success
}

@test "passes when not in devshop repo" {
  local project="$BATS_TEST_TMPDIR/project"
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

@test "blocks new script without test file" {
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/new-guard.sh"
  git -C "$TEST_REPO" add "kit/scripts/new-guard.sh"
  run_check
  assert_failure 1
  assert_output --partial "BLOCKING"
  assert_output --partial "new-guard.sh"
}

@test "passes new script that has a test referencing it" {
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/new-guard.sh"
  echo '@test "tests new-guard.sh" { true; }' > "$TEST_REPO/kit/tests/guard-new.bats"
  git -C "$TEST_REPO" add "kit/scripts/new-guard.sh" "kit/tests/guard-new.bats"
  run_check
  assert_success
}

@test "warns on modified script without test file" {
  # Modify existing script (which has a test)
  echo '#!/bin/bash\necho updated' > "$TEST_REPO/kit/scripts/existing-guard.sh"
  git -C "$TEST_REPO" add "kit/scripts/existing-guard.sh"
  # Test file references existing-guard.sh, so no warning
  run_check
  assert_success
}

@test "warns on modified script with no test reference" {
  # Create a script without tests, commit it, then modify
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/untested.sh"
  git -C "$TEST_REPO" add "kit/scripts/untested.sh"
  git -C "$TEST_REPO" commit -q -m "add untested"
  echo '#!/bin/bash\necho modified' > "$TEST_REPO/kit/scripts/untested.sh"
  git -C "$TEST_REPO" add "kit/scripts/untested.sh"
  run_check
  # Should warn but not block
  assert_success
  assert_output --partial "untested.sh"
  assert_output --partial "consider adding tests"
}

@test "skips exempt scripts" {
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/adversarial-review.sh"
  git -C "$TEST_REPO" add "kit/scripts/adversarial-review.sh"
  run_check
  assert_success
}

@test "skips exempt script: statusline.sh" {
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/statusline.sh"
  git -C "$TEST_REPO" add "kit/scripts/statusline.sh"
  run_check
  assert_success
}
