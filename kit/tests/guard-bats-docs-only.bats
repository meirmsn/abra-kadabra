#!/usr/bin/env bats
# Tests for the docs-only bats-skip predicate in .husky/pre-commit.
# On main/master, a staged diff of ONLY *.md paths skips the full kit bats
# suite (guaranteed no-op — the suite tests scripts/hooks/templates, never
# Markdown). The predicate lives inline in .husky/pre-commit and can't be
# sourced independently (the hook calls lint-staged, gitleaks, bats). We test a
# fixture holding identical logic; the parity test (last) asserts the
# production block matches the fixture — catches drift.

setup() {
  load helpers/setup
  create_test_repo

  # Fixture = the production predicate verbatim + an echo so tests can read it.
  PREDICATE_FIXTURE="$BATS_TEST_TMPDIR/docs-only-fixture.sh"
  cat > "$PREDICATE_FIXTURE" <<'PRED'
#!/usr/bin/env bash
_docs_only_diff=0
_staged_files=$(git diff --cached --name-only)
if [ -n "$_staged_files" ] && ! printf '%s\n' "$_staged_files" | grep -qvE '\.md$'; then
  _docs_only_diff=1
fi
echo "$_docs_only_diff"
PRED
  chmod +x "$PREDICATE_FIXTURE"

  # Production hook lives at the repo root (above kit/).
  HUSKY_PRECOMMIT="$(cd "$TESTS_DIR/../.." && pwd)/.husky/pre-commit"
}

run_predicate() {
  run env -C "$TEST_REPO" bash "$PREDICATE_FIXTURE"
}

# --- Behavior: the docs-only predicate ---

@test "docs-only: every staged path ends in .md → 1" {
  stage_file PLAN.md "forward plan"
  stage_file kit/docs/guide/note.md "a guide edit"
  stage_file BUILD-LOG.md "a ship entry"
  run_predicate
  assert_success
  assert_output "1"
}

@test "mixed: a .md plus a .sh → 0 (full suite runs)" {
  stage_file kit/TODOS.md "a todo"
  stage_file kit/scripts/foo.sh "echo hi"
  run_predicate
  assert_output "0"
}

@test "non-md only: a .sh → 0" {
  stage_file kit/scripts/foo.sh "echo hi"
  run_predicate
  assert_output "0"
}

@test "empty staged set → 0 (not treated as docs-only)" {
  run_predicate
  assert_output "0"
}

@test "anchor: a path containing .md but not ending in it → 0" {
  # Guards the trailing `$` anchor against a future weakening to `grep md`.
  stage_file readme.md.txt "not markdown"
  run_predicate
  assert_output "0"
}

# --- Parity: production block matches the fixture (drift protection) ---

@test "parity: docs-only predicate in .husky/pre-commit matches the fixture" {
  local production fixture
  production=$(sed -n '/^_docs_only_diff=0/,/^fi$/p' "$HUSKY_PRECOMMIT")
  fixture=$(sed -n '/^_docs_only_diff=0/,/^fi$/p' "$PREDICATE_FIXTURE")
  [ -n "$production" ]
  [ "$production" = "$fixture" ]
}
