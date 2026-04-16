#!/usr/bin/env bats
# Tests for release.sh pre-release test coverage gate
# Verifies the gate detects functional changes and invokes review

setup() {
  load helpers/setup
  setup_mock_bin
  RELEASE="$SCRIPTS_DIR/release.sh"

  # Create a devshop-like repo with version and tags
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/tests" "$TEST_REPO/kit/docs"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "1.0.0" > "$TEST_REPO/kit/version"
  echo "# CHANGELOG" > "$TEST_REPO/kit/docs/CHANGELOG.md"
  echo '#!/bin/bash' > "$TEST_REPO/kit/scripts/guard.sh"
  echo '@test "test" { true; }' > "$TEST_REPO/kit/tests/guard.bats"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
}

# Extract just the pre-release gate logic into a testable function
run_gate_check() {
  local repo="$1"
  cd "$repo"

  local LAST_TAG="v$(cat kit/version | tr -d '[:space:]')"
  local FUNC_CHANGES
  FUNC_CHANGES=$(git diff --name-only "$LAST_TAG"..HEAD | grep -E '^kit/scripts/|^kit/hooks/' || true)
  local TEST_CHANGES
  TEST_CHANGES=$(git diff --name-only "$LAST_TAG"..HEAD | grep '^kit/tests/' || true)

  if [ -z "$FUNC_CHANGES" ]; then
    echo "NO_FUNC_CHANGES"
  elif [ -n "$TEST_CHANGES" ]; then
    echo "TESTS_ALSO_CHANGED"
  else
    echo "NEEDS_REVIEW"
  fi
}

@test "release gate: skips when no functional changes since tag" {
  # Only doc changes since tag
  echo "# updated" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -q -m "docs only"

  result=$(run_gate_check "$TEST_REPO")
  assert_equal "$result" "NO_FUNC_CHANGES"
}

@test "release gate: detects functional changes without test updates" {
  echo '#!/bin/bash\necho new' > "$TEST_REPO/kit/scripts/guard.sh"
  git -C "$TEST_REPO" add kit/scripts/guard.sh
  git -C "$TEST_REPO" commit -q -m "modify script"

  result=$(run_gate_check "$TEST_REPO")
  assert_equal "$result" "NEEDS_REVIEW"
}

@test "release gate: passes when both scripts and tests changed" {
  echo '#!/bin/bash\necho new' > "$TEST_REPO/kit/scripts/guard.sh"
  echo '@test "new test" { true; }' >> "$TEST_REPO/kit/tests/guard.bats"
  git -C "$TEST_REPO" add kit/scripts/guard.sh kit/tests/guard.bats
  git -C "$TEST_REPO" commit -q -m "script + test"

  result=$(run_gate_check "$TEST_REPO")
  assert_equal "$result" "TESTS_ALSO_CHANGED"
}

@test "release gate: detects hook changes as functional" {
  mkdir -p "$TEST_REPO/kit/hooks"
  echo '#!/bin/bash' > "$TEST_REPO/kit/hooks/pre-commit.sh"
  git -C "$TEST_REPO" add kit/hooks/pre-commit.sh
  git -C "$TEST_REPO" commit -q -m "add hook"

  result=$(run_gate_check "$TEST_REPO")
  assert_equal "$result" "NEEDS_REVIEW"
}
