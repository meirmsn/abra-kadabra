#!/usr/bin/env bats
# Behavior tests for template/.devcontainer/derive-ports-from-config.sh.
#
# The script reads supabase/config.toml and upserts SUPABASE_*_PORT keys
# into .devcontainer/.env so config.toml is the single source of truth
# for port numbers. Falls back to upstream Supabase defaults when
# config.toml doesn't exist (fresh template before `supabase init`).
#
# Pure file-content checks against synthetic fixtures; no real container,
# no iptables, no sudo. Each test builds its own config.toml + .env in
# $BATS_TEST_TMPDIR and runs the real script against them.

setup() {
  load helpers/setup
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DERIVE_SCRIPT="$REPO_ROOT/template/.devcontainer/derive-ports-from-config.sh"

  # Per-test project root (auto-cleaned via BATS_TEST_TMPDIR).
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/.devcontainer" "$PROJECT/supabase"
  touch "$PROJECT/.devcontainer/.env"
}

# Helper: write a standard 5-block config.toml with given ports.
write_config() {
  local api="${1:-54321}" db="${2:-54322}" studio="${3:-54323}" inbucket="${4:-54324}" analytics="${5:-54327}"
  cat > "$PROJECT/supabase/config.toml" <<EOF
[api]
enabled = true
port = $api
schemas = ["public", "graphql_public"]

[db]
port = $db
major_version = 15

[studio]
enabled = true
port = $studio

[inbucket]
enabled = true
port = $inbucket

[analytics]
enabled = true
port = $analytics
EOF
}

# Helper: read a key from .env, stripping quotes/whitespace.
env_val() {
  grep -E "^${1}=" "$PROJECT/.devcontainer/.env" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"''
}

# =============================================================================
# Standard extraction — 5-block config.toml → 5 keys upserted
# =============================================================================

@test "standard 5-block config.toml → 5 keys upserted with correct values" {
  write_config 54321 54322 54323 54324 54327
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ "$(env_val SUPABASE_API_PORT)" = "54321" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54322" ]
  [ "$(env_val SUPABASE_STUDIO_PORT)" = "54323" ]
  [ "$(env_val SUPABASE_MAILPIT_PORT)" = "54324" ]
  [ "$(env_val SUPABASE_ANALYTICS_PORT)" = "54327" ]
}

# =============================================================================
# Port-rebound config → derived .env matches
# =============================================================================

@test "port-rebound config (home-os +100 offsets) → derived .env matches" {
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
  [ "$(env_val SUPABASE_STUDIO_PORT)" = "54423" ]
  [ "$(env_val SUPABASE_MAILPIT_PORT)" = "54424" ]
  [ "$(env_val SUPABASE_ANALYTICS_PORT)" = "54427" ]
}

# =============================================================================
# config.toml missing → upstream defaults written (bootstrap branch)
# =============================================================================

@test "config.toml missing → upstream defaults written" {
  rm -f "$PROJECT/supabase/config.toml"
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  assert_output --partial "config.toml not found"
  [ "$(env_val SUPABASE_API_PORT)" = "54321" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54322" ]
  [ "$(env_val SUPABASE_STUDIO_PORT)" = "54323" ]
  [ "$(env_val SUPABASE_MAILPIT_PORT)" = "54324" ]
  [ "$(env_val SUPABASE_ANALYTICS_PORT)" = "54327" ]
}

# =============================================================================
# .env has unrelated keys → port keys updated, others preserved
# =============================================================================

@test ".env has unrelated keys → port keys updated, others preserved" {
  cat > "$PROJECT/.devcontainer/.env" <<'EOF'
PRODUCTION_URL=example.vercel.app
GITHUB_TOKEN=ghp_test
LOCAL_WORKSPACE_FOLDER=/Users/meir/projects/myproject
EOF
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  # Port keys derived
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
  # Unrelated keys preserved
  grep -q '^PRODUCTION_URL=example.vercel.app$' "$PROJECT/.devcontainer/.env"
  grep -q '^GITHUB_TOKEN=ghp_test$' "$PROJECT/.devcontainer/.env"
  grep -q '^LOCAL_WORKSPACE_FOLDER=/Users/meir/projects/myproject$' "$PROJECT/.devcontainer/.env"
}

# =============================================================================
# Comment block — .env port section has "do not edit" header
# =============================================================================

@test ".env gets a comment block above the port keys" {
  write_config 54321 54322 54323 54324 54327
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  grep -q '^# -- Supabase ports (derived from supabase/config.toml) --$' "$PROJECT/.devcontainer/.env"
  grep -q '^# Do not edit these directly' "$PROJECT/.devcontainer/.env"
  grep -q '^# To change ports, edit supabase/config.toml' "$PROJECT/.devcontainer/.env"
}

# =============================================================================
# Drift warning — warns when .env port differs from config.toml
# =============================================================================

@test "drift warning when .env port differs from config.toml" {
  cat > "$PROJECT/.devcontainer/.env" <<'EOF'
SUPABASE_API_PORT=54321
SUPABASE_DB_PORT=54322
EOF
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  assert_output --partial "SUPABASE_API_PORT in .env was 54321 but config.toml says 54421"
  assert_output --partial "Edit supabase/config.toml to change ports"
}

@test "no drift warning when .env ports already match config.toml" {
  cat > "$PROJECT/.devcontainer/.env" <<'EOF'
SUPABASE_API_PORT=54421
SUPABASE_DB_PORT=54422
EOF
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  refute_output --partial "was 54421 but config.toml says"
}

# =============================================================================
# Re-run with matching values → no diff (idempotent)
# =============================================================================

@test "re-run with matching values → .env unchanged (idempotent)" {
  write_config 54321 54322 54323 54324 54327
  bash "$DERIVE_SCRIPT" "$PROJECT"
  local before
  before=$(cat "$PROJECT/.devcontainer/.env")
  # Run again — values already match
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  local after
  after=$(cat "$PROJECT/.devcontainer/.env")
  [ "$before" = "$after" ]
}

# =============================================================================
# Malformed config.toml — section exists but port line missing → default used
# =============================================================================

@test "config.toml section without port line → falls back to default for that section" {
  cat > "$PROJECT/supabase/config.toml" <<'EOF'
[api]
enabled = true

[db]
port = 54422
major_version = 15
EOF
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  # [api] has no port line → falls back to default 54321
  [ "$(env_val SUPABASE_API_PORT)" = "54321" ]
  # [db] has an explicit port
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
}

# =============================================================================
# Port value with inline comment → comment stripped
# =============================================================================

@test "port value with inline comment → comment stripped" {
  cat > "$PROJECT/supabase/config.toml" <<'EOF'
[api]
port = 54421 # rebound for home-os

[db]
port = 54422

[studio]
port = 54423

[inbucket]
port = 54424

[analytics]
port = 54427
EOF
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
}

# =============================================================================
# Port value with no spaces around = → extracted correctly
# =============================================================================

@test "port value with no spaces around = → extracted correctly" {
  cat > "$PROJECT/supabase/config.toml" <<'EOF'
[api]
port=54421

[db]
port=54422

[studio]
port=54423

[inbucket]
port=54424

[analytics]
port=54427
EOF
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
}

# =============================================================================
# Existing stale port values in .env → overwritten by config.toml values
# =============================================================================

@test "existing stale port values in .env → overwritten by config.toml values" {
  cat > "$PROJECT/.devcontainer/.env" <<'EOF'
SUPABASE_API_PORT=54321
SUPABASE_DB_PORT=54322
EOF
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
  [ "$(env_val SUPABASE_STUDIO_PORT)" = "54423" ]
  [ "$(env_val SUPABASE_MAILPIT_PORT)" = "54424" ]
  [ "$(env_val SUPABASE_ANALYTICS_PORT)" = "54427" ]
}

# =============================================================================
# .env does not exist yet → created with port keys
# =============================================================================

@test ".env does not exist yet → created with port keys" {
  rm -f "$PROJECT/.devcontainer/.env"
  write_config 54421 54422 54423 54424 54427
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  [ -f "$PROJECT/.devcontainer/.env" ]
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
}

# =============================================================================
# Nested sub-table [api.tls] does NOT terminate [api] port extraction
# — but a fresh top-level [db] DOES terminate it
# =============================================================================

@test "sub-table does not interfere with port extraction" {
  cat > "$PROJECT/supabase/config.toml" <<'EOF'
[api]
enabled = true
port = 54421

[api.tls]
enabled = false

[db]
port = 54422

[studio]
port = 54423

[inbucket]
port = 54424

[analytics]
port = 54427
EOF
  run bash "$DERIVE_SCRIPT" "$PROJECT"
  assert_success
  # [api] port found before [api.tls] (sub-table starts with [, terminates block)
  # — awk exits the section at [api.tls] but already printed 54421
  [ "$(env_val SUPABASE_API_PORT)" = "54421" ]
  [ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
}
