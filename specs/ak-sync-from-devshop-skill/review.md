# Review — ak-sync-from-devshop-skill

## Audit 1: manual (2026-05-27)

<!-- audited-at: f97b7df880b670f1ecca669722b0d4a0fa32be4b -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=4 low=0

### Docs findings

- [medium] CLAUDE.md:32 — `§ Session Start` still describes the post-sync flow as the raw script printing a `PROPAGATION.md` pointer; this commit re-routes both drift lines to `/ak-sync-from-devshop`, which handles the propagation read internally. Stale-by-omission. Fix: one-line clause noting the `Sync:` reminder now points at `/ak-sync-from-devshop`.
- [medium] kit/docs/guide/architecture.md:153 — `§ Propagating build tooling updates` still presents the bare `from-devshop.sh` invocation as canonical with no `/ak-sync-from-devshop` reference. Omission, not contradiction. Fix: one-line pointer at top of the section noting operators normally invoke the skill (script is the underlying mechanism).

### Tests findings

- [medium] .claude/skills/devshop/sync-from-devshop/SKILL.md (no test file) — new 205-line skill ships no `util-ak-sync-from-devshop.bats` smoke test and isn't proven-by an existing bats, violating the devshop "new SKILL.md → util-<skill>.bats or proven-by" rubric that 15+ devshop skills follow. Fix: add `kit/tests/util-ak-sync-from-devshop.bats` modeled on `util-ak-merge-devshop.bats` (frontmatter name, symlink resolution, phase-contract greps).
- [medium] kit/tests/devshop-version-tracking.bats:89-134 (untouched, diverged by this PR) — `run_drift_check` re-implements the drift logic inline with a hardcoded copy of the OLD message string and still asserts on it (lines 100/104/121/134). All 32 tests pass green while asserting a string `session-start.sh` no longer emits; new behavior is pinned only by a grep-existence check in `propagation-entry.bats`. Fix: refactor `run_drift_check` to track the real script, or update the hardcoded literals + assertions to the new `/ak-sync-from-devshop` string.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-27)

<!-- audited-at: 43f7fe89e2c1abe06c4729e705a0d2d95e1f9bc6 -->
<!-- range: f97b7df..43f7fe8 -->

findings: high=0 medium=0 low=0

Re-audit after polishing Audit 1's findings. All four Audit 1 mediums
resolved and confirmed sound (docs reviewer re-verified cross-doc coherence;
tests reviewer mutation-tested the de-fossilized `run_drift_check` to prove
it tracks the source).

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
