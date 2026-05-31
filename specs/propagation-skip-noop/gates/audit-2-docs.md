high=0 medium=0 low=1

### Docs findings

- [low] BUILD-LOG.md:107 — the entry asserts "Gate 2d full bats green (1586 passed, 0 failed)"; this re-audit only re-ran the two changed bats files (59 ok), not the full 1586-case suite, so the count is a point-in-time claim from the Phase 3 gate run rather than one verified at this HEAD. Non-blocking: the two files the feature touches are green, and the BUILD-LOG records the Phase 3 evidence faithfully.

### Coherence verification (Audit-1 mediums re-checked)

- Audit-1 medium (hooks.md NOTE-3 stale) — RESOLVED by 424edac. hooks.md:496 now documents the TWO-case FAIL (missing-block + present-but-untagged), names the `HAS_PROP_BLOCK` + `PROP_BLOCK_TAGGED` precompute, and the `(yes/no/n/a)` value set matches the script's emitted `PROP_BLOCK_TAGGED=n/a` (after 86c949b's n-a→n/a fix). conventions.md § Enforcement layer 1 and hooks.md now agree on the gate contract.
- Audit-1 medium (release-devshop SKILL.md Phase 2.5 treated `(no manual steps)` as omitted-block debt) — RESOLVED by 424edac. Phase 2.5 now states `(no manual steps)` is "a valid, correct end state" for all-`[auto]` ranges and adds "Do NOT re-add entries for `[auto]`-tagged changes; that would fight the filter" — the prior fight-the-feature footgun is removed.
- Audit-1 low (docs-review SKILL.md example modeled the untagged shape) — RESOLVED by 424edac. The example now carries `[auto] —` and the prose adds the tag requirement + squash-gate-FAIL note.
- New doc surfaces this range: conventions.md § Enforcement layer 2 documents the one-block-per-commit rule + the exact multi-block WARN string the generator emits; PROPAGATION.md header documents the tag vocabulary; v1.37.0 backfill collapsed 11 no-op bullets to the single `(conditional)` CSP entry + a trailing "all other v1.37.0 changes auto-propagate" line — consistent with the generator's filter behavior. All coherent.

### Bypass trailer audit

- 86c949b Docs-Coverage-Bypass: "Cosmetic internal-value fix (n-a → n/a); AFFECTED hooks.md already documents the correct n/a form; NOT-AFFECTED set grep-verified" — VERIFIED (hooks.md:496 already shows `(yes/no/n/a)`; code now agrees; purely a value-string alignment, no behavior change)
- 424edac Docs-Coverage-Bypass: "Prose-only doc-consistency fix; the two SKILL.md edits ARE docs; paired guide docs (conventions.md, hooks.md) staged same commit; NOT-AFFECTED catalog grep-verified" — VERIFIED (conventions.md + hooks.md both carry the contract; skills-surface gate's workflow.md/CLAUDE.md correctly n/a — the contract lives in conventions.md+hooks.md)
