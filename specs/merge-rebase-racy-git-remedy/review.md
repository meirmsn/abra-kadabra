<!-- audited-at: b2d883a5a4e389c6e682a83938c0e223424bc962 -->

# Review — merge-rebase-racy-git-remedy (Phase 3 gates, devshop-self-mode)

## Router Summary

- passed=6
- findings_pending=0
- n_a=9
- blocked=4 (all STRUCTURAL — devshop-self-mode carve-outs; real_blocked=0)

Dispatched gates: 1 (docs-check), 2d (fast-job-local), 4 (/simplify), 5 (docs-and-tests-review), 6 (/review), 11 (convention) — all pass.
Non-LLM-mediated n/a carve-outs: 2, 2b, 2c, 2e, 2f, 2g, 3, 8b, 10b.
LLM-mediated structural blocked carve-outs: 7, 8, 9, 10.

Advance condition (findings_pending==0 AND real_blocked==0): **met**.

---

## Gate 1: docs-check

- Result: pass

The tooling change (Phase 1.0 remedy reorder in `merge-devshop/SKILL.md`) carries matching doc updates in the same branch:

- **Skill prose** — `merge-devshop/SKILL.md § 1.0` is the change itself: the phantom-error recovery is rewritten to lead with the `core.checkStat=minimal -c core.trustctime=false` rebase retry ("First remedy"), demote `git merge "$ANCHOR"` to "Second remedy", and propagate the same inline `-c` form into the adjacent cherry-pick/`am` recipe. The prose explains *why* (preserves the rebase; no transient merge commit for Phase 2's soft-reset to discard) and the inline-`-c`/never-repo-global scoping rule.
- **CLAUDE.md § Known Footguns** — new entry "Phantom 'local changes would be overwritten' on rebase (virtiofs)" in symptom + first-action + pointer shape, pointing the full recipe at `merge-devshop § Phase 1.0`.
- **Spec** — `specs/merge-rebase-racy-git-remedy/spec.md` records Decisions D1–D5, in/out of scope, and the deferred mechanization (kit/TODOS.md stays open).

Devshop tooling-change-carries-docs invariant satisfied: the skill (the tool), the operator-facing footgun, and the spec all move together in the branch.

## Dismissals

None

---

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop — no user-facing event surface)

## Dismissals

None

---

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase — no RLS surface)

## Dismissals

None

---

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI lifecycle in devshop)

## Dismissals

None

---

## Gate 2d: fast-job-local

- Result: pass

`bats kit/tests/` run by the orchestrator: **1568 passed, 0 failed**. This is the devshop-self-mode adaptation of the project turbo pipeline (`bats` is the test suite). The new ordering assertion in `util-ak-merge-devshop.bats` ("Phase 1.0 promotes core.checkStat=minimal rebase retry ABOVE the merge fallback") is included in that green count and was independently re-confirmed during this audit.

## Dismissals

None

---

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no database migrations)

## Dismissals

None

---

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

---

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase advisor surface)

## Dismissals

None

---

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

---

## Gate 4: simplify

- Result: pass

The diff is a doc reorder plus one bats assertion — minimal surface, appropriately scoped, no over-engineering.

- **Skill prose** — the reorder reuses the existing two code fences (rebase retry / merge fallback) rather than introducing new machinery; the "First remedy / Second remedy" framing is the simplest possible way to express precedence. The inline-`-c`-never-repo-global rule is stated once with rationale and cross-referenced (not duplicated) in the cherry-pick recipe via "same per-command scope rule as the rebase above". No redundancy.
- **Cherry-pick recipe** — the checkStat `-c` form is added as the lead unsticker while the existing `sleep 3` + `git update-index --really-refresh` is kept as the documented deeper fallback. This is additive, not a rewrite; the prior recipe's verified-incident provenance (calibration-and-task-phases, 2026-05-20) is preserved.
- **bats test** — the assertion is two-part (presence in the 1.0–1.1 awk region, then a line-number ordering invariant). The comment block is proportionate and states provenance. The `awk '/^### 1\.0:/,/^### 1\.1:/'` region-scoping is the right altitude: it pins ordering *within the relevant section* rather than the whole file, so an unrelated later `merge "$ANCHOR"` mention can't false-pass the invariant. No simpler form would still catch a merge-first regression.

The CLAUDE.md footgun is a single bullet at the right grain (symptom + first-action + pointer) — not duplicating the full recipe.

## Dismissals

None

---

## Gate 5: docs-and-tests-review

- Result: pass

Coverage + adequacy audit (Audit 1). Range: `origin/main...HEAD` over the three review targets.

**Tests — does the bats assertion actually pin the new behavior?** Yes. The new `@test` does two things, and both are load-bearing:
1. Asserts the `core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"` form appears in the Phase 1.0 region (anchored `/^### 1\.0:/,/^### 1\.1:/`). This guards against the remedy being deleted or its exact `-c` form being mangled.
2. Asserts the first occurrence of that checkStat form precedes the first `"${GIT_CMD[@]}" merge "$ANCHOR"` occurrence (line-number comparison `checkstat_line -lt merge_line`). This is the ordering invariant — it would FAIL if a future edit reordered the remedies back to merge-first. Re-ran during audit: passes.

The test is region-scoped (awk window), so it pins ordering *within Phase 1.0* rather than relying on whole-file line order — correct construction. The awk anchors match real SKILL.md headings (lines 638 `### 1.0:` / 808 `### 1.1:`). Adequate: it pins exactly the behavior D5 specifies (checkStat present AND before merge).

**Docs — do they reflect what changed?** Yes.
- SKILL.md § 1.0 prose is the change and matches the new ordering (checkStat retry line 87 of the region, merge fallback line 103 — consistent with the test).
- CLAUDE.md footgun entry states the correct first-action (inline `-c` retry, merge only if that still aborts) and the inline-not-repo-global rule, matching the skill.
- spec.md Decisions D1–D5 match the implemented diff exactly.

**Coverage gap?** None for what shipped. The deeper orchestrator-side auto-detect-and-switch mechanization is explicitly out of scope and stays open in `kit/TODOS.md` — correctly deferred, not a coverage hole in this PR.

## Dismissals

None

---

## Gate 6: review

- Result: pass

Structural review of the diff. The only "code" is shell snippets in the skill and the bats test; the rest is prose.

**`-c` flag injection into the GIT_CMD array (skill).** Correct.
- The retry is written `"${GIT_CMD[@]}" -c core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"`. `GIT_CMD` expands to `git` or `git -C "$WORKTREE_PATH"`. git's argument parser accepts global options (`-C <path>`, `-c <key>=<val>`) in any order before the subcommand, so `git -C <path> -c core.checkStat=minimal -c core.trustctime=false rebase` parses cleanly — `-C` then `-c` then subcommand. The skill prose explicitly calls this out ("git parses `-C` then `-c`"). Verified against git's documented behavior.
- **No repo-global config leak.** Both flags are inline per-command (`-c`), never `git config core.checkStat ...`. The skill states the rule twice (rebase region + cherry-pick region) and explains why: the reduced stat comparison stays scoped to the single invocation and can't bleed into unrelated git operations in the same worktree/session. This is the security-correct form — a repo-global `core.checkStat=minimal` would silently weaken stat-dirtiness detection for all future operations, which could mask real local changes.
- **Cherry-pick recipe** uses bare `git -c ...` (not the GIT_CMD array) — correct, because those are standalone surgical operations run directly against the current worktree, not routed through the merge skill's `-C`-targeted array.

**bats ordering check soundness.** Sound.
- Region-scoped via `awk '/^### 1\.0:/,/^### 1\.1:/'` — confines both the presence grep and the ordering comparison to Phase 1.0, so a `merge "$ANCHOR"` elsewhere can't satisfy the invariant.
- `grep -n ... | head -1 | cut -d: -f1` extracts the first line number of each form *within the awk output* (consistent numbering basis for both sides since both pipe the same awk region). `[ "$checkstat_line" -lt "$merge_line" ]` is a numeric comparison; both are guarded non-empty first (`[ -n ... ]`). No off-by-one or basis-mismatch risk.
- Escaping: `core\.checkStat` / `\$ANCHOR` / `\$\{GIT_CMD\[@\]\}` are correctly escaped for ERE (`grep -E`). Confirmed the grep matches the live file.

No conditional-side-effect, trust-boundary, or SQL concerns (none in scope). No structural issues.

## Dismissals

None

---

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

---

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

---

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md / no UI surface)

## Dismissals

None

---

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

---

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

---

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

---

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

---

## Phase 3 → 4 advance log

Structural carve-out overrides (LLM-mediated gates architecturally inapplicable in devshop-self-mode). Never submitted to adversarial review — the gate cannot be satisfied, it is not practically blocked.

### 2026-05-29T16:53:20Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T16:53:20Z -->

### 2026-05-29T16:53:20Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T16:53:20Z -->

### 2026-05-29T16:53:20Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface (bats invariants are the test surface, ran in Gate 2d)
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T16:53:20Z -->

### 2026-05-29T16:53:20Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T16:53:20Z -->

---

## Audit 1

<!-- audited-at: b2d883a5a4e389c6e682a83938c0e223424bc962 -->

Docs + tests audit (Gate 5). Range `origin/main...HEAD` over `.claude/skills/devshop/merge-devshop/SKILL.md`, `CLAUDE.md`, `kit/tests/util-ak-merge-devshop.bats`.

findings: high=0 medium=0 low=0

- **Tests** — the new bats `@test` pins the new behavior correctly: asserts the `core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"` form exists in the Phase 1.0 region AND that its first occurrence precedes the first `merge "$ANCHOR"` occurrence (line-number ordering invariant). Region-scoped via awk; re-ran during audit — passes. Guards against a merge-first regression.
- **Docs** — SKILL.md § 1.0 prose, the CLAUDE.md footgun entry, and spec.md Decisions D1–D5 all reflect the shipped checkStat-first / merge-second ordering and the inline-`-c`-never-repo-global rule. Consistent across all three.
- **Coverage** — complete for what shipped. The deeper orchestrator-side auto-detect-and-switch mechanization is explicitly out of scope and stays open in `kit/TODOS.md` — correctly deferred, not a gap.
