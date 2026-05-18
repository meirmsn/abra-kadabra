# Review — ak-merge-devshop-worktree-aware

## Audit 1: manual (2026-05-18)

<!-- audited-at: 360186e76d0054156f68c09dbf5405ccab9ab4a5 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

Coverage (Section A): the SKILL.md change in `.claude/skills/devshop/merge-devshop/SKILL.md` is matched by edits to `kit/docs/guide/workflow.md` (skill-table entry — adds "worktree-aware" + Phase 0.1 + Phase 2 `git -C $WORKTREE_PATH` + Phase 4.2 teardown summary), `kit/docs/guide/architecture.md § Doing devshop work` (adds the worktree alternative to the canonical bash example), and `CLAUDE.md § Parallel work via linked worktrees` (rewrites "Merging requires the main worktree" prose to "Merging is worktree-aware" with the new flow). `kit/TODOS.md` deletion satisfies the close-out convention; `kit/tests/util-ak-merge-devshop.bats` is the test-coverage surface (not a coverage rubric target — it's the proof of coverage).

Adequacy (Section B): all three reference-doc edits are substantive — new prose describing observable behavior (worktree-list scan, `$GIT_CMD` routing, two-command teardown). Named claims verified: Phase 0.1, Phase 2, Phase 4.2 sections exist in the new SKILL.md. `--branch <name>` flag named in CLAUDE.md and workflow.md. No stub edits.

Coherence (Section C): no renames or deletions other than the TODO entry. Cross-doc sweep — the old "**Merging requires the main worktree**" prose is removed from CLAUDE.md (verified by `! grep` in the bats invariants); workflow.md and architecture.md describe the new flow consistently. No other devshop docs reference the "manual `git worktree remove` before merging" anti-pattern.

Bypass trailers (Section D): No Docs-Coverage-Bypass trailers in range.

### Tests findings

- (none)

Section A — Coverage: `kit/tests/util-ak-merge-devshop.bats` rewritten with 57 invariants covering the new contract. Sections A (frontmatter + inputs), B (Phase 0.1 detection: worktree-list scan, type-prefix filter, ahead-of-origin/main, zero/one/multi handling), C (Phase 0.2 FEATURE regex regression from Audit 1 2026-05-07), D (Phase 0.3 mechanical commands use `$BRANCH`), E (Phase 0.5 approval gate), F (Phase 1 audit orchestrator), G (Phase 2 `$GIT_CMD` routing — including the regression check that legacy `git merge --squash` is NOT present), H (Phase 3 ff-merge + push + workflow-scope), I (Phase 4 tree-equality + 4.2 teardown ordering + `--force` requirement + `deinit -f --all`), J (Phase 5 release-hint), K (cross-doc coherence with CLAUDE.md / workflow.md / architecture.md).

Section B — Quality: no weak assertions, no skip/only patterns. Section I's ordering test extracts line numbers from the section text and asserts `deinit_line < worktree_remove_line < branch_d_line` — a structural invariant that would fail if cleanup steps were ever reordered. All 57 tests pass locally against HEAD.

Section C — Bypass trailers: No Tests-Coverage-Bypass trailers in range.

### Bypass trailer audit

- (none)
