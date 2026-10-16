#!/usr/bin/env bash
# The devshop's deploy (specs/devshop-deploy-comment.md): the devshop is released when `fast` and `slow`
# pass on main, which the ci.yml `deploy` job waits for; projects get it when they pin it. Nothing is
# deployed, so this only writes, to $GITHUB_OUTPUT, what the merged PR's deploy comment reads
# (runtime/scripts/deploy-comment.mjs): deployed=yes first (main already has the commit), then version,
# previous_version, url and rollback.
# Inputs: BUILD_SHA (the commit), BEFORE (the previous tip of main; all zeros on a first push),
# GITHUB_SERVER_URL and GITHUB_REPOSITORY (set by GitHub; the URL is built here, so the repo names no
# repository), GITHUB_OUTPUT.
# Exit 0 = written; 2 = an input is missing or malformed (the comment then says the deploy failed and
# may be live, which is true: main has it).
set -euo pipefail

fail() { echo "deploy.sh: $*" >&2; exit 2; }
[ -n "${GITHUB_OUTPUT:-}" ] || fail "GITHUB_OUTPUT is not set"
echo "deployed=yes" >>"$GITHUB_OUTPUT"
[[ "${BUILD_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || fail "BUILD_SHA is not a commit: '${BUILD_SHA:-}'"
[[ "${BEFORE:-}" =~ ^[0-9a-f]{40}$ ]] || fail "BEFORE is not a commit: '${BEFORE:-}'"
[[ "${GITHUB_SERVER_URL:-}" =~ ^https://[A-Za-z0-9.-]+$ ]] || fail "GITHUB_SERVER_URL is not an https origin"
[[ "${GITHUB_REPOSITORY:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "GITHUB_REPOSITORY is not owner/name"

previous=${BEFORE:0:12}
[ "$BEFORE" != 0000000000000000000000000000000000000000 ] || previous=unknown
{
  echo "version=${BUILD_SHA:0:12}"
  echo "previous_version=$previous"
  echo "url=$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$BUILD_SHA"
  echo "rollback=revert \`${BUILD_SHA:0:12}\`"
} >>"$GITHUB_OUTPUT"
echo "deploy.sh: released ${BUILD_SHA:0:12} (replacing $previous)"
