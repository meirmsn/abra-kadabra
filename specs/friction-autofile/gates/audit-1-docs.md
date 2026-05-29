findings: high=0 medium=0 low=0

### Docs findings

- (none)

Notes:
- Range is a 2-line doc-only wording change across `CLAUDE.md` ("surface
  devshop-generalizable lessons proactively" rule) and
  `.claude/skills/devshop/go-live/SKILL.md` (Step 5b "File" disposition).
- Both edits are mutually coherent: each now instructs the agent to invoke
  `/ak-record-friction-log` itself at the reflection beat (rather than handing
  the operator the command) and to report what landed/bumped.
- The CLAUDE.md edit additionally pins that this fires at the end-of-pipeline
  reflection beat, NOT the per-PR merge audit (`/ak-merge-devshop` Phase 1.1).
  Verified consistent: `merge-devshop/SKILL.md` carries no contradicting
  friction-log auto-invoke instruction.
- Downstream wiring is intact: `kit/FRICTION-LOG.md` and the
  `/ak-record-friction-log` skill both exist; the prose accurately describes
  the skill's behavior (match-scan, count+session-link accrual, re-sort by
  impact × count, promotion flagging to ROADMAP/TODOS/PLAN).
- Devshop "tooling change includes doc updates in same commit" rule is moot —
  this change has no executable surface; it IS a doc-only change.
