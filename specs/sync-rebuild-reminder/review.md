# Review — sync-rebuild-reminder

## Audit 1: manual (2026-05-28)

<!-- audited-at: a966bbffcfb490d182e18b70a2c7afacf29cf93d -->
<!-- range: 0d78c67..a966bbf -->

findings: high=1 medium=2 low=0

### Docs findings

- [high] kit/docs/guide/workflow.md:487 — spec-promised (cited 3×) + commit-claimed sync-skill-map update never landed; the `/ak-sync-from-devshop` row omits the new Phase 2c devcontainer rebuild verdict. Devshop rubric also requires a guide-doc/CLAUDE.md edit when `kit/scripts/**` + SKILL.md are touched.
- [medium] (commit de03ac9 body) — propagation-relevant `kit/scripts/**` change ships without an `**Existing projects:**` block (resolved at squash: the composed squash body carries one).

### Tests findings

- [medium] kit/tests/sync-devcontainer-rebuild-reminder.bats — rc-1 (user-declined) suppression path untested; all 5 cases drive `--yes` (rc 0 / rc 2). A regression leaking the advisory on decline would pass green.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-28)

<!-- audited-at: f59d0419a267f0bd1b9bca78e9a5f482cc87eedd -->
<!-- range: 0d78c67..f59d041 -->

findings: high=0 medium=0 low=0

Re-audit after fixes (f59d041). Both Audit 1 findings resolved: workflow.md
sync-skill-map row now documents the Phase 2c rebuild verdict (high); the
de03ac9 Existing-projects gap is resolved-at-squash (the composed squash body
carries the block); the rc-1 decline-path suppression test was added (tests
medium). Bats 23/23 green.

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
