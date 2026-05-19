#!/usr/bin/env bash
# What: For every `supabase/migrations/*.sql` file, require a `-- ROLLBACK:`
#       block, apply the rollback statement against the local Postgres, then
#       re-apply the forward migration (round-trip). FAIL loudly on any
#       migration that lacks a `-- ROLLBACK:` marker or carries an empty
#       block — silent skip caused home-os PR #28's 6-attempt CI fix-loop
#       (markerless migration's column cascade-dropped, never restored,
#       PostgREST 204 for the rest of CI).
# Why:  Catches rollback-block syntax errors (typos, invalid column
#       references, missing `if exists`) before they bite us in prod where
#       the only time we run rollbacks is during an outage. The marker
#       mandate also forces "did I think about how to roll this back?" at
#       code-review time. Migrations with nothing to undo can ship a
#       single-line `-- noop: forward is idempotent` body — the script
#       still re-applies forward, which closes the cascade-loss hole.
# Does NOT: Apply migrations to any remote DB. `supabase start` must be
#       running locally first.
#
# Quirk: The forward migration must be applied before exercising the
#       rollback (rollback can't drop what doesn't exist). `supabase
#       db reset` (called earlier in the slow-job pipeline) leaves every
#       forward migration applied, so the initial state is correct.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIGRATIONS_DIR="${REPO_ROOT}/supabase/migrations"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "ERROR: $MIGRATIONS_DIR not found." >&2
  exit 1
fi

# Get the local DB URL from `supabase status`. Falls back to the stock
# connection string if `supabase status -o env` shape changes.
DB_URL="$(supabase status -o env 2>/dev/null | awk -F= '/^DB_URL=/{print $2}' | tr -d '"')"
if [ -z "$DB_URL" ]; then
  DB_URL='postgresql://postgres:postgres@127.0.0.1:54322/postgres'
  echo "WARN: falling back to default DB_URL $DB_URL" >&2
fi

# Extract the `-- ROLLBACK:` block from a migration file. Lines after the
# marker, stripped of leading `-- ` so they run as plain SQL.
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
# starts with `noop:` is treated as "nothing to undo". The rollback step is
# skipped but forward re-apply still runs — that's what closes the cascade-
# loss hole for column-adding migrations whose forward is idempotent.
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

# Marker mandate. Every migration MUST carry a `-- ROLLBACK:` block. Markerless
# migrations get cascade-dropped by upstream rollbacks without being re-applied
# (home-os PR #28 — column gone from DB → PGRST204 for the rest of CI). For
# migrations with nothing to undo, the body can be `-- noop: forward is
# idempotent`; the script still re-applies forward, which closes the hole.
# See `kit/docs/guide/conventions.md` (devshop) entry on `ci-rollback-explain.sh`.
missing_marker=()
empty_block=()
for migration in "$MIGRATIONS_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  filename="$(basename "$migration")"
  if ! grep -q '^-- ROLLBACK:' "$migration"; then
    missing_marker+=("$filename")
    continue
  fi
  rollback_sql="$(extract_rollback "$migration")"
  if [ -z "$(echo "$rollback_sql" | tr -d '[:space:]')" ]; then
    empty_block+=("$filename")
  fi
done

if [ "${#missing_marker[@]}" -gt 0 ] || [ "${#empty_block[@]}" -gt 0 ]; then
  echo "FAIL: every migration must carry a -- ROLLBACK: block." >&2
  if [ "${#missing_marker[@]}" -gt 0 ]; then
    echo "  Missing -- ROLLBACK: marker:" >&2
    for f in "${missing_marker[@]}"; do echo "    - $f" >&2; done
  fi
  if [ "${#empty_block[@]}" -gt 0 ]; then
    echo "  Empty -- ROLLBACK: block (add SQL or a -- noop: line):" >&2
    for f in "${empty_block[@]}"; do echo "    - $f" >&2; done
  fi
  echo >&2
  echo "Fix: append a -- ROLLBACK: block at the bottom of each migration." >&2
  echo "  - Schema-mutating migrations: list the reverse statements as SQL" >&2
  echo "    comments (drop column / drop index / drop table) prefixed by '-- '." >&2
  echo "  - Migrations with nothing to undo (data-only, idempotent forward):" >&2
  echo "    use a single body line '-- noop: forward is idempotent'." >&2
  echo "Background: markerless migrations were silently skipped, so upstream" >&2
  echo "rollback cascades dropped their state without restoring it — home-os" >&2
  echo "PR #28 burned 6 CI attempts on PGRST204 chasing this exact pattern." >&2
  exit 1
fi

failed=0
for migration in "$MIGRATIONS_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  filename="$(basename "$migration")"
  rollback_sql="$(extract_rollback "$migration")"

  echo "CHECK: $filename"

  # Apply the rollback + re-apply the forward migration (round-trip).
  # Reapply so subsequent migrations (which may depend on this one's forward
  # state) still apply cleanly. psql with `-v ON_ERROR_STOP=1` fails loudly
  # on any statement error — catches every failure mode EXPLAIN would (typos,
  # invalid column references, missing `if exists`, constraint violations)
  # plus real failures that only show up at apply time (data incompatibility,
  # privilege errors). Noop bodies (`-- noop: ...`) skip the rollback step
  # but still re-apply forward, restoring state lost to upstream cascades.
  if is_rollback_noop "$rollback_sql"; then
    echo "  NOOP: $filename (rollback declared noop, re-applying forward only)"
  elif ! PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 <<ROLLBACK_EOF >/dev/null
${rollback_sql}
ROLLBACK_EOF
  then
    echo "  FAIL: rollback didn't APPLY cleanly in $filename" >&2
    failed=1
    continue
  fi

  if ! PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration" >/dev/null; then
    echo "  FAIL: forward re-apply failed after rollback in $filename" >&2
    failed=1
    continue
  fi

  echo "  OK: $filename"
done

if [ $failed -ne 0 ]; then
  echo "One or more migrations failed rollback validation." >&2
  exit 1
fi

echo "OK: all migrations' rollback blocks apply + round-trip cleanly."
