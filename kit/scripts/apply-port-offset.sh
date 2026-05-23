#!/bin/bash
# What: Re-applies a project's port offset to supabase/config.toml after
#       a `supabase init` resets it to upstream defaults.
# Why:  `supabase init` overwrites config.toml with default ports (54321-54327),
#       discarding the project's assigned offset. This script restores them.
# Does NOT: handle cross-offset rebinding (moving a project from one offset to
#       another). That's a different scope — see kit/ROADMAP.md.

set -euo pipefail

PROJECT_ROOT="${1:?Usage: $0 <project-root>}"
CONFIG_TOML="$PROJECT_ROOT/supabase/config.toml"
DEVSHOP="${DEVSHOP:-/devshop}"

if [ ! -f "$CONFIG_TOML" ]; then
  echo "✖ $CONFIG_TOML not found — run 'supabase init' first."
  exit 1
fi

PROJECT_NAME="$(basename "$PROJECT_ROOT")"
NOTES_FILE="$DEVSHOP/kit/notes/projects/$PROJECT_NAME.md"

if [ ! -f "$NOTES_FILE" ]; then
  echo "✖ No devshop notes file at $NOTES_FILE — cannot determine offset."
  echo "  If this is a new project, run /ak-new-project to register it."
  exit 1
fi

OFFSET=$(grep -m1 '^supabase_port_offset:' "$NOTES_FILE" | sed 's/^supabase_port_offset:[[:space:]]*//' | tr -d '[:space:]')

if [ -z "$OFFSET" ]; then
  echo "✖ No supabase_port_offset found in $NOTES_FILE frontmatter."
  exit 1
fi

if ! [[ "$OFFSET" =~ ^[0-9]+$ ]]; then
  echo "✖ supabase_port_offset '$OFFSET' is not a valid number."
  exit 1
fi

API_PORT=$((54321 + OFFSET))
DB_PORT=$((54322 + OFFSET))
STUDIO_PORT=$((54323 + OFFSET))
MAILPIT_PORT=$((54324 + OFFSET))
ANALYTICS_PORT=$((54327 + OFFSET))

sed -i "/^\[api\]/,/^\[/{s/^port = .*/port = $API_PORT/}" "$CONFIG_TOML"
sed -i "/^\[db\]/,/^\[/{s/^port = .*/port = $DB_PORT/}" "$CONFIG_TOML"
sed -i "/^\[studio\]/,/^\[/{s/^port = .*/port = $STUDIO_PORT/}" "$CONFIG_TOML"
sed -i "/^\[inbucket\]/,/^\[/{s/^port = .*/port = $MAILPIT_PORT/}" "$CONFIG_TOML"
sed -i "/^\[analytics\]/,/^\[/{s/^port = .*/port = $ANALYTICS_PORT/}" "$CONFIG_TOML"

# Fix additional_redirect_urls (supabase init writes a buggy https + no-wildcard default).
sed -i 's|additional_redirect_urls = \["https://127.0.0.1:3000"\]|additional_redirect_urls = ["http://127.0.0.1:3000/**", "http://localhost:3000/**"]|' "$CONFIG_TOML"

echo "apply-port-offset.sh: offset $OFFSET applied to $CONFIG_TOML"
echo "  API=$API_PORT DB=$DB_PORT Studio=$STUDIO_PORT Mailpit=$MAILPIT_PORT Analytics=$ANALYTICS_PORT"

DERIVE_SCRIPT="$PROJECT_ROOT/.devcontainer/derive-ports-from-config.sh"
if [ -f "$DERIVE_SCRIPT" ]; then
  echo "Running derive-ports-from-config.sh to propagate to .env..."
  bash "$DERIVE_SCRIPT" "$PROJECT_ROOT"
else
  echo "⚠ derive-ports-from-config.sh not found at $DERIVE_SCRIPT — .env not updated."
  echo "  Rebuild the devcontainer to propagate ports to .env."
fi
