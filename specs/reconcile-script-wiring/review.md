# Review — reconcile-script-wiring

## Audit 1: manual (2026-05-29)

<!-- audited-at: 0cda20cc2cf5e20f44f192d3065c3dea98438e1d -->
<!-- range: 48eed4abce1e38952ba278e8a4cbcb45fc5339fd..0cda20cc2cf5e20f44f192d3065c3dea98438e1d -->

findings: high=0 medium=0 low=1

### Docs findings

- (none)

### Tests findings

- [low] kit/tests/structural-invariants.bats:234 — Widening the `infra_scripts` allow-list in the wiring meta-test trades a false positive for a permanent small coverage loss: no mechanism asserts listed exemptions still exist / stay unwired, so a future re-wire or deletion of `reconcile-task-commits.sh` would go unflagged. Inherent to all 30+ siblings; correct trade here. Optional hardening (devshop backlog): assert each exemption names an existing `kit/scripts/` file with no `kit/hooks/`/`.husky/` match. Recording as low; the fix is correct.

### Bypass trailer audit

- (none)
