#!/usr/bin/env bash
# What: Pre-ship RLS-coverage gate. For every table that has RLS enabled and
#       is written to by client code through PostgREST (.from(t).insert/update/
#       delete/upsert), verify a matching CREATE POLICY exists in the project's
#       supabase/migrations.
# Why:  Lalista PR 5 shipped a silent bug where the `items` table had RLS
#       enabled but no `for insert` policy, so the force-create flow's writes
#       to `items` succeeded as zero-row no-ops at the client and produced no
#       error — invisible at compile time, invisible in unit tests, invisible
#       in /cso. This gate catches that class of gap deterministically.
# Does NOT: validate WHERE / WITH CHECK predicates (semantic correctness needs
#       integration tests against a live DB), check RPCs (SECURITY DEFINER
#       bypasses RLS by design), or replace /cso (security audit).
#
# Usage: rls-coverage-check.sh [PROJECT_ROOT]
#        Exits 0 with stdout "pass" / "n/a (...)" or "findings (N)" + table.
#        Exits 1 only on internal error.

set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MIG_DIR="$PROJECT_ROOT/supabase/migrations"

if [ ! -d "$MIG_DIR" ]; then
  echo "n/a (no supabase/migrations directory)"
  exit 0
fi

# 1. Tables with RLS enabled.
#    Match: alter table [public.]<name> enable row level security
RLS_TABLES=$(grep -rhEi '^\s*alter\s+table\s+(public\.)?[a-z_][a-z0-9_]*\s+enable\s+row\s+level\s+security' \
  "$MIG_DIR" 2>/dev/null \
  | sed -E 's/^\s*alter\s+table\s+(public\.)?([a-z_][a-z0-9_]*)\s+enable\s+row\s+level\s+security.*/\2/i' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u || true)

# 2. Policies — operation per table. Strip comments first; CREATE POLICY may
#    span multiple lines, so collapse statements (split on ; ) onto one line.
POLICIES=$(awk '
  # Strip line-trailing -- comments (but not inside strings — pragmatic shortcut).
  { sub(/--.*$/, ""); printf "%s ", $0 }
  END { print "" }
' "$MIG_DIR"/*.sql 2>/dev/null \
  | tr ';' '\n' \
  | grep -iE 'create\s+policy.*\son\s+(public\.)?[a-z_][a-z0-9_]*\s+(as\s+\w+\s+)?for\s+(select|insert|update|delete|all)' \
  | sed -E 's/.*\son\s+(public\.)?([a-z_][a-z0-9_]*)\s+(as\s+\w+\s+)?for\s+(select|insert|update|delete|all).*/\2:\4/i' \
  | tr '[:upper:]' '[:lower:]' \
  | sort -u || true)

# 3. Client write usages — .from('table').<insert|update|delete|upsert>(
#    Method chains often span lines, so use perl slurp-mode (-0777) instead of
#    line-oriented grep. Skip:
#    - Unit/integration tests (*.test.ts) — rarely represent prod call paths.
#    - E2E specs + helpers (apps/*/e2e/, *.spec.ts) — typically use the admin
#      client (service-role), which bypasses RLS by design.
#    - Edge functions that explicitly construct a service-role client are
#      reviewed manually under CLAUDE.md § Principle of least privilege; the
#      gate scans them anyway because the same file may also do anon writes.
SEARCH_DIRS=()
[ -d "$PROJECT_ROOT/apps" ] && SEARCH_DIRS+=("$PROJECT_ROOT/apps")
[ -d "$PROJECT_ROOT/packages" ] && SEARCH_DIRS+=("$PROJECT_ROOT/packages")
[ -d "$PROJECT_ROOT/supabase/functions" ] && SEARCH_DIRS+=("$PROJECT_ROOT/supabase/functions")

if [ "${#SEARCH_DIRS[@]}" -eq 0 ]; then
  USAGES=""
else
  USAGES=$(find "${SEARCH_DIRS[@]}" -type f \
    \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.mjs' \) \
    ! -name '*.test.ts' ! -name '*.test.tsx' ! -name '*.integration.test.ts' \
    ! -name '*.spec.ts' ! -name '*.spec.tsx' \
    ! -path '*/e2e/*' ! -path '*/tests/*' ! -path '*/__tests__/*' \
    -print0 2>/dev/null \
    | xargs -0 perl -0777 -ne '
        while (/\.from\(\s*[\x27"\x60]([a-z_][a-z0-9_]*)[\x27"\x60]\s*\)\s*(?:\.\s*\w+\s*\([^)]*\)\s*)*?\.\s*(insert|update|delete|upsert)\s*\(/gs) {
          print "$1:$2\n";
        }
      ' 2>/dev/null \
    | sort -u || true)
fi

# 4. Compare. Only flag tables with RLS enabled (otherwise no policy needed).
gaps=()
while IFS= read -r u; do
  [ -z "$u" ] && continue
  table="${u%%:*}"
  op="${u##*:}"

  # Skip tables without RLS — they don't need policies.
  if ! printf '%s\n' "$RLS_TABLES" | grep -qx "$table"; then
    continue
  fi

  # upsert ≈ insert + update; both required.
  case "$op" in
    upsert) required_ops="insert update" ;;
    *)      required_ops="$op"           ;;
  esac

  for required in $required_ops; do
    has_policy=false
    if printf '%s\n' "$POLICIES" | grep -qx "$table:$required"; then
      has_policy=true
    fi
    if printf '%s\n' "$POLICIES" | grep -qx "$table:all"; then
      has_policy=true
    fi
    if [ "$has_policy" = false ]; then
      gaps+=("$table $op (RLS enabled, no '$required' policy)")
    fi
  done
done <<< "$USAGES"

if [ "${#gaps[@]}" -gt 0 ]; then
  echo "findings (${#gaps[@]}) — client writes lacking RLS policy coverage:"
  for g in "${gaps[@]}"; do echo "  - $g"; done
  echo
  echo "Each gap means: the table has RLS enabled, client code writes to it,"
  echo "but no matching CREATE POLICY exists. Postgres + PostgREST will accept"
  echo "the call and silently affect zero rows — invisible at compile/unit time."
  echo "Fix: add the missing policy in a new migration (mirroring the existing"
  echo "policies on the table), or reroute the write through a SECURITY DEFINER"
  echo "RPC, or use the service-role admin client (last resort — see CLAUDE.md"
  echo "§ Principle of least privilege)."
  exit 0  # Reports findings via stdout; non-zero exit reserved for script errors.
fi

echo "pass"
