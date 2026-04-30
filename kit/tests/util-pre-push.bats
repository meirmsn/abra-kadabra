#!/usr/bin/env bats
# Tests for kit/hooks/pre-push.sh — the unified pre-push policy script that
# both .husky/pre-push wrappers exec into via .hooks/pre-push symlink.
# Repo mode (project vs devshop) is detected at runtime by probing whether
# `kit/` exists at the repo root and is a real directory (not a symlink) —
# the same probe kit/hooks/pre-commit.sh uses.

setup() {
  load helpers/setup
  setup_mock_bin
  DEVSHOP_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
  # sed-substitute the absolute /devshop/kit/scripts/adversarial-review.sh
  # path to point at the BATS mock. Pattern mirrors guard-clean-tree.bats.
  PRE_PUSH="$BATS_TEST_TMPDIR/pre-push.sh"
  sed "s|bash \"\$DEVSHOP/kit/scripts/adversarial-review.sh\"|bash $MOCK_BIN/adversarial-review.sh|" \
    "$DEVSHOP_ROOT/hooks/pre-push.sh" > "$PRE_PUSH"
  chmod +x "$PRE_PUSH"
  create_test_repo
  # Mock gh: returns empty (no PR found) by default
  create_stub gh ""
}

# Force devshop-self mode: the script's REPO_MODE detector probes for a real
# `kit/` directory at the repo root. Creating it in the test repo flips the
# branch from project (default) to devshop.
setup_devshop_mode() {
  mkdir -p "$TEST_REPO/kit"
}

# --- Project pre-push: refs-based main-block ---

@test "project pre-push: blocks push to refs/heads/main with no bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/main 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/main" ]]
  [[ "$output" =~ "No bypass available" ]]
}

@test "project pre-push: blocks push to refs/heads/master with no bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/master 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/master" ]]
}

@test "project pre-push: blocks rename-style push (HEAD:main) from feature branch" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PRE_PUSH" origin <<< "HEAD abc123 refs/heads/main 0000000000000000000000000000000000000000"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: direct push to refs/heads/main" ]]
}

@test "project pre-push: allows push to feature branch (clean tree, no PR)" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x 0000000000000000000000000000000000000000"
  [ "$status" -eq 0 ]
}

@test "project pre-push: short-circuits on detached HEAD" {
  cd "$TEST_REPO" && git checkout -q --detach HEAD 2>/dev/null
  run bash "$PRE_PUSH" origin <<< ""
  [ "$status" -eq 0 ]
}

@test "project pre-push: short-circuits on branch deletion (zero local sha)" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  run bash "$PRE_PUSH" origin <<< "(delete) 0000000000000000000000000000000000000000 refs/heads/old-branch abc123"
  [ "$status" -eq 0 ]
}

# --- Project pre-push: dirty-tree check ---

@test "project pre-push: blocks dirty tree without bypass when adversarial rejects" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "local state is not clean" ]]
}

@test "project pre-push: passes dirty tree when adversarial accepts the bypass" {
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
}

# --- Project pre-push: PR-desc trivial-prefix short-circuit (PR G) ---
# Helper: stand up a fake `origin/main` ref + commits diverging from it, so
# `git log origin/main..HEAD` and `git diff --name-only origin/main..HEAD`
# return real data.
setup_branch_with_commits() {
  cd "$TEST_REPO"
  # Mark the initial-commit branch as origin/main equivalent by giving git
  # a local "origin/main" ref pointing at HEAD.
  git update-ref refs/remotes/origin/main HEAD
  git checkout -q -b feature-x
}

@test "project pre-push: short-circuits PR-desc check when all commits trivial AND no source files change" {
  setup_branch_with_commits
  # Commit a doc-only change with chore: prefix — trivial AND non-source.
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "chore: bump readme"
  # gh stub returns a PR — would normally trigger the PR-desc review
  create_stub gh "42"
  # adversarial-review.sh stub will FAIL if invoked. Short-circuit must
  # prevent that invocation entirely. (Dirty-tree check still fires later
  # but tree is clean, so it short-circuits too.)
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  refute_output --partial "description appears stale"
}

@test "project pre-push: trivial prefix WITH source-file change DOES fire PR-desc review (PR G)" {
  setup_branch_with_commits
  # chore-prefixed commit but it touches packages/*/src/ — exploit case.
  mkdir -p "$TEST_REPO/packages/core/src"
  echo "export const x = 1;" > "$TEST_REPO/packages/core/src/foo.ts"
  git add packages/core/src/foo.ts
  git -c user.email=test@test.com -c user.name=Test commit -q -m "chore: tidy"
  create_stub gh "42"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "description appears stale"
}

@test "project pre-push: trivial prefix WITH apps/*/src change ALSO fires PR-desc review (PR G)" {
  setup_branch_with_commits
  mkdir -p "$TEST_REPO/apps/web/src"
  echo "export const y = 2;" > "$TEST_REPO/apps/web/src/bar.ts"
  git add apps/web/src/bar.ts
  git -c user.email=test@test.com -c user.name=Test commit -q -m "docs: oops actually code"
  create_stub gh "99"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "description appears stale"
}

@test "project pre-push: trivial-prefix + ONLY non-source files (e2e/, scripts/) still short-circuits" {
  setup_branch_with_commits
  mkdir -p "$TEST_REPO/e2e" "$TEST_REPO/scripts"
  echo "test" > "$TEST_REPO/e2e/foo.spec.ts"
  echo "#!/bin/bash" > "$TEST_REPO/scripts/build.sh"
  git add e2e/foo.spec.ts scripts/build.sh
  git -c user.email=test@test.com -c user.name=Test commit -q -m "test: add e2e + tweak script"
  create_stub gh "42"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  refute_output --partial "description appears stale"
}

@test "project pre-push: non-trivial prefix (feat:) still fires PR-desc review (existing behavior)" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  create_stub gh "42"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "description appears stale"
}

# --- Devshop pre-push: short-circuits main, runs only dirty-tree ---

@test "devshop pre-push: short-circuits on push from main (release.sh territory)" {
  setup_devshop_mode
  cd "$TEST_REPO"
  # Already on master/main from create_test_repo's initial commit; just run.
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
    git checkout -q -b main 2>/dev/null || git checkout -q main
  fi
  run bash "$PRE_PUSH" origin <<< "refs/heads/main abc123 refs/heads/main def456"
  [ "$status" -eq 0 ]
}

@test "devshop pre-push: blocks dirty tree when adversarial rejects" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feature-x
  echo "wip" > "$TEST_REPO/uncommitted.txt"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "local state is not clean" ]]
}

@test "devshop pre-push: passes clean tree on feature branch" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feature-x
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
}

# --- Devshop pre-push: project-only checks must NOT fire under devshop mode ---

@test "devshop pre-push: does NOT block push to refs/heads/main from devshop repo" {
  # Devshop releases push direct to main with tags — the project-only
  # main-block must short-circuit before triggering. This is the same
  # invariant that the prior /devshop/.husky/pre-push asserted by simply
  # not having the main-block code; under unified script + REPO_MODE
  # branching, we test it directly.
  setup_devshop_mode
  cd "$TEST_REPO"
  current_branch=$(git branch --show-current)
  if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
    git checkout -q -b main 2>/dev/null || git checkout -q main
  fi
  run bash "$PRE_PUSH" origin <<< "refs/heads/main abc123 refs/heads/main def456"
  [ "$status" -eq 0 ]
  refute_output --partial "BLOCKED: direct push to"
}

@test "devshop pre-push: does NOT invoke PR-desc check (devshop has no PRs)" {
  # If the PR-desc branch fired in devshop mode, the gh stub returning a PR
  # number + adversarial-review FAIL would block. Devshop mode must skip
  # the entire PR-desc block.
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feature-x
  create_stub gh "42"
  mock_adversarial_review PASS  # only fires for dirty-tree (clean here)
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  refute_output --partial "description appears stale"
}
