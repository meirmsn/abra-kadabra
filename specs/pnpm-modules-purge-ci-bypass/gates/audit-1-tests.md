# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (15 commits)
**Branch**: `fix/pnpm-modules-purge-ci-bypass`
**Date**: 2026-05-23

## Section A — Coverage of new behavior

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/scripts/sync/from-devshop.sh:14` / `kit/scripts/sync/to-devshop.sh:16`
**What**: The `PROJECT_ROOT` path fix (3 levels up instead of 2) is a bug fix for a real sync failure ("surfaced today on a home-os sync attempt" per the commit comment), but the only test coverage is structural grep-based checks in `kit/tests/manifest-lifecycle.bats` (lines 391-415). No behavioral test runs `from-devshop.sh` or `to-devshop.sh` against a fixture tree with a `.devshopkit` symlink and verifies files sync to the correct destination.
**Why**: A regression to the path math would silently sync to the wrong directory (the devshop root instead of the project root), clobbering files. The structural grep tests (`assert_success` on `grep -q 'manifest_paths_by sync'`) cannot catch path-math regressions — they only verify the script mentions the right function names.
**Fix**: Add a behavioral bats test that creates a fixture project tree with a `.devshopkit -> <fake-devshop>/kit` symlink, invokes `from-devshop.sh` through the symlink path (as it runs in production), and asserts that synced files land in `$PROJECT/` not `$PROJECT/../`. Example:

```bash
@test "from-devshop: syncs files to correct project root via .devshopkit symlink" {
  # Create fixture tree: project/.devshopkit -> fake-devshop/kit
  mkdir -p "$FIXTURE/project/.devshopkit/scripts/sync"
  # ... run from-devshop.sh, assert files land in $FIXTURE/project/
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/scripts/apply-port-offset.sh:60-66`
**What**: `apply-port-offset.sh` chains into `derive-ports-from-config.sh` to propagate the offset to `.env`. The test in `ak-new-project-port-registry.bats` sets up the derive script in the fixture (line 25: `cp "$DERIVE_SCRIPT" ...`) and the derive script runs during the test, but no assertion verifies that `.env` was actually updated with the rebound ports after `apply-offset` completes.
**Why**: If the derive-script chain call silently fails (wrong path, permission error, script bug), `config.toml` would have the right ports but `.env` would still have stale values — the exact drift class this feature is designed to eliminate.
**Fix**: Add assertions after the `apply-offset: rewrites 5 port sections` test:

```bash
# Verify derive-ports chain propagated to .env
env_val() { grep -E "^${1}=" "$PROJECT/.devcontainer/.env" | tail -1 | cut -d= -f2-; }
[ "$(env_val SUPABASE_API_PORT)" = "54421" ]
[ "$(env_val SUPABASE_DB_PORT)" = "54422" ]
```

## Section B — Test quality

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/preship-migration-rollback-roundtrip.bats:172-173`
**What**: Test asserts hardcoded `:54322` in the blocked message (`assert_output --partial "host.docker.internal:54322"`). The script now resolves `SUPABASE_DB_PORT` from `.devcontainer/.env` with a fallback to `54322`. The test still passes because the fixture has no `.devcontainer/.env`, so the fallback fires — but the assertion is fragile: it tests the fallback path, not the intended env-driven path.
**Why**: If a future change removes the `54322` default (making `.devcontainer/.env` mandatory for preship scripts, as `init-firewall.sh` already does with `:?required`), this test would break for the wrong reason. The test doesn't exercise the primary code path (port read from `.devcontainer/.env`).
**Fix**: Add a companion test that creates `$TEST_REPO/.devcontainer/.env` with `SUPABASE_DB_PORT=54422` and asserts the blocked message contains `:54422` (the env-driven path). Keep the existing test as a "fallback to default" case but rename it to clarify intent.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the commit range. Zero rows harvested — nothing to judge.

## Summary

| Severity | Count |
| -------- | ----- |
| high     | 0     |
| medium   | 1     |
| low      | 2     |

No high-severity findings. The medium finding (sync path-fix without behavioral test) is the most material — it's a bug fix for a real production failure with only structural grep coverage. The two low findings are assertion-depth gaps that don't block ship.
