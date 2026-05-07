# Review — ak-check-docs-and-tests

## Audit 1: manual (2026-05-07)

<!-- audited-at: a2e1f34a9f60a2862a76fbe4420b14e38fc642ca -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=7 low=7

### Docs findings

- [medium] kit/docs/guide/conventions.md:498 — stale `check-test-coverage` (singular, pre-PR-C name) in untouched § Kit Testing paragraph; survives the rest of the rename sweep that updated lines 503/516/542 in the same file. Bypass-body drift-sweep attestation falsely claimed "every file uses the renamed paths."
- [medium] kit/docs/guide/conventions.md:498-500 — § Kit Testing's "Two enforcement layers" still describes `Per-release: Semantic test coverage review via adversarial agent` as live behavior. PR-C explicitly removed this. Internal contradiction with new release.sh comment + new CLAUDE.md Non-Negotiables bullet.
- [medium] CLAUDE.md:65 — pre-commit-guards parenthetical still names `docs drift, release-coverage`. Always-loaded surface contradicts itself within same file (Non-Negotiables bullet at line 90 correctly describes post-PR-C model).
- [medium] kit/docs/guide/architecture.md:92 — same stale `docs drift, release-coverage` parenthetical. PR-C touched line 179 in this file but missed the duplicate at :92.
- [medium] .claude/skills/devshop/release-devshop/SKILL.md:88,92 — still documents retired `release-coverage` check-type and `releaseReviewed` bypass. Operator running `/ak-release-devshop` would follow stale instructions.
- [medium] kit/docs/guide/conventions.md:381 — broken cross-ref `.claude/skills/devshop/test-review/SKILL.md § Wrapper API design` (skill dir renamed to `tests-review/` in PR-A).
- [medium] kit/docs/guide/conventions.md:466 — same broken cross-ref `.claude/skills/devshop/test-review/SKILL.md § Shape-only assertions`.
- [low] .claude/skills/devshop/build/SKILL.md:801 — `check-test-coverage-project.sh` (pre-PR-C name) in the new Phase 5.8 paragraph PR-B added. Self-introduced regression.
- [low] .claude/skills/devshop/new-project/SKILL.md:918 — `check-docs-freshness-project.sh` (pre-PR-C name) in untouched skill file. Pre-existing drift surfaced by rename sweep; broader than PR-C scope.
- [low] PR-C commit body Docs-Coverage-Bypass NOT-AFFECTED #9 (FAQ.md) — "0 hits" attestation overstated; FAQ.md does contain `/ak-check-docs-and-tests` (in the new audit findings paragraph). Substantive position holds (no Layer 1/2 enumeration). Attestation-quality nit.
- [low] PR-C commit body Docs-Coverage-Bypass NOT-AFFECTED #10 (supabase-ssr-boilerplate.md) — same shape; "0 hits" overstated due to rename catch-up edits flowing into the file. Substantive position holds.
- [low] PR-C commit body Docs-Coverage-Bypass AFFECTED #7 (security.md) — names section "§ Locked files" but actual heading is `## Security-Critical Files`. In-diff phrases verify; section anchor mismatch only.

### Tests findings

- [low] kit/tests/util-tests-review.bats:19 (and same pattern at util-docs-review.bats:10, util-check-docs-and-tests.bats:11, util-build-phase58-audit-parser.bats:28) — defensive `[ -f "$SKILL_FILE" ] || skip "..."` in setup() converts a SKILL.md rename regression into invisible skips (the precise regression these bats are meant to catch). Per-PR-A scope; recommend converting `skip` → `fail` in a follow-up.

### Bypass trailer audit

- a2e1f34 Docs-Coverage-Bypass — VERIFIED. All 7 AFFECTED-doc named-phrase claims grep-verified in the staged diff. Three attestation-quality nits classified as low findings above (D-section).
- a2e1f34 Tests-Coverage-Bypass — VERIFIED. util-bypass-trailers.bats (12 tests, 147 lines) covers append-bypass-trailers.sh substantively; guard-docs-coverage-devshop.bats (29 tests, 299 lines) covers check-docs-coverage-devshop.sh substantively. Both new scripts ship with paired bats.
