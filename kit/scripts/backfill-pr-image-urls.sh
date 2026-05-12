#!/usr/bin/env bash
# kit/scripts/backfill-pr-image-urls.sh
#
# One-time per-project backfill: walk a repo's merged PRs and rewrite
# /raw/<feature-branch>/ image URLs in PR bodies to /raw/<merge-sha>/
# so embeds survive `--delete-branch`. The forward fix at merge time
# lives in `/ak-go-live § Step 2.5` (which sources the same helper as
# this script — single source of truth).
#
# Per spec/pr-body-img-merge-sha-survival/spec.md § "API contracts" /
# "backfill-pr-image-urls.sh flags".
#
# Default mode is --dry-run; mutation requires explicit
# --accept-history-rewrite (D7c). Skips PRs with no head ref, no merge
# SHA, post-merge body edits (heuristic: updatedAt > mergedAt + 5min),
# or zero matching URLs. Writes a JSONL audit log per run.

set -euo pipefail

# -----------------------------------------------------------------------------
# Helper
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/rewrite-pr-body-urls.sh
source "$SCRIPT_DIR/lib/rewrite-pr-body-urls.sh"

# -----------------------------------------------------------------------------
# CLI parsing
# -----------------------------------------------------------------------------

usage() {
  cat <<'USAGE'
Usage: backfill-pr-image-urls.sh --owner <owner> --repo <repo> [options]

Rewrite PR-body /raw/<feature-branch>/ image URLs to /raw/<merge-sha>/
across a project's merged PRs so the embeds survive --delete-branch.

Required:
  --owner <owner>              GitHub org/user that owns the repo.
  --repo <repo>                Repo name.

Mode (exactly one — defaults to --dry-run if neither given):
  --dry-run                    Print planned rewrites; do not call gh pr edit.
  --accept-history-rewrite     Required to actually mutate PR bodies on GitHub.

Optional:
  --limit <N>                  Cap PR scan to most-recent N merged PRs (default 100).
  --since <YYYY-MM-DD>         Only consider PRs merged on or after this date.
  --audit-dir <path>           Override audit-log dir.
                               Default: ${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/
  --skip-edited                Skip PRs whose body was edited >5min after merge
                               (conservative — assumes the operator may have
                               manually fixed URLs). Default OFF: post-merge
                               edits are typically pipeline auto-edits (CI
                               checkbox marks, audit comments) that don't
                               touch image URLs, so suppressing rewrites on
                               that signal mis-skips real targets.
  --help, -h                   Print this message and exit.

Exit codes:
  0  completed (zero or more PRs processed; including all-skips)
  1  invalid CLI args (missing --owner/--repo, conflicting flags, unknown flag)
  2  gh unavailable or unauthenticated
  3  repo not found / no merged PRs returned at all
USAGE
}

OWNER=""
REPO=""
DRY_RUN=""
ACCEPT_HISTORY_REWRITE=""
LIMIT="100"
SINCE=""
AUDIT_DIR=""
SKIP_EDITED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --owner)
      OWNER="${2:-}"; shift 2 ;;
    --repo)
      REPO="${2:-}"; shift 2 ;;
    --dry-run)
      DRY_RUN="1"; shift ;;
    --accept-history-rewrite)
      ACCEPT_HISTORY_REWRITE="1"; shift ;;
    --limit)
      LIMIT="${2:-}"; shift 2 ;;
    --since)
      SINCE="${2:-}"; shift 2 ;;
    --audit-dir)
      AUDIT_DIR="${2:-}"; shift 2 ;;
    --skip-edited)
      SKIP_EDITED="1"; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "✖ Unknown flag: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

if [ -z "$OWNER" ]; then
  echo "✖ --owner is required" >&2
  usage >&2
  exit 1
fi
if [ -z "$REPO" ]; then
  echo "✖ --repo is required" >&2
  usage >&2
  exit 1
fi
if [ -n "$DRY_RUN" ] && [ -n "$ACCEPT_HISTORY_REWRITE" ]; then
  echo "✖ --dry-run and --accept-history-rewrite are mutually exclusive — pick one" >&2
  exit 1
fi
if [ -z "$DRY_RUN" ] && [ -z "$ACCEPT_HISTORY_REWRITE" ]; then
  # Default to dry-run with a banner that explains how to actually mutate.
  DRY_RUN="1"
  cat >&2 <<'BANNER'
ℹ Defaulting to --dry-run. No PR bodies will be modified.
  Re-run with --accept-history-rewrite to actually rewrite PR bodies.
BANNER
fi

# -----------------------------------------------------------------------------
# gh availability
# -----------------------------------------------------------------------------

# Allow tests to fake `gh` via _FAKE_GH=1 + a fixture file at $_FAKE_GH_FIXTURE.
# When set, the function below replaces real `gh pr list` / `gh pr edit` calls
# with deterministic fixture-driven behavior.
if [ "${_FAKE_GH:-}" = "1" ]; then
  gh() {
    if [ "${1:-}" = "pr" ] && [ "${2:-}" = "list" ]; then
      # Emit the canned fixture on stdout. Fixture is a JSON array of PR
      # objects with the same fields the real `gh pr list --json ...` would
      # return. The script doesn't care about the rest of the args.
      cat "${_FAKE_GH_FIXTURE:-/dev/null}"
      return 0
    fi
    if [ "${1:-}" = "pr" ] && [ "${2:-}" = "edit" ]; then
      # Capture the args + body to a file so tests can assert on it.
      # Last arg is --body-file <path>; preserve the body file's contents
      # in the capture so tests can check the rewritten body.
      local capture="${_FAKE_GH_CAPTURE:-/dev/null}"
      local body_path=""
      local prev=""
      for arg in "$@"; do
        if [ "$prev" = "--body-file" ]; then
          body_path="$arg"
        fi
        prev="$arg"
      done
      {
        echo "gh $*"
        if [ -n "$body_path" ] && [ -f "$body_path" ]; then
          echo "--- body ---"
          cat "$body_path"
          echo "--- end ---"
        fi
      } >> "$capture"
      return 0
    fi
    # Anything else (e.g. `gh auth status`) — pretend success.
    return 0
  }
else
  if ! command -v gh >/dev/null 2>&1; then
    echo "✖ gh CLI not found in PATH — install it from https://cli.github.com/" >&2
    exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "✖ gh is unauthenticated — run 'gh auth login'" >&2
    exit 2
  fi
fi

# -----------------------------------------------------------------------------
# Audit log setup
# -----------------------------------------------------------------------------

if [ -z "$AUDIT_DIR" ]; then
  AUDIT_DIR="${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls"
fi
mkdir -p "$AUDIT_DIR"
TS_UTC=$(date -u +'%Y-%m-%dT%H-%M-%SZ')
AUDIT_LOG="$AUDIT_DIR/${TS_UTC}.jsonl"
: > "$AUDIT_LOG"

echo "Audit log: $AUDIT_LOG" >&2

# -----------------------------------------------------------------------------
# Fetch merged PRs
# -----------------------------------------------------------------------------

# Build the gh pr list command. Fields used by the loop below:
#   number, headRefName, mergeCommit (object with .oid), body, mergedAt, updatedAt
GH_LIST_ARGS=(
  pr list
  --repo "$OWNER/$REPO"
  --state merged
  --limit "$LIMIT"
  --json "number,headRefName,mergeCommit,body,mergedAt,updatedAt"
)

PRS_JSON=$(gh "${GH_LIST_ARGS[@]}" 2>/dev/null || true)

if [ -z "$PRS_JSON" ] || [ "$PRS_JSON" = "[]" ]; then
  echo "✖ No merged PRs returned for $OWNER/$REPO" >&2
  exit 3
fi

# Apply --since filter (jq side — easier than juggling dates in bash).
if [ -n "$SINCE" ]; then
  PRS_JSON=$(echo "$PRS_JSON" | jq --arg since "$SINCE" '[.[] | select(.mergedAt >= $since)]')
fi

# -----------------------------------------------------------------------------
# Process each PR
# -----------------------------------------------------------------------------

# emit_audit_row <pr> <head_ref> <merge_sha> <merged_at> <updated_at>
#                <url_count_before> <url_count_after> <outcome> <reason>
emit_audit_row() {
  local pr="$1" head_ref="$2" merge_sha="$3" merged_at="$4" updated_at="$5"
  local before="$6" after="$7" outcome="$8" reason="$9"
  local dry_run="false"
  [ -n "$DRY_RUN" ] && dry_run="true"

  jq -n -c \
    --arg ts "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --argjson pr "$pr" \
    --arg head_ref "$head_ref" \
    --arg merge_sha "$merge_sha" \
    --arg merged_at "$merged_at" \
    --arg updated_at "$updated_at" \
    --argjson url_count_before "${before:-0}" \
    --argjson url_count_after "${after:-0}" \
    --arg outcome "$outcome" \
    --arg reason "$reason" \
    --argjson dry_run "$dry_run" \
    '{
      ts: $ts,
      pr: $pr,
      head_ref: (if $head_ref == "" then null else $head_ref end),
      merge_sha: (if $merge_sha == "" then null else $merge_sha end),
      merged_at: (if $merged_at == "" then null else $merged_at end),
      updated_at: (if $updated_at == "" then null else $updated_at end),
      url_count_before: $url_count_before,
      url_count_after: $url_count_after,
      outcome: $outcome,
      reason: (if $reason == "" then null else $reason end),
      dry_run: $dry_run
    }' >> "$AUDIT_LOG"
}

# Compare two ISO-8601 UTC timestamps; return 0 if updated > merged + 5min.
# Pure bash (no GNU date dependence beyond `date -d` which the devcontainer
# has). Heuristic per D7c: a 5-minute grace window; legitimate post-merge
# edits beyond that bump out.
post_merge_edit() {
  local merged="$1" updated="$2"
  [ -z "$merged" ] && return 1
  [ -z "$updated" ] && return 1
  local merged_epoch updated_epoch
  merged_epoch=$(date -d "$merged" +%s 2>/dev/null || echo 0)
  updated_epoch=$(date -d "$updated" +%s 2>/dev/null || echo 0)
  [ "$merged_epoch" -eq 0 ] && return 1
  [ "$updated_epoch" -eq 0 ] && return 1
  local delta=$(( updated_epoch - merged_epoch ))
  [ "$delta" -gt 300 ]
}

PROCESSED=0
echo "$PRS_JSON" | jq -c '.[]' | while IFS= read -r pr_json; do
  PR_NUMBER=$(echo "$pr_json" | jq -r '.number')
  HEAD_REF=$(echo "$pr_json" | jq -r '.headRefName // ""')
  MERGE_SHA=$(echo "$pr_json" | jq -r '.mergeCommit.oid // ""')
  MERGED_AT=$(echo "$pr_json" | jq -r '.mergedAt // ""')
  UPDATED_AT=$(echo "$pr_json" | jq -r '.updatedAt // ""')
  BODY=$(echo "$pr_json" | jq -r '.body // ""')

  PROCESSED=$(( PROCESSED + 1 ))

  if [ -z "$HEAD_REF" ]; then
    emit_audit_row "$PR_NUMBER" "" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" 0 0 "skip" "no-head-ref"
    echo "  PR #$PR_NUMBER: skip (no head-ref)" >&2
    continue
  fi

  if [ -z "$MERGE_SHA" ]; then
    emit_audit_row "$PR_NUMBER" "$HEAD_REF" "" "$MERGED_AT" "$UPDATED_AT" 0 0 "skip" "no-merge-sha"
    echo "  PR #$PR_NUMBER: skip (no merge-sha)" >&2
    continue
  fi

  # Materialize the body to a tmpfile, run the helper.
  BODY_IN=$(mktemp)
  BODY_OUT=$(mktemp)
  printf '%s' "$BODY" > "$BODY_IN"

  # Count matching URLs first — the post-merge-edit conservatism only
  # protects against clobbering URLs the operator may have already fixed
  # by hand. With zero matches there is nothing to clobber, so the edit
  # timing is irrelevant; report the truthful "no-matching-urls" reason.
  HEAD_REF_ESC=$(printf '%s' "$HEAD_REF" | perl -pe 's/([\/.+*?\[\]{}()^\$|\\])/\\$1/g')
  OWNER_REPO_ESC=$(printf '%s' "$OWNER/$REPO" | perl -pe 's/([\/.+*?\[\]{}()^\$|\\])/\\$1/g')
  PATTERN="https://github\\.com/${OWNER_REPO_ESC}/raw/${HEAD_REF_ESC}/"
  # m{} delimiter form — the embedded `/` in the URL would otherwise act
  # as the regex terminator and trip a perl syntax error.
  N=$(perl -ne "BEGIN{\$c=0}\$c+=()=m{${PATTERN}}g;END{print \$c}" "$BODY_IN")
  N=${N:-0}

  if [ "$N" -eq 0 ]; then
    emit_audit_row "$PR_NUMBER" "$HEAD_REF" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" 0 0 "skip" "no-matching-urls"
    echo "  PR #$PR_NUMBER: skip (no-matching-urls)" >&2
    rm -f "$BODY_IN" "$BODY_OUT"
    continue
  fi

  if [ -n "$SKIP_EDITED" ] && post_merge_edit "$MERGED_AT" "$UPDATED_AT"; then
    emit_audit_row "$PR_NUMBER" "$HEAD_REF" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" "$N" 0 "skip" "body-edited-post-merge"
    echo "  PR #$PR_NUMBER: skip (body-edited-post-merge, $N URL(s) at risk)" >&2
    rm -f "$BODY_IN" "$BODY_OUT"
    continue
  fi

  rewrite_pr_body_urls "$BODY_IN" "$BODY_OUT" "$OWNER/$REPO" "$HEAD_REF" "$MERGE_SHA"

  if [ -n "$DRY_RUN" ]; then
    emit_audit_row "$PR_NUMBER" "$HEAD_REF" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" "$N" "$N" "dry-run-would-rewrite" ""
    echo "  PR #$PR_NUMBER: would rewrite $N URL(s)" >&2
  else
    if gh pr edit "$PR_NUMBER" --repo "$OWNER/$REPO" --body-file "$BODY_OUT" >/dev/null 2>&1; then
      emit_audit_row "$PR_NUMBER" "$HEAD_REF" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" "$N" "$N" "rewrote" ""
      echo "  PR #$PR_NUMBER: rewrote $N URL(s)" >&2
    else
      emit_audit_row "$PR_NUMBER" "$HEAD_REF" "$MERGE_SHA" "$MERGED_AT" "$UPDATED_AT" "$N" "$N" "error" "gh-pr-edit-failed"
      echo "  PR #$PR_NUMBER: ERROR (gh pr edit failed)" >&2
    fi
  fi

  rm -f "$BODY_IN" "$BODY_OUT"
done

echo "Done. Audit log: $AUDIT_LOG" >&2
exit 0
