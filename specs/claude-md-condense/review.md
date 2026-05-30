# Review — claude-md-condense

## Audit 1: manual (2026-05-30)

<!-- audited-at: 8e0e1a0ea32805164c23214debe6a420630e34b6 -->
<!-- range: cc48f91a68444b874ab6b7ade77dc6fd3cf44033..8e0e1a0ea32805164c23214debe6a420630e34b6 -->

findings: high=0 medium=0 low=2

### Docs findings

- [low] commit d6ae19c — the script-touching commit (kit/scripts/adversarial-review.sh) carries a per-commit `**Existing projects:**` block; the squash message also carries one, so the propagation-block convention is satisfied at the squash surface. Verified: every relocated CLAUDE.md pointer resolves (ops.md § gstack runtime state has the split-brain + symlink + re-include + backfill; workflow.md has the worktree/merge mechanics; FRICTION-LOG.md has the worktree-hooks entry). No dangling refs, no dropped first-actions; the condensation correctly fixed the prior false "all hooks fire identically" claim.

### Tests findings

- [low] kit/tests/util-adversarial-review-narrowing.bats — the capture-the-prompt test pins the CLAUDE_MD_SECTIONS section list + forwarded reason but does NOT assert the rubric prose body (now including the new (f) "Reachability split" lines) reaches the assembled prompt. A future condense pass could silently drop the (f) lines and ship green. Cheap fix: add one `grep -q "Reachability split"` assertion to the existing capture test. Non-blocking.

### Bypass trailer audit

- (none in range)
