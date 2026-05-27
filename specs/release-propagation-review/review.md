# Review — release-propagation-review

## Audit 1: manual (2026-05-27)

<!-- audited-at: 30ddc634668e5ca1d1e717c29510e9b6a050f6bd -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

### Tests findings

- [low] kit/tests/propagation-entry.bats (missing test) — no test verifies --finalize rollback behavior on partial failure (commit lands but tag/push fails). The --finalize block exits before the rollback trap is registered. Deferred — low severity, the main code path has rollback coverage.

### Bypass trailer audit

- (none)
