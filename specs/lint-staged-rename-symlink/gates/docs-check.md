## Gate 1: docs-check

**Scope**: reference docs (`kit/docs/guide/*.md`, `CLAUDE.md`) vs diff on `main...HEAD`.

The diff adds `--no-stash` to both pre-commit hooks, disabling lint-staged's `git stash` backup. Several guide passages now describe behavior that no longer occurs.

### Finding 1 — `kit/docs/guide/hooks.md` line 55: step list says `pnpm exec lint-staged`

The ASCII tree (§ 2 overview) shows `2c. pnpm exec lint-staged` without `--no-stash`. Should read `pnpm exec lint-staged --no-stash` to match the actual hook.

**Severity**: low (cosmetic accuracy in reference tree).

### Finding 2 — `kit/docs/guide/hooks.md` line 138: table row says `pnpm exec lint-staged`

The blocking-hooks table shows the bare command. Should include `--no-stash`.

**Severity**: low (cosmetic accuracy in reference table).

### Finding 3 — `kit/docs/guide/hooks.md` lines 156: stash behavior paragraph is factually wrong

> "Both tasks modify files, so lint-staged's default `stash: true` behavior fires on every pre-commit: a backup of staged + unstaged state is created via `git stash create` and stored under a `refs/lint-staged/*` namespace…"

With `--no-stash`, lint-staged no longer creates any stash backup. This paragraph describes behavior that is now disabled. It should be updated to note that `--no-stash` is passed, the stash backup is disabled, and the `refs/lint-staged/*` machinery no longer runs.

**Severity**: medium (misleading — someone debugging a stash issue would read this and look for `refs/lint-staged/*` activity that no longer exists).

### Finding 4 — `kit/docs/guide/hooks.md` lines 319: "Recovering a vanished stash" says lint-staged is "the leading suspect"

> "The pre-commit lint-staged backup mechanic (§ 2 — lint-staged config) is the leading suspect — it uses `git stash create` machinery for its own backup and runs on every commit"

Now that `--no-stash` disables the backup, lint-staged no longer calls `git stash create` during pre-commit. The "runs on every commit" claim is false. Should note the backup mechanic is now disabled via `--no-stash`, which narrows the suspect surface (cross-reference: the TODOS entry and SKILL.md already note this).

**Severity**: medium (misleading investigation guidance — someone would chase a suspect that's been eliminated).

### Finding 5 — `kit/docs/guide/hooks.md` line 344: prevention section says stashes "still at risk if lint-staged fires"

> "Operator stashes made BEFORE invoking the skill are still at risk if lint-staged fires during the merge."

With `--no-stash`, lint-staged no longer touches the stash. This risk statement is no longer accurate.

**Severity**: medium (overstates residual risk, could cause unnecessary workarounds).

### Finding 6 — `CLAUDE.md` line 113: known footgun says lint-staged stash machinery is "the leading suspect"

> "Lint-staged's pre-commit stash-backup machinery is the leading suspect; root cause is still under investigation."

Should note that `--no-stash` now disables lint-staged's stash backup, reducing the suspect surface. The footgun entry should still exist (the vanishing-stash bug is not confirmed closed), but the characterization of lint-staged as "leading suspect" with active stash machinery should be updated to reflect that the machinery is now off.

**Severity**: medium (stale investigation guidance in the highest-visibility doc).

### Finding 7 — `kit/docs/guide/architecture.md` line 217: migration-commit gotcha mentions lint-staged's stash/restore

> "`git rm --cached` combined with lint-staged's stash/restore can delete files from disk if they're gitignored."

With `--no-stash`, lint-staged no longer performs stash/restore. The migration-commit advice to use `--no-verify` is still sound as a general precaution, but the stated mechanism (lint-staged stash/restore) no longer applies.

**Severity**: low (the advice `--no-verify` is still correct; only the stated mechanism is outdated).

---

## Dismissals

No findings dismissed. All 7 findings are doc-accuracy issues caused by the `--no-stash` change making existing prose factually incorrect. None are pre-existing issues unrelated to the diff.
