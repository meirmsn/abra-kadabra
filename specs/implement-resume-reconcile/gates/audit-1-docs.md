findings: high=0 medium=0 low=1

- [low] specs/implement-resume-reconcile/spec.md:§Tests case 7 — spec names only 2 usage-error cases (missing feature-dir arg; tasks.md absent), but the implemented bats adds a 3rd (`case 7c: unresolvable base-ref → exit 64`). Tests exceed the spec rather than fall short; the spec's "(exit 64)" header could enumerate the base-ref case for parity. Not a coverage gap — informational drift only.

Coherence + coverage notes (no findings):
- The four changed prose surfaces are mutually consistent: build/SKILL.md Step 0 rung 2 (the call + exit-code routing), build/SKILL.md Phase 2 non-clean-return note, implement/SKILL.md step 11 + Step 4 done-means-committed reaffirmation, and workflow.md tasks.md description all describe the same gate (clean tree + impl-commit-count ≥ done-count) with consistent wording.
- workflow.md's stale claim "per-task status with commit SHAs" was correctly rewritten to "reconciled against actual commits on resume — tasks.md stamps no SHAs"; the false promise that prompted this feature is gone, and a negative bats assertion (Section F) guards its return.
- Script header cross-refs (D1/D3/D4, spec § Behavior) resolve to real spec sections (D3 = clean-tree+count heuristic, D4 = re-enter Phase 2 on mismatch).
- The awk `done` matcher `^\*\*Status\*\*:[ \t]*done` matches exactly the `**Status**: done` marker /ak-implement writes (implement/SKILL.md:119) and this feature's own tasks.md uses — no marker-format drift.
- Step 0 wiring passes `origin/${BASE:-main}`, consistent with the script's `origin/main` default; the `$BASE`-usually-unset-at-Step-0 caveat is documented inline.
- mawk-portability rationale (no `\b`, runtime AWK_BIN selection) is documented in the script header and exercised by a test.
