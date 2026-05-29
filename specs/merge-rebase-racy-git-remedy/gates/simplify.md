## Gate 4: simplify

- Result: pass

The diff is a doc reorder plus one bats assertion — minimal surface, appropriately scoped, no over-engineering.

- **Skill prose** — the reorder reuses the existing two code fences (rebase retry / merge fallback) rather than introducing new machinery; the "First remedy / Second remedy" framing is the simplest possible way to express precedence. The inline-`-c`-never-repo-global rule is stated once with rationale and cross-referenced (not duplicated) in the cherry-pick recipe via "same per-command scope rule as the rebase above". No redundancy.
- **Cherry-pick recipe** — the checkStat `-c` form is added as the lead unsticker while the existing `sleep 3` + `git update-index --really-refresh` is kept as the documented deeper fallback. This is additive, not a rewrite; the prior recipe's verified-incident provenance (calibration-and-task-phases, 2026-05-20) is preserved.
- **bats test** — the assertion is two-part (presence in the 1.0–1.1 awk region, then a line-number ordering invariant). The comment block is proportionate and states provenance. The `awk '/^### 1\.0:/,/^### 1\.1:/'` region-scoping is the right altitude: it pins ordering *within the relevant section* rather than the whole file, so an unrelated later `merge "$ANCHOR"` mention can't false-pass the invariant. No simpler form would still catch a merge-first regression.

The CLAUDE.md footgun is a single bullet at the right grain (symptom + first-action + pointer) — not duplicating the full recipe.

## Dismissals

None
