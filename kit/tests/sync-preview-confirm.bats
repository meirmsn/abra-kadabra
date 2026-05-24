#!/usr/bin/env bats
# Tests for kit/scripts/sync/lib/preview-confirm.sh — the show-first-confirm
# library used by from-devshop.sh and to-devshop.sh.
#
# Validates:
#   - --yes flag bypasses the prompt and applies
#   - N / empty response aborts without touching the working tree
#   - Dry-run preview shows the same file set the apply pass would touch
#   - No-changes case exits cleanly

setup() {
  load helpers/setup
  setup_mock_bin
  PREVIEW_LIB="$SCRIPTS_DIR/sync/lib/preview-confirm.sh"
  PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  FROM_SCRIPT="$SCRIPTS_DIR/sync/from-devshop.sh"
  TO_SCRIPT="$SCRIPTS_DIR/sync/to-devshop.sh"

  # Build a minimal project + devshop fixture
  FIXTURE_PROJECT="$BATS_TEST_TMPDIR/project"
  FIXTURE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  FIXTURE_TEMPLATE="$FIXTURE_DEVSHOP/template"

  mkdir -p "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib"
  mkdir -p "$FIXTURE_TEMPLATE"
  mkdir -p "$FIXTURE_DEVSHOP/.git"
  mkdir -p "$FIXTURE_DEVSHOP/kit"
  echo "1.0.0" > "$FIXTURE_DEVSHOP/kit/version"

  # Copy scripts + libraries into the fixture's .devshopkit path so
  # PROJECT_ROOT (3 levels up from SCRIPT_DIR) resolves to FIXTURE_PROJECT.
  cp "$PREVIEW_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/preview-confirm.sh"
  cp "$PARSE_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/parse-manifest.sh"
  cp "$FROM_SCRIPT" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"
  cp "$TO_SCRIPT" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/to-devshop.sh"

  # Paths used by integration tests — invoke via fixture's .devshopkit
  FIXTURE_FROM="$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"
  FIXTURE_TO="$FIXTURE_PROJECT/.devshopkit/scripts/sync/to-devshop.sh"

  # Init git in the project fixture so git diff works
  git -C "$FIXTURE_PROJECT" init -q
  git -C "$FIXTURE_PROJECT" config user.email "test@test.com"
  git -C "$FIXTURE_PROJECT" config user.name "Test"
  echo "init" > "$FIXTURE_PROJECT/.gitkeep"
  git -C "$FIXTURE_PROJECT" add .gitkeep
  git -C "$FIXTURE_PROJECT" commit -q -m "initial"
}

# Helper: create a manifest + files for a basic sync scenario
setup_sync_fixture() {
  # Manifest with one [sync] file
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
turbo.json [sync]
M

  # Current project state
  echo '{"pipeline": {"build": {}}}' > "$FIXTURE_PROJECT/turbo.json"
  git -C "$FIXTURE_PROJECT" add turbo.json
  git -C "$FIXTURE_PROJECT" commit -q -m "add turbo"

  # Devshop template has a newer version
  echo '{"pipeline": {"build": {}, "test": {}}}' > "$FIXTURE_TEMPLATE/turbo.json"
}

# Helper: create a manifest + files where devshop matches project (no changes)
setup_no_change_fixture() {
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
turbo.json [sync]
M
  echo '{"same": true}' > "$FIXTURE_PROJECT/turbo.json"
  echo '{"same": true}' > "$FIXTURE_TEMPLATE/turbo.json"
  git -C "$FIXTURE_PROJECT" add turbo.json
  git -C "$FIXTURE_PROJECT" commit -q -m "add turbo"
}

# Helper: create a multi-file fixture with dir sync
setup_dir_sync_fixture() {
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
.devcontainer/ [sync]
.devcontainer/Dockerfile [locked]
!.devcontainer/.env
M
  mkdir -p "$FIXTURE_PROJECT/.devcontainer"
  echo "old-compose" > "$FIXTURE_PROJECT/.devcontainer/compose.yml"
  echo "SECRET=keepme" > "$FIXTURE_PROJECT/.devcontainer/.env"
  echo "FROM node:20" > "$FIXTURE_PROJECT/.devcontainer/Dockerfile"
  git -C "$FIXTURE_PROJECT" add .devcontainer/compose.yml .devcontainer/Dockerfile
  git -C "$FIXTURE_PROJECT" commit -q -m "add devcontainer"

  mkdir -p "$FIXTURE_TEMPLATE/.devcontainer"
  echo "new-compose" > "$FIXTURE_TEMPLATE/.devcontainer/compose.yml"
  echo "FROM node:22" > "$FIXTURE_TEMPLATE/.devcontainer/Dockerfile"
}

# ---------------------------------------------------------------------------
# preview-confirm library unit tests
# ---------------------------------------------------------------------------

@test "preview_confirm_parse_args extracts --yes flag" {
  run bash -c "
    source '$PREVIEW_LIB'
    preview_confirm_parse_args --yes --bump patch
    echo \"AUTO_YES=\$_PC_AUTO_YES\"
    echo \"REMAINING=\${PREVIEW_CONFIRM_REMAINING_ARGS[*]}\"
  "
  assert_success
  assert_line "AUTO_YES=true"
  assert_line "REMAINING=--bump patch"
}

@test "preview_confirm_parse_args extracts -y flag" {
  run bash -c "
    source '$PREVIEW_LIB'
    preview_confirm_parse_args -y --seed
    echo \"AUTO_YES=\$_PC_AUTO_YES\"
    echo \"REMAINING=\${PREVIEW_CONFIRM_REMAINING_ARGS[*]}\"
  "
  assert_success
  assert_line "AUTO_YES=true"
  assert_line "REMAINING=--seed"
}

@test "preview_confirm_parse_args passes through when no --yes" {
  run bash -c "
    source '$PREVIEW_LIB'
    preview_confirm_parse_args --bump minor
    echo \"AUTO_YES=\$_PC_AUTO_YES\"
    echo \"REMAINING=\${PREVIEW_CONFIRM_REMAINING_ARGS[*]}\"
  "
  assert_success
  assert_line "AUTO_YES=false"
  assert_line "REMAINING=--bump minor"
}

@test "preview_confirm_show_and_ask reports no changes when files match" {
  run bash -c "
    source '$PREVIEW_LIB'
    preview_confirm_init
    mkdir -p \"\$_PC_STAGING_DIR/proposed\"
    echo 'same' > \"\$_PC_STAGING_DIR/proposed/file.txt\"
    # Create matching target
    TARGET=\$(mktemp -d)
    echo 'same' > \"\$TARGET/file.txt\"
    preview_confirm_show_and_ask \"\$TARGET\"
  "
  assert_output --partial "No changes to apply"
  # Return code 1 = abort (no changes to apply)
  assert_failure
}

@test "preview_confirm_show_and_ask with --yes auto-confirms" {
  run bash -c "
    source '$PREVIEW_LIB'
    _PC_AUTO_YES=true
    preview_confirm_init
    mkdir -p \"\$_PC_STAGING_DIR/proposed\"
    echo 'new content' > \"\$_PC_STAGING_DIR/proposed/file.txt\"
    TARGET=\$(mktemp -d)
    echo 'old content' > \"\$TARGET/file.txt\"
    preview_confirm_show_and_ask \"\$TARGET\"
  "
  assert_success
  assert_output --partial "1 file(s) would change"
  assert_output --partial "auto-confirming"
}

# ---------------------------------------------------------------------------
# from-devshop.sh integration tests
# ---------------------------------------------------------------------------

@test "from-devshop.sh --yes applies changes without prompt" {
  setup_sync_fixture

  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    SCRIPT_DIR='$FIXTURE_PROJECT/.devshopkit/scripts/sync' \
    bash '$FIXTURE_FROM' --yes <<< ''
  " 3<<< ""
  # The script reads from /dev/tty, not stdin — --yes bypasses that.
  # It should show the preview and auto-confirm.
  assert_success
  assert_output --partial "auto-confirming"
  assert_output --partial "Changes applied"

  # Verify the file was actually updated
  run cat "$FIXTURE_PROJECT/turbo.json"
  assert_output '{"pipeline": {"build": {}, "test": {}}}'
}

@test "from-devshop.sh --yes with no changes exits cleanly" {
  setup_no_change_fixture

  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_FROM' --yes
  "
  assert_success
  assert_output --partial "No changes to apply"

  # Verify the file was NOT touched
  run cat "$FIXTURE_PROJECT/turbo.json"
  assert_output '{"same": true}'
}

@test "from-devshop.sh dry-run does not modify working tree before confirmation" {
  setup_sync_fixture

  # Capture the file content before the script runs (we'll abort via empty stdin)
  local before
  before=$(cat "$FIXTURE_PROJECT/turbo.json")

  # Pipe 'n' to /dev/tty is not possible in test, but --yes=false (default)
  # with no tty will cause read to fail and default to abort.
  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_FROM' < /dev/null 2>&1
  "
  # Should have shown the preview
  assert_output --partial "would change"
  assert_output --partial "Aborted"

  # Verify the file was NOT modified (the critical assertion)
  local after
  after=$(cat "$FIXTURE_PROJECT/turbo.json")
  [ "$before" = "$after" ]
}

@test "from-devshop.sh preview matches apply set (no drift)" {
  setup_sync_fixture

  # Run with --yes and capture the preview output
  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_FROM' --yes 2>&1
  "
  assert_success
  # Preview said 1 file would change
  assert_output --partial "1 file(s) would change"
  # Apply actually changed the file
  assert_output --partial "Changes applied"
  # The file in the working tree matches the proposed content
  run cat "$FIXTURE_PROJECT/turbo.json"
  assert_output '{"pipeline": {"build": {}, "test": {}}}'
}

@test "from-devshop.sh respects three-source exclude model in preview" {
  setup_dir_sync_fixture

  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_FROM' --yes 2>&1
  "
  assert_success
  # compose.yml should change (it's [sync])
  assert_output --partial "would change"
  # .env should be untouched (! exclusion)
  run cat "$FIXTURE_PROJECT/.devcontainer/.env"
  assert_output "SECRET=keepme"
}

# ---------------------------------------------------------------------------
# to-devshop.sh integration tests
# ---------------------------------------------------------------------------

@test "to-devshop.sh --yes applies changes without prompt" {
  setup_sync_fixture
  # Reverse the fixture: project has newer content, template has older
  echo '{"pipeline": {"build": {}, "test": {}, "lint": {}}}' > "$FIXTURE_PROJECT/turbo.json"
  echo '{"pipeline": {"build": {}}}' > "$FIXTURE_TEMPLATE/turbo.json"
  echo "1.0.0" > "$FIXTURE_PROJECT/.devshopkit/version"

  # to-devshop.sh needs a changelog-entry.sh — stub it
  cat > "$FIXTURE_PROJECT/.devshopkit/scripts/sync/changelog-entry.sh" <<'STUB'
#!/bin/bash
exit 0
STUB
  chmod +x "$FIXTURE_PROJECT/.devshopkit/scripts/sync/changelog-entry.sh"

  # Init git in devshop fixture
  git -C "$FIXTURE_DEVSHOP" init -q
  git -C "$FIXTURE_DEVSHOP" config user.email "test@test.com"
  git -C "$FIXTURE_DEVSHOP" config user.name "Test"
  echo "init" > "$FIXTURE_DEVSHOP/.gitkeep"
  git -C "$FIXTURE_DEVSHOP" add -A
  git -C "$FIXTURE_DEVSHOP" commit -q -m "initial"

  run bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_TO' --yes --bump patch 2>&1
  "
  assert_success
  assert_output --partial "auto-confirming"
  assert_output --partial "Applying changes"

  # Verify the template was updated
  run cat "$FIXTURE_TEMPLATE/turbo.json"
  assert_output '{"pipeline": {"build": {}, "test": {}, "lint": {}}}'
}

# ---------------------------------------------------------------------------
# Structural: scripts source the preview-confirm library
# ---------------------------------------------------------------------------

@test "from-devshop.sh sources preview-confirm.sh" {
  run grep -q 'source.*preview-confirm.sh' "$FROM_SCRIPT"
  assert_success
}

@test "to-devshop.sh sources preview-confirm.sh" {
  run grep -q 'source.*preview-confirm.sh' "$TO_SCRIPT"
  assert_success
}

@test "from-devshop.sh calls preview_confirm_show_and_ask" {
  run grep -q 'preview_confirm_show_and_ask' "$FROM_SCRIPT"
  assert_success
}

@test "to-devshop.sh calls preview_confirm_show_and_ask" {
  run grep -q 'preview_confirm_show_and_ask' "$TO_SCRIPT"
  assert_success
}

@test "from-devshop.sh does NOT apply before preview (no cp/rsync before show_and_ask)" {
  # The apply block must come AFTER preview_confirm_show_and_ask, not before.
  # Extract line numbers: show_and_ask should appear before the apply rsync/cp.
  local show_line apply_line
  show_line=$(grep -n 'preview_confirm_show_and_ask' "$FROM_SCRIPT" | head -1 | cut -d: -f1)
  apply_line=$(grep -n 'Applying changes' "$FROM_SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$show_line" ] && [ -n "$apply_line" ]
  [ "$show_line" -lt "$apply_line" ]
}

@test "to-devshop.sh does NOT apply before preview (no cp/rsync before show_and_ask)" {
  local show_line apply_line
  show_line=$(grep -n 'preview_confirm_show_and_ask' "$TO_SCRIPT" | head -1 | cut -d: -f1)
  apply_line=$(grep -n 'Applying changes' "$TO_SCRIPT" | head -1 | cut -d: -f1)
  [ -n "$show_line" ] && [ -n "$apply_line" ]
  [ "$show_line" -lt "$apply_line" ]
}
