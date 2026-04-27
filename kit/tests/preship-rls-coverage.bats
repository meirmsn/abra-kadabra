#!/usr/bin/env bats
# Tests for kit/scripts/preship/rls-coverage-check.sh
# Pre-ship gate that verifies every client write to an RLS-enabled table has a
# matching CREATE POLICY. Catches the silent class of failures where the write
# succeeds as zero rows because no policy permits it. See lalista PR 5 for the
# motivating incident; conventions.md § Supabase Hardening Defaults for the rule.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/rls-coverage-check.sh"
}

run_script() {
  run bash "$SCRIPT" "$TEST_REPO"
}

# Helper: write a migration file with arbitrary content.
write_migration() {
  local name="$1"
  mkdir -p "$TEST_REPO/supabase/migrations"
  cat > "$TEST_REPO/supabase/migrations/$name.sql"
}

# Helper: write a code file with arbitrary content.
write_code() {
  local path="$1"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  cat > "$TEST_REPO/$path"
}

# --- n/a outcomes ---

@test "n/a when no supabase/migrations directory" {
  run_script
  assert_success
  assert_output --partial "n/a (no supabase/migrations"
}

# --- pass outcomes ---

@test "pass when no RLS-enabled tables" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('foo').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when client write matches existing 'for insert' policy" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_insert on items for insert to authenticated with check (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').insert({ name: 'x' })
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when only reads (no writes) — RLS enabled but no write usage" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').select('*')
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when 'for all' policy covers any operation" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_all on items for all to authenticated using (true) with check (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').update({ name: 'x' })
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when upsert is covered by both insert and update policies" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_insert on items for insert to authenticated with check (true);
create policy items_update on items for update to authenticated using (true) with check (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').upsert({ name: 'x' })
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when public-schema-prefixed table reference is used" {
  # Match `alter table public.items` and `create policy ... on public.items`.
  write_migration 001 <<'SQL'
create table public.items (id int);
alter table public.items enable row level security;
create policy items_insert on public.items for insert to authenticated with check (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

# --- findings ---

@test "findings: RLS enabled, insert without matching policy" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_select on items for select to authenticated using (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items insert (RLS enabled, no 'insert' policy)"
}

@test "findings: RLS enabled, update without matching policy" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_select on items for select to authenticated using (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').update({ name: 'x' })
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items update (RLS enabled, no 'update' policy)"
}

@test "findings: RLS enabled, delete without matching policy" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').delete()
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items delete (RLS enabled, no 'delete' policy)"
}

@test "findings: upsert with only insert policy (missing update)" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create policy items_insert on items for insert to authenticated with check (true);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').upsert({})
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items upsert (RLS enabled, no 'update' policy)"
}

@test "findings: multiple gaps across multiple tables" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
create table list_entries (id int);
alter table list_entries enable row level security;
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('items').insert({})
supabase.from('list_entries').delete()
TS
  run_script
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "items insert"
  assert_output --partial "list_entries delete"
}

# --- skip categories ---

@test "skips unit test files (*.test.ts)" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  # Test file — should NOT trigger a finding even though no policy exists.
  write_code apps/web/a.test.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "skips integration test files (*.integration.test.ts)" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code apps/web/a.integration.test.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "skips E2E specs under apps/*/e2e/" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code apps/web/e2e/auth.spec.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

@test "skips files outside apps/, packages/, and supabase/functions/" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  # Top-level scripts aren't audited
  write_code scripts/seed.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}

# --- coverage scope ---

@test "scans packages/ in addition to apps/" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code packages/core/src/api.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items insert"
}

@test "scans supabase/functions/ in addition to apps/" {
  write_migration 001 <<'SQL'
create table items (id int);
alter table items enable row level security;
SQL
  write_code supabase/functions/add-item/index.ts <<'TS'
supabase.from('items').insert({})
TS
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "items insert"
}

@test "table without RLS enabled is not flagged even if no policy" {
  # Pre-RLS table — writes are unrestricted; gate has nothing to enforce.
  write_migration 001 <<'SQL'
create table public_data (id int);
SQL
  write_code apps/web/a.ts <<'TS'
supabase.from('public_data').insert({})
TS
  run_script
  assert_success
  assert_output "pass"
}
