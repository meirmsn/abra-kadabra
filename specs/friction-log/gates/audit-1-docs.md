# Docs review — Audit 1

Range: `6f441e1598fc8bbae9332b4fefc89b500155afed..0f58b82255693be77486dfeb7a329b61017fd2c4`
Repo: /devshop (worktree `feat/friction-log`)

## Scope

Pure-docs/skill change introducing a friction-intake ledger:
- `kit/FRICTION-LOG.md` (new, +100) — ledger header (purpose, schema, ordering) + one seeded `## Open` entry.
- `.claude/skills/devshop/record-friction-log/SKILL.md` (new, +165) — the write-path skill.
- `.claude/skills/ak-record-friction-log` (new symlink → `devshop/record-friction-log`).
- `CLAUDE.md` (±5) — three wiring edits (Context Loading backlogs line, lessons-rule, TODO Protocol routing).

No `METRICS.md` surface (devshop tooling, not a user-facing product feature) — none required.

## Coverage check

- New skill `/ak-record-friction-log` IS documented: its own SKILL.md is the spec; CLAUDE.md wires it in three places; the ledger header (`kit/FRICTION-LOG.md`) documents schema/scoring/ordering that the skill maintains. Coverage is adequate — the doc surface matches the introduced behavior.
- Symlink resolves correctly: `ak-record-friction-log -> devshop/record-friction-log`, and `devshop/record-friction-log/SKILL.md` exists. Naming is consistent across symlink, frontmatter `name:`, and every CLAUDE.md reference (`/ak-record-friction-log`).
- Ledger schema vs skill write-path: cross-checked. Skill Step 3c writes every schema field the header defines (Score, Impact, Count, Status, First seen, Sessions, Symptom, Detail, Promotion target). Scoring (`impact × count`), ordering (Score desc, tie-break Impact desc then most-recent), and the `## Open`/`## Resolved` split are consistent between the two files. The seeded entry conforms to the schema exactly. Self-consistent.
- CLAUDE.md edits point at the right targets: all three edits reference `kit/FRICTION-LOG.md` + `/ak-record-friction-log` correctly; the TODO-Protocol routing bullet and the Context-Loading backlogs line are coherent with the ledger's stated "intake upstream of the backlog" role.

## Findings

- [medium] CLAUDE.md:48 — Stale cross-reference after the lessons-rule edit. The edited lessons rule now says "File each lesson the user doesn't ship now into `kit/FRICTION-LOG.md` via `/ak-record-friction-log`" AND still names "`/ak-go-live § Step 5b` as the canonical reflection moment for ship-ending sessions." But `/ak-go-live § Step 5b` (go-live/SKILL.md:551-561) was NOT updated: its "ship now vs file vs skip" routing still sends "file" only to `kit/ROADMAP.md § v0/v1` with no mention of FRICTION-LOG or `/ak-record-friction-log`. The canonical reflection moment and the rule that cites it now disagree on where a not-shipped lesson lands. Per CLAUDE.md § "Closing TODO/ROADMAP entries when a fix ships" (unwind every cross-reference in the same PR), Step 5b should be updated to route "file" → `/ak-record-friction-log` in the same change. Recommend (do not auto-fix): add a FRICTION-LOG routing line to go-live Step 5b's file/skip options.

- [low] record-friction-log/SKILL.md:48-50 — Step 0 self-creation instruction is slightly incoherent. "create it from the template header in this skill's directory sibling (`kit/FRICTION-LOG.md` is the canonical seed — copy its header...)". `kit/FRICTION-LOG.md` is NOT a sibling of this skill's directory (`.claude/skills/devshop/record-friction-log/`); it lives at the repo's `kit/`. The phrase "this skill's directory sibling" contradicts the parenthetical that correctly names `kit/FRICTION-LOG.md` as the seed. Also, if the seed file is the same `kit/FRICTION-LOG.md` the skill is meant to create-if-absent, the "copy from the seed" instruction is circular when the file is genuinely missing. Low severity — the branch ships the file so the create-if-absent path won't fire in practice; recommend rewording to "scaffold the header + empty `## Open`/`## Resolved` sections" without the contradictory sibling/seed framing.

- [low] CLAUDE.md / README coherence — README.md:45 still describes `kit/TODOS.md` as "tactical: friction, bugs, small fixes." With FRICTION-LOG.md now the dedicated friction-intake funnel "upstream of the backlogs," the README's framing of TODOS as the friction destination is now mildly stale. Not contradictory (TODOS still holds promoted friction), but a future reader could see two "friction" homes. Recommend (optional): note in README that raw recurring friction now lands in FRICTION-LOG first. Out-of-range file — surface only, no block.

findings: high=0 medium=1 low=2
