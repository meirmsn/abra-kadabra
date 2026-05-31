findings: high=0 medium=0 low=2

### [domain: docs] [section: A] [severity: low]

**File**: BUILD-LOG.md:7 — merge-devshop-worktree-hooks entry
**What**: The BUILD-LOG quality-gates line reports "1575 passed" for the full bats suite; review.md Gate 2d (pre-ff-merge-gate) reported "1572 passed". The +3 is the three new ff-merge Section G tests (105/106/107) added in a7058e4 — internally consistent, not a defect. Flagged only as a count-drift note across the two audit-trail artifacts.
**Why**: Two committed audit artifacts cite different suite totals for the "same" feature; a future reader cross-referencing could momentarily read it as a discrepancy.
**Fix**: None required — the delta is the three post-Audit-1 ff-merge tests. The BUILD-LOG number (1575) is the correct final count at HEAD. No action.

### [domain: docs] [section: B] [severity: low]

**File**: .claude/skills/devshop/merge-devshop/SKILL.md:1281-1298 — Phase 3 ff-merge gitleaks gate
**What**: The new ff-merge gate prose is thorough (ANCHOR-recompute-before-checkout rationale, `protect --staged` vs `gitleaks git` subcommand split, cwd-pin target, halt contract) and the `--log-opts`/`--redact` flags were empirically verified against gitleaks 8.30.1 (`gitleaks git --help` confirms both). Like the Phase 2 gate, the prose names the shared `.gitleaks.toml` only via "the common git dir" without restating no worktree-local override is possible. Adequate as written — same low as Audit 1's SKILL.md:54-66 note, now also applying to the sibling Phase 3 gate.
**Why**: Minor under-specification of config resolution on the new gate; the squash-path equivalent was judged adequate in Audit 1, so this is parity, not regression.
**Fix**: Optional one-clause add naming root `.gitleaks.toml` as the resolved config. Non-blocking.

Coverage (Section A): the post-Audit-1 delta — the Phase 3 ff-merge gitleaks gate (a7058e4) — is documented in all operator/agent lookup surfaces: SKILL.md Phase 3 (home, with ANCHOR-recompute + halt-and-scrub recovery), the Phase 2 cross-reference comment (SKILL.md:1002-1006, "see Phase 3's ff-merge gitleaks gate"), workflow.md /ak-merge-devshop row (rewritten to state both paths scan — `protect --staged` squash / `gitleaks git` ff-merge), and the security.md:58 "unconditional net" claim. BUILD-LOG entry (dbfaa4d) records both gitleaks paths in its Summary. CLAUDE.md § Parallel work bullet carries the install-dependent + Phase-2-net cross-ref. No firing source-surface lacks a doc edit. The .claude/skills/\*\*/SKILL.md rubric row (→ workflow.md OR CLAUDE.md) is satisfied: both updated.

Adequacy (Section B): the ff-merge gate prose is substantive (not a stub). Named-mechanism empirical verification performed per § Section B: `gitleaks git --log-opts` + `--redact` confirmed present in 8.30.1 (the installed binary) — the doc's claimed invocation is real, not aspirational. The "unconditional / can't reach main even from an off-convention worktree" claim — flagged as an over-claim MEDIUM in Audit 1 because the ff-merge path bypassed scanning — is now TRUE: a7058e4 closes the gap, and the three docs asserting it (SKILL.md:1045-1050, security.md:58, workflow.md row) are accurate at HEAD. The Audit 1 MEDIUM is resolved by code, not by softening prose.

Cross-doc coherence (Section C): stale-prose sweep (`do NOT fire | fire identically | hooks don't fire | All pre-commit hooks fire | claims the opposite`) over CLAUDE.md + kit/docs/ + .claude/skills/devshop/ returns ZERO hits. The two kit/FRICTION-LOG.md hits are the historical entry title (body = Status: shipped (b)+(d)) and a rewritten cross-ref already in install-step-fixed posture — both expected, neither a false-safety-net claim. Cross-ref `CLAUDE.md → SKILL.md § Phase 2` resolves (anchor at SKILL.md:933). No renamed/deleted files in range, so no stale-path sweep needed. SKILL.md Phase 2 ↔ Phase 3 ↔ workflow.md row ↔ security.md ↔ BUILD-LOG all describe one coherent posture: squash path scans via `protect --staged`, ff-merge path scans via `gitleaks git`, both halt before merge — no contradiction.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode (project-mode-only gate). The in-range CLAUDE.md edit (§ Parallel work bullet rewrite + two gstack prettier-stability repairs) is a Known-Footgun posture update + semantically-inert formatting fix; no inclusion-rule regression.
