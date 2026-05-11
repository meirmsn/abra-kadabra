#!/usr/bin/env bash
# kit/scripts/lib/rewrite-pr-body-urls.sh
#
# Tiny, sourceable helper exposing rewrite_pr_body_urls() for both
# `/ak-go-live § Step 2.5` (forward fix at merge time) and
# `kit/scripts/backfill-pr-image-urls.sh` (one-time per-project backfill).
#
# Single source of truth — no behavior drift between the forward fix and
# the backfill. Per spec/pr-body-img-merge-sha-survival/spec.md § "Helper
# extraction strategy" (Shape B).
#
# This file does NOT execute anything when sourced — it only defines the
# `rewrite_pr_body_urls` function. Safe to `source` from inside another
# script without `set -euo pipefail` interactions.

# rewrite_pr_body_urls <body-file-in> <body-file-out> <owner-repo> <head-ref> <merge-sha>
#
# Substitute every literal occurrence of
#   https://github.com/<owner-repo>/raw/<head-ref>/
# with
#   https://github.com/<owner-repo>/raw/<merge-sha>/
# in <body-file-in>; write the result to <body-file-out> (which may be
# the same path as <body-file-in> — handled via an internal tmpfile).
#
# - <owner-repo> scopes the URL match to a single repo so third-party-repo
#   /raw/ URLs survive verbatim.
# - <head-ref> is regex-escaped before pattern construction so slashed /
#   dotted / plus-containing branch names work (D4).
# - Idempotent: a second call on the rewritten body is a silent no-op
#   (the body now has <merge-sha> in URL slots, not <head-ref>) — what
#   makes the backfill safe to re-run.
#
# Prints a one-line summary to stderr:
#   rewrote <N> URL(s) (head=<head-ref> sha=<short-sha>)
# or
#   no /raw/<head-ref>/ URLs in body — nothing to rewrite
#
# Exit code: 0 always (no-op-on-empty is a valid outcome, not an error).
rewrite_pr_body_urls() {
  local body_in="$1"
  local body_out="$2"
  local owner_repo="$3"
  local head_ref="$4"
  local merge_sha="$5"

  if [ -z "$body_in" ] || [ -z "$body_out" ] || [ -z "$owner_repo" ] || [ -z "$head_ref" ] || [ -z "$merge_sha" ]; then
    echo "rewrite_pr_body_urls: missing arg(s); usage: rewrite_pr_body_urls <body-in> <body-out> <owner-repo> <head-ref> <merge-sha>" >&2
    return 0
  fi

  if [ ! -f "$body_in" ]; then
    echo "rewrite_pr_body_urls: body-in not found: $body_in" >&2
    return 0
  fi

  # Regex-escape both the owner-repo (may contain '.' / '-') and the
  # head-ref (may contain '/' for `feat/foo`, '.' for `chore/x.y`,
  # `+` etc.). Without escaping, `feat/foo` would pattern-match `feat<any>foo`.
  # The regression tests in
  # `kit/tests/util-go-live-step-25-body-rewrite.bats` cover slashed,
  # dotted, and plus-containing branch names.
  local owner_repo_esc head_ref_esc
  owner_repo_esc=$(printf '%s' "$owner_repo" | perl -pe 's/([\/.+*?\[\]{}()^\$|\\])/\\$1/g')
  head_ref_esc=$(printf '%s' "$head_ref" | perl -pe 's/([\/.+*?\[\]{}()^\$|\\])/\\$1/g')

  local pattern="https://github\\.com/${owner_repo_esc}/raw/${head_ref_esc}/"
  local replacement="https://github.com/${owner_repo}/raw/${merge_sha}/"

  # Count matches first so the stderr summary is accurate even when
  # body_in == body_out (in-place rewrite). Use perl's m{} regex delimiter
  # form so the embedded `/` characters in the URL pattern aren't mistaken
  # for regex terminators.
  local n
  n=$(perl -ne "BEGIN { \$c = 0 } \$c += () = m{${pattern}}g; END { print \$c }" "$body_in")
  n=${n:-0}

  local short_sha
  short_sha=${merge_sha:0:7}

  if [ "$n" -eq 0 ]; then
    # Silent attesting pass per D6 — leaves a one-line audit trail
    # in the operator's terminal without forcing a `gh pr edit` call.
    echo "no /raw/${head_ref}/ URLs in body — nothing to rewrite" >&2
    # Preserve byte-identical body when in-place / out differs from in.
    if [ "$body_in" != "$body_out" ]; then
      cp -- "$body_in" "$body_out"
    fi
    return 0
  fi

  # Write the rewrite to a tmpfile, then move into place. Supports
  # body_in == body_out (in-place rewrite) without a read-after-write race.
  local tmp
  tmp=$(mktemp)
  # perl -pe is preferred over sed here — sed's BRE/ERE differences across
  # platforms have bitten us elsewhere (see kit/scripts/populate-playwright-cache.sh
  # which standardized on perl for the same reason). Use the s{}{} delimiter
  # form so the embedded `/` characters in the URL pattern + replacement
  # don't collide with the regex terminator.
  perl -pe "s{${pattern}}{${replacement}}g" "$body_in" > "$tmp"
  mv -- "$tmp" "$body_out"

  echo "rewrote ${n} URL(s) (head=${head_ref} sha=${short_sha})" >&2
  return 0
}
