# Tasks: virtiofs-rebase-auto-switch

Pre-scan against CLAUDE.md STOP-AND-ASK: none apply. Pure bash/git devshop
tooling — no DB schema, auth, third-party API, perf path, security logic, test
deletion, metrics, UI, or new observability surface. All five decisions (D1–D5)
were resolved at spec time. Proceed autonomously (devshop tooling change).

## Task: T1 — helper script

**Hat**: BE (correctness-first git tooling)
**Depends on**: none
**Blocks**: T2, T3, T4
**Done when**: `kit/scripts/virtiofs-rebase.sh` exists, executable, has the
`# What:/# Why:/# Does NOT:` + exit-code/RESULT header, implements the full
ladder (rebase → checkstat-retry → merge-fallback) with unmerged-path
discrimination and exit codes 0/10/11/1/64.
**Risk**: medium (set -euo pipefail + expected-nonzero git is the likely bug)
**Status**: done

## Task: T2 — bats tests

**Hat**: BE
**Depends on**: T1
**Blocks**: T3
**Done when**: `kit/tests/util-virtiofs-rebase.bats` covers all ~18 spec cases
(git-stub harness + real-repo fixtures), runs green.
**Risk**: medium
**Status**: done

## Task: T3 — wiring registration

**Hat**: BE
**Depends on**: T1, T2
**Blocks**: T4
**Done when**: `virtiofs-rebase.sh` is in the `infra_scripts` allow-list in
`structural-invariants.bats`; that suite is green.
**Risk**: low
**Status**: done

(T1+T2+T3 land together as one logical "helper + tests + wiring" commit per the
ordering dependency — an unregistered new script reds structural-invariants.)

## Task: T4 — SKILL rewrite

**Hat**: BE
**Depends on**: T1
**Blocks**: none
**Done when**: `merge-devshop/SKILL.md § Phase 1.0` calls
`virtiofs-rebase.sh "$ANCHOR" "$WORKTREE_PATH"`, handles exit 10 / 11; cherry-pick
/`am` manual recipe retained.
**Risk**: low
**Status**: done

## Task: T5 — closing-convention docs

**Hat**: PM/docs
**Depends on**: T1, T4
**Blocks**: none
**Done when**: CLAUDE.md footgun rewritten imperative-present; workflow.md row
updated; kit/TODOS.md mechanize entry deleted; FRICTION-LOG F244 resolved;
cross-refs unwound (`grep -rn "mechanize the virtiofs" kit/ CLAUDE.md` empty).
**Risk**: low
**Status**: done

## Decisions

- **T1 (merge other-error capture)**: captured `git merge` stderr into
  `merge_err` so the exit-1 `RESULT: error: <msg>` line carries the underlying
  message (spec's table shows `error: <msg>`). Spec didn't pin the exact
  capture mechanism; chose `merge_err=$(... 2>&1) || rc=$?`.
- **T1 (rebase-in-progress probe)**: probe BOTH `rebase-merge` and
  `rebase-apply` git-path dirs (spec § Guarding mentions either), guarding
  `rebase --abort` so a bare abort can't trip `set -e`.
- **T2 (cases 16/17)**: case 16 asserts the inline-flag invariant via the stub
  argv log (no `git config` write) rather than a real-repo `git config --local`
  probe — the real flake is non-reproducible, so a real checkstat run can't be
  forced; the argv assertion is the load-bearing one. Case 17 asserts the
  anchor-ancestor end-state on a real clean rebase (same end-state contract the
  merged-fallback rung guarantees), since merged-fallback only fires on the
  non-reproducible phantom.
- **T4 (stale SKILL bats tests)**: the Phase 1.0 rewrite removed the inline
  ladder prose that 4 `util-ak-merge-devshop.bats` grep-tests pinned; updated
  those tests in the same commit to assert the new helper-call shape (helper
  invocation, exit-10/11 caller handling, checkStat-before-merge ordering in the
  prose) — the doc/SKILL grep-drift friction. No coverage lost.
- **T5 (atomic single commit)**: shipped T1–T5 as one atomic commit rather than
  separate per-task commits. The clean-tree pre-commit guard counts ALL dirty
  tracked files, and `kit/` paths in this linked worktree interact with the
  husky lint-staged `--no-stash` run such that intermediate per-task commits
  repeatedly tripped the guard / a coverage false-negative on the new script.
  One atomic commit with the full feature is the simplest correct unit here.
- **T5 (testsCoverageReason bypass)**: the `check-tests-coverage-devshop.sh`
  gate false-negatived on `virtiofs-rebase.sh` even though
  `util-virtiofs-rebase.bats` is present + staged (verified: running the gate
  directly against the staged index returns rc=0). Used a specific
  `devshop.testsCoverageReason` documenting the false-negative, not a generic
  skip.
