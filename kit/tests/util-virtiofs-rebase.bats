#!/usr/bin/env bats
# Tests for kit/scripts/virtiofs-rebase.sh
# Mechanized virtiofs phantom-rebase recovery ladder: rebase → checkStat-retry →
# merge-fallback, with phantom-vs-real-conflict discrimination by unmerged-path
# presence (not stderr string). Genuine conflicts return exit 10/11 to the caller.
# See specs/virtiofs-rebase-auto-switch/spec.md § Tests (~18 cases).
#
# Two harnesses:
#   A. git-stub-on-PATH — a fake `git` shim, table-driven via env vars, records
#      every argv line to $GIT_ARGV_LOG so a test can assert which flags a call
#      carried. Used for the phantom/ladder paths that real git can't
#      deterministically produce (the flake is non-reproducible by construction).
#   B. real-repo fixtures — genuine git for the clean / genuine-conflict / usage /
#      worktree-routing / no-config-leak / ancestor paths.

setup() {
  load helpers/setup
  SCRIPT="$SCRIPTS_DIR/virtiofs-rebase.sh"

  # --- Real-repo fixture: main + feature branch (clean FF base by default) -----
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.email "test@test.com"
  git -C "$REPO" config user.name "Test"
  printf 'line1\nline2\n' > "$REPO/shared.txt"
  git -C "$REPO" add shared.txt
  git -C "$REPO" commit -q -m "base"
  git -C "$REPO" checkout -q -b feat
}

# --- git-stub harness --------------------------------------------------------
# Installs a fake `git` on PATH driven by per-case env vars. Each subcommand
# response is scripted; argv is logged to $GIT_ARGV_LOG.
#
# Env knobs (response tokens: ok | phantom | conflict | other):
#   STUB_REBASE1    first plain `rebase <anchor>`            (default phantom)
#   STUB_REBASE_CS  the `-c ... rebase` checkStat retry      (default ok)
#   STUB_MERGE      `merge <anchor> --no-edit`               (default ok)
#   STUB_INPROGRESS_AFTER_R1  if "yes", a rebase is "in progress" after rebase1
#                   fails (drives the F244 / abort-guard cases). default "no".
install_git_stub() {
  setup_mock_bin
  export GIT_ARGV_LOG="$BATS_TEST_TMPDIR/git-argv.log"
  : > "$GIT_ARGV_LOG"
  export GIT_STATE_DIR="$BATS_TEST_TMPDIR/git-state"
  mkdir -p "$GIT_STATE_DIR"
  : "${STUB_REBASE1:=phantom}"
  : "${STUB_REBASE_CS:=ok}"
  : "${STUB_MERGE:=ok}"
  : "${STUB_INPROGRESS_AFTER_R1:=no}"
  export STUB_REBASE1 STUB_REBASE_CS STUB_MERGE STUB_INPROGRESS_AFTER_R1

  cat > "$MOCK_BIN/git" <<'STUB'
#!/usr/bin/env bash
# Fake git: log argv, then dispatch by subcommand + flags. A "conflict" response
# writes an unmerged sentinel so the subsequent `diff --diff-filter=U` reports a
# path; a "phantom"/"other" response leaves NO unmerged sentinel (clean tree).
echo "$*" >> "$GIT_ARGV_LOG"

UNMERGED_SENTINEL="$GIT_STATE_DIR/unmerged"
REBASE_SENTINEL="$GIT_STATE_DIR/rebase-in-progress"

# Detect whether this invocation carries the checkStat retry flags.
HAS_CHECKSTAT=no
HAS_TRUSTCTIME=no
for a in "$@"; do
  case "$a" in
    core.checkStat=minimal) HAS_CHECKSTAT=yes ;;
    core.trustctime=false)  HAS_TRUSTCTIME=yes ;;
  esac
done

# Strip leading -C <path> and -c <kv> options to find the subcommand.
sub=""
while [ $# -gt 0 ]; do
  case "$1" in
    -C) shift 2 ;;
    -c) shift 2 ;;
    *) sub="$1"; shift; break ;;
  esac
done
rest=("$@")

emit_conflict() { touch "$UNMERGED_SENTINEL"; echo "CONFLICT (content)" >&2; }

case "$sub" in
  rebase)
    # rebase --abort
    if [ "${rest[0]:-}" = "--abort" ]; then
      rm -f "$REBASE_SENTINEL"
      exit 0
    fi
    if [ "$HAS_CHECKSTAT" = "yes" ] && [ "$HAS_TRUSTCTIME" = "yes" ]; then
      # checkStat retry
      case "$STUB_REBASE_CS" in
        ok)       rm -f "$REBASE_SENTINEL"; exit 0 ;;
        phantom)  echo "error: Your local changes would be overwritten" >&2; exit 1 ;;
        conflict) emit_conflict; exit 1 ;;
      esac
    else
      # first plain rebase
      case "$STUB_REBASE1" in
        ok)       exit 0 ;;
        phantom)
          echo "error: Your local changes would be overwritten" >&2
          [ "$STUB_INPROGRESS_AFTER_R1" = "yes" ] && touch "$REBASE_SENTINEL"
          exit 1 ;;
        conflict)
          # genuine conflict — phantom string emitted too, to prove the helper
          # discriminates by unmerged paths, not the stderr string (D3).
          echo "error: Your local changes would be overwritten" >&2
          emit_conflict
          exit 1 ;;
      esac
    fi
    ;;
  merge)
    case "$STUB_MERGE" in
      ok)       exit 0 ;;
      conflict) emit_conflict; exit 1 ;;
      other)    echo "fatal: some other merge error" >&2; exit 128 ;;
    esac
    ;;
  diff)
    # diff --diff-filter=U --name-only → list unmerged paths if sentinel set.
    if [ -f "$UNMERGED_SENTINEL" ]; then
      echo "shared.txt"
    fi
    exit 0
    ;;
  rev-parse)
    # rev-parse --git-path rebase-merge|rebase-apply — echo a path that exists
    # (the sentinel-backed dir) only when a rebase is "in progress".
    want="${rest[1]:-}"
    if [ "$want" = "rebase-merge" ] && [ -f "$REBASE_SENTINEL" ]; then
      d="$GIT_STATE_DIR/rebase-merge"; mkdir -p "$d"; echo "$d"; exit 0
    fi
    # otherwise echo a non-existent path
    echo "$GIT_STATE_DIR/$want-absent"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
STUB
  chmod +x "$MOCK_BIN/git"
}

# Run the script with the stub git on PATH.
run_stub() {
  run bash "$SCRIPT" "$@"
}

# =============================================================================
# A. real-repo fixtures
# =============================================================================

# --- Case 1: clean rebase, first try (real repo) ---
@test "case 1: clean rebase first try → exit 0, RESULT: rebased" {
  git -C "$REPO" checkout -q main
  echo "advance" > "$REPO/main-only.txt"
  git -C "$REPO" add main-only.txt
  git -C "$REPO" commit -q -m "advance main"
  git -C "$REPO" checkout -q feat
  echo "feat" > "$REPO/feat-only.txt"
  git -C "$REPO" add feat-only.txt
  git -C "$REPO" commit -q -m "feat work"

  ( cd "$REPO" && run bash "$SCRIPT" main
    echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 0 ]
  grep -qx "RESULT: rebased" "$BATS_TEST_TMPDIR/o"
}

# --- Case 5: genuine rebase conflict, first try (real repo) ---
@test "case 5: genuine rebase conflict → exit 10, RESULT: conflict-rebase, rebase in progress" {
  printf 'line1\nFEAT\n' > "$REPO/shared.txt"
  git -C "$REPO" add shared.txt
  git -C "$REPO" commit -q -m "feat edits shared"
  git -C "$REPO" checkout -q main
  printf 'line1\nMAIN\n' > "$REPO/shared.txt"
  git -C "$REPO" add shared.txt
  git -C "$REPO" commit -q -m "main edits shared"
  git -C "$REPO" checkout -q feat

  ( cd "$REPO" && run bash "$SCRIPT" main
    echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 10 ]
  grep -qx "RESULT: conflict-rebase" "$BATS_TEST_TMPDIR/o"
  # rebase left in progress (helper did NOT abort)
  [ -d "$REPO/.git/rebase-merge" ] || [ -d "$REPO/.git/rebase-apply" ]
}

# --- Case 11: usage — no anchor arg ---
@test "case 11: no anchor arg → exit 64, names usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 64 ]
  echo "$output" | grep -qi "usage"
}

# --- Case 12: usage — too many args ---
@test "case 12: three positional args → exit 64" {
  run bash "$SCRIPT" one two three
  [ "$status" -eq 64 ]
  echo "$output" | grep -qi "usage"
}

# --- Case 13: worktree-path routing (real repo, invoked from a different cwd) ---
@test "case 13: worktree-path arg2 routes git via -C → exit 0, rebase lands in worktree" {
  git -C "$REPO" checkout -q main
  echo "advance" > "$REPO/main-only.txt"
  git -C "$REPO" add main-only.txt
  git -C "$REPO" commit -q -m "advance main"
  git -C "$REPO" checkout -q feat
  echo "feat" > "$REPO/feat-only.txt"
  git -C "$REPO" add feat-only.txt
  git -C "$REPO" commit -q -m "feat work"
  local before_tip after_tip main_tip
  before_tip=$(git -C "$REPO" rev-parse feat)
  main_tip=$(git -C "$REPO" rev-parse main)

  # Invoke from a dir OUTSIDE the repo — routing must come from arg2, not cwd.
  ( cd "$BATS_TEST_TMPDIR" && run bash "$SCRIPT" main "$REPO"
    echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 0 ]
  grep -qx "RESULT: rebased" "$BATS_TEST_TMPDIR/o"
  after_tip=$(git -C "$REPO" rev-parse feat)
  [ "$before_tip" != "$after_tip" ]                          # feat tip moved
  git -C "$REPO" merge-base --is-ancestor "$main_tip" feat   # main now ancestor
}

# --- Case 15: clean success emits exactly RESULT: rebased (no fall-through) ---
@test "case 15: clean run emits exactly RESULT: rebased, not a fallback variant" {
  git -C "$REPO" checkout -q main
  echo "advance" > "$REPO/main-only.txt"
  git -C "$REPO" add main-only.txt
  git -C "$REPO" commit -q -m "advance main"
  git -C "$REPO" checkout -q feat
  echo "feat" > "$REPO/feat-only.txt"
  git -C "$REPO" add feat-only.txt
  git -C "$REPO" commit -q -m "feat work"

  ( cd "$REPO" && run bash "$SCRIPT" main
    echo "$status" > "$BATS_TEST_TMPDIR/s"; printf '%s' "$output" > "$BATS_TEST_TMPDIR/o" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 0 ]
  grep -qx "RESULT: rebased" "$BATS_TEST_TMPDIR/o"
  ! grep -q "rebased-checkstat" "$BATS_TEST_TMPDIR/o"
  ! grep -q "merged-fallback" "$BATS_TEST_TMPDIR/o"
}

# --- Case 16: checkstat path uses inline -c flags, never git config (stub) ---
@test "case 16: rebased-checkstat run uses inline -c flags, never git config" {
  # Drive the checkStat rung via the stub; assert the retry argv carried the
  # inline -c flags AND that no `git config core.checkStat ...` write ever ran
  # (the inline-flag invariant — flags must not leak repo-global).
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=ok run_stub main
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "RESULT: rebased-checkstat"
  grep -q "core.checkStat=minimal" "$GIT_ARGV_LOG"
  ! grep -E "^config .*core\.checkStat" "$GIT_ARGV_LOG"
}

# --- Case 17: rebase end-state leaves anchor as ancestor (real repo) ---
@test "case 17: successful run leaves anchor as ancestor of HEAD" {
  # The merged-fallback rung guarantees the branch tip descends from the anchor;
  # a clean rebase produces the same end-state contract Phase 1.1's audit range
  # depends on. Assert the contract on a real successful run.
  git -C "$REPO" checkout -q main
  echo "advance" > "$REPO/main-only.txt"
  git -C "$REPO" add main-only.txt
  git -C "$REPO" commit -q -m "advance main"
  local main_tip
  main_tip=$(git -C "$REPO" rev-parse main)
  git -C "$REPO" checkout -q feat
  echo "feat" > "$REPO/feat-only.txt"
  git -C "$REPO" add feat-only.txt
  git -C "$REPO" commit -q -m "feat work"

  ( cd "$REPO" && run bash "$SCRIPT" main
    echo "$status" > "$BATS_TEST_TMPDIR/s" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 0 ]
  git -C "$REPO" merge-base --is-ancestor "$main_tip" feat
}

# --- Case 18: conflict exit leaves state for the caller (case 5 companion) ---
@test "case 18: after exit 10 unmerged paths present + rebase still in progress" {
  printf 'line1\nFEAT\n' > "$REPO/shared.txt"
  git -C "$REPO" add shared.txt
  git -C "$REPO" commit -q -m "feat edits shared"
  git -C "$REPO" checkout -q main
  printf 'line1\nMAIN\n' > "$REPO/shared.txt"
  git -C "$REPO" add shared.txt
  git -C "$REPO" commit -q -m "main edits shared"
  git -C "$REPO" checkout -q feat

  ( cd "$REPO" && run bash "$SCRIPT" main
    echo "$status" > "$BATS_TEST_TMPDIR/s" )
  [ "$(cat "$BATS_TEST_TMPDIR/s")" -eq 10 ]
  # Helper did NOT clean up: unmerged paths remain, rebase still in progress.
  [ -n "$(git -C "$REPO" diff --diff-filter=U --name-only)" ]
  [ -d "$REPO/.git/rebase-merge" ] || [ -d "$REPO/.git/rebase-apply" ]
}

# =============================================================================
# B. git-stub harness (phantom / ladder paths)
# =============================================================================

# --- Case 2: checkstat retry success ---
@test "case 2: rebase1 phantom, checkstat rebase succeeds → exit 0, RESULT: rebased-checkstat" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=ok run_stub main
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "RESULT: rebased-checkstat"
}

# --- Case 3: checkstat retry carries BOTH flags (regression sentinel) ---
@test "case 3: checkstat retry argv carries core.checkStat=minimal AND core.trustctime=false" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=ok run_stub main
  [ "$status" -eq 0 ]
  local retry_line
  retry_line=$(grep "rebase" "$GIT_ARGV_LOG" | grep "core.checkStat=minimal" | head -1)
  [ -n "$retry_line" ]
  echo "$retry_line" | grep -q "core.checkStat=minimal"
  echo "$retry_line" | grep -q "core.trustctime=false"
}

# --- Case 4: merge fallback success ---
@test "case 4: both rebases phantom, merge succeeds → exit 0, RESULT: merged-fallback" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=phantom STUB_MERGE=ok run_stub main
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "RESULT: merged-fallback"
}

# --- Case 6: genuine conflict surfaced by the checkstat retry ---
@test "case 6: rebase1 phantom, checkstat rebase conflicts → exit 10, RESULT: conflict-rebase" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=conflict run_stub main
  [ "$status" -eq 10 ]
  echo "$output" | grep -qx "RESULT: conflict-rebase"
}

# --- Case 7: genuine conflict in the merge fallback ---
@test "case 7: both rebases phantom, merge conflicts → exit 11, RESULT: conflict-merge" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=phantom STUB_MERGE=conflict run_stub main
  [ "$status" -eq 11 ]
  echo "$output" | grep -qx "RESULT: conflict-merge"
}

# --- Case 8: merge fallback non-conflict error ---
@test "case 8: both rebases phantom, merge other-error (no unmerged) → exit 1, RESULT: error" {
  install_git_stub
  STUB_REBASE1=phantom STUB_REBASE_CS=phantom STUB_MERGE=other run_stub main
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "RESULT: error:"
}

# --- Case 9: discrimination by unmerged-path, not stderr string ---
@test "case 9: rebase1 emits phantom string BUT has unmerged paths → exit 10 (conflict)" {
  install_git_stub
  # STUB_REBASE1=conflict emits the phantom "would be overwritten" string AND sets
  # the unmerged sentinel. The helper must classify by the unmerged path, not the
  # stderr string → conflict-rebase / 10, never falling through to checkstat.
  STUB_REBASE1=conflict run_stub main
  [ "$status" -eq 10 ]
  echo "$output" | grep -qx "RESULT: conflict-rebase"
  # Prove it did NOT run the checkstat retry (no argv line carried the flags).
  ! grep -q "core.checkStat=minimal" "$GIT_ARGV_LOG"
}

# --- Case 10: F244 rescheduled-pick variant ---
@test "case 10: rebase1 fails with rebase IN PROGRESS, clean tree, no unmerged → recovery ladder (not conflict)" {
  install_git_stub
  # Phantom failure that leaves a rebase in progress (the rescheduled-pick shape)
  # but NO unmerged paths. Must route to the checkstat retry (and succeed), NOT
  # misclassify as a conflict. The abort-guard must fire (rebase --abort logged).
  STUB_REBASE1=phantom STUB_INPROGRESS_AFTER_R1=yes STUB_REBASE_CS=ok run_stub main
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "RESULT: rebased-checkstat"
  grep -q "rebase --abort" "$GIT_ARGV_LOG"         # abort-guard fired
  grep -q "core.checkStat=minimal" "$GIT_ARGV_LOG"  # checkstat retry ran
}

# --- Case 14: abort-guard — no rebase in progress, script does not die ---
@test "case 14: rebase1 phantom with NO rebase in progress → abort guarded, ladder continues" {
  install_git_stub
  # rebase1 phantom-fails but leaves NO rebase in progress (sentinel unset). The
  # abort-guard must NOT call `rebase --abort` (would be a no-op error), and the
  # script must continue to the checkstat retry and succeed.
  STUB_REBASE1=phantom STUB_INPROGRESS_AFTER_R1=no STUB_REBASE_CS=ok run_stub main
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx "RESULT: rebased-checkstat"
  ! grep -q "rebase --abort" "$GIT_ARGV_LOG"   # guard held: none in progress
}
