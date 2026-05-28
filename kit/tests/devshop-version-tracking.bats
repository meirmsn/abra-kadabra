#!/usr/bin/env bats
# Tests for .devshop-version tracking — from-devshop.sh writes the file after
# sync, session-start.sh shows drift in the briefing.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../scripts"
  PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  PREVIEW_LIB="$SCRIPTS_DIR/sync/lib/preview-confirm.sh"
  FROM_SCRIPT="$SCRIPTS_DIR/sync/from-devshop.sh"
  SESSION_SCRIPT="$SCRIPTS_DIR/session-start.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../manifest.txt"
}

# --- Structural invariants ---

@test "manifest lists .devshop-version as scaffold-once" {
  run grep '\.devshop-version \[scaffold-once\]' "$MANIFEST"
  [ "$status" -eq 0 ]
}

@test "template/.devshop-version exists and is valid semver" {
  local tpl="$BATS_TEST_DIRNAME/../../template/.devshop-version"
  [ -f "$tpl" ]
  run cat "$tpl"
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "template/.devshop-version matches kit/version" {
  local tpl="$(cat "$BATS_TEST_DIRNAME/../../template/.devshop-version" | tr -d '[:space:]')"
  local kit="$(cat "$BATS_TEST_DIRNAME/../../kit/version" | tr -d '[:space:]')"
  [ "$tpl" = "$kit" ]
}

# --- from-devshop.sh writes .devshop-version ---

setup_sync_fixture() {
  FIXTURE_PROJECT="$BATS_TEST_TMPDIR/project"
  FIXTURE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  FIXTURE_TEMPLATE="$FIXTURE_DEVSHOP/template"

  mkdir -p "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib"
  mkdir -p "$FIXTURE_TEMPLATE"
  mkdir -p "$FIXTURE_DEVSHOP/.git"
  mkdir -p "$FIXTURE_DEVSHOP/kit"
  echo "2.0.0" > "$FIXTURE_DEVSHOP/kit/version"

  cp "$PREVIEW_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/preview-confirm.sh"
  cp "$PARSE_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/parse-manifest.sh"
  cp "$FROM_SCRIPT" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"

  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
turbo.json [sync]
M
  echo '{"old": true}' > "$FIXTURE_PROJECT/turbo.json"
  echo '{"new": true}' > "$FIXTURE_TEMPLATE/turbo.json"

  git -C "$FIXTURE_PROJECT" init -q
  git -C "$FIXTURE_PROJECT" config user.email "test@test.com"
  git -C "$FIXTURE_PROJECT" config user.name "Test"
  echo "init" > "$FIXTURE_PROJECT/.gitkeep"
  git -C "$FIXTURE_PROJECT" add .
  git -C "$FIXTURE_PROJECT" commit -q -m "initial"
}

@test "from-devshop.sh writes .devshop-version after sync" {
  setup_sync_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh" --yes
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_PROJECT/.devshop-version" ]
  run cat "$FIXTURE_PROJECT/.devshop-version"
  [[ "$output" =~ 2\.0\.0 ]]
}

@test "from-devshop.sh success message includes version" {
  setup_sync_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"Synced to devshop v2.0.0"* ]]
}

# --- session-start.sh drift detection ---

# session-start.sh reads from $ROOT and /devshop/kit/version. We can't easily
# run the full script (needs git repo, gh, etc.), so we extract the real drift
# block from session-start.sh and run it in isolation — substituting the
# hardcoded /devshop/kit/version read for the test's version file. Running the
# real block (rather than an inline copy) means these behavioral tests track
# the script's actual drift message; a copy would silently fossilize when the
# message changes. Codified by Audit 1 (2026-05-27): the prior inline copy
# asserted `run: bash .devshopkit/scripts/sync/from-devshop.sh` while the
# script had already switched to `run /ak-sync-from-devshop`, and all tests
# stayed green against the stale copy.

run_drift_check() {
  local root="$1"
  local devshop_version_file="$2"
  local block
  block=$(awk '/^# --- Devshop version drift check/{f=1} f{print} f&&/^fi$/{exit}' "$SESSION_SCRIPT")
  [ -n "$block" ] || { echo "could not extract drift block from session-start.sh"; return 1; }
  block=$(echo "$block" | sed "s#/devshop/kit/version#$devshop_version_file#")
  IS_DEVSHOP=false ROOT="$root" bash -c "
    $block
    echo \"\$DEVSHOP_DRIFT\"
  "
}

@test "drift check: shows version mismatch" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root"
  echo "1.30.0" > "$root/.devshop-version"
  local ver_file="$BATS_TEST_TMPDIR/version"
  echo "1.33.0" > "$ver_file"

  run run_drift_check "$root" "$ver_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"synced at v1.30.0, devshop is v1.33.0"* ]]
  [[ "$output" == *"run /ak-sync-from-devshop"* ]]
}

@test "drift check: shows bootstrap message when file missing" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root"
  # no .devshop-version
  local ver_file="$BATS_TEST_TMPDIR/version"
  echo "1.33.0" > "$ver_file"

  run run_drift_check "$root" "$ver_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no .devshop-version found"* ]]
  [[ "$output" == *"run /ak-sync-from-devshop"* ]]
}

@test "drift check: silent when versions match" {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root"
  echo "1.33.0" > "$root/.devshop-version"
  local ver_file="$BATS_TEST_TMPDIR/version"
  echo "1.33.0" > "$ver_file"

  run run_drift_check "$root" "$ver_file"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "session-start.sh contains the drift check block" {
  grep -q 'DEVSHOP_DRIFT' "$SESSION_SCRIPT"
  grep -q '\.devshop-version' "$SESSION_SCRIPT"
  grep -q 'no \.devshop-version found' "$SESSION_SCRIPT"
}

@test "session-start.sh drift check is project-sessions only" {
  run grep -A2 'DEVSHOP_DRIFT=""' "$SESSION_SCRIPT"
  [[ "$output" == *'IS_DEVSHOP" != true'* ]]
}

@test "session-start.sh briefing includes Sync: line" {
  grep -q 'Sync:.*DEVSHOP_DRIFT' "$SESSION_SCRIPT"
}
