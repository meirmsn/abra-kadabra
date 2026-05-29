## Gate 1: docs-check

- Result: pass

The tooling change (Phase 1.0 remedy reorder in `merge-devshop/SKILL.md`) carries matching doc updates in the same branch:

- **Skill prose** — `merge-devshop/SKILL.md § 1.0` is the change itself: the phantom-error recovery is rewritten to lead with the `core.checkStat=minimal -c core.trustctime=false` rebase retry ("First remedy"), demote `git merge "$ANCHOR"` to "Second remedy", and propagate the same inline `-c` form into the adjacent cherry-pick/`am` recipe. The prose explains *why* (preserves the rebase; no transient merge commit for Phase 2's soft-reset to discard) and the inline-`-c`/never-repo-global scoping rule.
- **CLAUDE.md § Known Footguns** — new entry "Phantom 'local changes would be overwritten' on rebase (virtiofs)" in symptom + first-action + pointer shape, pointing the full recipe at `merge-devshop § Phase 1.0`.
- **Spec** — `specs/merge-rebase-racy-git-remedy/spec.md` records Decisions D1–D5, in/out of scope, and the deferred mechanization (kit/TODOS.md stays open).

Devshop tooling-change-carries-docs invariant satisfied: the skill (the tool), the operator-facing footgun, and the spec all move together in the branch.

## Dismissals

None
