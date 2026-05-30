# Audit 1 — Tests Review

Range: `38db19c01e07c34a6c6958372ca8cacd1425ba27..cc016eaeac47141a30fa85927e1b263ced146c5d`
Feature dir: `specs/claude-md-placement-gate`

Scope note (per orchestrator): the placement reviewer-judgment (dimension e) lives in the
`adversarial-review.sh` Sonnet prompt and is exercised by a live LLM call — not unit-testable in
bats. Tests-coverage judgment is focused on the script-level behavior that IS testable:
block-message guidance, pure-deletion pass-through, bypass dispatch, and the prompt-context
assembly (`CLAUDE_MD_SECTIONS`).

Code files in range: `kit/scripts/adversarial-review.sh`,
`kit/scripts/commit-hooks/check-claude-md-classification.sh`. Remaining files are docs/markdown
(`CLAUDE.md`, `kit/FRICTION-LOG.md`, `kit/docs/guide/claude-md.md`, `kit/docs/guide/hooks.md`).

Verification: ran the bats file via the vendored binary —
`./kit/tests/lib/bats-core/bin/bats kit/tests/guard-claude-md-classification.bats` → 11/11 pass,
including the new Test 3b.

Section C (bypass trailers): harvested zero `Tests-Coverage-Bypass:` rows in the range — nothing to judge.

---

### [domain: tests] [section: A] [severity: medium]

**File**: `kit/scripts/adversarial-review.sh:710-731` (new `CLAUDE_MD_SECTIONS` extraction + `=== Existing CLAUDE.md sections at HEAD (placement targets) ===` prompt block)
**What**: The PR adds new pure-bash prompt-context plumbing to the `claudeMdClassification` case — an `awk '/^#{2,3} /'` section-header extraction from `HEAD:CLAUDE.md` and a new `=== Existing CLAUDE.md sections at HEAD (placement targets) ===` block spliced into `$CONTEXT`. This is the data the dimension-(e) reviewer judgment reads. None of it is covered by a test. The added bats test (Test 3b) only exercises the *block-message* path (no-bypass branch), which never reaches the `adversarial-review.sh` CONTEXT assembly.
**Why**: A regression that breaks the section extraction (e.g. the `awk` pattern silently matching nothing, the heredoc dropping the `$CLAUDE_MD_SECTIONS` interpolation, or the block being placed after `$CLAUDE_MD_FULL` and truncated) would ship green. The placement reviewer would then judge "new section vs existing" against an empty/missing section list — silently degrading the gate's core new behavior to a no-op while every test still passes. This is exactly the "test exists alongside source but does not cover the new code path" case the rubric (Section A) calls out.
**Fix**: An established, in-repo pattern already exists for this. `kit/tests/util-adversarial-review-narrowing.bats` mocks `claude` to capture the assembled prompt to `$CAPTURED_PROMPT`, then asserts on context-block content with `grep -q`. Add an analogous test (either to that file or to `guard-claude-md-classification.bats`'s PASS path) that: seeds a `CLAUDE.md` with known `## `/`### ` headers in the test repo, drives `adversarial-review.sh claudeMdClassification "<reason>"` with the captured-prompt mock, and asserts the captured prompt contains `=== Existing CLAUDE.md sections at HEAD (placement targets) ===` AND at least one seeded header line. This pins the awk extraction + heredoc interpolation that the placement judgment depends on.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/guard-claude-md-classification.bats:78-86` (Test 3b)
**What**: Test 3b asserts the block message contains `--partial "placement"` and `--partial "NEW section"`. These two substrings adequately pin the two new *concepts*, but the test does not assert on the changed **usage string** (script line 98), which moved from `trap: <entry> — <why>` to the new `trap → § <section>: <entry> — <why silent>; placement: <extends|NEW> — <why>` shape. The substring `placement` matches it only transitively.
**Why**: The usage line is the copy-paste-able invocation the operator follows. If it regressed back to the old format (or lost the `§ <section>` / `<extends|NEW>` tokens) the message would still contain the word "placement" elsewhere (line 92), so Test 3b would stay green while handing the operator a stale invocation that the adversarial reviewer would then reject — a confusing loop.
**Fix**: Add one assertion targeting the usage shape, e.g. `assert_output --partial "placement: <extends|NEW>"` (or `--partial "trap → §"`). Cheap, and it locks the operator-facing invocation to the new contract.

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/guard-claude-md-classification.bats:90-106` (Test 4, PASS path)
**What**: Test 4 was updated to pass a placement-shaped bypass reason (`trap → § Known Footguns: New Trap … ; placement: extends — …`) but, because it uses the `mock_adversarial_review PASS` stub, it does not (and cannot) verify that the new reason string is actually forwarded into the reviewer prompt. The reason value is passed straight through; a quoting/arg-forwarding regression in `check-claude-md-classification.sh:69` (`bash "$SCRIPTS_DIR/adversarial-review.sh" claudeMdClassification "$REASON"`) would not be caught here.
**Why**: This is the dispatch boundary the gate hinges on. The mock swallows `$@`, so the test proves "PASS verdict ⇒ commit allowed" but not "operator's placement reason reaches the reviewer intact." Low severity because the dispatch line itself is unchanged by this PR (only the reason *content* changed), so it is grandfathered behavior — but the new placement contract increases the value of pinning it.
**Fix**: Optional — fold into the Section-A test above by using a capturing stub (`create_capturing_stub` exists in `helpers/setup.bash`) instead of `mock_adversarial_review`, and assert the captured args contain the placement reason. Covers both the dispatch forwarding and the Section-A prompt-assembly gap in one test.

---

## Summary

- **high**: 0
- **medium**: 1 (untested `CLAUDE_MD_SECTIONS` prompt-context plumbing — the data the new placement dimension reads; an established capture-the-prompt test pattern already exists and was not used)
- **low**: 2 (usage-string not directly asserted; PASS-path dispatch forwarding of the new reason not verified)

Well-covered by the diff: block-message placement guidance (Test 3b — "placement" + "NEW section"),
pure-deletion pass-through (Tests 2 & 10, unchanged and still green), no-bypass BLOCK (Test 3),
adversarial PASS/FAIL dispatch outcomes (Tests 4 & 5), empty-flag handling (Test 6), devshop-self
vs project mode (Tests 7 & 8), non-CLAUDE.md carve-out (Tests 1, 9). The bats suite runs 11/11.

The one medium is not a ship-blocker on its own (it is forward-coverage for a new code path, not a
broken assertion), but it is the highest-value addition: it converts the new placement-data plumbing
from untested to pinned using machinery already in the repo.
