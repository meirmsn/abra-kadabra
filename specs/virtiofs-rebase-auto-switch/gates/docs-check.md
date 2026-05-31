## Gate 1: docs-check

**Mode**: devshop-self. **Range**: `1408150b..HEAD` (2 commits). **Verdict**: PASS — no findings.

### Scope of behavior change

New `kit/scripts/virtiofs-rebase.sh` mechanizes the virtiofs phantom-rebase recovery
ladder (plain rebase → retry with `-c core.checkStat=minimal -c core.trustctime=false`
inline → fall back to `git merge`; exit 0 on any success, 1 if all paths fail). Wired
into merge-devshop SKILL § Phase 1.0, registered in structural-invariants.bats, and the
doc closing-convention applied (CLAUDE.md footgun rewrite, workflow.md merge row,
kit/TODOS.md mechanize-entry delete, FRICTION-LOG F244 resolve).

### Coverage checklist

1. **Helper behavior + invocation documented where a future reader looks** — PASS.
   - merge-devshop SKILL § Phase 1.0 (lines 55-64) gives the exact invocation
     (`bash kit/scripts/virtiofs-rebase.sh <anchor>`) plus exit-code handling
     ("Exit code 0 on success (rebase or merge), non-zero if both paths fail — halt
     and investigate"). Matches the script's actual contract (exits 0 on rebase /
     rebase+flags / merge success, 1 otherwise).
   - CLAUDE.md § Known Footguns (line 207) gives the operator first-action
     (`bash /devshop/kit/scripts/virtiofs-rebase.sh <anchor>`) and a one-line summary
     of the ladder, with a Full-recipe pointer to SKILL § Phase 1.0.

2. **CLAUDE.md footgun rewritten to imperative-present, points at helper** — PASS.
   First-action is now imperative ("run `bash .../virtiofs-rebase.sh <anchor>`") rather
   than the prior manual-`-c`-dance conditional prose. No stale "retry inline with
   `git -c ...`" instruction remains as the primary action.

3. **workflow.md merge-devshop row reflects mechanized ladder** — PASS.
   Row at line 197 now reads `bash kit/scripts/virtiofs-rebase.sh <anchor>` (retries
   inline `-c` flags, falls back to `git merge`) with the helper path in the
   mechanism column — was the manual `-c` recipe + "manual" before.

4. **No doc describes the OLD manual-only ladder as current state** — PASS.
   Full markdown sweep for `stat-cache` / `checkStat` / `trustctime` /
   `would be overwritten`: only CLAUDE.md:207 and SKILL.md:55,62, both updated to the
   helper-first form. No OVERVIEW / FAQ / ops / conventions / hooks reference exists.

5. **Closing-convention honored** — PASS.
   - `grep -rni "mechanize the virtiofs" kit/ CLAUDE.md` → empty (TODO body gone).
   - kit/TODOS.md "Mechanize the virtiofs phantom-rebase ladder" entry deleted.
   - FRICTION-LOG F244 (line 42-44): Status `resolved (2026-05-30)` with mechanization
     note + SKILL § Phase 1.0 cross-ref + branch ref. Was `open`.
   - No orphan cross-refs: every reference to the helper resolves to an existing path;
     SKILL ↔ CLAUDE ↔ workflow ↔ FRICTION-LOG pointers are mutually consistent.
   - structural-invariants.bats adds 4 invariants pinning the cross-references
     (helper exists+executable, referenced in SKILL, referenced in CLAUDE, TODO absent)
     so future drift is caught deterministically.

### Notes (non-findings)

- The live (system-reminder) CLAUDE.md snapshot carries an extra clause ("the same form
  unsticks cherry-pick / am") not present at this branch's base or HEAD; that clause is
  outside this diff's range and the branch-local entry is internally consistent. The
  helper intentionally scopes to rebase only — no doc in-range claims it covers
  cherry-pick / am, so there is no stale-coverage mismatch within this diff.

## Dismissals

None
