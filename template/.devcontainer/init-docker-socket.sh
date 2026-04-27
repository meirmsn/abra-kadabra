#!/usr/bin/env bash
# What: At container start, match the in-container `docker` group's GID to the
#       GID of the host-bound /var/run/docker.sock, then add `node` to it. This
#       lets the unprivileged `node` user talk to the host docker engine via
#       the socket without sudo.
# Why:  The socket is bind-mounted from the host (see devcontainer.json
#       § mounts), so its GID inside the container matches the host's docker
#       group's GID — typically 998 on Debian, 999 on Ubuntu, varies by host.
#       Without GID alignment, `docker ps` from `node` returns
#       "permission denied while trying to connect to the Docker daemon socket".
# Idempotent. Safe to re-run on every container start.

set -euo pipefail

SOCK=/var/run/docker.sock

if [ ! -S "$SOCK" ]; then
  # Bind-mount missing — host probably isn't a Docker host (or socket path
  # differs, e.g. some Linux distros). Skip silently; supabase-bootstrap.sh
  # will surface the consequence as `blocked` when Gate 9 needs Docker.
  exit 0
fi

GID=$(stat -c '%g' "$SOCK")
if [ "$GID" = "0" ]; then
  # Socket is root:root on the host (uncommon — Docker Desktop on macOS or
  # rootful daemons may do this). Nothing to align; node can't talk to it
  # without sudo. Surface the situation but don't fail container start.
  echo "warn: /var/run/docker.sock is owned by root; node cannot talk to it directly"
  exit 0
fi

if getent group docker >/dev/null 2>&1; then
  CUR_GID=$(getent group docker | cut -d: -f3)
  if [ "$CUR_GID" != "$GID" ]; then
    groupmod -g "$GID" docker
  fi
else
  groupadd -g "$GID" docker
fi

if ! id -nG node | tr ' ' '\n' | grep -qx docker; then
  usermod -aG docker node
fi
