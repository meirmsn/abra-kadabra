# Tasks: implement-resume-reconcile

Derived from `spec.md § Task order`. Devshop-self-mode: test surface is bats
(`kit/tests/lib/bats-core/bin/bats kit/tests/<file>.bats`), not vitest/turbo.

Pre-scan against CLAUDE.md STOP AND ASK: none apply (spec § Decision rows —
no DB schema, auth, third-party API, perf path, security logic, test deletion,
METRICS events, new input path beyond argv parsing, or UI). Proceed autonomously.

## Task: reconcile-task-commits.sh helper + bats

**Hat**: BE (tooling)
**Depends on**: none
**Blocks**: Task 2
**Done when**: `kit/scripts/reconcile-task-commits.sh` exists + executable +
mawk-portable; exits 0/1/64 per spec § Behavior; all 8 cases in
`kit/tests/util-reconcile-task-commits.bats` pass via vendored bats. Committed,
clean tree.
**Risk**: medium
**Status**: done

## Task: wire reconcile into /ak-build Step 0 resume + Phase 2 note

**Hat**: PM (doc/prose)
**Depends on**: Task 1
**Blocks**: Task 4
**Done when**: `devshop/build/SKILL.md` Step 0 rung 2 calls the helper before
trusting all-done; on mismatch re-enters Phase 2 + surfaces loudly (NOT skip to
Phase 3); Phase 2 subagent-non-clean-return note present. (Symlink covers
`ak-build` path — one inode.) Committed, clean tree.
**Risk**: low
**Status**: done

## Task: /ak-implement done-means-committed contract

**Hat**: PM (doc/prose)
**Depends on**: none
**Blocks**: Task 4
**Done when**: `devshop/implement/SKILL.md` Step 3 step 11 + Step 4 reaffirm
done-means-committed (atomic per-task commit + clean tree). Committed, clean tree.
**Risk**: low
**Status**: done

## Task: doc sweep + util-ak-build-skill.bats assertions + TODO close

**Hat**: PM (doc/prose)
**Depends on**: Task 2, Task 3
**Done when**: `kit/docs/guide/workflow.md` reworded (no false "commit SHAs"
claim; mentions reconcile-on-resume); `kit/tests/util-ak-build-skill.bats`
Section F asserts wiring prose; `kit/TODOS.md` entry deleted. Full `kit/tests/`
bats suite green. Committed, clean tree.
**Risk**: low
**Status**: done

## Decisions

- **Task 2 — base-ref default**: Step 0 (devshop mode) has no PR yet, so `$BASE`
  is unset there (it is assigned from the PR base only in Phase 5/6). Used
  `origin/${BASE:-main}` in the rung-2 call — faithful to the spec's `origin/$BASE`
  intent while defaulting to `main` (the base every devshop branch targets) to
  avoid an unbound-variable failure at resume time.
- **Task 4 — script mode fix**: the helper was committed in Task 1 as 100755;
  the `structural-invariants.bats` "all kit/scripts/*.sh tracked as 644" invariant
  flagged it during the full-suite run. Fixed with `git add --chmod=-x` and folded
  into Task 4's commit (<5 min minor fix). init-devshop.sh locks scripts to 644;
  they run via `bash <script>`, never direct execution.
- **Task 4 — pre-existing failing test filed, not fixed**: the full-suite run
  surfaced `util-build-phase58-audit-parser.bats` "Phase 6 audit comment posts
  concise summary" failing — confirmed pre-existing at the branch base, unrelated
  to this feature (my edits never touched the Phase 6 region). Routed to
  `kit/TODOS.md` per the out-of-scope-discovery protocol rather than expanding
  scope.
