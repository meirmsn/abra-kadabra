#!/usr/bin/env bash
# What: Pre-ship migration-rollback-roundtrip gate. For each migration with a
#       `-- ROLLBACK:` block, apply the rollback against the local Supabase
#       Postgres, then re-apply the forward migration (round-trip). Catches
#       rollback-block bugs (typos, invalid column references, non-defensive
#       ordering when the iterative rollback+reapply cascade changes schema
#       shape mid-loop) 30 seconds locally instead of ~10 min at CI slow-job.
# Why:  home-os PR #26 (2026-05-16) + #27 (2026-05-17) both shipped to CI with
#       rollback bugs that a local check would have caught. Both gauntlets ran
#       /ak-pre-ship green pre-push because no existing local gate exercised
#       the rollback comment blocks — only `db:reset` / forward apply did. This
#       gate closes that gap.
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

# Are there any migrations with rollback blocks at all? If not, n/a — the
# project hasn't adopted the rollback convention yet. A hard finding here
# would surface noise on every migration PR for projects that don't ship
# rollback blocks; the convention check (Gate 11) is the right place to
# enforce adoption.
mig_count=0
rollback_count=0
for migration in "$MIG_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  mig_count=$((mig_count + 1))
  if grep -q '^-- ROLLBACK:' "$migration"; then
    rollback_count=$((rollback_count + 1))
  fi
done

if [ "$mig_count" -eq 0 ]; then
  echo "n/a (no migration files in supabase/migrations/)"
  exit 0
fi

if [ "$rollback_count" -eq 0 ]; then
  echo "n/a (no -- ROLLBACK: blocks in any migration — rollback convention not adopted)"
  exit 0
fi

# --- DB URL discovery ---
#
# Three reachability shapes (see supabase-bootstrap.sh `detect_shape`):
#   - compose isolation (template default since v1.23.0) → host.docker.internal:54322
#   - host Supabase (lifecycle on macOS host)            → host.docker.internal:54322
#   - docker-bind (legacy single-container)              → localhost:54322
#
# Phase 0 preflight runs supabase-bootstrap.sh up before this gate fires, so
# the stack is already running on one of these endpoints. Probe each in order;
# first one that responds is canonical.
DB_URL=""
for candidate in \
    "postgresql://postgres:postgres@host.docker.internal:54322/postgres" \
    "postgresql://postgres:postgres@localhost:54322/postgres"; do
  if PGPASSWORD=postgres psql "$candidate" -tAc 'SELECT 1' >/dev/null 2>&1; then
    DB_URL="$candidate"
    break
  fi
done

if [ -z "$DB_URL" ]; then
  echo "blocked (local Supabase Postgres unreachable on host.docker.internal:54322 or localhost:54322 — Phase 0 supabase-bootstrap.sh should have started it; fix: re-run \`bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up\` or restart the supabase-runner container from a macOS terminal)"
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

# --- Round-trip loop ---
#
# For each migration in lexicographic order (matches `supabase migration` /
# Postgres apply order):
#   1. If no ROLLBACK block → skip (mirrors CI script behavior).
#   2. Apply rollback SQL via psql with ON_ERROR_STOP=1.
#   3. Re-apply forward migration via psql -f.
# Capture per-migration failures into `findings`. Continue on failure (don't
# short-circuit) so the operator sees every broken rollback in one shot.
findings=()
for migration in "$MIG_DIR"/*.sql; do
  [ -f "$migration" ] || continue
  filename="$(basename "$migration")"

  if ! grep -q '^-- ROLLBACK:' "$migration"; then
    continue
  fi

  rollback_sql="$(extract_rollback "$migration")"
  if [ -z "$(echo "$rollback_sql" | tr -d '[:space:]')" ]; then
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
    # Capture only the first ERROR line — psql echoes the failing statement
    # context, which would bloat findings output.
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
  echo "findings (${#findings[@]}) — migration rollback round-trip failed:"
  for f in "${findings[@]}"; do echo "  - $f"; done
  echo
  echo "Each failure means the migration's -- ROLLBACK: block doesn't apply"
  echo "cleanly OR doesn't restore a schema the forward migration can reapply"
  echo "against. Common causes:"
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
