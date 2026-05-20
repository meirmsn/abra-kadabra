<!-- audited-at: 900c572 -->
<!-- range: origin/main..HEAD -->
<!-- mode: devshop self-mode (GIT_ROOT=/devshop) -->

### [domain: docs] [section: B] [severity: high]
**File**: `.claude/skills/devshop/merge-devshop/SKILL.md`:934-942
**What**: The "DCG `-f` pattern-match constraint" paragraph asserts that DCG's `core.git:push-force-short` rule "pattern-matches on the literal `-f` / `--force` substrings and rejects compound commands that chain them" — empirically false against the installed binary (dcg 0.4.0).
**Why**: Direct verification (`dcg test 'git submodule deinit -f --all && git worktree remove --force /tmp/foo'`) returns ALLOWED. The actual `core.git:push-force-short` rule matches `git push -f` / `git push --force` substrings, not generic `-f` / `--force`. The named mechanism for splitting the teardown into separate Bash calls does not exist as described — a future operator (or maintainer) reading this paragraph will internalize a wrong mental model of DCG's pattern surface and may design future workarounds against rules that don't match what they think. The split-teardown DISCIPLINE may still be defensible (halt-point granularity, readable, idempotent recovery if Step 2 fails mid-flight), but the cited RATIONALE is wrong. Adequacy: a named-section claim ("`core.git:push-force-short` rule pattern-matches `-f` / `--force`") that doesn't survive a `dcg test` against the installed binary.
**Fix**: Either (a) re-verify against `dcg test`/`dcg explain` and replace the rationale with the actual reason the split is desirable (e.g., "Step 2's `git worktree remove --force` can fail independently of Step 1's `submodule deinit` — running them as separate Bash calls preserves the partial-success state for operator recovery; collapsing into one chained command makes the failure mode opaque"); or (b) if the DCG rule scope was tightened recently and the SKILL prose is fossilized from a previous broader rule, name the historical context explicitly ("DCG ≤ vX.Y matched `-f` substrings; current dcg 0.4.0 narrowed to `push -f` / `push --force` — discipline retained because […]"). Same correction applies to the new bats assertion at `kit/tests/util-ak-merge-devshop.bats:431-438` which pins the same wrong rationale.

### [domain: docs] [section: C] [severity: medium]
**File**: `kit/docs/guide/workflow.md`:477 (skill-map table row for `/ak-merge-devshop`)
**What**: The skill-map row still describes Phase 2 as `git rebase origin/main → git reset --soft origin/main → git commit -F`. The SKILL changed in this audit window: Phase 2 now anchor-selects between `origin/main` and local `main` via `git rev-list --count origin/main..main` and runs `$GIT_CMD rebase "$ANCHOR"` / `$GIT_CMD reset --soft "$ANCHOR"`.
**Why**: The skill-map table is the **discovery surface** an operator reads when asking "what does `/ak-merge-devshop` do?" — it currently asserts a literal `origin/main` anchor that the SKILL no longer uses unconditionally. The row also doesn't mention the medium-severity interactive halt or the split-teardown shape. Cross-doc coherence: the discovery doc contradicts the implementation doc on a load-bearing surface (the anchor choice is what made the home-os-skill-polish-batch merge fail without this hardening). Coverage rubric: source change touched `.claude/skills/**/SKILL.md`; the rubric expects `kit/docs/guide/workflow.md` OR `CLAUDE.md`; the skill-map row's STALENESS is the doc-side gap.
**Fix**: Update the row to reflect the new shape — either (a) one-sentence callout ("Phase 2 anchor-selects between `origin/main` and local `main` when local is ahead of origin/main; Phase 1 interactively pauses on medium-severity audit findings; Phase 4.2 splits the worktree teardown into separate Bash calls") or (b) trim the row to a high-level pointer to the SKILL with the worked-incident note and let the SKILL own the mechanics.

### [domain: docs] [section: B] [severity: low]
**File**: `.claude/skills/devshop/merge-devshop/SKILL.md`:644-647
**What**: The Phase 1 medium-halt prompt references `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` as the auto-mode bypass, claimed to "record the override in `review.md` as a bypass trailer."
**Why**: Adequacy — bypass-trailer convention is documented in `kit/docs/guide/conventions.md § Bypass trailers` and the existing inventory in `kit/docs/guide/hooks.md § Bypass flags + env hatches`, but neither doc currently registers `DEVSHOP_AUDIT_MEDIUM_POLICY` as a known env hatch. The SKILL introduces the bypass without lifting the registration. Future operators searching "what env vars bypass audit gates?" won't find this one in the canonical inventory. Severity low because the SKILL prose IS the authoritative source for `/ak-merge-devshop`-scoped bypasses; the inventory drift is a coherence gap, not a load-bearing mis-description.
**Fix**: Add a one-line entry to `kit/docs/guide/hooks.md § Bypass flags + env hatches` (or to `conventions.md § Bypass trailers`) mentioning `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` with a pointer back to the SKILL. Can be folded into the next devshop guide-hygiene commit, not blocking on this audit.

### [section: A] Coverage — no further findings
Surface touched: `.claude/skills/**/SKILL.md` (2 files) + `kit/tests/**` (carve-out, no firing). Coverage rubric expects `kit/docs/guide/workflow.md` OR `CLAUDE.md` for the SKILL touch; neither was staged, BUT the existing pointers from `CLAUDE.md § Two repos` (lines 62, 65, 69) and `workflow.md § skill-map` already route operators to the SKILL as the canonical source. The skill-map staleness is captured under Section C above; no separate Section A finding.

### [section: D] Bypass trailers
`git log --format='%H%n%B%n---' origin/main..HEAD | awk '/^Docs-Coverage-Bypass:/'` → empty. No `Docs-Coverage-Bypass:` trailers in range. No `CLAUDE-MD-Bypass:` trailers in range.

### [section: E] CLAUDE.md hygiene
Skipped — devshop self-mode (Section E is project-mode-only).

### Summary

- **Coverage (Section A)**: clean (skill-map row staleness routed to Section C as a coherence gap)
- **Adequacy (Section B)**: 1 high (DCG `-f` pattern-match claim is empirically false), 1 low (`DEVSHOP_AUDIT_MEDIUM_POLICY` not registered in canonical bypass inventory)
- **Coherence (Section C)**: 1 medium (`workflow.md § skill-map` row contradicts the new Phase 2/1/4.2 mechanics)
- **Bypass trailers (Section D)**: no trailers in range
- **CLAUDE.md hygiene (Section E)**: skipped (devshop self-mode)

Totals: high=1 medium=1 low=1
