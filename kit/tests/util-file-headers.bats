#!/usr/bin/env bats
# Tests for kit/scripts/check-file-headers.sh
# Validates .ts/.tsx files under src/ or app/ have // What: header

setup() {
  load helpers/setup
  create_test_repo
  CHECK="$SCRIPTS_DIR/check-file-headers.sh"
}

# Helper: stage a .ts file and run the check in staged mode
run_check() {
  run bash -c "cd '$TEST_REPO' && bash '$CHECK'"
}

@test "passes when staged .ts file has header" {
  stage_file "src/index.ts" '// What: Entry point
// Why: App bootstrap
// Does NOT: Handle auth
export const main = () => {}'
  run_check
  assert_success
}

@test "fails when staged .ts file is missing header" {
  stage_file "src/index.ts" 'export const main = () => {}'
  run_check
  assert_failure 1
  assert_output --partial "src/index.ts"
}

@test "skips .config.ts files" {
  stage_file "src/vitest.config.ts" 'export default {}'
  run_check
  assert_success
}

@test "skips .d.ts files" {
  stage_file "src/types.d.ts" 'declare module "foo" {}'
  run_check
  assert_success
}

@test "only checks files under src/ or app/" {
  stage_file "lib/utils.ts" 'export const noop = () => {}'
  run_check
  assert_success
}

@test "checks files under app/" {
  stage_file "app/page.tsx" 'export default function Page() {}'
  run_check
  assert_failure 1
  assert_output --partial "app/page.tsx"
}

@test "passes with no staged .ts files" {
  stage_file "README.md" "# hello"
  run_check
  assert_success
}
