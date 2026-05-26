#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-bats-devshop.sh
# Pre-commit gate that runs bats tests affected by the commit's changed files.
#
# Uses synthetic .bats test files (pass/fail stubs) to exercise the script's
# logic without running the real test suite.

setup() {
  load helpers/setup
  CHECK="$SCRIPTS_DIR/commit-hooks/check-bats-devshop.sh"

  # Create a synthetic devshop-like directory for the check to operate on
  FAKE_DEVSHOP="$BATS_TEST_TMPDIR/fake-devshop"
  mkdir -p "$FAKE_DEVSHOP/kit/tests" "$FAKE_DEVSHOP/kit/scripts/commit-hooks"

  # Symlink the bats-core runner so the check can invoke bats (avoids slow cp -a)
  ln -s "$TESTS_DIR/lib" "$FAKE_DEVSHOP/kit/tests/lib"

  # Create a passing synthetic test
  cat > "$FAKE_DEVSHOP/kit/tests/example-pass.bats" <<'EOF'
#!/usr/bin/env bats
@test "always passes" { true; }
EOF

  # Create a failing synthetic test
  cat > "$FAKE_DEVSHOP/kit/tests/example-fail.bats" <<'EOF'
#!/usr/bin/env bats
@test "always fails" { false; }
EOF

  # Create a script file referenced by the passing test
  echo '# check-bats-devshop.sh' > "$FAKE_DEVSHOP/kit/scripts/commit-hooks/check-bats-devshop.sh"

  # Create a test that references a script name
  cat > "$FAKE_DEVSHOP/kit/tests/guard-widget.bats" <<'EOF'
#!/usr/bin/env bats
# Tests for widget.sh
@test "widget passes" { true; }
EOF
  echo '# widget.sh' > "$FAKE_DEVSHOP/kit/scripts/widget.sh"

  # Create a test that references a script but always fails
  cat > "$FAKE_DEVSHOP/kit/tests/guard-broken.bats" <<'EOF'
#!/usr/bin/env bats
# Tests for broken-script.sh
@test "broken fails" { false; }
EOF
  echo '# broken-script.sh' > "$FAKE_DEVSHOP/kit/scripts/broken-script.sh"

  # Create test repo for git operations
  create_test_repo
}

# Run the check script with DEVSHOP pointed at the fake devshop.
# $1: newline-separated list of staged file paths (simulated git diff output)
run_check() {
  local changed="$1"
  local wrapper="$BATS_TEST_TMPDIR/wrapper.sh"
  # Replace git rev-parse with a static value and inject CHANGED_FILES
  cat > "$wrapper" <<WRAP
#!/bin/bash
set -euo pipefail
export DEVSHOP="$FAKE_DEVSHOP"
cd "$TEST_REPO"
# Inline the script with CHANGED_FILES overridden
TESTS_DIR="\$DEVSHOP/kit/tests"
BATS="\$DEVSHOP/kit/tests/lib/bats-core/bin/bats"
[ -d "\$TESTS_DIR" ] || exit 0
[ -x "\$BATS" ] || exit 0
GIT_ROOT="$FAKE_DEVSHOP"
CHANGED_FILES="$changed"
[ -z "\$CHANGED_FILES" ] && exit 0
BATS_FILES=()
collect() { BATS_FILES+=("\$1"); }
$(sed -n '/^# 1\. Changed \.bats/,$ p' "$CHECK")
WRAP
  run bash "$wrapper"
}

@test "exits 0 when CHANGED_FILES is empty" {
  run_check ""
  assert_success
  refute_output --partial "affected bats"
}

@test "exits 0 when only non-script/non-test files changed" {
  run_check "README.md"
  assert_success
  refute_output --partial "affected bats"
}

@test "runs and passes for a changed passing .bats file" {
  run_check "kit/tests/example-pass.bats"
  assert_success
  assert_output --partial "affected bats file"
  assert_output --partial "example-pass"
}

@test "blocks when a changed .bats file fails" {
  run_check "kit/tests/example-fail.bats"
  assert_failure
  assert_output --partial "BLOCKING"
  assert_output --partial "Bats tests failed"
}

@test "runs bats for a changed script via grep-reference lookup" {
  run_check "kit/scripts/widget.sh"
  assert_success
  assert_output --partial "affected bats file"
  assert_output --partial "guard-widget"
}

@test "blocks when a changed script's test fails" {
  run_check "kit/scripts/broken-script.sh"
  assert_failure
  assert_output --partial "BLOCKING"
}

@test "exits 0 when changed script has no referencing test" {
  run_check "kit/scripts/orphan.sh"
  assert_success
  refute_output --partial "affected bats"
}

@test "bypass message references batsSkipReason" {
  # Simulate the bypass check inline — the full script reads git config which
  # we can't easily stub, so verify the bypass message path via string match.
  run_check "kit/tests/example-fail.bats"
  assert_failure
  assert_output --partial 'devshop.batsSkipReason='
}
