#!/usr/bin/env bats
# Tests for .husky/pre-push (devshop) and template/.husky/pre-push (project).
# Project version blocks direct push to main with no bypass; both versions
# block dirty trees with adversarial review.

setup() {
  load helpers/setup
  setup_mock_bin
  DEVSHOP_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
  REPO_ROOT="$(cd "$DEVSHOP_ROOT/.." && pwd)"
  # Wrap each hook so the absolute /devshop/kit/scripts/adversarial-review.sh
  # path points at the BATS mock instead. Pattern mirrors guard-clean-tree.bats.
  PROJECT_PRE_PUSH="$BATS_TEST_TMPDIR/project-pre-push"
  DEVSHOP_PRE_PUSH="$BATS_TEST_TMPDIR/devshop-pre-push"
  sed "s|bash /devshop/kit/scripts/adversarial-review.sh|bash $MOCK_BIN/adversarial-review.sh|" \
    "$REPO_ROOT/template/.husky/pre-push" > "$PROJECT_PRE_PUSH"
  sed "s|bash /devshop/kit/scripts/adversarial-review.sh|bash $MOCK_BIN/adversarial-review.sh|" \
    "$REPO_ROOT/.husky/pre-push" > "$DEVSHOP_PRE_PUSH"
  chmod +x "$PROJECT_PRE_PUSH" "$DEVSHOP_PRE_PUSH"
  create_test_repo
  # Mock gh: returns empty (no PR found) by default
  create_stub gh ""
}

# --- Project pre-push: refs-based main-block ---

@test "project pre-push: blocks push to refs/heads/main with no bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PROJECT_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/main 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/main" ]]
  [[ "$output" =~ "No bypass available" ]]
}

@test "project pre-push: blocks push to refs/heads/master with no bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PROJECT_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/master 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/master" ]]
}

@test "project pre-push: blocks rename-style push (HEAD:main) from feature branch" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PROJECT_PRE_PUSH" origin <<< "HEAD abc123 refs/heads/main 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/main" ]]
}

@test "project pre-push: allows push to feature branch (clean tree, no PR)" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  mock_adversarial_review PASS
  run bash "$PROJECT_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x 0000000000000000000000000000000000000000"
  [ "$status" -eq 0 ]
}

@test "project pre-push: short-circuits on detached HEAD" {
  cd "$TEST_REPO" && git checkout -q --detach HEAD 2>/dev/null
  run bash "$PROJECT_PRE_PUSH" origin <<< ""
  [ "$status" -eq 0 ]
}

@test "project pre-push: short-circuits on branch deletion (zero local sha)" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PROJECT_PRE_PUSH" origin <<< "(delete) 0000000000000000000000000000000000000000 refs/heads/old-branch abc123"
  [ "$status" -eq 0 ]
}

# --- Project pre-push: dirty-tree check ---

@test "project pre-push: blocks dirty tree without bypass when adversarial rejects" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review FAIL
  run bash "$PROJECT_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "local state is not clean" ]]
}

@test "project pre-push: passes dirty tree when adversarial accepts the bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review PASS
  run bash "$PROJECT_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
}

# --- Devshop pre-push: still short-circuits on main ---

@test "devshop pre-push: short-circuits on push from main (release.sh territory)" {
  cd "$TEST_REPO"
  # Already on master/main from create_test_repo's initial commit; just run.
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
    git checkout -q -b main 2>/dev/null || git checkout -q main
  fi
  run bash "$DEVSHOP_PRE_PUSH" origin <<< "refs/heads/main abc123 refs/heads/main def456"
  [ "$status" -eq 0 ]
}

@test "devshop pre-push: blocks dirty tree when adversarial rejects" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review FAIL
  run bash "$DEVSHOP_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "local state is not clean" ]]
}

@test "devshop pre-push: passes clean tree on feature branch" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  mock_adversarial_review PASS
  run bash "$DEVSHOP_PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
}
