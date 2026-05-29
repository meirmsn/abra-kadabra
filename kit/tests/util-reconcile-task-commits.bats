#!/usr/bin/env bats
# Tests for kit/scripts/reconcile-task-commits.sh
# Resume-reconcile gate: an "all done" tasks.md is trustworthy only when the
# working tree is clean AND the implementation-commit count in <base>..HEAD
# (bookkeeping commits excluded) is >= the count of `done` tasks.
# See specs/implement-resume-reconcile/spec.md § Tests (9 cases).

setup() {
  load helpers/setup
  SCRIPT="$SCRIPTS_DIR/reconcile-task-commits.sh"

  # Fixture repo: init, configure user, base commit on `main`.
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.email "test@test.com"
  git -C "$REPO" config user.name "Test"
  echo "base" > "$REPO/README.md"
  git -C "$REPO" add README.md
  git -C "$REPO" commit -q -m "chore: base"
  BASE_REF="main"

  # Feature branch off main — implementation commits live in main..HEAD, the
  # same range Step 0 counts against (origin/$BASE..HEAD in production).
  git -C "$REPO" checkout -q -b feat/x

  FEATURE_DIR="$REPO/specs/feat"
  mkdir -p "$FEATURE_DIR"
}

# Write a tasks.md with $1 done tasks followed by $2 todo tasks, then commit the
# spec dir as a Phase-0-style bookkeeping commit (excluded from IMPL_COUNT) so the
# working tree is clean — mirroring production, where the spec/ dir is committed.
#   write_tasks <done_count> [todo_count]
write_tasks() {
  local done_count="$1" todo_count="${2:-0}" i
  : > "$FEATURE_DIR/tasks.md"
  for i in $(seq 1 "$done_count" 2>/dev/null); do
    [ "$done_count" -ge 1 ] || break
    printf '## Task: done-%s\n\n**Status**: done\n\n' "$i" >> "$FEATURE_DIR/tasks.md"
  done
  for i in $(seq 1 "$todo_count" 2>/dev/null); do
    [ "$todo_count" -ge 1 ] || break
    printf '## Task: todo-%s\n\n**Status**: todo\n\n' "$i" >> "$FEATURE_DIR/tasks.md"
  done
  git -C "$REPO" add specs
  git -C "$REPO" commit -q -m "chore(feat): Phase 0 spec skeleton (tasks fixture)"
}

# Make $1 implementation commits on a feature branch (each touches a tracked file).
#   make_impl_commits <count>
make_impl_commits() {
  local count="$1" i
  for i in $(seq 1 "$count"); do
    echo "task $i" > "$REPO/file-$i.txt"
    git -C "$REPO" add "file-$i.txt"
    git -C "$REPO" commit -q -m "feat(feat): task $i"
  done
}

# Run the helper from inside the fixture repo (git context follows cwd).
run_reconcile() {
  ( cd "$REPO" && run bash "$SCRIPT" "specs/feat" "$BASE_REF"; echo "$status" > "$BATS_TEST_TMPDIR/last_status"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/last_output" )
  status="$(cat "$BATS_TEST_TMPDIR/last_status")"
  output="$(cat "$BATS_TEST_TMPDIR/last_output")"
}

# --- Case 1: all-done-all-committed → pass (exit 0) ---

@test "case 1: 3 done, 3 impl commits, clean tree → exit 0 (trustworthy)" {
  write_tasks 3 0
  make_impl_commits 3
  run_reconcile
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "trustworthy"
}

# --- Case 2: done-count > impl-commit-count → fail (exit 1) ---

@test "case 2: 3 done, 1 impl commit, clean tree → exit 1 + counts in diag" {
  write_tasks 3 0
  make_impl_commits 1
  run_reconcile
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "done=3"
  echo "$output" | grep -q "impl-commits=1"
  echo "$output" | grep -qi "no matching commit"
}

# --- Case 3: dirty tree → fail (exit 1) ---

@test "case 3: 3 done, 3 commits, but uncommitted change → exit 1 + names dirty tree" {
  write_tasks 3 0
  make_impl_commits 3
  echo "uncommitted" > "$REPO/dirty.txt"   # untracked file → dirty
  run_reconcile
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "dirty"
}

# --- Case 4: partial-done → deterministic verdict (caller owns routing) ---

@test "case 4: 1 done + 2 todo, 1 impl commit → exit 0 (1 >= 1, pure count check)" {
  write_tasks 1 2
  make_impl_commits 1
  run_reconcile
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "done=1"
}

# --- Case 5: rebase-style — SHAs change, count+subjects+clean tree preserved ---

@test "case 5: rebase rewrites SHAs but preserves count → still exit 0 (D3 proof)" {
  write_tasks 3 0
  make_impl_commits 3
  # Reword every commit subject via a non-interactive filter-style rebase so
  # every SHA changes while count and a clean tree are preserved. (Subjects are
  # preserved-enough: bookkeeping exclusion keys off prefixes, untouched here.)
  # A per-task SHA-stamping approach would false-fail after this rewrite; the
  # count heuristic must still pass.
  local before_shas after_shas
  before_shas=$(git -C "$REPO" log --format='%H' main..HEAD | tr '\n' ' ')
  # Advance main by one commit, then rebase the feature branch onto the new tip.
  # The changed parent guarantees every replayed feature commit gets a new SHA,
  # while count + subjects + a clean tree are preserved — the exact shape a
  # /ak-merge-devshop Phase 1.0 rebase produces.
  git -C "$REPO" checkout -q main
  echo "advance" > "$REPO/main-advance.txt"
  git -C "$REPO" add main-advance.txt
  git -C "$REPO" commit -q -m "chore: advance main"
  git -C "$REPO" checkout -q feat/x
  git -C "$REPO" rebase --quiet main >/dev/null 2>&1
  after_shas=$(git -C "$REPO" log --format='%H' main..HEAD | tr '\n' ' ')
  [ "$before_shas" != "$after_shas" ]   # SHAs actually changed
  run_reconcile
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "impl-commits=3"
}

# --- Case 6: bookkeeping commits excluded (load-bearing) ---

@test "case 6: 3 impl + Phase0/roadmap/build-log bookkeeping → exit 0, no inflation" {
  write_tasks 3 0
  make_impl_commits 3
  # Add the four bookkeeping commit types the pipeline emits on a feature branch.
  git -C "$REPO" commit -q --allow-empty -m "chore(feat): Phase 0 spec skeleton (decisions)"
  git -C "$REPO" commit -q --allow-empty -m "chore(roadmap): track feat"
  git -C "$REPO" commit -q --allow-empty -m "chore(todos): close feat entry"
  git -C "$REPO" commit -q --allow-empty -m "chore(build-log): record feat"
  run_reconcile
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "impl-commits=3"   # NOT 7 — bookkeeping excluded
}

@test "case 6b: 2 impl + 4 bookkeeping commits, 3 done → exit 1 (exclusion load-bearing)" {
  # Same fixture shape as case 6 but only 2 real impl commits. If the
  # bookkeeping exclusion were broken (e.g. a prefix typo), the 4 chore
  # commits would inflate IMPL_COUNT to 6 and this would wrongly pass.
  write_tasks 3 0
  make_impl_commits 2
  git -C "$REPO" commit -q --allow-empty -m "chore(feat): Phase 0 spec skeleton (decisions)"
  git -C "$REPO" commit -q --allow-empty -m "chore(roadmap): track feat"
  git -C "$REPO" commit -q --allow-empty -m "chore(todos): close feat entry"
  git -C "$REPO" commit -q --allow-empty -m "chore(build-log): record feat"
  run_reconcile
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "impl-commits=2"
}

# --- Case 7: usage errors (exit 64) ---

@test "case 7a: missing feature-dir arg → exit 64 + Usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 64 ]
  echo "$output" | grep -q "Usage:"
}

@test "case 7b: tasks.md absent → exit 64" {
  rm -f "$FEATURE_DIR/tasks.md"
  ( cd "$REPO" && run bash "$SCRIPT" "specs/feat" "$BASE_REF"; echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 64 ]
  grep -qi "tasks.md not found" "$BATS_TEST_TMPDIR/o"
}

@test "case 7c: unresolvable base-ref → exit 64" {
  write_tasks 1 0
  make_impl_commits 1
  ( cd "$REPO" && run bash "$SCRIPT" "specs/feat" "origin/nonexistent"; echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 64 ]
  grep -qi "does not resolve" "$BATS_TEST_TMPDIR/o"
}

# --- Case 8: mawk parity (re-run case 6 with AWK_BIN=mawk) ---

@test "case 8: AWK_BIN=mawk yields identical verdict to default (case 6 shape)" {
  write_tasks 3 0
  make_impl_commits 3
  git -C "$REPO" commit -q --allow-empty -m "chore(feat): Phase 0 spec skeleton (decisions)"
  git -C "$REPO" commit -q --allow-empty -m "chore(roadmap): track feat"
  git -C "$REPO" commit -q --allow-empty -m "chore(build-log): record feat"
  ( cd "$REPO" && AWK_BIN=mawk run bash "$SCRIPT" "specs/feat" "$BASE_REF"; echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 0 ]
  grep -q "impl-commits=3" "$BATS_TEST_TMPDIR/o"
}

# --- Case 9: CRLF tasks.md counted correctly (regression sentinel for CR strip) ---

@test "case 9: CRLF tasks.md (3 done) with 2 impl commits → exit 1 (done counted)" {
  # Author tasks.md with CRLF line endings (e.g. Windows / mis-set editor).
  : > "$FEATURE_DIR/tasks.md"
  for i in 1 2 3; do
    printf '## Task: done-%s\r\n\r\n**Status**: done\r\n\r\n' "$i" >> "$FEATURE_DIR/tasks.md"
  done
  git -C "$REPO" add specs
  git -C "$REPO" commit -q -m "chore(feat): Phase 0 spec skeleton (CRLF tasks fixture)"
  make_impl_commits 2
  run_reconcile
  # With CR-stripping: done=3 > impl=2 → NOT trustworthy (exit 1). Without the
  # strip, the done\r lines miss the anchor → done undercounts to 0 → 2 >= 0
  # falsely passes (exit 0). Asserting exit 1 pins the fix.
  [ "$status" -eq 1 ]
  grep -q "done=3" "$BATS_TEST_TMPDIR/last_output"
}
