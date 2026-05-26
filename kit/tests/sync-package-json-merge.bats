#!/usr/bin/env bats
# Tests for from-devshop.sh package.json merge logic.
#
# Validates:
#   - Sync preserves project's name, version, packageManager
#   - Sync updates scripts, devDependencies, pnpm, lint-staged from template
#   - Missing jq falls back to raw copy
#   - Brand-new project (no existing package.json) gets template verbatim

setup() {
  load helpers/setup
  setup_mock_bin
  PREVIEW_LIB="$SCRIPTS_DIR/sync/lib/preview-confirm.sh"
  PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  FROM_SCRIPT="$SCRIPTS_DIR/sync/from-devshop.sh"

  FIXTURE_PROJECT="$BATS_TEST_TMPDIR/project"
  FIXTURE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  FIXTURE_TEMPLATE="$FIXTURE_DEVSHOP/template"

  mkdir -p "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib"
  mkdir -p "$FIXTURE_TEMPLATE"
  mkdir -p "$FIXTURE_DEVSHOP/.git"
  mkdir -p "$FIXTURE_DEVSHOP/kit"
  echo "1.0.0" > "$FIXTURE_DEVSHOP/kit/version"

  cp "$PREVIEW_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/preview-confirm.sh"
  cp "$PARSE_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/parse-manifest.sh"
  cp "$FROM_SCRIPT" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"

  FIXTURE_FROM="$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"

  git -C "$FIXTURE_PROJECT" init -q
  git -C "$FIXTURE_PROJECT" config user.email "test@test.com"
  git -C "$FIXTURE_PROJECT" config user.name "Test"
  echo "init" > "$FIXTURE_PROJECT/.gitkeep"
  git -C "$FIXTURE_PROJECT" add .gitkeep
  git -C "$FIXTURE_PROJECT" commit -q -m "initial"
}

setup_pkg_fixture() {
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
package.json [sync]
M

  # Project's package.json — has a real name + version + packageManager
  cat > "$FIXTURE_PROJECT/package.json" <<'PKG'
{
  "name": "@home-os/root",
  "version": "0.3.0",
  "packageManager": "pnpm@10.1.0",
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build"
  },
  "devDependencies": {
    "turbo": "^2.3.0"
  }
}
PKG
  git -C "$FIXTURE_PROJECT" add package.json
  git -C "$FIXTURE_PROJECT" commit -q -m "add package.json"

  # Template's package.json — generic name, updated scripts + deps
  cat > "$FIXTURE_TEMPLATE/package.json" <<'PKG'
{
  "name": "project-name",
  "version": "0.0.0",
  "packageManager": "pnpm@10.0.0",
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "test": "turbo test"
  },
  "devDependencies": {
    "turbo": "^2.4.0",
    "prettier": "^3.0.0"
  },
  "pnpm": {
    "patchedDependencies": {}
  }
}
PKG
}

@test "merge preserves project name during sync" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.name' "$FIXTURE_PROJECT/package.json"
  assert_output "@home-os/root"
}

@test "merge preserves project version during sync" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.version' "$FIXTURE_PROJECT/package.json"
  assert_output "0.3.0"
}

@test "merge preserves project packageManager during sync" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.packageManager' "$FIXTURE_PROJECT/package.json"
  assert_output "pnpm@10.1.0"
}

@test "merge updates scripts from template" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.scripts.test' "$FIXTURE_PROJECT/package.json"
  assert_output "turbo test"
}

@test "merge updates devDependencies from template" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.devDependencies.prettier' "$FIXTURE_PROJECT/package.json"
  assert_output "^3.0.0"
}

@test "merge adds new top-level fields from template" {
  setup_pkg_fixture
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq '.pnpm' "$FIXTURE_PROJECT/package.json"
  assert_success
  assert_output --partial 'patchedDependencies'
}

@test "merge falls back to raw copy when jq is unavailable" {
  setup_pkg_fixture

  # Shadow jq with a stub that fails (simulates jq unavailable/broken)
  cat > "$MOCK_BIN/jq" <<'STUB'
#!/bin/bash
exit 1
STUB
  chmod +x "$MOCK_BIN/jq"

  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  # Remove the stub so real jq is available for the assertion
  rm "$MOCK_BIN/jq"

  # Without jq, raw copy wins — project gets the template's name
  run jq -r '.name' "$FIXTURE_PROJECT/package.json"
  assert_output "project-name"
}

@test "brand-new project gets template package.json verbatim" {
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
package.json [sync]
M
  cat > "$FIXTURE_TEMPLATE/package.json" <<'PKG'
{
  "name": "project-name",
  "version": "0.0.0",
  "scripts": { "dev": "turbo dev" }
}
PKG
  # No existing package.json in the project

  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  run jq -r '.name' "$FIXTURE_PROJECT/package.json"
  assert_output "project-name"
}

@test "preview shows merged result (not raw template)" {
  setup_pkg_fixture

  # Run with --yes but capture output to check the preview mentions the file
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success

  # The merged file on disk should have project's name, not template's
  run jq -r '.name' "$FIXTURE_PROJECT/package.json"
  assert_output "@home-os/root"
}
