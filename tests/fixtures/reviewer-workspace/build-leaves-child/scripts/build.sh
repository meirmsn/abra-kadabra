#!/usr/bin/env bash
# A build that exits 0 but leaves a process running in the background.
set -euo pipefail
nohup python3 -c "import time; time.sleep(300)" "${LR_MARKER:-leftover}" >/dev/null 2>&1 &
cd apps/web
exec ./node_modules/.bin/site-tool build src dist
