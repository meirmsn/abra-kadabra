### [domain: tests] [section: B] [severity: medium]

**File**: `kit/tests/sync-devcontainer-rebuild-reminder.bats` (no test) / branch covered at `kit/scripts/sync/from-devshop.sh:175-179`
**What**: The rc-1 (user-aborted) branch — the one path where the rebuild advisory must *stay silent* — has no test asserting suppression. The diff added a three-way dispatch on `preview_confirm_show_and_ask`'s return: rc 2 fires `report_devcontainer_rebuild` then `exit 0`; `elif [ "$pc_rc" -ne 0 ]` (rc 1, decline) `exit 0` with NO advisory. All five new cases drive `--yes`, so they only exercise rc 0 (apply → trailing advisory) and rc 2 (no-synced-change → advisory). The existing abort test (`sync-preview-confirm.bats:207` "dry-run does not modify working tree before confirmation") asserts `"Aborted"` and that the tree is untouched, but never asserts `refute_output --partial "Rebuild needed"` / `refute_output --partial "No .devcontainer changes"`.
**Why**: The rc 1 vs rc 2 distinction is the load-bearing reason this feature changed `preview-confirm.sh`'s return code at all (per its own commit message and the inline comment at `from-devshop.sh:166-172`). A regression that drops the `elif`, reorders `report_devcontainer_rebuild` ahead of the abort check, or collapses rc 1 back into rc 2 would leak the advisory after a user declines the sync — and the whole suite would stay green. The "stay quiet on decline" behavior is currently unprotected.
**Fix**: Add one case to `sync-devcontainer-rebuild-reminder.bats` that drives the interactive decline path with drifted locked leaves and asserts the advisory is suppressed. Reuse the `setsid bash -c ... < /dev/null` decline harness already proven at `sync-preview-confirm.bats:218`:

```bash
@test "user-declined sync stays silent — no rebuild advisory on abort" {
  set_dockerfile "FROM node:22" "FROM node:20"   # locked leaf drifted
  # Force a synced-file change so the preview prompts (rc 1 path, not rc 2).
  echo "template readme (new)"  > "$FIXTURE_TEMPLATE/.devcontainer/README.md"
  echo "project readme (stale)" > "$FIXTURE_PROJECT/.devcontainer/README.md"
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run setsid bash "$FIXTURE_FROM" < /dev/null
  assert_success
  assert_output --partial "Aborted"
  refute_output --partial "Rebuild needed"
  refute_output --partial "No .devcontainer changes"
}
```

---

## Coverage summary (no findings)

- **`report_devcontainer_rebuild()`** (`from-devshop.sh:108-141`) — covered by `sync-devcontainer-rebuild-reminder.bats` (5 cases): drift-names-file, identical-no-note, project-missing-leaf-is-drift, non-locked-synced-change-does-not-trigger, and locked-only-no-synced-change (the rc-2 path). Section A satisfied. All four behavior modes named in the task brief are exercised, and assertions are content-specific (`--partial "Dockerfile"`, `--partial "Rebuild needed"`, paired with `refute_output` on the negative cases) — not shape-only.
- **rc-2 return-code change** (`preview-confirm.sh:104`) — covered at two layers: unit (`sync-preview-confirm.bats:150` `assert_failure 2`, updated in this diff) and integration (rebuild-reminder case 5 asserts both `"No changes to apply"` and `"Rebuild needed"` fire together). The rc 1 vs rc 2 distinction itself is the subject of the medium finding above.
- All 22 tests (5 new + 17 in the updated preview-confirm suite) pass under the vendored bats runner.

## Section C — bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in `0d78c67..a966bbf`. Zero rows (expected — mechanic not yet active).
