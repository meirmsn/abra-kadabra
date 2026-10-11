#!/usr/bin/env bash
# Devshop entry point for cloud environments. The environment's setup script is just:
#   git clone -q --bare https://x-access-token:<read-only token>@github.com/meirmsn/abra-kadabra.git /opt/devshop.git || true
#   git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true
# This file stays at the repo root so that script never changes. Usage: bootstrap.sh [ref] (default: HEAD = main).
# Until the v2 layout lands (W10.4.1), it delegates to the W10.1.2b spike bootstrap.
REF=${1:-HEAD}
git --git-dir=/opt/devshop.git show "$REF:kit/notes/revamp/spikes/w10-1-2b-thin/bootstrap.sh" | bash -s "$REF"
exit 0
