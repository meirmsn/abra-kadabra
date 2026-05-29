## Gate 11: convention

- Result: pass

Devshop conventions (`kit/docs/guide/conventions.md`, CLAUDE.md) checked against the diff.

- **Inline `-c` (not `git config`)** — satisfied. Both the rebase retry and the cherry-pick recipe use per-command `-c` flags; the skill states the never-repo-global rule explicitly in both regions. Matches the principle-of-least-privilege / minimal-blast-radius posture.
- **Footgun entry shape** — the new CLAUDE.md § Known Footguns bullet follows the documented shape: bolded symptom ("Phantom 'local changes would be overwritten' on rebase (virtiofs)"), explicit **First action** (inline `-c` retry, merge fallback only if it still aborts), and a pointer to the full recipe (`merge-devshop § Phase 1.0`). Recipe-heavy detail lives in the owning skill, not duplicated in the footgun — matches the stated convention "the entry here is the symptom + first-action".
- **Commit + PR text style** — branch commits are at the right grain: `fix(ak-merge-devshop): checkStat=minimal rebase retry as first Phase 1.0 remedy`, `docs(claude-md): add virtiofs phantom-rebase footgun + checkStat remedy`, plus the spec/tasks docs commits. Subjects describe the observable change, conventional-commit prefixed, ≤72 chars. (Squash-message composition + propagation-block enforcement is the Phase 4.0/4.5 `/ak-merge-devshop` surface, not this gate.)
- **Tracker closure** — spec.md § In scope lists deleting the `kit/ROADMAP.md` v0 entry and removing the `PLAN.md` Planned row. These are **not in this audited diff** because tracker closure is deferred to Phase 4.0 bookkeeping per the build pipeline — this is by design, not a convention violation. The `kit/TODOS.md` mechanization entry correctly stays open (separate deliverable).
- **bats test for tooling change** — the skill change carries a regression guard in `util-ak-merge-devshop.bats`. No-code-without-tests satisfied (bats is the devshop test surface).

## Dismissals

- **ROADMAP/PLAN closure not present in diff** — n/a as a violation: deferred to Phase 4.0 per `/ak-build` devshop-mode pipeline. Will be verified at bookkeeping, not at this analysis-pass gate.
