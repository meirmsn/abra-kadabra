# Tasks — merge-rebase-racy-git-remedy

## Tasks

- [x] **T1 — Reorder Phase 1.0 remedy** (done) — `merge-devshop/SKILL.md`: promote
  `"${GIT_CMD[@]}" -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"`
  to the first response to the virtiofs phantom error; demote the `git merge`
  fallback to second. Commit `5b336fa`.
- [x] **T2 — Cherry-pick/`am` recipe** (done) — same skill section: lead the recipe
  with the inline checkStat-minimal `-c` form, keep sleep + `update-index
  --really-refresh` as the deeper fallback. Commit `5b336fa`.
- [x] **T3 — CLAUDE.md footgun** (done) — one-line `§ Known Footguns` entry
  (symptom + first-action → `merge-devshop § Phase 1.0`). Commit `1ca32fe`.
- [x] **T4 — bats guard** (done) — `util-ak-merge-devshop.bats` new `@test`
  asserting the checkStat form exists in Phase 1.0 AND precedes the merge
  fallback (ordering invariant). `bats kit/tests/util-ak-merge-devshop.bats`
  → 104/104 green (new test is #58). Commit `5b336fa`.
- [ ] **T5 — Close trackers** (Phase 4.0) — delete `kit/ROADMAP.md § Merge-rebase
  racy-git remedy`, remove the `PLAN.md § Planned (v0)` row, rewrite the
  `kit/TODOS.md` "tracked at v0" cross-ref to shipped present tense. Deferred to
  Phase 4.0 (tracker-closure step) per the /ak-build flow.

## Decisions (judgment calls made during implementation)

- **T1 array-injection form**: wrote the retry as `"${GIT_CMD[@]}" -c
  core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"` so it works
  whether `GIT_CMD=(git)` or `GIT_CMD=(git -C "$WORKTREE_PATH")` — git parses
  `-C` then `-c`. Added an inline note in the skill confirming this is valid.
- **T2**: kept the sleep + `update-index --really-refresh` recipe rather than
  deleting it — checkStat-minimal is the lead unsticker, sleep+refresh the
  deeper fallback (mirrors the rebase's two-rung structure).
- **T3 placement**: clustered the new footgun with the other git-working-tree
  footguns (after "Never discard unrelated dirty files"), not at the end.
- **T4 ordering check**: used the same line-number comparison pattern as the
  existing "rebase-before-audit" test (grep -n within the awk-scoped Phase 1.0
  section, compare first-occurrence line numbers).
- **kit/TODOS.md NOT closed**: its entry tracks the deeper orchestrator-side
  mechanization (auto-detect + auto-switch), a separate deliverable. Only the
  ROADMAP checkStat-stopgap entry closes with this PR; the TODOS cross-ref to it
  gets rewritten to present tense.

## Test status

`bats kit/tests/util-ak-merge-devshop.bats` → 104 passed, 0 failed (includes the
new checkStat-ordering assertion). Full `bats kit/tests/` run is the Phase 3
fast-job-local gate.
