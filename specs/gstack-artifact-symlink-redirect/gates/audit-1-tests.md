Tests look solid — no findings.

## Coverage map (section A)

Source changes in range and their test coverage:

- `kit/scripts/init-devshop.sh` (+25 lines, new "Gstack projects symlink" block) — covered by `kit/tests/gstack-projects-symlink.bats`:
  - Structural assertions (tests 1-7): each of `GSTACK_PROJECTS_LINK`, `GSTACK_PROJECTS_DIR`, `mkdir -p`, `chown -R`, `ln -sfn`, `chown -h`, migration guard, and post-devshop-self-guard ordering are individually asserted against the source script.
  - Behavioral assertions (tests 8-9): the symlink block is extracted into a sandbox and run with synthetic `$WS` / `$HOME` paths; verifies (a) write-through-symlink lands in workspace tree, (b) pre-existing real dir is migrated then linked.
- `template/.gitignore` (+12 / -4 lines, widened re-include patterns) — covered:
  - Structural assertions (tests 10-12): the five literal lines (`.gstack/*`, `!.gstack/projects/`, `.gstack/projects/**`, `!.gstack/projects/**/`, four `!.gstack/projects/**/*.{md,html,png,json}` re-includes) all asserted with `grep -Fx`.
  - Behavioral assertion (test 14): throwaway git repo with the actual template gitignore, sample artifacts at multiple depths (one-level, deep `designs/<screen>-YYYYMMDD/`, slash-in-branch `fix/foo/*.md`), plus runtime noise (`.jsonl`, `sessions/`, `browse.json`). Uses `git check-ignore -q` exit codes to assert tracked-vs-ignored for each.

No source files in the range lack test coverage.

## Section B — Test quality

- **Weak assertions**: none. Every behavioral test asserts concrete content (`[ "$output" = "design doc" ]`, `[ "$output" = "legacy content" ]`) or specific file existence at exact paths, not `-n "$x"` / `-z "$x"`. Structural tests use exact-line `grep -Fx` rather than substring matches.
- **Missing error/invalid input tests**: n/a — the new code is a deterministic infra block (mkdir + ln -sfn + cp), not an API surface. No throw paths to test.
- **Untested auth boundaries**: n/a — no RLS / auth surface in scope.
- **Implementation detail tests**: borderline acceptable. The structural assertions (tests 1-7) match against exact `grep` patterns of script lines — they will break if the block is refactored without changing behavior (e.g., renaming `$GSTACK_PROJECTS_LINK` to `$GSTACK_LINK`). However, behavioral tests 8-9 + 14 cover the contract independently, so a refactor that breaks the structural tests but preserves behavior would still pass the behavioral ones. This is acceptable for a script-not-binary surface where the structural tests serve as documentation of the expected idiom; no finding.
- **Missing boundary conditions**: the migration path is tested for the "pre-existing real dir with content" case; the "no pre-existing dir" case is exercised by test 8 (which only creates the workspace dir, no $HOME/.gstack/projects pre-existing). The "symlink already exists, pointing elsewhere" case is implicitly covered by `ln -sfn` semantics (force-replace) but not explicitly asserted. Not flagging — `ln -sfn` is well-understood and the structural test asserts the `-sfn` flag is present.
- **Shape-only assertions**: n/a — all assertions are against observable behavior (file existence, file content, symlink resolution, `git check-ignore` exit codes), not internal state shape.
- **Skipped tests**: none. `git diff` of test file shows zero `.only` / `.skip` / `skip()` patterns.

## Section C — Bypass trailers

Harvest of `Tests-Coverage-Bypass:` trailers in `d3a690670525ce336c3d9c95002c8e7e7bb256ee..a20c2002441663fb94a6156fbb80afaa2b8f1443`: **zero rows**. Nothing to verify / defer / escalate.

## Summary

high=0 medium=0 low=0
