### Docs findings

- (none)

Notes (informational, no findings):

- Range touches three files: one mode-only flip (`kit/scripts/preship/migration-rollback-roundtrip.sh` 755→644, zero content change) and two bats test fixes (`kit/tests/structural-invariants.bats`, `kit/tests/template-compose-isolation.bats`). Both bats files are in the explicit Section A carve-out (`kit/tests/**`) — test fixes don't require doc updates. The mode-only preship-script flip introduces no new behavior to document.
- No reference docs touched in range → Sections B (Adequacy) and C (Cross-doc coherence) have nothing to assess. No renames/deletes → no stale-reference sweep needed.
- No `Docs-Coverage-Bypass:` trailers in range.
- Section E (CLAUDE.md hygiene) is project-mode only; this audit runs in devshop self-mode (`$GIT_ROOT = /devshop/.worktrees/fix-prerelease-bats-gaps`) → skipped.
- Meta-observation surfaced by the commit bodies themselves (not a finding, recorded for the operator): two regressions on origin/main (chmod from 7262fac, dport-regex from 94de8d7) slipped past their own pre-commit bats gauntlets on 2026-05-18. Commit 1aa4081 (structural-invariants worktree-awareness) is the durable fix — it makes the same class of regression catchable from feature branches going forward. No doc update required; the test-infrastructure fix is the answer.

Tally: high=0 medium=0 low=0
