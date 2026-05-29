## Gate 5: docs-and-tests-review

- Result: pass

Coverage + adequacy audit (Audit 1). Range: `origin/main...HEAD` over the three review targets.

**Tests — does the bats assertion actually pin the new behavior?** Yes. The new `@test` does two things, and both are load-bearing:
1. Asserts the `core.checkStat=minimal -c core.trustctime=false rebase "$ANCHOR"` form appears in the Phase 1.0 region (anchored `/^### 1\.0:/,/^### 1\.1:/`). This guards against the remedy being deleted or its exact `-c` form being mangled.
2. Asserts the first occurrence of that checkStat form precedes the first `"${GIT_CMD[@]}" merge "$ANCHOR"` occurrence (line-number comparison `checkstat_line -lt merge_line`). This is the ordering invariant — it would FAIL if a future edit reordered the remedies back to merge-first. Re-ran during audit: passes.

The test is region-scoped (awk window), so it pins ordering *within Phase 1.0* rather than relying on whole-file line order — correct construction. The awk anchors match real SKILL.md headings (lines 638 `### 1.0:` / 808 `### 1.1:`). Adequate: it pins exactly the behavior D5 specifies (checkStat present AND before merge).

**Docs — do they reflect what changed?** Yes.
- SKILL.md § 1.0 prose is the change and matches the new ordering (checkStat retry line 87 of the region, merge fallback line 103 — consistent with the test).
- CLAUDE.md footgun entry states the correct first-action (inline `-c` retry, merge only if that still aborts) and the inline-not-repo-global rule, matching the skill.
- spec.md Decisions D1–D5 match the implemented diff exactly.

**Coverage gap?** None for what shipped. The deeper orchestrator-side auto-detect-and-switch mechanization is explicitly out of scope and stays open in `kit/TODOS.md` — correctly deferred, not a coverage hole in this PR.

## Dismissals

None
