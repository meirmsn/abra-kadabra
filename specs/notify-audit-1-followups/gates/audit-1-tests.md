Tests look solid — no findings.

## Scope reviewed

- Range: `origin/main..HEAD` (single commit `39e1623`)
- Files touched: `kit/docs/OVERVIEW.md` (docs only, no test impact), `kit/tests/util-notify-claude.bats` (+27 lines, +2 cases)
- New cases:
  1. `notify-claude-done: suppresses when last turn used run_in_background Agent` (kit/tests/util-notify-claude.bats:144) — covers the `Agent` branch of the jq predicate at `kit/scripts/notify/claude-done:35`, previously only the `Bash` branch was exercised.
  2. `notify-claude-done: unreadable transcript_path falls through to schedule` (kit/tests/util-notify-claude.bats:241) — covers the `[ -r "$transcript" ]` short-circuit at `kit/scripts/notify/claude-done:29` for the key-present-file-missing case, distinct from the existing JSON-key-absent test at line 230.

## Section A — Coverage of new behavior

No source scripts modified in this range; the commit is test-only follow-up that closes documented coverage gaps in an existing script. Both new tests cover real, previously-uncovered branches of `kit/scripts/notify/claude-done`. Coverage: complete.

## Section B — Test quality

- Assertions use concrete file-system effects (`[ ! -f $CLAUDE_NOTIFY_PID_FILE ]` / `[ -f $CLAUDE_NOTIFY_PID_FILE ]`) — not weak (`toBeDefined`-equivalent) and not shape-only.
- Each new test mirrors a sibling test's shape (the Agent case mirrors the Bash-background case at line 134; the unreadable-path case mirrors the missing-transcript case at line 230), so assertion depth matches the existing pattern in the suite.
- Inline comments name the rationale (what regression each test guards against), satisfying the "comment names the absence of user-visible output" shape for shell-script tests.
- No `.skip` / `.only`, no realtime / WebKit / LLM-boundary / wrapper-API patterns apply.

## Section C — Bypass trailer audit

Zero `Tests-Coverage-Bypass:` trailers in range.
