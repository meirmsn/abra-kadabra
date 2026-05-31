<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: merge-devshop-worktree-hooks -->
<!-- date: 2026-05-30 -->

# Spec: merge-devshop-worktree-hooks

**Sources:**

- `PLAN.md § Planned (v0)` row `merge-devshop-worktree-hooks` — primary scope
- `kit/TODOS.md § /ak-merge-devshop + worktree convention: pre-commit hooks don't fire in worktrees` (l.490–492) — the (a)–(d) option set
- `kit/FRICTION-LOG.md § Pre-commit hooks don't fire in linked worktrees (husky uninstalled)` (Impact 4) — symptom + worked bites
- `CLAUDE.md § Parallel work via linked worktrees` — the worktree-add recipe (edit target)
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2` — squash commit site (gitleaks gate target)
- `.husky/pre-commit:29` — canonical `gitleaks protect --staged --redact` invocation
- `kit/tests/util-ak-merge-devshop.bats § Section G` — test surface for the new gate

Close a silent gate-skip on the default parallel-work path: commits made inside a
`git worktree add .worktrees/<topic>` worktree run NO pre-commit hook (husky's
`.husky/_` is gitignored, regenerated only by `pnpm install`), so gitleaks,
doc/test coverage, the branch guard, and the CLAUDE.md gates all silently no-op
until merge — and `/ak-merge-devshop`'s squash commit, when created in the
worktree, never scans the delta for secrets. This PR makes hooks fire in-worktree
(primary) and adds a merge-time gitleaks compensating gate (defense-in-depth).

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — Phase 4.0 copies
Headline into BUILD-LOG `Headline:` and Detail into `Summary:`. (Devshop mode:
no PR body, no Phase 7 / `/ak-go-live` — BUILD-LOG is the downstream surface.)
Verified against the diff at Phase 6 Gate A/B equivalent (devshop: the
`/ak-merge-devshop` Phase 1 audit).

### Headline (user-facing)

Parallel-work worktrees now run the same safety checks as the main repo, and the
merge step double-checks for leaked secrets before any change lands.

### Detail (team-facing)

The worktree-add recipe now runs `pnpm install` so husky pre-commit hooks
(gitleaks, doc/test coverage, branch guard, CLAUDE.md gates) fire in-worktree
instead of silently no-opping. As a belt-and-suspenders net, `/ak-merge-devshop`
now runs a gitleaks scan on every path that lands a branch on `main` —
`protect --staged` on the squash delta, and a commit-range history scan on the
rename-symlink ff-merge fallback — so secrets can't reach `main` even from an
off-convention worktree where the install step was skipped.

---

## Decisions (resolved at spec time)

Six `/ak-spec`-time decisions resolved in Phase 0 with the operator. Recorded
below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking. The operator's governing directive: **do (b) as the primary fix +
(d) as defense-in-depth, and don't let it land as a-only (which reads as "done"
but leaves the gate skipped). (b) alone technically closes the gap; (d) is the
cheap belt-and-suspenders that makes it robust to off-convention worktrees.**

### D1: Which fix options ship?

**Decision:** (b) primary + (d) defense-in-depth. (a)'s doc-accuracy correction
folds in as a _consequence_ of shipping (d) (the docs must stop asserting a false
safety net and describe the real posture), NOT as the whole fix. (c)
(session-start.sh empty-`.husky/_` warning) is deferred to a slimmed FRICTION-LOG
"optional follow-up" stub.

**Rationale:** Operator directive. (b) closes the gap on-convention; (d) is the
unconditional net for off-convention worktrees where the install step was skipped.
Landing a-only would read as "done" while leaving the gate skipped.

### D2: (b) — where + what command?

**Decision:** Append `&& (cd .worktrees/<topic> && pnpm install)` to the
worktree-add recipe in `CLAUDE.md § Parallel work via linked worktrees`; mirror in
`kit/docs/guide/workflow.md` if it carries the recipe.

**Rationale:** `pnpm install` runs husky's `prepare` script → regenerates
`.husky/_` AND populates `node_modules`, so lint-staged/typecheck hooks actually
run rather than just arm. A bare `npx husky` would arm hooks that then crash with
no deps installed.

### D3: (d) — where + what command?

**Decision:** In `merge-devshop SKILL.md § Phase 2`, after `reset --soft "$ANCHOR"`
stages the squash delta and BEFORE `commit -F`: run `gitleaks protect --staged
--redact` from the squash cwd (the worktree when `WORKTREE_PATH` is set, else
`/devshop`). On a finding → halt, surface, do NOT commit.

**Rationale:** Identical invocation to `.husky/pre-commit:29` (same binary
8.30.1, same `.gitleaks.toml`). The soft-reset stages exactly the squash range,
so `--staged` scans exactly the delta. Runs unconditionally → robust to
worktrees where `pnpm install` was skipped, and belt-and-suspenders for the
`/devshop` case. `gitleaks protect --staged` exits non-zero on a finding, which
drives the halt. (Empirical basis: verified-by-analogy to the already-working
pre-commit hook — same flags, same config, same binary.)

### D4: Test surface?

**Decision:** Add bats test(s) to `kit/tests/util-ak-merge-devshop.bats §
Section G` asserting Phase 2 contains the gitleaks compensating-gate step (and
that it runs before the `commit -F`). The CLAUDE.md / workflow.md recipe edits
are doc-only (no test).

**Rationale:** Satisfies "no code without tests" for the SKILL behavioral change;
matches the file's existing grep-assertion style. No existing bats test asserts
the "still fire on the feature-branch commit" text being refined, so D5 causes no
test drift.

### D5: Doc-accuracy correction (the (a) fragment)

**Decision:** Refine Phase 2's "Pre-commit hooks … still fire on the
feature-branch commit" claim to be worktree-accurate (hooks fire where husky is
installed — `/devshop`, or a worktree after `pnpm install` per the recipe — and
the new gitleaks gate scans the delta unconditionally). Update the `CLAUDE.md §
Parallel work` bullet "Pre-commit hooks do NOT fire in a fresh worktree" to
reflect the install-step fix + the merge-time net.

**Rationale:** "Don't let it land as a-only" ≠ "skip the doc fix." The docs must
stop asserting a false safety net and describe the real (b)+(d) posture.

### D6: Tracker closure

**Decision:** Delete the PLAN row `merge-devshop-worktree-hooks` and the
`kit/TODOS.md` entry (l.490–492). Rewrite the `kit/FRICTION-LOG.md` entry to
"shipped (b)+(d); (c) session-start warning remains an optional follow-up" rather
than deleting it outright (since (c) genuinely wasn't shipped). Unwind every
cross-reference to the closed entry in the same PR.

**Rationale:** Per `CLAUDE.md § Closing TODO/ROADMAP entries when a fix ships`.
Keeping a slimmed (c) stub preserves the one unshipped option without leaving a
stale "candidate fixes (pick one)" framing that future sessions would misread as
"still open."

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Product update + Decisions sections above stay
     verbatim. This is devshop-self-mode: no METRICS.md, no DESIGN.md; the
     test surface is bats (kit/tests/), not vitest/Playwright. -->

## In scope

- **(b) primary fix** — append a `pnpm install` step to the worktree-add recipe
  in `CLAUDE.md § Parallel work via linked worktrees` so husky's `prepare` script
  regenerates `.husky/_` and populates `node_modules`, making every pre-commit
  gate (gitleaks, doc/test coverage, branch guard, CLAUDE.md classification/
  placement) fire on in-worktree commits instead of silently no-opping.
- **(d) defense-in-depth gate** — add an unconditional `gitleaks protect --staged
--redact` compensating gate to `merge-devshop SKILL.md § Phase 2`, after the
  `reset --soft "$ANCHOR"` stages the squash delta and before `commit -F`, run
  from the squash cwd (the worktree when `WORKTREE_PATH` is set, else `/devshop`).
  Halts the merge on a finding.
- **bats coverage** — Section G assertion(s) in
  `kit/tests/util-ak-merge-devshop.bats` pinning the gitleaks gate's presence in
  Phase 2 and its ordering before `commit -F`.
- **(a) doc-accuracy correction** (folds in as a consequence of (d)) — refine the
  Phase 2 "Pre-commit hooks … still fire on the feature-branch commit" claim to be
  worktree-accurate; update the `CLAUDE.md § Parallel work` bullet "Pre-commit
  hooks do NOT fire in a fresh worktree"; correct the stale "Pre-commit hooks fire
  identically in worktrees" claim in `kit/docs/guide/security.md:58`.
- **tracker closure** — delete the PLAN row + the `kit/TODOS.md` entry; rewrite the
  `kit/FRICTION-LOG.md` entry to "shipped (b)+(d); (c) remains an optional
  follow-up"; unwind every cross-reference in the same PR.

## Out of scope

- **(c) — `session-start.sh` empty-`.husky/_` warning.** Deferred to a slimmed
  `kit/FRICTION-LOG.md` "optional follow-up" stub (per D1 + D6). (b) makes the
  on-convention path correct and (d) nets the off-convention path, so the
  session-start warning is a nice-to-have, not a gate. Not shipped here; the
  rewritten FRICTION-LOG entry preserves it as the one un-done option so a future
  session can pick it up without the entry reading as "all open."
- **Any change to `kit/scripts/**`hook scripts.** The fix is doc-recipe-only on
the (b) side and SKILL.md-prose-only on the (d) side — no new hook script, no
edit to`.husky/pre-commit` (we mirror its existing invocation verbatim, we do
  not touch it).
- **`kit/docs/guide/workflow.md` recipe mirror.** Verified: workflow.md does NOT
  carry the worktree-add recipe verbatim (its `/ak-merge-devshop` row references
  worktrees but not the `git worktree add … && pnpm install` command). So D2's
  "mirror in workflow.md if it carries the recipe" resolves to **no edit** — Phase
  2 must NOT invent one. (Recorded here so the implementer doesn't hunt for a
  phantom mirror target.)

## Files to create/modify

| File                                                                          | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CLAUDE.md` § Parallel work via linked worktrees (l.63 recipe + l.66 bullet)  | **(b) + (a).** Append `&& (cd .worktrees/<topic> && pnpm install)` to the worktree-add recipe (regenerates `.husky/_` + installs `node_modules` so hooks fire in-worktree). Rewrite the "Pre-commit hooks do NOT fire in a fresh worktree" bullet from the current absolute "do NOT fire … skips every gate" framing to the install-step-fixed posture: hooks fire after the recipe's `pnpm install`, and `/ak-merge-devshop` Phase 2 runs a gitleaks net unconditionally. Imperative present tense (per the closing-trackers convention).                                                                                                                                                                                                                                                                                                                                             |
| `.claude/skills/devshop/merge-devshop/SKILL.md` § Phase 2 (around l.968–1003) | **(d) + (a).** Insert the `gitleaks protect --staged --redact` gate into the Phase 2 bash fence, positioned **after** `"${GIT_CMD[@]}" reset --soft "$ANCHOR"` (which stages the squash delta into the index) and **before** `"${GIT_CMD[@]}" commit -F "…"`. The gate runs from the squash cwd — route it via the same `GIT_CMD` array discipline so it scans the worktree's index when `WORKTREE_PATH` is set, else `/devshop`'s. On a non-zero exit (finding), print the redacted finding and HALT (do NOT commit); idempotent re-run after the operator clears the secret. Also refine the prose claim around l.941–942 ("Pre-commit hooks … still fire on the feature-branch commit") to: hooks fire where husky is installed (`/devshop`, or a worktree after the recipe's `pnpm install`), and the new Phase 2 gitleaks gate scans the staged delta unconditionally regardless. |
| `kit/tests/util-ak-merge-devshop.bats` § Section G                            | **bats coverage.** Add `@test`(s) asserting (1) the Phase 2 range contains `gitleaks protect --staged`, and (2) the gitleaks line is ordered before the `commit -F` line. Grep-based, `awk`-range-scoped to `/^## Phase 2:/,/^## Phase 3:/`, matching the file's existing style.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `kit/docs/guide/security.md` (l.58)                                           | **(a) cross-ref.** The sentence "Pre-commit hooks fire identically in worktrees, so the guard gauntlet is not weakened" is now only true _after the recipe's `pnpm install`_. Rewrite to reflect the install-step dependency (hooks fire in worktrees once the recipe's `pnpm install` has run; the `/ak-merge-devshop` Phase 2 gitleaks gate is the unconditional net). Keep the surrounding deny-pattern rationale intact.                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `PLAN.md` § Planned (v0)                                                      | **(D6) closure.** Delete the `merge-devshop-worktree-hooks` row (l.80).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `kit/TODOS.md` (l.490–492)                                                    | **(D6) closure.** Delete the `/ak-merge-devshop` + worktree convention entry (the (a)–(d) option block).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `kit/FRICTION-LOG.md` § Pre-commit hooks don't fire in linked worktrees       | **(D6) rewrite.** Set `Status: shipped (b)+(d); (c) optional follow-up`; collapse the "Candidate fixes (operator picks)" list to a single residual (c) stub; drop the now-corrected "actively claims the opposite" doc-drift framing. Add the merge SHA / date when the merge lands (Phase 4.0 fills it).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| `specs/merge-devshop-worktree-hooks/spec.md`                                  | This file (already created at Phase 0; expanded here at Phase 1).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

### Phase 2 gitleaks gate — exact placement

The gate runs **once per merge, unconditionally** (belt-and-suspenders — operator
directive). It is NOT conditional on whether in-worktree hooks already ran:
re-scanning a clean staged delta from `/devshop` is cheap, and the unconditional
form is what makes it robust to off-convention worktrees where `pnpm install` was
skipped. Sequence inside the Phase 2 bash fence:

```bash
"${GIT_CMD[@]}" reset --soft "$ANCHOR"   # stages the full squash delta into the index

# … existing rename-plus-symlink collision detection …

# (d) compensating gitleaks gate — mirrors .husky/pre-commit:29 verbatim.
# Scans the staged index (== the squash delta after the soft-reset), from the
# squash cwd: the worktree when WORKTREE_PATH is set, else /devshop. Runs
# UNCONDITIONALLY (belt-and-suspenders) so an off-convention worktree that skipped
# `pnpm install` still can't land a secret on main.
if [ -n "$WORKTREE_PATH" ]; then
  ( cd "$WORKTREE_PATH" && gitleaks protect --staged --redact )
else
  gitleaks protect --staged --redact
fi
# On non-zero (a finding): HALT — do NOT commit. Surface the redacted finding,
# tell the operator to scrub the secret from the staged delta and re-run.

"${GIT_CMD[@]}" commit -F "/tmp/squash-message-${FEATURE}.txt"
```

(`gitleaks` honors the repo's `.gitleaks.toml`; the worktree shares the parent's
config via the common git dir, so the same allow-list applies in both cwds.)

## Tests

bats, in `kit/tests/util-ak-merge-devshop.bats § Section G — Phase 2
worktree-routed squash` (after the existing Phase 2 tests, ~l.535). Grep-based,
`awk`-range-scoped, `mawk`-portable, matching the file's style:

```bash
@test "Phase 2 runs a gitleaks compensating gate on the staged squash delta before commit" {
  # (d) defense-in-depth: even an off-convention worktree that skipped `pnpm
  # install` (so in-worktree hooks never armed) can't land a secret on main —
  # Phase 2 scans the staged delta with gitleaks before creating the squash
  # commit. Mirrors .husky/pre-commit's `gitleaks protect --staged --redact`.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'gitleaks protect --staged'
}

@test "Phase 2 gitleaks gate is ordered before the commit -F (halt-before-commit)" {
  # The gate must run AFTER `reset --soft` stages the delta and BEFORE `commit
  # -F`, so a finding halts the merge with nothing committed. Assert line order
  # within the Phase 2 range: the gitleaks line precedes the commit -F line.
  local block gitleaks_line commit_line
  block=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE")
  gitleaks_line=$(printf '%s\n' "$block" | grep -nE 'gitleaks protect --staged' | head -1 | cut -d: -f1)
  commit_line=$(printf '%s\n' "$block" | grep -nE '"\$\{GIT_CMD\[@\]\}" commit -F' | head -1 | cut -d: -f1)
  [ -n "$gitleaks_line" ]
  [ -n "$commit_line" ]
  [ "$gitleaks_line" -lt "$commit_line" ]
}
```

The CLAUDE.md / security.md recipe + prose edits are doc-only (no test) — they're
caught by the CLAUDE.md classification/placement gates at commit time, not by bats.
No existing bats test asserts the "still fire on the feature-branch commit" text
being refined (D5), so the prose refinement causes no test drift.

## Dependencies

None external. `gitleaks` (8.30.1) is already on PATH (used by `.husky/pre-commit`
today). `pnpm` is already the worktree-recipe's package manager. The two new bats
tests use only `awk` / `grep` / `printf` already used throughout the suite.

## Task order

Dependency-ordered; each task is one atomic commit.

1. **(b) recipe edit — `CLAUDE.md`.** Append `&& (cd .worktrees/<topic> && pnpm
install)` to the worktree-add recipe. (Standalone doc change; no dependency on
   the others. Triggers the Layer-2 CLAUDE.md classification gate — classify as a
   convention/Known-Footgun update.)
2. **(d) gitleaks gate — `merge-devshop SKILL.md § Phase 2`.** Insert the gate
   between `reset --soft` and `commit -F`. (Must land before the bats test so the
   test goes green in the same suite run.)
3. **bats test — `util-ak-merge-devshop.bats § Section G`.** Add the two `@test`s
   from § Tests. (Depends on Task 2 for green.)
4. **(a) doc-accuracy refine.** Refine the Phase 2 prose claim (SKILL.md
   l.941–942), the `CLAUDE.md § Parallel work` bullet (l.66), and the
   `security.md:58` "fire identically" sentence — all to imperative-present
   describing the (b)+(d) posture. (Can fold Task 1's CLAUDE.md edit's bullet
   rewrite here if cleaner to keep the recipe-append and the bullet-rewrite in one
   commit; the implementer may merge Task 1 + the CLAUDE.md half of Task 4 into a
   single commit since both touch the same § — but keep SKILL.md and security.md
   prose in this commit.)
5. **tracker closure — `PLAN.md` + `kit/TODOS.md` + `kit/FRICTION-LOG.md`.** Delete
   the PLAN row + the TODOS entry; rewrite the FRICTION-LOG entry to the
   shipped-(b)+(d)/(c)-stub form; unwind any remaining cross-refs. (Last — closes
   the trackers only once the fix is in the same PR, per the closing-trackers
   convention.)

## Gotchas

1. **Husky `.husky/` hooks run under sh/dash, not bash** (devshop memory:
   `feedback_husky-dash.md`). Bash-isms in a hook crash silently. **Low risk
   here** — the (b) recipe edit is a _documentation_ shell command (an operator/
   agent types it at a normal shell, zsh/bash), not a line added to a `.husky/*`
   hook, so the dash constraint doesn't apply. We are not editing any
   `.husky/*` file.
2. **The (d) gate's cwd must be the worktree when `WORKTREE_PATH` is set.** If it
   runs from `/devshop` while the squash is happening in a worktree, `gitleaks
protect --staged` scans `/devshop`'s index (which is on `main`, an empty staged
   delta) and false-passes. The `( cd "$WORKTREE_PATH" && … )` subshell (or the
   `GIT_CMD`-array discipline) keeps the scan pinned to the same index the
   soft-reset just staged. This mirrors why Phase 2 routes every git op via
   `GIT_CMD`.
3. **`gitleaks protect --staged` reads the git index.** After `reset --soft
"$ANCHOR"` the index holds exactly the squash delta (`$ANCHOR..HEAD` content),
   so `--staged` scans exactly the range that will become the squash commit —
   no more, no less. The gate's correctness is load-bearing on running _after_ the
   soft-reset and _before_ the commit; the bats ordering test pins this.
4. **Editing `CLAUDE.md` triggers the Layer-2 classification gate at commit time.**
   The recipe-append + bullet-rewrite is a Known-Footgun / convention update
   (parallel-work safety posture), not an entry-placement or new-section change —
   classify accordingly when the `devshop.claudeMdClassification` reviewer fires.
5. **Closing-trackers convention** (`CLAUDE.md § Closing TODO/ROADMAP entries when
a fix ships`): deleting the PLAN/TODOS entry MUST be paired with rewriting every
   "without this X silently fails" / "claims the opposite" conditional prose to
   imperative present, and unwinding cross-refs — in the _same_ PR. Concrete
   targets: the `CLAUDE.md` bullet, the `security.md:58` "fire identically"
   sentence, and the FRICTION-LOG entry's "actively claims the opposite" framing.
   Leaving any of these stale recreates the false belief the fix removed.
6. **FRICTION-LOG is a rewrite, not a delete** (D6). (c) genuinely wasn't shipped,
   so the entry survives as a slimmed "optional follow-up" stub — don't delete it
   outright, and don't leave the full "candidate fixes (pick one)" list (which a
   future session would misread as "still open").

## Acceptance / rollout / rollback

**Acceptance:**

- Full bats suite green: `pnpm turbo run test` (or `kit/tests/lib/bats-core/bin/bats
kit/tests/util-ak-merge-devshop.bats` for the targeted file). Both new Section G
  `@test`s pass.
- The Phase 2 gitleaks gate demonstrably scans the _staged delta_: the gate line
  appears between `reset --soft "$ANCHOR"` and `commit -F` in the SKILL.md Phase 2
  fence (asserted by the ordering test), and mirrors `.husky/pre-commit:29`'s
  `gitleaks protect --staged --redact` invocation verbatim.
- Docs read imperative-present: the `CLAUDE.md` worktree bullet, the `security.md`
  "fire identically" sentence, and the SKILL.md Phase 2 prose all describe the
  real (b)+(d) posture (hooks fire after the recipe's `pnpm install`; the merge-time
  gitleaks net is unconditional) — no residual "do NOT fire / silently skips every
  gate / fire identically" absolute claims.
- Trackers closed: no `merge-devshop-worktree-hooks` row in `PLAN.md`, no
  worktree-hooks entry in `kit/TODOS.md`, FRICTION-LOG entry rewritten to the
  shipped/(c)-stub form.

**Rollout:** Lands via `/ak-merge-devshop` (devshop shipping flow — no PR). The
(d) gate is self-validating on its very first run: the next worktree merge after
this lands exercises the new gate against a real staged delta. No migration, no
flag, no staged rollout — it's a doc + skill-prose change plus two bats tests.

**Rollback:** Pure revert of the squash commit. The (b) recipe step is additive
(an extra `pnpm install` in a documented command — harmless if reverted, worktrees
just return to the un-installed state). The (d) gate is additive prose in a SKILL
bash fence — reverting removes the extra scan with no state to unwind. The bats
tests revert with it. No data migration, no schema, no runtime artifact to clean
up.
