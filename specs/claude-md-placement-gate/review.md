# Review — claude-md-placement-gate

## Audit 1: manual (2026-05-29)

<!-- audited-at: cc016eaeac47141a30fa85927e1b263ced146c5d -->
<!-- range: 38db19c01e07c34a6c6958372ca8cacd1425ba27..cc016eaeac47141a30fa85927e1b263ced146c5d -->

findings: high=0 medium=1 low=3

### Docs findings

- [low] kit/docs/guide/claude-md.md:3 — top-matter still advertises "the section allowlist that bounds its shape" while the body (§ Enforcement / Q6) now establishes there is explicitly NO mechanical allowlist; rephrase to the placement-discipline framing.

### Tests findings

- [medium] kit/scripts/adversarial-review.sh:710-731 — new `CLAUDE_MD_SECTIONS` prompt-context plumbing (awk header extraction + "Existing CLAUDE.md sections" block) is untested; a regression breaking the extraction or heredoc interpolation ships green and silently degrades the placement dimension to a no-op (judges against an empty section list). Fix: add a capture-the-prompt test (pattern exists in `util-adversarial-review-narrowing.bats`) asserting the block + a seeded header appear.
- [low] kit/tests/guard-claude-md-classification.bats:78-86 — Test 3b pins "placement"/"NEW section" but not the changed usage-string shape (`trap → § <section>: … ; placement: <extends|NEW>`); add an assertion on the usage line.
- [low] kit/tests/guard-claude-md-classification.bats:90-106 — Test 4 PASS path uses the mock stub, so it doesn't verify the placement reason forwards into the reviewer prompt; optionally use a capturing stub.

### Bypass trailer audit

- (none — no Docs-Coverage-Bypass / Tests-Coverage-Bypass trailers in range; three well-formed Claude-MD-Classification trailers present but those are Layer-B, not Section-D)
