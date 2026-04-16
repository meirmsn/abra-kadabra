#!/usr/bin/env bash
# Shared BATS test helpers for kit/tests/
# Provides: mock bin setup, adversarial-review stubs, temp git repo creation

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/../scripts" && pwd)"
HOOKS_DIR="$(cd "$TESTS_DIR/../hooks" && pwd)"

load "$TESTS_DIR/lib/bats-support/load"
load "$TESTS_DIR/lib/bats-assert/load"

# --- Environment isolation ---
# When BATS runs inside a pre-commit hook (e.g., git -c devshop.docsVerified="..."),
# GIT_CONFIG_PARAMETERS leaks -c flags into test repos. Unset to isolate tests.
unset GIT_CONFIG_PARAMETERS

# --- Mock bin ---

# Create a temp directory for mock executables and prepend to PATH.
# Call in setup(). Cleaned up automatically via BATS_TMPDIR.
setup_mock_bin() {
  MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"
}

# Create a stub executable that prints output and exits with a code.
#   create_stub <name> <stdout> [exit_code]
create_stub() {
  local name="$1" output="$2" exit_code="${3:-0}"
  cat > "$MOCK_BIN/$name" <<STUB
#!/bin/bash
echo "$output"
exit $exit_code
STUB
  chmod +x "$MOCK_BIN/$name"
}

# Create a stub that captures its arguments to a file and returns canned output.
#   create_capturing_stub <name> <stdout> [exit_code]
# Arguments written to $MOCK_BIN/<name>.args (one invocation per line).
create_capturing_stub() {
  local name="$1" output="$2" exit_code="${3:-0}"
  cat > "$MOCK_BIN/$name" <<STUB
#!/bin/bash
echo "\$@" >> "$MOCK_BIN/${name}.args"
echo "$output"
exit $exit_code
STUB
  chmod +x "$MOCK_BIN/$name"
}

# --- Adversarial review mock ---

# Mock adversarial-review.sh to return PASS or FAIL.
#   mock_adversarial_review PASS   → exit 0
#   mock_adversarial_review FAIL   → exit 1 with "FAIL: mocked rejection"
mock_adversarial_review() {
  local result="$1"
  if [ "$result" = "PASS" ]; then
    cat > "$MOCK_BIN/adversarial-review.sh" <<'STUB'
#!/bin/bash
echo "PASS: mocked acceptance"
exit 0
STUB
  else
    cat > "$MOCK_BIN/adversarial-review.sh" <<'STUB'
#!/bin/bash
echo "FAIL: mocked rejection"
exit 1
STUB
  fi
  chmod +x "$MOCK_BIN/adversarial-review.sh"
}

# --- Temp git repo ---

# Create a throwaway git repo with one initial commit.
# Sets TEST_REPO to the path. Caller can cd into it.
create_test_repo() {
  TEST_REPO="$BATS_TEST_TMPDIR/test-repo"
  mkdir -p "$TEST_REPO"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  git -C "$TEST_REPO" add .gitkeep
  git -C "$TEST_REPO" commit -q -m "initial"
}

# Create and stage a file in the test repo.
#   stage_file <relative_path> [content]
stage_file() {
  local path="$1" content="${2:-test content}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add "$path"
}

# Create an untracked file (not staged).
#   create_untracked <relative_path> [content]
create_untracked() {
  local path="$1" content="${2:-untracked content}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
}

# Create a tracked file, then modify it without staging (unstaged change).
#   create_dirty <relative_path>
create_dirty() {
  local path="$1"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "original" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add "$path"
  git -C "$TEST_REPO" commit -q -m "add $path"
  echo "modified" > "$TEST_REPO/$path"
}
