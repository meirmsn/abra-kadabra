<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: claude-md-hygiene -->
<!-- date: 2026-05-27 -->

# Spec: claude-md-hygiene

**Sources:**

- `kit/ROADMAP.md` § CLAUDE.md hygiene — primary scope
- `kit/docs/guide/claude-md.md` — existing convention doc (routing table, inclusion rule, enforcement layers)
- `kit/notes/claude-md-migration.md` — Wave 1-5 migration record
- `kit/notes/devshop-claude-md-classification.md` — devshop classification worked example
- Prior spec `specs/calibration-and-task-phases/spec.md` — style + structure reference

Mechanical pre-commit gate on CLAUDE.md edits: every addition/modification goes through
the 3-bullet inclusion test at commit time. Reference and convention content gets redirected
to its canonical home. Includes audit sweep of devshop CLAUDE.md regrowth since the May
cleanup.

---

## Product update

### Headline (user-facing)

Changes to the project instructions file now go through an automated routing check — traps stay, everything else moves to its canonical home.

### Detail (team-facing)

New pre-commit gate fires on any CLAUDE.md edit that adds or modifies content. Requires per-entry classification (trap / reference / convention) via adversarial-reviewed bypass trailer. Reference and convention content must be relocated before the commit lands. Includes audit sweep of devshop CLAUDE.md to relocate ~9k of regrowth since the May cleanup, and convention doc update documenting the new mechanical gate.

---

## Decisions (resolved at spec time)

9 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Gate trigger

**Decision:** Any staged edit to CLAUDE.md that adds or modifies content. Pure deletions pass trivially (reducing is always good).

**Rationale:** User direction: "any edit to claude.md to be considered through the approach we have for claude.md." The inclusion test applies to additions and modifications; removals are unconditionally beneficial.

### D2: Hook mechanism

**Decision:** New `check-claude-md-classification.sh` script in `kit/scripts/commit-hooks/`, same pattern as `check-docs-coverage-devshop.sh`.

**Rationale:** Fits existing pre-commit architecture. Deterministic trigger (file detection) → adversarial classification (LLM judgment).

### D3: Classification interface

**Decision:** `git -c devshop.claudeMdClassification="trap: <entry> — <why silent failure>"` bypass trailer. Each addition classified as trap/reference/convention.

**Rationale:** Reuses existing bypass trailer pattern. The adversarial reviewer judges the classification against the inclusion test and routing table.

### D4: Redirect enforcement

**Decision:** Reviewer verifies reference/convention content was relocated to its canonical home (guide doc, area README, code comment) — not still sitting in CLAUDE.md.

**Rationale:** User direction: "if adding something that should not be there and should be somewhere else, then move it to where it should be." The reviewer checks that the relocation actually happened in the same commit.

### D5: Reviewer context

**Decision:** Feed routing table from `kit/docs/guide/claude-md.md` + the staged CLAUDE.md diff hunks + current CLAUDE.md to the reviewer.

**Rationale:** The routing table is the source of truth for destinations. The diff hunks show what changed. The full file shows surrounding context.

### D6: Model routing

**Decision:** Sonnet — classifying content against the inclusion test is judgment, not rule application.

**Rationale:** Same tier as prTextHygieneReason, dismissalLog, and other judgment-heavy check-types.

### D7: Repo scope

**Decision:** Both devshop-self and project modes — single script, wired into both dispatch paths in `pre-commit.sh`.

**Rationale:** The classification logic is universal; routing table handles destination differences between devshop and project contexts.

### D8: Audit sweep

**Decision:** Devshop CLAUDE.md only. Project-side audit is per-project, already tracked for lalista in `kit/TODOS.md`.

**Rationale:** Can't edit project CLAUDE.md from the devshop repo. The audit sweep exercises the same classification logic the gate enforces.

### D9: Convention doc update

**Decision:** Update `kit/docs/guide/claude-md.md` § Enforcement — replace "no mechanical gates" design note (Q6) with the new gate documentation.

**Rationale:** Closes the design gap identified by the 41% regrowth evidence. The convention doc is the canonical reference for the enforcement model.

---

## In scope

- New pre-commit hook script `check-claude-md-classification.sh` that blocks CLAUDE.md additions/modifications unless a `claudeMdClassification` bypass trailer classifies each entry
- New `claudeMdClassification` check-type in `adversarial-review.sh` — Sonnet-routed, fed the routing table from `claude-md.md`, the staged diff hunks, and the full CLAUDE.md; verifies classification accuracy AND that reference/convention relocations actually landed in the same commit
- Wiring in `kit/hooks/pre-commit.sh` for both devshop-self and project (`/workspace`) dispatch paths
- Trailer emission in `append-bypass-trailers.sh` for `Claude-MD-Classification-Bypass:` trailers (audit-time harvesting)
- Audit sweep of devshop CLAUDE.md: reclassify every entry against the inclusion rule + routing table, relocate reference/convention content to canonical homes
- Convention doc update: `kit/docs/guide/claude-md.md` § Enforcement rewritten to document the new mechanical gate (replaces Q6 "no mechanical gates" design note)
- Bats tests for the new hook (trigger conditions, pure-deletion pass-through, bypass acceptance, project-repo firing, devshop-self firing)

## Out of scope

- Project CLAUDE.md audit (per-project, tracked separately for lalista in `kit/TODOS.md`)
- Size caps or section allowlists (D9 rationale: judgment-based hygiene, not gate-based)
- Changes to `/ak-docs-review` Section E (the audit-time reviewer already judges CLAUDE.md hygiene; this feature adds the commit-time gate)

## Files to create/modify

| File | Action | What changes |
|------|--------|-------------|
| `kit/scripts/commit-hooks/check-claude-md-classification.sh` | **create** | New pre-commit hook: detects staged CLAUDE.md adds/mods, blocks unless `claudeMdClassification` bypass flag set, invokes adversarial review |
| `kit/scripts/adversarial-review.sh` | modify | Add `claudeMdClassification` case in context-gathering switch, add to Sonnet model list, add `get_claude_md_guide_to_inline()` for routing-table inlining, add per-check-type rule in prompt |
| `kit/hooks/pre-commit.sh` | modify | Add `check-claude-md-classification.sh` call in both devshop-self and `/devshop` and `/workspace` dispatch paths |
| `kit/scripts/commit-hooks/append-bypass-trailers.sh` | modify | Read `devshop.claudeMdClassification` and append `Claude-MD-Classification:` trailer |
| `kit/docs/guide/claude-md.md` | modify | Rewrite § Enforcement to document the new Layer B mechanical gate; update Q6 rationale; add cross-reference to hooks.md |
| `kit/docs/guide/hooks.md` | modify | Add `check-claude-md-classification.sh` row to the guard table (§ 2 Husky pre-commit) and bypass-flag inventory |
| `CLAUDE.md` | modify | Audit sweep: relocate reference/convention entries to canonical homes, tighten trap entries |
| `kit/tests/guard-claude-md-classification.bats` | **create** | Bats tests for the new hook |

## Tests

Bats test file: `kit/tests/guard-claude-md-classification.bats`

Test cases:

- **PASS: no CLAUDE.md in staged files** — hook exits 0 immediately (no firing)
- **PASS: CLAUDE.md staged but only deletions (no additions/modifications)** — pure deletion pass-through per D1
- **BLOCK: CLAUDE.md staged with additions, no bypass flag** — hook blocks with guidance message
- **PASS: CLAUDE.md staged with additions + bypass flag + adversarial PASS** — bypass accepted, prints classification summary
- **BLOCK: CLAUDE.md staged with additions + bypass flag + adversarial FAIL** — reviewer rejects classification, commit blocked
- **PASS: bypass with empty-reason blocks** — empty `claudeMdClassification` value treated as absent (same pattern as `docsCoverageReason`)
- **PASS: fires in devshop-self mode** — repo with real `kit/` directory triggers the hook
- **PASS: fires in project mode (`/workspace`)** — project repo with symlinked `kit/` triggers the hook
- **carve-out: non-CLAUDE.md files do not fire** — staging unrelated files exits 0
- **PASS: mixed commit with CLAUDE.md deletions only + other files** — deletions-only on CLAUDE.md does not fire even when other files are staged

## Dependencies

- T2 (`claudeMdClassification` check-type) must exist before T1 can call it — but T1 can be developed in parallel since it calls `adversarial-review.sh` by path and the call only fires on adversarial review (bypass flag set), which bats mocks
- T3 (wiring) depends on T1 (script must exist to be called)
- T4 (audit sweep) depends on T1 + T2 + T3 being wired so the gate exercises on real commits during the sweep
- T5 (convention doc) depends on T4 (doc update reflects what actually shipped in the sweep)
- T6 (bats tests) has no hard dependency — tests mock `adversarial-review.sh` — but should come before or alongside T1 for TDD discipline

Recommended order: T6 → T1 + T2 (parallel) → T3 → T4 → T5. However, since T6 tests the script from T1, the practical approach is T1 + T2 + T6 as a single commit (script + check-type + tests), then T3, T4, T5.

## Task order

### Task 1: Hook script + check-type + bats tests
**Files**: `kit/scripts/commit-hooks/check-claude-md-classification.sh` (create), `kit/scripts/adversarial-review.sh` (modify), `kit/scripts/commit-hooks/append-bypass-trailers.sh` (modify), `kit/tests/guard-claude-md-classification.bats` (create)
**Tests**: `kit/tests/guard-claude-md-classification.bats` — all 10 cases listed above
**Depends on**: none
**Description**: Create the hook script, add the `claudeMdClassification` check-type to adversarial-review.sh, add trailer emission, and write the bats tests. Ship as one commit since the script and its tests are inseparable.

The hook script follows the `check-docs-coverage-devshop.sh` pattern:
1. Detect staged files: `git diff --cached --name-only` filtered for `CLAUDE.md`
2. If no CLAUDE.md staged, exit 0
3. Check if the diff is pure deletion: `git diff --cached --diff-filter=d CLAUDE.md` — if the only changes are removals (no `+` lines in the diff excluding `+++` header), exit 0 (D1)
4. Check bypass flag: `git config --get devshop.claudeMdClassification` — if set and non-empty, invoke `adversarial-review.sh claudeMdClassification "$REASON"`. Exit with the reviewer's exit code.
5. If no bypass flag, block with guidance message listing the classification interface

The check-type in adversarial-review.sh:
1. Context gathering: read the staged CLAUDE.md diff hunks (`git diff --cached CLAUDE.md`), read the full current CLAUDE.md from HEAD (`git show HEAD:CLAUDE.md`), detect repo mode (devshop vs project)
2. Inlining: feed the routing table + inclusion rule from `kit/docs/guide/claude-md.md` (new `get_claude_md_guide_to_inline()` helper — reads `## The inclusion rule`, `## Routing table for new content`, and `## The 3-class taxonomy for gotchas` sections)
3. Model: Sonnet (D6) — add to the Sonnet list in `get_model_for_check_type`
4. Prompt rule: the reviewer judges (a) every addition classified correctly as trap/reference/convention per the inclusion rule, (b) reference/convention entries were relocated to the destination named in the routing table within the same commit (verifiable via the staged diff showing the destination file was also touched), (c) trap entries genuinely cause silent wrong work

The trailer in append-bypass-trailers.sh:
1. Read `devshop.claudeMdClassification` via `git config --get`
2. If set, append `Claude-MD-Classification: $REASON` trailer via `git interpret-trailers --in-place`

Scope note: the hook fires in BOTH devshop and project repos. Unlike `check-docs-coverage-devshop.sh` (which is devshop-only), this script checks for CLAUDE.md at the repo root regardless of repo mode. The routing table from `claude-md.md` handles destination differences.

### Task 2: Wire into pre-commit.sh
**Files**: `kit/hooks/pre-commit.sh` (modify)
**Tests**: none (structural wiring; covered by the bats tests from T1 which run the script directly, and by the pre-commit-router.bats if it exists)
**Depends on**: Task 1
**Description**: Add `bash "$SCRIPTS_DIR/commit-hooks/check-claude-md-classification.sh"` to all three dispatch paths in `kit/hooks/pre-commit.sh`:
1. `is_devshop_self_mode` block (worktree/devshop-self) — after `check-docs-coverage-devshop.sh`, before `check-bats-devshop.sh`
2. `/workspace` case — after `check-docs-coverage-project.sh`, before `check-rollback-prose.sh`
3. `/devshop` case — after `check-docs-coverage-devshop.sh`, before `check-bats-devshop.sh`

Placement rationale: the CLAUDE.md classification check is conceptually a docs-coverage concern (where does content belong?), so it runs right after the existing docs-coverage hooks. It runs before bats/commit-guard since those are structural checks that don't depend on CLAUDE.md routing.

### Task 3: Audit sweep of devshop CLAUDE.md
**Files**: `CLAUDE.md` (modify), potentially `kit/docs/guide/*.md` files (modify — destinations for relocated content)
**Tests**: none (content relocation; the gate from T1 + T2 + T3 validates the commit itself)
**Depends on**: Task 1, Task 2
**Description**: Walk every entry in devshop CLAUDE.md and classify against the inclusion rule + routing table (using `kit/notes/devshop-claude-md-classification.md` as the existing worked example). For each entry:

1. **Trap** (silent wrong work) → keep, tighten wording if verbose
2. **Reference** (look-it-up information) → relocate to canonical home (guide doc, area README), delete from CLAUDE.md
3. **Convention** (already documented in a guide) → delete the CLAUDE.md duplicate, keep a one-line pointer if the convention is frequently violated

The commit uses the new gate: `git -c devshop.claudeMdClassification="trap: <entry> — <why>" commit ...` for every surviving entry. This exercises the full pipeline on a real commit.

Focus areas for regrowth since May cleanup:
- § Known Footguns entries that duplicate guide docs
- § Non-Negotiables entries that are loud-failure rules (toolchain catches them)
- Any new entries added since the May cleanup that should have been routed elsewhere

### Task 4: Convention doc update
**Files**: `kit/docs/guide/claude-md.md` (modify), `kit/docs/guide/hooks.md` (modify)
**Tests**: none (documentation)
**Depends on**: Task 3
**Description**: Update `kit/docs/guide/claude-md.md` § Enforcement:

1. Replace the "no mechanical gates" design note under Q6 with documentation of the new Layer B gate:
   - **Layer B — Pre-commit classification gate (`check-claude-md-classification.sh`)**: fires on any staged CLAUDE.md edit that adds or modifies content. Pure deletions pass trivially. Requires per-entry classification via `devshop.claudeMdClassification` bypass flag. The adversarial reviewer (Sonnet) judges classification accuracy against the inclusion rule + routing table and verifies relocations landed in the same commit.
   - Document the bypass interface: `git -c devshop.claudeMdClassification="trap: <entry> — <why silent failure>"` with per-entry classification as trap/reference/convention
   - Document the trailer: `Claude-MD-Classification:` appended by prepare-commit-msg for audit-time harvesting

2. Update Q6 rationale: "Mechanical gates were dropped during planning" → "Layer B mechanical gate added after 41% regrowth evidence showed judgment-only enforcement was insufficient for CLAUDE.md specifically. The gate complements Layer A (write-time router) and Layer C (audit-time reviewer) — Layer A prevents accidental drift from skills; Layer B prevents intentional additions that don't pass the inclusion test; Layer C catches drift that slipped through both."

3. Update `kit/docs/guide/hooks.md`:
   - Add `check-claude-md-classification.sh` row to the § 2 Husky pre-commit guard table
   - Add `claudeMdClassification` to the bypass-flag inventory paragraph
   - Add `Claude-MD-Classification:` to the trailer list in the prepare-commit-msg section

## Gotchas

- **Pure-deletion detection must handle rename-as-delete**: `git diff --cached --diff-filter=d` may not cover all edge cases. Use the hunk-level approach: parse `git diff --cached CLAUDE.md` for `+`-prefixed lines (excluding the `+++` header and `+++ b/CLAUDE.md` line). If zero `+` lines exist, it is pure deletion. This is more robust than relying on `--diff-filter` which operates at the file level.
- **Project repos without `kit/docs/guide/claude-md.md`**: the routing table lives in the devshop repo. In project repos, `kit/` is a symlink to `/devshop/kit/`, so the file is reachable at `$GIT_ROOT/.devshopkit/docs/guide/claude-md.md` (via the `.devshopkit` symlink) or at `/devshop/kit/docs/guide/claude-md.md` directly. The hook should try both paths, falling back to `/devshop/kit/docs/guide/claude-md.md` if the repo-relative path fails.
- **Adversarial review context size**: feeding the full CLAUDE.md (currently ~20k chars for devshop) + routing table (~5k chars) + diff hunks to Sonnet is within budget but watch the 180s commit timeout. If the context is too large, truncate the full CLAUDE.md to the sections surrounding the diff hunks.
- **The audit sweep (T3) must use the new gate for its own commit**: this is the first real exercise of the pipeline. The `claudeMdClassification` bypass reason must classify every surviving entry. If the adversarial reviewer rejects, iterate on the classification until it passes — this validates the reviewer's calibration.
- **Hooks.md guard table format**: the existing table rows use pipe-separated markdown. Match the exact column widths and formatting of existing rows.
- **`append-bypass-trailers.sh` runs under `set -euo pipefail`**: the new `git config --get` call must have `|| true` to handle the unset case without triggering `set -e`.

## Acceptance

1. **Gate fires**: staging a CLAUDE.md edit that adds content blocks the commit with a guidance message when no bypass flag is set
2. **Pure deletions pass**: staging a CLAUDE.md edit that only removes content passes without any gate interaction
3. **Bypass + adversarial PASS**: providing a well-classified `claudeMdClassification` reason that correctly identifies entries as trap/reference/convention AND shows reference/convention relocations in the same commit → commit succeeds
4. **Bypass + adversarial FAIL**: providing a weak/generic/incorrect classification → commit blocked
5. **Both repos**: the gate fires in devshop-self mode, `/devshop` case, and `/workspace` (project) case in `pre-commit.sh`
6. **Trailer recorded**: `Claude-MD-Classification:` trailer appears in the commit message after a bypassed commit
7. **Audit sweep landed**: devshop CLAUDE.md has been reclassified; reference/convention entries relocated to canonical homes; the commit passed the new gate
8. **Convention doc updated**: `claude-md.md` § Enforcement documents the new Layer B gate; Q6 rationale updated; `hooks.md` guard table includes the new row
9. **All bats tests pass**: `bats kit/tests/guard-claude-md-classification.bats` green
10. **Existing bats tests still pass**: `bats kit/tests/` full suite green (no regressions from the adversarial-review.sh and pre-commit.sh modifications)
