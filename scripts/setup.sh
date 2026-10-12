#!/usr/bin/env bash
# This repo's session setup: the devshop's session start runs it (runtime/hooks/session-start.sh),
# so the repo's checks can run: Prettier at the version package-lock.json pins.
set -euo pipefail
cd "$(dirname "$0")/.."
exec npm ci --ignore-scripts --no-audit --no-fund
