#!/usr/bin/env bats
# Tests for template/.husky/post-merge + template/.husky/post-checkout
# Auto-run `pnpm install --frozen-lockfile` when pnpm-lock.yaml changes in
# a merge or branch switch. No-op otherwise.

setup() {
  load helpers/setup
  setup_mock_bin
  DEVSHOP_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
  # Hooks live at the REPO root (above kit/). Use the template versions as
  # canonical — devshop repo has its own copies that ship to new projects.
  POST_MERGE="$(cd "$DEVSHOP_ROOT/.." && pwd)/.husky/post-merge"
  POST_CHECKOUT="$(cd "$DEVSHOP_ROOT/.." && pwd)/.husky/post-checkout"
  create_test_repo
}

# --- post-merge ---

@test "post-merge: no-op when pnpm-lock.yaml not in diff" {
  create_capturing_stub pnpm ""
  (cd "$TEST_REPO" && \
    echo "unrelated" > file.txt && \
    git add file.txt && \
    git commit -q -m "add file" && \
    git update-ref ORIG_HEAD HEAD~1 && \
    bash "$POST_MERGE")
  [ ! -f "$MOCK_BIN/pnpm.args" ]
}

@test "post-merge: runs pnpm install when pnpm-lock.yaml changed" {
  create_capturing_stub pnpm ""
  (cd "$TEST_REPO" && \
    echo "deps" > pnpm-lock.yaml && \
    git add pnpm-lock.yaml && \
    git commit -q -m "bump deps" && \
    git update-ref ORIG_HEAD HEAD~1 && \
    bash "$POST_MERGE")
  [ -f "$MOCK_BIN/pnpm.args" ]
  grep -q 'install --frozen-lockfile' "$MOCK_BIN/pnpm.args"
}

# --- post-checkout ---

@test "post-checkout: no-op on file checkout (flag=0)" {
  create_capturing_stub pnpm ""
  (cd "$TEST_REPO" && bash "$POST_CHECKOUT" HEAD HEAD 0)
  [ ! -f "$MOCK_BIN/pnpm.args" ]
}

@test "post-checkout: no-op on branch checkout when lockfile unchanged" {
  create_capturing_stub pnpm ""
  (cd "$TEST_REPO" && \
    echo "unrelated" > other.txt && \
    git add other.txt && \
    git commit -q -m "add other" && \
    prev=$(git rev-parse HEAD~1) && \
    new=$(git rev-parse HEAD) && \
    bash "$POST_CHECKOUT" "$prev" "$new" 1)
  [ ! -f "$MOCK_BIN/pnpm.args" ]
}

@test "post-checkout: runs pnpm install on branch checkout when lockfile changed" {
  create_capturing_stub pnpm ""
  (cd "$TEST_REPO" && \
    echo "deps" > pnpm-lock.yaml && \
    git add pnpm-lock.yaml && \
    git commit -q -m "bump deps" && \
    prev=$(git rev-parse HEAD~1) && \
    new=$(git rev-parse HEAD) && \
    bash "$POST_CHECKOUT" "$prev" "$new" 1)
  [ -f "$MOCK_BIN/pnpm.args" ]
  grep -q 'install --frozen-lockfile' "$MOCK_BIN/pnpm.args"
}
