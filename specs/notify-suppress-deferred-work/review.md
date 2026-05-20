# Review — notify-suppress-deferred-work

## Audit 1: manual (2026-05-20)

<!-- audited-at: 6e48f12f436dbaf710c656733e586c46183fa0b2 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=4

### Docs findings

- [low] kit/docs/OVERVIEW.md:262 — notifications summary line under-represents the new "deferred-work suppression" section. Fix: append `, deferred-work suppression` to the OVERVIEW notifications topic-keyword list.
- [low] commit fd271f3 (Docs-Coverage-Bypass trailer) — VERIFIED. Catalog-gap rationale was load-bearing AND closed in 3fbde1f within the same range; the canonical doc (`kit/docs/guide/notifications.md`) was staged with the right content.

### Tests findings

- [low] kit/tests/util-notify-claude.bats:134-142 — `Agent` tool with `run_in_background:true` is a documented suppression path in `claude-done` but has zero test coverage (only `Bash` background is tested). Fix: add one bats case mirroring the Bash case with `"name":"Agent"` in the tool_use payload.
- [low] kit/tests/util-notify-claude.bats:216-225 — `transcript_path` present in JSON but file unreadable / missing has no test (only the JSON-key-absent case is covered via `<<<'{}'`). Fix: add `run bash "$DONE_SCRIPT" <<<'{"transcript_path":"/does/not/exist.jsonl"}'` → `assert_success` + `[ -f "$CLAUDE_NOTIFY_PID_FILE" ]`.

### Bypass trailer audit

- `fd271f3` Docs-Coverage-Bypass: catalog-gap rationale — **VERIFIED**. The right canonical doc was staged; the catalog gap the trailer cited as session-learning was closed in `3fbde1f` within the same range.
- (no `Tests-Coverage-Bypass:` trailers in range)
