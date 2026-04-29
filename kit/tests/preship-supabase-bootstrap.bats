#!/usr/bin/env bats
# Tests for kit/scripts/preship/supabase-bootstrap.sh
# Phase 0 preflight helper — bootstraps local Supabase for Gate 9, or reports blocked.
# Three reachability shapes are auto-detected: compose isolation (template default since
# v1.23.0), docker-bind (legacy), and Host Supabase (data plane reachable on
# host.docker.internal but lifecycle on macOS host). Tests exercise each detection branch
# + the error paths via stubs; deep integration (real supabase start / docker / relay)
# is out of scope.

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

# Helper: run with isolated PATH (no real supabase/docker/curl/psql leakage)
run_script_isolated() {
  local mode="${1:-up}"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" bash -c "cd '$TEST_REPO' && bash '$SCRIPT' '$mode'"
}

# Helper: run with isolated PATH + env vars (compose isolation needs these set, since
# compose.yml normally exports them)
run_script_compose() {
  local mode="${1:-up}"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
    SUPABASE_URL="http://host.docker.internal:54321" \
    SUPABASE_ANON_KEY="test-anon-key" \
    bash -c "cd '$TEST_REPO' && bash '$SCRIPT' '$mode'"
}

# Helper: mock the relay via curl. Reads $MOCK_RELAY_STATUS_RC + $MOCK_RELAY_START_RC.
mock_relay_curl() {
  cat > "$MOCK_BIN/curl" <<'STUB'
#!/bin/bash
URL=""
for arg in "$@"; do
  case "$arg" in
    http://supabase-runner:9000/status) URL="status" ;;
    http://supabase-runner:9000/start)  URL="start" ;;
    http://supabase-runner:9000/stop)   URL="stop" ;;
    http://host.docker.internal:54321)  URL="host-data" ;;
  esac
done
case "$URL" in
  status)    exit "${MOCK_RELAY_STATUS_RC:-0}" ;;
  start)     exit "${MOCK_RELAY_START_RC:-0}" ;;
  stop)      exit "${MOCK_RELAY_STOP_RC:-0}" ;;
  host-data) exit "${MOCK_HOST_DATA_RC:-0}" ;;
  *)         exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/curl"
}

# Helper: mock psql to return seed-fixture count
mock_psql_seed_count() {
  local count="${1:-2}"
  cat > "$MOCK_BIN/psql" <<STUB
#!/bin/bash
echo "$count"
exit 0
STUB
  chmod +x "$MOCK_BIN/psql"
}

# --- Error paths (shape-independent) ---

@test "up: missing supabase CLI → error exit 2" {
  # Isolated PATH ensures no real supabase (installed at /usr/local/bin) leaks in
  run_script_isolated up
  assert_failure 2
  assert_output --partial "supabase CLI not installed"
}

@test "up: nothing reachable (no compose.yml, no docker, no host data plane) → blocked, refuses hosted fallback" {
  create_stub supabase "CLI ok" 0
  # Mock docker to fail info → docker-bind detection fails
  cat > "$MOCK_BIN/docker" <<'STUB'
#!/bin/bash
[ "$1" = "info" ] && exit 1
exit 0
STUB
  chmod +x "$MOCK_BIN/docker"
  # Mock curl to fail host.docker.internal:54321 check → host detection fails
  cat > "$MOCK_BIN/curl" <<'STUB'
#!/bin/bash
exit 7
STUB
  chmod +x "$MOCK_BIN/curl"

  run_script_isolated up
  assert_success
  assert_output --partial "blocked"
  assert_output --partial "Refusing hosted-Supabase fallback"
}

# --- docker-bind shape (legacy) ---

@test "docker-bind up: already running → reuse + ok exit 0" {
  # supabase status → 0 (running). Returns anon-key payload for --output env (post-refactor
  # the docker-bind path runs seed verification + anon-key extraction + .env.local rewrite
  # even on the reused path — more correct than the pre-refactor early-return on reused).
  cat > "$MOCK_BIN/supabase" <<'STUB'
#!/bin/bash
case "$1" in
  status)
    if [ "$2" = "--output" ] && [ "$3" = "env" ]; then
      echo "API_URL=http://localhost:54321"
      echo "ANON_KEY=test-anon-key"
    else
      echo "API URL: http://localhost:54321"
      echo "anon key: test-anon-key"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/supabase"
  create_stub docker "docker ok" 0
  mock_psql_seed_count 2

  run_script up
  assert_success
  assert_output --partial "reused"
  assert_output --partial "ok: local Supabase up"
}

# --- compose isolation shape (template default since v1.23.0) ---

@test "compose up: detected via .devcontainer/compose.yml + supabase-runner/, relay reachable + stack running → reuse" {
  # Compose isolation detector
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=0  # stack running
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl
  mock_psql_seed_count 2

  run_script_compose up
  assert_success
  assert_output --partial "reused: local Supabase already running (via cmd-relay)"
  assert_output --partial "ok: local Supabase up"
}

@test "compose up: relay alive but stack down → POST /start, then ok" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=22  # relay alive, stack not running (HTTP 500 → curl exit 22)
  MOCK_RELAY_START_RC=0    # POST /start succeeds
  export MOCK_RELAY_STATUS_RC MOCK_RELAY_START_RC
  mock_relay_curl
  mock_psql_seed_count 2

  run_script_compose up
  assert_success
  refute_output --partial "reused"
  assert_output --partial "ok: local Supabase up"
}

@test "compose up: relay unreachable → blocked with cmd-relay fix recipe" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=7  # couldn't connect
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl

  run_script_compose up
  assert_success  # blocked is exit 0; pre-ship dispatcher decides
  assert_output --partial "blocked"
  assert_output --partial "cmd-relay on supabase-runner:9000 unreachable"
  assert_output --partial "Rebuild Container"
}

@test "compose up: missing seed fixtures → error exit 4" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=0  # stack running
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl
  mock_psql_seed_count 0  # no seed users

  run_script_compose up
  assert_failure 4
  assert_output --partial "seed fixtures missing"
  assert_output --partial "pnpm db:reset"
}

@test "compose up: SUPABASE_URL or SUPABASE_ANON_KEY missing in env → error exit 5" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=0
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl
  mock_psql_seed_count 2

  # Run WITHOUT setting SUPABASE_URL or SUPABASE_ANON_KEY (which compose normally sets).
  # `env -u` explicitly clears those vars in case a prior test exported them — bats does
  # NOT reset env between tests, so leakage from run_script_compose would otherwise mask
  # the failure path under test.
  run env -u SUPABASE_URL -u SUPABASE_ANON_KEY PATH="$MOCK_BIN:/usr/bin:/bin" bash -c "cd '$TEST_REPO' && bash '$SCRIPT' up"
  assert_failure 5
  assert_output --partial "SUPABASE_URL or SUPABASE_ANON_KEY not in workspace env"
}

# --- status mode ---

@test "status: no CLI → cli-missing" {
  run_script_isolated status
  assert_success
  assert_output "cli-missing"
}

@test "status: nothing reachable → docker-unavailable" {
  create_stub supabase "ok" 0
  cat > "$MOCK_BIN/docker" <<'STUB'
#!/bin/bash
[ "$1" = "info" ] && exit 1
exit 0
STUB
  chmod +x "$MOCK_BIN/docker"
  cat > "$MOCK_BIN/curl" <<'STUB'
#!/bin/bash
exit 7
STUB
  chmod +x "$MOCK_BIN/curl"

  run_script_isolated status
  assert_success
  assert_output "docker-unavailable"
}

@test "status: docker-bind shape, running → running" {
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

@test "status: docker-bind shape, CLI + docker + not running → stopped" {
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

@test "status: compose isolation, relay alive + stack running → running" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"
  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=0
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl

  run_script_isolated status
  assert_success
  assert_output "running"
}

@test "status: compose isolation, relay alive + stack down → stopped" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"
  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=22
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl

  run_script_isolated status
  assert_success
  assert_output "stopped"
}

@test "status: compose isolation, relay unreachable → relay-unreachable" {
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"
  create_stub supabase "ok" 0
  MOCK_RELAY_STATUS_RC=7
  export MOCK_RELAY_STATUS_RC
  mock_relay_curl

  run_script_isolated status
  assert_success
  assert_output "relay-unreachable"
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
