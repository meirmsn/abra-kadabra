#!/usr/bin/env bash
# What: Mechanize the virtiofs phantom-rebase recovery ladder that
#       /ak-merge-devshop Phase 1.0 hand-drives: rebase <anchor> → on a phantom
#       false-failure, retry with reduced stat comparison → on a still-phantom,
#       fall back to merge. Genuine conflicts are returned to the caller.
# Why:  On macOS/linuxkit devcontainers, `git rebase` intermittently aborts with
#       "Your local changes ... would be overwritten" (or stalls as a rescheduled
#       pick) on a verifiably clean tree — a stat-cache race, not a real diff.
#       The proven manual fix (checkStat-retry then merge-fallback) was ~70 lines
#       of SKILL prose the agent re-ran each merge; mechanizing it makes devshop
#       merges stop stalling on the flake without operator hand-driving
#       (spec § Behavior, D1, D2).
# Does NOT: re-derive the anchor (caller passes it in as arg1), auto-resolve
#       genuine conflicts (it leaves git state as-is and returns exit 10/11 so the
#       caller's inline resolution path takes over — D4), discriminate phantom
#       from real conflict by the stderr string (it checks unmerged-path presence
#       instead — D3), or git-config the reduced-stat flags repo-global (they are
#       passed inline per-command — D2). cherry-pick / `am` keep their manual
#       inline recipes (out of scope — D5).
#
# Usage:
#   virtiofs-rebase.sh <anchor> [worktree-path]
#
#   <anchor>         the rebase target ref (e.g. origin/main or main). Required.
#                    The caller pre-selects it; the helper does not re-derive it.
#   [worktree-path]  optional. When given, every git call runs via
#                    `git -C "$worktree-path"`. When absent (or empty), git runs
#                    in the current repo. Mirrors the caller's GIT_CMD array.
#
# Exit codes + RESULT vocabulary:
#   0   RESULT: rebased            clean rebase, first try → proceed.
#   0   RESULT: rebased-checkstat  rebase succeeded after the reduced-stat retry
#                                  (phantom dodged) → proceed.
#   0   RESULT: merged-fallback    both rebase attempts phantom-failed; merge
#                                  fallback succeeded → proceed (Phase 2's
#                                  soft-reset discards the transient merge commit).
#   10  RESULT: conflict-rebase    genuine rebase conflict (unmerged paths);
#                                  rebase left in progress → caller resolves,
#                                  `add`, `rebase --continue`.
#   11  RESULT: conflict-merge     genuine conflict in the merge fallback; merge
#                                  left in progress → caller resolves, `add`,
#                                  `commit -F /tmp/merge-commit-msg.txt`.
#   1   RESULT: error: <msg>       unexpected failure (merge failed, not a
#                                  conflict) → surface to operator, halt.
#   64  usage: ...                 no <anchor> arg, or too many args.
#
# Discrimination (D3): a failed rebase/merge is a real conflict iff it left
# UNMERGED PATHS (`git diff --diff-filter=U --name-only` non-empty). Both phantom
# flavors ("would be overwritten" + the rescheduled-pick stall) leave a clean
# tree with no unmerged paths, so they route into the recovery ladder. This is
# more robust than stderr string-matching and auto-covers friction-log F244.
#
# set -euo pipefail interaction: rungs 1-3 invoke git calls that are expected to
# fail. Each captures its exit code (`rc=0; "${GIT[@]}" ... || rc=$?`) so `set -e`
# does not kill the script before discrimination runs.
#
# Spec: specs/virtiofs-rebase-auto-switch/spec.md § Behavior.

set -euo pipefail

# --- Arg parsing / usage -----------------------------------------------------
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <anchor> [worktree-path]" >&2
  exit 64
fi

ANCHOR="$1"
WORKTREE_PATH="${2:-}"

# Build the git argv array — (git) or (git -C "$worktree-path"). Every git call
# routes through "${GIT[@]}". Inline -c flags go AFTER any -C (git parses -C then
# -c), keeping the reduced-stat comparison scoped to the single retry command.
if [ -n "$WORKTREE_PATH" ]; then
  GIT=(git -C "$WORKTREE_PATH")
else
  GIT=(git)
fi

# --- Helpers -----------------------------------------------------------------

# True (0) if the failed operation left unmerged paths → a genuine conflict.
# Captures rather than asserts so `set -e` can't kill us before we branch.
has_unmerged_paths() {
  local out
  out=$("${GIT[@]}" diff --diff-filter=U --name-only 2>/dev/null || true)
  [ -n "$out" ]
}

# True (0) if a rebase is currently in progress (rebase-merge or rebase-apply
# state dir exists). Used to guard `rebase --abort` so a bare abort with no rebase
# in progress can't exit non-zero and trip `set -e`.
rebase_in_progress() {
  local mdir adir
  mdir=$("${GIT[@]}" rev-parse --git-path rebase-merge 2>/dev/null || true)
  adir=$("${GIT[@]}" rev-parse --git-path rebase-apply 2>/dev/null || true)
  [ -n "$mdir" ] && [ -d "$mdir" ] && return 0
  [ -n "$adir" ] && [ -d "$adir" ] && return 0
  return 1
}

# Abort a rebase only if one is in progress; never let it kill the script.
abort_rebase_if_any() {
  if rebase_in_progress; then
    "${GIT[@]}" rebase --abort 2>/dev/null || true
  fi
}

# --- Rung 1: plain rebase ----------------------------------------------------
rc=0
"${GIT[@]}" rebase "$ANCHOR" || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "RESULT: rebased"
  exit 0
fi
# Non-zero. Real conflict (unmerged paths) → return to caller as-is.
if has_unmerged_paths; then
  echo "RESULT: conflict-rebase"
  exit 10
fi
# No unmerged paths → phantom. Continue to rung 2.

# --- Rung 2: checkStat-reduced retry -----------------------------------------
abort_rebase_if_any
rc=0
"${GIT[@]}" -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR" || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "RESULT: rebased-checkstat"
  exit 0
fi
if has_unmerged_paths; then
  echo "RESULT: conflict-rebase"
  exit 10
fi
# Still phantom → continue to rung 3.

# --- Rung 3: merge fallback --------------------------------------------------
abort_rebase_if_any
rc=0
merge_err=$("${GIT[@]}" merge "$ANCHOR" --no-edit 2>&1) || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "RESULT: merged-fallback"
  exit 0
fi
if has_unmerged_paths; then
  echo "RESULT: conflict-merge"
  exit 11
fi
# Merge failed for some other (non-conflict) reason.
echo "RESULT: error: ${merge_err:-merge failed}"
exit 1
