#!/usr/bin/env bash
# What: Pre-ship advisor-clean gate. Runs `pnpm db:advisor` against the local
#       Supabase stack to surface DB-hardening gaps (function search_path,
#       auth.uid() initplan wrap, unindexed FKs, multiple permissives,
#       security_definer views, RLS disabled / no-policy, extension_in_public,
#       duplicate indexes) before they ship.
# Why:  These are the same lints Supabase's hosted Advisor runs. Catching them
#       locally closes the loop on the DB hardening contract codified at
#       kit/docs/guide/security.md § DB hardening — SQL conventions for
#       Supabase projects.
# Does NOT: install pg, install the local stack (preflight's
#       supabase-bootstrap.sh does that), or rewrite findings — operator
#       fixes them in a new migration.
#
# Usage: advisor-clean.sh [PROJECT_ROOT]
#        Stdout: "pass" / "n/a (...)" / "findings (N) ..." / "blocked (...)"
#        Exit 0 on completion (outcome reported via stdout).
#
# Bypass: git config devshop.advisorBypassReason "<per-finding rationale>"
#         The reason is run through adversarial-review.sh advisorBypassReason
#         (Sonnet-routed) — generic / scope-contradicting / no-tracker
#         reasons fail.

set -uo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MIG_DIR="$PROJECT_ROOT/supabase/migrations"
BASE_REF="${LOCAL_TESTS_BASE_REF:-origin/main}"

# --- Scope (n/a outcomes) ---

if [ ! -d "$MIG_DIR" ]; then
  echo "n/a (no supabase/migrations directory)"
  exit 0
fi

if [ ! -f "$PROJECT_ROOT/package.json" ]; then
  echo "n/a (no package.json - script wiring not present)"
  exit 0
fi

# Wiring check: project must have `db:advisor` script. Older projects from
# pre-2026-05-20 template lack it - they need the migration recipe at
# kit/docs/guide/security.md § DB hardening to backfill.
if ! grep -q '"db:advisor"' "$PROJECT_ROOT/package.json"; then
  echo "n/a (no db:advisor script in package.json - backfill from template per kit/docs/guide/security.md § DB hardening)"
  exit 0
fi

# Diff predicate: skip when the diff doesn't touch migrations or schema-shaped
# surfaces. Mirrors rls-coverage-check.sh and migration-rollback-roundtrip.sh.
diff_touches_db() {
  local diff_out
  if ! diff_out=$(cd "$PROJECT_ROOT" && git diff --name-only --diff-filter=AM "$BASE_REF"...HEAD 2>/dev/null); then
    # Base ref missing -> fail-open. Cheaper to run the probe than skip on
    # the very PR introducing the bug.
    return 0
  fi
  [ -z "$diff_out" ] && return 1
  printf '%s\n' "$diff_out" | grep -qE '^supabase/(migrations|functions)/'
}

if ! diff_touches_db; then
  echo "n/a (no migration or function changes in diff)"
  exit 0
fi

# --- Bypass (short-circuit before probe) ---

BYPASS_REASON="$(git -C "$PROJECT_ROOT" config --get devshop.advisorBypassReason 2>/dev/null || true)"
if [ -n "$BYPASS_REASON" ]; then
  ADVERSARIAL="/devshop/kit/scripts/adversarial-review.sh"
  if [ -x "$ADVERSARIAL" ] && [ -z "${DEVSHOP_SKIP_ADVERSARIAL:-}" ]; then
    if "$ADVERSARIAL" advisorBypassReason "$BYPASS_REASON" >/dev/null 2>&1; then
      echo "pass (skipped - adversarially reviewed)"
      echo "Bypass: $BYPASS_REASON"
      exit 0
    fi
    echo "findings (1) pending"
    echo "Bypass reason REJECTED by adversarial review (check-type advisorBypassReason)."
    echo "Reason: $BYPASS_REASON"
    echo "Either tighten the reason (per-finding rationale + TODOS pointer) or clear it: git config --unset devshop.advisorBypassReason"
    exit 0
  fi
  # Adversarial bypass intentionally disabled (CI / tight iteration loop).
  echo "pass (skipped - adversarial review disabled)"
  echo "Bypass: $BYPASS_REASON"
  exit 0
fi

# --- Probe ---

# Resolve DB port from environment or .devcontainer/.env, falling back to
# upstream default for legacy projects without derive-ports-from-config.sh.
DC_ENV="$PROJECT_ROOT/.devcontainer/.env"
if [ -z "${SUPABASE_DB_PORT:-}" ] && [ -f "$DC_ENV" ]; then
  SUPABASE_DB_PORT=$(grep -E '^SUPABASE_DB_PORT=' "$DC_ENV" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'' || true)
fi
SUPABASE_DB_PORT="${SUPABASE_DB_PORT:-54322}"

# Pre-flight Postgres reachability - surface a clear `blocked` rather than
# letting `pnpm db:advisor` produce an opaque connection error.
PG_OK=false
for candidate in \
    "postgresql://postgres:postgres@host.docker.internal:$SUPABASE_DB_PORT/postgres" \
    "postgresql://postgres:postgres@localhost:$SUPABASE_DB_PORT/postgres" \
    "postgresql://postgres:postgres@supabase-runner:$SUPABASE_DB_PORT/postgres"; do
  if PGPASSWORD=postgres psql "$candidate" -tAc 'SELECT 1' >/dev/null 2>&1; then
    PG_OK=true
    export DATABASE_URL="$candidate"
    break
  fi
done

if [ "$PG_OK" = false ]; then
  echo "blocked (local Supabase Postgres unreachable on host.docker.internal / localhost / supabase-runner :$SUPABASE_DB_PORT - Phase 0 supabase-bootstrap.sh should have started it; fix: re-run bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up or restart the supabase-runner container)"
  exit 0
fi

# Run the probe. Capture output; let the probe's exit code drive the gate
# outcome (0 = pass, 1 = findings, 2 = probe error / blocked).
# Capture rc directly (not behind `if !`, which masks the real exit code
# because $? in the then-branch is the exit of `!cmd`, always 0).
probe_out=$(cd "$PROJECT_ROOT" && DATABASE_URL="$DATABASE_URL" pnpm --silent db:advisor 2>&1)
probe_rc=$?

case "$probe_rc" in
  0)
    echo "$probe_out"
    exit 0
    ;;
  1)
    # Findings reported via stdout; advisor-probe.mjs already prints structured
    # output with `findings (N)` as the first line.
    echo "$probe_out"
    echo
    echo "Fix recipe: open kit/docs/guide/security.md § DB hardening for the"
    echo "rule each lint encodes, then ship a new migration. If a specific"
    echo "finding is intentional, annotate the migration with"
    echo "-- ADVISOR-EXEMPT(<lint_name>): <reason> (markers are scanned"
    echo "from supabase/migrations/). For repo-wide bypass: git config"
    echo "devshop.advisorBypassReason '<per-finding rationale>'."
    exit 0
    ;;
  2)
    # Probe error (couldn't connect, missing pg, etc).
    echo "blocked (advisor-probe failed): $(echo "$probe_out" | head -3 | tr '\n' ' ')"
    exit 0
    ;;
  *)
    echo "blocked (advisor-probe unexpected exit $probe_rc): $(echo "$probe_out" | head -3 | tr '\n' ' ')"
    exit 0
    ;;
esac
