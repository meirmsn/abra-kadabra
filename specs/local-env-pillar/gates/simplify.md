## Gate 4: /simplify

- Result: findings (2) fixed

1. `local-env-health.sh`: removed unused `PROJECT_ROOT` variable (declared, ran `git rev-parse`, never referenced) and redundant `any_failed` tracking variable (replaced with direct `${#failures[@]}` array-length check).
2. `roster-check.sh`: simplified PNG existence check from 3-process pipeline (`ls | head -1 | grep -q .`) to single `ls ... >/dev/null 2>&1`.

All 33 bats tests pass after changes.

## Dismissals

None
