#!/bin/bash
# What: Phase 0 preflight helper — bootstrap local Supabase for Gate 9 evidence, or report unavailable.
# Why: Hosted Supabase rate-limits signups aggressively (~30-min cooldown after 1-2 tries), which
#      turns Gate 9 into a "blocked (rate-limited)" result. Local Supabase has no limits and keeps
#      Gate 9 isolated from hosted-DB pollution during dev. Admin-API against hosted is the fallback
#      when Docker-in-Docker isn't available in the devcontainer.
# Does NOT: Install the Supabase CLI or Docker. Both must be provisioned by the devcontainer.
#           Does not touch hosted Supabase. Does not create migrations or seed files — expects them
#           to already exist at supabase/migrations/ and supabase/seed.sql.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
ENV_FILE="$PROJECT_ROOT/apps/web/.env.local"
BACKUP_FILE="$ENV_FILE.preship-backup"

MODE="${1:-up}"

case "$MODE" in
  up)
    # 1. CLI check — hard block. Without the CLI, Phase 0 can't do anything here.
    if ! command -v supabase >/dev/null 2>&1; then
      echo "error: supabase CLI not installed — install via devcontainer Dockerfile" >&2
      exit 2
    fi

    # 2. Docker check — advisory, not blocking. If Docker-in-Docker isn't available (common in the
    #    current devcontainer without --privileged), Gate 9 falls back to admin-API against hosted.
    if ! docker info >/dev/null 2>&1; then
      echo "unavailable: Docker not running — local Supabase cannot start; Gate 9 must use admin-API against hosted"
      exit 0
    fi

    # 3. Already running → reuse (idempotent).
    cd "$PROJECT_ROOT"
    if supabase status >/dev/null 2>&1; then
      echo "reused: local Supabase already running"
      exit 0
    fi

    # 4. Start.
    if ! supabase start >/dev/null 2>&1; then
      echo "error: supabase start failed — check Docker quota + supabase/config.toml" >&2
      exit 3
    fi

    # 5. Verify seed fixtures loaded. Gate 9's walk uses alice@test.local; absence means the seed
    #    file didn't replay and downstream tests will fail cryptically.
    if ! PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -d postgres \
         -tAc "SELECT count(*) FROM auth.users WHERE email IN ('alice@test.local', 'bob@test.local')" \
         2>/dev/null | grep -q '^2$'; then
      echo "error: seed fixtures missing (expected alice@test.local + bob@test.local in auth.users) — check supabase/seed.sql" >&2
      exit 4
    fi

    # 6. Extract anon_key from supabase status.
    ANON_KEY=$(supabase status --output env 2>/dev/null | grep '^ANON_KEY=' | cut -d= -f2- | tr -d '"' || true)
    if [ -z "$ANON_KEY" ]; then
      # Fallback to --output pretty parsing for older CLI versions.
      ANON_KEY=$(supabase status 2>/dev/null | grep -i 'anon key' | sed -E 's/.*:\s*//')
    fi
    if [ -z "$ANON_KEY" ]; then
      echo "error: could not extract anon_key from supabase status" >&2
      exit 5
    fi

    # 7. Back up + rewrite .env.local to point at local.
    if [ -f "$ENV_FILE" ]; then
      cp "$ENV_FILE" "$BACKUP_FILE"
      # Rewrite only the Supabase vars; preserve PostHog, Sentry, etc.
      sed -i.tmp \
        -e 's|^NEXT_PUBLIC_SUPABASE_URL=.*|NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321|' \
        -e "s|^NEXT_PUBLIC_SUPABASE_ANON_KEY=.*|NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY|" \
        "$ENV_FILE"
      rm -f "$ENV_FILE.tmp"
    else
      # No existing .env.local — create a minimal one with just Supabase vars.
      cat > "$ENV_FILE" <<ENV
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY
ENV
      # Sentinel so "down" knows to delete (not restore) — empty backup = new file.
      touch "$BACKUP_FILE.created"
    fi

    echo "ok: local Supabase up; .env.local rewritten (backup at .preship-backup)"
    ;;

  down)
    # Restore .env.local.
    if [ -f "$BACKUP_FILE.created" ]; then
      # We created the file from scratch; delete it.
      rm -f "$ENV_FILE" "$BACKUP_FILE.created"
    elif [ -f "$BACKUP_FILE" ]; then
      mv "$BACKUP_FILE" "$ENV_FILE"
    fi

    # Stop local Supabase if Docker + CLI both available.
    if command -v supabase >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      cd "$PROJECT_ROOT"
      supabase stop >/dev/null 2>&1 || true
    fi

    echo "down: .env.local restored; local Supabase stopped"
    ;;

  status)
    # Diagnostic — report what the bootstrap would do without side effects.
    if ! command -v supabase >/dev/null 2>&1; then
      echo "cli-missing"; exit 0
    fi
    if ! docker info >/dev/null 2>&1; then
      echo "docker-unavailable"; exit 0
    fi
    cd "$PROJECT_ROOT"
    if supabase status >/dev/null 2>&1; then
      echo "running"; exit 0
    fi
    echo "stopped"
    ;;

  *)
    echo "Usage: $0 [up|down|status]" >&2
    exit 1
    ;;
esac
