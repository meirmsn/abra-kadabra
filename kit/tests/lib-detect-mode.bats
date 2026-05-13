#!/usr/bin/env bats
# Tests for kit/scripts/sync/lib/detect-mode.sh
# Verifies is_devshop_self_mode() honors DEVSHOP_FORCE_MODE override and falls
# back to filesystem detection (kit/ is a real dir, not a symlink) otherwise.

setup() {
  load helpers/setup
  LIB="$SCRIPTS_DIR/sync/lib/detect-mode.sh"

  # Fake roots for filesystem-based detection.
  FAKE_DEVSHOP="$BATS_TEST_TMPDIR/fake-devshop"
  FAKE_PROJECT="$BATS_TEST_TMPDIR/fake-project"
  mkdir -p "$FAKE_DEVSHOP/kit"      # devshop shape: kit/ is a real dir
  mkdir -p "$FAKE_PROJECT"
  ln -s "$FAKE_DEVSHOP/kit" "$FAKE_PROJECT/kit"   # project shape: kit/ is a symlink
}

# Helper: source the lib and call the function in a single bash -c so DEVSHOP_FORCE_MODE
# from `env -u` / `DEVSHOP_FORCE_MODE=...` propagates correctly.
run_detect() {
  local arg="${1:-}"
  shift || true
  run "$@" bash -c "source '$LIB' && is_devshop_self_mode '$arg'"
}

# --- Auto mode (default) — filesystem detection ---

@test "auto: real kit/ dir → devshop-self (returns 0)" {
  run_detect "$FAKE_DEVSHOP" env -u DEVSHOP_FORCE_MODE
  assert_success
}

@test "auto: kit/ symlink → project (returns 1)" {
  run_detect "$FAKE_PROJECT" env -u DEVSHOP_FORCE_MODE
  assert_failure 1
}

@test "auto: missing kit/ → project (returns 1)" {
  local empty="$BATS_TEST_TMPDIR/empty-root"
  mkdir -p "$empty"
  run_detect "$empty" env -u DEVSHOP_FORCE_MODE
  assert_failure 1
}

@test "auto: empty root path → project (returns 1)" {
  run_detect "" env -u DEVSHOP_FORCE_MODE
  assert_failure 1
}

# --- Test override: force devshop-self ---

@test "DEVSHOP_FORCE_MODE=devshop-self → devshop-self regardless of filesystem" {
  # Force devshop-self even though FAKE_PROJECT has a kit/ symlink (project shape).
  run_detect "$FAKE_PROJECT" env DEVSHOP_FORCE_MODE=devshop-self
  assert_success
}

@test "DEVSHOP_FORCE_MODE=devshop-self ignores empty root path" {
  run_detect "" env DEVSHOP_FORCE_MODE=devshop-self
  assert_success
}

# --- Test override: force project ---

@test "DEVSHOP_FORCE_MODE=project → project regardless of filesystem" {
  # Force project even though FAKE_DEVSHOP has a real kit/ dir (devshop shape).
  # This is the failing-test fix: bats tests sed-rewrite GIT_ROOT=/workspace,
  # and in the devshop devcontainer /workspace/kit is a real dir → without
  # this override the inline detection would force devshop-self mode.
  run_detect "$FAKE_DEVSHOP" env DEVSHOP_FORCE_MODE=project
  assert_failure 1
}

@test "DEVSHOP_FORCE_MODE=project ignores filesystem entirely" {
  run_detect "$FAKE_PROJECT" env DEVSHOP_FORCE_MODE=project
  assert_failure 1
}

# --- Auto override is explicit and works the same as unset ---

@test "DEVSHOP_FORCE_MODE=auto behaves identically to unset" {
  run_detect "$FAKE_DEVSHOP" env DEVSHOP_FORCE_MODE=auto
  assert_success
  run_detect "$FAKE_PROJECT" env DEVSHOP_FORCE_MODE=auto
  assert_failure 1
}

# --- Invalid override fails closed ---

@test "DEVSHOP_FORCE_MODE=garbage → exit 2 + stderr error (fail closed)" {
  run_detect "$FAKE_DEVSHOP" env DEVSHOP_FORCE_MODE=garbage
  assert_failure 2
  assert_output --partial "DEVSHOP_FORCE_MODE='garbage' invalid"
}

@test "DEVSHOP_FORCE_MODE=devshop (not devshop-self) → exit 2" {
  # Common typo: "devshop" instead of "devshop-self". Must fail loudly.
  run_detect "$FAKE_DEVSHOP" env DEVSHOP_FORCE_MODE=devshop
  assert_failure 2
}
