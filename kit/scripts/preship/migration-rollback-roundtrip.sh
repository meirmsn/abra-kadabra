#!/usr/bin/env bash
# What: Pre-ship migration-rollback-roundtrip gate. For each migration with a
#       `-- ROLLBACK:` block, apply the rollback against the local Supabase
#       Postgres, then re-apply the forward migration (round-trip). Catches
#       rollback-block bugs (typos, invalid column references, non-defensive
#       ordering when the iterative rollback+reapply cascade changes schema
#       shape mid-loop) 30 seconds locally instead of ~10 min at CI slow-job.
#       FAILs as a finding when a migration lacks the required `-- ROLLBACK:`
#       marker or carries an empty block — markerless migrations get cascade-
#       dropped by upstream rollbacks without re-apply (home-os PR #28).
#       Mirrors the loud-fail contract of `template/scripts/ci-rollback-
#       explain.sh` so locally-green PRs don't surprise the operator at CI.
# Why:  home-os PR #26 (2026-05-16) + #27 (2026-05-17) both shipped to CI with
#       rollback bugs that a local check would have caught. Both gauntlets ran
#       /ak-pre-ship green pre-push because no existing local gate exercised
#       the rollback comment blocks — only `db:reset` / forward apply did.
#       home-os PR #28 (2026-05-18) added the markerless-cascade pattern to
#       the catch list (see ci-rollback-explain.sh for the 6-attempt CI
#       fix-loop background).
# Does NOT: validate WHERE / WITH CHECK predicates (integration tests do that),
#       run against a remote DB, or install / start the local Supabase stack
#       (Phase 0 preflight's supabase-bootstrap.sh does that; this gate
#       assumes the stack is up and probes both candidate endpoints).
#
# Usage: migration-rollback-roundtrip.sh [PROJECT_ROOT]
#        Stdout: "pass" / "n/a (...)" / "findings (N) ..." / "blocked (...)"
#        Exit 0 on completion (outcome reported via stdout). Exit 1 reserved
#        for internal error.

set -uo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MIG_DIR="$PROJECT_ROOT/supabase/migrations"
BASE_REF="${LOCAL_TESTS_BASE_REF:-origin/main}"

# --- Scope checks (n/a outcomes) ---

if [ ! -d "$MIG_DIR" ]; then
  echo "n/a (no supabase/migrations directory)"
  exit 0
fi

# Diff predicate: skip when the diff doesn't touch supabase/migrations/.
# Mirrors path-classifier.sh's stack-needing rule but scoped specifically to
# migrations — rollback round-trip only matters for migration changes.
diff_touches_migrations() {
  local diff_out
  if ! diff_out=$(cd "$PROJECT_ROOT" && git diff --name-only --diff-filter=AM "$BASE_REF"...HEAD 2>/dev/null); then
    # Base ref missing (e.g. fresh clone without origin/main) — fail-open and
    # run the gate. Cheaper to round-trip all migrations than to silently skip
    # on what could be the very PR introducing the bug.
    return 0
  fi
  [ -z "$diff_out" ] && return 1
  printf '%s\n' "$diff_out" | grep -qE '^supabase/migrations/'
}

if ! diff_touches_migrations; then
  echo "n/a (no migration changes in diff)"
  exit 0
fi

# Count migrations. Empty dir → n/a. Note: markerless migrations are NOT an
# n/a path anymore — they're a finding (see marker mandate in the round-trip
# loop below) per parity with template/scripts/ci-rollback-explain.sh. The
# n/a "rollback convention not adopted" path was dropped 2026-05-19 once the
# convention became mandatory devshop-wide.
mig_count=0
for migration in "$MIG_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  mig_count=$((mig_count + 1))
done

if [ "$mig_count" -eq 0 ]; then
  echo "n/a (no migration files in supabase/migrations/)"
  exit 0
fi

# --- DB URL discovery ---
#
# Resolve DB port from environment or .devcontainer/.env, falling back to
# upstream default for legacy projects without derive-ports-from-config.sh.
DC_ENV="$PROJECT_ROOT/.devcontainer/.env"
if [ -z "${SUPABASE_DB_PORT:-}" ] && [ -f "$DC_ENV" ]; then
  SUPABASE_DB_PORT=$(grep -E '^SUPABASE_DB_PORT=' "$DC_ENV" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"'"'"'' || true)
fi
SUPABASE_DB_PORT="${SUPABASE_DB_PORT:-54322}"

# Three reachability shapes (see supabase-bootstrap.sh `detect_shape`):
#   - compose isolation (template default since v1.23.0) → host.docker.internal:$SUPABASE_DB_PORT
#   - host Supabase (lifecycle on macOS host)            → host.docker.internal:$SUPABASE_DB_PORT
#   - docker-bind (legacy single-container)              → localhost:$SUPABASE_DB_PORT
#
# Phase 0 preflight runs supabase-bootstrap.sh up before this gate fires, so
# the stack is already running on one of these endpoints. Probe each in order;
# first one that responds is canonical.
DB_URL=""
for candidate in \
    "postgresql://postgres:postgres@host.docker.internal:$SUPABASE_DB_PORT/postgres" \
    "postgresql://postgres:postgres@localhost:$SUPABASE_DB_PORT/postgres"; do
  if PGPASSWORD=postgres psql "$candidate" -tAc 'SELECT 1' >/dev/null 2>&1; then
    DB_URL="$candidate"
    break
  fi
done

if [ -z "$DB_URL" ]; then
  echo "blocked (local Supabase Postgres unreachable on host.docker.internal:$SUPABASE_DB_PORT or localhost:$SUPABASE_DB_PORT — Phase 0 supabase-bootstrap.sh should have started it; fix: re-run \`bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up\` or restart the supabase-runner container from a macOS terminal)"
  exit 0
fi

# --- Extract rollback block from a single migration ---
#
# Mirrors template/scripts/ci-rollback-explain.sh extract_rollback: strip the
# leading `-- ` from every line after the `-- ROLLBACK:` marker so the body
# runs as plain SQL.
extract_rollback() {
  local file="$1"
  awk '
    /^-- ROLLBACK:/ { found=1; next }
    found {
      sub(/^-- ?/, "")
      print
    }
  ' "$file"
}

# Noop escape hatch: a rollback whose first non-blank line (after `-- ` strip)
# starts with `noop:` is treated as "nothing to undo". Skip the rollback apply
# step, still re-apply forward — that's what closes the cascade-loss hole for
# column-adding migrations whose forward is idempotent. Mirrors ci-rollback-
# explain.sh.
is_rollback_noop() {
  local body="$1"
  local first
  first=$(printf '%s\n' "$body" | grep -vE '^[[:space:]]*$' | head -1)
  first=$(printf '%s' "$first" | sed 's/^[[:space:]]*//')
  case "$first" in
    [Nn]oop:*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Round-trip loop ---
#
# For each migration in lexicographic order (matches `supabase migration` /
# Postgres apply order):
#   1. No `-- ROLLBACK:` marker → finding (mirrors ci-rollback-explain.sh
#      loud-fail contract — markerless migrations get cascade-dropped by
#      upstream rollbacks without re-apply, breaking the rest of CI).
#   2. Empty `-- ROLLBACK:` block → finding.
#   3. `-- noop: ...` body → skip rollback apply, re-apply forward only.
#   4. Otherwise → apply rollback via psql, then re-apply forward via psql.
# Capture per-migration failures into `findings`. Continue on failure (don't
# short-circuit) so the operator sees every problem in one pass.
findings=()
for migration in "$MIG_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  filename="$(basename "$migration")"

  if ! grep -q '^-- ROLLBACK:' "$migration"; then
    findings+=("$filename missing -- ROLLBACK: marker (add SQL or '-- noop: forward is idempotent')")
    continue
  fi

  rollback_sql="$(extract_rollback "$migration")"
  if [ -z "$(echo "$rollback_sql" | tr -d '[:space:]')" ]; then
    findings+=("$filename empty -- ROLLBACK: block (add SQL or '-- noop: forward is idempotent')")
    continue
  fi

  if is_rollback_noop "$rollback_sql"; then
    # Noop: skip rollback apply, still re-apply forward to restore state
    # upstream cascades may have dropped.
    reapply_err=""
    if ! reapply_err=$(PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration" 2>&1 >/dev/null); then
      err_line=$(echo "$reapply_err" | grep -m1 '^ERROR' || echo "$reapply_err" | head -1)
      findings+=("$filename forward re-apply FAILED (noop rollback): $err_line")
    fi
    continue
  fi

  # Apply rollback. Failure means the rollback block itself is broken (syntax
  # error, references a column / enum / type that doesn't exist in the
  # iterative-rollback-and-reapply ordering — cascades from earlier rollbacks
  # changed schema shape under it).
  rollback_err=""
  if ! rollback_err=$(PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 <<ROLLBACK_EOF 2>&1 >/dev/null
${rollback_sql}
ROLLBACK_EOF
  ); then
    err_line=$(echo "$rollback_err" | grep -m1 '^ERROR' || echo "$rollback_err" | head -1)
    findings+=("$filename rollback FAILED: $err_line")
    continue
  fi

  # Re-apply forward. Failure here means the rollback wasn't a true inverse:
  # it left the schema in a state the forward migration can't reapply against.
  # Also a real bug worth surfacing.
  reapply_err=""
  if ! reapply_err=$(PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration" 2>&1 >/dev/null); then
    err_line=$(echo "$reapply_err" | grep -m1 '^ERROR' || echo "$reapply_err" | head -1)
    findings+=("$filename forward re-apply FAILED after rollback: $err_line")
    continue
  fi
done

# --- Report ---

if [ "${#findings[@]}" -gt 0 ]; then
  echo "findings (${#findings[@]}) — migration marker / rollback round-trip failed:"
  for f in "${findings[@]}"; do echo "  - $f"; done
  echo
  echo "Missing-marker / empty-block findings: every migration MUST carry a"
  echo "  -- ROLLBACK: block (devshop convention — see kit/docs/guide/conventions.md"
  echo "  § ci-rollback-explain.sh). Markerless migrations get cascade-dropped by"
  echo "  upstream rollbacks without re-apply. Add SQL rollback lines or"
  echo "  '-- noop: forward is idempotent' if there is nothing to undo."
  echo "Round-trip failures: the rollback block doesn't apply cleanly OR doesn't"
  echo "  restore a schema the forward migration can reapply against. Common causes:"
  echo "  - Statement order assumes a fresh schema; cascades from earlier"
  echo "    migrations' rollbacks change column / enum / type shape under it."
  echo "    Make the rollback defensive (IF EXISTS, type casts that survive"
  echo "    narrowed enums, etc.)."
  echo "  - Typo / dropped-column reference / missing IF EXISTS clause."
  echo "Fix: edit the migration's -- ROLLBACK: block. Re-run this gate or the"
  echo "CI script directly: bash scripts/ci-rollback-explain.sh"
  exit 0
fi

echo "pass"
