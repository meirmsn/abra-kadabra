#!/usr/bin/env bats
# Goal 1 (Separation): devshop and project are independent
# Verifies: symlink creation, mixed commit detection, path normalization

setup() {
  load helpers/setup
  setup_mock_bin
}

# --- Symlink creation ---

@test "separation: create-devshop-symlinks creates expected symlinks" {
  # Set up a minimal workspace and devshop structure
  local ws="$BATS_TEST_TMPDIR/workspace"
  local ds="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$ws" "$ds/kit" "$ds/.claude/skills/devshop" "$ds/.claude/commands"

  run bash -c "
    export DEVSHOP='$ds' WS='$ws'
    bash '$SCRIPTS_DIR/create-devshop-symlinks.sh'
  "
  assert_success

  # Verify key symlinks exist
  [ -L "$ws/.devshopkit" ]
  [ -L "$ws/.claude/skills/devshop" ]
  [ -L "$ws/.claude/commands" ]
  [ -L "$ws/.hooks/pre-commit" ]
}

@test "separation: symlink creation is idempotent" {
  local ws="$BATS_TEST_TMPDIR/workspace"
  local ds="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$ws" "$ds/kit" "$ds/.claude/skills/devshop" "$ds/.claude/commands"

  # Run twice — second run should not fail
  bash -c "DEVSHOP='$ds' WS='$ws' bash '$SCRIPTS_DIR/create-devshop-symlinks.sh'"
  run bash -c "DEVSHOP='$ds' WS='$ws' bash '$SCRIPTS_DIR/create-devshop-symlinks.sh'"
  assert_success
}

@test "separation: skips when workspace IS the devshop" {
  local ds="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$ds/kit" "$ds/.claude/skills"

  # When WS has a real kit/ dir, it should skip
  run bash -c "DEVSHOP='$ds' WS='$ds' bash '$SCRIPTS_DIR/create-devshop-symlinks.sh'"
  assert_success
  # .devshopkit should NOT be created (we're in the devshop itself)
  [ ! -L "$ds/.devshopkit" ]
}

# --- Mixed commit detection ---

@test "separation: prevents mixing devshop + project files in one commit" {
  TEST_REPO="$BATS_TEST_TMPDIR/project"
  mkdir -p "$TEST_REPO/.claude/skills" "$TEST_REPO/src"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "init" > "$TEST_REPO/.gitkeep"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"

  local wrapper="$BATS_TEST_TMPDIR/guard-wrapper.sh"
  cp "$SCRIPTS_DIR/devshop-commit-guard.sh" "$wrapper"
  sed -i "s|bash \"\$SCRIPT_DIR/adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$wrapper"
  sed -i "s|GIT_ROOT=\$(git rev-parse --show-toplevel.*|GIT_ROOT=\"/workspace\"|" "$wrapper"
  sed -i 's|if \[ -n "\$OTHER_REPO" \] \&\& \[ -d "\$OTHER_REPO/\.git" \]|if false|' "$wrapper"
  chmod +x "$wrapper"

  stage_file ".claude/skills/new-skill.md" "skill"
  stage_file "src/index.ts" "code"
  run bash -c "cd '$TEST_REPO' && bash '$wrapper'"
  assert_failure 1
  assert_output --partial "Mixed commit"
}

# --- Project works without devshop ---

@test "separation: pre-commit hook no-ops when devshop not mounted" {
  # Simulate a standalone project with no devshop
  local standalone="$BATS_TEST_TMPDIR/standalone"
  mkdir -p "$standalone/.husky"
  git -C "$standalone" init -q
  git -C "$standalone" config user.email "test@test.com"
  git -C "$standalone" config user.name "Test"
  echo "init" > "$standalone/.gitkeep"
  git -C "$standalone" add .
  git -C "$standalone" commit -q -m "initial"

  # Copy the husky pre-commit but point DEVSHOP to nonexistent path
  local hook="$standalone/.husky/pre-commit"
  cat > "$hook" <<'HOOK'
# Symlink recovery — no-ops without devshop
[ ! -L .devshopkit ] && [ -d /nonexistent/devshop/kit ] && bash /nonexistent/devshop/kit/scripts/create-devshop-symlinks.sh 2>/dev/null || true

# Kit tests — no-ops without kit/tests/
if [ -d kit/tests ] && [ -x kit/tests/lib/bats-core/bin/bats ]; then
  kit/tests/lib/bats-core/bin/bats kit/tests/ --print-output-on-failure
fi

# Devshop guards — no-ops without devshop
if [ -x /nonexistent/devshop/kit/hooks/pre-commit.sh ]; then bash /nonexistent/devshop/kit/hooks/pre-commit.sh; fi
HOOK
  chmod +x "$hook"

  # Stage a file and verify the hook runs without errors
  echo "code" > "$standalone/index.ts"
  git -C "$standalone" add index.ts
  run bash -c "cd '$standalone' && bash .husky/pre-commit"
  assert_success
}

# --- Path normalization ---

@test "separation: paths normalized for project context" {
  result=$(echo "kit/scripts/guard.sh" | bash "$SCRIPTS_DIR/normalize-devshop-paths.sh")
  assert_equal "$result" ".devshopkit/scripts/guard.sh"
}

@test "separation: absolute devshop paths preserved" {
  result=$(echo "/devshop/kit/hooks/pre-commit.sh" | bash "$SCRIPTS_DIR/normalize-devshop-paths.sh")
  assert_equal "$result" "/devshop/kit/hooks/pre-commit.sh"
}
