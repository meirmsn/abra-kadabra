#!/bin/bash
# What: Phase 0 preflight helper — bootstrap local Supabase for Gate 9 evidence, or report unavailable.
# Why: Hosted Supabase rate-limits signups aggressively (~30-min cooldown after 1-2 tries), which
#      turns Gate 9 into a "blocked (rate-limited)" result. Local Supabase has no limits and keeps
#      Gate 9 isolated from hosted-DB pollution during dev. Hosted-Supabase fallback is refused
#      under any shape (would pollute prod with real Gate-9 walk artifacts).
# Does NOT: install the Supabase CLI, Docker, or compose.yml/supabase-runner. The devcontainer
#      ships those (or doesn't, per the project's chosen reachability shape — see /ak-new-project §
#      Step 2b). Does not touch hosted Supabase. Does not create migrations/seed — expects them
#      to already exist at supabase/migrations/ and supabase/seed.sql.
#
# Reachability shape detection (auto):
#   - "compose"     : project ships .devcontainer/compose.yml + supabase-runner/. Workspace has
#                     no docker CLI; lifecycle drives through the cmd-relay on supabase-runner:9000.
#                     Data plane reached via host.docker.internal on the configured ports. (Template
#                     default since v1.23.0.)
#   - "docker-bind" : workspace has docker CLI + daemon access (legacy host-docker-socket bind-
#                     mount shape, no longer offered to new projects but supported here for
#                     existing projects scaffolded pre-v1.23.0).
#   - "host"        : workspace has neither docker CLI nor compose.yml, but the data plane is
#                     reachable at host.docker.internal:$SUPABASE_API_PORT — Host Supabase shape,
#                     where the operator runs `supabase start` from a macOS host terminal. This
#                     script can verify reachability + rewrite .env.local but cannot start/stop
#                     the stack (lifecycle lives on the macOS host).
#   - "none"        : nothing reachable. Report `blocked` with shape-specific fix recipe.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
ENV_FILE="$PROJECT_ROOT/apps/web/.env.local"
BACKUP_FILE="$ENV_FILE.preship-backup"

# Resolve Supabase ports from environment (set by compose.yml env_file) or
# .devcontainer/.env (for docker-bind / host shapes), falling back to
# upstream Supabase defaults (54321/54322) for legacy projects without
# derive-ports-from-config.sh.
DC_ENV="$PROJECT_ROOT/.devcontainer/.env"
_read_port() {
  local key="$1" default="$2"
  local val="${!key:-}"
  if [ -z "$val" ] && [ -f "$DC_ENV" ]; then
    val=$(grep -E "^${key}=" "$DC_ENV" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'' || true)
  fi
  printf '%s' "${val:-$default}"
}
SUPABASE_API_PORT=$(_read_port SUPABASE_API_PORT 54321)
SUPABASE_DB_PORT=$(_read_port SUPABASE_DB_PORT 54322)

MODE="${1:-up}"

RELAY_URL="http://supabase-runner:9000"

# Path classifier (sub-fix 3) — used by emit_degraded_outcome to decide whether
# a degraded-stack situation should hard-block or fall back to legacy
# pass-with-note. Tests can override via PATH_CLASSIFIER_SCRIPT.
PATH_CLASSIFIER_SCRIPT="${PATH_CLASSIFIER_SCRIPT:-$DEVSHOP/kit/scripts/preship/path-classifier.sh}"

# D6 decision: read git config devshop.requireHealthyLocalStack and decide
# whether the current `blocked:` situation should be promoted to a hard block
# or downgraded to `pass-with-note:` advisory. The orchestrator treats
# `blocked:` as halt and `pass-with-note:` as continue-with-note.
#
# Args: $1 = the message to emit (without the leading token).
# Stdout: either `blocked: <msg>` or `pass-with-note: <msg>`.
emit_degraded_outcome() {
  local msg="$1"
  # Read config; treat unset as "when-relevant".
  local cfg
  cfg=$(cd "$PROJECT_ROOT" 2>/dev/null && git config --get devshop.requireHealthyLocalStack 2>/dev/null || true)
  [ -z "$cfg" ] && cfg="when-relevant"
  case "$cfg" in
    never)
      # Explicit opt-out: legacy pass-with-note regardless of diff.
      echo "pass-with-note: $msg"
      return
      ;;
    always)
      # Aspirational strict: hard block regardless of diff.
      echo "blocked: $msg"
      return
      ;;
    when-relevant|*)
      # Default: hard-block only when the diff is stack-needing AND we can
      # actually classify the diff. If the classifier is unavailable OR the
      # base ref is missing (git error → exit 2), fail-safe to `blocked:` so
      # a missing tool / missing remote can't silently downgrade the gate.
      if [ -x "$PATH_CLASSIFIER_SCRIPT" ] || [ -f "$PATH_CLASSIFIER_SCRIPT" ]; then
        local rc=0
        (cd "$PROJECT_ROOT" && bash "$PATH_CLASSIFIER_SCRIPT" diff-needs-stack "${LOCAL_TESTS_BASE_REF:-origin/main}" >/dev/null 2>&1) || rc=$?
        case "$rc" in
          0) echo "blocked: $msg" ;;        # diff has stack-needing paths
          1) echo "pass-with-note: $msg" ;; # docs-only diff
          *) echo "blocked: $msg" ;;        # git error / classifier failure → fail-safe
        esac
      else
        # Classifier unavailable → fall back to legacy `blocked:` (the safer
        # default — orchestrator halts on it; better than silently letting
        # a stack-needing diff slip through).
        echo "blocked: $msg"
      fi
      return
      ;;
  esac
}

# Detect which reachability shape this project is on. Read-only, side-effect-free.
detect_shape() {
  if [ -f "$PROJECT_ROOT/.devcontainer/compose.yml" ] && [ -d "$PROJECT_ROOT/.devcontainer/supabase-runner" ]; then
    echo "compose"
    return
  fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "docker-bind"
    return
  fi
  # Host Supabase: data plane reachable at host.docker.internal:$SUPABASE_API_PORT even though
  # workspace has no docker tooling. -fsS exits 22 on HTTP 4xx (kong returns 401 on bare /),
  # which confirms the listener is up. exit 7 (couldn't connected) → not reachable.
  if curl -sS -m 2 "http://host.docker.internal:$SUPABASE_API_PORT" -o /dev/null 2>/dev/null; then
    echo "host"
    return
  fi
  # curl returned non-zero — treat 22 (HTTP 4xx, listener alive) as host-supabase-reachable.
  if [ "$?" = "22" ]; then
    echo "host"
    return
  fi
  echo "none"
}

case "$MODE" in
  up)
    # 1. CLI check — hard block. Without the CLI, workspace can't run `supabase migration new`
    #    or any of the filesystem-only supabase commands, even under compose isolation where
    #    lifecycle is relay-driven (the workspace still uses supabase CLI for non-runtime ops).
    if ! command -v supabase >/dev/null 2>&1; then
      echo "error: supabase CLI not installed — install via devcontainer Dockerfile" >&2
      exit 2
    fi

    SHAPE=$(detect_shape)

    case "$SHAPE" in
      compose)
        # Check relay reachability via /status (which runs `supabase status` inside the runner).
        # curl exit code mapping:
        #   0  → relay alive AND stack running (supabase status returned 0; relay returned HTTP 200)
        #   22 → relay alive but stack not running (supabase status non-zero; relay returned HTTP 500)
        #   7  → relay unreachable (couldn't connect)
        #   28 → relay unreachable (timeout)
        STATUS_RC=0
        curl -fsS -m 5 "$RELAY_URL/status" -o /dev/null 2>/dev/null || STATUS_RC=$?

        if [ "$STATUS_RC" = "0" ]; then
          echo "reused: local Supabase already running (via cmd-relay)"
        elif [ "$STATUS_RC" = "22" ]; then
          # Relay alive, stack down — start via relay /start (runs `supabase start` inside runner).
          # First start can take 30-60s; allow generous timeout.
          if ! curl -fsS -X POST -m 180 "$RELAY_URL/start" -o /dev/null 2>/dev/null; then
            echo "error: relay-driven supabase start failed — check \`docker logs <project>_devcontainer-supabase-runner-1\` from a macOS terminal" >&2
            exit 3
          fi
        else
          emit_degraded_outcome "cmd-relay on supabase-runner:9000 unreachable (curl exit $STATUS_RC). Compose isolation requires the supabase-runner sibling container to be running. Fix: from a macOS terminal, restart the runner (\`docker restart <project>_devcontainer-supabase-runner-1\`), or rebuild the devcontainer (Cmd+Shift+P → Dev Containers: Rebuild Container)."
          exit 0
        fi

        # Verify seed fixtures via Postgres (data plane at host.docker.internal:$SUPABASE_DB_PORT under compose).
        if ! PGPASSWORD=postgres psql -h host.docker.internal -p "$SUPABASE_DB_PORT" -U postgres -d postgres \
             -tAc "SELECT count(*) FROM auth.users WHERE email IN ('alice@test.local', 'bob@test.local')" \
             2>/dev/null | grep -q '^2$'; then
          echo "error: seed fixtures missing (expected alice@test.local + bob@test.local in auth.users) — check supabase/seed.sql, then re-run \`pnpm db:reset\`" >&2
          exit 4
        fi

        # Under compose isolation, compose.yml's environment block already exposes
        # SUPABASE_URL via compose env + the published local-stack JWTs as
        # SUPABASE_ANON_KEY. Use those rather than re-extracting via the relay.
        if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
          echo "error: SUPABASE_URL or SUPABASE_ANON_KEY not in workspace env — compose.yml's services.workspace.environment block should set both" >&2
          exit 5
        fi
        _LOCAL_URL="$SUPABASE_URL"
        _LOCAL_ANON_KEY="$SUPABASE_ANON_KEY"
        ;;

      docker-bind)
        # Legacy shape: workspace holds docker socket + supabase CLI talks to it directly.
        # Already running → reuse (idempotent).
        cd "$PROJECT_ROOT"
        if supabase status >/dev/null 2>&1; then
          echo "reused: local Supabase already running"
        else
          if ! supabase start >/dev/null 2>&1; then
            echo "error: supabase start failed — check Docker quota + supabase/config.toml" >&2
            exit 3
          fi
        fi

        if ! PGPASSWORD=postgres psql -h localhost -p "$SUPABASE_DB_PORT" -U postgres -d postgres \
             -tAc "SELECT count(*) FROM auth.users WHERE email IN ('alice@test.local', 'bob@test.local')" \
             2>/dev/null | grep -q '^2$'; then
          echo "error: seed fixtures missing (expected alice@test.local + bob@test.local in auth.users) — check supabase/seed.sql" >&2
          exit 4
        fi

        _LOCAL_URL="http://localhost:$SUPABASE_API_PORT"
        _LOCAL_ANON_KEY=$(supabase status --output env 2>/dev/null | grep '^ANON_KEY=' | cut -d= -f2- | tr -d '"' || true)
        if [ -z "$_LOCAL_ANON_KEY" ]; then
          # Fallback to --output pretty parsing for older CLI versions.
          _LOCAL_ANON_KEY=$(supabase status 2>/dev/null | grep -i 'anon key' | sed -E 's/.*:\s*//')
        fi
        if [ -z "$_LOCAL_ANON_KEY" ]; then
          echo "error: could not extract anon_key from supabase status" >&2
          exit 5
        fi
        ;;

      host)
        # Host Supabase: data plane is reachable but lifecycle lives on the macOS host.
        # Treat as reused — Phase 0 doesn't try to manage start/stop.
        echo "reused: local Supabase reachable at host.docker.internal (Host Supabase shape — lifecycle managed from macOS terminal)"

        # Verify seed via Postgres on host.docker.internal:$SUPABASE_DB_PORT.
        if ! PGPASSWORD=postgres psql -h host.docker.internal -p "$SUPABASE_DB_PORT" -U postgres -d postgres \
             -tAc "SELECT count(*) FROM auth.users WHERE email IN ('alice@test.local', 'bob@test.local')" \
             2>/dev/null | grep -q '^2$'; then
          echo "error: seed fixtures missing (expected alice@test.local + bob@test.local in auth.users) — check supabase/seed.sql, then run \`supabase db reset\` from your macOS host terminal" >&2
          exit 4
        fi

        # ANON_KEY: published well-known supabase-local default JWT (same across every install).
        # Hardcoded here to avoid forcing the workspace to shell out to a CLI it can't run under
        # Host Supabase (no docker daemon access).
        _LOCAL_URL="http://host.docker.internal:$SUPABASE_API_PORT"
        _LOCAL_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
        ;;

      none)
        emit_degraded_outcome "no local Supabase reachable. Detection fell through (no compose.yml + supabase-runner/, no docker daemon, no listener at host.docker.internal:$SUPABASE_API_PORT). Refusing hosted-Supabase fallback (would pollute prod). Fix: rebuild the devcontainer with one of the supported shapes — compose isolation (template default; see /devshop/kit/docs/guide/local-supabase-compose-isolation.md), Host Supabase (\`brew install supabase/tap/supabase\` on macOS host + \`supabase start\` from host terminal), or run on a machine with Docker."
        exit 0
        ;;
    esac

    # Common: rewrite .env.local using $_LOCAL_URL + $_LOCAL_ANON_KEY.
    if [ -f "$ENV_FILE" ]; then
      cp "$ENV_FILE" "$BACKUP_FILE"
      sed -i.tmp \
        -e "s|^NEXT_PUBLIC_SUPABASE_URL=.*|NEXT_PUBLIC_SUPABASE_URL=$_LOCAL_URL|" \
        -e "s|^NEXT_PUBLIC_SUPABASE_ANON_KEY=.*|NEXT_PUBLIC_SUPABASE_ANON_KEY=$_LOCAL_ANON_KEY|" \
        "$ENV_FILE"
      rm -f "$ENV_FILE.tmp"
    else
      cat > "$ENV_FILE" <<ENV
NEXT_PUBLIC_SUPABASE_URL=$_LOCAL_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$_LOCAL_ANON_KEY
ENV
      touch "$BACKUP_FILE.created"
    fi

    echo "ok: local Supabase up; .env.local rewritten (backup at .preship-backup)"
    ;;

  down)
    # Restore .env.local.
    if [ -f "$BACKUP_FILE.created" ]; then
      rm -f "$ENV_FILE" "$BACKUP_FILE.created"
    elif [ -f "$BACKUP_FILE" ]; then
      mv "$BACKUP_FILE" "$ENV_FILE"
    fi

    # Stop local Supabase (best-effort; only stops if THIS script is responsible for lifecycle).
    SHAPE=$(detect_shape)
    case "$SHAPE" in
      compose)
        # Stop via relay (best-effort).
        curl -fsS -X POST -m 60 "$RELAY_URL/stop" -o /dev/null 2>/dev/null || true
        ;;
      docker-bind)
        if command -v supabase >/dev/null 2>&1 && command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
          cd "$PROJECT_ROOT"
          supabase stop >/dev/null 2>&1 || true
        fi
        ;;
      host|none)
        # Host Supabase: lifecycle on macOS, don't touch. None: nothing to stop.
        ;;
    esac

    echo "down: .env.local restored; local Supabase stopped"
    ;;

  status)
    if ! command -v supabase >/dev/null 2>&1; then
      echo "cli-missing"; exit 0
    fi

    SHAPE=$(detect_shape)
    case "$SHAPE" in
      compose)
        STATUS_RC=0
        curl -fsS -m 5 "$RELAY_URL/status" -o /dev/null 2>/dev/null || STATUS_RC=$?
        case "$STATUS_RC" in
          0)  echo "running" ;;
          22) echo "stopped" ;;
          *)  echo "relay-unreachable" ;;
        esac
        ;;
      docker-bind)
        cd "$PROJECT_ROOT"
        if supabase status >/dev/null 2>&1; then
          echo "running"
        else
          echo "stopped"
        fi
        ;;
      host)
        # Data plane reachable → running. Lifecycle on macOS, can't query "stopped" precisely.
        echo "running"
        ;;
      none)
        echo "docker-unavailable"
        ;;
    esac
    ;;

  *)
    echo "Usage: $0 [up|down|status]" >&2
    exit 1
    ;;
esac
