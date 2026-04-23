#!/usr/bin/env bats
# Tests for kit/scripts/notify/claude-{request,done,cancel}
# 30s-debounced ntfy.sh notifications with cancel-on-activity.

setup() {
  load helpers/setup
  setup_mock_bin
  REQUEST="$SCRIPTS_DIR/notify/claude-request"
  DONE_SCRIPT="$SCRIPTS_DIR/notify/claude-done"
  CANCEL="$SCRIPTS_DIR/notify/claude-cancel"

  # Isolate PID file per test + short delay so happy-path tests don't hang
  export CLAUDE_NOTIFY_PID_FILE="$BATS_TEST_TMPDIR/pending.pid"
  export CLAUDE_NOTIFY_DELAY="0.1"
}

teardown() {
  # Kill any lingering background jobs from happy-path tests
  if [ -f "$CLAUDE_NOTIFY_PID_FILE" ]; then
    kill "$(cat "$CLAUDE_NOTIFY_PID_FILE")" 2>/dev/null || true
    rm -f "$CLAUDE_NOTIFY_PID_FILE"
  fi
}

# --- No-op path (NTFY_URL unset) ---

@test "notify-claude-request: no-op when NTFY_URL unset" {
  unset NTFY_URL
  run bash "$REQUEST"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-done: no-op when NTFY_URL unset" {
  unset NTFY_URL
  run bash "$DONE_SCRIPT"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-cancel: idempotent when no pending notification" {
  run bash "$CANCEL"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

# --- Happy path: PID file + delayed curl ---

@test "notify-claude-request: writes PID file and fires curl after DELAY" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  run bash "$REQUEST"
  assert_success
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
  # Wait for backgrounded sleep 0.1 + curl call to land
  sleep 0.4
  [ -f "$MOCK_BIN/curl.args" ]
  grep -q 'ntfy.sh/test-topic' "$MOCK_BIN/curl.args"
  grep -q 'Needs your input' "$MOCK_BIN/curl.args"
}

@test "notify-claude-done: fires curl with 'Task finished' body" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  run bash "$DONE_SCRIPT"
  assert_success
  sleep 0.4
  [ -f "$MOCK_BIN/curl.args" ]
  grep -q 'Task finished' "$MOCK_BIN/curl.args"
}

# --- Cancel behavior ---

@test "notify-claude-cancel: kills pending and removes PID file" {
  export NTFY_URL="https://ntfy.sh/test-topic"
  export CLAUDE_NOTIFY_DELAY="5"  # long enough to catch before it fires
  create_capturing_stub curl ""
  bash "$REQUEST"
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
  pid=$(cat "$CLAUDE_NOTIFY_PID_FILE")
  kill -0 "$pid" 2>/dev/null  # process alive
  run bash "$CANCEL"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
  sleep 0.1
  ! kill -0 "$pid" 2>/dev/null  # process dead
}

@test "notify-claude-request: replaces prior pending (cancel-then-schedule)" {
  export NTFY_URL="https://ntfy.sh/test-topic"
  export CLAUDE_NOTIFY_DELAY="5"
  create_capturing_stub curl ""
  bash "$REQUEST"
  first_pid=$(cat "$CLAUDE_NOTIFY_PID_FILE")
  bash "$REQUEST"
  second_pid=$(cat "$CLAUDE_NOTIFY_PID_FILE")
  [ "$first_pid" != "$second_pid" ]
  sleep 0.1
  ! kill -0 "$first_pid" 2>/dev/null  # old pending killed
  kill -0 "$second_pid" 2>/dev/null    # new pending alive
}

# --- Project label detection ---

@test "notify-claude-request: labels banner with package.json name" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  mkdir -p "$BATS_TEST_TMPDIR/proj"
  echo '{"name": "my-project"}' > "$BATS_TEST_TMPDIR/proj/package.json"
  (cd "$BATS_TEST_TMPDIR/proj" && bash "$REQUEST")
  sleep 0.4
  grep -q 'Title: my-project — Claude Code' "$MOCK_BIN/curl.args"
}

@test "notify-claude-request: falls back to dir basename when no package.json" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  mkdir -p "$BATS_TEST_TMPDIR/fallback-dir"
  (cd "$BATS_TEST_TMPDIR/fallback-dir" && bash "$REQUEST")
  sleep 0.4
  grep -q 'Title: fallback-dir — Claude Code' "$MOCK_BIN/curl.args"
}
