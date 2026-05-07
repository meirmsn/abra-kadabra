#!/usr/bin/env bats
# Tests for kit/scripts/preship/supabase-bootstrap.sh's D6 classifier integration.
# Asserts: degraded stack + stack-needing diff → `blocked:`;
#          degraded stack + docs-only diff → `pass-with-note:`;
#          honors all four `devshop.requireHealthyLocalStack` values.
# Spec: specs/cheap-test-gates-local/spec.md § D6, § Tests, § supabase-bootstrap.sh up — the contract change.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/supabase-bootstrap.sh"
  CLASSIFIER="$SCRIPTS_DIR/preship/path-classifier.sh"

  # Project layout the script expects
  mkdir -p "$TEST_REPO/apps/web"
}

# Helper: stage a baseline commit + a second commit changing the named path so
# `git diff HEAD~1...HEAD` reports the change. Sets up a fake `origin/main` ref
# pointing at the baseline commit so path-classifier's default base ref works.
make_diff_against_base() {
  local path="$1" content="${2:-x}"
  echo "base" > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add base.md
  git -C "$TEST_REPO" commit -q -m "baseline"
  # Create a fake origin/main pointing at the baseline.
  git -C "$TEST_REPO" update-ref refs/remotes/origin/main HEAD
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "add $path"
}

# Helper: create a degraded-stack scenario by stubbing a supabase CLI but
# nothing else (no docker, no host data plane, no compose.yml). Then run the
# script in `up` mode. Returns whatever the script emitted on stdout.
run_degraded() {
  create_stub supabase "ok" 0
  cat > "$MOCK_BIN/docker" <<'STUB'
#!/bin/bash
[ "$1" = "info" ] && exit 1
exit 0
STUB
  chmod +x "$MOCK_BIN/docker"
  # curl returns 7 (couldn't connect) so host detection fails too.
  cat > "$MOCK_BIN/curl" <<'STUB'
#!/bin/bash
exit 7
STUB
  chmod +x "$MOCK_BIN/curl"

  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      PATH_CLASSIFIER_SCRIPT="$CLASSIFIER" \
      bash -c "cd '$TEST_REPO' && bash '$SCRIPT' up"
}

# === D6 promotion: stack-needing diff + degraded → blocked ===

@test "D6: degraded stack + stack-needing diff (apps/) + unset config → blocked" {
  make_diff_against_base apps/web/components/X.tsx
  run_degraded
  assert_success  # blocked is exit 0; orchestrator decides
  assert_output --partial "blocked:"
  refute_output --partial "pass-with-note:"
}

@test "D6: degraded stack + stack-needing diff (packages/core/) + unset config → blocked" {
  make_diff_against_base packages/core/src/api/y.ts
  run_degraded
  assert_success
  assert_output --partial "blocked:"
}

@test "D6: degraded stack + stack-needing diff (supabase/migrations/) + unset config → blocked" {
  make_diff_against_base supabase/migrations/001_init.sql
  run_degraded
  assert_success
  assert_output --partial "blocked:"
}

# === D6 promotion: docs-only diff + degraded → pass-with-note ===

@test "D6: degraded stack + docs-only diff (README.md) + unset config → pass-with-note" {
  make_diff_against_base README.md
  run_degraded
  assert_success
  assert_output --partial "pass-with-note:"
  refute_output --partial "blocked:"
}

@test "D6: degraded stack + devshop-docs-only diff (kit/docs/) + unset config → pass-with-note" {
  make_diff_against_base kit/docs/guide/foo.md
  run_degraded
  assert_success
  assert_output --partial "pass-with-note:"
}

# === D6: requireHealthyLocalStack=when-relevant explicit form ===

@test "D6: when-relevant explicit form == unset (stack-needing → blocked)" {
  make_diff_against_base apps/web/components/X.tsx
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "when-relevant"
  run_degraded
  assert_success
  assert_output --partial "blocked:"
}

@test "D6: when-relevant explicit form == unset (docs-only → pass-with-note)" {
  make_diff_against_base README.md
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "when-relevant"
  run_degraded
  assert_success
  assert_output --partial "pass-with-note:"
}

# === D6: requireHealthyLocalStack=never (legacy explicit opt-out) ===

@test "D6: requireHealthyLocalStack=never + degraded + stack-needing diff → pass-with-note (no promotion)" {
  make_diff_against_base apps/web/components/X.tsx
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "never"
  run_degraded
  assert_success
  assert_output --partial "pass-with-note:"
  refute_output --partial "blocked:"
}

@test "D6: requireHealthyLocalStack=never + degraded + docs-only diff → pass-with-note" {
  make_diff_against_base README.md
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "never"
  run_degraded
  assert_success
  assert_output --partial "pass-with-note:"
}

# === D6: requireHealthyLocalStack=always (aspirational strict) ===

@test "D6: requireHealthyLocalStack=always + degraded + docs-only diff → blocked (promoted regardless)" {
  make_diff_against_base README.md
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "always"
  run_degraded
  assert_success
  assert_output --partial "blocked:"
  refute_output --partial "pass-with-note:"
}

@test "D6: requireHealthyLocalStack=always + degraded + stack-needing diff → blocked" {
  make_diff_against_base apps/web/components/X.tsx
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "always"
  run_degraded
  assert_success
  assert_output --partial "blocked:"
}

# === D6: classifier missing → fail-safe blocked ===

@test "D6: classifier script missing → fail-safe to blocked (legacy behavior)" {
  make_diff_against_base apps/web/components/X.tsx
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

  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      PATH_CLASSIFIER_SCRIPT="/nonexistent/path-classifier.sh" \
      bash -c "cd '$TEST_REPO' && bash '$SCRIPT' up"
  assert_success
  assert_output --partial "blocked:"
}

# === D6: healthy stack — no behavior change ===

@test "D6: healthy stack + any diff + any config → no degraded outcome (existing ok / reused path)" {
  make_diff_against_base apps/web/components/X.tsx
  git -C "$TEST_REPO" config devshop.requireHealthyLocalStack "always"

  # Healthy compose isolation shape: compose.yml + supabase-runner/ + relay returns 0.
  mkdir -p "$TEST_REPO/.devcontainer/supabase-runner"
  touch "$TEST_REPO/.devcontainer/compose.yml"

  create_stub supabase "ok" 0
  cat > "$MOCK_BIN/curl" <<'STUB'
#!/bin/bash
# Status returns 0 (running)
exit 0
STUB
  chmod +x "$MOCK_BIN/curl"
  cat > "$MOCK_BIN/psql" <<'STUB'
#!/bin/bash
echo "2"
exit 0
STUB
  chmod +x "$MOCK_BIN/psql"

  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      SUPABASE_URL="http://host.docker.internal:54321" \
      SUPABASE_ANON_KEY="test-anon-key" \
      PATH_CLASSIFIER_SCRIPT="$CLASSIFIER" \
      bash -c "cd '$TEST_REPO' && bash '$SCRIPT' up"
  assert_success
  refute_output --partial "blocked:"
  refute_output --partial "pass-with-note:"
  assert_output --partial "reused"
}

# === D6: empty repo / git error fallback ===

@test "D6: degraded stack + no origin/main ref (git error) → fail-safe to blocked" {
  # Test repo has only the initial commit; no origin/main → classifier returns 2.
  run_degraded
  assert_success
  assert_output --partial "blocked:"
}
