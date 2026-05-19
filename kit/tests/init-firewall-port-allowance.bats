#!/usr/bin/env bats
# Env-aware Supabase port allowance in template/.devcontainer/init-firewall.sh.
#
# The HOST_DOCKER_INTERNAL ACCEPT-rule block reads SUPABASE_API_PORT +
# SUPABASE_DB_PORT directly from /workspace/.devcontainer/.env (script
# runs as root via sudo in postStartCommand; sudo strips env vars by
# default so we can't rely on inherited vars). Defaults: 54321 + 54322 —
# Supabase's upstream defaults. Projects that rebind to avoid host-port
# collisions (e.g. home-os uses 54421/54422) declare the rebind in
# .devcontainer/.env without editing this script.
#
# Two layers:
#   1. Structure — grep over template/.devcontainer/init-firewall.sh
#      confirms the env-driven port pattern + numeric validation is wired.
#   2. Behavior — extract just the port-resolution + validation snippet
#      via awk and exercise it with synthetic .env fixtures. Pure-bash
#      execution; never touches iptables / ipset / sudo / host state.
#
# Background:
#   Spec: specs/sandbox-qa-close-gap/spec.md
#   Footgun: home-os PR #26 (2026-05-16) — silent EHOSTUNREACH on
#            rebound-port projects because workspace iptables ACCEPT
#            rule hardcoded 54321/54322 instead of reading the project's
#            .env override.

setup() {
  load helpers/setup
  # Self-locate the repo root so the test works equally in the main /devshop
  # checkout and in a worktree (where the file under test lives in the
  # worktree path during development, then in /devshop/template/ after merge).
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  INIT_FIREWALL="$REPO_ROOT/template/.devcontainer/init-firewall.sh"

  # Workspace per-test temp dir (auto-cleaned via BATS_TEST_TMPDIR).
  FIXTURE_DIR="$BATS_TEST_TMPDIR/firewall-port-fixture"
  mkdir -p "$FIXTURE_DIR"
  SNIPPET="$FIXTURE_DIR/snippet.sh"

  # Extract just the port-resolution + numeric-validation block from the
  # real script. This guarantees the test exercises the actual code, not
  # a hand-mirrored copy that could drift.
  awk '
    /^ENV_FILE="\/workspace\/\.devcontainer\/\.env"$/ { capture=1 }
    capture { print }
    capture && /^done$/ { capture=0 }
  ' "$INIT_FIREWALL" > "$SNIPPET"

  # Sanity check: the snippet must be non-empty AND end with "done"
  # (the close of the validation loop). If extraction returned nothing,
  # FAIL loudly — a refactor that renames ENV_FILE / restructures the
  # validation loop SHOULD surface as a red test, not a silent skip.
  # The awk-extract pattern is intentionally rigid so the test fires
  # at the right rung: a missing snippet means the production script
  # no longer has the canonical port-resolution shape this test is
  # asserting against.
  [ -s "$SNIPPET" ] || fail "snippet extraction returned empty — init-firewall.sh refactored? Update the awk pattern in setup() to match the new shape, or update the test to assert the new shape directly."
  tail -1 "$SNIPPET" | grep -qE '^done$' \
    || fail "snippet does not end with 'done' — extraction misaligned with the validation loop close. Inspect /tmp/snippet.sh and update setup()'s awk."
}

# Run the extracted snippet against a synthetic .env at $1; capture exit
# code + resulting port values into BATS variables.
#   run_snippet "/path/to/fake/.env"
# Sets: status, output, SUPABASE_API_PORT, SUPABASE_DB_PORT
run_snippet() {
  local env_file="$1"
  # The snippet uses `ENV_FILE="/workspace/.devcontainer/.env"` — override
  # by sed-rewriting in the runner. Cleaner than asking the script to
  # honor an external ENV_FILE override (would require modifying the
  # real script just for testability).
  local runner="$FIXTURE_DIR/runner.sh"
  sed "s|ENV_FILE=\"/workspace/.devcontainer/.env\"|ENV_FILE=\"$env_file\"|" \
    "$SNIPPET" > "$runner"
  # Trailing echo to expose the resolved port values for assertion.
  cat >> "$runner" <<'TAIL'
echo "RESOLVED_API=$SUPABASE_API_PORT"
echo "RESOLVED_DB=$SUPABASE_DB_PORT"
TAIL
  run bash "$runner"
}

# =============================================================================
# Structure — the env-aware port pattern is present in the real script
# =============================================================================

@test "structure: init-firewall reads SUPABASE_API_PORT from /workspace/.devcontainer/.env" {
  run grep -qE 'ENV_FILE="/workspace/\.devcontainer/\.env"' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_API_PORT=' "$INIT_FIREWALL"
  assert_success
}

@test "structure: init-firewall reads SUPABASE_DB_PORT from .env" {
  run grep -qE 'SUPABASE_DB_PORT=' "$INIT_FIREWALL"
  assert_success
}

@test "structure: init-firewall defaults to 54321 / 54322 when env vars absent" {
  run grep -qE 'SUPABASE_API_PORT="\$\{SUPABASE_API_PORT:-54321\}"' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_DB_PORT="\$\{SUPABASE_DB_PORT:-54322\}"' "$INIT_FIREWALL"
  assert_success
}

@test "structure: init-firewall validates each port is numeric + in 1-65535" {
  run grep -qE '\[\[ ! "\$port_val" =~ \^\[0-9\]\+\$ \]\]' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'port_val" -lt 1' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'port_val" -gt 65535' "$INIT_FIREWALL"
  assert_success
}

@test "structure: init-firewall iptables --dport lines reference the env-driven port vars, not hardcoded literals" {
  # The two ACCEPT rules must use "$SUPABASE_API_PORT" / "$SUPABASE_DB_PORT".
  # Use grep -qE -- '...' to terminate option parsing so the literal "--dport"
  # in the pattern doesn't get interpreted as a grep flag.
  run grep -qE -- '--dport "\$SUPABASE_API_PORT"' "$INIT_FIREWALL"
  assert_success
  run grep -qE -- '--dport "\$SUPABASE_DB_PORT"' "$INIT_FIREWALL"
  assert_success
  # And the hardcoded 54321 / 54322 literals must NOT appear in the
  # iptables ACCEPT lines (defaults are in the ${VAR:-DEFAULT} fallback,
  # which is the only legitimate reference).
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54321 -j ACCEPT' "$INIT_FIREWALL"
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54322 -j ACCEPT' "$INIT_FIREWALL"
}

# =============================================================================
# Behavior — extracted snippet resolves ports per .env contents
# =============================================================================

@test "behavior: defaults to 54321 / 54322 when .env is missing" {
  run_snippet "$FIXTURE_DIR/does-not-exist.env"
  assert_success
  assert_output --partial "RESOLVED_API=54321"
  assert_output --partial "RESOLVED_DB=54322"
}

@test "behavior: defaults when .env exists but has no SUPABASE_*_PORT lines" {
  cat > "$FIXTURE_DIR/empty.env" <<EOF
# .env with no port overrides
PRODUCTION_URL=example.vercel.app
GITHUB_TOKEN=ghp_test
EOF
  run_snippet "$FIXTURE_DIR/empty.env"
  assert_success
  assert_output --partial "RESOLVED_API=54321"
  assert_output --partial "RESOLVED_DB=54322"
}

@test "behavior: honors SUPABASE_API_PORT override + SUPABASE_DB_PORT override" {
  cat > "$FIXTURE_DIR/rebound.env" <<EOF
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54422
EOF
  run_snippet "$FIXTURE_DIR/rebound.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
  assert_output --partial "RESOLVED_DB=54422"
}

@test "behavior: partial override — only API_PORT set; DB_PORT falls back" {
  cat > "$FIXTURE_DIR/partial.env" <<EOF
SUPABASE_API_PORT=54421
EOF
  run_snippet "$FIXTURE_DIR/partial.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
  assert_output --partial "RESOLVED_DB=54322"
}

@test "behavior: strips surrounding double-quotes from .env values" {
  cat > "$FIXTURE_DIR/quoted.env" <<EOF
SUPABASE_API_PORT="54421"
SUPABASE_DB_PORT='54422'
EOF
  run_snippet "$FIXTURE_DIR/quoted.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
  assert_output --partial "RESOLVED_DB=54422"
}

@test "behavior: rejects non-numeric port (typo); names the offending var" {
  cat > "$FIXTURE_DIR/typo.env" <<EOF
SUPABASE_API_PORT=abc
SUPABASE_DB_PORT=54322
EOF
  run_snippet "$FIXTURE_DIR/typo.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_API_PORT=abc is not a valid TCP port"
}

@test "behavior: rejects out-of-range port (0)" {
  cat > "$FIXTURE_DIR/zero.env" <<EOF
SUPABASE_API_PORT=0
EOF
  run_snippet "$FIXTURE_DIR/zero.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_API_PORT=0 is not a valid TCP port"
}

@test "behavior: rejects out-of-range port (65536)" {
  cat > "$FIXTURE_DIR/overflow.env" <<EOF
SUPABASE_DB_PORT=65536
EOF
  run_snippet "$FIXTURE_DIR/overflow.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_DB_PORT=65536 is not a valid TCP port"
}

@test "behavior: error message names .env as the source (operator hint)" {
  cat > "$FIXTURE_DIR/bad.env" <<EOF
SUPABASE_API_PORT=xyz
EOF
  run_snippet "$FIXTURE_DIR/bad.env"
  assert_failure
  # Source line points at the actual .env path (fixture path in the test
  # context, /workspace/.devcontainer/.env in production).
  assert_output --partial "Source:"
}

@test "behavior: last occurrence of a duplicated var wins (tail -1 semantics)" {
  cat > "$FIXTURE_DIR/dup.env" <<EOF
SUPABASE_API_PORT=54321
SUPABASE_API_PORT=54421
EOF
  run_snippet "$FIXTURE_DIR/dup.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
}
