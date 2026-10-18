#!/usr/bin/env bash
# The site's local run (the reviewer's browser serves it): static files on 127.0.0.1:$PORT.
set -euo pipefail
exec python3 -m http.server --bind 127.0.0.1 "$PORT"
