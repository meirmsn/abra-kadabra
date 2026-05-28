# Review — merge-devshop-shell-robustness

## Audit 1: manual (2026-05-28)

<!-- audited-at: 2f7f0376bde56068e80350b310c9f9fb4503f871 -->
<!-- range: 3a3489967f2144dd41327e32ec6b14a062dbd290..2f7f0376bde56068e80350b310c9f9fb4503f871 -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] CLAUDE.md:67 — Worktree-merge summary still says "squashes via `git -C "$WORKTREE_PATH"`"; the detailed skill map (workflow.md) was updated to the `GIT_CMD` array form, but this one-liner wasn't. Not stale (the array expands to exactly `git -C "$WORKTREE_PATH"`, so the description is still accurate in effect), just less precise than its sibling doc. Optional: align the phrasing to "routes git via the `GIT_CMD` array" or leave as-is since the effect description is correct.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
