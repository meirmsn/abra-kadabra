#!/usr/bin/env bash
# Devshop container-start setup (runs as root via sudo on every start)

# Set root password if provided (enables human `su -` access)
if [ -f /workspace/.devcontainer/.env ]; then
  ROOT_PASSWORD=$(grep '^DEVCONTAINER_ROOT_PASSWORD=' /workspace/.devcontainer/.env | cut -d= -f2)
  if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "node:$ROOT_PASSWORD" | chpasswd
    echo "node ALL=(ALL:ALL) ALL" > /etc/sudoers.d/node
    chmod 0440 /etc/sudoers.d/node
  fi
fi
