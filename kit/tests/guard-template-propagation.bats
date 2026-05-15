#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-template-propagation.sh
# Soft nudge — emits one-line reminders for staged files that have [sync]-tagged
# devshop template counterparts. Never blocks (always exit 0).

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-template-propagation.sh"

  # Build a minimal mock devshop tree with manifest + template counterparts.
  MOCK_DEVSHOP="$BATS_TEST_TMPDIR/mock-devshop"
  mkdir -p "$MOCK_DEVSHOP/kit/scripts/sync/lib"
  mkdir -p "$MOCK_DEVSHOP/template/.github/workflows"
  mkdir -p "$MOCK_DEVSHOP/template/.devcontainer"
  cp "$SCRIPTS_DIR/sync/lib/parse-manifest.sh" "$MOCK_DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"

  cat > "$MOCK_DEVSHOP/kit/manifest.txt" <<'EOF'
turbo.json [sync]
.github/workflows/ [sync]
.devcontainer/ [sync]
!.devcontainer/.env
CLAUDE.md [scaffold-once]
.devshopkit [symlink]
EOF

  # Real template counterparts (the check verifies these exist before nudging)
  echo "{}" > "$MOCK_DEVSHOP/template/turbo.json"
  echo "name: ci" > "$MOCK_DEVSHOP/template/.github/workflows/ci.yml"
  echo "image: devcontainer" > "$MOCK_DEVSHOP/template/.devcontainer/devcontainer.json"
  echo "# scaffold-once" > "$MOCK_DEVSHOP/template/CLAUDE.md"

  export DEVSHOP="$MOCK_DEVSHOP"
  cd "$TEST_REPO"
}

run_script() {
  run bash "$SCRIPT"
}

# --- exits cleanly + always returns 0 ---

@test "exits 0 silently when nothing is staged" {
  run_script
  assert_success
  refute_output --partial "📦"
}

@test "exits 0 when devshop is not mounted (DEVSHOP points at nonexistent path)" {
  export DEVSHOP="$BATS_TEST_TMPDIR/nonexistent-devshop"
  stage_file turbo.json "{}"
  run_script
  assert_success
  refute_output --partial "📦"
}

@test "exits 0 when staged file has no manifest counterpart" {
  stage_file apps/web/app/page.tsx "export default function Page() { return null }"
  run_script
  assert_success
  refute_output --partial "📦"
}

# --- nudge fires on [sync] entries ---

@test "fires nudge on staged [sync] file (turbo.json)" {
  stage_file turbo.json '{"x": 1}'
  run_script
  assert_success
  assert_output --partial "📦"
  assert_output --partial "turbo.json"
  assert_output --partial "to-devshop.sh"
}

@test "fires nudge on staged file under [sync] directory (.github/workflows/ci.yml)" {
  stage_file .github/workflows/ci.yml "name: ci-modified"
  run_script
  assert_success
  assert_output --partial "📦"
  assert_output --partial ".github/workflows/ci.yml"
}

@test "fires nudge on staged file under nested [sync] directory (.devcontainer/devcontainer.json)" {
  stage_file .devcontainer/devcontainer.json '{"image": "x"}'
  run_script
  assert_success
  assert_output --partial "📦"
  assert_output --partial ".devcontainer/devcontainer.json"
}

@test "fires one nudge line per matched file when multiple staged" {
  stage_file turbo.json "{}"
  stage_file .github/workflows/ci.yml "name: ci"
  run_script
  assert_success
  assert_output --partial "turbo.json"
  assert_output --partial ".github/workflows/ci.yml"
}

# --- non-firing classes ---

@test "does NOT nudge on [scaffold-once] entries (CLAUDE.md)" {
  stage_file CLAUDE.md "# Project guidance"
  run_script
  assert_success
  refute_output --partial "📦"
}

@test "does NOT nudge on [symlink] entries (.devshopkit)" {
  stage_file .devshopkit "symlink-stub"
  run_script
  assert_success
  refute_output --partial "📦"
}

@test "does NOT nudge on !-excluded path (.devcontainer/.env)" {
  stage_file .devcontainer/.env "SECRET=value"
  run_script
  assert_success
  refute_output --partial "📦"
}

@test "does NOT nudge when [sync] directory matches but template counterpart is missing" {
  # Stage a file under .github/workflows/ that exists in manifest as [sync] (the dir)
  # but the specific file has no template counterpart.
  stage_file .github/workflows/release.yml "name: release"
  run_script
  assert_success
  refute_output --partial "📦"
}

# --- structural ---

@test "always exits 0 (never blocks) even when manifest is malformed" {
  echo "garbage-line-with-no-tag" > "$MOCK_DEVSHOP/kit/manifest.txt"
  stage_file turbo.json "{}"
  run_script
  assert_success
}

@test "exits 0 when manifest file is missing" {
  rm -f "$MOCK_DEVSHOP/kit/manifest.txt"
  stage_file turbo.json "{}"
  run_script
  assert_success
  refute_output --partial "📦"
}
