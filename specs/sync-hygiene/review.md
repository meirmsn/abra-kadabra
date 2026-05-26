# Review — sync-hygiene

## Audit 1: manual (2026-05-26)

<!-- audited-at: 9f8217e2dc9e8c7c5a035d10f934397982cb5ad1 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=3 low=2

### Docs findings

- [medium] kit/docs/guide/architecture.md:181 — `from-devshop.sh` docs say plain `cp` for all `[sync]` files; now factually incorrect for `package.json` which does a jq merge preserving identity fields
- [medium] kit/docs/guide/ops.md:71 — slow-job "battle-earned fixes" list missing the two new fixes (dynamic API port from config.toml + ./apps/web directory-based filter)
- [low] kit/docs/guide/conventions.md:159 — stale `pnpm --filter apps/web` form; template now uses `./apps/web` consistently

### Tests findings

- [medium] kit/tests/sync-package-json-merge.bats — header claims jq-fallback test exists but no test exercises the `! command -v jq` branch in `merge_package_json()`
- [low] kit/tests/template-ci-yml-shape.bats:405 — regression guard regex `[^/]` doesn't match EOL; mitigated by companion test at line 389

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-26)

<!-- audited-at: 77ca94d80ae8920ffcaa93643aad2d6a2096280f -->
<!-- range: 9f8217e2dc9e8c7c5a035d10f934397982cb5ad1..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none) — all 3 Audit 1 findings verified fixed

### Tests findings

- (none) — Audit 1 medium (jq-fallback test) verified fixed; low (regex gap) mitigated by companion test

### Bypass trailer audit

- (none)
