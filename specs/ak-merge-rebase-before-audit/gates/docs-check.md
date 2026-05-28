## Gate 1: docs-check

- Result: pass

The behavior change (rebase-before-audit in /ak-merge-devshop) carries its doc
updates in the same branch:

- `kit/docs/guide/workflow.md` — /ak-merge-devshop skill-map row updated to the
  rebase-before-audit ordering + `--range "$ANCHOR..HEAD"`.
- `.claude/skills/devshop/build/devshop-mode.md` — § "What /ak-merge-devshop
  handles" Phase 1 summary + idempotence note updated (Phase 2.5 catch).
- `.claude/skills/devshop/merge-devshop/SKILL.md` — self-documenting (the skill
  IS the doc); Phase 0.2 table, Phase 1.0/1.1, Phase 2, Idempotence all updated.
- CLAUDE.md references "/ak-merge-devshop Phase 1" generically (audit is still in
  Phase 1, now as 1.1) — no stale ordering claim (verified Phase 2.5).

## Dismissals

None
