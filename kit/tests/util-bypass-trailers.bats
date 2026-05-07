#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/append-bypass-trailers.sh
# prepare-commit-msg hook: appends Git trailers when Layer 1 bypass flags are present.
# See kit/ROADMAP.md § PR-C § B for the bypass-trailer mechanic.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/append-bypass-trailers.sh"
  cd "$TEST_REPO"
  MSG_FILE="$BATS_TEST_TMPDIR/COMMIT_EDITMSG"
}

write_msg() {
  echo "$1" > "$MSG_FILE"
}

run_hook() {
  local source="${1:-}"
  run bash "$SCRIPT" "$MSG_FILE" "$source"
}

# --- Trailer emission ---

@test "no flags set → message unchanged, no trailers appended" {
  write_msg "feat: do thing"
  run_hook
  assert_success
  run cat "$MSG_FILE"
  refute_output --partial "Docs-Coverage-Bypass:"
  refute_output --partial "Tests-Coverage-Bypass:"
}

@test "docsCoverageReason set → Docs-Coverage-Bypass trailer appended" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "deferring CLAUDE.md update to end of feature"
  write_msg "feat: add wiring

Body."
  run_hook
  assert_success
  run cat "$MSG_FILE"
  assert_output --partial "Docs-Coverage-Bypass: deferring CLAUDE.md update to end of feature"
}

@test "testsCoverageReason set → Tests-Coverage-Bypass trailer appended" {
  git -C "$TEST_REPO" config devshop.testsCoverageReason "type re-export, transitively covered"
  write_msg "feat: add foo"
  run_hook
  assert_success
  run cat "$MSG_FILE"
  assert_output --partial "Tests-Coverage-Bypass: type re-export, transitively covered"
}

@test "both flags set → both trailers appended (one per key)" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  git -C "$TEST_REPO" config devshop.testsCoverageReason "test deferred"
  write_msg "feat: add thing"
  run_hook
  assert_success
  run cat "$MSG_FILE"
  assert_output --partial "Docs-Coverage-Bypass: doc deferred"
  assert_output --partial "Tests-Coverage-Bypass: test deferred"
}

# --- Idempotence (re-running collapses dup trailers) ---

@test "running twice does not duplicate trailers" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  write_msg "feat: thing"
  run_hook
  assert_success
  run_hook
  assert_success
  local count
  count=$(grep -c '^Docs-Coverage-Bypass:' "$MSG_FILE" 2>/dev/null || echo 0)
  [ "$count" = "1" ]
}

# --- Skip on commit-source amend / merge / squash ---

@test "skips when commit-source = merge" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  write_msg "Merge branch foo"
  run_hook merge
  assert_success
  run cat "$MSG_FILE"
  refute_output --partial "Docs-Coverage-Bypass:"
}

@test "skips when commit-source = squash" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  write_msg "Squashed commit message"
  run_hook squash
  assert_success
  run cat "$MSG_FILE"
  refute_output --partial "Docs-Coverage-Bypass:"
}

@test "skips when commit-source = commit (amend)" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  write_msg "feat: amended"
  run_hook commit
  assert_success
  run cat "$MSG_FILE"
  refute_output --partial "Docs-Coverage-Bypass:"
}

# --- Body / round-trip preservation ---

@test "trailer appended after multi-line body, body preserved verbatim" {
  git -C "$TEST_REPO" config devshop.docsCoverageReason "doc deferred"
  write_msg "feat: thing

This is the body line 1.
This is the body line 2.

Co-Authored-By: Existing <existing@example.com>"
  run_hook
  assert_success
  run cat "$MSG_FILE"
  assert_output --partial "feat: thing"
  assert_output --partial "This is the body line 1."
  assert_output --partial "This is the body line 2."
  assert_output --partial "Co-Authored-By: Existing <existing@example.com>"
  assert_output --partial "Docs-Coverage-Bypass: doc deferred"
}

# --- Edge: missing args / files ---

@test "missing message file path → exit 0, no-op" {
  run bash "$SCRIPT"
  assert_success
}

@test "non-existent message file → exit 0, no-op" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nope.txt"
  assert_success
}

@test "outside a git repo → exit 0, no-op" {
  local outside="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$outside"
  echo "feat: thing" > "$outside/MSG"
  run bash -c "cd '$outside' && bash '$SCRIPT' '$outside/MSG'"
  assert_success
}
