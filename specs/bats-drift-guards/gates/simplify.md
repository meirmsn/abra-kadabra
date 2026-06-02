## Gate 4: /simplify

Code-quality pass (reuse / simplification / efficiency / altitude) over
`git diff origin/main...HEAD`, scoped to the two substantive bats blocks in
`kit/tests/structural-invariants.bats`:

1. The skill-autodetect branch in the `wiring: every devshop script is wired` `@test`.
2. The new `@test "grep-drift: every '# pins:' annotation still resolves in its target file"`.

(The 3 seed `# pins:` annotations and the docs/tracker edits carry no logic and
were not in quality scope.)

**Result: clean pass — no changes warranted.**

The two blocks are tractable and idiomatic for this file. They reuse the file's
established conventions: `local` declarations, the defensive
`[ -z "$x" ] && continue` loop guard (identical to the wiring test's
`[ -z "$script" ] && continue`), per-iteration `grep` filtering, and
fixed-string `grep -qF` / `grep -qwF` matching. No dead state, no copy-paste
variation, no redundant I/O, no leftover locals from the `infra_scripts`
pruning (`skills_dir` is declared and consumed; `root` feeds only `tests_dir`
and the `"$root/$path"` resolve).

Altitude is a net improvement, not a regression: the autodetect branch _removes_
two hardcoded entries (`reconcile-task-commits.sh`, `virtiofs-rebase.sh`) from
`infra_scripts` and replaces them with a general SKILL.md-basename mechanism —
de-special-casing, the right depth. The annotation-parsing in the grep-drift
test (`${line#*# pins: }` after a marker-anchored grep, single `%% :: ` /
`#* :: ` split) is already the simple form; splitting on colons would be more
complex, not less.

### Dismissals

- **`grep-drift` test uses `git rev-parse --show-toplevel` while every other
  test in the file uses `$DEVSHOP` (`/devshop`).** Surfaced under the
  reuse/consistency angle as a candidate to switch to `$DEVSHOP` for uniformity.
  rationale: the divergence is deliberate and load-bearing — switching would
  change behavior, so it is out of /simplify scope (quality only, no behavior
  change). The guard must resolve against the _current worktree_ root so it
  catches `# pins:` annotations that exist only in the worktree at the editing
  commit (the whole point of firing at the commit that introduces the drift);
  `$DEVSHOP` would scan the canonical `/devshop` tree and miss worktree-local
  annotations. It also matches the pre-commit bats runner's own root resolution
  (`check-bats-devshop.sh` derives `GIT_ROOT=$(git rev-parse --show-toplevel)`),
  so the two are consistent with each other, just not with the canonical-tree
  tests that assert against fixed `/devshop` paths.
- **Two-condition malformed-annotation guard
  (`[ "$path" = "$annotation" ] || [ "$literal" = "$annotation" ]`).** When no
  `::` separator is present, both halves are true, so the `||` is belt-and-
  suspenders. rationale: harmless, cheap, and arguably clearer as a paired
  check; collapsing it is churn with no readability or efficiency payoff.
- **Verbose `NOTE:` comment block explaining the pruning-as-validation rationale
  in the wiring test.** rationale: documents a genuinely non-obvious design
  choice (why the two scripts were removed from `infra_scripts` rather than left
  in); trimming it is prose churn the gate brief explicitly warns against.

Tests confirmed green before the pass (no edits made):
`kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats` → 62/62 ok
(test 62 = the new grep-drift guard).
