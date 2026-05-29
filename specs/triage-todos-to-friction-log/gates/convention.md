## Gate 11: convention

- Result: findings (1)

**Commit subjects — conventional-commit + readability (`git log origin/main..HEAD --oneline`)**: All 7 subjects use valid conventional-commit types (`docs:`/`chore:`) with scopes and describe the observable change (e.g. "demote 7 premature items to friction log", "promote virtiofs phantom-rebase auto-switch to v0", "version-tag remaining open entries per triage buckets"). PARTIAL — two subjects exceed the ≤72-char readability limit from `kit/docs/guide/conventions.md § Commit + PR Text Style`:

- `chore(triage-todos-to-friction-log): branch baseline — capture triage intake + ignore scheduler lock` — **102 chars**
- `chore(todos): demote 7 premature items to friction log; delete triage driver` — **76 chars**
  These are already-committed history on the branch; the squash subject produced at `/ak-merge-devshop` Phase 0.3 is the reviewer-facing surface that the pre-push `prTextHygieneReason` engine judges, so the over-length per-commit subjects do not block. Flagged as a readability finding only. The other 5 subjects are ≤72.

**FRICTION-LOG.md entry schema + ordering (`kit/FRICTION-LOG.md` top-of-file rules)**: PASS. The branch added 7 new entries (matching the "seed 7 demoted TODOs" commit). All 8 Open-section entries carry the full 9-field schema (Score / Impact / Count / Status / First seen / Sessions / Symptom / Detail / Promotion target) — verified programmatically, zero missing fields. Scores are sorted descending: 4, 4, 3, 3, 3, 3, 2, 1 (ties broken by impact then recency, consistent with the Ordering rule). Each Score equals `impact × count`. `## Resolved` section present and empty ("_None yet._").

**PLAN.md virtiofs row — "How to add entries" column contract**: PASS.

- Hook: `/ak-merge-devshop auto-detects the virtiofs phantom-rebase flake and auto-switches to the merge fallback` = **104 chars** ≤ 120. OK.
- Source: `` `kit/TODOS.md` `` `§` `/ak-merge-devshop` Phase 2 / Phase 1.0 — mechanize the virtiofs phantom-rebase fallback`— correct shape (file path in its own code span +`§`separator + heading text). Source heading >70 chars so the truncation rule applies; truncated at the first`—`-bearing parenthetical, and the cited text resolves to exactly 1 match in `kit/TODOS.md`. OK.
- Lev: M impact (3) × S risk (2) ÷ S cost-divisor (0.75) = **8.0**, matches the cell. Table is sorted by Lev descending (8.0, 3.6, 3.6, 3.2, 2.4, 2.4, 0.7). OK.

**kit/TODOS.md version tags — documented `[vN]` form**: PASS. The branch's added/changed tag lines use only `[v0]`, `[v1]`, `[v+]` (diff-of-added-lines: 8×`[v0]`, 15×`[v1]`, 6×`[v+]`). Pre-existing `[v0.2]` and `[v0+]` tags are NOT introduced by this branch and are explicitly sanctioned by the file's own header comment ("Tag with [v0.2], [v1] etc."). `[v+]` is the established "future/unscheduled" tier already in use across the file. No malformed tags introduced.

**No SKILL.md / shell-script / guide-doc changes**: CONFIRMED. `git diff origin/main..HEAD --name-only` is tracker/docs/spec only: `.gitignore`, `PLAN.md`, `kit/FRICTION-LOG.md`, `kit/TODOS.md`, `specs/triage-todos-to-friction-log/{spec,tasks}.md`. No `*SKILL.md`, no `*.sh`, no `kit/docs/guide/**`. The SKILL-frontmatter and new-script-needs-bats convention checks are correctly n/a.

## Dismissals

None
