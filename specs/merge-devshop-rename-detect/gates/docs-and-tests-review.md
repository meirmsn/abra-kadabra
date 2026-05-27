## Gate 5: docs-and-tests-review

- Result: pass
- Docs: No reference doc updates needed. CLAUDE.md, hooks.md, and workflow.md are clean.
- Tests: 9 new bats tests in section L adequately cover all detection-block assertions.

### Docs audit

**CLAUDE.md Known Footguns**: The "Operator stashes can vanish silently" entry references lint-staged's stash-backup machinery as a hypothesis. It does NOT describe the rename+symlink manual recovery dance, so there is nothing to update now that the dance is automated. The entry's scope is stash-vanishing, not the rename combo itself. No change needed.

**kit/docs/guide/hooks.md**: References lint-staged stash backup context at line 151 (Section 2 config) and line 314 (Recovering a vanished stash). Neither section describes the rename+symlink combo or its manual recovery. The hooks.md content is about the stash-vanishing symptom, not the rename-triggers-lint-staged-crash symptom. No change needed.

**kit/docs/guide/workflow.md**: The `/ak-merge-devshop` skill table entry (line 478) is already long and describes the skill's major capabilities. The rename detection is an internal Phase 2 implementation detail (a pre-commit safety check), not a new top-level capability or interaction mode. The skill table entry's purpose is to describe what the skill does at the capability level (audit, squash, ff-merge, worktree-aware, etc.), not every internal safety check. No change needed.

**kit/TODOS.md**: The `/ak-merge-devshop Phase 2: detect rename-plus-symlink` entry was correctly deleted. The companion `lint-staged stash backup chokes on rename` entry was correctly updated with a `(2026-05-26)` note that option 3 shipped. Cross-references in the "Known limitations" section of SKILL.md were updated to point at the remaining lint-staged entry. Clean.

### Tests audit

All 9 section L tests cover the detection block's required assertions:

| # | Test | What it covers | Adequate? |
|---|------|----------------|-----------|
| 1 | `Phase 2 has a rename-plus-symlink detection block between soft-reset and commit` | Ordering: soft-reset < detection < commit by line number | Yes -- verifies correct placement |
| 2 | `Phase 2 detection scans git diff --cached --name-status for R (rename) entries` | `--diff-filter=R` presence | Yes |
| 3 | `Phase 2 detection compares rename source paths against A (added) entries` | Both `--diff-filter=R` and `--diff-filter=A` + `comm -12` intersection | Yes |
| 4 | `Phase 2 detection unstages on hit via git reset (not git reset --hard)` | Positive: `$GIT_CMD reset   # unstage`; Negative: no `--hard` in detection block | Yes -- covers both the safe unstage AND the negative case |
| 5 | `Phase 2 detection surfaces the lint-staged stash bug explanation` | `lint-staged` + `beyond a symbolic link` in detection block | Yes |
| 6 | `Phase 2 detection offers git merge --ff-only as fallback` | `ff-only` or `ff-merge` in detection block | Yes |
| 7 | `Phase 2 detection requires operator confirmation before ff-merge (not auto-fallback)` | `AskUserQuestion` in detection block | Yes -- verifies D2 decision |
| 8 | `Known limitations section notes rename-plus-symlink is now auto-detected` | `auto-detect` language in Known limitations | Yes |
| 9 | `Known limitations section preserves the recovery recipe` | `git reset` + `git merge --ff-only` still present | Yes |

**Negative case coverage**: Test 4 explicitly verifies `$GIT_CMD reset --hard` does NOT appear in the detection block (scoped to the `awk '/Rename-plus-symlink detection/,/^fi/'` range). This is the key safety assertion -- the detection unstages without destroying the working tree.

**Coverage completeness against the SKILL.md detection block**:
- Scan (`git diff --cached --name-status --diff-filter=R` + `--diff-filter=A`): tests 2, 3
- Intersection (`comm -12`): test 3
- Unstage on hit (`$GIT_CMD reset` without `--hard`): test 4
- Surface explanation (lint-staged + error message): test 5
- Fallback offer (`ff-only`): test 6
- Operator confirmation (`AskUserQuestion`): test 7
- Ordering (between soft-reset and commit): test 1
- Known limitations update: tests 8, 9

All assertions in the detection block are covered. No gaps found.

## Dismissals

None
