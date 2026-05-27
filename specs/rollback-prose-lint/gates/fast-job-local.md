## Gate 2d: fast-job-local

**Outcome**: pass

**Suite**: bats (devshop-self mode)
**Command**: `kit/tests/lib/bats-core/bin/bats kit/tests/`
**Result**: 1397/1397 tests passed

Two pre-existing test gaps were found and fixed during this run:
1. `pre-commit-router.bats` test 410 — mock list missing `check-rollback-prose.sh` stub, causing `bash: ...check-rollback-prose.sh: No such file or directory` (exit 127). Fixed by adding the stub to the setup mock list and adding positive/negative routing assertions.
2. `structural-invariants.bats` test 683 — `check-rollback-prose.sh` tracked as 100755 instead of the required 100644. Fixed via `git update-index --chmod=-x`.

After fixes, full suite passes clean.

## Dismissals

None
