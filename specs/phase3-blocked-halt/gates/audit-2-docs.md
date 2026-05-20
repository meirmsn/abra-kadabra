Clean — no docs findings.

Audit 1 closures verified:

- [closed] kit/docs/guide/hooks.md:251 (was: "One check-type runs at pre-ship time") — now reads "Two check-types fire outside commit-time" with a second bullet for `blockedGateOverride` mirroring the `coreUserStoryNaReason` bullet's shape (invocation surface = `/ak-build § Phase 3 → Phase 4 handoff § Rung 2`, capture target = `specs/<feature>/review.md § Phase 3 → 4 advance log`, names rule #12's four PASS sub-criteria — (a) gate-specific reason, (b) no core-user-story crossing, (c) verifiable follow-up tracker, (d) no § In scope contradiction — and Sonnet routing rationale). Cross-references verified: build SKILL.md line 873/883 carries the named anchor, adversarial-review.sh line 788 carries rule #12 with the four sub-criteria matching verbatim ("matches PR #27" FAIL example aligns with the script's REJECT example).

- [closed] kit/docs/guide/hooks.md:393-396 — Sonnet routing table row now lists `coreUserStoryNaReason` (pre-existing gap surfaced while fixing) and `blockedGateOverride` with per-clause rationale ("waves past a gate that didn't run at all — strongest claim in the surface"). Matches adversarial-review.sh's Sonnet routing list at line 68 verbatim.

- [closed] kit/docs/guide/hooks.md:432 (was: "the only adversarial-review check-type whose surface isn't a git hook") — now reads "Two adversarial-review check-types fire inside `/ak-build` rather than at commit or push time — `testReviewSkipReason` here (Phase 5.8 post-audit halt override) and `blockedGateOverride` (Phase 3 → 4 halt override...)" with cross-reference to `.claude/skills/devshop/build/SKILL.md § Phase 3 → Phase 4 handoff § Rung 2` and a pointer to the `coreUserStoryNaReason` bullet above as the second non-commit-time entry on the pre-ship-time surface.

Section sweep:

- Section A (Coverage): kit/docs/guide/hooks.md touched in response to the prior commit's adversarial-review.sh change — surface→doc rubric satisfied (`kit/scripts/**.sh` → any `kit/docs/guide/*.md`). specs/phase3-blocked-halt/* paths are audit-artifact meta-commits — carve-out applies (kit/docs/CHANGELOG.md / kit/version / kit/tests/** family). No coverage finding.
- Section B (Adequacy): hooks.md edits are substantive (three sections rewritten, not whitespace/reflow). Every cited path + anchor + rule number verified to exist at HEAD. The "matches PR #27" example in the new bullet matches the script's REJECT example verbatim. No stub edits, no dangling references.
- Section C (Coherence): all three Audit 1 coherence breaks closed; no new contradictions introduced. The routing table, the non-commit-time section, and the closing paragraph at line 432 are mutually consistent (all three name `blockedGateOverride` + `testReviewSkipReason` + `coreUserStoryNaReason` as the non-commit-time surface). No renames/deletes in range.
- Section D (Bypass trailers): No `Docs-Coverage-Bypass:` trailers in range. Informational only.
- Section E (CLAUDE.md hygiene): devshop self-mode — skipped per skill spec (CLAUDE.md was not touched in range; devshop-mode hygiene latitude is broader).
