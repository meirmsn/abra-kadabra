# Tests Review — Audit 1

<!-- audited-at: c81407a -->

**Range**: `origin/main..HEAD` (1 commit)
**Branch**: `chore/conventions-md-lift-vs-cross-ref`
**Date**: 2026-05-23

## Section A — Coverage of new behavior

This branch is primarily a docs/conventions housekeeping change: lifting operational copy from `conventions.md` into the skills that consume it, updating cross-references, and reverting the Supabase port-offset registry feature (deleting scripts, tests, template files, and docs that were introduced on the parent branch `fix/pnpm-modules-purge-ci-bypass`).

**Deleted scripts + their tests (correct pairing):**

| Deleted script | Deleted test | Pairing |
| --- | --- | --- |
| `kit/scripts/apply-port-offset.sh` | `kit/tests/ak-new-project-port-registry.bats` | PASS |
| `kit/scripts/next-port-offset.sh` | `kit/tests/ak-new-project-port-registry.bats` | PASS |
| `kit/scripts/commit-hooks/check-port-offset-unique.sh` | `kit/tests/ak-new-project-port-registry.bats` | PASS |
| `template/.devcontainer/derive-ports-from-config.sh` | `kit/tests/derive-ports-from-config.bats` | PASS |

**Modified scripts — existing test coverage verified:**

| Modified script | Existing test file | Tests updated? | Coverage gap? |
| --- | --- | --- | --- |
| `kit/hooks/pre-commit.sh` | `kit/tests/pre-commit-router.bats` | Yes — removed `check-port-offset-unique.sh` references | No |
| `kit/scripts/preship/advisor-clean.sh` | `kit/tests/preship-advisor-clean.bats` | No — tests don't reference port env vars | No |
| `kit/scripts/preship/migration-rollback-roundtrip.sh` | `kit/tests/preship-migration-rollback-roundtrip.bats` | No — tests don't reference port env vars | No |
| `kit/scripts/preship/supabase-bootstrap.sh` | `kit/tests/preship-supabase-bootstrap.bats` | No — tests don't reference port env vars | No |
| `kit/scripts/sync/from-devshop.sh` | `kit/tests/manifest-lifecycle.bats` | Yes — removed `from-devshop.sh excludes` test | See finding below |
| `kit/scripts/sync/to-devshop.sh` | `kit/tests/manifest-lifecycle.bats` | Yes — removed `manifest_scaffold_once_under` assertion | No |
| `kit/scripts/sync/lib/parse-manifest.sh` | `kit/tests/manifest-lifecycle.bats` | Yes — removed `manifest_scaffold_once_under` test | No |
| `template/.devcontainer/init-firewall.sh` | `kit/tests/init-firewall-port-allowance.bats` | Yes — reduced from 5-port to 2-port with defaults | No |
| `template/.devcontainer/compose.yml` | `kit/tests/template-compose-isolation.bats` | Yes — reverted to literal 54321 | No |
| `template/.devcontainer/devcontainer.json` | `kit/tests/template-compose-isolation.bats` | Yes — removed derive-ports assertion | No |
| `template/apps/web/e2e/helpers/inbucket.ts` | (no dedicated test) | N/A | No — template helper, not devshop script |
| `template/scripts/advisor-probe.mjs` | `kit/tests/template-advisor-probe.bats` (exists, not modified) | N/A — tests don't reference port env vars | No |
| `template/scripts/ci-rollback-explain.sh` | (no dedicated test) | N/A | No — template script with :-default fallback |
| `kit/scripts/init-devshop.sh` | (no unit test) | N/A | No — infrastructure script, hard to unit test |

**Modified tests — all updated consistently with script changes.**

**Coverage findings**: 0.

---

## Section B — Test quality

### Deleted test audit

Two test files deleted entirely (`ak-new-project-port-registry.bats` — 227 lines, `derive-ports-from-config.bats` — 319 lines). Both tested scripts that are also deleted in this branch. Deletion is correct — orphan tests for deleted scripts would fail and provide no value.

### Modified test quality

The 5 modified bats files (`init-firewall-port-allowance.bats`, `manifest-lifecycle.bats`, `pre-commit-router.bats`, `structural-invariants.bats`, `template-compose-isolation.bats`) were reviewed for assertion quality:

- **No weak assertions introduced** — all modified tests use `assert_success`, `assert_failure`, `assert_output --partial`, `assert_line`, `refute_output` with specific expected values.
- **No `.skip` / `.only` patterns** in any modified test file.
- **No shape-only assertions** without corresponding behavioral verification.

### Removed structural-invariants test

The `wiring: template .gitignore matches Screenshot Routing convention` test was removed from `structural-invariants.bats`. This test asserted that `template/.gitignore` contains both `specs/*/screenshots/` and `specs/*/qa-walk/`. The branch also removes `specs/*/screenshots/` from `template/.gitignore`. The test removal is consistent with the gitignore change — `specs/*/qa-walk/` is still present in the gitignore but is no longer asserted by a structural test.

### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/structural-invariants.bats` (removed test at former line 391)
**What**: The structural invariant test `wiring: template .gitignore matches Screenshot Routing convention` was deleted, removing the assertion that `specs/*/qa-walk/` is present in `template/.gitignore`. While `specs/*/screenshots/` was intentionally removed from `.gitignore`, the `qa-walk` pattern is still present and still serves its purpose (Gate 9 per-verb artifacts). Removing the structural test means a future template edit could silently drop the `qa-walk` exclusion with no test catching it.
**Why**: Without a structural test, a future refactor of `template/.gitignore` could accidentally remove `specs/*/qa-walk/` — causing Gate 9 artifacts to be tracked by git in every project, polluting diffs and repo size.
**Fix**: Keep a narrowed version of the test that asserts only `specs/*/qa-walk/` is present:
```bash
@test "wiring: template .gitignore excludes specs/*/qa-walk/" {
  local gitignore="$DEVSHOP/template/.gitignore"
  [ -f "$gitignore" ] || skip "template .gitignore not found"
  grep -qF 'specs/*/qa-walk/' "$gitignore"
}
```

---

## Section C — Bypass trailer audit

```bash
git log --format='%H%n%B%n---' origin/main..HEAD | \
  awk '/^Tests-Coverage-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}'
```

**Trailers found**: 0.

No `Tests-Coverage-Bypass:` trailers in the range.

---

## Summary

| Section               | Findings       | High  | Medium | Low   |
| --------------------- | -------------- | ----- | ------ | ----- |
| A — Coverage          | 0              | 0     | 0      | 0     |
| B — Test quality      | 1              | 0     | 1      | 0     |
| C — Bypass trailers   | 0              | 0     | 0      | 0     |
| **Total**             | **1**          | **0** | **1**  | **0** |

One medium finding: structural invariant test for `specs/*/qa-walk/` gitignore pattern was dropped along with the `specs/*/screenshots/` assertion, leaving the remaining qa-walk exclusion unguarded against future template refactors.
