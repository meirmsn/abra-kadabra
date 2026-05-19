#!/usr/bin/env bats
# Tests for kit/scripts/preship/migration-rollback-roundtrip.sh
# Pre-ship gate that round-trips each migration's `-- ROLLBACK:` block against
# local Supabase Postgres. Catches the silent class home-os PR #26 + #27 hit
# (rollback blocks broken under iterative rollback+reapply cascades — invisible
# in db:reset / forward-apply gates, only surfaces at CI's 10-min slow-job).

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/migration-rollback-roundtrip.sh"
}

# Run with isolated PATH so no real psql leaks in from the host environment.
run_script() {
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LOCAL_TESTS_BASE_REF="${LOCAL_TESTS_BASE_REF:-HEAD~1}" \
      bash "$SCRIPT" "$TEST_REPO"
}

# Write a migration file at supabase/migrations/<name>.sql with given content.
write_migration() {
  local name="$1"
  mkdir -p "$TEST_REPO/supabase/migrations"
  cat > "$TEST_REPO/supabase/migrations/$name.sql"
}

# Commit current working tree state in TEST_REPO with given message.
commit_repo() {
  local msg="${1:-update}"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "$msg"
}

# Default psql mock: probe succeeds, every other call succeeds.
mock_psql_all_pass() {
  cat > "$MOCK_BIN/psql" <<'STUB'
#!/bin/bash
# Probe call: -tAc 'SELECT 1' — exit 0 (DB reachable).
# Rollback / forward-apply calls — exit 0 (clean).
exit 0
STUB
  chmod +x "$MOCK_BIN/psql"
}

# psql mock: probe fails on both candidate URLs.
mock_psql_unreachable() {
  cat > "$MOCK_BIN/psql" <<'STUB'
#!/bin/bash
exit 2
STUB
  chmod +x "$MOCK_BIN/psql"
}

# psql mock: probe passes; rollback (heredoc SQL) fails with a fixed error.
mock_psql_rollback_fails() {
  cat > "$MOCK_BIN/psql" <<'STUB'
#!/bin/bash
# Probe: -tAc 'SELECT 1' → pass.
for arg in "$@"; do
  if [ "$arg" = "SELECT 1" ]; then
    exit 0
  fi
done
# -f <file> form → forward re-apply, succeed.
for ((i=1; i<=$#; i++)); do
  eval arg=\"\$$i\"
  if [ "$arg" = "-f" ]; then
    exit 0
  fi
done
# Otherwise heredoc rollback path → fail with a recognizable ERROR.
echo 'ERROR:  column "tool_name" does not exist' >&2
exit 1
STUB
  chmod +x "$MOCK_BIN/psql"
}

# psql mock: probe passes; rollback passes; forward re-apply (-f) fails.
mock_psql_reapply_fails() {
  cat > "$MOCK_BIN/psql" <<'STUB'
#!/bin/bash
for arg in "$@"; do
  if [ "$arg" = "SELECT 1" ]; then
    exit 0
  fi
done
# -f <file> → forward re-apply, fail.
for ((i=1; i<=$#; i++)); do
  eval arg=\"\$$i\"
  if [ "$arg" = "-f" ]; then
    echo 'ERROR:  relation "items" already exists' >&2
    exit 1
  fi
done
# Heredoc rollback path → success.
exit 0
STUB
  chmod +x "$MOCK_BIN/psql"
}

# --- n/a outcomes ---

@test "n/a when no supabase/migrations directory" {
  run_script
  assert_success
  assert_output --partial "n/a (no supabase/migrations directory)"
}

@test "n/a when supabase/migrations exists but is empty" {
  mkdir -p "$TEST_REPO/supabase/migrations"
  write_migration touch-trigger <<'SQL'
-- placeholder
SQL
  commit_repo "add migrations dir"
  # Force diff predicate to skip migrations by setting base ref to HEAD itself.
  LOCAL_TESTS_BASE_REF="HEAD" run_script
  assert_success
  # Either "no migration changes" or "no -- ROLLBACK: blocks" — the gate
  # short-circuits at the first predicate that holds. Empty rollback content
  # means n/a (no -- ROLLBACK: blocks); empty diff means n/a (no migration
  # changes in diff). Both are valid skip outcomes.
  assert_output --partial "n/a"
}

@test "n/a when migrations exist but diff doesn't touch them" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  commit_repo "add baseline migration"
  # Make a non-migration change so HEAD-1 → HEAD diff exists but doesn't
  # touch supabase/migrations/.
  echo "readme content" > "$TEST_REPO/README.md"
  commit_repo "non-migration change"
  run_script
  assert_success
  assert_output --partial "n/a (no migration changes in diff)"
}

@test "findings: markerless migration surfaces as a finding (parity with template ci-rollback-explain.sh)" {
  # Markerless was an n/a path pre-2026-05-19 ("rollback convention not adopted").
  # Now mandatory devshop-wide — markerless → finding, mirrors CI script.
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  commit_repo "add migration without rollback block"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output --partial "findings (1)"
  assert_output --partial "001.sql missing -- ROLLBACK: marker"
  # Recipe surfaces the noop escape hatch so operators know the way out.
  assert_output --partial "noop: forward is idempotent"
}

# --- blocked outcome ---

@test "blocked when local Supabase Postgres is unreachable" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  commit_repo "add rollback-block migration"
  mock_psql_unreachable
  run_script
  assert_success
  assert_output --partial "blocked"
  assert_output --partial "host.docker.internal:54322"
  assert_output --partial "localhost:54322"
  assert_output --partial "supabase-bootstrap.sh up"
}

# --- pass outcome ---

@test "pass when rollback + forward re-apply both succeed" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  commit_repo "add rollback-block migration"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output "pass"
}

@test "pass with multiple migrations all round-tripping cleanly" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  write_migration 002 <<'SQL'
create table bar (id int);
-- ROLLBACK:
-- drop table if exists bar;
SQL
  commit_repo "add two rollback-block migrations"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output "pass"
}

@test "findings: markerless migration in a mixed set surfaces, others still round-trip" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_migration 002 <<'SQL'
create table bar (id int);
-- ROLLBACK:
-- drop table if exists bar;
SQL
  commit_repo "mixed migrations"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output --partial "findings (1)"
  assert_output --partial "001.sql missing -- ROLLBACK: marker"
  # 002 round-trips cleanly under the mock, must not appear in findings list.
  refute_output --partial "002.sql"
}

@test "pass when migration uses the noop escape hatch — skip rollback apply, forward re-apply succeeds" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- noop: forward is idempotent
SQL
  commit_repo "add migration with noop rollback"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output "pass"
}

@test "findings: empty -- ROLLBACK: block surfaces as a finding" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
SQL
  commit_repo "add migration with empty rollback block"
  mock_psql_all_pass
  run_script
  assert_success
  assert_output --partial "findings (1)"
  assert_output --partial "001.sql empty -- ROLLBACK: block"
  assert_output --partial "noop: forward is idempotent"
}

@test "findings: noop rollback but forward re-apply fails" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- noop: forward is idempotent
SQL
  commit_repo "noop rollback, broken forward"
  mock_psql_reapply_fails
  run_script
  assert_success
  assert_output --partial "findings (1)"
  assert_output --partial "001.sql forward re-apply FAILED (noop rollback)"
}

# --- findings ---

@test "findings: rollback block fails to apply (typo / dropped column)" {
  write_migration 010 <<'SQL'
alter table cards add column tool_name text;
-- ROLLBACK:
-- update cards set tool_name = null where tool_name is not null;
-- alter table cards drop column if exists tool_name;
SQL
  commit_repo "add migration with broken rollback (home-os PR #26 shape)"
  mock_psql_rollback_fails
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "010.sql rollback FAILED"
  assert_output --partial "tool_name"
  # Fix-recipe is part of the body so the operator knows how to recover.
  assert_output --partial "ci-rollback-explain.sh"
}

@test "findings: rollback succeeds but forward re-apply fails" {
  write_migration 011 <<'SQL'
create table items (id int);
-- ROLLBACK:
-- drop table if exists items;
SQL
  commit_repo "add migration where forward re-apply breaks after rollback"
  mock_psql_reapply_fails
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "011.sql forward re-apply FAILED"
}

@test "findings: count reflects total broken migrations across the set" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  write_migration 002 <<'SQL'
create table bar (id int);
-- ROLLBACK:
-- drop table if exists bar;
SQL
  commit_repo "two migrations, both with broken rollback"
  mock_psql_rollback_fails
  run_script
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "001.sql"
  assert_output --partial "002.sql"
}

# --- scope behavior ---

@test "diff predicate honors LOCAL_TESTS_BASE_REF env var" {
  # Two migrations; the second is the "new" one we're shipping.
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  commit_repo "baseline migration"
  write_migration 002 <<'SQL'
create table bar (id int);
-- ROLLBACK:
-- drop table if exists bar;
SQL
  commit_repo "new migration"
  mock_psql_all_pass
  # LOCAL_TESTS_BASE_REF=HEAD~1 → diff includes 002.sql → gate runs.
  run_script
  assert_success
  assert_output "pass"
}

@test "fail-open when base ref doesn't exist (fresh clone) — gate runs anyway" {
  write_migration 001 <<'SQL'
create table foo (id int);
-- ROLLBACK:
-- drop table if exists foo;
SQL
  commit_repo "rollback-block migration"
  mock_psql_all_pass
  # Point at a nonexistent ref — script should fail-open (run the gate).
  LOCAL_TESTS_BASE_REF="origin/does-not-exist" run_script
  assert_success
  assert_output "pass"
}
