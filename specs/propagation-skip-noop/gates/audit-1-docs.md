### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/hooks.md:496
**What**: The NOTE-3 description of the squash-surface `prTextHygieneReason` dimension (d) still says it FAILs only "when... the body carries no `**Existing projects:**` block." It was not updated to mention the new present-but-untagged FAIL path this PR added to the same NOTE-3 directive in `adversarial-review.sh` (FAIL when a block IS present but carries no recognized `[auto]`/`[manual]`/`[conditional]` tag).
**Why**: hooks.md is the canonical guide doc for the adversarial-review squash gate. It now describes the gate's FAIL contract incompletely — a reader (or a future audit) consulting it would not learn that an untagged-but-present block also FAILs. conventions.md (touched) and hooks.md (untouched) now disagree on the gate's behavior.
**Fix**: In the NOTE-3 sentence at hooks.md:496, extend the dimension-(d) description: "...and the body carries no `**Existing projects:**` block — OR carries one with no recognized `[auto]`/`[manual]`/`[conditional]` disposition tag (an untagged block falls back to keep-and-warn in propagation-entry.sh and re-admits no-op noise)." Mirror the wording landed in conventions.md § Enforcement layer 1.

### [domain: docs] [section: C] [severity: medium]

**File**: .claude/skills/devshop/release-devshop/SKILL.md:96-100
**What**: Phase 2.5 ("Review PROPAGATION.md") describes `(no manual steps)` as occurring only when a block was _omitted_ ("commits that omitted the block produce `(no manual steps)` even when propagation steps are needed"), and instructs the reviewer: "If the generated entry says `(no manual steps)` but propagation-relevant changes exist, compose the missing entry, edit `PROPAGATION.md`, and re-stage it." Post-change, `(no manual steps)` is ALSO the intended output when all blocks are `[auto]` (the core D3 payoff of this feature).
**Why**: This is a direct contradiction with the new generator behavior. A release reviewer following this checklist for an all-`[auto]` version would see `(no manual steps)`, observe that propagation-relevant changes exist, and (per the instruction) RE-ADD the entries the feature deliberately filtered out — fighting the feature at the exact gate where it matters. The doc that owns the release-time PROPAGATION review was not updated to distinguish "omitted block (real debt)" from "all-`[auto]` (intended no-op)".
**Fix**: Update Phase 2.5 to teach the disposition tag: `(no manual steps)` is legitimate when every block is `[auto]`; it is a coverage gap only when a propagation-surface commit _omitted_ a block (the stderr `WARN: <sha> … silently dropped` is the signal to act on, not the bare `(no manual steps)` line). Point at conventions.md § Existing-Project Migration Block.

### [domain: docs] [section: B] [severity: low]

**File**: .claude/skills/devshop/docs-review/SKILL.md:174
**What**: The Section-A migration-block example still shows the untagged form: `**Existing projects:** <file> is [locked]; init-devshop.sh refreshes on rebuild. No project-side migration needed.` — no leading `[auto]`/`[manual]`/`[conditional]` disposition tag.
**Why**: Cosmetic drift in an illustrative example (not a behavior contract), but the docs-review skill is the very gate that now expects tagged blocks; its own example modeling the old shape is mildly self-inconsistent.
**Fix**: Prefix the example with `[auto] — ` to model the current required shape. Low priority — does not affect any runtime path.

### Bypass trailer audit (docs)

- cd80ecc Docs-Coverage-Bypass: "merge-devshop SKILL.md § 0.3 edit restates the convention; canonical home conventions.md § Existing-Project Migration Block staged in same commit" — VERIFIED. conventions.md IS updated in the same commit (and across the branch); the SKILL.md edit is a faithful restatement of the tag contract. Per-doc NOT-AFFECTED claims (workflow.md, CLAUDE.md) grep-confirmed.
- baa92ed Docs-Coverage-Bypass: "hygiene-gate tag validation; conventions.md § Enforcement layer 1 updated in atomic Task 5 commit on same branch; gate precompute covered by 2 new bats" — VERIFIED. conventions.md § Enforcement layer 1 IS updated by HEAD; bats cases (f)+(g) cover the precompute. NOTE: the bypass scopes coverage to conventions.md but the same gate change left hooks.md § NOTE-3 stale — surfaced as the medium Section-C finding above (the bypass was valid for its named doc; the staleness is in a doc the bypass did not enumerate).
- 7942a2d Docs-Coverage-Bypass: "comment-only generator change confirming all-[auto] collapse; behavior doc lands as Task 5" — VERIFIED. Comment-only; conventions.md updated by HEAD.
- fe297dc Docs-Coverage-Bypass: "generator tag-vocabulary behavior doc lands as Task 5; test surface is the bats cases" — VERIFIED. conventions.md tag vocabulary IS updated by HEAD; 5 new generator bats cases landed in Task 4.
