<!-- generated-by: /ak-build Phase 0 + Phase 1 (devshop mode) -->
<!-- feature: merge-rebase-racy-git-remedy -->
<!-- date: 2026-05-29 -->

# Spec: merge-rebase-racy-git-remedy

**Sources:**

- `kit/ROADMAP.md § Merge-rebase racy-git remedy — core.checkStat=minimal as the first Phase 1.0 fix` — primary scope + decisions (v0, surfaced-by implement-resume-reconcile-2026-05-29)
- `kit/TODOS.md` — the deeper orchestrator-side mechanization entry (stays open; this PR ships only the checkStat stopgap, not the auto-detect-and-switch mechanization)
- `PLAN.md § Planned (v0)` row `merge-rebase-racy-git-remedy` — scope summary + source pointer
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0` — the skill region this amends

Devshop merge tooling gains a first-line recovery for the virtiofs phantom
"local changes would be overwritten" rebase flake: retry the rebase with
`core.checkStat=minimal -c core.trustctime=false` (preserving the rebase)
before falling back to a merge.

---

## Product update

Single source-of-truth for the BUILD-LOG entry + `/ak-merge-devshop` squash
message. Collapsed shape — this is a devshop-internal tooling change with no
end-user product surface.

### Headline + Detail (combined)

Infrastructure update — no user-visible change in this PR. The devshop's
merge tooling (`/ak-merge-devshop § Phase 1.0`) now retries a flaky rebase
with `git -c core.checkStat=minimal -c core.trustctime=false` before
dropping to a merge fallback. On virtiofs/overlay devcontainers (macOS /
linuxkit) `git rebase` intermittently false-aborts with "Your local changes
to the following files would be overwritten by merge" on a verifiably clean
tree — a stat-cache race, not a real diff. The checkStat-minimal retry
resolves it while keeping the rebase (no transient merge commit for Phase 2's
soft-reset to discard), so the merge fallback becomes the second rung instead
of the first. The same `-c` form is added to the adjacent cherry-pick/`am`
recipe, and a one-line `CLAUDE.md § Known Footguns` entry points operators at
the remedy.

---

## Decisions (resolved at spec time)

5 decisions resolved in Phase 0 with the operator.

### D1: First remedy when the phantom error fires

**Decision:** Promote `"${GIT_CMD[@]}" -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"`
to the **first** remedy; demote the existing `git merge "$ANCHOR"` fallback to
**second** (used only if the checkStat-minimal retry still fails).

**Rationale:** checkStat=minimal preserves the rebase — no transient merge
commit for Phase 2's soft-reset to discard, same code path. Resolved cleanly
first-try every time in the `implement-resume-reconcile` incident (2026-05-29).

### D2: Inline `-c` flags vs repo-global config

**Decision:** Inline `-c core.checkStat=minimal -c core.trustctime=false` on
the single rebase (and cherry-pick) invocation. Do NOT set repo-global config.

**Rationale:** Scopes the reduced stat comparison to the one command — no
global side effect on unrelated git operations.

### D3: Apply to the cherry-pick / `git am` recipe too

**Decision:** Add the same `-c` form to the adjacent cherry-pick/`am` recipe,
kept alongside (not replacing) the existing `sleep 3` + `git update-index
--really-refresh` unsticker.

**Rationale:** Same flake, same class of fix; keeps the two recovery recipes
consistent and gives the checkStat form as the lead unsticker there too.

### D4: CLAUDE.md footgun entry

**Decision:** Add a one-line `CLAUDE.md § Known Footguns` entry (symptom +
first-action), pointing the recipe at `merge-devshop § Phase 1.0`.

**Rationale:** Matches the footgun-entry convention — symptom + first-action
here, full recipe in the owning skill/guide.

### D5: Test surface

**Decision:** Add a content-validation bats assertion in
`kit/tests/util-ak-merge-devshop.bats` that the `core.checkStat=minimal` form
appears in the Phase 1.0 phantom-error region AND precedes the `git merge
"$ANCHOR"` fallback.

**Rationale:** Cheap regression guard so a future skill edit can't silently
reorder the remedies back to merge-first. bats is the devshop test surface.

---

## In scope

- Reorder the Phase 1.0 phantom-error recovery in
  `.claude/skills/devshop/merge-devshop/SKILL.md`: checkStat-minimal rebase
  retry first, merge fallback second.
- Add the checkStat-minimal `-c` form to the cherry-pick/`am` recipe in the
  same skill section.
- One-line `CLAUDE.md § Known Footguns` entry.
- bats assertion in `kit/tests/util-ak-merge-devshop.bats`.
- Close `kit/ROADMAP.md § Merge-rebase racy-git remedy` (delete) + remove the
  `PLAN.md § Planned (v0)` row; unwind cross-references.

## Out of scope

- The deeper orchestrator-side mechanization (auto-detect the phantom + auto-
  switch recovery path without halting the merge subagent) — stays open in
  `kit/TODOS.md`. This PR ships only the checkStat stopgap that stops the
  rebase from false-failing in the first place.
- Any change to repo-global git config.

## Files to create / modify

- `.claude/skills/devshop/merge-devshop/SKILL.md` — Phase 1.0 remedy reorder +
  cherry-pick/`am` recipe (modify)
- `CLAUDE.md` — § Known Footguns one-liner (modify)
- `kit/tests/util-ak-merge-devshop.bats` — checkStat-first assertion (modify)
- `kit/ROADMAP.md` — delete the shipped v0 entry (modify)
- `PLAN.md` — remove the Planned (v0) row (modify)
- `specs/merge-rebase-racy-git-remedy/` — spec.md, tasks.md, review.md (create)

## Tests

bats content-validation (`kit/tests/util-ak-merge-devshop.bats`):

- New `@test`: the Phase 1.0 phantom-error region contains the
  `core.checkStat=minimal` + `core.trustctime=false` rebase form, AND that
  form's first occurrence precedes the first `git merge "$ANCHOR"` /
  `merge "$ANCHOR"` occurrence (remedy ordering: checkStat retry before merge
  fallback).

No runtime code changes → no other test surface. Existing bats suite must
still pass (`bats kit/tests/`).

## Dependencies

- Builds on `merge-devshop-phase25-tree-pin` (`6f441e1`), `claude-md-hygiene`
  (`e930fdc`), `ak-build-commit-spec-expansion` (`000c4a2`) — all merged to
  `origin/main` before this branch was cut. No code dependency, but this PR
  edits the same Phase 1.0 region phase25 touched, so it is sequenced after it.

## Task order

1. **Reorder Phase 1.0 remedy** — in `merge-devshop/SKILL.md`, make the
   checkStat-minimal rebase retry the first response to the phantom error;
   demote the merge fallback to second.
2. **Cherry-pick/`am` recipe** — add the checkStat-minimal `-c` form to the
   adjacent recipe in the same section.
3. **CLAUDE.md footgun** — add the one-line § Known Footguns entry.
4. **bats guard** — add the checkStat-first assertion to
   `util-ak-merge-devshop.bats`; run `bats kit/tests/util-ak-merge-devshop.bats`.
5. **Close trackers** — delete the `kit/ROADMAP.md` v0 entry, remove the
   `PLAN.md` Planned row, unwind cross-refs (`kit/TODOS.md` cross-ref prose
   stays — it tracks the still-open mechanization, but rewrite its "tracked at
   v0" pointer to "shipped" present tense).

## Gotchas

- `"${GIT_CMD[@]}"` is an array that may expand to `git -C "$WORKTREE_PATH"`.
  The retry must inject the `-c` flags as `"${GIT_CMD[@]}" -c core.checkStat=minimal
  -c core.trustctime=false rebase "$ANCHOR"` — git accepts `-c` after `-C`.
- Keep the inline `-c` form; do not introduce `git config`.
- `kit/TODOS.md` entry is NOT closed — it tracks the deeper mechanization, a
  separate deliverable. Only the ROADMAP checkStat-stopgap entry closes.

## Acceptance

- Phase 1.0 of `merge-devshop/SKILL.md` documents checkStat-minimal rebase as
  the first remedy, merge fallback as the second.
- Cherry-pick/`am` recipe carries the checkStat-minimal form.
- `CLAUDE.md § Known Footguns` has the pointer entry.
- `bats kit/tests/` is green, including the new assertion.
- ROADMAP v0 entry + PLAN row removed; no orphaned cross-references.
