### Tests findings

- (none high/medium)

Coverage assessment:

- Section G (G1–G4) added to kit/tests/util-ak-build-skill.bats is adequate coverage for the SKILL.md behavior change. The change is LLM-orchestrator prose, so the only meaningful test surface is structural assertions against the SKILL.md text — exactly what Sections A–F already do, and what Section G extends.
- The assertions pin the ACTUAL new text, not tautologies. Verified each against the pre-change strings:
  - G1 pins `^### 1.1: Commit the expanded spec` — the new subsection header.
  - G2 scopes to the Phase-1 region via `awk '/^## Phase 1: Spec/,/^## Phase 2:/'` and asserts the canonical `git add "$FEATURE_DIR/spec.md"`, the `git diff --cached --quiet` idempotence guard, and the `docs($FEATURE): expand spec (Phase 1)` message all appear, plus a meaningful NEGATIVE assert that no `git push` exists in the region (confirmed the region genuinely contains zero `git push` — so the negative assert can actually fail if a push leaks in).
  - G3 (`grep -qE '\| 1 \|.*committed.*## Task order.*git show HEAD:'`) genuinely detects the change: confirmed it does NOT match the old row (`contains '## Task order' … grep -q`), so it is a real regression guard, not a tautology.
  - G4 scopes to the resume region with the same `awk '/^### Resume check/,/^## Phase 0/'` boundary Section F uses, requires `committed at HEAD` count ≥ 2 (confirmed exactly 2 in the region; old rungs had 0) AND a literal `git show HEAD:$FEATURE_DIR/spec.md | grep -q`. Both rungs are pinned.
- All 46 tests in util-ak-build-skill.bats pass (including 43–46 = G1–G4). The registry-row reword did not break any existing Section A–F assertion.
- Nothing material untested. The four observable units of the change (commit step present; idempotence guard present; registry row 1 committed-state; resume rungs 4/5 committed-state) each map to a dedicated assertion. The "no push in Phase 1" invariant — the one behavior most likely to silently regress — is explicitly guarded by G2's negative assert.
- One known pre-existing full-sweep failure (structural-invariants.bats reconcile-task-commits wiring) is already routed to kit/TODOS.md and is out of scope for this change — not a finding.

### Bypass trailer audit

- (none)
