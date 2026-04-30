#!/bin/bash
# What: Pre-commit guards for devshop hygiene — unified script for both repos
# Why: Single source of truth, symlinked into .hooks/pre-commit by create-devshop-symlinks.sh
# Does NOT: Run code quality tools (lint, typecheck, gitleaks) — those live in .husky/pre-commit

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
SCRIPTS_DIR="$DEVSHOP/kit/scripts"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

# Detect devshop-self mode: workspace IS the devshop repo (opened directly in VS Code).
# kit/ is a real directory in the devshop repo but always a symlink (.devshopkit) in projects.
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  # Devshop-self mode: same checks as devshop repo
  bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-manifest.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-test-coverage.sh"
  bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
else
  case "$GIT_ROOT" in
    /workspace)
      # Project repo: full guard suite. check-exempt-additions runs BEFORE
      # check-test-coverage-project / check-docs-freshness-project so that bad
      # exempt entries surface first (the operator knows to fix the exempt
      # entry, not chase the gate it would have silenced).
      bash "$SCRIPTS_DIR/commit-hooks/check-security-files-freshness.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-exempt-additions.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-test-coverage-project.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-docs-freshness-project.sh"
      bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
      ;;
    /devshop)
      # Devshop repo: clean tree + manifest sync + test coverage + commit guards
      bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-manifest.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-test-coverage.sh"
      bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
      ;;
    *)
      echo "✖ Cannot determine git root (got: '${GIT_ROOT:-empty}'). Commit blocked."
      exit 1
      ;;
  esac
fi
