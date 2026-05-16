# Review — worktree-support

## Audit 1: manual (2026-05-16)

<!-- audited-at: bf9fe690ffca4b0ec5b23843c33a8a7ba689fff3 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

Notes (not findings):

- Coverage (A): kit/scripts/session-start.sh surface satisfied by CLAUDE.md edit.
- Adequacy (B): all named claims in the new CLAUDE.md paragraph verify against the codebase (git-common-dir usage in session-start.sh:24, dual-check pattern in 6 commit-hooks, /ak-merge-devshop cwd refusal).
- Coherence (C): no renames/deletes; new paragraph is additive over OVERVIEW/architecture/workflow/hooks docs (no contradictions).
- Bypass audit (D): no Docs-Coverage-Bypass trailers in range.

### Tests findings

- [low] kit/scripts/session-start.sh — new IS_DEVSHOP detection block (lines 20-32) ships without bats coverage. Three behaviors warrant assertion: ROOT=/devshop, ROOT=/devshop/.worktrees/<topic>, ROOT=/workspace. Mitigated by manual smoke-test in this session + pre-existing zero-coverage convention for this script. Fix: add util-session-start.bats covering the three setups.

### Bypass trailer audit

- (none)
