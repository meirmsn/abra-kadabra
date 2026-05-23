#!/usr/bin/env bats
# Env-aware Supabase port allowance in template/.devcontainer/init-firewall.sh.
#
# The HOST_DOCKER_INTERNAL ACCEPT-rule block reads all 5 Supabase port vars
# (API, DB, Studio, Mailpit, Analytics) directly from
# /workspace/.devcontainer/.env (script runs as root via sudo in
# postStartCommand; sudo strips env vars by default so we can't rely on
# inherited vars). All 5 are required (:?required) — no fallback defaults.
# The derive-ports-from-config.sh script populates .env from config.toml on
# every container start. Projects that rebind to avoid host-port collisions
# (e.g. home-os uses +100 offset) declare the rebind in config.toml.
#
# Two layers:
#   1. Structure — grep over template/.devcontainer/init-firewall.sh
#      confirms the env-driven port pattern + numeric validation is wired.
#   2. Behavior — extract just the port-resolution + validation snippet
#      via awk and exercise it with synthetic .env fixtures. Pure-bash
#      execution; never touches iptables / ipset / sudo / host state.
#
# Two runners — preserves the production execution context.
# Per `kit/docs/guide/conventions.md § Kit Testing § Preserve the production
# execution context`, bats tests that exec extracted snippets must replicate
# the source script's `set` options so pipefail-driven silent failures are
# visible:
#   - run_snippet            — plain bash, for behavior assertions where
#                              pipefail death is not in scope (resolved
#                              ports, error messages, etc).
#   - run_snippet_pipefail   — wraps the runner in `set -euo pipefail` +
#                              IFS=$'\n\t' + a sentinel echo at the end,
#                              replicating the production script header.
#                              Used by the regression block at the bottom
#                              of this file.
#
# Background:
#   Spec: specs/sandbox-qa-close-gap/spec.md
#   Footgun: home-os PR #26 (2026-05-16) — silent EHOSTUNREACH on
#            rebound-port projects because workspace iptables ACCEPT
#            rule hardcoded 54321/54322 instead of reading the project's
#            .env override.
#   Regression: lalista devcontainer rebuild 2026-05-20 — pipefail
#            killed init-firewall.sh on `.env` missing SUPABASE_*_PORT
#            keys. Test suite was 15/15 green pre-incident because the
#            extracted snippet ran in plain bash, bypassing the
#            production `set -euo pipefail` header.

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
# Sets: status, output, SUPABASE_*_PORT values
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
echo "RESOLVED_STUDIO=$SUPABASE_STUDIO_PORT"
echo "RESOLVED_MAILPIT=$SUPABASE_MAILPIT_PORT"
echo "RESOLVED_ANALYTICS=$SUPABASE_ANALYTICS_PORT"
TAIL
  run bash "$runner"
}

# =============================================================================
# Structure — the env-aware port pattern is present in the real script
# =============================================================================

@test "structure: init-firewall reads all 5 port vars from /workspace/.devcontainer/.env" {
  run grep -qE 'ENV_FILE="/workspace/\.devcontainer/\.env"' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_API_PORT=' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_DB_PORT=' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_STUDIO_PORT=' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_MAILPIT_PORT=' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_ANALYTICS_PORT=' "$INIT_FIREWALL"
  assert_success
}

@test "structure: init-firewall uses :?required (no :-default fallbacks)" {
  run grep -qE 'SUPABASE_API_PORT=.*:\?required' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_DB_PORT=.*:\?required' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_STUDIO_PORT=.*:\?required' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_MAILPIT_PORT=.*:\?required' "$INIT_FIREWALL"
  assert_success
  run grep -qE 'SUPABASE_ANALYTICS_PORT=.*:\?required' "$INIT_FIREWALL"
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

@test "structure: init-firewall iptables --dport lines reference all 5 env-driven port vars" {
  run grep -qE -- '--dport "\$SUPABASE_API_PORT"' "$INIT_FIREWALL"
  assert_success
  run grep -qE -- '--dport "\$SUPABASE_DB_PORT"' "$INIT_FIREWALL"
  assert_success
  run grep -qE -- '--dport "\$SUPABASE_STUDIO_PORT"' "$INIT_FIREWALL"
  assert_success
  run grep -qE -- '--dport "\$SUPABASE_MAILPIT_PORT"' "$INIT_FIREWALL"
  assert_success
  run grep -qE -- '--dport "\$SUPABASE_ANALYTICS_PORT"' "$INIT_FIREWALL"
  assert_success
  # Hardcoded port literals must NOT appear in iptables ACCEPT lines.
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54321 -j ACCEPT' "$INIT_FIREWALL"
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54322 -j ACCEPT' "$INIT_FIREWALL"
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54323 -j ACCEPT' "$INIT_FIREWALL"
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54324 -j ACCEPT' "$INIT_FIREWALL"
  ! grep -qE -- '^\s+iptables -A OUTPUT.*--dport 54327 -j ACCEPT' "$INIT_FIREWALL"
}

# =============================================================================
# Behavior — extracted snippet resolves ports per .env contents
# =============================================================================

@test "behavior: fails when .env is missing (all 5 ports are required)" {
  run_snippet "$FIXTURE_DIR/does-not-exist.env"
  assert_failure
}

@test "behavior: fails when .env exists but has no SUPABASE_*_PORT lines" {
  cat > "$FIXTURE_DIR/empty.env" <<EOF
# .env with no port overrides
PRODUCTION_URL=example.vercel.app
GITHUB_TOKEN=ghp_test
EOF
  run_snippet "$FIXTURE_DIR/empty.env"
  assert_failure
}

@test "behavior: resolves all 5 ports from .env" {
  cat > "$FIXTURE_DIR/full.env" <<EOF
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54422
SUPABASE_STUDIO_PORT=54423
SUPABASE_MAILPIT_PORT=54424
SUPABASE_ANALYTICS_PORT=54427
EOF
  run_snippet "$FIXTURE_DIR/full.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
  assert_output --partial "RESOLVED_DB=54422"
  assert_output --partial "RESOLVED_STUDIO=54423"
  assert_output --partial "RESOLVED_MAILPIT=54424"
  assert_output --partial "RESOLVED_ANALYTICS=54427"
}

@test "behavior: fails when only API_PORT + DB_PORT set (Studio/Mailpit/Analytics missing)" {
  cat > "$FIXTURE_DIR/partial.env" <<EOF
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54422
EOF
  run_snippet "$FIXTURE_DIR/partial.env"
  assert_failure
}

@test "behavior: strips surrounding double-quotes from .env values" {
  cat > "$FIXTURE_DIR/quoted.env" <<EOF
SUPABASE_API_PORT="54421"
SUPABASE_DB_PORT='54422'
SUPABASE_STUDIO_PORT=54423
SUPABASE_MAILPIT_PORT=54424
SUPABASE_ANALYTICS_PORT=54427
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
SUPABASE_STUDIO_PORT=54323
SUPABASE_MAILPIT_PORT=54324
SUPABASE_ANALYTICS_PORT=54327
EOF
  run_snippet "$FIXTURE_DIR/typo.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_API_PORT=abc is not a valid TCP port"
}

@test "behavior: rejects out-of-range port (0)" {
  cat > "$FIXTURE_DIR/zero.env" <<EOF
SUPABASE_API_PORT=0
SUPABASE_DB_PORT=54322
SUPABASE_STUDIO_PORT=54323
SUPABASE_MAILPIT_PORT=54324
SUPABASE_ANALYTICS_PORT=54327
EOF
  run_snippet "$FIXTURE_DIR/zero.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_API_PORT=0 is not a valid TCP port"
}

@test "behavior: rejects out-of-range port (65536)" {
  cat > "$FIXTURE_DIR/overflow.env" <<EOF
SUPABASE_API_PORT=54321
SUPABASE_DB_PORT=65536
SUPABASE_STUDIO_PORT=54323
SUPABASE_MAILPIT_PORT=54324
SUPABASE_ANALYTICS_PORT=54327
EOF
  run_snippet "$FIXTURE_DIR/overflow.env"
  assert_failure
  assert_output --partial "ERROR: SUPABASE_DB_PORT=65536 is not a valid TCP port"
}

@test "behavior: error message names .env as the source (operator hint)" {
  cat > "$FIXTURE_DIR/bad.env" <<EOF
SUPABASE_API_PORT=xyz
SUPABASE_DB_PORT=54322
SUPABASE_STUDIO_PORT=54323
SUPABASE_MAILPIT_PORT=54324
SUPABASE_ANALYTICS_PORT=54327
EOF
  run_snippet "$FIXTURE_DIR/bad.env"
  assert_failure
  assert_output --partial "Source:"
}

@test "behavior: last occurrence of a duplicated var wins (tail -1 semantics)" {
  cat > "$FIXTURE_DIR/dup.env" <<EOF
SUPABASE_API_PORT=54321
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54322
SUPABASE_STUDIO_PORT=54323
SUPABASE_MAILPIT_PORT=54324
SUPABASE_ANALYTICS_PORT=54327
EOF
  run_snippet "$FIXTURE_DIR/dup.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
}

# =============================================================================
# Regression — `set -euo pipefail` must not silently kill the script when:
#   (a) .env exists but lacks SUPABASE_*_PORT keys (grep no-match → exit 1)
#   (b) host.docker.internal does not resolve (getent exit non-zero)
# Both pipelines need a trailing `|| true` so the empty-result branch stays
# reachable. Without it pipefail propagates the non-zero through the pipe,
# set -e kills the assignment, and the script exits silently — bypassing the
# [ -n "$var" ] guard and the `else: warn:` branch. Worked incident: lalista
# devcontainer rebuild 2026-05-20 (regression introduced 2026-05-19 commit
# `94de8d7 feat(sandbox-qa): env-aware Supabase ports in init-firewall.sh`).
#
# Why this could not be caught by behavior tests above: run_snippet executes
# the extracted block under plain bash (no pipefail), which masks the
# regression — production init-firewall.sh runs the same block inside
# `set -euo pipefail` (script header).
# =============================================================================

# Same shape as run_snippet but wraps the runner in `set -euo pipefail` to
# replicate the production execution context. A sentinel echo at the end
# distinguishes "exited cleanly with empty resolution" from "died silently".
run_snippet_pipefail() {
  local env_file="$1"
  local runner="$FIXTURE_DIR/runner-pipefail.sh"
  {
    printf '#!/bin/bash\nset -euo pipefail\nIFS=$'"'"'\\n\\t'"'"'\n'
    sed "s|ENV_FILE=\"/workspace/.devcontainer/.env\"|ENV_FILE=\"$env_file\"|" "$SNIPPET"
    printf 'echo "RESOLVED_API=$SUPABASE_API_PORT"\necho "RESOLVED_DB=$SUPABASE_DB_PORT"\necho "DID_NOT_DIE_SILENTLY"\n'
  } > "$runner"
  run bash "$runner"
}

@test "regression: full .env does not silently kill under set -euo pipefail" {
  cat > "$FIXTURE_DIR/full-pipefail.env" <<EOF
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54422
SUPABASE_STUDIO_PORT=54423
SUPABASE_MAILPIT_PORT=54424
SUPABASE_ANALYTICS_PORT=54427
EOF
  run_snippet_pipefail "$FIXTURE_DIR/full-pipefail.env"
  assert_success
  assert_output --partial "RESOLVED_API=54421"
  assert_output --partial "RESOLVED_DB=54422"
  assert_output --partial "DID_NOT_DIE_SILENTLY"
}

@test "regression: .env without SUPABASE_*_PORT keys fails loudly under set -euo pipefail" {
  cat > "$FIXTURE_DIR/no-keys.env" <<EOF
# .env without SUPABASE port overrides
PRODUCTION_URL=example.vercel.app
GITHUB_TOKEN=ghp_test
EOF
  run_snippet_pipefail "$FIXTURE_DIR/no-keys.env"
  assert_failure
}

@test "regression: HOST_DOCKER_INTERNAL pipeline survives unresolved host.docker.internal under set -euo pipefail" {
  # Extract just the getent assignment line and run it in a synthetic context
  # where `getent` is stubbed to mimic NSS failure (exit 2, no output) —
  # replicates docker-desktop configurations where host.docker.internal
  # doesn't resolve or resolves IPv6-only. Without `|| true` on the pipeline,
  # set -e + pipefail kills the assignment silently; with the fix the var
  # ends up empty and the else-branch warn message is reachable.
  local getent_line
  getent_line=$(grep '^HOST_DOCKER_INTERNAL=' "$INIT_FIREWALL")
  [ -n "$getent_line" ] || fail "could not locate HOST_DOCKER_INTERNAL assignment in init-firewall.sh — refactor renamed the var? Update the grep pattern."

  local runner="$FIXTURE_DIR/getent-runner.sh"
  cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
IFS=\$'\n\t'
# Stub getent to simulate NSS failure (exit 2, no stdout).
getent() { return 2; }
$getent_line
if [ -n "\$HOST_DOCKER_INTERNAL" ]; then
  echo "RESOLVED=\$HOST_DOCKER_INTERNAL"
else
  echo "warn: host.docker.internal did not resolve to IPv4"
fi
echo "DID_NOT_DIE_SILENTLY"
EOF
  run bash "$runner"
  assert_success
  assert_output --partial "warn: host.docker.internal did not resolve"
  assert_output --partial "DID_NOT_DIE_SILENTLY"
}
