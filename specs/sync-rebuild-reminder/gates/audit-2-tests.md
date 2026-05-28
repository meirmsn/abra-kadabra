Tests look solid — no findings.

---

## Re-audit context (Audit 2)

Range audited: `0d78c67..f59d041` (worktree `/devshop/.worktrees/sync-rebuild-reminder`, branch `feat/sync-rebuild-reminder`). 11 files in range; source-bearing changes in `kit/scripts/sync/from-devshop.sh`, `kit/scripts/sync/lib/preview-confirm.sh`, two SKILL.md docs, `workflow.md`, and the two bats suites.

### Audit 1 MEDIUM — RESOLVED

The Audit 1 finding (rc-1 user-declined suppression path of `report_devcontainer_rebuild` untested) is now closed.

- **`kit/tests/sync-devcontainer-rebuild-reminder.bats:117-138`** adds the case `user-declined sync stays silent — no rebuild advisory on abort (rc 1)`.
- It drives the rc-1 decline path exactly as the finding's fix prescribed: drifted locked leaf (`set_dockerfile "FROM node:22" "FROM node:20"`), a synced README change so the preview is non-empty (reaches the confirm prompt → rc 1, not rc 2), and `setsid bash -c "... < /dev/null"` to detach the controlling terminal + supply empty stdin so the prompt's `read < /dev/tty` fails and the script aborts.
- Asserts suppression with both negatives — `refute_output --partial "Rebuild needed"` AND `refute_output --partial "No .devcontainer changes"` — plus `assert_output --partial "Aborted"`. The `"Aborted"` literal is confirmed present at `kit/scripts/sync/lib/preview-confirm.sh:148`.
- This guards the load-bearing rc 1 vs rc 2 distinction in `from-devshop.sh`: rc 2 fires the advisory then `exit 0`; the `elif [ "$pc_rc" -ne 0 ]` (rc 1) branch `exit 0`s with NO advisory. A regression that reorders `report_devcontainer_rebuild` ahead of the abort check, or collapses rc 1 into rc 2, would now fail this case instead of staying green.
- Verified green: case 6 passes under the vendored bats runner (full file 6/6 of the rebuild-reminder suite, 23/23 across both suites).

### Coverage summary (Section A) — no findings

- **`report_devcontainer_rebuild()`** (`from-devshop.sh`) — covered by `sync-devcontainer-rebuild-reminder.bats` (6 cases): drift-names-file, identical-no-note, project-missing-leaf-is-drift, non-locked-synced-change-does-not-trigger, locked-only-no-synced-change (rc-2 path), and the new rc-1 decline-stays-silent case. All assertions are content-specific (`--partial "Dockerfile"`, `--partial "Rebuild needed"`, paired `refute_output` on negatives) — not shape-only.
- **rc-2 return-code change** (`preview-confirm.sh:104`) — covered at two layers: unit (`sync-preview-confirm.bats` now asserts `assert_failure 2`, updated in this diff) and integration (rebuild-reminder rc-2 case asserts both `"No changes to apply"` and `"Rebuild needed"` fire together).
- **SKILL.md changes** (`sync-from-devshop` Phase 2c rebuild verdict; `check-docs-and-tests` inline-run fallback) and `workflow.md` row are documentation; no test pairing required.
- All 23 tests across both suites (`sync-devcontainer-rebuild-reminder.bats` + `sync-preview-confirm.bats`) pass under the vendored bats runner.

### Section C — bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in `0d78c67..f59d041`. Zero rows (expected — mechanic not yet active).
