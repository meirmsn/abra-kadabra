## Gate 11: convention

**Outcome:** pass

### Checks performed

1. **Shell script structure** (`kit/hooks/pre-push.sh`): shebang `#!/usr/bin/env bash`, `set -euo pipefail`, and header comments (`# What:` / `# Why:` / `# Does NOT:`) all present. Husky dash re-exec guard present (lines 13-15).

2. **Bats test conventions** (`kit/tests/util-pre-push.bats`): shebang `#!/usr/bin/env bats`, `setup()` with `load helpers/setup` and `setup_mock_bin`, naming consistent with existing `util-*.bats` pattern. All 31 tests pass.

3. **Guide docs linked in routing index** (`kit/docs/guide/README.md`): `hooks.md` already routed in the Ops + deploy group (line 95) and listed in the alphabetical file list (line 132). No new guide files added, so no routing-index update needed.

4. **Commit messages follow conventional-commit format**: all 6 feature-scoped commits use valid prefixes (`feat(hooks):`, `fix(hooks):`, `test(hooks):`, `docs(hooks):`, `chore(pr-hygiene-hash-cache):`), all under 72 characters, all describe observable changes.

## Dismissals

None
