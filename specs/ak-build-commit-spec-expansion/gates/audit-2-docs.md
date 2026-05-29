### [domain: docs] [section: A] [severity: low]
**File**: kit/docs/guide/workflow.md:218
**What**: The `/ak-build` SKILL.md change (resume discriminator now reads committed state via `git show HEAD:…`, Phase 1.1 commits the expansion) has no matching edit to workflow.md's Phase 1 prose, but the prose stays accurate.
**Why**: Coverage rubric (`.claude/skills/**/SKILL.md` → `workflow.md` OR `CLAUDE.md`) technically wants a paired doc edit. Here the existing workflow.md description ("the `## Task order` section is the discriminator the resume check uses to tell skeleton from complete spec") is deliberately implementation-agnostic — it does not assert WHERE the discriminator is read from, so it does not go stale. No new behavior surfaced to an operator (the commit-the-expanded-spec step is an internal robustness improvement, not a user-facing flow change). Recording as low/informational, not a coverage gap requiring a fix.
**Fix**: None required. Optionally, a future workflow.md touch could append "(read from the committed spec.md on resume)" to line 218 for precision, but it is not load-bearing.

### Bypass trailer audit
- (none) — no Docs-Coverage-Bypass trailers in range.

### Coherence note (section C)
- Verified: no renamed/deleted files in range; no stale path/section references introduced. The SKILL.md self-references (`devshop-mode.md § Phase 2.5`, `reconcile-task-commits.sh`, `util-reconcile-task-commits.bats`, Phase 0.3 skeleton commit) are pre-existing and unchanged. The Phase-exit registry row 1 and resume rungs 4/5 were updated consistently within the same file (working-tree `grep` → `git show HEAD:` migrated in all three call sites + the discriminator-explainer paragraph), so the SKILL.md is internally coherent.
- Verified: tracker hygiene correct — the TODOS.md entry this feature implements ("`/ak-build` Phase 1 doesn't commit the expanded spec.md") was deleted in the same range (c64de2c), per CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships". The newly-added structural-invariants.bats TODOS entry is correctly routed as out-of-scope discovery, not stale.

Summary: high=0 medium=0 low=1
