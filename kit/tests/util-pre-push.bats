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
  refute_output --partial "fails the text-hygiene gate"
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
  assert_output --partial "fails the text-hygiene gate"
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
  assert_output --partial "fails the text-hygiene gate"
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
  refute_output --partial "fails the text-hygiene gate"
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
  assert_output --partial "fails the text-hygiene gate"
}

# --- Project pre-push: text-hygiene verdict cache (fast path-(b)) ---

@test "project pre-push: first PASS records a verdict-cache entry" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  create_stub gh "42"
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  # A PASS must leave exactly one hash line in the cache file.
  [ -f "$TEST_REPO/.git/devshop-prtext-verdict-cache" ]
  run wc -l < "$TEST_REPO/.git/devshop-prtext-verdict-cache"
  [ "$output" -eq 1 ]
}

@test "project pre-push: identical re-push short-circuits to cached PASS without re-rolling the LLM" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  create_stub gh "42"
  # First push: reviewer PASSES, caches the verdict.
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  # Second push, same title/body/commits: flip the reviewer to FAIL. If the
  # cache short-circuits, the LLM is never invoked and the push still passes.
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  assert_output --partial "cached"
  refute_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: changing the commit set invalidates the cache and re-rolls the LLM" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  create_stub gh "42"
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  # New commit → different commit-set → different hash → cache miss.
  echo "more" >> "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add logout"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: a FAILed verdict is not cached (no false short-circuit)" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  create_stub gh "42"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  # No cache file should be written on a FAIL (or, if created, no matching line).
  if [ -f "$TEST_REPO/.git/devshop-prtext-verdict-cache" ]; then
    run wc -l < "$TEST_REPO/.git/devshop-prtext-verdict-cache"
    [ "$output" -eq 0 ]
  fi
  # Re-push still fails (the FAIL was never cached as a PASS).
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

# Arg-aware gh stub: distinct stdout per `gh` subcommand so PR_TITLE and
# PR_BODY are no longer conflated (the generic `create_stub gh "42"` returns
# "42" for every call, making title==body). Lets the title/body cache-key legs
# be exercised independently of the commit-set leg.
#   make_gh_stub <title> <body>
make_gh_stub() {
  cat > "$MOCK_BIN/gh" <<STUB
#!/bin/bash
case "\$*" in
  *"pr list"*)        echo "42" ;;
  *"--json title"*)   echo "$1" ;;
  *"--json body"*)    echo "$2" ;;
  *)                  echo "42" ;;
esac
STUB
  chmod +x "$MOCK_BIN/gh"
}

@test "project pre-push: changing ONLY the PR title invalidates the cache and re-rolls the LLM" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  make_gh_stub "Title A" "Body A"
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  # Same commits + body, edited title → different hash → cache miss → LLM fires.
  make_gh_stub "Title B" "Body A"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: changing ONLY the PR body invalidates the cache and re-rolls the LLM" {
  setup_branch_with_commits
  echo "doc" > "$TEST_REPO/README.md"
  git add README.md
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  make_gh_stub "Title A" "Body A"
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  # Same commits + title, edited body → different hash → cache miss → LLM fires.
  make_gh_stub "Title A" "Body B"
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

# The pr-surface primary-judgment NOTE in adversarial-review.sh governs LLM
# judgment (untestable at the bats layer), but its presence is load-bearing:
# delete it and clean PR text starts FAILing on "no reason given" again. Pin
# the phrase so an accidental deletion fails CI — mirrors extract-prod-url.bats's
# "go-live SKILL.md sources the helper" structural-anchor test.
@test "adversarial-review.sh keeps the pr-surface primary-judgment NOTE" {
  run grep -qF "do NOT fail on the empty" "$SCRIPTS_DIR/adversarial-review.sh"
  [ "$status" -eq 0 ]
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

# --- Devshop pre-push: feature-branch-to-main guard ---

@test "devshop pre-push: blocks feature branch push to main without pushToMainApproved" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feat/my-feature
  run bash "$PRE_PUSH" origin <<< "refs/heads/feat/my-feature abc123 refs/heads/main def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "BLOCKED: push to refs/heads/main from feature branch" ]]
  [[ "$output" =~ "/ak-merge-devshop" ]]
  # Error message must NOT print the bypass flag name (option 2: no self-serve)
  refute_output --partial "git -c devshop.pushToMainApproved"
}

@test "devshop pre-push: passes feature branch push to main when adversarial approves reason" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feat/my-feature
  mock_adversarial_review PASS
  GIT_CONFIG_PARAMETERS="'devshop.pushToMainApproved=/ak-merge-devshop Phase 3 — audit passed'" \
    run bash "$PRE_PUSH" origin <<< "refs/heads/feat/my-feature abc123 refs/heads/main def456"
  [ "$status" -eq 0 ]
  refute_output --partial "BLOCKED"
}

@test "devshop pre-push: blocks feature branch push to main when adversarial rejects reason" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feat/my-feature
  mock_adversarial_review FAIL "FAIL: reason does not name the /ak-merge-devshop ceremony"
  GIT_CONFIG_PARAMETERS="'devshop.pushToMainApproved=just a small doc fix'" \
    run bash "$PRE_PUSH" origin <<< "refs/heads/feat/my-feature abc123 refs/heads/main def456"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "pushToMainApproved reason rejected" ]]
}

@test "devshop pre-push: feature branch push to feature remote is not blocked" {
  setup_devshop_mode
  cd "$TEST_REPO" && git checkout -q -b feat/my-feature
  mock_adversarial_review PASS
  run bash "$PRE_PUSH" origin <<< "refs/heads/feat/my-feature abc123 refs/heads/feat/my-feature def456"
  [ "$status" -eq 0 ]
  refute_output --partial "BLOCKED"
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
  refute_output --partial "fails the text-hygiene gate"
}

# --- Project pre-push: PR-desc SHA-enumeration short-circuit (B3) ---
# Helper: install a `gh` stub that returns the PR number for `gh pr list ...`
# AND the body text for `gh pr view ... --json body --jq .body`. Single stub
# distinguishes by the second positional arg (`list` vs `view`).
#
# CONSTRAINT: $pr_body must not contain literal `$` characters. The outer
# heredoc below is unquoted (<<STUB) so $pr_body is expanded into the stub
# script at stub-creation time. Any embedded `$VAR` interpolations in
# pr_body would be evaluated then (typically silently yielding wrong text).
# Pass plain ASCII bodies or pre-interpolated strings only. Codified from
# home-os-skill-polish-batch Audit 1 low-severity finding (2026-05-20).
gh_stub_with_pr_body() {
  local pr_number="$1" pr_body="$2"
  cat > "$MOCK_BIN/gh" <<STUB
#!/bin/bash
case "\$2" in
  list) echo "$pr_number" ;;
  view) cat <<'BODY'
$pr_body
BODY
    ;;
  *) echo "" ;;
esac
exit 0
STUB
  chmod +x "$MOCK_BIN/gh"
}

@test "project pre-push: B3 short-circuit — PR body enumerates every SHA → PASS, no LLM call" {
  setup_branch_with_commits
  # Land a feat: commit (non-trivial, would normally invoke the reviewer).
  echo "feat" > "$TEST_REPO/feat.txt"
  git add feat.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add login"
  local sha
  sha=$(git rev-parse HEAD)
  # PR body names the full SHA — short-circuit should fire.
  gh_stub_with_pr_body "42" "Fresh PR body referencing commit $sha verbatim."
  # adversarial-review.sh stub would FAIL if invoked. Short-circuit prevents
  # the invocation entirely.
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  refute_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: B3 short-circuit — PR body uses 7-char abbrev SHA → PASS" {
  setup_branch_with_commits
  echo "feat" > "$TEST_REPO/feat.txt"
  git add feat.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add signup"
  local sha short
  sha=$(git rev-parse HEAD)
  short="${sha:0:7}"
  gh_stub_with_pr_body "42" "PR body uses short SHA $short — should still match."
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 0 ]
  refute_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: B3 fall-through — PR body missing the commit SHA → adversarial reviewer fires" {
  setup_branch_with_commits
  echo "feat" > "$TEST_REPO/feat.txt"
  git add feat.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add password reset"
  # PR body is stale (no SHAs at all). Should fall through to reviewer.
  gh_stub_with_pr_body "42" "Stale body without any commit references."
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: B3 fall-through — empty PR body → adversarial reviewer fires" {
  setup_branch_with_commits
  echo "feat" > "$TEST_REPO/feat.txt"
  git add feat.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: add magic link"
  gh_stub_with_pr_body "42" ""
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}

@test "project pre-push: B3 fall-through — PR body names FIRST SHA but not SECOND (partial-match) → adversarial reviewer fires" {
  # Multi-commit fixture. The earlier B3 tests all used single-commit branches,
  # which meant the short-circuit loop's `break` on first-non-match was
  # exercised only via "all match" or "none match" cases — the partial-match
  # fall-through codepath at kit/hooks/pre-push.sh:133-142 was dead. This case
  # exercises it: two commits, PR body names the first but not the second →
  # reviewer must fire.
  setup_branch_with_commits
  echo "feat1" > "$TEST_REPO/feat1.txt"
  git add feat1.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: first half"
  local sha1
  sha1=$(git rev-parse HEAD)
  echo "feat2" > "$TEST_REPO/feat2.txt"
  git add feat2.txt
  git -c user.email=test@test.com -c user.name=Test commit -q -m "feat: second half"
  # PR body names the first SHA; the second commit is unreferenced.
  gh_stub_with_pr_body "42" "PR body references first commit $sha1 verbatim but does not mention the second."
  mock_adversarial_review FAIL
  run bash "$PRE_PUSH" origin <<< "refs/heads/feature-x abc123 refs/heads/feature-x def456"
  [ "$status" -eq 1 ]
  assert_output --partial "fails the text-hygiene gate"
}
