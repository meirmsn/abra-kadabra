## Task: De-submodule the bats libs

**Hat**: BE/Data (VCS-structure; can corrupt shared state)
**Depends on**: none
**Blocks**: Task 2, Task 3, Task 4, Task 5
**Done when**: `.gitmodules` deleted; `submodule.*` keys gone from shared config; each lib is plain tracked files (no gitlink); runtime subset present + non-runtime dirs gone; full bats suite green; BOTH trees healthy; committed.
**Risk**: high (mutates shared `.git` state — D6)
**Status**: done

## Task: Vendor script + manifest + paired test

**Hat**: BE
**Depends on**: Task 1
**Blocks**: Task 3
**Done when**: `kit/scripts/vendor-bats-libs.sh` exists+executable (pinned SHAs D2, runtime subset D3, `.git` strip, VENDORED-VERSIONS emit, self-verify); `kit/tests/lib/VENDORED-VERSIONS` lists 3 libs; `kit/tests/util-vendor-bats-libs.bats` written; script registered in `structural-invariants.bats` `infra_scripts`; full suite green; committed.
**Risk**: medium
**Status**: done

## Task: Gate exclusions + rewrite submodule-init invariant

**Hat**: BE
**Depends on**: Task 1
**Blocks**: none
**Done when**: each gate audited (tests-coverage, file-headers, bats-coverage, Gate-11, merge gitleaks) — exclusion added only where audit shows a reach; "BATS submodules are initialized" invariant rewritten to assert plain runtime files; full suite green; committed.
**Risk**: medium
**Status**: done

## Task: Recipe + doc edits

**Hat**: PM/docs
**Depends on**: Task 1
**Blocks**: none
**Done when**: submodule step stripped from `CLAUDE.md`, `architecture.md`, `ROADMAP.md`; trap prose rewritten; merge-devshop submodule-deinit teardown removed; FAQ:46 confirmed accurate; full suite green; committed.
**Risk**: low
**Status**: done

## Task: Tracker closure (config-injection face only)

**Hat**: PM
**Depends on**: Task 1
**Blocks**: none
**Done when**: [HIGH] kit/TODOS.md entry split — config-injection portion removed, HEAD-race face re-filed as new entry preserving observations; cross-refs to config-injection footgun unwound across kit/docs/ + CLAUDE.md; full suite green; committed. (PLAN.md Active-row + FRICTION-LOG fold = Phase 4.0, NOT here.)
**Risk**: low
**Status**: done

## Decisions

- **Task 2 / docs-coverage**: Documented the vendored-plain-files + `vendor-bats-libs.sh`
  re-vendor mechanism in `conventions.md § Kit Testing` (natural home — the existing
  BATS-testing section) to satisfy the scripts→guide doc-coverage gate, rather than
  CLAUDE.md (CLAUDE.md already carries the worktree recipe, edited in Task 4).
- **Task 2 / gates**: `vendor-bats-libs.sh` tracked as `644` (per `kit/scripts/*.sh`
  mode invariant — init-devshop.sh applies exec at deploy); working-tree exec bit
  removed to keep the tree clean. Tests-coverage gate false-blocked in-worktree
  (Gotcha 1: `$DEVSHOP`-rooted scan can't see the worktree's new paired test) —
  bypassed with a Tests-Coverage-Bypass trailer; resolves on merge to main.
- **Task 3 / gate audit (D4)**: Audited all five gates — NONE needs a `kit/tests/lib/**`
  exclusion. tests-coverage scopes to `^kit/scripts/.*\.sh$`; file-headers to `.ts/.tsx`
  under `src|app`; bats-coverage to `kit/tests/*.bats` (top-level) + `kit/scripts/*.sh`;
  Gate 11 runs check-file-headers (same scope). gitleaks (`protect --staged` husky path
  AND `git --log-opts` merge/ff path) scanned the full vendored delta clean — the D3
  trim removed `bats-core/test/` fixtures (the only false-positive risk). Adding any
  exclusion would be a no-op, which the spec explicitly says to avoid. No `.gitleaks.toml`
  change needed.
- **Task 5 / cross-ref unwind (D7)**: No config-injection footgun line ever landed in
  `CLAUDE.md § Known Footguns` (the old TODOS "captured as a footgun" note was never
  actually committed), and no `kit/docs/` page cross-referenced it — so there were no
  stale cross-refs to unwind beyond the TODOS split itself. The new HEAD-race TODOS entry
  inlines the key observations (Phase 2→2.5 HEAD jump, branch-ref deletion + `git branch -f`
  recovery, byte-identical regression hazard) so they survive independently of the
  Phase-4.0 FRICTION-LOG fold. PLAN.md Active-row removal + FRICTION-LOG `core.bare` fold
  into BUILD-LOG left for Phase 4.0 per orchestrator scope.
