# Review — existing-projects-commit-convention

## Audit 1: manual (2026-05-24)

<!-- audited-at: 56d1505ad61a687cfa4f82e41ca575613d52fe0a -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

### Tests findings

- [low] `kit/tests/structural-invariants.bats:844` — trigger-table grep searches entire `conventions.md` instead of scoping to the `## Existing-Project Migration Block` section; would pass even if the trigger table were removed as long as `[locked]`/`[scaffold-once]`/`[sync]` strings exist elsewhere in the file.

### Bypass trailer audit

- (none)
