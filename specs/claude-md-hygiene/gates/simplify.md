## Gate 4: /simplify

- Result: findings (2) fixed

### Findings

1. **Test 7 name prefix mismatch** (`guard-claude-md-classification.bats`): Comment and test name used "PASS:" prefix but the test asserted failure (blocking behavior). Renamed to "BLOCK:" for consistency with tests 3, 5, and 6.

2. **Symlink check on wrong path** (`check-claude-md-classification.sh` line 59): Tested `[ ! -L "$GIT_ROOT/kit/scripts" ]` — `kit/scripts` is never a symlink anywhere. The canonical devshop-self detection pattern checks `[ ! -L "$GIT_ROOT/kit" ]` (the `kit/` directory itself is the symlink in project repos). Changed to match the canonical pattern used in `adversarial-review.sh` and other hooks. No behavioral change (the preceding `-d` check already ensured correctness).

## Dismissals

None
