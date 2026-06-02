#!/bin/bash
# What: Pre-commit guard (real repos only) — blocks commits stamped with the
#       test-fixture identity (Test <test@test.com>) in /devshop or /workspace.
# Why: ~/.gitconfig is NOT volume-backed (only /home/node/.claude survives a
#      rebuild), so global git identity resets to empty on every container
#      rebuild and the Dockerfile never bakes user.name/user.email. If a stale
#      LOCAL override sits in the bind-mounted .git/config, it silently wins
#      (local > global) and outlives every global "fix" — so commits ship as
#      "Test <test@test.com>" with no error. This makes that footgun LOUD.
# Does NOT: Fire in ephemeral bats fixture repos — test@test.com IS the canonical
#      fixture identity (helpers/setup.bash, guard-commit.bats, goal1/goal2),
#      so the guard self-gates on the real bind-mount toplevel and skips /tmp.

set -euo pipefail

# Real bind-mounted repos where the fixture identity is never legitimate.
# Space-separated; overridable so the bats test can point it at its temp repo.
REAL_ROOTS="${IDENTITY_GUARD_REAL_ROOTS:-/devshop /workspace}"

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

_is_real=0
for r in $REAL_ROOTS; do
  [ "$GIT_ROOT" = "$r" ] && _is_real=1 && break
done
[ "$_is_real" = "1" ] || exit 0

# The identity git will actually stamp on the commit (honors local > global
# precedence and GIT_AUTHOR_* env overrides). Empty if no identity is set at
# all — then we stay silent and let git's own "please tell me who you are"
# error fire.
AUTHOR_EMAIL=$(git var GIT_AUTHOR_IDENT 2>/dev/null | sed -E 's/.*<([^>]*)>.*/\1/' || echo "")

if [ "$AUTHOR_EMAIL" = "test@test.com" ]; then
  cat >&2 <<'HOOK_EOF'
BLOCKED: commit identity is the test fixture (Test <test@test.com>).

Your real git identity is being shadowed by a placeholder. The usual cause:
a stale LOCAL override in .git/config wins over (and outlives) your global
identity, because ~/.gitconfig resets on every container rebuild while the
bind-mounted .git/config does not.

Fix — set a durable identity in the bind-mounted local config:

  git config --local --remove-section user 2>/dev/null || true
  git config --local user.name  "<your name>"
  git config --local user.email "<your email>"

Then re-commit. (Local config persists across rebuilds and is never
committed, so it is the right home for your identity here.)
HOOK_EOF
  exit 1
fi

exit 0
