#!/usr/bin/env bats
# Tests for kit/scripts/preship/supabase-bootstrap.sh
# Phase 0 preflight helper — bootstraps local Supabase for Gate 9, or reports blocked.
# Deep integration (real supabase start / docker) is out of scope; these tests exercise the
# error paths + CLI-contract surface via stubs.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/supabase-bootstrap.sh"

  # Project layout the script expects
  mkdir -p "$TEST_REPO/apps/web"
}

# Helper: run the script from inside the test repo
run_script() {
  local mode="${1:-up}"
  run bash -c "cd '$TEST_REPO' && bash '$SCRIPT' '$mode'"
}

# Helper: run with isolated PATH (no real supabase/docker leakage)
run_script_isolated() {
  local mode="${1:-up}"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" bash -c "cd '$TEST_REPO' && bash '$SCRIPT' '$mode'"
}

# --- Error paths ---

@test "up: missing supabase CLI → error exit 2" {
  # Isolated PATH ensures no real supabase (installed at /usr/local/bin) leaks in
  run_script_isolated up
  assert_failure 2
  assert_output --partial "supabase CLI not installed"
}

@test "up: supabase CLI present but docker not running → blocked, refuses hosted fallback" {
  create_stub supabase "CLI ok" 0
  # Mock docker to fail info
  cat > "$MOCK_BIN/docker" <<'STUB'
#!/bin/bash
[ "$1" = "info" ] && exit 1
exit 0
STUB
  chmod +x "$MOCK_BIN/docker"

  run_script up
  assert_success
  assert_output --partial "blocked"
  assert_output --partial "Docker not running"
  assert_output --partial "Refusing hosted-Supabase fallback"
}

@test "up: already running → reuse exit 0" {
  # supabase status → 0 (running)
  cat > "$MOCK_BIN/supabase" <<'STUB'
#!/bin/bash
case "$1" in
  status) exit 0 ;;
  *)      exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/supabase"
  create_stub docker "docker ok" 0

  run_script up
  assert_success
  assert_output --partial "reused"
}

@test "status mode: no CLI → cli-missing" {
  run_script_isolated status
  assert_success
  assert_output "cli-missing"
}

@test "status mode: CLI but no docker → docker-unavailable" {
  create_stub supabase "ok" 0
  cat > "$MOCK_BIN/docker" <<'STUB'
#!/bin/bash
[ "$1" = "info" ] && exit 1
exit 0
STUB
  chmod +x "$MOCK_BIN/docker"

  run_script status
  assert_success
  assert_output "docker-unavailable"
}

@test "status mode: running → running" {
  cat > "$MOCK_BIN/supabase" <<'STUB'
#!/bin/bash
exit 0
STUB
  chmod +x "$MOCK_BIN/supabase"
  create_stub docker "ok" 0

  run_script status
  assert_success
  assert_output "running"
}

@test "status mode: CLI + docker + not running → stopped" {
  cat > "$MOCK_BIN/supabase" <<'STUB'
#!/bin/bash
[ "$1" = "status" ] && exit 1  # stopped
exit 0
STUB
  chmod +x "$MOCK_BIN/supabase"
  create_stub docker "ok" 0

  run_script status
  assert_success
  assert_output "stopped"
}

# --- down mode ---

@test "down: restores backup .env.local if present" {
  echo "NEXT_PUBLIC_SUPABASE_URL=http://original.supabase.co" > "$TEST_REPO/apps/web/.env.local.preship-backup"
  # Simulate a rewritten .env.local from `up`
  echo "NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321" > "$TEST_REPO/apps/web/.env.local"

  run_script down
  assert_success
  run cat "$TEST_REPO/apps/web/.env.local"
  assert_output --partial "original.supabase.co"
  [ ! -f "$TEST_REPO/apps/web/.env.local.preship-backup" ]
}

@test "down: deletes created .env.local if sentinel present" {
  # `up` created the file from scratch — sentinel marks this
  touch "$TEST_REPO/apps/web/.env.local.preship-backup.created"
  echo "NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321" > "$TEST_REPO/apps/web/.env.local"

  run_script down
  assert_success
  [ ! -f "$TEST_REPO/apps/web/.env.local" ]
  [ ! -f "$TEST_REPO/apps/web/.env.local.preship-backup.created" ]
}

@test "down: no-op when nothing to restore" {
  # No backup, no env file — should not error
  run_script down
  assert_success
  assert_output --partial "down"
}

# --- invalid mode ---

@test "invalid mode → error exit 1" {
  run_script nonsense
  assert_failure 1
  assert_output --partial "Usage"
}
