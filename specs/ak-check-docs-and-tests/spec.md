---
feature: ak-check-docs-and-tests
status: draft
roadmap: kit/ROADMAP.md § Move adversarial Layer 2 reviews from per-commit to sweep-time
prs: PR-A (skills + orchestrator), PR-B (Phase 5.8 wiring + file collapse), PR-C (per-commit removal + symmetry rename + cost savings)
---

# `/ak-check-docs-and-tests` — sweep-time docs+tests audit

## Provenance

This spec implements the v0 roadmap entry at `kit/ROADMAP.md:16`. The roadmap captures the cost + signal-quality argument; this spec captures the architectural shape after a design review pass that surfaced three load-bearing refinements:

1. **All Layer 2 judgment lives in skills, not in `adversarial-review.sh` check-types.** The orchestrator is pure-skill orchestration. `adversarial-review.sh` shrinks to its actual purpose: bypass-reason judgment fired from bash hooks.
2. **One Layer 2 skill per domain, judging both coverage and quality.** No split between coverage and quality sub-skills; the asymmetry between docs (coverage at L1, quality at L2) and tests (coverage at L1, coverage _also_ at L2, quality at L2) was an accident.
3. **Layer 1 bypasses at commit-time get extra scrutiny at sweep-time.** The bypass reason becomes a recorded commit trailer that the L2 sweeper picks up and re-judges with awareness that L1 was skipped.

## Sources

- `kit/ROADMAP.md:16-163` — original roadmap entry
- `kit/scripts/adversarial-review.sh:1-120` — current LLM-call engine, CHECK_TYPE switch, CONVENTIONS_TO_INCLUDE map
- `kit/scripts/commit-hooks/commit-guard.sh:94-260` — current per-commit `docsReviewed` + `testCoverage` (release-time) Layer 2 invocations
- `kit/scripts/commit-hooks/check-test-coverage-project.sh:130-244` — current project-side L1+L2 split
- `kit/scripts/commit-hooks/check-docs-freshness-project.sh:200-285` — current project-side L1+L2 split (note: uses `docsReviewed` check-type, not `docsFreshnessProject` which was merged into `docsReviewed` 2026-05-01)
- `kit/scripts/commit-hooks/check-test-coverage.sh:1-40` — current devshop-side test-coverage L1
- `.claude/skills/devshop/build/SKILL.md:776-960` — current Phase 5.8 wiring (writes to `test-review-followup.md`)
- `.claude/skills/devshop/pre-ship/SKILL.md:447-455` — current Gate 5 (invokes `/ak-test-review`)
- `.claude/skills/devshop/test-review/SKILL.md` — current `/ak-test-review` skill (stays, will be renamed + scope-expanded in PR-A)

## Decisions (locked in via design pass)

### D1. Sweep-time Layer 2 judgment lives in skills

**Choice**: New skills `/ak-docs-review` (NEW) and `/ak-tests-review` (rename + scope-expand of existing `/ak-test-review`). Orchestrator skill `/ak-check-docs-and-tests` invokes them.

**Why**: The pre-design state had Layer 2 fired from bash hooks via `adversarial-review.sh`. At sweep time the agent IS the caller, so there's no reason to route through a bash script — skills give richer affordances (Glob/Grep/AskUserQuestion, multi-file reads, structured findings) and keep each prompt's policy + conventions colocated with the skill.

**How to apply**: `adversarial-review.sh` keeps only its bypass-reason check-types (`prDescStaleReason`, `dirtyTreeReason`, `manifestReviewed`, `hookBypass`, `exemptAddition`, `testReviewSkipReason`, `dismissalLog`). The doc/test adequacy check-types (`docsReviewed`, `testCoverageProject`, `testCoverage` release-time) move into skills and the bash check-types are removed in PR-C.

### D2. One Layer 2 skill per domain — covers both coverage and quality

**Choice**: `/ak-docs-review` judges both "did you update enough docs?" (coverage) AND "are the doc updates thorough/correct?" (quality). `/ak-tests-review` judges both "does the diff have paired tests for surfaces it touches?" (coverage) AND "are the tests well-written?" (quality — assertion strength, RLS coverage, skip audits, wrapper-API lifecycle, Zod-at-LLM-boundary, etc.).

**Why**: Symmetric across docs and tests. Each domain has one skill with one rubric. Avoids the trap where `/ak-test-coverage-review` and `/ak-tests-review` would both ship and operators would wonder which to invoke when.

**How to apply**: `/ak-tests-review`'s SKILL.md absorbs the coverage rubric from the current `testCoverageProject` adversarial-review.sh prompt. Its existing quality rules (weak assertions, RLS, etc.) are unchanged. `/ak-docs-review` is built fresh by lifting the current `docsReviewed` adversarial-review.sh prompt into a skill.

### D3. L1/L2 naming distinction: "presence" vs "review"

**Choice**: Layer 1 scripts are renamed to `check-{tests,docs}-presence-{project,devshop}.sh`. Layer 2 skills are `/ak-{docs,tests}-review`. No substring overlap between layers.

**Why**: Pre-design naming had both `check-test-coverage-project.sh` (L1) and `/ak-test-coverage-review` (proposed L2) — operators would conflate them. "Presence" describes what L1 actually does (file-pairing math); "review" describes the LLM-judgment activity of L2.

**How to apply**: Renames land in PR-C alongside the L2 invocation removal:

|             | tests                                                                | docs                                                                 |
| ----------- | -------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **project** | `check-test-coverage-project.sh` → `check-tests-presence-project.sh` | `check-docs-freshness-project.sh` → `check-docs-presence-project.sh` |
| **devshop** | `check-test-coverage.sh` → `check-tests-presence-devshop.sh`         | (NEW) `check-docs-presence-devshop.sh`                               |

### D4. L1 bypass at commit-time records a commit trailer for sweep-time pickup

**Choice**: When a Layer 1 hook is bypassed via `git -c devshop.<domain>PresenceReason="<why>"`, a `prepare-commit-msg` hook appends a commit trailer `Devshop-<Domain>-Presence-Bypass: <reason>` to the commit message. Sweep-time L2 skills harvest trailers from commits in their range and re-judge each bypass with extra scrutiny — was the bypass actually warranted given what eventually shipped?

**Why**: Without this, per-commit bypass becomes silent skip. The whole point of moving Layer 2 to sweep-time was that judgment is more accurate when artifacts exist; the corollary is the sweep MUST know what was bypassed at commit time.

**How to apply**:

- New hook `kit/scripts/commit-hooks/prepare-bypass-trailer.sh` runs from `prepare-commit-msg`. Reads `git config --get devshop.testsPresenceReason` and `devshop.docsPresenceReason`. For each non-empty value, appends a trailer line.
- L2 skills pick up trailers via `git log --pretty='%H%n%B%n---' <range>` and a parser. For each bypass-flagged commit, the skill's prompt includes: "Commit `<sha>` bypassed Layer 1 `<domain>-presence` with reason: `<reason>`. Verify the eventual diff justifies this bypass."

### D5. Orchestrator output: single `review.md` with appended `## Sweep N` sections

**Choice**: Both first-sweep (Phase 3 / pre-polish) and second-sweep (Phase 5.8 / post-polish) write to `specs/<feature>/review.md`. Each invocation appends a new `## Sweep N: <pre-polish|post-polish> (date)` section. The `test-review-followup.md` file is removed (its data folds into Sweep 2).

**Why**: Single file = single place to read audit history. Idempotence via the latest sweep section's `audited-at: <SHA>` stamp.

**How to apply**: Sweep section shape (matches roadmap):

```
## Sweep 1: pre-polish (2026-05-06)
audited-at: abc123
range: origin/main..abc123
findings: high=0 medium=2 low=3
- [med] apps/web/.../<file>:<line> — <one-line summary>
- ...

## Sweep 2: post-polish (2026-05-08)
audited-at: def456
range: abc123..def456
findings: high=0 medium=1 low=0
- ...
```

Idempotence: when the latest `## Sweep N` section's `audited-at` matches current HEAD, the orchestrator no-ops with `✓ already audited at <SHA>`.

### D6. Gate 5 (currently `/ak-test-review`) folds into the new orchestrator

**Choice**: `/ak-pre-ship` Gate 5 invokes `/ak-check-docs-and-tests` instead of `/ak-test-review` directly. The orchestrator handles both docs and tests in one gate.

**Why**: Pre-ship's Gate 5 is the natural Phase-3-first-sweep entry. Folding here means one gate → one audit per sweep moment, instead of two adjacent gates (current `/ak-test-review` + a new `/ak-docs-review` gate).

**How to apply**: `/ak-pre-ship` Gate 5 renames from "test-review" to "docs-and-tests-review" (or "sweep" — naming bikeshed deferred to implementation). The router shim and gate-name mapping update accordingly.

## End-state inventory (after PR-A + PR-B + PR-C)

### Bash scripts at `kit/scripts/commit-hooks/`

| Path                              | Purpose                                              | Layer | Repo    |
| --------------------------------- | ---------------------------------------------------- | ----- | ------- |
| `check-tests-presence-project.sh` | tests file-pairing math                              | L1    | project |
| `check-tests-presence-devshop.sh` | bash-tests file-pairing math                         | L1    | devshop |
| `check-docs-presence-project.sh`  | docs file-pairing math                               | L1    | project |
| `check-docs-presence-devshop.sh`  | NEW: surface→doc map for devshop                     | L1    | devshop |
| `prepare-bypass-trailer.sh`       | NEW: records L1 bypass reasons as commit trailers    | infra | both    |
| `commit-guard.sh`                 | EXISTING (modified): mixed-commit check, no L2 calls | L1    | both    |
| (other existing checks unchanged) |                                                      |       |         |

### Skills at `.claude/skills/devshop/`

| Path                            | Purpose                                                                | Status                     |
| ------------------------------- | ---------------------------------------------------------------------- | -------------------------- |
| `check-docs-and-tests/SKILL.md` | NEW: orchestrator (computes range, invokes L2 skills, appends Sweep N) | NEW in PR-A                |
| `docs-review/SKILL.md`          | NEW: judges docs coverage + quality over a range                       | NEW in PR-A                |
| `tests-review/SKILL.md`         | RENAMED from `test-review/`; scope-expanded to also judge coverage     | RENAMED + EXPANDED in PR-A |

### `kit/scripts/adversarial-review.sh` surface

After PR-C the CHECK_TYPE switch carries only:

- `prDescStaleReason` (pre-push)
- `dirtyTreeReason` (pre-commit clean-tree)
- `manifestReviewed` (commit-guard manifest)
- `hookBypass` (commit-guard hook-bypass)
- `exemptAddition` (commit-guard exempt-list)
- `testReviewSkipReason` (Phase 5.8 halt override — repurposed for sweep skip)
- `dismissalLog` (pre-ship dismissal rationales)

Removed in PR-C: `docsReviewed`, `testCoverage`, `testCoverageProject`, `docsFreshnessProject` (already merged into `docsReviewed`).

## Two flows, end to end

### Per-commit flow (every git commit, agent-agnostic)

```
git commit
  ├─ prepare-commit-msg
  │   └─ prepare-bypass-trailer.sh           ← appends bypass trailers
  └─ pre-commit
      └─ kit/hooks/pre-commit.sh
          ├─ check-tests-presence-{project,devshop}.sh    ← L1 file math
          ├─ check-docs-presence-{project,devshop}.sh     ← L1 file math
          ├─ check-clean-tree.sh, check-manifest.sh, …    ← other L1 hooks
          └─ commit-guard.sh
              └─ adversarial-review.sh <bypass-type>      ← bypass-reason judgment ONLY
                                                            (only when a bypass flag is set)
```

No docs/tests adequacy LLM calls. No skill invocations.

### Sweep-time flow (operator invokes; or `/ak-build` Phase 3 / Phase 5.8)

```
operator: /ak-check-docs-and-tests
  └─ orchestrator skill
      ├─ Read specs/<feature>/review.md → compute range
      │   - if no Sweep N section: range = origin/main..HEAD (first sweep)
      │   - else: range = <latest-sweep-audited-at>..HEAD (polish sweep)
      │   - if range empty (HEAD == latest sweep): no-op + exit
      ├─ git log --pretty='%H%n%B%n---' <range>
      │   → harvest Devshop-{Docs,Tests}-Presence-Bypass trailers
      ├─ /ak-docs-review (range, bypass-trailers-for-docs)
      │   → emits findings (high/medium/low + file:line + summary)
      ├─ /ak-tests-review (range, bypass-trailers-for-tests)
      │   → emits findings (high/medium/low + file:line + summary)
      └─ Append `## Sweep N` to specs/<feature>/review.md
          → high>0 ⇒ halt (operator must address or `git -c devshop.testReviewSkipReason="..."`)
          → med/low ⇒ surface in Phase 6 audit comment
          → 0/0/0 ⇒ "Clean" entry
```

## PR breakdown

### PR-A (~6-8h) — orchestrator + 2 L2 skills + Gate 5 fold

**Adds:**

1. `.claude/skills/devshop/check-docs-and-tests/SKILL.md` — orchestrator. Reads range from `review.md`, invokes the two L2 skills, appends Sweep N section. Idempotent on `audited-at`.
2. `.claude/skills/devshop/docs-review/SKILL.md` — NEW skill. Lifts the `docsReviewed` adversarial-review.sh prompt + repo-aware doc catalog into a skill. Judges coverage AND quality. Picks up `Devshop-Docs-Presence-Bypass` trailers and re-judges them.
3. Renames `.claude/skills/devshop/test-review/` → `.claude/skills/devshop/tests-review/` and updates SKILL.md frontmatter (`name: ak-tests-review`). Adds a coverage rubric section to the SKILL.md (lifted from the current `testCoverageProject` adversarial-review.sh prompt). Picks up `Devshop-Tests-Presence-Bypass` trailers.
4. Updates `.claude/skills/devshop/pre-ship/SKILL.md` Gate 5: invokes `/ak-check-docs-and-tests` (the orchestrator) instead of `/ak-test-review`. Renames the gate.
5. Updates `kit/scripts/preship/router-shim.sh` to map the new gate name to the new skill name.
6. Updates references to `/ak-test-review` across docs (mechanical rename to `/ak-tests-review`).
7. Bats coverage: any tests of the router-shim or pre-ship gate-list need updates for the new gate name. New skills don't have bats tests directly (skills aren't bash-testable); the orchestrator's range-computation logic could use a small test if extracted into a script.

**Does NOT yet:**

- Remove per-commit Layer 2 (commit-guard.sh still invokes `docsReviewed`, check-test-coverage-project.sh still invokes `testCoverageProject`). PR-C handles removal.
- Wire into Phase 5.8 (still calls `/ak-tests-review` directly via the renamed-but-existing path). PR-B handles.
- Rename L1 scripts. PR-C handles.

**Validation:**

- Manually invoke `/ak-check-docs-and-tests` over a recent project PR's range; verify a Sweep 1 section lands in `review.md` with sensible findings.
- Run `/ak-pre-ship` on a project branch; verify Gate 5 invokes the new orchestrator.

### PR-B (~4-6h) — Phase 5.8 wiring + collapse the two-file model

**Changes:**

1. `.claude/skills/devshop/build/SKILL.md` Phase 5.8: invokes `/ak-check-docs-and-tests` over the polish range (`<phase-3-sha>..HEAD`) instead of `/ak-test-review`. The skill's idempotence + range computation lets us keep the wiring simple — Phase 5.8 just calls it.
2. Phase 5.8 idempotence rung now reads the latest `## Sweep N` section's `audited-at` from `review.md`, not `test-review-followup.md`.
3. Step 0 resume rung 1a: same change — read latest sweep section from `review.md`.
4. Delete `test-review-followup.md` references across docs. The single `review.md` is the source of truth.
5. Phase 6 audit-comment composition: read `review.md` end-to-end (Gate sections + Sweep sections) instead of two files.
6. Update build/SKILL.md narrative to reflect the new flow: "Gate 5 = first sweep; Phase 5.8 = second sweep."

**Validation:**

- Run `/ak-build` end-to-end on a small project change; verify Phase 5.8 appends Sweep 2 to `review.md` (no `test-review-followup.md` created).

### PR-C (~4-6h) — remove per-commit Layer 2 + symmetry rename + missing devshop docs L1

**Removes (cost savings land here):**

1. `commit-guard.sh:94-187` — the `docs-reviewed` semantic block (per-commit `docsReviewed` adversarial invocation). Replaced by `check-docs-presence-devshop.sh` (NEW).
2. `commit-guard.sh:189-258` — the `release-coverage` semantic block (kit/version-bump `testCoverage` adversarial invocation). Release becomes tag + summary; sweep-time has already audited every commit in the range.
3. `check-test-coverage-project.sh:217-244` — the Layer 2 bypass-reason adversarial invocation. Bypass at L1 records a trailer for sweep-time pickup.
4. `check-docs-freshness-project.sh:258-284` — the Layer 2 bypass-reason adversarial invocation. Same trailer mechanism.
5. `kit/scripts/release.sh` — the `release-coverage` adversarial review path.
6. `kit/scripts/adversarial-review.sh` CHECK_TYPE branches: `docsReviewed`, `testCoverage`, `testCoverageProject`. Their CONVENTIONS_TO_INCLUDE entries also drop.

**Adds:**

1. `kit/scripts/commit-hooks/check-docs-presence-devshop.sh` — NEW. Surface→doc map per roadmap § Devshop Layer 1:

   | Surface path touched                        | Required staged doc                                              |
   | ------------------------------------------- | ---------------------------------------------------------------- |
   | `kit/scripts/**.sh`                         | any `kit/docs/guide/*.md` OR `CLAUDE.md`                         |
   | `kit/scripts/commit-hooks/**`               | `kit/docs/guide/hooks.md`                                        |
   | `kit/scripts/preship/**`                    | `.claude/skills/devshop/pre-ship/SKILL.md` OR `kit/docs/guide/*` |
   | `kit/hooks/**`                              | `kit/docs/guide/hooks.md` OR `CLAUDE.md`                         |
   | `.claude/skills/**/SKILL.md`                | `kit/docs/guide/workflow.md` OR `CLAUDE.md`                      |
   | `template/**` (excl. `.devcontainer/.env*`) | `kit/docs/guide/{architecture,security,ops}.md`                  |
   | `.devcontainer/**` (excl. `.env`)           | `kit/docs/guide/{security,ops}.md`                               |
   | `kit/manifest.txt`                          | `kit/docs/guide/architecture.md`                                 |

   Carve-outs (no firing): `kit/notes/**`, `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/docs/CHANGELOG.md`, `kit/version`, `kit/tests/**`.

   Bypass: `git -c devshop.docsPresenceReason="<why>"` → records trailer.

2. `kit/scripts/commit-hooks/prepare-bypass-trailer.sh` — NEW. Reads bypass git-config flags, writes trailer to commit message. Wired into `prepare-commit-msg` via `kit/hooks/prepare-commit-msg.sh` (or the husky equivalent).

**Renames (symmetry):**

- `check-test-coverage-project.sh` → `check-tests-presence-project.sh`
- `check-test-coverage.sh` → `check-tests-presence-devshop.sh`
- `check-docs-freshness-project.sh` → `check-docs-presence-project.sh`
- Bypass flags rename: `devshop.testCoverageReviewed` → `devshop.testsPresenceReason`; `devshop.docsReviewed` → `devshop.docsPresenceReason`.
- Override files rename: `.devshop-test-coverage-exempt` → `.devshop-tests-presence-exempt`; `.devshop-docs-freshness-exempt` → `.devshop-docs-presence-exempt`.

**Updates:**

1. `kit/hooks/pre-commit.sh` — wire the renamed scripts + new devshop docs presence script.
2. `kit/docs/guide/hooks.md` — document the L1/L2 split, sweep model, bypass-trailer mechanism. Remove docs of removed check-types.
3. `CLAUDE.md` — add the convention block from roadmap § Part 3:

   > **Adversarial Layer 2 reviews fire at sweep moments, not per commit.**
   > Per-commit hooks run only Layer 1: deterministic file-presence math. Layer 2 (sweep skills — `/ak-docs-review`, `/ak-tests-review`) fires when `/ak-check-docs-and-tests` is invoked. ...

4. `kit/scripts/release.sh` — simplify to: bump version + write semantic tag-description summary (drafted by reading recent merge titles).
5. Bats coverage: update existing bats tests for renamed scripts; add bats coverage for `check-docs-presence-devshop.sh` and `prepare-bypass-trailer.sh`.

**Validation:**

- Make a non-trivial devshop commit (e.g., a `kit/scripts/foo.sh` change); verify `check-docs-presence-devshop.sh` blocks until a doc is staged or bypassed; verify bypass produces a trailer; verify a subsequent `/ak-check-docs-and-tests` sweep picks up the trailer and judges it.
- Make a non-trivial project commit; verify the renamed L1 scripts behave correctly; verify no L2 LLM call fires per-commit.
- Run `kit/tests/*.bats` — all pass.

## Open questions deferred to implementation

1. **Gate 5 rename** — pick "docs-and-tests-review", "sweep", or keep "test-review" (despite expanded scope). Decision: rename to `sweep` — matches the conceptual model best (Sweep 1 = Gate 5 = first sweep). To revisit during PR-A.
2. **Skill names final form** — `/ak-tests-review` (plural, matches `/ak-docs-review`) vs keeping `/ak-test-review` (singular, smaller blast radius). Going with **plural** for symmetry; the rename pass is mechanical.
3. **Bypass trailer format** — `Devshop-Tests-Presence-Bypass: <reason>` (proposed) vs `Devshop-Bypass: tests-presence: <reason>` (single trailer name). Going with **per-domain trailer name** so `git interpret-trailers` can match by name without parsing.
4. **Range default for `/ak-check-docs-and-tests` outside `specs/<feature>/`** — when the orchestrator is invoked without a feature dir (e.g., devshop ad-hoc sweep), where does `review.md` live? Proposed: `kit/notes/sweeps/<date>-<short-sha>.md` for devshop ad-hoc sweeps. Resolve in PR-A.
5. **What happens when `/ak-check-docs-and-tests` is invoked on a branch without a `specs/<feature>/` dir at all (project ad-hoc)** — same answer: write to `<git-root>/.devshop-sweeps/<date>-<short-sha>.md`? Or refuse? Resolve in PR-A.

## Out of scope

- Refactoring `adversarial-review.sh` into a domain-agnostic LLM-call runner. The script keeps its CHECK_TYPE switch for the bypass-reason types it still carries. A future v1 entry could revisit.
- Migrating `/ak-test-review`'s test-quality rules into per-domain conventions documents. They stay in the skill's SKILL.md.
- Devshop-side Layer 1 test-coverage tuning. The existing `check-test-coverage.sh` (renamed `check-tests-presence-devshop.sh`) is fine; minor improvements are out of scope.
- Multi-project sweep aggregation. Each repo's `/ak-check-docs-and-tests` invocation is independent.

## Cross-references

- `kit/ROADMAP.md § Move adversarial Layer 2 reviews from per-commit to sweep-time` — original entry; mark as in-progress when PR-A lands; mark shipped when PR-C lands.
- `kit/docs/guide/hooks.md § Adversarial review` — needs a rewrite in PR-C to describe the L1/L2 split + sweep model.
- `kit/docs/guide/conventions.md § Test Presence`, `§ Project Docs Freshness` — sections need a pointer to the sweep model.
- `.claude/skills/devshop/build/SKILL.md § Phase 5.8` — wiring change in PR-B.
- `.claude/skills/devshop/pre-ship/SKILL.md § Gate 5` — wiring change in PR-A.

## Task order (for `/ak-implement`)

PR-A:

1. Create `/ak-check-docs-and-tests` skill scaffold with range computation + idempotence
2. Create `/ak-docs-review` skill (lift docsReviewed prompt from adversarial-review.sh + repo-aware doc catalog)
3. Rename `test-review/` → `tests-review/`; expand SKILL.md with coverage rubric (lift from testCoverageProject prompt); add bypass-trailer harvesting
4. Update `/ak-pre-ship` Gate 5 to invoke orchestrator
5. Update router-shim gate-name mapping
6. Mechanical rename `/ak-test-review` → `/ak-tests-review` across docs
7. Manual validation pass

PR-B: 8. Update `/ak-build` Phase 5.8 to invoke orchestrator 9. Update Phase 5.8 idempotence to read sweep sections from `review.md` 10. Update Step 0 resume rung 1a 11. Update Phase 6 to read `review.md` only 12. Remove `test-review-followup.md` references 13. Manual validation pass

PR-C: 14. Add `prepare-bypass-trailer.sh` + wire into prepare-commit-msg hook 15. Add `check-docs-presence-devshop.sh` with surface→doc map 16. Rename L1 scripts (4 renames) + update bypass-flag and override-file names 17. Update `kit/hooks/pre-commit.sh` for renamed + new scripts 18. Remove L2 invocations from `commit-guard.sh` (docsReviewed + release-coverage blocks) 19. Remove L2 invocations from `check-tests-presence-project.sh` (formerly check-test-coverage-project.sh) 20. Remove L2 invocations from `check-docs-presence-project.sh` (formerly check-docs-freshness-project.sh) 21. Remove `docsReviewed`, `testCoverage`, `testCoverageProject` CHECK_TYPE branches from `adversarial-review.sh` 22. Simplify `release.sh` to tag + summary 23. Update `kit/docs/guide/hooks.md` 24. Add CLAUDE.md sweep convention block 25. Update bats tests for renames; add bats for new scripts 26. Manual validation pass
