#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-tests-coverage-project.sh
# Layer-1 deterministic test-presence hook for project repos:
#   ADD without paired test → BLOCK
#   DELETE source while paired test still present → BLOCK (orphan)
#   MODIFY without test diff → WARN only
# Bypass via `git -c devshop.testsCoverageReason="<why>"` accepts on flag presence
# (no LLM call). Trailer emission is the prepare-commit-msg hook's job; audit-time
# `/ak-tests-review` harvests the trailer (PR-C migration — see kit/ROADMAP.md).

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-tests-coverage-project.sh"
  cd "$TEST_REPO"
}

run_script() {
  run bash "$SCRIPT"
}

# --- early-exit: devshop self mode ---

@test "exits 0 when run in devshop-self mode (kit/ is real dir)" {
  mkdir -p "$TEST_REPO/kit"
  echo placeholder > "$TEST_REPO/kit/anything"
  git -C "$TEST_REPO" add kit/anything
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- ADD: block if no paired test ---

@test "BLOCK on new packages/*/src file without paired test" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  run_script
  assert_failure
  assert_output --partial "BLOCKING: New source files without paired tests"
  assert_output --partial "packages/core/src/api/foo.ts"
}

@test "PASS when new src file ships with adjacent .test.ts" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  run_script
  assert_success
}

@test "PASS when new src file ships with adjacent .integration.test.ts" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.integration.test.ts "test('x', () => {})"
  run_script
  assert_success
}

@test "PASS when new src file is referenced by a sibling .test.ts" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  # A grouped test in same dir that references the stem
  stage_file packages/core/src/api/api.test.ts "import { foo } from './foo';"
  run_script
  assert_success
}

# --- ADD: filename + path exemptions ---

@test "page.tsx is exempt by filename (route entry-points covered by E2E)" {
  stage_file apps/web/app/list/page.tsx "export default function Page() {}"
  run_script
  assert_success
}

@test "layout.tsx is exempt by filename" {
  stage_file apps/web/app/layout.tsx "export default function Layout() {}"
  run_script
  assert_success
}

@test "middleware.ts is exempt by filename" {
  stage_file apps/web/middleware.ts "export function middleware() {}"
  run_script
  assert_success
}

@test "*.d.ts is exempt by pattern" {
  stage_file packages/core/src/types.d.ts "export type X = {};"
  run_script
  assert_success
}

@test "*.config.ts is exempt by pattern" {
  stage_file packages/core/src/api/something.config.ts "export const cfg = {};"
  run_script
  assert_success
}

@test "files under e2e/ are exempt" {
  stage_file apps/web/e2e/auth.spec.ts "test('x', () => {})"
  run_script
  assert_success
}

# --- ADD: per-project override file ---

@test "PASS when src is in .devshop-test-coverage-exempt override" {
  stage_file packages/core/src/api/legacy.ts "export const x = 1;"
  echo 'packages/core/src/api/legacy.ts' > "$TEST_REPO/.devshop-test-coverage-exempt"
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  run_script
  assert_success
}

@test "override file ignores comments and blank lines" {
  stage_file packages/core/src/api/legacy.ts "export const x = 1;"
  cat > "$TEST_REPO/.devshop-test-coverage-exempt" <<EOF
# legacy file — unit tests not meaningful

packages/core/src/api/legacy.ts
EOF
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  run_script
  assert_success
}

@test "override file accepts trailing inline comment after path" {
  stage_file packages/core/src/api/legacy.ts "export const x = 1;"
  cat > "$TEST_REPO/.devshop-test-coverage-exempt" <<EOF
packages/core/src/api/legacy.ts  # covered by api.integration.test.ts
EOF
  git -C "$TEST_REPO" add .devshop-test-coverage-exempt
  run_script
  assert_success
}

# --- DELETE: orphan check ---

@test "BLOCK when src deleted but paired test still present" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  git -C "$TEST_REPO" commit -q -m "add foo"
  git -C "$TEST_REPO" rm packages/core/src/api/foo.ts -q
  run_script
  assert_failure
  assert_output --partial "Source files removed but paired tests still present"
  assert_output --partial "packages/core/src/api/foo.ts"
}

@test "PASS when src and paired test deleted in same commit" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  git -C "$TEST_REPO" commit -q -m "add foo"
  git -C "$TEST_REPO" rm packages/core/src/api/foo.ts packages/core/src/api/foo.test.ts -q
  run_script
  assert_success
}

# --- MODIFY: warn only ---

@test "WARN (not BLOCK) when src modified without staged test" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  git -C "$TEST_REPO" commit -q -m "add foo"
  echo 'export const foo = 2; export const bar = 3;' > "$TEST_REPO/packages/core/src/api/foo.ts"
  git -C "$TEST_REPO" add packages/core/src/api/foo.ts
  run_script
  assert_success
  assert_output --partial "Modified source files without staged test changes"
  assert_output --partial "packages/core/src/api/foo.ts"
}

@test "no warning when src and paired test both staged in modify" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  git -C "$TEST_REPO" commit -q -m "add foo"
  echo 'export const foo = 2;' > "$TEST_REPO/packages/core/src/api/foo.ts"
  echo 'test("y", () => {})' > "$TEST_REPO/packages/core/src/api/foo.test.ts"
  git -C "$TEST_REPO" add packages/core/src/api/foo.ts packages/core/src/api/foo.test.ts
  run_script
  assert_success
  refute_output --partial "Modified source files"
}

# --- Layer 1 bypass: flag-presence (no LLM call) ---

@test "bypass: flag presence accepts ADD-without-test (no LLM call)" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  git -C "$TEST_REPO" config devshop.testsCoverageReason "foo.ts is a 1-line type re-export — covered transitively by api.test.ts"
  run_script
  assert_success
  assert_output --partial "Tests-coverage block bypassed"
  assert_output --partial "Tests-Coverage-Bypass: trailer"
}

@test "bypass: flag presence accepts orphan-after-DELETE" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x', () => {})"
  git -C "$TEST_REPO" commit -q -m "add foo"
  git -C "$TEST_REPO" rm packages/core/src/api/foo.ts -q
  git -C "$TEST_REPO" config devshop.testsCoverageReason "test now covers the replacement util in api.test.ts"
  run_script
  assert_success
}

@test "bypass: empty flag value still blocks" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  git -C "$TEST_REPO" config devshop.testsCoverageReason ""
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

# --- multi-file scenarios ---

@test "BLOCK lists all paths missing tests" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/bar.ts "export const bar = 1;"
  stage_file apps/web/lib/util.ts "export const u = 1;"
  run_script
  assert_failure
  assert_output --partial "packages/core/src/api/foo.ts"
  assert_output --partial "packages/core/src/api/bar.ts"
  assert_output --partial "apps/web/lib/util.ts"
}

@test "exempt and non-exempt mixed: only non-exempt blocks" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file apps/web/app/page.tsx "export default function P() {}"
  stage_file packages/core/src/index.ts "export *"
  run_script
  assert_failure
  assert_output --partial "packages/core/src/api/foo.ts"
  refute_output --partial "page.tsx"
  refute_output --partial "index.ts"
}

# --- no-op path ---

@test "no-op when no project source paths staged" {
  stage_file README.md "x"
  run_script
  assert_success
}

@test "no-op when only test files staged" {
  stage_file packages/core/src/api/foo.ts "export const foo = 1;"
  stage_file packages/core/src/api/foo.test.ts "test('x')"
  git -C "$TEST_REPO" commit -q -m "add foo"
  echo "test('y')" > "$TEST_REPO/packages/core/src/api/foo.test.ts"
  git -C "$TEST_REPO" add packages/core/src/api/foo.test.ts
  run_script
  assert_success
}
