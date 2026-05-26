# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (1 commit: `19c4cc4`)
**Date**: 2026-05-26

## Section A — Coverage of new behavior

The diff modifies 11 files: 3 Dockerfiles (devshop + template workspace + template supabase-runner), 2 `checksums.sha256`, 1 `devcontainer.json`, 1 `compose.yml`, 2 `README.md`, 2 guide docs (`ops.md`, `security.md`).

No `kit/scripts/*.sh` files were added or modified. No `kit/hooks/**` files were added or modified. No new skills were added. The devshop-side rubric (new script -> matching `.bats` spec) does not apply.

The changes are Dockerfile build-step logic (swapping hardcoded checksum lookup for self-verifying fetch from GitHub release), Docker Compose version bumps, and documentation updates. These are infra/config changes with no bats-testable script surface.

Existing structural test suites (`template-compose-isolation.bats`, `structural-invariants.bats`) cover the compose file shape and Dockerfile structural properties but do not assert on the checksum-verification pattern or version-sync between the three Dockerfile sites.

### [domain: tests] [section: A] [severity: low]

**File**: `template/.devcontainer/compose.yml` + `template/.devcontainer/Dockerfile` + `template/.devcontainer/supabase-runner/Dockerfile`
**What**: No structural test asserts that the `SUPABASE_CLI_VERSION` default value stays in sync across the three sites (compose.yml workspace arg, compose.yml runner arg, supabase-runner/Dockerfile ARG default). A drift between these would cause workspace and runner to run different Supabase CLI versions silently.
**Why**: Version drift between workspace and runner is explicitly called out in the `supabase-runner/Dockerfile` comment ("workspace + runner stay in lockstep"). Without a test, a future bump that touches only one of the three sites would silently break the invariant.
**Fix**: Add a bats test to `template-compose-isolation.bats` that extracts the `SUPABASE_CLI_VERSION` default from all three sites and asserts equality. Example:
```bash
@test "compose-isolation: SUPABASE_CLI_VERSION default is consistent across compose.yml + runner Dockerfile" {
  local compose_ws compose_runner runner_df
  compose_ws=$(grep -oP 'SUPABASE_CLI_VERSION:-\K[0-9.]+' "$DC/compose.yml" | head -1)
  compose_runner=$(grep -oP 'SUPABASE_CLI_VERSION:-\K[0-9.]+' "$DC/compose.yml" | tail -1)
  runner_df=$(grep -oP 'SUPABASE_CLI_VERSION=\K[0-9.]+' "$DC/supabase-runner/Dockerfile")
  [ "$compose_ws" = "$compose_runner" ]
  [ "$compose_ws" = "$runner_df" ]
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `.devcontainer/Dockerfile:71-78` + `template/.devcontainer/Dockerfile:115-122` + `template/.devcontainer/supabase-runner/Dockerfile:47-54`
**What**: No structural test asserts that all three Dockerfiles use the self-verifying checksum pattern (fetch `supabase_${VERSION}_checksums.txt` from GitHub release, then `sha256sum -c`). A future edit could accidentally revert one site to the old hardcoded-checksum pattern or remove verification entirely.
**Why**: The self-verifying pattern is the core security mechanism of this change — it's what makes arbitrary version pinning safe. If one site loses it, that site installs unverified binaries.
**Fix**: Add a bats test that greps each Dockerfile for the `supabase_checksums.txt` fetch + `sha256sum -c` pipeline. Example:
```bash
@test "compose-isolation: all Supabase CLI install blocks use self-verifying checksums" {
  for f in "$DC/Dockerfile" "$DC/supabase-runner/Dockerfile"; do
    run grep -q 'supabase_checksums.txt' "$f"
    assert_success
    run grep -q 'sha256sum -c' "$f"
    assert_success
  done
}
```

## Section B — Test quality

No test files were added or modified in this range. Section B checks (weak assertions, missing error tests, etc.) do not apply.

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers found in the commit range. Section C has zero rows.

## Summary

| Severity | Count |
|----------|-------|
| high     | 0     |
| medium   | 0     |
| low      | 2     |

Tests look solid for the scope of this change. The two low-severity findings are forward-looking structural guards that would prevent future drift — not gaps in the current commit's correctness. No halting findings.
