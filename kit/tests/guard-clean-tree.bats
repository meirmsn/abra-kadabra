#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-clean-tree.sh
# Pre-commit guard: blocks if working tree has untracked/unstaged files

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  CHECK="$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
}

# Helper: run the check inside the test repo with adversarial-review mocked
run_check() {
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'"
}

run_check_with_review() {
  local review_result="$1"
  mock_adversarial_review "$review_result"
  local wrapper="$BATS_TEST_TMPDIR/check-wrapper.sh"
  sed "s|bash \"\$SCRIPT_DIR/../adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$CHECK" > "$wrapper"
  chmod +x "$wrapper"
  run bash -c "cd '$TEST_REPO' && bash '$wrapper'"
}

# --- Clean tree ---

@test "passes on clean tree" {
  run_check
  assert_success
}

@test "passes when only staged changes exist" {
  stage_file "new-file.txt" "staged content"
  run_check
  assert_success
}

# --- Dirty tree ---

@test "blocks on untracked file" {
  create_untracked "forgotten.txt"
  run_check
  assert_failure 1
  assert_output --partial "forgotten.txt"
}

@test "blocks on unstaged modification" {
  create_dirty "src/index.ts"
  run_check
  assert_failure 1
  assert_output --partial "src/index.ts"
}

@test "blocks on both untracked and unstaged" {
  create_untracked "untracked.txt"
  create_dirty "modified.ts"
  run_check
  assert_failure 1
  assert_output --partial "untracked.txt"
  assert_output --partial "modified.ts"
}

# --- Stash detection ---

@test "blocks on stashed changes for current branch" {
  # Create a stash on the current branch
  echo "stash me" > "$TEST_REPO/temp.txt"
  git -C "$TEST_REPO" add temp.txt
  git -C "$TEST_REPO" stash push -m "test stash"
  run_check
  assert_failure 1
  assert_output --partial "Stashed changes"
}

@test "passes when stash is on a different branch" {
  # Create stash, then switch branches
  git -C "$TEST_REPO" checkout -b feature
  echo "stash me" > "$TEST_REPO/temp.txt"
  git -C "$TEST_REPO" add temp.txt
  git -C "$TEST_REPO" stash push -m "feature stash"
  git -C "$TEST_REPO" checkout master 2>/dev/null || git -C "$TEST_REPO" checkout main 2>/dev/null
  run_check
  assert_success
}

# --- Bypass with adversarial review ---

@test "passes with bypass reason when adversarial review accepts" {
  create_untracked "leftover.txt"
  git -C "$TEST_REPO" config devshop.dirtyTreeReason "intentionally committing a subset"
  run_check_with_review PASS
  assert_success
  assert_output --partial "adversarial review accepted"
}

@test "blocks with bypass reason when adversarial review rejects" {
  create_untracked "leftover.txt"
  git -C "$TEST_REPO" config devshop.dirtyTreeReason "meh whatever"
  run_check_with_review FAIL
  assert_failure 1
  assert_output --partial "REJECTED"
}
