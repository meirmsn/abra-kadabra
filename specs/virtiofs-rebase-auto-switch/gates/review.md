## Gate 6: /review

Scope: `git diff 1408150..HEAD`, adversarial focus on `kit/scripts/virtiofs-rebase.sh`
(the phantom-vs-real-conflict discrimination core) plus the `/ak-merge-devshop`
§ Phase 1.0 caller wiring. Lens: gstack `/review` (SQL safety / trust boundaries /
conditional side effects / structural correctness), adapted to a shell merge-helper.

Verdict: the discrimination core is correct and well-guarded. No high-severity
correctness bug found in the script. Findings below are medium/low — one (F2) is a
real behavioral gap on a genuine-conflict edge case (rerere/exec/empty-stop), the rest
are robustness/hardening nits. The SKILL.md § Phase 1.0 caller wiring was independently
verified against the script's exit-code contract (F10) — exit 0/10/11/1/64 all
correctly handled, `$WORKTREE_PATH` empty-vs-set pass-through correct.

Severity tally: high=0 medium=1 (F2) low=3 (F1, F3, F4) + 6 positive confirmations
(F5-F10). Nothing blocks the gate; F2 + F3 warrant either a one-line code comment / spec
scope note or a follow-up bats case, operator's call.

### Findings

**F1 — `merge --no-edit` can succeed with conflicts when `merge.conflictstyle`/
auto-resolution leaves a clean tree, but the more pressing case: rung 3 captures
stdout+stderr into a command substitution, which strips the merge's progress output
and can mask a non-conflict failure mode.** Severity: low. Mechanical: yes.
Rung 3 runs `merge_err=$("${GIT[@]}" merge "$ANCHOR" --no-edit 2>&1) || rc=$?`. On a
genuine conflict, `git merge` writes "CONFLICT" lines to stdout and exits non-zero;
those are captured (not shown) and then discarded because the code branches to
`has_unmerged_paths` → exit 11 without echoing `merge_err`. That is fine for the
conflict path. The only consumer of `merge_err` is the final `error:` branch (exit 1).
Net: behavior is correct, but capturing the conflict output into a variable that is
then dropped is slightly wasteful and means an operator who later inspects the helper's
own stdout sees only `RESULT: conflict-merge` with no conflict detail. Low-risk; the
caller re-derives conflict files itself. Optional: on the exit-11 branch, also surface
the captured `merge_err` to stderr so the run log shows which paths conflicted.

**F2 — A genuine _first-rung_ rebase conflict that git resolves via `rerere` (or that
leaves the rebase stopped with the conflict already staged) would show NO unmerged
paths, so `has_unmerged_paths` returns false and the script wrongly routes the real
conflict into the recovery ladder.** Severity: medium. Mechanical: no.
The discrimination axiom is "non-zero rebase + no unmerged paths ⇒ phantom." This holds
for the two documented phantom flavors. But `git rebase` can also stop non-zero with a
_clean index_ in real scenarios: (a) `rerere` auto-staged a previously-recorded
resolution and rebase halts for confirmation; (b) an `exec` line failed; (c) an empty
commit caused a stop (`--empty=stop`-style). In each, `git diff --diff-filter=U` is
empty, so the helper treats it as phantom, runs `rebase --abort`, and retries — losing
the rerere-resolved state / masking the exec failure. Default devshop rebases are plain
`git rebase <anchor>` with no `exec` and rerere typically off, so the practical blast
radius is small, but the axiom as written is "no unmerged paths ⇒ safe to abort+retry,"
which is broader than "no unmerged paths ⇒ phantom." Recommend either (a) narrowing the
phantom signal to _also_ require the rebase did not advance (e.g. HEAD unchanged /
`rebase-merge/done` empty), or (b) documenting in the spec that rerere/`exec`/empty-stop
are explicitly out of scope and the helper assumes plain `rebase <anchor>`. At minimum
this assumption deserves an inline comment at the rung-1 discrimination branch, since a
future caller passing rebase options would silently break the axiom.

**F3 — `rebase_in_progress` checks `rev-parse --git-path` dir existence, but in a
_worktree_ the rebase state lives under `$GIT_COMMON_DIR/worktrees/<wt>/rebase-merge`,
and `rev-parse --git-path` run via `git -C "$wt"` resolves it correctly — verify the
`-d` test path is the resolved absolute, not a relative `.git/...`.** Severity: low.
Mechanical: yes (verification, not a code change unless it fails).
`mdir=$("${GIT[@]}" rev-parse --git-path rebase-merge ...)`. With `git -C "$wt"`,
`--git-path` returns a path resolved against the worktree's gitdir (which for a linked
worktree is `.../worktrees/<name>`), and the value is printed relative to the worktree
cwd OR absolute depending on git version. The subsequent `[ -d "$mdir" ]` is evaluated
in the _script's_ cwd, not the worktree's. If git returns a relative path
(e.g. `worktrees/foo/rebase-merge` or `.git/worktrees/...`) and the script's cwd is not
the worktree root, the `-d` test resolves against the wrong directory → false negative →
`abort_rebase_if_any` no-ops when a rebase IS in progress → rung 2 then runs `rebase`
on top of an in-progress rebase, which git refuses with a different error. In practice
`git rev-parse --git-path` returns paths relative to `GIT_DIR` printed as absolute when
`-C` differs from cwd on modern git, so this likely works, but it is the single most
load-bearing path-resolution in the worktree mode and is NOT exercised by a unit test
that runs git in a real linked worktree with an interrupted rebase. Recommend a bats
case that (1) creates a linked worktree, (2) forces a real mid-rebase stop, (3) asserts
`rebase_in_progress` returns 0 from the script invoked from /devshop cwd with the
worktree path as arg2. Until then, treat worktree-mode abort as unverified.

**F4 — `set -euo pipefail` + `local out=$(...)` masks the assignment's exit status,
which is intended here, but the same pattern in `rebase_in_progress` means a `rev-parse`
failure is swallowed and indistinguishable from "no rebase dir."** Severity: low.
Mechanical: no.
`mdir=$("${GIT[@]}" rev-parse ... 2>/dev/null || true)`. If the git invocation itself
fails for an unrelated reason (corrupt repo, bad `-C` path), `mdir` is empty and the
function returns "no rebase in progress," so `abort_rebase_if_any` silently skips. This
is the safe direction (never aborts spuriously) but means a broken `-C` path produces a
confusing downstream failure rather than a clear "bad worktree path" error. Minor;
acceptable for a recovery helper. Consider validating arg2 is a dir up front
(`[ -d "$WORKTREE_PATH" ]` when non-empty → else exit 64) so a typo'd worktree path
fails loudly at the usage boundary instead of producing phantom-looking behavior.

**F5 — Exit-code contract is internally consistent (0/10/11/1/64) and matches the
header table; no branch returns an undocumented code.** Severity: n/a (positive
confirmation). Traced every exit: 64 (arg count), 0 (rung1/rung2/rung3 success), 10
(unmerged after rung1 OR rung2), 11 (unmerged after rung3 merge), 1 (rung3 non-conflict
failure). Rung 2's exit-10 reuses `conflict-rebase` correctly because a conflict that
surfaces only under reduced-stat comparison is still a genuine rebase conflict the
caller resolves with `rebase --continue`. No path falls through without an explicit exit
(rung 3 ends in `exit 1`). Good.

**F6 — `set -e` vs expected-nonzero git calls: correctly neutralized.** Severity: n/a
(positive confirmation). Every fallible git call uses the `rc=0; cmd || rc=$?` capture
form (rungs 1/2/3) or `... || true` (helpers), so `set -e` cannot kill the script before
the discrimination branch runs. This is the highest-risk interaction the task flagged
and it is handled correctly on all three rungs.

**F7 — Inline `-c core.checkStat=minimal -c core.trustctime=false` placement is
correct.** Severity: n/a (positive confirmation). The flags appear after the `-C "$wt"`
prefix (inside `"${GIT[@]}"`) and before the `rebase` subcommand — i.e.
`git -C <wt> -c core.checkStat=minimal -c core.trustctime=false rebase <anchor>`. Git
parses `-C` then `-c` then the subcommand, so this is valid and the config is scoped to
the single retry invocation only (not repo-global). Matches D2 and the CLAUDE.md footgun
recipe.

**F8 — `git rebase --abort` with no rebase in progress is correctly guarded.**
Severity: n/a (positive confirmation). `abort_rebase_if_any` gates the abort behind
`rebase_in_progress`, and even then suffixes `|| true`, so a stray abort cannot trip
`set -e`. (See F3 for the residual worktree-path resolution risk on the guard itself.)

**F9 — Arg/quoting: `WORKTREE_PATH="${2:-}"` + `GIT=(git -C "$WORKTREE_PATH")` is
correct; empty arg2 → bare `git` in cwd.** Severity: n/a (positive confirmation). The
`[ -n "$WORKTREE_PATH" ]` branch ensures an empty/absent arg2 never produces
`git -C ""` (which would error). Array form preserves a worktree path containing spaces.
`$ANCHOR` is always quoted at use. Usage guard rejects `>2` args. Clean.

**F10 — SKILL.md § Phase 1.0 caller wiring is correct and complete.** Severity: n/a
(positive confirmation). Verified against `.claude/skills/devshop/merge-devshop/SKILL.md`
lines 684-764. The call site is `bash /devshop/kit/scripts/virtiofs-rebase.sh "$ANCHOR"
"$WORKTREE_PATH"` (line 691) — `$WORKTREE_PATH` is passed quoted as arg2; when it is
empty (merging from /devshop) the helper's `${2:-}` + `[ -n ... ]` branch falls through
to bare `git`, and when set (linked worktree) the helper routes every git via
`-C "$WORKTREE_PATH"`. The `rc=0; ... || rc=$?` capture mirrors the helper's own
`set -e` neutralization, so the caller never dies before its `case`. The `case`
dispatches all five contract codes: `0` → proceed (`: ;;`), `10` → `"${GIT_CMD[@]}"
add` + `rebase --continue` (matches conflict-rebase), `11` → `add` + `commit -F
/tmp/merge-commit-msg.txt` (matches conflict-merge), and `*` → echo + `exit "$rc"`
(covers both `1` and `64`). The exit-10/11 handlers use the `GIT_CMD` array (re-derived
at line 668-669 with the same `-C "$WORKTREE_PATH"` rule), so resolution lands in the
correct worktree. One minor doc nit (not a bug): the `*` branch's comment names exit `1`
and `64`, but `64` (usage error) can only occur on a wiring bug in the call itself — it
is correctly surfaced-and-halted rather than silently swallowed, which is the right
posture. Caller half of the contract fully honors the script half. No finding.

### Dismissals

- **"Rung 2 reuses exit 10 / `conflict-rebase` for a reduced-stat conflict — is that a
  different state the caller mishandles?"** — Dismissed. A conflict that only surfaces
  under reduced-stat comparison is still a normal in-progress rebase with unmerged
  paths; the caller's `add` + `rebase --continue` path resolves it identically to a
  rung-1 conflict. No separate vocabulary needed.
- **"`merge --no-edit` could open an editor and hang in CI."** — Dismissed. `--no-edit`
  explicitly suppresses the editor; a non-conflict merge commit uses the default message
  non-interactively.
- **"`echo` for RESULT lines should be `printf` for portability."** — Dismissed as
  noise. The strings are fixed literals with no leading `-`/escapes; `echo` is safe here
  and matches the rest of kit/scripts style.
- **"Should the helper `set +e` around the git calls instead of the capture idiom?"** —
  Dismissed. The `rc=$?` capture is the idiomatic, locally-scoped neutralization and is
  clearer than toggling `set -e` on/off across rungs.
