#!/usr/bin/env bats
# Tests for kit/scripts/propagation-entry.sh and the PROPAGATION.md integration
# across release.sh, from-devshop.sh, and session-start.sh.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../scripts"
  PROP_SCRIPT="$SCRIPTS_DIR/propagation-entry.sh"
  RELEASE_SCRIPT="$SCRIPTS_DIR/release.sh"
  FROM_SCRIPT="$SCRIPTS_DIR/sync/from-devshop.sh"
  SESSION_SCRIPT="$SCRIPTS_DIR/session-start.sh"
  PROP_FILE="$BATS_TEST_DIRNAME/../docs/PROPAGATION.md"
}

# --- Structural invariants ---

@test "PROPAGATION.md exists" {
  [ -f "$PROP_FILE" ]
}

@test "propagation-entry.sh exists and is valid bash" {
  [ -f "$PROP_SCRIPT" ]
  bash -n "$PROP_SCRIPT"
}

@test "release.sh calls propagation-entry.sh" {
  grep -q 'propagation-entry.sh' "$RELEASE_SCRIPT"
}

@test "release.sh adds PROPAGATION.md to git add" {
  grep -q 'PROPAGATION_PATH' "$RELEASE_SCRIPT"
}

@test "release.sh rollback includes PROPAGATION.md" {
  grep -q 'PROPAGATION' "$RELEASE_SCRIPT"
  grep -A2 'rolling back' "$RELEASE_SCRIPT" | grep -q 'PROPAGATION_PATH'
}

@test "from-devshop.sh prints propagation hint on version change" {
  grep -q 'PROPAGATION.md' "$FROM_SCRIPT"
  grep -q 'OLD_DEVSHOP_VERSION' "$FROM_SCRIPT"
}

@test "session-start.sh drift message points to /ak-sync-from-devshop skill" {
  # The skill wraps from-devshop.sh and handles PROPAGATION.md review internally,
  # so the drift line names the skill instead of the raw script + manual doc read.
  grep -q '/ak-sync-from-devshop' "$SESSION_SCRIPT"
}

# --- propagation-entry.sh behavioral tests ---

setup_git_fixture() {
  FIXTURE_DIR="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIXTURE_DIR"
  git -C "$FIXTURE_DIR" init -q
  git -C "$FIXTURE_DIR" config user.email "test@test.com"
  git -C "$FIXTURE_DIR" config user.name "Test"
  echo "init" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "initial"
  git -C "$FIXTURE_DIR" tag -a v1.0.0 -m "v1.0.0"

  FIXTURE_PROP="$FIXTURE_DIR/PROPAGATION.md"
  cat > "$FIXTURE_PROP" <<'EOF'
# Propagation Log

Per-version manual steps for existing projects after `from-devshop.sh`.

EOF
}

@test "extracts Existing projects block from commit" {
  setup_git_fixture

  echo "change1" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "feat(sync): add version tracking" -m "**Existing projects:** no migration needed — runs automatically on rebuild.

---

## Squashed commits"

  run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' '1.1.0' 'v1.0.0' '$FIXTURE_PROP'"
  assert_success

  run cat "$FIXTURE_PROP"
  [[ "$output" == *"## v1.1.0"* ]]
  [[ "$output" == *"feat(sync): add version tracking"* ]]
  [[ "$output" == *"no migration needed"* ]]
}

@test "writes (no manual steps) when no blocks found" {
  setup_git_fixture

  echo "change1" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "chore: update docs"

  run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' '1.1.0' 'v1.0.0' '$FIXTURE_PROP'"
  assert_success

  run cat "$FIXTURE_PROP"
  [[ "$output" == *"## v1.1.0"* ]]
  [[ "$output" == *"(no manual steps)"* ]]
}

@test "inserts newest version at top" {
  setup_git_fixture

  # Seed an existing v1.1.0 section
  cat > "$FIXTURE_PROP" <<'EOF'
# Propagation Log

Per-version manual steps for existing projects after `from-devshop.sh`.

## v1.1.0

(no manual steps)
EOF

  echo "change2" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "feat: new thing" -m "**Existing projects:** run db:migrate after sync."
  git -C "$FIXTURE_DIR" tag -a v1.1.0 -m "v1.1.0"

  run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' '1.2.0' 'v1.1.0' '$FIXTURE_PROP'"
  assert_success

  run cat "$FIXTURE_PROP"
  # v1.2.0 should appear before v1.1.0
  local v12_line v11_line
  v12_line=$(echo "$output" | grep -n "## v1.2.0" | head -1 | cut -d: -f1)
  v11_line=$(echo "$output" | grep -n "## v1.1.0" | head -1 | cut -d: -f1)
  [ "$v12_line" -lt "$v11_line" ]
}

@test "handles multi-line Existing projects block" {
  setup_git_fixture

  echo "change" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "feat: big change" -m "**Existing projects:** run these steps:
1. Rebuild the container
2. Run from-devshop.sh
3. Check .env for new keys

---"

  run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' '1.1.0' 'v1.0.0' '$FIXTURE_PROP'"
  assert_success

  run cat "$FIXTURE_PROP"
  [[ "$output" == *"run these steps:"* ]]
  [[ "$output" == *"Rebuild the container"* ]]
  [[ "$output" == *"Check .env for new keys"* ]]
}

@test "handles multiple commits with mixed blocks" {
  setup_git_fixture

  echo "c1" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "feat: with block" -m "**Existing projects:** rebuild container.

---"

  echo "c2" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "chore: no block"

  echo "c3" > "$FIXTURE_DIR/file.txt"
  git -C "$FIXTURE_DIR" add .
  git -C "$FIXTURE_DIR" commit -q -m "fix: another block" -m "**Existing projects:** update .env with NEW_KEY=value.

Key details:"

  run bash -c "cd '$FIXTURE_DIR' && bash '$PROP_SCRIPT' '1.1.0' 'v1.0.0' '$FIXTURE_PROP'"
  assert_success

  run cat "$FIXTURE_PROP"
  [[ "$output" == *"feat: with block"* ]]
  [[ "$output" == *"rebuild container"* ]]
  [[ "$output" == *"fix: another block"* ]]
  [[ "$output" == *"update .env with NEW_KEY=value"* ]]
  # The chore commit should NOT appear (no block)
  [[ "$output" != *"chore: no block"* ]]
}

# --- from-devshop.sh propagation hint ---

setup_sync_fixture() {
  FIXTURE_PROJECT="$BATS_TEST_TMPDIR/project"
  FIXTURE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  FIXTURE_TEMPLATE="$FIXTURE_DEVSHOP/template"

  mkdir -p "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib"
  mkdir -p "$FIXTURE_TEMPLATE"
  mkdir -p "$FIXTURE_DEVSHOP/.git"
  mkdir -p "$FIXTURE_DEVSHOP/kit/docs"
  echo "2.0.0" > "$FIXTURE_DEVSHOP/kit/version"
  echo "# Propagation" > "$FIXTURE_DEVSHOP/kit/docs/PROPAGATION.md"

  local PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  local PREVIEW_LIB="$SCRIPTS_DIR/sync/lib/preview-confirm.sh"
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

@test "release.sh supports --no-push flag" {
  grep -q 'no-push\|NO_PUSH' "$RELEASE_SCRIPT"
}

@test "release.sh --no-push exits before commit" {
  # Match the actual CLAUDECODE= git invocation (not echo instructions)
  local no_push_exit commit_line
  no_push_exit=$(sed -n '/NO_PUSH.*=.*true.*then/,/^fi$/{ /exit 0/= }' "$RELEASE_SCRIPT" | head -1)
  commit_line=$(grep -n '^CLAUDECODE= git' "$RELEASE_SCRIPT" | grep -v echo | head -1 | cut -d: -f1)
  [ -n "$no_push_exit" ]
  [ -n "$commit_line" ]
  [ "$no_push_exit" -lt "$commit_line" ]
}

@test "release.sh supports --finalize flag" {
  grep -q 'finalize\|FINALIZE' "$RELEASE_SCRIPT"
}

@test "release.sh --finalize re-stages PROPAGATION.md" {
  grep -A20 'FINALIZE.*true' "$RELEASE_SCRIPT" | grep -q 'git add.*PROPAGATION'
}

@test "release.sh --finalize commits with CLAUDECODE unset" {
  sed -n '/^if.*FINALIZE.*true/,/^fi$/p' "$RELEASE_SCRIPT" | grep -q 'CLAUDECODE= git'
}

@test "release.sh --finalize guards against missing staged files" {
  sed -n '/^if.*FINALIZE.*true/,/^fi$/p' "$RELEASE_SCRIPT" | grep -q 'run --no-push first'
}

@test "from-devshop.sh prints propagation hint when version changes" {
  setup_sync_fixture
  echo "1.0.0" > "$FIXTURE_PROJECT/.devshop-version"

  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh" --yes
  assert_success
  [[ "$output" == *"PROPAGATION.md"* ]]
  [[ "$output" == *"v1.0.0"* ]]
}

@test "from-devshop.sh skips hint when no old version (bootstrap)" {
  setup_sync_fixture
  # No .devshop-version file

  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh" --yes
  assert_success
  [[ "$output" != *"PROPAGATION.md"* ]]
}

@test "from-devshop.sh skips hint when version unchanged" {
  setup_sync_fixture
  echo "2.0.0" > "$FIXTURE_PROJECT/.devshop-version"

  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh" --yes
  assert_success
  [[ "$output" != *"PROPAGATION.md"* ]]
}
