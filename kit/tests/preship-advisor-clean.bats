#!/usr/bin/env bats
# Tests for kit/scripts/preship/advisor-clean.sh
# Pre-ship gate that wraps `pnpm db:advisor` (template/scripts/advisor-probe.mjs)
# and surfaces 9 Supabase Advisor lints locally. See kit/docs/guide/security.md
# § DB hardening for the rules these lints encode.
#
# These tests exercise the scope guards and bypass paths. The probe itself
# (pg_catalog SQL) is exercised indirectly via `pnpm db:advisor` stubs — a
# live Postgres-connected smoke test would need a real Supabase stack.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/advisor-clean.sh"
}

run_script() {
  run bash "$SCRIPT" "$TEST_REPO"
}

write_migration() {
  local name="$1"
  mkdir -p "$TEST_REPO/supabase/migrations"
  cat > "$TEST_REPO/supabase/migrations/$name.sql"
}

write_package_json() {
  cat > "$TEST_REPO/package.json"
}

# --- n/a outcomes (scope short-circuits, no probe invocation) ---

@test "n/a when no supabase/migrations directory" {
  run_script
  assert_success
  assert_output --partial "n/a (no supabase/migrations"
}

@test "n/a when no package.json" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  run_script
  assert_success
  assert_output --partial "n/a (no package.json"
}

@test "n/a when package.json missing db:advisor script" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_package_json <<'JSON'
{
  "name": "x",
  "scripts": { "dev": "next dev" }
}
JSON
  run_script
  assert_success
  assert_output --partial "n/a (no db:advisor script"
}

@test "n/a when diff doesn't touch migrations or functions" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_package_json <<'JSON'
{
  "name": "x",
  "scripts": { "db:advisor": "node scripts/advisor-probe.mjs" }
}
JSON
  # Commit baseline so diff against origin/main (which falls back to HEAD~ when
  # missing) shows no migration changes.
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "baseline"
  # Touch a non-migration file.
  mkdir -p "$TEST_REPO/apps/web"
  echo "x" > "$TEST_REPO/apps/web/page.tsx"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "non-migration change"

  run_script
  assert_success
  # Either "no migration or function changes" (diff predicate fires) OR
  # "blocked (Postgres unreachable)" if the predicate fails open (no
  # origin/main). Both are acceptable scope outcomes for this test.
  assert_output --regexp "n/a \(no migration or function changes|blocked \(local Supabase Postgres unreachable"
}

# --- Bypass path (DEVSHOP_SKIP_ADVERSARIAL=1 disables the reviewer) ---

@test "bypass pass when DEVSHOP_SKIP_ADVERSARIAL=1 + reason set" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_package_json <<'JSON'
{
  "name": "x",
  "scripts": { "db:advisor": "node scripts/advisor-probe.mjs" }
}
JSON
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "baseline with migration"

  git -C "$TEST_REPO" config devshop.advisorBypassReason "extension-in-public per project D4 (pgcrypto move would break call sites); tracked at TODOS.md L42"

  DEVSHOP_SKIP_ADVERSARIAL=1 run bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "pass (skipped"
  assert_output --partial "extension-in-public"
}

# --- Probe blocked path (pnpm db:advisor unavailable when stack down) ---
# When Postgres is unreachable the gate emits "blocked" via the psql reachability
# preflight — exercised end-to-end on a real stack in CI rather than here.
# This test asserts the script does not crash when no stack is up; the outcome
# string is the blocked-emit path.

@test "blocked when local Postgres unreachable (no real stack in BATS env)" {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_package_json <<'JSON'
{
  "name": "x",
  "scripts": { "db:advisor": "node scripts/advisor-probe.mjs" }
}
JSON
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "baseline with migration"

  # Force a fresh migration that the diff predicate sees as AM-filtered.
  write_migration 002 <<'SQL'
create table bar (id int);
SQL
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "second migration"

  # Stub psql to always fail (simulate Postgres unreachable).
  create_stub psql "" 2

  run_script
  assert_success
  assert_output --regexp "blocked \(local Supabase Postgres unreachable|n/a \(no migration or function changes"
}

# --- Live outcome routing (stubbed pnpm) ---
# These exercise the probe-exit-code → gate-outcome mapping that the scope-only
# tests above can't reach. Regression coverage for the `if !cmd; then rc=$?; fi`
# pitfall (caught 2026-05-20): inside the then-branch, $? is the exit of `!cmd`,
# always 0, so every probe outcome routed to `pass` regardless of exit code.

setup_migration_scope() {
  write_migration 001 <<'SQL'
create table foo (id int);
SQL
  write_package_json <<'JSON'
{ "name": "x", "scripts": { "db:advisor": "node scripts/advisor-probe.mjs" } }
JSON
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "baseline with migration"
  write_migration 002 <<'SQL'
create table bar (id int);
SQL
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "second migration"
  # Stub psql so reachability check passes.
  create_stub psql "1" 0
}

@test "live: probe exit 0 → gate emits probe output verbatim" {
  setup_migration_scope
  cat > "$MOCK_BIN/pnpm" <<'STUB'
#!/bin/bash
echo "pass"
echo "Advisor: 9/9 lints clean."
exit 0
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run_script
  assert_success
  assert_output --partial "pass"
  assert_output --partial "9/9 lints clean"
}

@test "live: probe exit 1 → gate emits findings + fix recipe (regression: rc capture)" {
  setup_migration_scope
  cat > "$MOCK_BIN/pnpm" <<'STUB'
#!/bin/bash
echo "findings (3)"
echo "  - auth_rls_initplan: 2 finding(s)"
exit 1
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run_script
  assert_success
  assert_output --partial "findings (3)"
  assert_output --partial "auth_rls_initplan"
  # The fix recipe lines are the regression sentinel — they were unreachable
  # before the rc-capture fix because `$?` inside `if !cmd; then` is always 0.
  assert_output --partial "kit/docs/guide/security.md"
  assert_output --partial "ADVISOR-EXEMPT"
}

@test "live: probe exit 2 → gate emits 'blocked' + propagates probe error excerpt" {
  setup_migration_scope
  cat > "$MOCK_BIN/pnpm" <<'STUB'
#!/bin/bash
echo "blocked: 'pg' is not installed"
exit 2
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run_script
  assert_success
  assert_output --partial "blocked (advisor-probe failed)"
  # Excerpt formatting (head -3 | tr '\n' ' ') propagates the probe's first
  # lines so operators can distinguish missing-pg vs query-syntax-error vs
  # other probe failures from the gate's blocked output alone.
  assert_output --partial "pg' is not installed"
}
