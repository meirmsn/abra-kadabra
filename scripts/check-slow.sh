#!/usr/bin/env bash
# This repo's slow CI tier (spec specs/ci-fast-slow-tiers.md): CI's `slow` job runs it, after `fast`
# passed. End-to-end tests: the test files marked "# tier: slow" (the whole install, today).
# Usage: scripts/check-slow.sh   (an argument is ignored)
# Exit 0 = passed; 1 = failures; 2 = couldn't run.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
tests/run.sh slow
