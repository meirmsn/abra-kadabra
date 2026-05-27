## Gate 5: docs-and-tests-review

- Result: findings (1) pending
- findings: high=0 medium=1 low=0

### Medium-1: CLAUDE.md claim "per-commit hooks run only Layer 1 (deterministic checks)" is inaccurate

**File:** `CLAUDE.md` line 93

**Claim:** "Per-commit hooks run only Layer 1 (deterministic checks)."

**Reality:** Multiple pre-commit hooks make per-commit adversarial LLM calls (Sonnet/Haiku) — this was true before the branch (`check-manifest.sh` calls `adversarial-review.sh manifestReviewed`; `check-exempt-additions.sh` calls `adversarial-review.sh exemptAddition`), and the new `check-claude-md-classification.sh` adds another. The statement was already inaccurate on main (the original text read "deterministic file-existence math"), and the audit sweep trimmed the paragraph (removing detail about Layer 2 audit moments) but kept the inaccurate core claim.

The `hooks.md` guard table correctly classifies the new gate as **Semantic** (same classification as `check-manifest.sh` and `check-exempt-additions.sh`), so hooks.md is internally consistent. The inconsistency is CLAUDE.md vs hooks.md.

**Suggested fix:** Replace "Per-commit hooks run only Layer 1 (deterministic checks)" with something like "Per-commit hooks run Layer 1 (deterministic checks) plus semantic gates for manifests, exemptions, and CLAUDE.md classification" — or simply remove the claim and let the pointer to hooks.md carry the detail.

**Severity:** Medium. The claim doesn't cause silent wrong work on its own (the hooks fire regardless of what CLAUDE.md says), but it creates a false mental model that could lead a future session to skip adversarial-review context when reasoning about commit-time behavior.

---

### Docs review summary

- **`kit/docs/guide/claude-md.md`** accurately describes the new Layer B gate: trigger (additions/modifications), pure-deletion pass-through, bypass interface, adversarial reviewer (Sonnet), trailer emission, and the three layers compose correctly. Q6 rationale update is accurate and well-motivated (41% regrowth evidence). The "Durable justification artifacts" section correctly distinguishes the new `Claude-MD-Classification:` trailer from the legacy `CLAUDE-MD-Bypass:` trailer.

- **`kit/docs/guide/hooks.md`** guard table entry is correct: classified as Semantic, both repos, correct bypass flag and trailer documented. The tree diagram (ASCII art near line 77) includes the new check in the right position. The bypass-flag inventory paragraph (line 190) and adversarial-reviewed flag list (line 281) both include `claudeMdClassification`. The model-routing table (line 479) correctly lists `claudeMdClassification` in the Sonnet tier with rationale. The `prepare-commit-msg` section (line 92) is updated. All five hooks.md touch-points are consistent.

- **CLAUDE.md audit sweep** (commit `07ed9d6`): Three changes made — (1) deleted stale `docsReviewed` entry (check-type removed in PR-C, confirmed no longer live in `adversarial-review.sh`), (2) deleted `/ak-pre-ship Dismissals` entry (convention fully documented in `hooks.md` Dismissal Log section, confirmed at line 400+), (3) condensed `localTestSkipReason` entry to one-liner with pointer. All three are correct classifications — the removed entries were convention/reference content, not silent-failure traps.

### Tests review summary

- **10 bats tests** all pass. They cover the spec's 10 acceptance-criterion test cases: no-CLAUDE.md (T1), pure-deletion (T2), block-without-bypass (T3), bypass+PASS (T4), bypass+FAIL (T5), empty-bypass-blocks (T6), devshop-self-mode (T7), project-mode (T8), non-CLAUDE.md-carveout (T9), mixed-deletions+other-files (T10).

- **pre-commit-router.bats** updated correctly — `check-claude-md-classification.sh` stub added to setup, and three route-verification tests (project, devshop, devshop-self) assert the stub was called.

- **Edge cases not covered (acceptable):** (a) CLAUDE.md doesn't exist yet (first creation) — the hook would detect additions and block, which is correct behavior; a test would confirm but the code path is clear. (b) Very large diffs — bounded by the 180s adversarial-review timeout, not a test concern. (c) Concurrent edits — git's index locking handles this at a lower layer. These are low-risk gaps and not worth blocking on.

## Dismissals

None
