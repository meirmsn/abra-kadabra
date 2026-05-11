# Plan

Forward-looking plan at the feature/PR grain.

- Pipeline phase per active branch: each feature's `specs/<name>/tasks.md`
- Shipped (rich history): `BUILD-LOG.md`
- Deferred / long-term: `kit/ROADMAP.md`
- Tactical bugs/polish: `kit/TODOS.md`
- Plan history (including dropped rows): `git log --follow PLAN.md`

## Active

| Feature                         | Branch                                  | Spec                                          |
| ------------------------------- | --------------------------------------- | --------------------------------------------- |
| context-aware-guideline-routing | feature/context-aware-guideline-routing | specs/context-aware-guideline-routing/spec.md |

## Planned

| #   | Feature                        | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| --- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | gstack-helper-path-resolution  | SKILL.md preambles hardcoded to `~/.claude/skills/gstack/<helper>` go silently no-op when Claude Code prunes the user-global gstack folder (devcontainer rebuilds, settings refreshes). Telemetry / timeline / learnings have been silently no-op'ing across multiple lalista deploy cycles; only `gstack-slug` failed visibly because `/land-and-deploy` consumes its output. Fix: SKILL.md preambles resolve via `$_ROOT/.claude/skills/gstack/<helper>` first (project-local, survives prune), fall back to `~/.claude/skills/gstack/<helper>` — either inline as a `B=` resolver or factor into `bin/gstack-resolve-bin`. Prior art: `browse` SETUP block (`/devshop/.claude/skills/gstack/browse/SKILL.md` lines 358-361). Source: `kit/TODOS.md § SKILL.md gstack-helper path resolution`. ~20 min. **Urgent** — actively bugged today across every silently-firing helper.                                                                                                                     |
| 2   | pr-body-img-merge-sha-survival | Two-track fix for the broken-image-on-closed-PR bug surfaced by lalista PR 53 (2026-05-08). **Track A (forward fix, ~2h)**: insert `/ak-go-live § Step 2.5: Rewrite PR-body image URLs to merge SHA` between `gh pr merge` and branch cleanup. Rewrites `/raw/${BRANCH}/` URL slices to `/raw/${mergeCommit.oid}/` so embedded hero / qa-walk / design evidence survives `--delete-branch`. Exact-branch-match preserves cross-PR refs and tag-based refs. Paired `kit/docs/guide/workflow.md` paragraph + BATS test. **Track B (one-time backfill, ~4h)**: new `kit/scripts/devshop/backfill-pr-image-urls.sh` with `--dry-run` / `--accept-history-rewrite` / per-PR audit log. Run once per project against `gh pr list --state merged`; idempotent on re-run. Pre-existing surface: ~15+ closed lalista PRs (every UI-touching chapter with hero shots) currently render evidence as blue-square-question-mark. Source: `kit/ROADMAP.md § PR-body image URLs survive branch deletion`. Total ~6h. |

<!--
Conventions:
- Status lives in section membership (Active vs Planned) — no status column.
- A Planned row transitions to Active when /ak-spec runs: drop #, add Branch + Spec columns.
- An Active row disappears when the feature ships — BUILD-LOG.md carries the full record.
- A row that's dropped (rescope, deprecated) — delete it; git log + commit message is the audit trail.
- "Not now, maybe later" work belongs in kit/ROADMAP.md, not Planned.
- Planned ordered by # ascending (smallest = next up). Renumber on reorder.
-->
