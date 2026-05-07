#!/usr/bin/env bats
# Tests for kit/scripts/preship/path-classifier.sh
# Hardcoded path classifier per spec D4. Two subcommands:
#   classify <path>          — print "stack-needing" or "not-stack-needing"
#   diff-needs-stack [<base>] — exit 0 if any diff path classifies as stack-needing
# Spec: specs/cheap-test-gates-local/spec.md § D4, § Tests.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/path-classifier.sh"
}

# Helper: run `classify <path>` and assert verdict on stdout.
classify() {
  run bash "$SCRIPT" classify "$1"
}

# Helper: stage two commits in TEST_REPO so HEAD~1 has a baseline and HEAD has
# the changed path. Returns with TEST_REPO at HEAD on the second commit.
two_commit_diff() {
  local path="$1" content="${2:-x}"
  echo "base" > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add base.md
  git -C "$TEST_REPO" commit -q -m "baseline"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "add $path"
}

# === classify: D4 table verbatim ===

@test "classify: apps/web/components/X.tsx → stack-needing" {
  classify apps/web/components/X.tsx
  assert_success
  assert_output "stack-needing"
}

@test "classify: packages/core/src/api/y.ts → stack-needing" {
  classify packages/core/src/api/y.ts
  assert_success
  assert_output "stack-needing"
}

@test "classify: packages/ui/src/Button.tsx → stack-needing" {
  classify packages/ui/src/Button.tsx
  assert_success
  assert_output "stack-needing"
}

@test "classify: foo.integration.test.ts → stack-needing" {
  classify foo.integration.test.ts
  assert_success
  assert_output "stack-needing"
}

@test "classify: nested *.integration.test.ts → stack-needing" {
  classify packages/core/src/api/list.integration.test.ts
  assert_success
  assert_output "stack-needing"
}

@test "classify: apps/web/e2e/x.spec.ts → stack-needing (matches apps/**)" {
  classify apps/web/e2e/x.spec.ts
  assert_success
  assert_output "stack-needing"
}

@test "classify: supabase/migrations/001.sql → stack-needing" {
  classify supabase/migrations/001.sql
  assert_success
  assert_output "stack-needing"
}

@test "classify: supabase/functions/foo/index.ts → stack-needing" {
  classify supabase/functions/foo/index.ts
  assert_success
  assert_output "stack-needing"
}

# === classify: not-stack-needing cases ===

@test "classify: README.md → not-stack-needing" {
  classify README.md
  assert_success
  assert_output "not-stack-needing"
}

@test "classify: CLAUDE.md → not-stack-needing" {
  classify CLAUDE.md
  assert_success
  assert_output "not-stack-needing"
}

@test "classify: specs/foo/spec.md → not-stack-needing" {
  classify specs/foo/spec.md
  assert_success
  assert_output "not-stack-needing"
}

@test "classify: .github/workflows/ci.yml → not-stack-needing" {
  classify .github/workflows/ci.yml
  assert_success
  assert_output "not-stack-needing"
}

@test "classify: kit/docs/guide/conventions.md → not-stack-needing (devshop docs)" {
  classify kit/docs/guide/conventions.md
  assert_success
  assert_output "not-stack-needing"
}

# === classify: ambiguous paths ===

@test "classify: apps/web/e2e/_smoke/foo.spec.ts → stack-needing (matches apps/**)" {
  classify apps/web/e2e/_smoke/foo.spec.ts
  assert_success
  assert_output "stack-needing"
}

@test "classify: supabase/migrations/.gitkeep → stack-needing (matches supabase/migrations/**)" {
  classify supabase/migrations/.gitkeep
  assert_success
  assert_output "stack-needing"
}

@test "classify: empty path → CLI rejects with usage (exit 64)" {
  # Empty arg is treated as missing-arg by the dispatcher (defensive — a
  # caller passing an empty path string is almost certainly a bug, not a
  # request to classify "the empty path"). The internal classify_path
  # function is defensive and returns "not-stack-needing", but the CLI
  # surfaces it as a usage error so the bug surfaces immediately.
  classify ""
  [ "$status" -eq 64 ]
}

# === diff-needs-stack ===

@test "diff-needs-stack: exit 0 when fixture diff has any stack-needing path" {
  two_commit_diff apps/web/components/X.tsx
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack HEAD~1
  assert_success
}

@test "diff-needs-stack: exit 1 on pure-docs fixture diff" {
  two_commit_diff README.md
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack HEAD~1
  assert_failure
  [ "$status" -eq 1 ]
}

@test "diff-needs-stack: exit 1 on devshop-docs-only diff (kit/docs/...)" {
  two_commit_diff kit/docs/guide/foo.md
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack HEAD~1
  assert_failure
  [ "$status" -eq 1 ]
}

@test "diff-needs-stack: exit 0 when diff includes both docs AND a stack-needing path" {
  echo "base" > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add base.md
  git -C "$TEST_REPO" commit -q -m "baseline"
  mkdir -p "$TEST_REPO/apps/web/components" "$TEST_REPO/specs/foo"
  echo "tsx" > "$TEST_REPO/apps/web/components/X.tsx"
  echo "spec" > "$TEST_REPO/specs/foo/spec.md"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "mixed"
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack HEAD~1
  assert_success
}

@test "diff-needs-stack: exit 2 on git error (nonexistent base ref)" {
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack nonexistent-ref-xyz
  [ "$status" -eq 2 ]
}

@test "diff-needs-stack: exit 1 on empty diff (HEAD vs HEAD)" {
  cd "$TEST_REPO"
  run bash "$SCRIPT" diff-needs-stack HEAD
  assert_failure
  [ "$status" -eq 1 ]
}

# === CLI dispatch ===

@test "CLI: missing args prints usage to stderr (exit 64)" {
  run bash "$SCRIPT"
  [ "$status" -eq 64 ]
}

@test "CLI: classify with no path prints usage to stderr (exit 64)" {
  run bash "$SCRIPT" classify
  [ "$status" -eq 64 ]
}

@test "CLI: unknown subcommand prints usage to stderr (exit 64)" {
  run bash "$SCRIPT" frobnicate
  [ "$status" -eq 64 ]
}
