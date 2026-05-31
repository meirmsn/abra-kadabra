## Gate 4: /simplify

Scope: substantive new code in `git diff 1408150..HEAD` —
`kit/scripts/virtiofs-rebase.sh`, `kit/tests/util-virtiofs-rebase.bats`,
`.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0`.

Mode: REPORT-ONLY (no edits / commits). Lens: reuse, simplification,
efficiency, dead-code, altitude. Conservative bar — only net-positive,
low-risk changes flagged. This code is already tested (full suite 0 failures)
and passed a fresh-eyes verification, so the bar is high.

### Findings (0)

`pass` — nothing to change. The diff is already at the right altitude:

- The script (`kit/scripts/virtiofs-rebase.sh`) is a linear 3-rung ladder with
  three small, single-purpose helpers (`has_unmerged_paths`,
  `rebase_in_progress`, `abort_rebase_if_any`). No duplication worth factoring,
  no dead code, no inefficiency.
- The test file (`kit/tests/util-virtiofs-rebase.bats`) uses ONE env-var-driven
  `git` stub (the `STUB` heredoc, lines 54–148) shared across all stub-harness
  cases via `install_git_stub` + `run_stub`, plus a shared real-repo fixture in
  `setup()`. That is already the DRY design — there is no duplicated stub to
  collapse.

### Dismissals

- **`kit/scripts/virtiofs-rebase.sh` — no change.** The three rungs are explicit
  and readable; each `abort_rebase_if_any` + capture-then-branch
  (`rc=0; "${GIT[@]}" … || rc=$?`) is load-bearing for the `set -e` interaction
  documented in the header. The rungs differ enough (plain rebase vs `-c`-hardened
  rebase vs merge; rebase-abort vs merge-abort; exit 10 vs 11) that a loop/table
  would need per-rung data and obscure the ladder it documents. Linear form is
  correct altitude for a 3-rung helper. The three helpers each have one caller
  pattern but earn their names (the comments explaining the `set -e` guard would
  otherwise inline-clutter the ladder). n/a.

- **`make_fake_git` / repeated real-repo setup in the bats file — no change.**
  The real-repo cases (1, 5, 13, 15, 17, 18) each re-build a main-advance +
  feat-commit scenario inline. This _could_ be factored into a 2–3 line helper
  (e.g. `advance_main_and_feat`), but the cases vary (clean FF vs genuine
  conflict on `shared.txt` vs ancestor-assertion vs tip-moved assertion) and the
  inline form keeps each test's arrange-block self-contained and readable in
  isolation — the standard bats idiom. Net of a helper would be marginal and
  trades readability for ~15 saved lines across 6 tests. Below the conservative
  bar for a REPORT-ONLY mechanical fix. n/a.

- **The stub `git`'s arg-stripping loop (lines 74–83) + the separate
  checkStat-flag scan (lines 64–72) — no change.** They serve different jobs
  (find the subcommand vs detect the retry flags); merging them would entangle
  two concerns. The stub is test scaffolding, already minimal for the dispatch
  it must do. n/a.

- **`SKILL.md § Phase 1.0` wiring — no change.** Prose/doc-only edit replacing
  the ~70-line hand-walked ladder with the `bash kit/scripts/virtiofs-rebase.sh
"$ANCHOR" "$WORKTREE_PATH"` invocation + a clean exit-code `case`. This is
  itself a large simplification (the point of the feature); the remaining prose
  is correctly scoped and references the script header for the full contract
  rather than restating it. Nothing to simplify. n/a.

- **Earlier draft of this gate flagged a duplicated `FAKE` heredoc — RETRACTED.**
  Re-verification (`grep -n FAKE` → 0 matches) confirmed the test file has a
  single env-driven `STUB` heredoc, not two duplicated fakes. No such finding
  exists. n/a.
