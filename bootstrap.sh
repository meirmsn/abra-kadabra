#!/usr/bin/env bash
# Devshop entry point for cloud environments. Every environment's setup script is just:
#   git clone -q --bare https://x-access-token:<read-only token>@github.com/<owner>/<repo>.git /opt/devshop.git || true
#   git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash || true
# so what is here on main is live for every environment at its next cache rebuild. This file stays
# at the repo root, path unchanged, and only delegates to the install (install/README.md).
# Usage: bootstrap.sh [ref] (default: HEAD = main as cloned).
set -o pipefail
REF=${1:-HEAD}
git --git-dir=/opt/devshop.git show "$REF:install/bootstrap.sh" | bash -s "$REF"
