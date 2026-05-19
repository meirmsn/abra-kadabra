### [domain: docs] [section: B] [severity: medium]
**File**: kit/ROADMAP.md:927
**What**: "NOT SHIPPED" enumeration cites `.claude/skills/devshop/ak-spec/SKILL.md` as the destination for the `/ak-spec` consultation step; that path does not exist at HEAD. Same dangling path is repeated at `kit/ROADMAP.md:953` inside the preserved historical spec.
**Why**: Stale path in an edit asserting a future-work destination. A future operator picking up the "NOT SHIPPED" item will `Edit` a non-existent file (or create a parallel one and split the canonical skill). Canonical paths in the same repo are `.claude/skills/ak-spec/SKILL.md` (root-level alias) and `.claude/skills/devshop/spec/SKILL.md` (canonical dir, used elsewhere in this repo — `kit/docs/guide/conventions.md:87`, `kit/docs/guide/workflow.md:225`).
**Fix**: Repoint both citations (lines 927 + 953) to `.claude/skills/devshop/spec/SKILL.md` (or `.claude/skills/ak-spec/SKILL.md` if the alias is intentional) — whichever matches the rest of the doc-set's convention.

### [domain: docs] [section: B] [severity: low]
**File**: kit/docs/guide/latency-feedback.md:356
**What**: Test-patterns section says the multi-cycle test "catches the load-bearing functional-setState detail" for `useSubmitFeedback`, but the `useSubmitFeedback` primitive contract above (lines 206-224) never uses the phrase "functional setState" — its load-bearing detail is described as "the `setShowSpinner(false)` inside the cleanup runs as part of the next effect pass / unmount, NOT synchronously." A reader landing on the test-patterns line can't connect the term back to the contract.
**Why**: Stub adequacy — a named "load-bearing detail" must be defined where the contract lives so the test-patterns section can reference it by name. Otherwise the test is the only record of what the detail IS, which inverts the contract→test direction.
**Fix**: Either rename "functional-setState detail" in the test-patterns line to match the contract's actual phrasing ("cleanup-runs-on-next-effect-pass detail"), or add a one-line "functional setState" definition inside the `useSubmitFeedback` contract block at lines 218-224.

### [domain: docs] [section: C] [severity: low]
**File**: kit/ROADMAP.md:935
**What**: The preserved historical-spec lead paragraph still says "co-developed a 4-tier framework" while the same preserved block at line 939 was updated to "5-tier table (A1 / A2 / B / C / D)". Inside one "Spec below preserved for full original context" block, the framework is asserted as both 4-tier and 5-tier.
**Why**: Coherence — the update touched some 4→5 spots inside the preserved block but missed the lead sentence. The preservation marker softens the impact (this block is labeled historical context), but the asymmetric edit creates an internal contradiction a future reader hits in the first sentence they encounter under the section heading.
**Fix**: Either (a) update line 935 from "4-tier framework" to "5-tier framework" so the preserved block is internally consistent, or (b) revert line 939 to its pre-update text if the intent was "preserve the historical spec verbatim, including its original tier count." Option (a) is the cheaper fix and matches the rest of the section's direction.

## Bypass trailers

No Docs-Coverage-Bypass trailers in range.

## CLAUDE.md hygiene (Section E)

Skipped — devshop self-mode (`$GIT_ROOT == /devshop`). Section E runs in project mode only.
