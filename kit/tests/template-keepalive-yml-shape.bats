#!/usr/bin/env bats
# Structural assertions for the template's keepalive workflow.
# Pure file-content checks; no real GitHub Actions runner needed.

setup() {
  load helpers/setup
  DEVSHOP="$(git rev-parse --show-toplevel)"
  KEEPALIVE="$DEVSHOP/template/.github/workflows/keepalive.yml"
}

@test "template keepalive.yml exists" {
  [ -f "$KEEPALIVE" ]
}

@test "cron schedule is twice-weekly (Mon + Thu)" {
  grep -q "0 9 \* \* 1,4" "$KEEPALIVE"
}

@test "Ping production step exists" {
  grep -q "name: Ping production" "$KEEPALIVE"
}

@test "Ping Supabase step exists" {
  grep -q "name: Ping Supabase" "$KEEPALIVE"
}

@test "Supabase ping uses vars.SUPABASE_PROD_URL (not vars.SUPABASE_URL)" {
  grep -q 'vars\.SUPABASE_PROD_URL' "$KEEPALIVE"
}

@test "Supabase ping uses vars.SUPABASE_PROD_ANON_KEY (not vars.SUPABASE_ANON_KEY)" {
  grep -q 'vars\.SUPABASE_PROD_ANON_KEY' "$KEEPALIVE"
}

@test "Supabase ping hits /rest/v1/ endpoint" {
  grep -q '/rest/v1/' "$KEEPALIVE"
}

@test "Supabase ping emits warning on non-2xx" {
  # Extract lines between "Ping Supabase" and the next step (or EOF)
  local supabase_block
  supabase_block=$(sed -n '/name: Ping Supabase/,/^ *- name:/p' "$KEEPALIVE" | head -n -1)
  [ -z "$supabase_block" ] && supabase_block=$(sed -n '/name: Ping Supabase/,$p' "$KEEPALIVE")
  echo "$supabase_block" | grep -q '::warning::'
}

@test "step order: Ping production before Ping Supabase" {
  local prod_line supa_line
  prod_line=$(grep -n "name: Ping production" "$KEEPALIVE" | head -1 | cut -d: -f1)
  supa_line=$(grep -n "name: Ping Supabase" "$KEEPALIVE" | head -1 | cut -d: -f1)
  [ "$prod_line" -lt "$supa_line" ]
}
