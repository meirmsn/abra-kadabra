#!/usr/bin/env bats
# Tests for release.sh pre-release test coverage gate.
# The gate runs on every release (once the first tag exists), builds the full
# diff + test inventory since the last tag, and delegates the judgment to the
# adversarial reviewer. PASS/FAIL comes entirely from the reviewer's verdict.

setup() {
  load helpers/setup
  setup_mock_bin
  RELEASE="$SCRIPTS_DIR/release.sh"

  # Create a devshop-like repo with version and tags
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts" "$TEST_REPO/kit/tests" "$TEST_REPO/kit/docs"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  echo "1.0.0" > "$TEST_REPO/kit/version"
  echo "# CHANGELOG" > "$TEST_REPO/kit/docs/CHANGELOG.md"
  echo '#!/bin/bash
echo "guard logic"' > "$TEST_REPO/kit/scripts/guard.sh"
  echo '@test "guard blocks on dirty tree" { true; }' > "$TEST_REPO/kit/tests/guard.bats"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "initial"
  git -C "$TEST_REPO" tag -a v1.0.0 -m "v1.0.0"
}

# Run the full release.sh gate section with mocked adversarial-review.sh.
# Creates a wrapper that replaces SCRIPT_DIR so the mock is used.
run_release_gate() {
  local repo="$1" review_result="$2"
  mock_adversarial_review "$review_result"

  # Create a release.sh wrapper that uses our mock adversarial-review.sh
  # and skips everything after the gate (version bump, tag, push)
  local wrapper="$BATS_TEST_TMPDIR/release-gate-wrapper.sh"
  # Extract just the gate section from release.sh, stop before version bump
  sed -n '/^# --- Pre-release gate/,/^if \[ -n "\$ARG_BUMP" \]/p' "$RELEASE" | head -n -1 > "$wrapper"
  # Replace SCRIPT_DIR to use our mock
  sed -i "s|SCRIPT_DIR=.*|SCRIPT_DIR=\"$MOCK_BIN\"|" "$wrapper"
  # Add shebang and setup
  local full_wrapper="$BATS_TEST_TMPDIR/release-gate-full.sh"
  cat > "$full_wrapper" <<WRAP
#!/bin/bash
set -euo pipefail
CURRENT_VERSION=\$(cat kit/version | tr -d '[:space:]')
LAST_TAG="v\$CURRENT_VERSION"
SCRIPT_DIR="$MOCK_BIN"
$(cat "$wrapper")
echo "GATE_PASSED"
WRAP
  chmod +x "$full_wrapper"
  run bash -c "cd '$repo' && bash '$full_wrapper'"
}

# === Gate runs on every release regardless of file type ===

@test "release gate: runs on docs-only release" {
  echo "# updated" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -q -m "docs only"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

@test "release gate: runs on config-only change (devcontainer.json)" {
  mkdir -p "$TEST_REPO/.devcontainer"
  echo '{"containerEnv": {"NEW_VAR": "1"}}' > "$TEST_REPO/.devcontainer/devcontainer.json"
  git -C "$TEST_REPO" add .devcontainer/devcontainer.json
  git -C "$TEST_REPO" commit -q -m "add devcontainer env var"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

@test "release gate: runs on script change with tests" {
  echo '#!/bin/bash
echo "modified guard"' > "$TEST_REPO/kit/scripts/guard.sh"
  echo '@test "guard handles new flag" { true; }' >> "$TEST_REPO/kit/tests/guard.bats"
  git -C "$TEST_REPO" add kit/scripts/guard.sh kit/tests/guard.bats
  git -C "$TEST_REPO" commit -q -m "script and test updated together"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

@test "release gate: runs on script change without tests" {
  echo '#!/bin/bash
echo "modified guard"' > "$TEST_REPO/kit/scripts/guard.sh"
  git -C "$TEST_REPO" add kit/scripts/guard.sh
  git -C "$TEST_REPO" commit -q -m "modify script"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

@test "release gate: runs on hook change" {
  mkdir -p "$TEST_REPO/kit/hooks"
  echo '#!/bin/bash
echo "hook logic"' > "$TEST_REPO/kit/hooks/pre-commit.sh"
  git -C "$TEST_REPO" add kit/hooks/pre-commit.sh
  git -C "$TEST_REPO" commit -q -m "add hook"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

# === Gate respects adversarial verdict ===

@test "release gate: passes when adversarial review accepts" {
  echo '#!/bin/bash
echo "modified"' > "$TEST_REPO/kit/scripts/guard.sh"
  git -C "$TEST_REPO" add kit/scripts/guard.sh
  git -C "$TEST_REPO" commit -q -m "modify"

  run_release_gate "$TEST_REPO" PASS
  assert_success
  assert_output --partial "GATE_PASSED"
}

@test "release gate: blocks when adversarial review rejects" {
  echo '#!/bin/bash
echo "modified"' > "$TEST_REPO/kit/scripts/guard.sh"
  git -C "$TEST_REPO" add kit/scripts/guard.sh
  git -C "$TEST_REPO" commit -q -m "modify"

  run_release_gate "$TEST_REPO" FAIL
  assert_failure 1
  assert_output --partial "FAILED"
}
