#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-rollback-prose.sh
# Pre-commit lint catches prose lines in migration -- ROLLBACK: blocks
# before they reach CI's rollback round-trip test. Prose lines become SQL
# syntax errors after ci-rollback-explain.sh strips the `-- ` prefix.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-rollback-prose.sh"
  cd "$TEST_REPO"
}

run_script() {
  run sh "$SCRIPT"
}

# --- Pass: no migration files staged ---

@test "exits 0 when no migration files are staged" {
  stage_file README.md "hello"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Pass: valid SQL-only rollback block ---

@test "exits 0 when rollback block contains only SQL keywords" {
  stage_file supabase/migrations/001_create_table.sql "$(cat <<'SQL'
CREATE TABLE items (id uuid PRIMARY KEY);

-- ROLLBACK:
-- DROP TABLE IF EXISTS items;
SQL
)"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Pass: noop rollback ---

@test "exits 0 when rollback block is noop" {
  stage_file supabase/migrations/002_data_only.sql "$(cat <<'SQL'
INSERT INTO items (id) VALUES (gen_random_uuid());

-- ROLLBACK:
-- noop: forward is idempotent
SQL
)"
  run_script
  assert_success
}

@test "exits 0 when rollback block is Noop (mixed case)" {
  stage_file supabase/migrations/003_mixed_noop.sql "$(cat <<'SQL'
UPDATE items SET name = 'test';

-- ROLLBACK:
-- Noop: nothing to undo
SQL
)"
  run_script
  assert_success
}

# --- Pass: multi-line SQL continuation (lowercase start) ---

@test "exits 0 when rollback has lowercase continuation lines" {
  stage_file supabase/migrations/004_complex.sql "$(cat <<'SQL'
ALTER TABLE items ADD COLUMN card_count integer DEFAULT 0;

-- ROLLBACK:
-- ALTER TABLE items
--   DROP COLUMN IF EXISTS card_count;
SQL
)"
  run_script
  assert_success
}

# --- Pass: lines starting with special characters ---

@test "exits 0 when rollback has lines starting with parens, quotes, digits" {
  stage_file supabase/migrations/005_values.sql "$(cat <<'SQL'
INSERT INTO config (key, val) VALUES ('mode', 'dark');

-- ROLLBACK:
-- DELETE FROM config
--   WHERE key = 'mode';
SQL
)"
  run_script
  assert_success
}

@test "exits 0 when rollback has lines starting with parentheses" {
  stage_file supabase/migrations/006_parens.sql "$(cat <<'SQL'
CREATE INDEX idx_items ON items (name, created_at);

-- ROLLBACK:
-- DROP INDEX IF EXISTS idx_items;
SQL
)"
  run_script
  assert_success
}

# --- Fail: prose line in rollback block ---

@test "exits 1 when rollback block contains a prose line" {
  stage_file supabase/migrations/007_with_prose.sql "$(cat <<'SQL'
ALTER TABLE items ADD COLUMN status text;

-- ROLLBACK:
-- This removes the status column added above
-- DROP COLUMN IF EXISTS status;
SQL
)"
  run_script
  assert_failure
  assert_output --partial "This removes the status column added above"
  assert_output --partial "BLOCKING"
}

# --- Fail: the worked incident pattern ---

@test "catches the home-os PR #35 pattern: prose description line" {
  stage_file supabase/migrations/015_card_count.sql "$(cat <<'SQL'
ALTER TABLE items ADD COLUMN card_count integer DEFAULT 0;

-- ROLLBACK:
-- Restore the migration 006b version (resets card_count only):
-- ALTER TABLE items DROP COLUMN IF EXISTS card_count;
SQL
)"
  run_script
  assert_failure
  assert_output --partial "Restore the migration 006b version"
  assert_output --partial "BLOCKING"
}

# --- Pass: migration without ROLLBACK block ---

@test "exits 0 when migration has no ROLLBACK block (marker mandate is ci-rollback-explain's job)" {
  stage_file supabase/migrations/008_no_rollback.sql "$(cat <<'SQL'
CREATE TABLE logs (id uuid PRIMARY KEY, msg text);
SQL
)"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Edge: empty rollback block ---

@test "exits 0 when rollback block is empty" {
  stage_file supabase/migrations/009_empty_rollback.sql "$(cat <<'SQL'
CREATE TABLE temp (id uuid PRIMARY KEY);

-- ROLLBACK:
SQL
)"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Edge: multiple migration files, one with prose ---

@test "reports prose from the offending file only" {
  stage_file supabase/migrations/010_clean.sql "$(cat <<'SQL'
CREATE TABLE a (id uuid PRIMARY KEY);

-- ROLLBACK:
-- DROP TABLE IF EXISTS a;
SQL
)"
  stage_file supabase/migrations/011_dirty.sql "$(cat <<'SQL'
CREATE TABLE b (id uuid PRIMARY KEY);

-- ROLLBACK:
-- Remove table b that was added for feature X
-- DROP TABLE IF EXISTS b;
SQL
)"
  run_script
  assert_failure
  assert_output --partial "011_dirty.sql"
  assert_output --partial "Remove table b"
  refute_output --partial "010_clean.sql"
}

# --- Edge: non-migration SQL files are ignored ---

@test "ignores SQL files outside supabase/migrations/" {
  stage_file supabase/seed.sql "$(cat <<'SQL'
-- ROLLBACK:
-- This is prose that would fail if checked
SQL
)"
  run_script
  assert_success
}

# --- Pass: all SQL keywords from the decision list ---

@test "exits 0 for all recognized SQL keywords" {
  stage_file supabase/migrations/012_keywords.sql "$(cat <<'SQL'
SELECT 1;

-- ROLLBACK:
-- DROP TABLE IF EXISTS foo;
-- CREATE TABLE bar (id int);
-- ALTER TABLE baz ADD COLUMN x int;
-- SELECT 1;
-- INSERT INTO foo VALUES (1);
-- UPDATE foo SET x = 1;
-- DELETE FROM foo WHERE id = 1;
-- SET search_path TO public;
-- RESET search_path;
-- GRANT ALL ON foo TO public;
-- REVOKE ALL ON foo FROM public;
-- NOTIFY channel;
-- BEGIN;
-- COMMIT;
-- ROLLBACK;
-- DO $$ BEGIN RAISE NOTICE 'hi'; END $$;
-- WITH cte AS (SELECT 1) SELECT * FROM cte;
-- TRUNCATE TABLE foo;
-- COMMENT ON TABLE foo IS 'bar';
SQL
)"
  run_script
  assert_success
}
