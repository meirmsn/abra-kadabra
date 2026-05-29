# Review — friction-log

## Audit 1: manual (2026-05-29)

<!-- audited-at: 0f58b82255693be77486dfeb7a329b61017fd2c4 -->
<!-- range: 6f441e1598fc8bbae9332b4fefc89b500155afed..0f58b82255693be77486dfeb7a329b61017fd2c4 -->

findings: high=0 medium=1 low=2

### Docs findings

- [medium] CLAUDE.md:48 — Lessons rule now routes not-shipped lessons to `kit/FRICTION-LOG.md` via `/ak-record-friction-log` AND still names `/ak-go-live § Step 5b` as the canonical reflection moment, but Step 5b (go-live/SKILL.md:551-561) was not updated — its "file" routing still points only at `kit/ROADMAP.md § v0/v1`, no FRICTION-LOG. The cited canonical moment and the rule citing it disagree on where a not-shipped lesson lands; unwind the cross-reference in the same PR (add FRICTION-LOG routing to Step 5b).
- [low] .claude/skills/devshop/record-friction-log/SKILL.md:48-50 — Step 0 create-if-absent says "the template header in this skill's directory sibling (`kit/FRICTION-LOG.md` is the canonical seed)" — but `kit/FRICTION-LOG.md` is not a sibling of the skill dir, and "copy from the seed" is circular when the file is the very one being created. Reword to "scaffold the header + empty `## Open`/`## Resolved` sections."
- [low] README.md:45 — README still frames `kit/TODOS.md` as the home for "friction"; with FRICTION-LOG.md now the dedicated upstream funnel, that framing is mildly stale (out-of-range file, surface only).

### Tests findings

- (none) — no test surface added; none required. The change is a pure Markdown ledger + prose SKILL.md + symlink + doc edits, with no new/changed executable kit/script, so there is no bats target to add and no existing test is invalidated.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-29)

<!-- audited-at: e35f140a3e2dc6cc3904a25bbed901b306228e87 -->
<!-- range: 6f441e1598fc8bbae9332b4fefc89b500155afed..e35f140 -->

findings: high=0 medium=0 low=0

Re-audit after the cross-reference unwind commit (e35f140). All three Audit 1
findings are resolved; no new findings introduced.

### Docs findings

- (none) — all three Audit 1 findings verified resolved:
  - [Audit 1 medium — RESOLVED] go-live/SKILL.md:561 now routes the "File" disposition to `kit/FRICTION-LOG.md` via `/ak-record-friction-log`; CLAUDE.md:48 ↔ Step 5b cross-reference is now consistent in both directions.
  - [Audit 1 low — RESOLVED] record-friction-log/SKILL.md:48-51 reworded from the circular "directory sibling / canonical seed" phrasing to "scaffold it: write the `# Friction Log` header ... and empty `## Open` and `## Resolved` sections" — non-circular, and the named sections match FRICTION-LOG.md (`## Open`, `## Resolved`).
  - [Audit 1 low — RESOLVED] README.md:45-46 now lists `kit/FRICTION-LOG.md` as the intake funnel and reframes `kit/TODOS.md` as "committed bugs + small fixes".

### Tests findings

- (none) — e35f140 is pure Markdown prose (go-live SKILL.md, record-friction-log SKILL.md, README.md); no executable kit/script or source touched, so no test surface required. Same conclusion as Audit 1.

### Bypass trailer audit

- (none)
