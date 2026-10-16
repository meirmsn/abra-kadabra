#!/usr/bin/env bash
# The slow CI tier: end-to-end tests. CI's `slow` job runs it after `fast` passes. This project has
# no end-to-end tests yet, so it says so and passes. Replace the two lines below with the first
# end-to-end test the moment one exists: a required check that always passes proves nothing.
# Exit 0 = clean; 1 = failures; 2 = couldn't run.
set -uo pipefail
echo "check-slow: no end-to-end tests yet"
exit 0
