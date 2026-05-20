# Review — plan-close-shipped-rows

## Audit 1: manual (2026-05-20)

<!-- audited-at: 430cfd6b39c427442d6ba586aa0ce94a2706d7c4 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] PLAN.md:72 — `home-os-skill-polish-batch` Hook now ~166 chars, exceeding the ≤120-char cap PLAN.md:17 documents. Caused by folding the bottom-section absorbed-bundle note (sub-bundle counts + 3rd-project-trigger marker + "do not re-split") into the Hook. The cap is author-discretion ("Hook stays ≤ 120 chars"), not a hard rule; consistency nit only. Options: tighten the Hook (lose the parenthetical security gloss + "do not re-split"), relax the cap in PLAN.md:17 for absorbed-bundle rows, or no-action — all three are defensible.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
