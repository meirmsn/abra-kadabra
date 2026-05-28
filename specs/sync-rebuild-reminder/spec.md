<!-- generated-by: /ak-build Phase 0 (devshop mode) -->
<!-- feature: sync-rebuild-reminder -->
<!-- date: 2026-05-28 -->

# Spec: sync-rebuild-reminder

**Sources:**

- Operator request (2026-05-28): "the sync from devshop skill should tell me to rebuild container at the end right?"
- `kit/TODOS.md` § init-devshop mtime-bumps `[locked]` files (trains operators to dismiss VS Code's rebuild prompt) — related problem space; this feature is the complementary *accurate* rebuild signal
- `kit/scripts/sync/from-devshop.sh` — the sync script to extend
- `.claude/skills/devshop/sync-from-devshop/SKILL.md` — the skill to document
- `kit/scripts/init-devshop.sh:178-188` — the locked-file refresh-from-template loop that makes a rebuild the mechanism for applying `.devcontainer` changes
- Prior spec `specs/sync-show-first-confirm/spec.md` — style/structure reference

After a sync, tell the operator whether they need to rebuild the devcontainer — based on a content diff of the project's in-tree locked `.devcontainer/` files against the devshop template — so `.devcontainer` changes (Dockerfile, devcontainer.json, init scripts, firewall, compose) don't silently lag behind the version bump.

---

## Product update

### Headline (user-facing)

Infrastructure update — `/ak-sync-from-devshop` now tells you at the end whether you need to rebuild the devcontainer, so devcontainer changes never silently lag behind a sync.

### Detail (team-facing)

`from-devshop.sh` gains a post-sync drift check: it diffs the project's in-tree locked `.devcontainer/` leaves (enumerated from the manifest via `manifest_locked_under`) against `/devshop/template/.devcontainer/`. The sync rsync excludes those locked leaves (`init-devshop.sh` owns them, refreshing from template on every container start), so they're invisible to `git diff` — only a template-vs-project content diff predicts what the next container start will change. On drift it prints a loud "Rebuild needed" block listing the differing files; on a clean check it prints a one-line "no `.devcontainer` changes — rebuild not needed" note (conditional + always-note). The skill repeats the verdict in its summary and Phase 4 commit handoff.

---

## Decisions (resolved at Phase 0 with the operator)

### D1: Reminder trigger

**Decision:** Conditional + always-note. Loud "rebuild needed" block only when the project's locked `.devcontainer/` files differ from the template; otherwise a one-line "no `.devcontainer` changes — rebuild not needed" confirmation so the verdict is never ambiguous.

**Rationale:** Operator chose this over always-remind (noisy on tooling-only syncs) and silent-conditional (ambiguous — operator can't tell whether the check ran). Pairs well with the known noise problem in `kit/TODOS.md` (VS Code's mtime-based rebuild prompt cries wolf); a content-based always-note is the trustworthy counter-signal.

### D2: Detection signal — template-vs-project content diff, not git diff

**Decision:** Diff each locked `.devcontainer/` leaf (`manifest_locked_under .devcontainer`) between `$PROJECT_ROOT/.devcontainer/<leaf>` and `$DEVSHOP_DIR/template/.devcontainer/<leaf>` using `cmp -s`. A leaf is "drifted" if the template copy exists AND (the project copy is missing OR differs).

**Rationale:** The sync rsync excludes locked leaves (`build_rsync_excludes` filters `manifest_locked_under`), so they never appear in the working-tree `git diff` after a sync. `init-devshop.sh:178-188` refreshes them from `$DEVSHOP/template/$path` via `install` on every container start, so the template-vs-project content diff exactly predicts what the next start (rebuild) will change. Version-tag range logic is unusable — tags lag `kit/version` badly (latest tag v1.9.0, current 1.35.0).

### D3: Scope to `.devcontainer/` locked leaves only

**Decision:** Only `.devcontainer/` locked leaves drive the rebuild verdict. Other locked files (`.husky/*`, etc.) are out of scope.

**Rationale:** "Rebuild container" is specifically about `.devcontainer/`. Among those leaves, image-defining files (`Dockerfile`, `devcontainer.json`, `compose.yml`, `supabase-runner/Dockerfile`) strictly require a full rebuild; the init scripts refresh on any container start (which a rebuild includes). Husky hook changes take effect on next commit without a container rebuild, so they don't belong in this signal.

### D4: Where the logic lives — script first, skill documents

**Decision:** Detection + reminder live in `from-devshop.sh` (prints to stdout after the version bump). The SKILL.md documents the verdict and surfaces/repeats it. No new lib file — inline function, consistent with the script's existing structure and testable via the established whole-script bats pattern.

**Rationale:** The script is the durable source of truth (works standalone, bats-testable end-to-end like `sync-package-json-merge.bats`). The skill wraps the script and must echo the verdict so Claude-driven runs surface it prominently in the summary + commit handoff.

---

## In scope

- `from-devshop.sh`: a `report_devcontainer_rebuild()` function called after the version bump that enumerates locked `.devcontainer/` leaves, content-diffs project vs template, and prints the conditional loud block / always-note.
- `sync-from-devshop/SKILL.md`: a new short section (post-sync rebuild verdict) + a line in Phase 4 commit handoff that repeats the verdict.
- `kit/tests/sync-devcontainer-rebuild-reminder.bats`: drift case, clean case, non-locked-only-change case.
- `kit/docs/guide/workflow.md`: note the rebuild verdict in the sync skill map.
- `kit/docs/CHANGELOG.md`: changelog entry (handled at release time, but note the change).

## Out of scope

- Fixing `init-devshop.sh`'s unconditional locked-file rewrite (the mtime-bump noise in `kit/TODOS.md`). Separate, larger change touching a locked template file via the `/tmp + sudo install` handoff. This feature makes that less urgent (operators get an accurate terminal signal) but does not replace it.
- `to-devshop.sh` (devshop-direction sync; no project devcontainer to rebuild).

## Files to create/modify

- modify `kit/scripts/sync/from-devshop.sh`
- modify `.claude/skills/devshop/sync-from-devshop/SKILL.md`
- create `kit/tests/sync-devcontainer-rebuild-reminder.bats`
- modify `kit/docs/guide/workflow.md` (sync skill map line)

## Tests

bats (`kit/tests/sync-devcontainer-rebuild-reminder.bats`):

1. **Drift → reminder**: template `.devcontainer/Dockerfile` differs from project copy → output contains "Rebuild" and names `Dockerfile`.
2. **Clean → no-rebuild note**: locked `.devcontainer/` leaves byte-identical → output contains the "no .devcontainer changes" note and NOT a rebuild reminder.
3. **Project-missing leaf → reminder**: project lacks a locked leaf the template has → flagged as drift.
4. **Non-locked-only change does not trigger**: a synced (non-locked) `.devcontainer/README.md` change with identical locked leaves → no rebuild reminder.

## Task order

1. Add `report_devcontainer_rebuild()` + call site to `from-devshop.sh`.
2. Document the verdict in `sync-from-devshop/SKILL.md` (new section + Phase 4 line).
3. Add `kit/tests/sync-devcontainer-rebuild-reminder.bats`.
4. Update `kit/docs/guide/workflow.md` sync skill map.

## Gotchas

- The clean case still has the existing synced non-locked `.devcontainer/` files updated by rsync — those must NOT contribute to the rebuild verdict (D3 scopes to locked leaves only).
- `cmp -s` returns non-zero on missing file too — treat "template exists, project missing-or-differs" as drift; skip leaves whose template source is absent (host-supabase / skip projects legitimately lack some).
- Keep the script's plain-text output voice (no emoji in script prose); the SKILL.md may use ✓/⚠ status markers per its output conventions.
