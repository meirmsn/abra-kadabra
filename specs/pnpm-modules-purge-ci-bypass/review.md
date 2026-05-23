# Review — pnpm-modules-purge-ci-bypass

## Audit 1: manual (2026-05-23)

<!-- audited-at: 6c80d31a9f58dd43032e7863faf667f134caa59b -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=3

### Docs findings

- [low] `kit/docs/guide/ops.md:414` — Line-number citations for `su node -c` invocations in `init-devshop.sh` are stale (claims line 61/127; actual 67/136). Inherently fragile citation.

### Tests findings

- [medium] `kit/scripts/sync/from-devshop.sh:14` / `kit/scripts/sync/to-devshop.sh:16` — PROJECT_ROOT path fix (3→2 levels) has only structural grep tests, no behavioral test that runs the script through the `.devshopkit` symlink and verifies files land in the correct directory.
- [low] `kit/scripts/apply-port-offset.sh:60-66` — apply-offset chains into derive-ports but no assertion verifies `.env` was updated with rebound ports after completion.
- [low] `kit/tests/preship-migration-rollback-roundtrip.bats:172-173` — Hardcoded `:54322` assertion tests the fallback path, not the intended env-driven path.

### Bypass trailer audit

- `172aa2b` Docs-Coverage-Bypass: "init-devshop.sh quoting fix is cosmetic" — VERIFIED
