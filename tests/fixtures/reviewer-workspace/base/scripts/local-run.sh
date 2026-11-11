#!/usr/bin/env bash
# Serves what scripts/build.sh built, on 127.0.0.1:$PORT; installs and builds nothing.
set -euo pipefail
cd apps/web
[ -f dist/index.html ] || { echo "no build in apps/web/dist: run scripts/build.sh" >&2; exit 1; }
exec ./node_modules/.bin/site-tool serve dist "$PORT"
