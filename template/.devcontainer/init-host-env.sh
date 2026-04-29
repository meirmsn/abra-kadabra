#!/bin/bash
# What: Runs on the HOST (macOS / Linux) before VS Code creates the dev
#       container — wired in via `initializeCommand` in devcontainer.json.
#       Writes LOCAL_WORKSPACE_FOLDER=<host-path> into .devcontainer/.env
#       so docker compose can interpolate it when resolving the
#       supabase-runner's path-mirrored bind mount.
# Why:  docker compose has no built-in interpolation for "host pwd" or
#       "compose file directory", and VS Code does not auto-export
#       ${localWorkspaceFolder} as a compose-readable env var (it ships
#       the path as a label, which compose can't interpolate). The
#       supabase-runner service needs to bind-mount the host's
#       <project>/supabase at the EXACT host path so paths in supabase
#       CLI's `docker run -v ...` calls resolve correctly on the host
#       engine when supabase CLI spawns its sibling containers (Postgres,
#       edge runtime, etc.). LOCAL_WORKSPACE_FOLDER carries that path
#       from the host into compose-time interpolation via the .env file
#       compose auto-reads from its project directory (.devcontainer/).
#       See /devshop/kit/notes/security/local-supabase-isolation-options.md
#       § Operational details for Option 3.
# Does NOT: assume the path is stable. Re-runs on every container start
#       (initializeCommand fires on Rebuild Container too) and refreshes
#       the value in case the project moved.

set -e

PROJECT_ROOT="${1:?usage: $0 <project-root>}"
ENV_FILE="$PROJECT_ROOT/.devcontainer/.env"

touch "$ENV_FILE"

# Strip any existing LOCAL_WORKSPACE_FOLDER line, then append the
# canonical one. Avoids sed regex-escaping issues with paths containing
# special characters.
{
  grep -v '^LOCAL_WORKSPACE_FOLDER=' "$ENV_FILE" || true
  printf 'LOCAL_WORKSPACE_FOLDER=%s\n' "$PROJECT_ROOT"
} > "$ENV_FILE.tmp"
mv "$ENV_FILE.tmp" "$ENV_FILE"

echo "init-host-env.sh: LOCAL_WORKSPACE_FOLDER=$PROJECT_ROOT in $ENV_FILE"
