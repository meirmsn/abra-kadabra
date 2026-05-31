# Tasks: merge-devshop-worktree-hooks

Per spec § Task order. Devshop-self-mode (bats surface, no vitest/Playwright,
no METRICS.md/DESIGN.md). Per-task atomic commits. Task 1 + the CLAUDE.md half
of Task 4 fold into ONE commit (same §).

## Task: (b)+(a-CLAUDE.md) recipe edit + worktree bullet rewrite — CLAUDE.md

**Hat**: PM (doc/convention)
**Depends on**: none
**Blocks**: none
**Done when**: worktree-add recipe (l.63) appends `&& (cd .worktrees/<topic> && pnpm install)`; the "Pre-commit hooks do NOT fire in a fresh worktree" bullet (l.66) is rewritten to install-step-fixed + merge-time-net imperative present. Commit lands (CLAUDE.md classification gate answered: Known-Footgun/convention update).
**Risk**: low

**Status**: done

## Task: (d) gitleaks compensating gate — merge-devshop SKILL.md § Phase 2

**Hat**: BE (skill behavior)
**Depends on**: none
**Blocks**: bats test task
**Done when**: gitleaks `protect --staged --redact` gate inserted after the rename-plus-symlink block and before `commit -F`, cwd-pinned to `$WORKTREE_PATH` when set; halt-on-finding prose + explanatory paragraph below the fence.
**Risk**: low

**Status**: done

## Task: bats test — util-ak-merge-devshop.bats § Section G

**Hat**: BE (test)
**Depends on**: (d) gitleaks gate
**Blocks**: none
**Done when**: two `@test`s from spec § Tests added after existing Phase 2 tests; targeted bats run green.
**Risk**: low

**Status**: done

## Task: (a) doc-accuracy refine — SKILL.md Phase 2 claim + security.md

**Hat**: PM (doc)
**Depends on**: (d) gate (describes its posture)
**Blocks**: none
**Done when**: SKILL.md l.941–942 claim refined; security.md l.58 "fire identically" rewritten. (CLAUDE.md bullet folded into Task 1.)
**Risk**: low

**Status**: done

## Task: tracker closure — PLAN.md + kit/TODOS.md + kit/FRICTION-LOG.md

**Hat**: PM (doc)
**Depends on**: all above (close only once fix is in same PR)
**Blocks**: none
**Done when**: PLAN row deleted; TODOS entry deleted; FRICTION-LOG entry rewritten (Status shipped (b)+(d), (c) stub, drop "claims opposite" framing, SHA placeholder); cross-refs unwound; grep clean.
**Risk**: low

**Status**: done

## Decisions

- **Task 1 (CLAUDE.md classification gate)**: the adversarial reviewer rejected the first bullet wording for embedding the full Phase 2 gitleaks mechanism (failed the reachability split — that detail doesn't bite before opening the merge-devshop skill). Trimmed the bullet to symptom + first-action ("skip install → empty core.hooksPath → gates no-op; run the full recipe") with the gitleaks net reduced to a one-line pointer into SKILL.md § Phase 2. Re-classified as `trap → extends § Parallel work via linked worktrees` and the commit landed.
- **Task 2 (docs-coverage pairing)**: the "skills" surface (merge-devshop SKILL.md) requires `workflow.md` OR `CLAUDE.md` staged. Added a substantive, on-topic sentence to the `/ak-merge-devshop` row in `kit/docs/guide/workflow.md` documenting the new Phase 2 gitleaks gate (genuine doc update, not a phantom worktree-recipe mirror — the spec scoped out only the _recipe_ mirror, not gate documentation). This satisfied the pairing without a bypass.
- **Task 4 (docs-coverage bypass)**: the SKILL.md Phase 2 _prose-only_ correction's canonical guide homes (workflow.md row, CLAUDE.md bullet) already landed in Tasks 1+2 of this same branch; re-editing them would be redundant padding. Used the `devshop.docsCoverageReason` bypass trailer (the designed mechanism for "paired doc already shipped this PR") with a grounded per-doc enumeration; audit-time `/ak-docs-review` VERIFIES it against the f887c8e + 79a0eb3 edits.
