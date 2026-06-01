# Tasks: init-devshop-mtime-bump

## Task: T1 — content-aware cmp -s guard on manifest [locked] install loop

**Hat**: BE (root-only container-boot script)
**Depends on**: none
**Blocks**: T2, T3
**Done when**: the manifest `[locked]` refresh loop runs `install -D` only when `cmp -s "$src" "$dst"` reports a difference (missing dst → exit 2 → still installs); all three Test-8-pinned substrings remain textually intact; bats Test-8 stays green.
**Risk**: medium (security-critical boot path; test-preservation constraint)
**Status**: done

## Task: T2 — ownership-idempotent guards on chown/chmod lock steps

**Hat**: BE
**Depends on**: T1
**Blocks**: T3
**Done when**: all five lock sites gate `chown`/`chmod` on a `stat -c '%U:%G %a'` mismatch against `root:root NNN`; sticky-bit `[locked-dir]` loops untouched; in-script comment block updated to note conditional refresh + lock; `set -euo pipefail` safety preserved.
**Risk**: medium
**Status**: done

## Task: T3 — bats regression tests for both guards

**Hat**: BE (test)
**Depends on**: T1, T2
**Blocks**: none
**Done when**: two new Test-8-family `@test` blocks appended to `kit/tests/manifest-lifecycle.bats` (cmp -s guard + stat-tuple guard); full bats suite green.
**Risk**: low
**Status**: done

## Decisions

- **T1 (docs-coverage guard)**: The pre-commit docs-coverage guard requires a
  catalog guide doc staged alongside any `scripts` change; the in-script comment
  alone does not satisfy it. Updated the `[locked]` row in
  `kit/docs/guide/architecture.md § File lifecycle` (it described an
  unconditional "refreshed every container start") to note the content-
  conditional refresh — an accurate doc-drift fix, not a guard-appeasing edit.
  Did the same in T2 for the firewall-extras "always-chown" paragraph.
- **T1 comment block**: Split the in-script comment-block doc touch across T1
  (content-conditional sentence) and T2 (ownership-conditional sentence) so each
  atomic commit carries its own doc update and clears the docs-coverage guard,
  rather than landing the whole comment in T2 (which would block T1).
- **tasks.md + clean-tree guard**: Staged `tasks.md` into the T1 commit (the
  clean-tree guard flags it as untracked otherwise); committed it once with T1,
  then it tracks normally.
