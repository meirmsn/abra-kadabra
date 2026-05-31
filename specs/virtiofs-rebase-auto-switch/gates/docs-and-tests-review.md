## Gate 5: docs-and-tests-review

findings: high=0 medium=1 low=1

Audit-time docs + tests adequacy (Layer 2), devshop-self-mode. Range `1408150..HEAD`
(`f447e0f..8582b3e`, the virtiofs-rebase-auto-switch feature, 5 commits). HALT-ON-FIND:
findings surfaced below, NOT auto-fixed, NOT committed. Helper script (150 lines), bats
file (399 lines), spec, and every modified doc surface read verbatim.

### Tests — verdict: ADEQUATE, notably disciplined

`kit/tests/util-virtiofs-rebase.bats` PINS the helper's contract — it does not
under-assert. Every item this gate was told to check is present:

- **RESULT vocabulary is asserted, not exit-0-only.** Every success/conflict case asserts
  the exact `RESULT:` line via anchored `grep -qx` (not loose substring, not status-only):
  case 1/13/15 → `RESULT: rebased`; case 2 → `rebased-checkstat`; case 4 →
  `merged-fallback`; case 6 → `conflict-rebase`; case 7 → `conflict-merge`; case 8 →
  `error:`. case 15 additionally **negatively** asserts a clean run does NOT emit
  `rebased-checkstat` or `merged-fallback` (no spurious fall-through).
- **The BOTH-flags requirement is double-pinned (case 3).** case 3 isolates the retry argv
  line and asserts it carries BOTH `core.checkStat=minimal` AND `core.trustctime=false`.
  Independently, the stub only takes the checkStat branch when BOTH flags are present
  (`HAS_CHECKSTAT=yes && HAS_TRUSTCTIME=yes`), so dropping either flag would also break the
  expected RESULT in cases 2/4/10/14/16. A future edit dropping a flag reds multiple cases.
- **Conflict cases assert git is LEFT mid-op for the caller (exit 10).** case 5 + case 18
  run a REAL repo with a genuinely conflicting line and assert `.git/rebase-merge ||
rebase-apply` still exists AND `git diff --diff-filter=U` is non-empty after the helper
  returns 10 — i.e. the helper did NOT abort/clean up (D4). Real git state, not a mock.
- **D3 unmerged-path discrimination is exercised (case 9).** Stub emits the phantom "would
  be overwritten" stderr string AND sets the unmerged sentinel; case 9 asserts classify-as-
  conflict (exit 10) AND `! grep core.checkStat` proves it did NOT fall through to the
  retry. Exactly the "discriminate by unmerged paths, not stderr string" pin.
- **F244 rescheduled-pick variant is exercised (case 10) + abort-guard both branches.**
  case 10 drives a phantom that leaves a rebase in-progress with NO unmerged paths; asserts
  recovery-ladder routing (`rebased-checkstat`), abort-guard fired (`grep "rebase --abort"`),
  retry ran. case 14 is the negative twin (no rebase in progress → abort NOT called).
- **Worktree routing (case 13)** invokes from a cwd OUTSIDE the repo, proves the rebase
  landed in the arg2-target repo (tip moved, anchor now ancestor). **Ancestor end-state
  (case 17)** asserts `merge-base --is-ancestor` post-run. **Usage (cases 11, 12)** cover
  zero-arg and too-many-args → exit 64.

All 18 numbered cases are present (1-18, interleaved by harness section). The negative
greps (cases 9/14/15) are coverage-strengthening (prove a path was NOT taken), and the
positive assertions are exact-anchored — the opposite of the recurring "grep-based
under-assertion ships green after a future edit" friction. The `helpers/setup` primitives
the file leans on (`SCRIPTS_DIR`, `setup_mock_bin`, `MOCK_BIN`) all exist. Phase 2.5's
verification.log reports the suite green; structural-invariants registration (below) keeps
it green.

### Docs — verdict: ADEQUATE, closing convention fully satisfied

All read verbatim:

- **Helper contract** documented in-script (full exit-code + RESULT table, D1-D5 rationale,
  set -e / abort-guard / inline-flag notes) AND mirrored in spec § Behavior. Consistent.
- **Phase 1.0 wiring** (`.claude/skills/devshop/merge-devshop/SKILL.md`): the bare
  `"${GIT_CMD[@]}" rebase` is replaced with a `bash …/virtiofs-rebase.sh "$ANCHOR"
"$WORKTREE_PATH"` call + a `case "$rc"` that handles 0 / 10 / 11 / \* exactly per the
  helper's contract, including the worktree-path arg2 note and the exit-10/11 inline
  resolution recipes. The prose ladder section was rewritten to "mechanized by
  virtiofs-rebase.sh" and points at the script header for the full contract. Accurate.
- **CLAUDE.md footgun** rewritten to imperative-present: "First action inside an
  /ak-merge-devshop run: nothing — Phase 1.0 auto-handles it via
  kit/scripts/virtiofs-rebase.sh", correctly scopes the manual `-c` recipe to the
  still-manual cherry-pick/`am` call-sites, names the rescheduled-pick variant, points at
  SKILL § Phase 1.0. Clean close.
- **workflow.md** skill-table `/ak-merge-devshop` row gained a sentence: Phase 1.0 runs
  through `virtiofs-rebase.sh` (reduced-stat retry → merge fallback, unmerged-path
  discrimination, returns only real conflicts). Accurate.
- **Closing-convention deletions fully unwound, NO orphan refs:**
  - `kit/TODOS.md`: the "mechanize the virtiofs phantom-rebase fallback" entry (the whole
    15-line block) is deleted. `grep -rn "mechanize the virtiofs phantom-rebase"` over
    `kit/ CLAUDE.md .claude/` → ZERO hits. No dangling pointer to the old title.
  - `kit/FRICTION-LOG.md` F244: the "rescheduled pick stall" entry is removed from the open
    list and re-added under `## Resolved` with `Status: resolved (virtiofs-rebase-auto-switch)`,
    a "Resolved by …" detail naming the helper + D3, and `Promotion target: n/a — resolved`.
    The only remaining `F244` mentions in the tree are the deliberate citations in the
    spec/helper-header/test (e.g. "auto-covers friction-log F244", "Case 10: F244
    rescheduled-pick variant") — these are correct forward-references to the now-resolved
    entry, not stale "still-open" cross-refs.
- **structural-invariants.bats** registration: `virtiofs-rebase.sh` is appended to the
  `infra_scripts` allow-list with a rationale comment (skill-invoked from /ak-merge-devshop
  § Phase 1.0, not hook-wired) — so the "every non-exempt kit script is wired" wiring test
  stays green for the new script. Correct.
- **hooks.md / conventions.md** touches in range are unrelated prettier-stability reflows
  (table-padding, `*emphasis*` → `_emphasis_`) — no semantic claim about this feature,
  no invalidated doc.

No sign the diff invalidated an un-updated doc. The spec § Out-of-scope correctly defers
the `PLAN.md` row deletion to Phase 4.0, so its absence from this range is expected, not a
docs hole.

### Findings

**[medium] F1 — Exit-11 (`conflict-merge`) "left mid-op for the caller" is asserted only
via a mocked sentinel, never against real git mid-merge state — asymmetric with exit-10.**
The exit-10 path has both a stub case (6) AND two real-repo cases (5, 18) that assert
`.git/rebase-merge|rebase-apply` exists and real unmerged paths remain after the helper
returns, proving git is genuinely left mid-op for inline resolution. The exit-11
merge-fallback-conflict path (case 7) is stub-only: it asserts the RESULT line + exit code,
but the stub's `emit_conflict` merely `touch`es an unmerged sentinel — nothing asserts a
real `git merge` was left in progress (`.git/MERGE_HEAD` present, real unmerged paths) when
the helper returns 11. The gate explicitly asked whether the exit-10/11 conflict cases
assert git was LEFT mid-op; exit-10 fully satisfies this, exit-11 only at the mocked layer.
A future helper edit that erroneously added a `git merge --abort` before the exit-11 return
would NOT be caught (the stub abort is a no-op on a sentinel; no real MERGE_HEAD is
checked), yet the caller's documented exit-11 recovery (`resolve → add → commit -F
/tmp/merge-commit-msg.txt`) depends on the merge actually being in progress. Recommended: a
real-repo exit-11 companion mirroring case 18 — force both rebase rungs to phantom-fail
(hard against real git; may require the stub for the rebase rungs + a real merge conflict),
then assert `.git/MERGE_HEAD` + real unmerged paths survive. Non-blocking: the shipped
helper's exit-11 path verifiably does NOT call `merge --abort` (it returns immediately on
unmerged paths), so this is a regression-coverage gap, not a correctness hole in what
ships.

**[low] F2 — case 3 proves both flags are PRESENT but not that they PRECEDE the rebase
subcommand; the inline-flag-position correctness is unpinned by any real-git case.** git
requires `-c k=v` before the subcommand; the helper places them correctly (line 125, after
the `GIT` array which only ever holds `-C <path>`). But the stub's option-stripping `while`
loop consumes `-c kv` pairs regardless of position, so a buggy helper emitting
`git rebase -c core.checkStat=minimal <anchor>` (flags after the subcommand, which real git
rejects) would still pass case 3. The checkStat rung is never traversed by a real-git case
(the flake is non-reproducible by construction — see Dismissals), so flag-position
correctness has no real-git guard. Low severity: the shipped code is correct and the header
documents the ordering; the suite just wouldn't catch a position regression. Optional: a
comment in case 3 noting this, or a cheap real-git parse-check of the emitted retry argv.

### Overall

Tests adequate and disciplined; docs adequate with the closing convention fully unwound and
zero orphan refs. No high findings. The one real gap (F1, medium) is the missing real-repo
exit-11 companion — a ~15-line mirror of case 18; the orchestrator should decide whether to
add it before ship (recommended). F2 is a low calibration note. Both are robustness
improvements, not blockers — what ships is correct.

## Dismissals

- **"Only stub-tested checkStat rung / phantom paths" — n/a, by design.** The phantom flake
  is a non-reproducible stat-cache race; real git cannot deterministically exercise the
  checkStat rung. The git-stub-on-PATH harness is the correct and only way to pin those
  paths, and the file's header is explicit about the A/B harness split. Not a coverage
  defect. (The narrower residual — flag _position_ unpinned by real git — is captured as
  F2, not dismissed.)
- **"~18 cases but file looks like 16" — n/a.** All 18 numbered @test blocks (1-18) are
  present; numbering is non-contiguous in file order only because the real-repo group (A)
  and stub group (B) are interleaved by section.
- **"F244 still referenced in the tree" — n/a, intentional.** The three remaining F244
  mentions (spec source list, helper header line 51, bats case-10 comment) are deliberate
  forward-citations to the now-resolved entry, documenting that the unmerged-path
  discrimination auto-covers that variant. They are not stale open-status cross-refs; the
  FRICTION-LOG entry itself is correctly moved to `## Resolved`.
- **"`.gstack/` not in `.gitignore` / gstack-tree concerns" — n/a.** No gstack files in
  range; the standing CLAUDE.md dismissal does not apply to this feature.
