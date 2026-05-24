<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: sync-show-first-confirm -->
<!-- date: 2026-05-23 -->

# Spec: sync-show-first-confirm

**Sources:**

- `kit/TODOS.md` § Flip `sync/from-devshop.sh` (and `to-devshop.sh`) from apply-first-show-after to show-first-confirm-then-apply — primary scope
- `kit/docs/guide/architecture.md` § Apply-first-show-after semantics — architecture doc to rewrite
- `kit/tests/manifest-lifecycle.bats` — existing test coverage reference
- Prior BUILD-LOG entry `supabase-port-series-and-sync-safety` — sync safety fixes that preceded this work

Flip both sync scripts from apply-first-show-after to show-first-confirm-then-apply, so the operator sees a preview of proposed changes and confirms before any files are modified.

---

## Product update

### Headline (user-facing)

Sync scripts now show a preview of proposed changes and ask for confirmation before modifying any files — no more silent overwrites.

### Detail (team-facing)

`from-devshop.sh` and `to-devshop.sh` gain a two-pass dry-run-then-apply flow: stage proposed changes to `/tmp/sync-preview-$$/`, display a unified diff with file-count summary, then prompt `y/N/diff` via `/dev/tty`. `--yes`/`-y` flag bypasses the prompt for CI. Architecture doc rewritten from "apply-first-show-after" to "show-first-confirm-then-apply".

---

## Decisions (resolved at spec time)

6 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Dry-run strategy

**Decision:** Temp-dir staging (`/tmp/sync-preview-$$/`) with `diff` against current working tree.

**Rationale:** `rsync -an --itemize-changes` shows what would change but in rsync's own format — not a familiar unified diff. Staging to a temp dir and running `diff -rq` (summary) + `diff -ru` (per-file unified diff) gives the operator the exact same output format they'd see from `git diff` post-apply.

### D2: Prompt mechanism

**Decision:** Read from `/dev/tty`, not stdin.

**Rationale:** When invoked under `su node -c` or piped contexts, stdin isn't a terminal. `/dev/tty` reads from the controlling terminal directly — same pattern as the pnpm prompt fix in `ba0ab3e`.

### D3: `--yes` flag shape

**Decision:** Both `--yes` and `-y`.

**Rationale:** Symmetric with `apt-get -y`, `gh pr merge --yes`. Minimal cost.

### D4: Diff display format

**Decision:** `diff -ru` with `--color` when available (avoid git dependency in the diff path).

**Rationale:** `git diff --no-index` works but prints confusing headers (`a/tmp/sync-preview-.../turbo.json` vs `b/workspace/turbo.json`). Plain `diff -ru` with labels gives cleaner output.

### D5: Abort behavior

**Decision:** Abort is a clean no-op — no `git checkout` recovery needed because we haven't touched anything yet.

**Rationale:** The whole point of show-first is that abort leaves the working tree untouched. The temp dir gets cleaned up; nothing else happens.

### D6: `to-devshop.sh` treatment

**Decision:** Yes, same dry-run preview before applying — same PR.

**Rationale:** Per the TODOS entry: "Pushing project content back to template is more catastrophic per failure." Same pattern, same PR.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens, Data
     model changes, API contracts, Offline behavior, Metrics, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Product update + Decisions sections above
     stay verbatim. -->
