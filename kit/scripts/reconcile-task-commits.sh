#!/usr/bin/env bash
# What: Decide whether an "all done" tasks.md is trustworthy on /ak-build resume —
#       clean working tree AND implementation-commit count >= done-task count.
# Why:  /ak-build Step 0 resume keyed off tasks.md `done` markers alone, so a
#       dropped /ak-implement subagent that marked tasks done-before-commit (or
#       left work uncommitted) could make the next /ak-build silently skip Phase 2
#       to pre-ship with unfinished work. This reconciles markers against git
#       state before the resume check trusts them (spec § Behavior, D3).
# Does NOT: modify tasks.md, stamp per-task SHAs, run any phase, or guess which
#       task is missing — on a non-zero verdict the caller re-enters Phase 2,
#       which re-verifies per-task and no-ops if work is genuinely complete (D4).
#
# Usage:
#   reconcile-task-commits.sh <feature-dir> [base-ref]
#
#   <feature-dir>  path to specs/<feature>/ (the dir containing tasks.md). Required.
#   [base-ref]     git ref implementation commits are counted against.
#                  Optional; defaults to origin/main. Step 0 passes origin/$BASE;
#                  tests pass a local ref (origin/main may be absent in a fixture).
#
# Exit codes:
#   0  — trustworthy: clean tree AND impl-commit-count >= done-count. May skip Phase 2.
#   1  — not trustworthy: dirty tree, OR impl-commit-count < done-count. Must NOT skip.
#  64  — usage error: missing arg, tasks.md absent, base-ref unknown, or not a git repo.
#
# Why count-based, not per-SHA (D3, decisive): a plain rebase (/ak-merge-devshop
# Phase 1.0) or an operator `git commit --amend` preserves commit count, subjects,
# and a clean tree — so the count heuristic still passes after history rewrite.
# Per-task SHA stamping would false-fail on exactly the interrupted-then-rebased
# resume path this feature exists to protect. A count false-fail is cheap:
# re-entering Phase 2 re-verifies per-task and no-ops if work is genuinely complete.
#
# mawk portability: no \b word boundaries in awk (mawk lacks them); commit-prefix
# matches anchor with ($|[^...]) per the check-llm-mediated-na.sh precedent. The
# awk binary is selected at runtime (prefer mawk, fall back to awk) so the bats
# suite can pin AWK_BIN=mawk to catch a \b regression.
#
# Spec: specs/implement-resume-reconcile/spec.md § Behavior.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <feature-dir> [base-ref]" >&2
  exit 64
fi

FEATURE_DIR="$1"
BASE_REF="${2:-origin/main}"
TASKS_FILE="$FEATURE_DIR/tasks.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo "error: tasks.md not found at $TASKS_FILE" >&2
  exit 64
fi

# Must be inside a git work tree (count + tree checks both need git).
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 64
fi

# The base ref must resolve, else the commit-range count is meaningless.
if ! git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null 2>&1; then
  echo "error: base ref '$BASE_REF' does not resolve to a commit" >&2
  exit 64
fi

# Prefer mawk for consistency (devcontainer ships both); fall back to awk.
AWK_BIN="${AWK_BIN:-}"
if [ -z "$AWK_BIN" ]; then
  if command -v mawk >/dev/null 2>&1; then
    AWK_BIN="mawk"
  else
    AWK_BIN="awk"
  fi
fi

# --- 1. Clean-tree check -----------------------------------------------------
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ]; then
  echo "Resume reconcile NOT trustworthy: working tree is dirty — uncommitted task" >&2
  echo "  work present (git status --porcelain non-empty). A done marker on a task" >&2
  echo "  whose work is not committed is not trustworthy." >&2
  exit 1
fi

# --- 2. Count `done` tasks ---------------------------------------------------
# Matches the `**Status**: done` marker /ak-implement writes (implement/SKILL.md
# Step 2 task template). Tolerate optional surrounding bold + trailing space.
DONE_AWK='
  /^\*\*Status\*\*:[ \t]*done([ \t]*$|[ \t])/ { n++ }
  END { print n + 0 }
'
# Strip CR before counting so a CRLF-encoded tasks.md (e.g. authored on Windows)
# does not undercount — `done\r` would otherwise miss the line anchor below.
DONE_COUNT=$(tr -d '\r' < "$TASKS_FILE" | "$AWK_BIN" "$DONE_AWK")

# --- 3. Count implementation commits in <base>..HEAD -------------------------
# Subject lines in the range, EXCLUDING bookkeeping commits the pipeline emits:
#   chore(<feature>): Phase 0 spec skeleton ...   (Phase 0 skeleton)
#   chore(roadmap): ... / chore(todos): ...       (tracker-close commits)
#   chore(build-log): ...                         (Phase 4.0 BUILD-LOG commit)
# Everything else counts as an implementation commit.
#
# mawk-portable: no \b. Anchor the chore scope after the prefix with ($|[^...])
# style so chore(roadmapX) would NOT match chore(roadmap). The "Phase 0 spec
# skeleton" line is matched by its full distinctive substring.
IMPL_AWK='
  # chore(...): Phase 0 spec skeleton  — any chore scope, skeleton wording.
  /^chore\([^)]*\):[ \t]+Phase 0 spec skeleton/ { next }
  # chore(roadmap): ...  (scope exactly "roadmap")
  /^chore\(roadmap\):/ { next }
  # chore(todos): ...    (scope exactly "todos")
  /^chore\(todos\):/ { next }
  # chore(build-log): ... (scope exactly "build-log")
  /^chore\(build-log\):/ { next }
  { n++ }
  END { print n + 0 }
'
IMPL_COUNT=$(git log --format='%s' "$BASE_REF..HEAD" | "$AWK_BIN" "$IMPL_AWK")

# --- 4. Verdict --------------------------------------------------------------
if [ "$IMPL_COUNT" -ge "$DONE_COUNT" ]; then
  echo "Resume reconcile trustworthy: tree clean, done=$DONE_COUNT impl-commits=$IMPL_COUNT (>= done)."
  exit 0
fi

MISSING=$((DONE_COUNT - IMPL_COUNT))
echo "Resume reconcile NOT trustworthy: done=$DONE_COUNT impl-commits=$IMPL_COUNT" >&2
echo "  — $MISSING done task(s) have no matching commit; not trustworthy." >&2
exit 1
