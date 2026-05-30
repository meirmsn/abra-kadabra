## Tests Review — Audit 1

**Range**: `cc48f91a68444b874ab6b7ade77dc6fd3cf44033..8e0e1a0ea32805164c23214debe6a420630e34b6`

### Scope

Range touches 6 files. Only one is executable code: `kit/scripts/adversarial-review.sh`.
The rest are markdown — CLAUDE.md, kit/docs/guide/claude-md.md, kit/ROADMAP.md,
kit/TODOS.md (docs/trackers) and specs/claude-md-condense/PLAN.md (spec artifact) —
trivial for test-coverage purposes (no source behavior to exercise).

The sole code change adds rubric dimension **(f) "Reachability split"** to the
`claudeMdClassification` adversarial check-type: ~14 lines of prose appended to the
`RUBRIC` heredoc (the LLM reviewer prompt) plus a one-clause amendment to the
default-REJECT rationale paragraph. No new shell branch, no new variable plumbing —
the `claudeMdClassification` prompt assembly (`CLAUDE_MD_SECTIONS` awk extraction,
heredoc interpolation, reason forwarding) is unchanged.

Rubric (f) is reviewer-prompt prose evaluated by a live Sonnet call, so its
*judging behavior* is correctly NOT unit-testable in bats. What IS testable — and
what the existing suite already pins for the prompt-plumbing path — is that the
prompt is assembled correctly; the existing capture-the-prompt test
(`util-adversarial-review-narrowing.bats`, the "claudeMdClassification: prompt
carries the existing-section list + forwards the reason" test added in the prior
placement-gate work) already covers `CLAUDE_MD_SECTIONS` and reason forwarding.

### Section A — Coverage of new behavior

The devshop rubric maps `kit/scripts/**.sh` changes → matching `.bats` under
`kit/tests/`. The script already has matching coverage:
`util-adversarial-review-narrowing.bats` (24 tests, all green) plus
`guard-claude-md-classification.bats` exercise the `claudeMdClassification` path.
The (f) addition is reviewer-prompt prose, not a new code path or failure mode, so
no NEW test file is required by Section A — the rubric's "test the new behavior"
intent is satisfied by the live reviewer that evaluates (f) at audit time. The only
unit-testable surface of the change (presence of the (f) line in the assembled
prompt) is addressed as a low finding below.

### Section B — Test quality

No project-side patterns (weak assertions, RLS, shape-only, WebKit race, realtime,
wrapper-boundary, Zod-boundary, skipped-tests) apply — the diff adds no `.ts`/`.tsx`/
`.spec` tests and no application code. The existing bats assertions on the
claudeMdClassification path are specific (scoped `awk`-extracted block greps, not
whole-prompt greps — see the deliberate comment at narrowing.bats:471-473 explaining
why the section-block scoping avoids a false-pass against the full-file copy). Quality
is sound.

### Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in range. Zero rows — legitimate.

### Findings

#### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/util-adversarial-review-narrowing.bats:475` (test "claudeMdClassification: prompt carries the existing-section list + forwards the reason")
**What**: The capture-the-prompt test pins the existing-section list header and the forwarded reason, but does NOT assert the rubric prose itself reaches the prompt. With dimension (f) now added, there is no test pinning that the rubric (a)-(f) text — including the new `Reachability split` line — is actually present in the assembled prompt. The prompt-plumbing test would stay green even if a future edit dropped or mangled the rubric body.
**Why**: A later CLAUDE.md-condense pass (this very feature's theme is trimming prose) could accidentally delete or truncate the (f) rubric lines from the heredoc and ship green — the gate would silently degrade to judging without the reachability-split dimension. This is the same regression class the existing section-list assertion guards against for the placement dimension.
**Fix**: Add one assertion to the existing claudeMdClassification capture test — e.g. `grep -q "Reachability split" "$CAPTURED_PROMPT"` (and optionally `grep -q "would this detail bite before the operator opened" "$CAPTURED_PROMPT"` to pin the operative test sentence). One line in an existing test; no new file. Low severity: the rubric is reviewer-facing prose, the live Sonnet call is the real evaluator of (f), and the prompt-assembly path is already proven to work — this only adds a cheap regression tripwire on the rubric body.

### Adequacy of existing coverage

The `claudeMdClassification` path remains adequately exercised: the narrowing suite
runs 24/24 green (confirmed this session via the vendored bats runner), covering
prompt assembly, section-list extraction, reason forwarding, and every surviving
check-type's dispatch. The (f) addition needs no new bats test — extending the one
existing capture test fully closes the only (low) gap. A standalone new test would be
over-engineering for a ~14-line prompt-prose change. Note: `kit/tests/` contains no
`util-adversarial-review.bats` (no such "main" file exists); the relevant coverage
lives in `util-adversarial-review-narrowing.bats` + `guard-claude-md-classification.bats`.

### Summary

high=0 medium=0 low=1
