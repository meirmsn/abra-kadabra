#!/usr/bin/env bash
# What: Pre-push guards for devshop hygiene — unified script for both repos
# Why: Single source of truth, symlinked into .hooks/pre-push by create-devshop-symlinks.sh.
#      Mirrors kit/hooks/pre-commit.sh (.hooks/pre-commit symlink pattern). Before this
#      file existed, the entire ~160-line pre-push body was duplicated as a [locked] file
#      in template/.husky/pre-push and had to propagate per-project on every change.
# Does NOT: Run code quality tools (lint/typecheck/gitleaks) — those live in .husky/* if
#           a repo wants them at push time. The husky-side wrapper is the husky-shim
#           bridge; this script is the policy.

# Husky v9's hook shim runs hooks with `sh -e "$hook"` regardless of shebang.
# Re-exec under bash for here-string + grep -P features used below.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"

# pre-push receives ref info on stdin: <local-ref> <local-sha> <remote-ref> <remote-sha>
# (one line per ref pair). Read once — every check below operates on $INPUT.
INPUT=$(cat)

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
REMOTE_NAME="${1:-origin}"

# --- Check 0: short-circuits common to both repos ---
[ -z "$BRANCH" ] && exit 0                                         # detached HEAD
echo "$INPUT" | awk '{print $2}' | grep -qE '^0{40}$' && exit 0    # branch deletion

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

# Detect devshop-self mode: workspace IS the devshop repo (opened directly in VS Code).
# kit/ is a real directory in the devshop repo but always a symlink (.devshopkit) in
# projects, so the test "kit/ exists AND is not a symlink" is the load-bearing
# distinguisher (mirrors the same probe in kit/hooks/pre-commit.sh).
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  REPO_MODE="devshop"
else
  REPO_MODE="project"
fi

# --- Check 1: main/master push behavior (per-repo) ---
if [ "$REPO_MODE" = "devshop" ]; then
  # On main already: release.sh territory — short-circuit.
  [ "$BRANCH" = "main" ] && exit 0
  [ "$BRANCH" = "master" ] && exit 0

  # On a feature branch pushing to main: require devshop.pushToMainApproved
  # matching the branch name. /ak-merge-devshop Phase 3 sets this via
  # `git -c devshop.pushToMainApproved="$BRANCH" push origin HEAD:main`.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    remote_ref=$(echo "$line" | awk '{print $3}')
    case "$remote_ref" in
      refs/heads/main|refs/heads/master)
        APPROVED=$(git config --get devshop.pushToMainApproved 2>/dev/null || echo "")
        if [ "$APPROVED" != "$BRANCH" ]; then
          echo "❌ BLOCKED: push to $remote_ref from feature branch '$BRANCH'." >&2
          echo "" >&2
          echo "  Devshop pushes to main go through /ak-merge-devshop, which sets" >&2
          echo "  devshop.pushToMainApproved as part of the merge ceremony." >&2
          echo "" >&2
          echo "  If you need to push manually (recovery, release.sh):" >&2
          echo "    git -c devshop.pushToMainApproved=\"$BRANCH\" push origin HEAD:main" >&2
          exit 1
        fi
        ;;
    esac
  done <<< "$INPUT"
else
  # Project: BLOCK direct push to main/master. No bypass — projects deploy via
  # PR-merge → CI → Vercel and the remote enforces the same rule via branch
  # protection. Parse each ref-pair from stdin so all forms are caught:
  #   git push                              (current branch → matching remote)
  #   git push origin local-branch:main     (rename)
  #   git push origin HEAD:main             (HEAD-style)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    remote_ref=$(echo "$line" | awk '{print $3}')
    case "$remote_ref" in
      refs/heads/main|refs/heads/master)
        echo "❌ BLOCKED: direct push to $remote_ref." >&2
        echo "" >&2
        echo "  $remote_ref is PR-only — projects deploy via PR-merge → CI → Vercel." >&2
        echo "  Push your feature branch and open a PR instead:" >&2
        echo "" >&2
        echo "    git branch <save-name>            # preserve your work" >&2
        echo "    git reset --hard origin/main      # restore main to upstream" >&2
        echo "    git checkout <save-name>" >&2
        echo "    git push -u origin <save-name>" >&2
        echo "    gh pr create" >&2
        echo "" >&2
        echo "  No bypass available for this check. The remote enforces the same" >&2
        echo "  rule via GitHub branch protection; this local check fails fast." >&2
        exit 1
        ;;
    esac
  done <<< "$INPUT"
fi

# --- Check 2: PR description staleness (project only) ---
# Devshop has no PRs (release.sh tags + pushes direct to main), so `gh pr list`
# always returns empty there — the check used to live in /devshop/.husky/pre-push
# as dead code and was deleted. It belongs only on the project surface.
if [ "$REPO_MODE" = "project" ]; then
  PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

  if [ -n "$PR" ]; then
    # Get commits in this PR (all commits on branch relative to main)
    COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)

    # Conventional-commit short-circuit: skip LLM review if all commits are
    # trivially-prefixed AND zero source files changed. The prefix-check alone
    # is bypassable — `chore: rewrite auth flow` would skip the PR-desc check
    # despite shipping substantive code. Requiring zero source-file changes
    # closes that hole. Source roots: apps/*/src/, packages/*/src/.
    ALL_TRIVIAL=true
    ANY_COMMIT=false
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      ANY_COMMIT=true
      subj=$(echo "$line" | sed 's/^[a-f0-9]* //')
      if ! echo "$subj" | grep -qE '^(chore|docs|style|test|ci|build|perf)(\([^)]*\))?!?:'; then
        ALL_TRIVIAL=false
        break
      fi
    done <<< "$COMMITS"

    # Even when every prefix is trivial, treat any source-file change as
    # non-trivial. A mis-prefixed substantive commit must not slip past the
    # PR-desc check.
    if [ "$ANY_COMMIT" = "true" ] && [ "$ALL_TRIVIAL" = "true" ]; then
      SOURCE_CHANGES=$(git diff --name-only origin/main..HEAD 2>/dev/null \
        | grep -E '^(apps/[^/]+/src/|packages/[^/]+/src/)' || true)
      if [ -n "$SOURCE_CHANGES" ]; then
        ALL_TRIVIAL=false
      fi
    fi

    # Fast path-(a) short-circuit: if the PR body enumerates every commit
    # SHA on the branch (full 40-char OR abbreviated to ≥7), the body is
    # demonstrably current. Skip the LLM call — the adversarial reviewer
    # would PASS this exact shape anyway, and the LLM round-trip is the
    # slowest step in pre-push on a clean re-push. The check is exact-
    # SHA-match only; the reviewer still handles judgment cases (partial
    # SHA, commit-subject overlap, sub-7-char matches).
    PR_BODY_HAS_ALL_SHAS=false
    if [ "$ANY_COMMIT" = "true" ] && [ "$ALL_TRIVIAL" = "false" ]; then
      PR_BODY=$(gh pr view "$PR" --json body --jq '.body' 2>/dev/null || echo "")
      if [ -n "$PR_BODY" ]; then
        BRANCH_SHAS=$(git log --format='%H' "origin/main..HEAD" 2>/dev/null || true)
        PR_BODY_HAS_ALL_SHAS=true
        ANY_SHA=false
        while IFS= read -r sha; do
          [ -z "$sha" ] && continue
          ANY_SHA=true
          # Match full SHA or any abbreviation ≥7 chars (Git's default-min).
          if ! printf '%s' "$PR_BODY" \
             | grep -qE "${sha}|${sha:0:12}|${sha:0:10}|${sha:0:8}|${sha:0:7}"; then
            PR_BODY_HAS_ALL_SHAS=false
            break
          fi
        done <<< "$BRANCH_SHAS"
        # No commits = nothing to match against = fall through.
        [ "$ANY_SHA" = "false" ] && PR_BODY_HAS_ALL_SHAS=false
      fi
    fi

    if [ "$ANY_COMMIT" = "true" ] \
       && [ "$ALL_TRIVIAL" = "false" ] \
       && [ "$PR_BODY_HAS_ALL_SHAS" = "false" ]; then
      # Non-trivial commits + PR body did NOT enumerate every SHA — adversarial
      # review of PR text hygiene (accuracy + readability + body shape).
      BYPASS_REASON=$(git config --get devshop.prTextHygieneReason 2>/dev/null || echo "")

      # Invoke shared adversarial engine (same as commit guards).
      # Engine gathers PR title/body/commits itself from the current branch.
      if ! REVIEW_OUTPUT=$(bash "$DEVSHOP/kit/scripts/adversarial-review.sh" \
             prTextHygieneReason \
             "${BYPASS_REASON:-no reason given}" 2>&1); then
        echo "❌ Pre-push: PR #${PR} title/description/body-shape fails the text-hygiene gate." >&2
        echo "" >&2
        echo "Reviewer assessment:" >&2
        echo "$REVIEW_OUTPUT" | sed 's/^/  /' >&2
        echo "" >&2
        echo "Options:" >&2
        echo "  1. Update PR via: gh pr edit $PR --title \"...\" --body \"...\"" >&2
        echo "     then retry the push." >&2
        echo "  2. Bypass (adversarially reviewed): " >&2
        echo "     git -c devshop.prTextHygieneReason=\"<specific reason>\" push ..." >&2
        exit 1
      fi
    fi
  fi
fi

# --- Check 3: tree + stash cleanliness (both repos) ---
DIRTY=$(git status --porcelain 2>/dev/null | head -20 || true)
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ' || echo "0")

if [ -n "$DIRTY" ] || [ "$STASH_COUNT" -gt 0 ]; then
  BYPASS_REASON=$(git config --get devshop.dirtyPushReason 2>/dev/null || echo "")

  if ! REVIEW_OUTPUT=$(bash "$DEVSHOP/kit/scripts/adversarial-review.sh" \
         dirtyPushReason \
         "${BYPASS_REASON:-no reason given}" 2>&1); then
    echo "❌ Pre-push: local state is not clean at push time." >&2
    echo "" >&2
    [ -n "$DIRTY" ] && { echo "Dirty files:"; echo "$DIRTY" | sed 's/^/  /'; } >&2
    [ "$STASH_COUNT" -gt 0 ] && echo "Stash entries: $STASH_COUNT" >&2
    echo "" >&2
    echo "Reviewer assessment:" >&2
    echo "$REVIEW_OUTPUT" | sed 's/^/  /' >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Commit or stash-and-drop your changes first." >&2
    echo "  2. Clear stashes with 'git stash drop' if no longer needed." >&2
    echo "  3. Bypass (adversarially reviewed):" >&2
    echo "     git -c devshop.dirtyPushReason=\"<specific reason>\" push ..." >&2
    exit 1
  fi
fi

exit 0
