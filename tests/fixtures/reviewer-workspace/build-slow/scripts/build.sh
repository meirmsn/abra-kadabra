#!/usr/bin/env bash
# A build that never finishes within the reviewer's (shortened) BUILD_WAIT.
echo "building slowly"
exec python3 -c "import time; time.sleep(300)" "${LR_MARKER:-slow-build}"
