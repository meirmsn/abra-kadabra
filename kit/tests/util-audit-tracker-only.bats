#!/usr/bin/env bats
# Tests for kit/scripts/preship/audit-tracker-only.sh
# Classifies a git range as tracker-only (exit 0, caller short-circuits) vs
# has-source-surface (exit 1, caller audits); usage error exits 64.
# Spec: specs/ak-check-docs-orphan-stubs/spec.md § Tests (D2 matrix).

setup() {
  load helpers/setup
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/audit-tracker-only.sh"
}

# Stage two commits so HEAD~1..HEAD is a real range. The first arg is a
# space-separated list of paths changed in the second commit.
two_commit_diff() {
  echo "base" > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add base.md
  git -C "$TEST_REPO" commit -q -m "baseline"
  local path
  for path in "$@"; do
    mkdir -p "$TEST_REPO/$(dirname "$path")"
    echo "changed" > "$TEST_REPO/$path"
  done
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "change"
}

run_audit() {
  run bash -c "cd '$TEST_REPO' && bash '$SCRIPT' '$1'"
}

# === D2 matrix ===

@test "tracker-only diff → exit 0" {
  two_commit_diff kit/TODOS.md PLAN.md kit/version
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "mixed tracker + source diff → exit 1" {
  two_commit_diff kit/TODOS.md kit/scripts/foo.sh
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "pure source diff → exit 1" {
  two_commit_diff kit/scripts/foo.sh
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "guide-doc-only diff → exit 1 (NOT short-circuited)" {
  two_commit_diff kit/docs/guide/workflow.md
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "test-only diff → exit 1" {
  two_commit_diff kit/tests/util-x.bats
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "friction-log-only diff → exit 0" {
  two_commit_diff kit/FRICTION-LOG.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "tracker prefix boundary: kit/versioning.md → exit 1 (exact-anchored, not prefix)" {
  # Regression guard for the Gate 5 + Gate 6 cross-confirmed over-match: the
  # file trackers (TODOS/ROADMAP/version) are matched EXACTLY, so a future
  # non-tracker whose name shares the prefix must NOT short-circuit as tracker.
  two_commit_diff kit/versioning.md
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "tracker prefix boundary: kit/ROADMAPER + kit/TODOS-archive.md → exit 1" {
  two_commit_diff kit/ROADMAPER kit/TODOS-archive.md
  run_audit "HEAD~1..HEAD"
  assert_failure 1
}

@test "kit/notes/** stays a dir-prefix tracker → exit 0" {
  two_commit_diff kit/notes/projects/foo.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "kit/docs/CHANGELOG.md is a tracker (the ONLY kit/docs/ path that is) → exit 0" {
  # D2's trickiest boundary: kit/docs/CHANGELOG.md short-circuits, but the rest
  # of kit/docs/ (esp. kit/docs/guide/**) does NOT — covered by the guide-doc
  # test above. This pins the tracker SIDE of that boundary so a regression
  # collapsing or widening the dedicated CHANGELOG case arm is caught.
  two_commit_diff kit/docs/CHANGELOG.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "remaining D2 trackers (BUILD-LOG/PRODUCT-ROADMAP/DEPS-WATCH/kit/ROADMAP) → exit 0" {
  # The top-level docs case arm has five tokens; only PLAN.md was exercised
  # above. Pin the other four + kit/ROADMAP.md so a dropped/mistyped arm can't
  # silently re-introduce orphan stubs for those doc-merge types.
  two_commit_diff BUILD-LOG.md PRODUCT-ROADMAP.md DEPS-WATCH.md kit/ROADMAP.md
  run_audit "HEAD~1..HEAD"
  assert_success
  assert_output --partial "short-circuit"
}

@test "empty diff → exit 0" {
  run_audit "HEAD..HEAD"
  assert_success
}

@test "usage error (no range arg) → exit 64" {
  run bash "$SCRIPT"
  assert_failure 64
  assert_output --partial "Usage:"
}

@test "unresolvable range (bad/rewritten SHA) → exit 1, does NOT false short-circuit" {
  # A failing `git diff` (e.g. a rewritten-history audited-at SHA fed to the
  # pre-Step-2 short-circuit) must NOT be swallowed into an empty-diff exit-0
  # verdict — that would skip a real audit. Safe direction is exit 1 (audit).
  echo base > "$TEST_REPO/base.md"
  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m baseline
  run_audit "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef..HEAD"
  assert_failure 1
}
