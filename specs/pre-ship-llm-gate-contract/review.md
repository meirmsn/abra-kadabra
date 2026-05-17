# Review — pre-ship-llm-gate-contract

## Audit 1: manual (2026-05-17)

<!-- audited-at: 3ed6e8baf81f67f99af62aeafa2f27e50cafbad7 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=2 low=0

### Docs findings

- [medium] `kit/docs/guide/workflow.md:267` — "Gate outcomes use four categories: `pass`, `findings (N) [fixed|pending]`, `n/a`, `blocked`" is stale after this PR. The new LLM-mediated-gate contract (Gates 6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa` MUST emit `pass | findings | blocked` — never `n/a`; scope exemptions use `blocked (n/a per scope: <reason>)`) is codified in `ak-pre-ship/SKILL.md § Outcome semantics`, `ak-build/SKILL.md § Phase 3 → Phase 4 handoff`, `CLAUDE.md`'s dismissalLog bullet, and `hooks.md § Dismissal Log` — but workflow.md (the overview-level enumeration an operator reads first for orientation) still presents `n/a` as universally valid. **Fix**: amend workflow.md:267 with one sentence noting the carve-out plus pointer to `pre-ship/SKILL.md § Outcome semantics § \`n/a\` is not legal for LLM-mediated gates`.

### Tests findings

- [medium] `.claude/skills/devshop/build/SKILL.md:478-487` — the Phase 3→4 handoff's third halt rung is an inlined `awk` script with no codified regression test. The mid-branch fix `3ed6e8b` ("portable awk boundary in Phase 3→4 n/a halt grep") demonstrated the exact failure mode — the original `\b` is a Perl/GNU-awk extension; mawk (devcontainer default) treats it as empty silently, so the rung never fired. Fix was verified by manual smoke test, NOT codified. **Fix** (cheapest): add `kit/tests/util-ak-build-llm-mediated-na-grep.bats` exercising the inlined awk against fixture `review.md` files — plain `n/a` on Gate 8 (should print gate line, regression target for the mawk `\b` bug), `blocked (n/a per scope: ...)` (should print nothing, scope-exempt shape), non-LLM-mediated gate `n/a` (should print nothing, carve-out preserved). Run with `mawk` explicitly. Higher-scope alternative: extract the awk to `kit/scripts/preship/check-llm-mediated-na.sh` and bats-test the script.

### Bypass trailer audit

- (none — no `Docs-Coverage-Bypass:` or `Tests-Coverage-Bypass:` trailers in range)
