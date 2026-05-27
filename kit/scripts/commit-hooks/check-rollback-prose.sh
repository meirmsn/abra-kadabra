#!/bin/sh
# What: Pre-commit lint for migration ROLLBACK blocks — catches prose lines that
#       would become SQL syntax errors after ci-rollback-explain.sh strips `-- ` prefixes.
# Why: Prose lines (e.g., "Restore the migration 006b version:") survive prefix-stripping
#      as bare English text that Postgres rejects with a syntax error. This lint catches
#      them at commit time instead of after an 8-minute CI round-trip.
# Does NOT: Enforce ROLLBACK block presence (ci-rollback-explain.sh's marker mandate does that).

set -eu

# Only run in project repos — devshop has no migration files.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Gather staged migration files (added, copied, modified).
STAGED_MIGRATIONS=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
  | grep '^supabase/migrations/.*\.sql$' || true)

[ -z "$STAGED_MIGRATIONS" ] && exit 0

found_prose=0

for file in $STAGED_MIGRATIONS; do
  full_path="$GIT_ROOT/$file"
  [ -f "$full_path" ] || continue

  # Check if file has a ROLLBACK block at all.
  if ! grep -q '^-- ROLLBACK:' "$full_path"; then
    # No ROLLBACK block — not our job to enforce (ci-rollback-explain.sh does that).
    continue
  fi

  # Extract lines after the `-- ROLLBACK:` marker, keeping the `-- ` prefix intact
  # so we can report accurate line numbers.
  in_rollback=0
  line_num=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    if [ "$in_rollback" -eq 0 ]; then
      case "$line" in
        "-- ROLLBACK:"*) in_rollback=1 ;;
      esac
      continue
    fi

    # We're inside the ROLLBACK block. Strip the `-- ` or `--` prefix.
    case "$line" in
      "-- "*)  stripped="${line#-- }" ;;
      "--"*)   stripped="${line#--}" ;;
      *)       # Line without `-- ` prefix after the ROLLBACK marker — skip
               # (could be blank line or actual SQL not in comment form).
               continue ;;
    esac

    # Skip empty / whitespace-only lines.
    trimmed=$(printf '%s' "$stripped" | sed 's/^[[:space:]]*//')
    [ -z "$trimmed" ] && continue

    # Get the first character to check skip conditions.
    first_char=$(printf '%s' "$trimmed" | cut -c1)

    # Skip lines starting with lowercase letter — SQL continuation.
    case "$first_char" in
      [a-z]) continue ;;
    esac

    # Skip lines starting with special characters (parens, quotes, dashes,
    # asterisks, digits) — SQL value lists, subqueries, string literals,
    # nested comments, list items, numeric literals.
    case "$first_char" in
      '('|')'|"'"|'"'|'-'|'*'|[0-9]) continue ;;
    esac

    # Get the first word (uppercase), stripping trailing punctuation (semicolons,
    # colons, parens) so `BEGIN;` matches `BEGIN`.
    first_word=$(printf '%s' "$trimmed" | awk '{print toupper($1)}' | sed 's/[^A-Z]$//')

    # Skip recognized SQL keywords. The D2 decision list plus common clause-
    # starting keywords that appear at line starts in multi-line rollback SQL.
    case "$first_word" in
      DROP|CREATE|ALTER|SELECT|INSERT|UPDATE|DELETE|SET|RESET|\
      GRANT|REVOKE|NOTIFY|BEGIN|COMMIT|ROLLBACK|DO|WITH|TRUNCATE|COMMENT|\
      WHERE|FROM|INTO|VALUES|ON|IF|ELSE|END|RETURN|RAISE|EXECUTE|\
      DECLARE|PERFORM|LOCK|CALL|REFRESH|REINDEX|ANALYZE|VACUUM|\
      PREPARE|DEALLOCATE|LISTEN|UNLISTEN|RELEASE|SAVEPOINT|ABORT|\
      USING|CHECK|CONSTRAINT|ADD|ENABLE|DISABLE|CASCADE|RESTRICT|\
      INDEX|TABLE|SCHEMA|VIEW|FUNCTION|PROCEDURE|TRIGGER|POLICY|\
      SEQUENCE|TYPE|DOMAIN|EXTENSION|RULE|COPY|REASSIGN)
        continue ;;
    esac

    # Skip noop: escape hatch (case-insensitive).
    # first_word is already uppercased and colon-stripped, so "noop:" → "NOOP".
    case "$first_word" in
      NOOP) continue ;;
    esac

    # This line looks like prose — flag it.
    printf '  %s:%d: %s\n' "$file" "$line_num" "$stripped"
    found_prose=1
  done < "$full_path"
done

if [ "$found_prose" -ne 0 ]; then
  echo ""
  echo "BLOCKING: prose lines detected in ROLLBACK block(s)."
  echo "  After ci-rollback-explain.sh strips the '-- ' prefix, these lines"
  echo "  become bare English text that Postgres rejects with a syntax error."
  echo ""
  echo "  Fix: rewrite as valid SQL, remove the line, or prefix with 'noop:'"
  echo "  if the rollback genuinely has nothing to undo."
  exit 1
fi

exit 0
