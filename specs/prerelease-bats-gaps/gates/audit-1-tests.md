### Tests findings

- [low] kit/tests/structural-invariants.bats:618 — current-repo fallback to `$DEVSHOP` makes the test vacuously pass when bats runs from a project repo (`git -C /workspace ls-files 'kit/scripts/**/*.sh'` returns empty because `.devshopkit` is a gitignored symlink). The inline comment names this as intentional ("gracefully no-ops"), so it's not a bug — but the per-repo behavior split means operators reading green CI from a project repo should not infer anything about devshop kit/scripts mode bits. No fix required for this PR; consider documenting the asymmetry in `kit/docs/guide/conventions.md § Test wiring invariants` so the next reader doesn't repeat the analysis.

Tally: high=0 medium=0 low=1
