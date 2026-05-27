#!/bin/bash
# What: prepare-commit-msg helper — appends Git trailers when Layer 1 bypass flags
#       are present on the commit. Runs ONCE per commit, after pre-commit, before
#       the commit message is finalized.
# Why: Bypasses recorded as trailers travel with the commit (survive rebase, push,
#      clone) and are universally greppable via `git log --format=%B`. Audit-time
#      `/ak-docs-review` and `/ak-tests-review` harvest these trailers from the
#      commit range and surface each one as a [bypass-revisit] finding.
#
# Usage (from .husky/prepare-commit-msg): bash <this-script> "$1" "$2" "$3"
#   $1: path to commit-message file (always provided by Git)
#   $2: source — "message" / "template" / "merge" / "squash" / "commit" / "" (optional)
#   $3: SHA of an existing commit (when $2 == "commit") (optional)
#
# Idempotent: re-running on the same message file does not duplicate trailers
# (`git interpret-trailers --in-place` collapses duplicate keys + values).
#
# Skip on: merge / squash / commit-source-amend (those messages are already
# written; Git is just opening them for a touch-up). Bypass flags are commit-time
# context — they don't apply to message-edits.

set -euo pipefail

MSG_FILE="${1:-}"
MSG_SOURCE="${2:-}"

[ -z "$MSG_FILE" ] && exit 0
[ -f "$MSG_FILE" ] || exit 0

case "$MSG_SOURCE" in
  merge|squash|commit) exit 0 ;;
esac

# Only run inside a git repo (skip standalone invocations).
git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0

DOCS_REASON=$(git config --get devshop.docsCoverageReason 2>/dev/null || true)
TESTS_REASON=$(git config --get devshop.testsCoverageReason 2>/dev/null || true)
BATS_REASON=$(git config --get devshop.batsSkipReason 2>/dev/null || true)
CLAUDE_MD_REASON=$(git config --get devshop.claudeMdClassification 2>/dev/null || true)

if [ -n "$DOCS_REASON" ]; then
  git interpret-trailers --in-place \
    --trailer "Docs-Coverage-Bypass: $DOCS_REASON" \
    "$MSG_FILE"
fi

if [ -n "$TESTS_REASON" ]; then
  git interpret-trailers --in-place \
    --trailer "Tests-Coverage-Bypass: $TESTS_REASON" \
    "$MSG_FILE"
fi

if [ -n "$BATS_REASON" ]; then
  git interpret-trailers --in-place \
    --trailer "Bats-Skip-Reason: $BATS_REASON" \
    "$MSG_FILE"
fi

if [ -n "$CLAUDE_MD_REASON" ]; then
  git interpret-trailers --in-place \
    --trailer "Claude-MD-Classification: $CLAUDE_MD_REASON" \
    "$MSG_FILE"
fi

exit 0
