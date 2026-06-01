## Gate 4: /simplify

- Result: pass (no changes applied)

Reviewed the changed code for reuse / simplification / efficiency / altitude.
Primary surface: `kit/scripts/preship/audit-tracker-only.sh` (~25 lines of code
under a documentation-heavy header). Secondary: the SKILL.md Step 1 prose
addition (descriptive docs, not refactorable code).

### Reuse

No existing helper performs git-range tracker classification — nothing to
deduplicate against. The `case`-glob tracker set is the single source of truth;
it is mirrored (not duplicated as code) in the workflow.md note.

### Simplification — candidates considered and rejected

- **Collapse the `while`/`case` loop into a `grep -vE` regex one-liner.**
  Rejected: the header deliberately chose `case` globbing "so dash-sourcing is
  safe" (no regex engine, mawk/dash-clean). A regex rewrite would trade that
  guarantee for terseness and complicate the empty-diff and diff-failure
  branches. Not a genuine win.
- **Drop the explicit `if ! CHANGED=$(git diff ...)` capture.** Load-bearing:
  `set -e` does NOT catch a failure inside command-substitution used as
  heredoc input, so the explicit check is what produces the safe exit-1 on an
  unresolvable range (covered by the bats case at line 83). Cannot remove.
- **Pipe `$CHANGED` into the loop instead of the `<<EOF` heredoc.** Rejected:
  a pipe runs the loop in a subshell, so `exit 1` would exit the subshell, not
  the script — silently breaking the first-source-path short-circuit. The
  heredoc is the correct POSIX form here.

### Efficiency

Single `git diff` invocation; early `exit 1` on the first non-tracker path
(no full-scan). Already optimal for the task.

### Altitude

Single responsibility (classify → exit code), no audit/scaffold/dispatch logic
leaking in (the "Does NOT" header enforces this). Appropriately scoped — no
over-abstraction, no premature generalization.

Conclusion: the helper already sits at the boring-solution baseline the
convention prescribes. No behavior-preserving simplification exists that
wouldn't sacrifice dash-safety or correctness. No commit made; bats not re-run
(no code change).

## Dismissals

None
