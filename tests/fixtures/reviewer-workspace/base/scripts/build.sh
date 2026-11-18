#!/usr/bin/env bash
# Builds apps/web/dist from apps/web/src with the workspace's site tool.
set -euo pipefail
cd apps/web
exec ./node_modules/.bin/site-tool build src dist
