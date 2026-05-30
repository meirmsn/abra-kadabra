### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/claude-md.md:3
**What**: Top-matter blurb still advertises "the **section allowlist** that bounds its shape" while the body (§ Enforcement + § Rationale Q6) now establishes there is explicitly NO mechanical section allowlist — it was replaced by an adversarial placement judgment at Layer B.
**Why**: Internal phrasing drift — the doc's own summary line describes a mechanism the same doc's body says was dropped. A reader skimming the top-matter forms a wrong mental model (expects a mechanical allowlist) that the body then contradicts.
**Fix**: Rephrase line 3 from "the section allowlist that bounds its shape" to something like "the placement discipline that keeps its section set from sprawling" (or "the adversarial placement judgment that bounds new sections"). Non-load-bearing; safe to defer.

---

**Notes (not findings):**

- Section A (Coverage): clean. Script changes (`kit/scripts/adversarial-review.sh`, `kit/scripts/commit-hooks/check-claude-md-classification.sh`) have matching guide edits (`claude-md.md § Layer B` + `hooks.md` guard row). The propagation-surface-touching `feat` commit (`b10cd23`, touches `kit/scripts/**`) carries a valid `**Existing projects:**` block ("no migration — the gate fires via the already-symlinked kit/hooks/pre-commit.sh; next from-devshop.sh sync propagates it"); verified accurate — neither script is in `kit/manifest.txt`, both fire via the symlinked pre-commit hook. The `15fbec4` friction-log commit carries no migration block but only touches `kit/FRICTION-LOG.md` (a carve-out surface — not propagation-relevant), so none is required. New bats coverage added (`guard-claude-md-classification.bats` Test 3b) for the placement dimension.

- Section B (Adequacy): all edits substantive. Cross-references verified to exist: `hooks.md § Bypass flags + env hatches` (line 466), `claude-md.md § Layer B`, the `### gstack` anchor (line 201) for the rewritten gstack-footgun pointer ("§ gstack below"). The bats assertion `assert_output --partial "NEW section"` matches the check script's printed guidance line. The placement contract is stated consistently across all four touched surfaces (claude-md.md § Layer B, hooks.md guard row, the adversarial-review.sh prompt dimension (e), and the check-script block-message).

- Section C (Coherence): the removed `CLAUDE.md` "Pre-push blocks PR text-hygiene..." footgun is a genuine loud-failure case (husky hook blocks + prints guidance), so relocation out of the silent-failure Footguns list is correct per the inclusion rule; its full contract lives in `hooks.md § 3 — Husky pre-push`, and no dangling reference to the removed entry survives in `CLAUDE.md`, `kit/docs/**`, or `.claude/**`. The corrected worktree claim ("Pre-commit hooks do NOT fire in a fresh worktree") is coherent with the new FRICTION-LOG entry it points to ("Pre-commit hooks don't fire in linked worktrees"). No renames/deletes in range.

- Section D (Bypass trailers): No `Docs-Coverage-Bypass:` trailers in range. (Three `Claude-MD-Classification:` trailers are present and well-formed, but those are Layer-B / Section-E trailers, not Section-D `Docs-Coverage-Bypass:` trailers.)

- Section E (CLAUDE.md hygiene): skipped — this is devshop self-mode ($GIT_ROOT is a linked worktree of /devshop); Section E is project-mode only per the skill contract. The change is itself a CLAUDE.md hygiene improvement (net −3056 bytes: 30261 → 27205; no new entries or sections; pruned/condensed six Footgun entries + removed one loud-failure entry).
