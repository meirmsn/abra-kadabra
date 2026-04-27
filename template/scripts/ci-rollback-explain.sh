#!/usr/bin/env bash
# What: For each `supabase/migrations/*.sql` file with a `-- ROLLBACK:` block,
#       apply the rollback statement against the local Postgres, then
#       re-apply the forward migration (round-trip).
#       Fail on any non-zero exit.
# Why: Catches rollback-block syntax errors (typos, invalid column
#       references, missing `if exists`) before they bite us in prod where
#       the only time we run rollbacks is during an outage.
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

failed=0
for migration in "$MIGRATIONS_DIR"/*.sql; do
  filename="$(basename "$migration")"
  if ! grep -q '^-- ROLLBACK:' "$migration"; then
    echo "SKIP: $filename (no ROLLBACK block)"
    continue
  fi

  rollback_sql="$(extract_rollback "$migration")"
  if [ -z "$(echo "$rollback_sql" | tr -d '[:space:]')" ]; then
    echo "SKIP: $filename (empty ROLLBACK block)"
    continue
  fi

  echo "CHECK: $filename"

  # Apply the rollback + re-apply the forward migration (round-trip).
  # Reapply so subsequent migrations (which may depend on this one's forward
  # state) still apply cleanly. psql with `-v ON_ERROR_STOP=1` fails loudly
  # on any statement error — catches every failure mode EXPLAIN would (typos,
  # invalid column references, missing `if exists`, constraint violations)
  # plus real failures that only show up at apply time (data incompatibility,
  # privilege errors).
  if ! PGPASSWORD=postgres psql "$DB_URL" -v ON_ERROR_STOP=1 <<ROLLBACK_EOF >/dev/null
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
