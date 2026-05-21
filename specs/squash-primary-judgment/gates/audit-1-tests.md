# Audit 1 — Tests Review

**Range**: `origin/main..HEAD`
**Commits**: `8027d02` (fix + tests), `41ee2d7` (docs only)
**Feature dir**: `specs/squash-primary-judgment`

## Scope

Source changes audited:

- `kit/scripts/adversarial-review.sh` — added NOTE 1 (primary-judgment / procedural-marker disclaimer) and renamed prior NOTE → NOTE 2 (surface-shape) in the squash-surface CONTEXT block (lines 345-366).
- `.claude/skills/devshop/merge-devshop/SKILL.md` + `kit/docs/guide/hooks.md` — doc-only.

Test changes audited:

- `kit/tests/util-adversarial-review-narrowing.bats` — extended the existing happy-path test (`prTextHygieneReason squash-surface: reads from DEVSHOP_HYGIENE_MESSAGE_FILE + reaches claude`) with 4 new grep assertions for NOTE 1 distinctive phrases + updated the NOTE → NOTE 2 comment.

Doc-only commit `41ee2d7` requires no test coverage.

## Section A — Coverage of new behavior

The only source change is a prompt-content addition (4 sentences inside the squash-surface CONTEXT heredoc). The new assertions in `util-adversarial-review-narrowing.bats:204-211` cover each NOTE 1 phrase directly:

- `grep -q "Primary judgment" "$CAPTURED_PROMPT"`
- `grep -q "operator has NOT supplied a bypass" "$CAPTURED_PROMPT"`
- `grep -q "procedural marker" "$CAPTURED_PROMPT"`
- `grep -q "Do NOT apply the generic" "$CAPTURED_PROMPT"`

The renamed NOTE 2 comment ("NOTE 2 telling reviewer to skip rule (c) is inlined") preserves the existing assertion on `SKIP rule (c) Body` + `bold-led-bullet`.

Each new phrase in the script diff has a matching grep in the test. No missing pair.

## Section B — Test quality

- **Assertion specificity**: The new assertions match distinctive phrases (not generic words). All 4 phrases would fail-loud if a future edit reworded them — exactly the behavior the procedural-marker lock benefits from (the followup commit 41ee2d7 explicitly codified this as a maintenance constraint).
- **Shape-only check**: N/A — script under test has no user-visible output; tests assert on the prompt the LLM judge will see, which is the only contract the script owns. Existing setup comment + the test's purpose statement at lines 161-165 explain why prompt inspection is the right layer.
- **Failure-path coverage**: Already present in adjacent tests at lines 217-249 (`MESSAGE_FILE missing` + `MESSAGE_FILE empty`). The new behavior doesn't introduce a new failure mode — it only changes prompt content on the existing success path — so the existing failure tests still cover the contract.
- **Weak assertions / boundary conditions**: None. The 4 grep checks are content-specific.
- **Skipped tests / `.only`**: None added or modified.
- **Wrapper / Zod / WebKit / realtime / routeWebSocket rubrics**: N/A — devshop bash script, none of the project-side rubrics apply.

**Layer note (informational, not a finding)**: The test verifies the new prompt text reaches the LLM judge but cannot verify the judge actually honors the instruction at the end of the chain. The operator's 10-commit dry-run validation (referenced in the commit body / task tracker) is the right layer for that end-to-end assertion; the bats test correctly stops at the contract boundary it owns.

## Section C — Bypass trailers

No `Tests-Coverage-Bypass:` trailers in range.

## Findings

Tests look solid — no findings.

`high=0 medium=0 low=0`
