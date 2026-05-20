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

# Returns 0 if `pid` is gone OR a zombie. Use this instead of `! kill -0` —
# in containers where PID 1 is a non-init like `sleep infinity` (Option 3
# devcontainer), orphaned children stay zombie until reaped, and `kill -0`
# still returns 0 against a zombie. For the cancel/replace tests we just
# need to confirm the script actually signaled the subshell — Z state is
# "logically dead" for our purposes.
_dead_or_zombie() {
  local pid="$1" state
  state=$(ps -p "$pid" -o stat= 2>/dev/null | tr -d ' ')
  [ -z "$state" ] || [[ "$state" == Z* ]]
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
  _dead_or_zombie "$pid"  # subshell signaled (gone or zombie)
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
  _dead_or_zombie "$first_pid"          # old subshell signaled (gone or zombie)
  kill -0 "$second_pid" 2>/dev/null     # new pending alive
}

# --- Deferred-work suppression ---
#
# claude-done reads the Stop hook payload from stdin and inspects the
# last `type:"assistant"` line of the transcript. If the just-ended turn
# scheduled future work, the ping is suppressed because Claude will
# resume on its own.

@test "notify-claude-done: suppresses when last turn used ScheduleWakeup" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ScheduleWakeup","input":{}}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
  sleep 0.4
  [ ! -f "$MOCK_BIN/curl.args" ]
}

@test "notify-claude-done: suppresses when last turn used run_in_background Bash" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"sleep 60","run_in_background":true}}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-done: suppresses when last turn used CronCreate" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"CronCreate","input":{}}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-done: still schedules when last turn was plain text" {
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"text","text":"all done"}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
  sleep 0.4
  [ -f "$MOCK_BIN/curl.args" ]
  grep -q 'Task finished' "$MOCK_BIN/curl.args"
}

@test "notify-claude-done: foreground bash tool_use in last turn does not suppress" {
  # run_in_background:false (or absent) means Claude waited on the tool
  # inline — once the tool returned, the turn ended naturally. Genuinely
  # halted, should ping.
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-done: suppression looks at the LAST assistant turn only" {
  # Earlier turn used ScheduleWakeup, but the just-ended turn is plain
  # text — ping should fire (suppression only applies to the most recent
  # turn end).
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  {
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ScheduleWakeup","input":{}}]}}'
    echo '{"type":"user","message":{"content":[{"type":"text","text":"resumed"}]}}'
    echo '{"type":"assistant","message":{"content":[{"type":"text","text":"truly done"}]}}'
  } > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
}

@test "notify-claude-done: suppression cancels any prior pending ping" {
  # Prior turn scheduled a ping (Request hook). The next turn ends with
  # ScheduleWakeup — Done hook fires + sees deferred work + must kill the
  # prior pending so the now-stale "Needs your input" doesn't escape.
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  export CLAUDE_NOTIFY_DELAY="5"  # long enough to survive the cancel test
  bash "$REQUEST"
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
  pid=$(cat "$CLAUDE_NOTIFY_PID_FILE")
  transcript="$BATS_TEST_TMPDIR/t.jsonl"
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ScheduleWakeup","input":{}}]}}' > "$transcript"
  run bash "$DONE_SCRIPT" <<<"{\"transcript_path\":\"$transcript\"}"
  assert_success
  [ ! -f "$CLAUDE_NOTIFY_PID_FILE" ]
  sleep 0.1
  _dead_or_zombie "$pid"
}

@test "notify-claude-done: missing transcript_path falls through to schedule" {
  # Backward-compat: if the Stop hook payload lacks a transcript_path
  # (older harness, manual invocation), the script should still schedule
  # the ping rather than silently no-op.
  create_capturing_stub curl ""
  export NTFY_URL="https://ntfy.sh/test-topic"
  run bash "$DONE_SCRIPT" <<<'{}'
  assert_success
  [ -f "$CLAUDE_NOTIFY_PID_FILE" ]
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
