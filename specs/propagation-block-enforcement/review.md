# Review — propagation-block-enforcement

## Audit 1: manual (2026-05-28)

<!-- audited-at: a7c37aaf362983c1353a1b1d02daefd9f99caf57 -->
<!-- range: 8a4869a..a7c37aa -->

findings: high=0 medium=1 low=1

### Docs findings

- [medium] CLAUDE.md:115 + .claude/skills/devshop/merge-devshop/SKILL.md §0.4.5 — both enumerate the squash `prTextHygieneReason` surface as judging only (a)+(b)/skips (c); this PR adds dimension (d) (propagation-block presence) to that surface, leaving both stale. The merge SKILL's "both surfaces move in lockstep" line is now imprecise — (d) is squash-surface-only. Fix: extend both enumerations + soften the lockstep line in this PR.

### Tests findings

- [low] kit/tests/util-adversarial-review-narrowing.bats — the squash-surface `HAS_PROP_BLOCK=yes` branch is never asserted (only the `no` branch). A regression breaking the `^**Existing projects:**` marker for the present-block case would mis-feed NOTE 3 with no test catching it. Fix: add a third case with a body carrying the block, asserting `block: yes`.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-28)

<!-- audited-at: b1cc8d775eba8e5185a36d7126c86cd990575c83 -->
<!-- range: 8a4869a..b1cc8d7 -->

findings: high=0 medium=0 low=0

Re-audit after fixes (b1cc8d7). Both Audit 1 findings resolved: CLAUDE.md +
merge-devshop SKILL.md §0.4.5 now enumerate dimension (d) as squash-surface-only
and the lockstep line is corrected; the three docs (conventions / CLAUDE.md /
merge SKILL) are mutually coherent; the surface + marker regexes are byte-
identical between adversarial-review.sh and propagation-entry.sh. The
`block: yes` narrowing case was added, completing the dimension-(d) branch
matrix (no / N/A / yes). Full bats suite 1519 green.

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
