#!/usr/bin/env bats
# Structural + behavioral assertions for the gstack-symptom wrapper pair.
#
# Two wrappers, both living outside .claude/skills/gstack/** (gstack is
# upstream-owned per CLAUDE.md § gstack — local edits there get wiped by
# /gstack-upgrade):
#
#   Sub-A: init-devshop.sh auto-runs populate-playwright-cache.sh on every
#          container start, so headless-browser skills (/qa, /design-review,
#          /benchmark, /canary, /ak-pre-ship Phase 0) work on first invocation
#          without operators having to know to run the script manually.
#
#   Sub-B: capture-screenshot.sh wraps `browse screenshot` so writes to
#          <git-root>/specs/<feature>/hero/ and <git-root>/.gstack/qa-reports/
#          screenshots/ stage through /tmp (always inside the daemon's
#          [TEMP_DIR, process.cwd()] allow-list), then cp to the final path.
#
# Background:
#   Operations: kit/docs/guide/ops.md § Playwright cache population
#               kit/docs/guide/ops.md § Hero screenshot — manual capture
#   CLAUDE.md § Known Footguns (Browse binary + Playwright + Screenshots)
#   CLAUDE.md § gstack (vendored-install upgrade wipe rationale)

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  INIT_DEVSHOP="$DEVSHOP/kit/scripts/init-devshop.sh"
  CAPTURE_SCRIPT="$DEVSHOP/kit/scripts/capture-screenshot.sh"
  # Test under the worktree if we're in one, otherwise main.
  if [ -f "$BATS_TEST_DIRNAME/../scripts/init-devshop.sh" ]; then
    INIT_DEVSHOP="$BATS_TEST_DIRNAME/../scripts/init-devshop.sh"
  fi
  if [ -f "$BATS_TEST_DIRNAME/../scripts/capture-screenshot.sh" ]; then
    CAPTURE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/capture-screenshot.sh"
  fi
}

# =============================================================================
# Sub-A: init-devshop.sh auto-runs populate-playwright-cache.sh
# =============================================================================

@test "Sub-A: init-devshop.sh invokes populate-playwright-cache.sh" {
  run grep -F 'populate-playwright-cache.sh' "$INIT_DEVSHOP"
  assert_success
}

@test "Sub-A: invocation runs as node user (cache lives under /home/node/)" {
  # Match the populate-playwright-cache line, then check it's wrapped in `su node -c`.
  run grep -E "su node -c '.*populate-playwright-cache\.sh'" "$INIT_DEVSHOP"
  assert_success
}

@test "Sub-A: invocation runs AFTER pnpm install (browsers.json lives in node_modules)" {
  pnpm_line=$(grep -n 'pnpm install --frozen-lockfile' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  populate_line=$(grep -n 'populate-playwright-cache.sh' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  [ -n "$pnpm_line" ] && [ -n "$populate_line" ]
  [ "$populate_line" -gt "$pnpm_line" ]
}

@test "Sub-A: invocation lands BEFORE the locked-files block (must run while node can still write)" {
  populate_line=$(grep -n 'populate-playwright-cache.sh' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  lock_line=$(grep -n 'Lock security-critical files' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  [ -n "$populate_line" ] && [ -n "$lock_line" ]
  [ "$populate_line" -lt "$lock_line" ]
}

@test "Sub-A: invocation tolerates failure (|| true) so a broken cache stub never bricks container start" {
  # The whole subshell + su must end with `|| true` so a populate failure
  # (broken browsers.json, missing playwright-core, etc.) cannot fail the
  # init script and brick container start.
  run grep -E 'populate-playwright-cache\.sh.*\|\| true' "$INIT_DEVSHOP"
  assert_success
}

# =============================================================================
# Sub-B: capture-screenshot.sh exists + is well-formed
# =============================================================================

@test "Sub-B: capture-screenshot.sh exists in kit/scripts/" {
  [ -f "$CAPTURE_SCRIPT" ]
}

@test "Sub-B: capture-screenshot.sh parses as bash (no syntax errors)" {
  run bash -n "$CAPTURE_SCRIPT"
  assert_success
}

@test "Sub-B: capture-screenshot.sh has the canonical 3-line header (What/Why/Does NOT)" {
  run grep -E '^# What:' "$CAPTURE_SCRIPT"
  assert_success
  run grep -E '^# Why:' "$CAPTURE_SCRIPT"
  assert_success
  run grep -E '^# Does NOT:' "$CAPTURE_SCRIPT"
  assert_success
}

@test "Sub-B: capture-screenshot.sh prints usage + exits 2 on no args" {
  run bash "$CAPTURE_SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: capture-screenshot.sh"* ]]
}

@test "Sub-B: capture-screenshot.sh stages through mktemp under /tmp" {
  # Must use mktemp (parallel-safe), not a fixed /tmp path (collision risk).
  run grep -E 'mktemp.*--tmpdir' "$CAPTURE_SCRIPT"
  assert_success
}

@test "Sub-B: capture-screenshot.sh creates the destination dir (mkdir -p FINAL_DIR)" {
  # Removes the burden from callers + matches the existing skill convention
  # (pre-ship/SKILL.md used to mkdir -p before each screenshot — now redundant).
  run grep -E 'mkdir -p "\$FINAL_DIR"' "$CAPTURE_SCRIPT"
  assert_success
}

@test "Sub-B: capture-screenshot.sh cps (not mvs) so /tmp keeps its copy" {
  # cp, not mv: /tmp keeps the staging file so callers can re-fetch within
  # the same container session; tmpreaper / teardown sweeps it later.
  run grep -E '^if ! cp "\$STAGE_PATH" "\$ABS_FINAL"' "$CAPTURE_SCRIPT"
  assert_success
}

@test "Sub-B: capture-screenshot.sh has a fallback browse binary path under gstack vendored install" {
  # If `browse` isn't on $PATH, fall back to the gstack vendored binary.
  run grep -F '/devshop/.claude/skills/gstack/browse/browse' "$CAPTURE_SCRIPT"
  assert_success
}

# =============================================================================
# Sub-B: behavioral — end-to-end with a stubbed `browse` binary
# =============================================================================

@test "Sub-B: wrapper stages to /tmp, cps to final path under specs/" {
  setup_mock_bin
  SANDBOX="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$SANDBOX"

  # Stub `browse`: when called as `browse screenshot <path> [flags...]`,
  # write a 4-byte PNG-ish payload to <path> so the wrapper's emptiness check
  # passes.
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "screenshot" ] && [ -n "$2" ]; then
  printf 'PNG\n' > "$2"
  exit 0
fi
echo "stub: unsupported invocation: $*" >&2
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  final="$SANDBOX/specs/myfeature/hero/signin.png"
  run bash "$CAPTURE_SCRIPT" "$final" --full-page
  assert_success

  # Assert on the wrapper's $output / $lines FIRST — any later `run <cmd>`
  # clobbers them with the new command's output. Wrapper's "ok:" line names
  # the final path + a /tmp staging path.
  [[ "${lines[0]}" == "ok: captured $final"* ]]
  [[ "${lines[0]}" == *"via /tmp/"* ]]

  # Final file exists and contains the stub payload.
  [ -f "$final" ]
  [ "$(cat "$final")" = "PNG" ]
}

@test "Sub-B: wrapper creates the destination dir if missing" {
  setup_mock_bin
  SANDBOX="$BATS_TEST_TMPDIR/sandbox-mkdir"

  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "screenshot" ] && [ -n "$2" ] && { printf 'PNG\n' > "$2"; exit 0; }
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  # Target dir does NOT exist yet — wrapper must create it.
  final="$SANDBOX/deep/nested/dir/shot.png"
  [ ! -d "$(dirname "$final")" ]
  run bash "$CAPTURE_SCRIPT" "$final"
  assert_success
  [ -f "$final" ]
}

@test "Sub-B: wrapper exits 3 when browse fails" {
  setup_mock_bin
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
echo "simulated browse failure" >&2
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  run bash "$CAPTURE_SCRIPT" "$BATS_TEST_TMPDIR/fail.png"
  [ "$status" -eq 3 ]
  [[ "$output" == *"browse screenshot failed"* ]]
}

@test "Sub-B: wrapper exits 3 when browse produces an empty file" {
  setup_mock_bin
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "screenshot" ] && [ -n "$2" ] && { : > "$2"; exit 0; }
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  run bash "$CAPTURE_SCRIPT" "$BATS_TEST_TMPDIR/empty.png"
  [ "$status" -eq 3 ]
  [[ "$output" == *"empty or missing"* ]]
}

@test "Sub-B: wrapper passes browse-flags through after the final path" {
  setup_mock_bin
  # Stub records its argv to a file so we can assert pass-through ordering.
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ARGV_DUMP"
[ "$1" = "screenshot" ] && [ -n "$2" ] && { printf 'PNG\n' > "$2"; exit 0; }
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"
  export ARGV_DUMP="$BATS_TEST_TMPDIR/argv.txt"

  final="$BATS_TEST_TMPDIR/flagged.png"
  run bash "$CAPTURE_SCRIPT" "$final" --full-page --viewport=1920x1080
  assert_success

  # Expected argv: screenshot <staging-path> --full-page --viewport=1920x1080
  [ "$(sed -n 1p "$ARGV_DUMP")" = "screenshot" ]
  [[ "$(sed -n 2p "$ARGV_DUMP")" == /tmp/* ]]
  [ "$(sed -n 3p "$ARGV_DUMP")" = "--full-page" ]
  [ "$(sed -n 4p "$ARGV_DUMP")" = "--viewport=1920x1080" ]
}

# =============================================================================
# Cross-check: devshop-owned docs point at the wrapper, not `browse screenshot`
# directly. Guards against future drift where a doc edit re-introduces the
# disallowed pattern that hits the gstack allow-list rejection.
# =============================================================================

@test "docs: pre-ship/SKILL.md hero-shot example uses capture-screenshot.sh wrapper" {
  SKILL="$BATS_TEST_DIRNAME/../../.claude/skills/devshop/pre-ship/SKILL.md"
  [ -f "$SKILL" ] || SKILL="/devshop/.claude/skills/devshop/pre-ship/SKILL.md"
  [ -f "$SKILL" ] || skip "pre-ship/SKILL.md not found"
  run grep -F 'capture-screenshot.sh' "$SKILL"
  assert_success
}

@test "docs: ops.md hero-screenshot recipe uses capture-screenshot.sh wrapper" {
  OPS="$BATS_TEST_DIRNAME/../docs/guide/ops.md"
  [ -f "$OPS" ] || OPS="/devshop/kit/docs/guide/ops.md"
  [ -f "$OPS" ] || skip "ops.md not found"
  run grep -F 'capture-screenshot.sh' "$OPS"
  assert_success
}
