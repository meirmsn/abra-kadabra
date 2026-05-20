# Audit 3 — Docs Review

**Range**: `2c076fa..HEAD` (single commit: `fe4459a`)
**Feature-dir**: `specs/convention-housekeeping`
**Mode**: devshop self-mode (`$GIT_ROOT == /devshop`)
**Bypass trailers in range**: none (Docs-Coverage-Bypass + CLAUDE-MD-Bypass both empty)

---

## Findings

### [domain: docs] [section: C] [severity: low]
**File**: kit/ROADMAP.md:939
**What**: Stale reference to `kit/scripts/commit-hooks/check-docs-freshness-project.sh` (renamed to `check-docs-coverage-project.sh` in PR-C). The (E6) gen #11 entry under `kit/ROADMAP.md § PR-C` describes the still-open scaffold reorder using the pre-rename script name.
**Why**: Pre-existing drift surfaced by this commit's rename sweep across template files. The closure commit `fe4459a` scoped its rename ride-along strictly to template-side files (per the audit-2 enumeration); the kit/ROADMAP.md instance is operational doc, not template. Functional impact is zero (the script name is documented, never executed from prose), but a future operator grepping for the script name to triage the E6 entry will miss the canonical hit. Sibling stale refs in `kit/notes/**` (`projects/home-os.md:70`, `roadmap/adversarial-review-doc-inlining.md`, `roadmap/lalista-launch.md:105`) are carve-outs per the Section A rubric (`kit/notes/**` does not fire coverage); `BUILD-LOG.md` entries are historical record and intentionally untouched.
**Fix**: Single-line `sed` in `kit/ROADMAP.md:939` swapping `check-docs-freshness-project.sh` → `check-docs-coverage-project.sh`. Defer to a separate housekeeping commit or piggyback on the next ROADMAP edit.

---

## Section summary

- **A (Coverage)**: PASS. All 4 touched files map cleanly to their required doc updates per the devshop rubric:
  - `kit/tests/guard-docs-coverage-project.bats` (test revert) — falls under `kit/tests/**` carve-out (no firing).
  - `kit/docs/guide/conventions.md` (trigger-map carve-out + 2 stub headings) — self-touching reference doc.
  - `template/METRICS.md` + `template/.devshop-docs-freshness-exempt` (script rename) — `template/**` → `kit/docs/guide/{architecture,security,ops}.md` rubric is satisfied by the prose alignment with the canonical script name already documented in `kit/docs/guide/conventions.md:686` and `kit/docs/guide/hooks.md:150`.

- **B (Adequacy)**: PASS. All three substantive edits are accurate:
  - Trigger-map carve-out at `conventions.md:695` cites paths (`apps/`, `packages/`, `supabase/functions/`) that match the script's actual processing at `check-docs-coverage-project.sh:99-140`. Parallel to the existing carve-out note at `hooks.md:150` (different prose, same semantics — no contradiction).
  - Stub headings at `conventions.md:412` (`## Confidence Calibration`) and `:416` (`## TODO Protocol`) close dangling ToC self-anchors at `conventions.md:28-29` left by the prior `e0d5adc` deletion. The stubs match the established sibling pattern (Supabase Hardening Defaults at `:396`, Wrapper API design at `:404`, Database queries at `:408`, etc.) of relocated sections pointing forward at their canonical home. Cited anchors `/devshop/CLAUDE.md#confidence-calibration` and `#todo-protocol` resolve correctly to `CLAUDE.md` lines 129 and 151 (Markdown auto-anchor generation is heading-level-agnostic, so the H3 targets in CLAUDE.md match the H2 stub references).
  - Script rename in `template/METRICS.md:3` + `template/.devshop-docs-freshness-exempt:1` cites the canonical script name at `kit/scripts/commit-hooks/check-docs-coverage-project.sh` (verified to exist).

- **C (Cross-doc coherence)**: 1 LOW finding (above). No contradictions between touched docs and the broader reference set. Carve-out prose in `conventions.md:695` and `hooks.md:150` describes the same script behavior with compatible semantics. Script-rename sweep is internally consistent in the touched files; only the operational-doc `kit/ROADMAP.md:939` lags.

- **D (Bypass trailer audit)**: No `Docs-Coverage-Bypass:` trailers in range. No `CLAUDE-MD-Bypass:` trailers in range. Pass.

- **E (CLAUDE.md hygiene)**: SKIP — devshop self-mode (Section E is project-mode-only per the skill spec).

---

## Outcome

`high=0 medium=0 low=1`

The closure commit `fe4459a` correctly unwinds the three Audit 2 findings it claimed to address:

1. **HIGH (bats tightener)** — reverted; 30/30 test suite passing (per commit message verification trail).
2. **MEDIUM (trigger-map second-location)** — carve-out parenthetical added at `conventions.md:695`, matching the prior `hooks.md:150` fix.
3. **MEDIUM (ToC dangling anchors)** — stub headings added at `conventions.md:412 + :416`, matching the sibling pattern of 4 prior relocated sections.
4. **LOW (template-side script rename)** — both sibling locations swept (`template/METRICS.md:3` + `template/.devshop-docs-freshness-exempt:1`).

The lone new LOW finding (stale script name in `kit/ROADMAP.md:939`) is pre-existing drift surfaced by the rename sweep — outside the audit-2 enumeration's template-only scope. Not a regression. Acceptable to defer to a separate housekeeping pass.

Audit 2's flagged issues are resolved; no new drift introduced.
