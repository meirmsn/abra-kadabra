#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-not-test-identity.sh
# Pre-commit guard that blocks commits stamped with the fixture identity
# (Test <test@test.com>) in a real bind-mounted repo (/devshop or /workspace),
# while staying silent in ephemeral /tmp fixture repos (where test@test.com is
# the canonical identity).

setup() {
  load helpers/setup
  # When this suite runs INSIDE a real pre-commit hook (check-bats-devshop),
  # git exports GIT_DIR / GIT_INDEX_FILE / GIT_AUTHOR_* pointing at the real
  # repo being committed. Those leak into the test's `git var` / `git rev-parse`
  # calls and break isolation (the guard would read /devshop's identity instead
  # of the temp repo's). Clear them so each test resolves against its own REPO.
  # (The guard is correct in production — there GIT_DIR IS the real repo.)
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX \
        GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  CHECK="$SCRIPTS_DIR/commit-hooks/check-not-test-identity.sh"
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
}

# Run the guard from inside REPO with REAL_ROOTS overridden to whatever is passed.
run_guard() {
  local real_roots="$1"
  run bash -c "cd '$REPO' && IDENTITY_GUARD_REAL_ROOTS='$real_roots' bash '$CHECK'"
}

@test "blocks when identity is the test fixture and repo is a real root" {
  git -C "$REPO" config user.name "Test"
  git -C "$REPO" config user.email "test@test.com"
  run_guard "$REPO"
  assert_failure
  assert_output --partial "test fixture"
}

@test "passes when identity is a real one in a real root" {
  git -C "$REPO" config user.name "meirmsn"
  git -C "$REPO" config user.email "meirmsn@gmail.com"
  run_guard "$REPO"
  assert_success
}

@test "skips (passes) fixture identity when repo is NOT a real root" {
  git -C "$REPO" config user.name "Test"
  git -C "$REPO" config user.email "test@test.com"
  # Default real-roots — REPO (a /tmp path) is not among them.
  run_guard "/devshop /workspace"
  assert_success
}

@test "stays silent when no identity is set at all (lets git error fire)" {
  git -C "$REPO" config --remove-section user 2>/dev/null || true
  run_guard "$REPO"
  assert_success
}
