#!/usr/bin/env bats
# Behavior tests for the Supabase port registry: next-port-offset.sh,
# apply-port-offset.sh, and check-port-offset-unique.sh.
#
# Pure file-content checks against synthetic fixtures; no real container,
# no supabase CLI, no iptables.

setup() {
  load helpers/setup
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  NEXT_OFFSET="$REPO_ROOT/kit/scripts/next-port-offset.sh"
  APPLY_OFFSET="$REPO_ROOT/kit/scripts/apply-port-offset.sh"
  CHECK_UNIQUE="$REPO_ROOT/kit/scripts/commit-hooks/check-port-offset-unique.sh"
  DERIVE_SCRIPT="$REPO_ROOT/template/.devcontainer/derive-ports-from-config.sh"

  # Synthetic devshop tree for registry tests.
  FAKE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$FAKE_DEVSHOP/kit/notes/projects"
  export DEVSHOP="$FAKE_DEVSHOP"

  # Synthetic project tree for apply-offset tests.
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/.devcontainer" "$PROJECT/supabase"
  touch "$PROJECT/.devcontainer/.env"
  cp "$DERIVE_SCRIPT" "$PROJECT/.devcontainer/derive-ports-from-config.sh"
}

# Helper: write a project notes file with a port offset.
write_notes() {
  local name="$1" offset="$2"
  cat > "$FAKE_DEVSHOP/kit/notes/projects/$name.md" <<EOF
---
supabase_port_offset: $offset
---

# Init Tracker — $name
EOF
}

# Helper: write a standard 5-block config.toml with default ports.
write_default_config() {
  cat > "$PROJECT/supabase/config.toml" <<'EOF'
[api]
enabled = true
port = 54321
schemas = ["public", "graphql_public"]

[db]
port = 54322
major_version = 15

[studio]
enabled = true
port = 54323

[inbucket]
enabled = true
port = 54324

[auth]
enabled = true
additional_redirect_urls = ["https://127.0.0.1:3000"]

[analytics]
enabled = true
port = 54327
EOF
}

# Helper: extract port from a config.toml section.
config_port() {
  local section="$1"
  awk -v sect="$section" '
    $0 ~ "^\\[" sect "\\]" { in_sect=1; next }
    in_sect && /^\[/        { exit }
    in_sect && /^port[[:space:]]*=/ {
      sub(/^port[[:space:]]*=[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print; exit
    }
  ' "$PROJECT/supabase/config.toml"
}

# Helper: init a git repo with identity configured.
init_test_git() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
}

# =============================================================================
# next-port-offset.sh — registry scanning
# =============================================================================

@test "next-port-offset: empty registry → assigns 0" {
  find "$FAKE_DEVSHOP/kit/notes/projects" -name '*.md' -delete
  run bash "$NEXT_OFFSET"
  assert_success
  assert_output "0"
}

@test "next-port-offset: registry has 0,100 → assigns 200" {
  write_notes "lalista" 0
  write_notes "home-os" 100
  run bash "$NEXT_OFFSET"
  assert_success
  assert_output "200"
}

@test "next-port-offset: registry has 0,200 (gap at 100) → assigns 100" {
  write_notes "lalista" 0
  write_notes "project-b" 200
  run bash "$NEXT_OFFSET"
  assert_success
  assert_output "100"
}

@test "next-port-offset: operator override takes precedence" {
  write_notes "lalista" 0
  write_notes "home-os" 100
  SUPABASE_PORT_OFFSET_OVERRIDE=500 run bash "$NEXT_OFFSET"
  assert_success
  assert_output "500"
}

@test "next-port-offset: missing projects dir → assigns 0" {
  DEVSHOP="$BATS_TEST_TMPDIR/no-devshop" run bash "$NEXT_OFFSET"
  assert_success
  assert_output "0"
}

# =============================================================================
# apply-port-offset.sh — config.toml rewriting
# =============================================================================

@test "apply-offset: rewrites 5 port sections with offset 100" {
  write_default_config
  write_notes "project" 100

  run bash "$APPLY_OFFSET" "$PROJECT"
  assert_success
  [ "$(config_port api)" = "54421" ]
  [ "$(config_port db)" = "54422" ]
  [ "$(config_port studio)" = "54423" ]
  [ "$(config_port inbucket)" = "54424" ]
  [ "$(config_port analytics)" = "54427" ]
}

@test "apply-offset: fixes additional_redirect_urls" {
  write_default_config
  write_notes "project" 0

  run bash "$APPLY_OFFSET" "$PROJECT"
  assert_success
  run grep 'additional_redirect_urls' "$PROJECT/supabase/config.toml"
  assert_output --partial 'http://127.0.0.1:3000/**'
  assert_output --partial 'http://localhost:3000/**'
  refute_output --partial 'https://127.0.0.1:3000'
}

@test "apply-offset: fails when config.toml missing" {
  write_notes "project" 0
  rm -f "$PROJECT/supabase/config.toml"
  run bash "$APPLY_OFFSET" "$PROJECT"
  assert_failure
  assert_output --partial "not found"
}

@test "apply-offset: fails when notes file missing" {
  write_default_config
  rm -f "$FAKE_DEVSHOP/kit/notes/projects/project.md"
  run bash "$APPLY_OFFSET" "$PROJECT"
  assert_failure
  assert_output --partial "No devshop notes file"
}

# =============================================================================
# check-port-offset-unique.sh — duplicate guard
# =============================================================================

@test "duplicate-guard: passes with unique offsets" {
  write_notes "lalista" 0
  write_notes "home-os" 100

  init_test_git "$FAKE_DEVSHOP"
  cd "$FAKE_DEVSHOP"
  git add kit/notes/projects/lalista.md kit/notes/projects/home-os.md
  git commit -q -m "init" --no-verify
  echo "# updated" >> kit/notes/projects/lalista.md
  git add kit/notes/projects/lalista.md

  run bash "$CHECK_UNIQUE"
  assert_success
}

@test "duplicate-guard: rejects duplicate offsets" {
  write_notes "lalista" 100
  write_notes "home-os" 100

  init_test_git "$FAKE_DEVSHOP"
  cd "$FAKE_DEVSHOP"
  git add kit/notes/projects/lalista.md kit/notes/projects/home-os.md
  git commit -q -m "init" --no-verify
  echo "# updated" >> kit/notes/projects/home-os.md
  git add kit/notes/projects/home-os.md

  run bash "$CHECK_UNIQUE"
  assert_failure
  assert_output --partial "Duplicate supabase_port_offset"
}

@test "duplicate-guard: skips when no project files staged" {
  write_notes "lalista" 100
  write_notes "home-os" 100

  init_test_git "$FAKE_DEVSHOP"
  cd "$FAKE_DEVSHOP"
  git add kit/notes/projects/lalista.md kit/notes/projects/home-os.md
  git commit -q -m "init" --no-verify
  mkdir -p "$FAKE_DEVSHOP/other"
  echo "test" > "$FAKE_DEVSHOP/other/file.md"
  git add other/file.md

  run bash "$CHECK_UNIQUE"
  assert_success
}
