## Gate 2d: fast-job-local

- Result: pass

Devshop-self-mode: the bats suite is the deterministic test gate (replaces
`pnpm turbo run lint typecheck test:unit build`). Full suite ran in-worktree at
HEAD with husky hooks armed:

```
kit/tests/lib/bats-core/bin/bats kit/tests/
→ 0 failures
```

Includes the new 18-case `util-virtiofs-rebase.bats` and the
`structural-invariants.bats` wiring registration for `virtiofs-rebase.sh`.

## Dismissals

None
