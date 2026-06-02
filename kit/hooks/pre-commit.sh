#!/bin/bash
# What: Pre-commit guards for devshop hygiene — unified script for both repos
# Why: Single source of truth, symlinked into .hooks/pre-commit by create-devshop-symlinks.sh
# Does NOT: Run code quality tools (lint, typecheck, gitleaks) — those live in .husky/pre-commit

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
SCRIPTS_DIR="$DEVSHOP/kit/scripts"

# Source via $DEVSHOP (not $SCRIPTS_DIR) so test wrappers that sed-rewrite
# SCRIPTS_DIR to point at a mock-bin (pre-commit-router.bats) don't break
# the lib resolution — the lib lives under the real /devshop tree even when
# the rest of the script is calling mocked commit-hooks.
# shellcheck source=/devshop/kit/scripts/sync/lib/detect-mode.sh
source "$DEVSHOP/kit/scripts/sync/lib/detect-mode.sh"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

# Devshop-self mode (workspace IS the devshop repo) → same checks as a /devshop
# session. Tests can force this branch via DEVSHOP_FORCE_MODE=devshop-self.
if is_devshop_self_mode "$GIT_ROOT"; then
  # Devshop-self mode: same checks as devshop repo
  bash "$SCRIPTS_DIR/commit-hooks/check-not-test-identity.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-manifest.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-port-offset-unique.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-tests-coverage-devshop.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-docs-coverage-devshop.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-claude-md-classification.sh"
  bash "$SCRIPTS_DIR/commit-hooks/check-bats-devshop.sh"
  bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
else
  case "$GIT_ROOT" in
    /workspace)
      # Project repo: full guard suite. check-exempt-additions runs BEFORE
      # check-tests-coverage-project / check-docs-coverage-project so that bad
      # exempt entries surface first (the operator knows to fix the exempt
      # entry, not chase the gate it would have silenced).
      bash "$SCRIPTS_DIR/commit-hooks/check-not-test-identity.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-security-files-freshness.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-exempt-additions.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-tests-coverage-project.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-docs-coverage-project.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-claude-md-classification.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-rollback-prose.sh"
      bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
      # Soft nudge — never blocks. Runs after commit-guard so the nudge is
      # the last thing the operator sees before the commit succeeds.
      bash "$SCRIPTS_DIR/commit-hooks/check-template-propagation.sh"
      ;;
    /devshop)
      # Devshop repo: clean tree + manifest sync + port-offset uniqueness + Layer 1 docs/tests coverage + bats + commit guards
      bash "$SCRIPTS_DIR/commit-hooks/check-not-test-identity.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-clean-tree.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-manifest.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-port-offset-unique.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-tests-coverage-devshop.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-docs-coverage-devshop.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-claude-md-classification.sh"
      bash "$SCRIPTS_DIR/commit-hooks/check-bats-devshop.sh"
      bash "$SCRIPTS_DIR/commit-hooks/commit-guard.sh"
      ;;
    *)
      echo "✖ Cannot determine git root (got: '${GIT_ROOT:-empty}'). Commit blocked."
      exit 1
      ;;
  esac
fi
