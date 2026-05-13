#!/usr/bin/env bash
# What: Single source of truth for devshop-self vs project-mode detection.
# Why:  Multiple scripts (commit-guard, pre-commit/pre-push routers, every
#       commit-hook check, init-devshop, adversarial-review, create-devshop-
#       symlinks) need the same signal: "is the workspace the devshop repo
#       itself, or a project consuming devshop?" The signal is filesystem-
#       based — kit/ is a real directory in the devshop repo but always a
#       symlink (.devshopkit) in projects. Inlining the check in 13 places
#       made it invisible to bats tests that sed-rewrite GIT_ROOT="/workspace"
#       — when those tests run from the devshop devcontainer, /workspace/kit
#       is a real dir (bind-mount of the devshop repo), so the inline check
#       routes around the project-mode branches the tests want to exercise.
#       Centralizing it here lets tests force a mode via DEVSHOP_FORCE_MODE.
# Does NOT: Set globals other than via return code. Use as predicate:
#       if is_devshop_self_mode "$GIT_ROOT"; then ...

# is_devshop_self_mode <root-path>
#
# Returns 0 (true) if <root-path> is the devshop repo itself (devshop-self
# mode), 1 (false) if it's a project consuming devshop, 2 if the env override
# is malformed.
#
# Detection:
#   DEVSHOP_FORCE_MODE=devshop-self  → returns 0 (test override)
#   DEVSHOP_FORCE_MODE=project       → returns 1 (test override)
#   DEVSHOP_FORCE_MODE=auto / unset  → filesystem check: kit/ is a real dir
#                                      (not a symlink) at <root-path>
#
# DEVSHOP_FORCE_MODE is intentionally test-only — production callers leave it
# unset and the filesystem check answers the question without ambiguity. Any
# value other than auto / devshop-self / project is rejected (return 2 with a
# stderr error) so a typo doesn't silently degrade to one mode.
is_devshop_self_mode() {
  local root="${1:-}"
  case "${DEVSHOP_FORCE_MODE:-auto}" in
    devshop-self) return 0 ;;
    project)      return 1 ;;
    auto)
      [ -n "$root" ] && [ -d "$root/kit" ] && [ ! -L "$root/kit" ]
      ;;
    *)
      echo "✖ DEVSHOP_FORCE_MODE='${DEVSHOP_FORCE_MODE}' invalid (expected: auto|devshop-self|project)" >&2
      return 2
      ;;
  esac
}
