#!/bin/bash
# What: Pre-commit guards for devshop hygiene — unified script for both repos
# Why: Single source of truth, symlinked into .hooks/pre-commit by create-devshop-symlinks.sh
# Does NOT: Run code quality tools (lint, typecheck, gitleaks) — those live in .husky/pre-commit

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
SCRIPTS_DIR="$DEVSHOP/.devshop/scripts"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

case "$GIT_ROOT" in
  /workspace)
    # Project repo: full guard suite
    bash "$SCRIPTS_DIR/check-security-files-freshness.sh"
    bash "$SCRIPTS_DIR/check-clean-tree.sh"
    bash "$SCRIPTS_DIR/devshop-commit-guard.sh"
    ;;
  /devshop)
    # Devshop repo: clean tree + commit guards only
    bash "$SCRIPTS_DIR/check-clean-tree.sh"
    bash "$SCRIPTS_DIR/devshop-commit-guard.sh"
    ;;
esac
