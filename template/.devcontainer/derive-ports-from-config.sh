#!/bin/bash
# What: Runs on the HOST (macOS / Linux) before VS Code creates the dev
#       container — chained after init-host-env.sh in devcontainer.json's
#       initializeCommand. Derives SUPABASE_*_PORT keys in .devcontainer/.env
#       from supabase/config.toml so config.toml is the single source of truth.
# Why:  The Supabase CLI reads config.toml at every `supabase start` and has
#       no env-var interpolation for port fields. Rather than fight this,
#       we invert: config.toml owns the ports, .env is mechanically derived.
#       Eliminates the silent-drift class where .env and config.toml diverge.
# Does NOT: touch non-port keys in .env — operator secrets, LOCAL_WORKSPACE_FOLDER,
#       and any other vars are preserved verbatim.

set -e

PROJECT_ROOT="${1:?usage: $0 <project-root>}"
CONFIG_TOML="$PROJECT_ROOT/supabase/config.toml"
ENV_FILE="$PROJECT_ROOT/.devcontainer/.env"

# Upstream Supabase defaults — used when config.toml doesn't exist yet
# (fresh template before `supabase init` runs).
DEFAULT_API_PORT=54321
DEFAULT_DB_PORT=54322
DEFAULT_STUDIO_PORT=54323
DEFAULT_MAILPIT_PORT=54324
DEFAULT_ANALYTICS_PORT=54327

COMMENT_MARKER="# -- Supabase ports (derived from supabase/config.toml) --"

# Extract a `port = <number>` value from a TOML [section] block.
extract_port() {
  local section="$1" default="$2"
  local port
  port=$(awk -v sect="$section" '
    $0 ~ "^\\[" sect "\\]" { in_sect=1; next }
    in_sect && /^\[/        { exit }
    in_sect && /^port[[:space:]]*=/ {
      sub(/^port[[:space:]]*=[[:space:]]*/, "")
      sub(/[[:space:]]*#.*/, "")
      gsub(/[[:space:]]/, "")
      print; exit
    }
  ' "$CONFIG_TOML")
  printf '%s' "${port:-$default}"
}

if [ -f "$CONFIG_TOML" ]; then
  API_PORT=$(extract_port "api"       "$DEFAULT_API_PORT")
  DB_PORT=$(extract_port "db"         "$DEFAULT_DB_PORT")
  STUDIO_PORT=$(extract_port "studio" "$DEFAULT_STUDIO_PORT")
  MAILPIT_PORT=$(extract_port "inbucket" "$DEFAULT_MAILPIT_PORT")
  ANALYTICS_PORT=$(extract_port "analytics" "$DEFAULT_ANALYTICS_PORT")
else
  echo "derive-ports-from-config.sh: supabase/config.toml not found — using upstream defaults"
  API_PORT=$DEFAULT_API_PORT
  DB_PORT=$DEFAULT_DB_PORT
  STUDIO_PORT=$DEFAULT_STUDIO_PORT
  MAILPIT_PORT=$DEFAULT_MAILPIT_PORT
  ANALYTICS_PORT=$DEFAULT_ANALYTICS_PORT
fi

touch "$ENV_FILE"

# Warn when .env has a port value that differs from what config.toml says.
warn_drift() {
  local key="$1" new_val="$2"
  local old_val
  old_val=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'' || true)
  if [ -n "$old_val" ] && [ "$old_val" != "$new_val" ]; then
    printf '  ⚠ %s in .env was %s but config.toml says %s — overwriting.\n' "$key" "$old_val" "$new_val"
    printf '    Edit supabase/config.toml to change ports, not .env directly.\n'
  fi
}

warn_drift "SUPABASE_API_PORT"       "$API_PORT"
warn_drift "SUPABASE_DB_PORT"        "$DB_PORT"
warn_drift "SUPABASE_STUDIO_PORT"    "$STUDIO_PORT"
warn_drift "SUPABASE_MAILPIT_PORT"   "$MAILPIT_PORT"
warn_drift "SUPABASE_ANALYTICS_PORT" "$ANALYTICS_PORT"

# Skip rewrite when all values + comment block already match (idempotent).
env_val() { grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'' || true; }
if grep -q "^# -- Supabase ports" "$ENV_FILE" 2>/dev/null \
   && [ "$(env_val SUPABASE_API_PORT)" = "$API_PORT" ] \
   && [ "$(env_val SUPABASE_DB_PORT)" = "$DB_PORT" ] \
   && [ "$(env_val SUPABASE_STUDIO_PORT)" = "$STUDIO_PORT" ] \
   && [ "$(env_val SUPABASE_MAILPIT_PORT)" = "$MAILPIT_PORT" ] \
   && [ "$(env_val SUPABASE_ANALYTICS_PORT)" = "$ANALYTICS_PORT" ]; then
  echo "derive-ports-from-config.sh: ports already up to date — no changes"
  echo "  API=$API_PORT DB=$DB_PORT Studio=$STUDIO_PORT Mailpit=$MAILPIT_PORT Analytics=$ANALYTICS_PORT"
  exit 0
fi

# Rewrite the port block in .env: strip old port keys + old comment block,
# then append a fresh comment block + all 5 keys. Preserves all other content.
{
  grep -v "^SUPABASE_API_PORT=\|^SUPABASE_DB_PORT=\|^SUPABASE_STUDIO_PORT=\|^SUPABASE_MAILPIT_PORT=\|^SUPABASE_ANALYTICS_PORT=\|^# -- Supabase ports\|^# Do not edit these\|^# To change ports" "$ENV_FILE" || true
  printf '\n%s\n' "$COMMENT_MARKER"
  printf '# Do not edit these directly — they are overwritten on every container start.\n'
  printf '# To change ports, edit supabase/config.toml and rebuild the container.\n'
  printf 'SUPABASE_API_PORT=%s\n' "$API_PORT"
  printf 'SUPABASE_DB_PORT=%s\n' "$DB_PORT"
  printf 'SUPABASE_STUDIO_PORT=%s\n' "$STUDIO_PORT"
  printf 'SUPABASE_MAILPIT_PORT=%s\n' "$MAILPIT_PORT"
  printf 'SUPABASE_ANALYTICS_PORT=%s\n' "$ANALYTICS_PORT"
} > "$ENV_FILE.tmp"
mv "$ENV_FILE.tmp" "$ENV_FILE"

echo "derive-ports-from-config.sh: ports derived from ${CONFIG_TOML#$PROJECT_ROOT/} → .devcontainer/.env"
echo "  API=$API_PORT DB=$DB_PORT Studio=$STUDIO_PORT Mailpit=$MAILPIT_PORT Analytics=$ANALYTICS_PORT"
