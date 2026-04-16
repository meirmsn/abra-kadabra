#!/usr/bin/env bats
# Tests for kit/scripts/changelog-entry.sh
# Appends versioned entries to a CHANGELOG.md file

setup() {
  load helpers/setup
  CHANGELOG_SCRIPT="$SCRIPTS_DIR/changelog-entry.sh"
  CHANGELOG="$BATS_TEST_TMPDIR/CHANGELOG.md"

  # Create a minimal changelog with existing entries
  cat > "$CHANGELOG" <<'CHANGEFILE'
# Changelog

Auto-appended by changelog-entry.sh.

## v1.3.4 (2026-04-01)

- fix: something old

## v1.3.3 (2026-03-28)

- chore: older thing
CHANGEFILE
}

@test "inserts entry before first version heading" {
  run bash "$CHANGELOG_SCRIPT" "1.3.5" "- feat: new thing" "$CHANGELOG"
  assert_success
  assert_output --partial "Changelog entry added: v1.3.5"

  # New entry should appear before v1.3.4
  run grep -n "## v" "$CHANGELOG"
  assert_line --index 0 --partial "v1.3.5"
  assert_line --index 1 --partial "v1.3.4"
}

@test "entry contains date" {
  bash "$CHANGELOG_SCRIPT" "1.3.5" "- feat: new thing" "$CHANGELOG"
  local today
  today=$(date +%Y-%m-%d)
  run grep "v1.3.5" "$CHANGELOG"
  assert_output --partial "$today"
}

@test "preserves existing entries" {
  bash "$CHANGELOG_SCRIPT" "1.3.5" "- feat: new thing" "$CHANGELOG"
  run grep "something old" "$CHANGELOG"
  assert_success
  run grep "older thing" "$CHANGELOG"
  assert_success
}

@test "fails with missing changelog file" {
  run bash "$CHANGELOG_SCRIPT" "1.0.0" "test" "/nonexistent/CHANGELOG.md"
  assert_failure 1
  assert_output --partial "not found"
}

@test "fails with missing version argument" {
  run bash "$CHANGELOG_SCRIPT"
  assert_failure
}
