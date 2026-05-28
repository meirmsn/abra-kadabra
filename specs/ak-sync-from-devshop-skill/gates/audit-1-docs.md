### [domain: docs] [section: C] [severity: medium]

**File**: CLAUDE.md:32
**What**: `CLAUDE.md § Session Start` still describes the post-sync flow as the raw script printing a `PROPAGATION.md` pointer ("After syncing, `from-devshop.sh` prints a pointer to `kit/docs/PROPAGATION.md`... No manual reads needed"), but this commit re-routes both session-start drift lines to `/ak-sync-from-devshop`, which now wraps the script and handles the propagation read internally.
**Why**: Cross-doc coherence — a reference doc NOT touched by this commit now under-describes the operator path the commit just changed. A reader following CLAUDE.md would still picture the bare-script + manual-doc-read two-step the commit explicitly replaced (per the workflow row: "Replaces the previous 'run `bash .devshopkit/scripts/sync/from-devshop.sh` then read `PROPAGATION.md`' two-step"). Not a hard contradiction (the script still works and still prints the pointer), but stale-by-omission on the operator-facing handoff.
**Fix**: Add a clause to the `§ Session Start` drift sentence noting the `Sync:` reminder now points operators at `/ak-sync-from-devshop` (which runs the script + filters PROPAGATION.md to the version range), so the always-loaded doc matches the hook's actual output. One line; no structural change.

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/architecture.md:153
**What**: `architecture.md § Propagating build tooling updates` still presents the bare `.devshopkit/scripts/sync/from-devshop.sh` (and `--yes`) invocation as the canonical "pull devshop updates into a project" instruction, with no reference to the new `/ak-sync-from-devshop` skill that this commit established as the operator entry point (both session-start drift lines and the workflow row now route here).
**Why**: Cross-doc coherence — the guide section operators read for "how do I sync?" omits the skill that is now the recommended front door. The raw-script invocation remains correct (the skill wraps it), so this is an omission, not a contradiction; but leaving it unmentioned means the two canonical sync references (workflow Skill Map vs architecture § Propagating) now disagree on the recommended path.
**Fix**: Add a one-line pointer at the top of `§ Propagating build tooling updates` noting that operators normally invoke `/ak-sync-from-devshop` (which wraps the script + applies PROPAGATION.md steps for the version range), and that the bare-script invocations below are the underlying mechanism / scripted-use form.
