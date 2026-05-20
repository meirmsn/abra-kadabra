#!/usr/bin/env bats
# Tests for template/scripts/advisor-probe.mjs — assert the script defines
# all 9 lints, parses ADVISOR-EXEMPT markers, and reports a clear blocked
# message when `pg` is missing or the DB is unreachable. Live Postgres-
# connected tests are covered indirectly by the advisor-clean gate against
# a real local Supabase stack.

setup() {
  load helpers/setup
  PROBE="${TESTS_DIR%/}/../../template/scripts/advisor-probe.mjs"
  # Resolve via realpath so symlinked test layouts work.
  PROBE="$(cd "$(dirname "$PROBE")" 2>/dev/null && pwd)/$(basename "$PROBE")"
}

@test "probe script exists and is syntactically valid" {
  [ -f "$PROBE" ]
  run node --check "$PROBE"
  assert_success
}

@test "probe defines all 9 advisor lints" {
  run grep -c 'async function lint' "$PROBE"
  assert_success
  assert_output "9"
}

@test "probe driver's lints array references all 9 lint functions" {
  # Defense against "lint defined but not invoked" — catches the gap where
  # someone adds a new lintFoo function but forgets to add it to the
  # `const lints = [...]` array in main(). Source-grep is sufficient because
  # the regex is anchored to the array literal's slice.
  run bash -c "awk '/const lints = \\[/{f=1; next} f && /^\\s*\\];/{exit} f' '$PROBE' | grep -c 'lint[A-Z]'"
  assert_success
  assert_output "9"
}

@test "probe names match documented lint IDs" {
  for lint in \
      function_search_path_mutable \
      auth_rls_initplan \
      unindexed_foreign_key \
      multiple_permissive_policies \
      security_definer_view \
      rls_disabled_in_public \
      rls_enabled_no_policy \
      extension_in_public \
      duplicate_index; do
    run grep -F "\"$lint\"" "$PROBE"
    assert_success
  done
}

@test "probe parses ADVISOR-EXEMPT markers from migrations" {
  run grep -E 'ADVISOR-EXEMPT\\\(' "$PROBE"
  assert_success
  # Confirm exemption set is consulted before emitting findings.
  run grep -E 'exemptions\.has\(' "$PROBE"
  assert_success
}

@test "probe emits 'blocked: pg' when pg dep is missing" {
  # The script's top-level try/catch around `import('pg')` should print a
  # clear remediation. Search the source for the message rather than running
  # the script (running it requires a controlled missing-pg env).
  run grep -F "blocked: 'pg' is not installed" "$PROBE"
  assert_success
}

@test "probe reports 'blocked' when DATABASE_URL cannot connect" {
  run grep -F "blocked: cannot connect to" "$PROBE"
  assert_success
}
