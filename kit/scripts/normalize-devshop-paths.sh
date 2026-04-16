#!/usr/bin/env bash
# Rewrite devshop kit/ paths to workspace .devshopkit/ paths.
# Preserves absolute /devshop/kit/ references (those work from any cwd).
# Used by init-devshop.sh (copy) and check-security-files-freshness.sh (diff).
sed 's|/devshop/kit/|@@DK@@|g; s|kit/|.devshopkit/|g; s|@@DK@@|/devshop/kit/|g'
