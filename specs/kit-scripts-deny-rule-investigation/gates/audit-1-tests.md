# Tests Review — Audit 1

**Range**: `origin/main..HEAD` (1 commit: `a917e9d`)
**Feature**: `kit-scripts-deny-rule-investigation`
**Date**: 2026-05-23

## Section A — Coverage of new behavior

### Deleted scripts + matching deleted tests

- `kit/scripts/apply-port-offset.sh` (deleted) — `kit/tests/ak-new-project-port-registry.bats` (deleted). Clean.
- `kit/scripts/next-port-offset.sh` (deleted) — `kit/tests/ak-new-project-port-registry.bats` (deleted). Clean.
- `kit/scripts/commit-hooks/check-port-offset-unique.sh` (deleted) — `kit/tests/ak-new-project-port-registry.bats` (deleted). Clean.
- `template/.devcontainer/derive-ports-from-config.sh` (deleted) — `kit/tests/derive-ports-from-config.bats` (deleted). Clean.

### Modified scripts + test updates

- `kit/scripts/preship/supabase-bootstrap.sh` — removed `_read_port` helper and hardcoded ports to 54321/54322. Existing tests in `preship-supabase-bootstrap.bats` and `preship-supabase-bootstrap-classifier.bats` already use hardcoded 54321/54322 values. No gap.
- `kit/scripts/preship/advisor-clean.sh` — removed `.env` port lookup, hardcoded 54322. Existing `preship-advisor-clean.bats` does not test port resolution directly (tests probe postgres reachability at a higher level). No gap.
- `kit/scripts/preship/migration-rollback-roundtrip.sh` — removed port lookup, hardcoded 54322. Existing test assertions at `preship-migration-rollback-roundtrip.bats:172-173` already assert hardcoded `host.docker.internal:54322` / `localhost:54322`. Clean.
- `kit/scripts/sync/lib/parse-manifest.sh` — removed `manifest_scaffold_once_under` function. Corresponding test deleted from `manifest-lifecycle.bats`. Clean.
- `kit/scripts/sync/from-devshop.sh` — removed all rsync exclusion logic (MANIFEST_EXCLUDES, manifest_locked_under, manifest_scaffold_once_under). Old structural test asserting these was deleted. Remaining test at `manifest-lifecycle.bats:373` verifies parse-manifest.sh sourcing + `manifest_paths_by sync` usage. Consistent.
- `kit/scripts/sync/to-devshop.sh` — removed `manifest_scaffold_once_under` usage. Test at `manifest-lifecycle.bats:384` updated to remove that assertion; still asserts `manifest_locked_under`. Clean.
- `kit/hooks/pre-commit.sh` — removed `check-port-offset-unique.sh` calls (2 sites). Tests in `pre-commit-router.bats` updated to remove corresponding mock + assertion. Clean.
- `kit/scripts/init-devshop.sh` — removed CI=true from pnpm install and derive-ports backstop. No existing test covers CI=true specifically. Removing a workaround; no gap.
- `template/.devcontainer/init-firewall.sh` — reduced from 5 env-driven ports to 2 (API + DB) with `:-default` fallbacks. Tests in `init-firewall-port-allowance.bats` updated to match: structure tests check 2 ports + `:-54321`/`:-54322` defaults; behavior tests assert default fallback instead of hard failure when .env missing. Clean.
- `template/.devcontainer/compose.yml` — hardcoded SUPABASE_URL + socat ports. Test at `template-compose-isolation.bats:44` updated to match literal `54321`. Clean.
- `template/.devcontainer/devcontainer.json` — removed derive-ports-from-config.sh from initializeCommand. Test at `template-compose-isolation.bats:143` updated. Clean.
- `template/apps/web/e2e/helpers/inbucket.ts` — hardcoded mailpit port 54324 instead of reading SUPABASE_MAILPIT_PORT env var. No devshop-side bats test for this template helper (project-side E2E tests cover it). Acceptable — template helpers are tested at the project layer.
- `template/scripts/advisor-probe.mjs` — hardcoded DB port 54322 instead of reading SUPABASE_DB_PORT. Existing `template-advisor-probe.bats` does not assert port resolution (tests structural invariants). Acceptable.
- `template/scripts/ci-rollback-explain.sh` — hardcoded fallback DB URL. No dedicated bats test for this CI helper. Acceptable — CI workflow exercises it.
- `kit/tests/structural-invariants.bats` — removed deleted scripts from infra_scripts exemption list; removed `.gitignore` screenshot routing test (feature removed). Consistent with source deletions.

### [domain: tests] [section: A] [severity: low]

**File**: `kit/scripts/sync/from-devshop.sh:14`
**What**: `PROJECT_ROOT` resolution changed from `$SCRIPT_DIR/../../..` (3 levels up) to `$SCRIPT_DIR/../..` (2 levels up). No functional test covers this path resolution — existing `manifest-lifecycle.bats:373` only does structural grep checks, not a functional invocation that would catch a wrong PROJECT_ROOT.
**Why**: If the path depth is wrong, `from-devshop.sh` reads the manifest from the wrong directory and all synced files land in the wrong place. The same change applies to `to-devshop.sh:16`. Both scripts were previously patched FROM `../..` TO `../../..` (with a detailed comment explaining the symlink resolution), and this PR reverts that patch.
**Fix**: Add a functional test in `manifest-lifecycle.bats` that creates a synthetic project tree with a `.devshopkit` symlink, invokes `from-devshop.sh` through the symlink, and asserts files land at the correct project-root-relative path. This is a pre-existing gap, not newly introduced by this PR, so severity is low.

## Section B — Test quality

No findings. Modified tests use appropriate assertion patterns (structural greps with `assert_success`/`assert_failure`, behavior tests with `assert_output --partial`). No weak assertions, no skip/only patterns, no implementation-detail coupling.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in the range. Nothing to audit.

## Summary

Tests look solid — 0 high, 0 medium, 1 low.

The single low finding is a pre-existing functional-coverage gap for `from-devshop.sh`'s `PROJECT_ROOT` symlink resolution, not newly introduced by this PR. All deleted scripts have matching deleted tests. All modified scripts have consistently updated tests. No skip/only patterns, no weak assertions.
