## Gate 11: convention

- Result: pass

### Checks performed

1. **Shell script structure** -- All 3 new scripts (`local-env-health.sh`, `roster-check.sh`, `check-llm-mediated-na.sh`) have `#!/usr/bin/env bash` shebang, `set -euo pipefail`, 3-line header (`# What:` / `# Why:` / `# Does NOT:`), and spec reference comment.

2. **Bats test files exist** -- Corresponding test files present for all 3 scripts: `preship-local-env-health.bats`, `preship-roster-check.bats`, `util-check-llm-mediated-na.bats`.

3. **Guide docs routing index** -- No new guide docs added; `kit/docs/guide/README.md` alphabetical file list matches the 19 guide files on disk. No update needed.

4. **POSIX compatibility** -- New scripts are bash-only (`#!/usr/bin/env bash`), invoked via `bash "$SCRIPT"`, and not referenced from `.husky/` hooks (which run under `sh`/dash). No dash-incompatible patterns in POSIX-required paths.

5. **Conventional commits** -- All 11 commits follow `type(scope): description` format with valid types (`feat`, `fix`, `docs`, `chore`), under 72 chars, describing observable changes.

## Dismissals

None
