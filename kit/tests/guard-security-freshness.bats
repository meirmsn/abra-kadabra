#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-security-files-freshness.sh
# Verifies settings.json and .dcg.toml are present, are copies (not symlinks), and match source

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/commit-hooks/check-security-files-freshness.sh"

  # Create a fake devshop with source security files
  FAKE_DS="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$FAKE_DS/.claude" "$FAKE_DS/kit/scripts/sync/lib"
  echo '{"permissions": {"allow": ["Read"]}}' > "$FAKE_DS/.claude/settings.json"
  echo '[packs]' > "$FAKE_DS/.dcg.toml"
  # Copy normalize script + detect-mode lib so the freshness check can source/call them.
  cp "$SCRIPTS_DIR/sync/normalize-devshop-paths.sh" "$FAKE_DS/kit/scripts/sync/"
  cp "$SCRIPTS_DIR/sync/lib/detect-mode.sh" "$FAKE_DS/kit/scripts/sync/lib/"

  # Create a fake workspace
  FAKE_WS="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$FAKE_WS/.claude"
}

run_check() {
  run bash -c "DEVSHOP='$FAKE_DS' WS='$FAKE_WS' bash '$CHECK'"
}

# --- Happy path ---

@test "passes when both files are fresh copies" {
  # Copy source files (simulate init-devshop.sh)
  # settings.json needs path normalization applied (kit/ → .devshopkit/)
  bash "$FAKE_DS/kit/scripts/sync/normalize-devshop-paths.sh" < "$FAKE_DS/.claude/settings.json" > "$FAKE_WS/.claude/settings.json"
  cp "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  run_check
  assert_success
}

@test "passes when devshop not mounted" {
  # No devshop dir
  run bash -c "DEVSHOP='$BATS_TEST_TMPDIR/nonexistent' WS='$FAKE_WS' bash '$CHECK'"
  assert_success
}

@test "skips in devshop-self mode (workspace has real kit/ dir)" {
  # Devshop-self mode: $WS/kit exists as a real directory (in projects it's
  # always a symlink). Without the skip, the script would compare devshop's
  # own infra against template/ and report spurious staleness — the bug
  # surfaced in the devshop devcontainer's session-start warnings.
  mkdir -p "$FAKE_WS/kit"
  # Stale state that WOULD fail without the short-circuit: missing settings.json.
  rm -f "$FAKE_WS/.claude/settings.json"
  run_check
  assert_success
  refute_output --partial "MISSING"
  refute_output --partial "stale"
}

@test "still blocks when workspace kit/ is a symlink (project mode)" {
  # Project mode: $WS/kit is a symlink to /devshop/kit. Skip MUST NOT fire —
  # projects need the freshness check to run. Pair with the previous test
  # to lock down the symlink-vs-realdir distinction.
  ln -s "$FAKE_DS/kit" "$FAKE_WS/kit"
  rm -f "$FAKE_WS/.claude/settings.json"
  cp "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  run_check
  assert_failure 1
  assert_output --partial "MISSING"
}

# --- settings.json ---

@test "blocks when settings.json is missing" {
  cp "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  # Don't create settings.json
  run_check
  assert_failure 1
  assert_output --partial "settings.json"
  assert_output --partial "MISSING"
}

@test "blocks when settings.json is a symlink" {
  ln -s "$FAKE_DS/.claude/settings.json" "$FAKE_WS/.claude/settings.json"
  cp "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  run_check
  assert_failure 1
  assert_output --partial "SYMLINK"
}

@test "blocks when settings.json is stale" {
  echo '{"permissions": {"allow": ["Read", "Write"]}}' > "$FAKE_WS/.claude/settings.json"
  cp "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  run_check
  assert_failure 1
  assert_output --partial "stale"
}

# --- .dcg.toml ---

@test "blocks when .dcg.toml is missing" {
  bash "$FAKE_DS/kit/scripts/sync/normalize-devshop-paths.sh" < "$FAKE_DS/.claude/settings.json" > "$FAKE_WS/.claude/settings.json"
  # Don't create .dcg.toml
  run_check
  assert_failure 1
  assert_output --partial "dcg.toml"
  assert_output --partial "MISSING"
}

@test "blocks when .dcg.toml is a symlink" {
  bash "$FAKE_DS/kit/scripts/sync/normalize-devshop-paths.sh" < "$FAKE_DS/.claude/settings.json" > "$FAKE_WS/.claude/settings.json"
  ln -s "$FAKE_DS/.dcg.toml" "$FAKE_WS/.dcg.toml"
  run_check
  assert_failure 1
  assert_output --partial "SYMLINK"
}

@test "blocks when .dcg.toml is stale" {
  bash "$FAKE_DS/kit/scripts/sync/normalize-devshop-paths.sh" < "$FAKE_DS/.claude/settings.json" > "$FAKE_WS/.claude/settings.json"
  echo '[different]' > "$FAKE_WS/.dcg.toml"
  run_check
  assert_failure 1
  assert_output --partial "stale"
}

# --- Both failing ---

@test "reports both files when both are missing" {
  run_check
  assert_failure 1
  assert_output --partial "settings.json"
  assert_output --partial "dcg.toml"
}

@test "shows fix command on failure" {
  run_check
  assert_failure 1
  assert_output --partial "init-devshop.sh"
}
