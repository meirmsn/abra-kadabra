#!/usr/bin/env bats
# Tests for the Claude branch guard in .husky/pre-commit.
# The guard blocks Claude (CLAUDECODE=1) from committing on main/master.
# Humans (CLAUDECODE unset) pass through unconditionally.

setup() {
  load helpers/setup
  create_test_repo

  # The guard logic lives inline in .husky/pre-commit and can't be sourced
  # independently (it calls lint-staged, gitleaks, bats). We test a small
  # standalone script that contains the identical logic. The parity test
  # (last test) verifies the guard block in .husky/pre-commit matches this
  # fixture — catches drift.
  GUARD_FIXTURE="$BATS_TEST_TMPDIR/guard-fixture.sh"
  cat > "$GUARD_FIXTURE" <<'GUARD'
#!/usr/bin/env bash
_current_branch=$(git branch --show-current 2>/dev/null || echo "")

# Claude branch guard — backstop for PreToolUse check-branch-not-main.sh.
# Closes TOCTOU race: parallel sessions can switch branches between PreToolUse
# "allow" and git commit execution. This runs inside git's commit — no race.
# Humans commit on main unconditionally (release.sh needs this).
if [ "${CLAUDECODE:-}" = "1" ]; then
  if [ "$_current_branch" = "main" ] || [ "$_current_branch" = "master" ]; then
    echo "BLOCKED: Claude commit on main/master (husky branch guard)." >&2
    echo "" >&2
    echo "A parallel session may have switched branches. Create a branch first:" >&2
    echo "  git checkout -b <type>/<topic>" >&2
    exit 1
  fi
fi
GUARD
  chmod +x "$GUARD_FIXTURE"

  # Path to the production .husky/pre-commit (worktree copy)
  HUSKY_PRECOMMIT="$(cd "$TESTS_DIR/../.." && pwd)/.husky/pre-commit"
}

# Helper: run the guard fixture in the test repo with given env.
run_guard() {
  run env -C "$TEST_REPO" "$@" bash "$GUARD_FIXTURE"
}

# --- Claude x branch matrix ---

@test "blocks Claude commit on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  run_guard CLAUDECODE=1
  assert_failure 1
  assert_output --partial "BLOCKED"
  assert_output --partial "husky branch guard"
}

@test "blocks Claude commit on master" {
  git -C "$TEST_REPO" branch -m master 2>/dev/null || true
  run_guard CLAUDECODE=1
  assert_failure 1
  assert_output --partial "BLOCKED"
}

@test "allows Claude commit on feature branch" {
  git -C "$TEST_REPO" checkout -q -b feat/x
  run_guard CLAUDECODE=1
  assert_success
}

@test "allows human commit on main" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  run env -u CLAUDECODE -C "$TEST_REPO" bash "$GUARD_FIXTURE"
  assert_success
}

@test "allows human commit on feature branch" {
  git -C "$TEST_REPO" checkout -q -b feat/x
  run env -u CLAUDECODE -C "$TEST_REPO" bash "$GUARD_FIXTURE"
  assert_success
}

# --- Edge cases ---

@test "allows when CLAUDECODE is empty string" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  run_guard CLAUDECODE=""
  assert_success
}

@test "allows release.sh pattern: parent CLAUDECODE=1, override CLAUDECODE= on commit" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  # Simulate: Claude session (CLAUDECODE=1) runs release.sh which does
  # CLAUDECODE= git commit — the override clears it for the subprocess.
  run env -C "$TEST_REPO" CLAUDECODE=1 bash -c 'CLAUDECODE= bash '"$GUARD_FIXTURE"
  assert_success
}

@test "allows when CLAUDECODE is 0" {
  git -C "$TEST_REPO" branch -m main 2>/dev/null || true
  run_guard CLAUDECODE=0
  assert_success
}

# --- Parity test: guard logic in .husky/pre-commit matches test fixture ---

@test "parity: guard block in .husky/pre-commit matches test fixture" {
  # Extract the guard block from the production .husky/pre-commit.
  # The block starts with '_current_branch=' and ends with the 'fi' that
  # closes the CLAUDECODE check (the line before '# Recreate devshop symlinks').
  local production_guard
  production_guard=$(sed -n '/^_current_branch=.*git branch --show-current/,/^fi$/p' "$HUSKY_PRECOMMIT" | head -16)

  # Extract the same block from the test fixture (everything after the shebang).
  local fixture_guard
  fixture_guard=$(tail -n +2 "$GUARD_FIXTURE")

  # Compare — if these drift, someone edited the production guard without
  # updating the test fixture (or vice versa).
  [ "$production_guard" = "$fixture_guard" ]
}
