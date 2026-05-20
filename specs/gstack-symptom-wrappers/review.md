# Review — gstack-symptom-wrappers

## Audit 1: manual (2026-05-20)

<!-- audited-at: 2f08711c297722a90f322df991e155b74ab270dc -->
<!-- range: origin/main..HEAD -->

findings: high=3 medium=0 low=4

### Docs findings

### [domain: docs] [section: C] [severity: high]

**File**: PLAN.md:72
**What**: The `gstack-symptom-wrappers` Planned row's `Source` column still cites `kit/ROADMAP.md § Gstack-symptom workarounds — Chromium fallback + screenshot allow-list`, but that ROADMAP section was DELETED by this same PR (36-line removal in `kit/ROADMAP.md`). The cross-reference is broken at HEAD — anyone clicking it after merge hits a dangling `§` anchor.
**Why**: Direct violation of CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships": _"The same PR that ships a fix MUST close the tracker entries for it — delete from `kit/ROADMAP.md` / `kit/TODOS.md` / project `TODOS.md`; … unwind every cross-reference in the same PR. Otherwise stale entries get cited as 'still pending' in future sessions and recreate the false belief the fix removed."_ This is the exact failure mode the convention exists to prevent — the ROADMAP delete happened but the PLAN.md cross-ref didn't get unwound in the same diff. Compounds with the next finding (the row itself should be gone).
**Fix**: Delete the entire `gstack-symptom-wrappers` row from `PLAN.md` Planned table (PLAN.md:72). Per PLAN.md:50 — _"A row ships → delete it. `BUILD-LOG.md` + `git log` carry the audit trail."_ The shipped commit `2f08711` will be the audit trail. If retention in PLAN.md is desired pending /ak-merge-devshop landing, at minimum rewrite the Source cell to drop the stale ROADMAP anchor (e.g. point at `BUILD-LOG.md` once the merge lands, or at the in-flight branch).

---

### [domain: docs] [section: A] [severity: high]

**File**: PLAN.md:72
**What**: The `gstack-symptom-wrappers` row is still listed in the **Planned** table even though this PR is the one that ships it. Per the PLAN.md authoring contract (PLAN.md:50, repeated in the maintenance HTML comment at PLAN.md:55-61), a row ships → it gets deleted from PLAN.md in the same PR; the BUILD-LOG.md + git-log carry the audit trail.
**Why**: Same convention as the previous finding ("Closing TODO / ROADMAP entries when a fix ships"). Leaving the row in Planned means the next session that reads PLAN.md will see the work as still-pending — and the next /ak-build / /ak-status invocation will treat it as fair game. Worsened by the fact that the ROADMAP `§` Source pointer is now dangling (previous finding).
**Fix**: Same diff: delete row 72 of PLAN.md (the `gstack-symptom-wrappers` table row + its column separator). No other PLAN.md edits needed (the bundle table, leverage ordering, and remaining rows are unaffected).

---

### [domain: docs] [section: C] [severity: high]

**File**: kit/version (+ kit/docs/CHANGELOG.md + 3 deleted spec files under specs/plan-close-shipped-rows/)
**What**: The audit range `origin/main..HEAD` shows kit/version regressed from `1.32.0` → `1.31.0`, the entire `## v1.32.0 (2026-05-20)` block (19 lines, 16 commit-summary bullets) deleted from `kit/docs/CHANGELOG.md`, and three completed-feature spec artifacts deleted (`specs/plan-close-shipped-rows/{review.md, gates/audit-1-docs.md, gates/audit-1-tests.md}`). None of these changes are described in the HEAD commit message (which only documents Sub-A + Sub-B of the gstack-symptom wrappers feature) and no doc explains the un-release. Investigation confirms HEAD (`2f08711`) is BEHIND `origin/main` (`3f122d4` — "Bump devshop version to 1.32.0") on these paths — the feature branch was forked before the v1.32.0 release commit + plan-close-shipped-rows merge and was never rebased / merged-up, so `git diff origin/main..HEAD` surfaces those 5 reverts as part of this audit's range.
**Why**: Two distinct doc-correctness risks:
  (a) **If this branch is squash-merged via `/ak-merge-devshop` without rebasing first**, the squash commit will land on main as an apparent revert of v1.32.0 (kit/version 1.32.0→1.31.0) and an apparent deletion of 16 changelog bullets + a completed feature's spec artifacts. That breaks the release-history audit trail and silently un-ships a release. Recovery requires a manual re-bump + restore.
  (b) **The audit range itself is polluted** — the structured-findings docs review is supposed to judge what this feature ships, not what main has accumulated since the branch was cut. Treating the 5 reverts as in-scope for this audit risks generating false-positive findings (or missing real ones because the diff is noisier than the feature warrants).
**Fix**: Before `/ak-merge-devshop` runs Phase 1, rebase the feature branch onto `origin/main`: `git -C /devshop/.worktrees/gstack-symptom-wrappers fetch origin && git -C /devshop/.worktrees/gstack-symptom-wrappers rebase origin/main`. The kit/version + CHANGELOG.md + plan-close-shipped-rows reverts should vanish from the diff (they're already on main). Then re-run this audit (orchestrator caches by HEAD SHA, so it'll re-fire automatically once HEAD advances) — the resulting findings will be feature-scoped. Doc-side: no edit needed beyond the rebase itself; the v1.32.0 changelog + version bump are the canonical record on main.

---

### [domain: docs] [section: B] [severity: low]

**File**: CLAUDE.md:120-121 (the existing "Browse binary + Playwright browsers" footgun + the new "Screenshots through capture-screenshot.sh" footgun)
**What**: The two adjacent Known Footgun entries describe overlapping gstack-friction territory but split the routing differently. The Browse-binary entry now says _"if it does, run `bash /devshop/kit/scripts/populate-playwright-cache.sh` manually"_ — a manual-fallback first-action that's plausibly never needed (the new auto-wire in `init-devshop.sh` is idempotent and runs on every container start, not just first-launch). The new Screenshots entry directs callers to `capture-screenshot.sh` but doesn't address what happens if the operator forgets and calls `browse screenshot` directly — symptom is `Path must be within: /tmp, /workspace/apps/web`, which is the cue to switch tools. Both entries pass the "name the symptom + root cause + fix" rubric individually; the gap is the cross-entry routing — a future reader hitting either symptom may not realize the other entry's recipe applies.
**Why**: Adequacy-low (not high — the entries individually pass the gotcha-specificity check, and the load-bearing first-actions are correct). The friction is "did I read the right Footgun?" rather than "is this Footgun wrong." Easy to dismiss.
**Fix**: Optional consolidation pass — either (a) collapse both entries into a single "gstack workspace integration friction" footgun with subsections per symptom (Browse binary / Playwright cache / Screenshot allow-list), OR (b) add a one-line "if you hit `Path must be within ...` errors, see the next entry" cross-link in the Browse-binary footgun. No-action is also defensible; flagged as low because both entries individually serve their first-action role.

---

### [domain: docs] [section: B] [severity: low]

**File**: kit/scripts/capture-screenshot.sh:23 (Usage docstring)
**What**: The script's Usage docstring says _"final-path may be absolute or relative to cwd"_, but the implementation runs `realpath -m "$FINAL_PATH"` (line 39) which resolves a relative path against the caller's CWD before any subsequent operation. The behavior is correct, but the docstring doesn't mention that the resolved absolute path is what gets passed to `browse screenshot` and `cp`, and the printed "ok:" line names the absolute resolution — a caller passing a relative path to a script-from-elsewhere may briefly wonder why the path in the success line doesn't match what they typed. The `bats` test at line 132-148 (`Sub-B: wrapper stages to /tmp, cps to final path under specs/`) only exercises the absolute-path path.
**Why**: Adequacy-low. The "may be relative" claim is technically accurate but under-specified. A future operator might wire the wrapper into a CI snippet that runs `cd /tmp && bash capture-screenshot.sh foo.png` expecting `/tmp/foo.png` and being surprised — they'd get it (realpath resolves correctly), but the docstring should say "relative paths are resolved against the caller's CWD via `realpath -m`" to spare the moment of doubt.
**Fix**: Tighten the Usage docstring (lines 19-23) to say _"final-path may be absolute or relative to the caller's CWD; the script resolves relative paths via `realpath -m` and prints the absolute resolution in the success line."_ No tests need to change.

---

**Section D — Bypass trailer audit**: No `Docs-Coverage-Bypass:` trailers in range.

**Section E — CLAUDE.md hygiene**: Skipped (devshop self-mode; Section E is project-mode only per `ak-docs-review § Step E`).

**Summary**: `high=3 medium=0 low=2`

---

**Coverage summary (Section A baseline pass)** — every source change in the in-feature scope has paired doc edits:

- `kit/scripts/init-devshop.sh` (Sub-A wire-up) → `kit/docs/guide/ops.md § Playwright cache population` updated to "Auto-wired (post-2026-05-20)" + `CLAUDE.md § Known Footguns` entry updated.
- `kit/scripts/capture-screenshot.sh` (Sub-B new script) → `kit/docs/guide/ops.md § Hero screenshot — manual capture` updated to drive the wrapper + `CLAUDE.md § Known Footguns` new entry + `.claude/skills/devshop/pre-ship/SKILL.md § Capture mechanics` updated.
- `kit/tests/gstack-symptom-wrappers.bats` (new tests) → tests carve-out (no doc required).
- `kit/ROADMAP.md` (delete `§ Gstack-symptom workarounds`) → tracker-close action (no doc required for the deletion itself, but PLAN.md unwind required — see Section C findings above).

The high-severity findings are all rooted in the "ship the fix, close the tracker" convention being half-applied (ROADMAP deleted, PLAN row + cross-ref not). The kit/version regression is a branch-staleness artifact, not a feature-doc problem — but ships as a release-history rewrite if not rebased before merge.

### Tests findings

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/gstack-symptom-wrappers.bats:200-212`
**What**: `capture-screenshot.sh` documents 4 exit codes (`0 ok, 2 usage error, 3 browse failure, 4 cp failure`) but the bats suite never exercises **exit 4** (cp failure). Tests cover 0 (tests 14/15/18), 2 (test 9), and 3 in two flavors (16: browse non-zero; 17: empty file), but the `cp` failure branch at script line 87 — `if ! cp "$STAGE_PATH" "$ABS_FINAL"; then ... exit 4; fi` — is untested.
**Why**: a regression that swaps `cp` for `mv` (a tempting "simpler" refactor that the script's existing comment explicitly warns against) would still pass all 20 tests, even though it would change the exit-4 path's behavior on failure (mv on a cross-filesystem move with permission denial on dest exits differently). More concretely, an upstream `cp` argument-order swap or `--no-clobber` addition could turn exit-4 into a silent success or a different exit code, and the suite would not catch it.
**Fix**: add one bats test that engineers a deterministic cp failure — make the destination dir read-only (`chmod 0500`) before invoking the wrapper, assert `status -eq 4` and `output` contains `"cp ... failed"`. Example:

```bash
@test "Sub-B: wrapper exits 4 when cp to final path fails" {
  setup_mock_bin
  cat > "$MOCK_BIN/browse" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "screenshot" ] && [ -n "$2" ] && { printf 'PNG\n' > "$2"; exit 0; }
exit 1
EOF
  chmod +x "$MOCK_BIN/browse"

  SANDBOX="$BATS_TEST_TMPDIR/readonly"
  mkdir -p "$SANDBOX"
  chmod 0500 "$SANDBOX"  # read+execute only — cp into here fails

  run bash "$CAPTURE_SCRIPT" "$SANDBOX/shot.png"
  chmod 0700 "$SANDBOX"  # restore for cleanup
  [ "$status" -eq 4 ]
  [[ "$output" == *"cp"*"failed"* ]]
}
```

### [domain: tests] [section: A] [severity: low]

**File**: `kit/tests/gstack-symptom-wrappers.bats:123-127`
**What**: the fallback `browse` binary discovery branch (`BROWSE_BIN=/devshop/.claude/skills/gstack/browse/browse` when `command -v browse` fails) is verified only **structurally** (test 13 greps for the literal path string in the script). The behavioral branch — what happens when `browse` is NOT on PATH AND the fallback path is also absent — is never exercised. The "binary not found" error message at script lines 57-60 (`error: 'browse' binary not found on PATH or at ...`, `exit 3`) is unreachable by the current suite.
**Why**: this is the primary user-facing error for a half-installed gstack (the most common installation failure mode for the very symptom this wrapper exists to work around). A future refactor that, say, drops the fallback path or changes the error message would not be caught by the structural grep alone — and the structural grep is satisfied even by a comment containing the literal string.
**Fix**: add one behavioral test that scrubs PATH and points the fallback at a missing file, asserting exit 3 + the binary-not-found message:

```bash
@test "Sub-B: wrapper exits 3 with a clear message when browse binary is missing entirely" {
  # Empty PATH so `command -v browse` fails; fallback path is absent in this sandbox.
  run env -i PATH="$BATS_TEST_TMPDIR/empty" HOME="$HOME" bash "$CAPTURE_SCRIPT" "$BATS_TEST_TMPDIR/x.png"
  [ "$status" -eq 3 ]
  [[ "$output" == *"'browse' binary not found"* ]]
}
```

### [domain: tests] [section: C] [severity: low]

**File**: n/a
**What**: no `Tests-Coverage-Bypass:` trailers in the commit range (one commit: `2f08711`); harvest returns zero rows.
**Why**: section C is forward-compatible per the skill's spec — legitimate zero-row outcome, noted for completeness.
**Fix**: none.

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: 1bb1347ad2ff819a8c0778392167707ef12eb02e -->
<!-- range: 2f08711c297722a90f322df991e155b74ab270dc..HEAD -->

findings: high=0 medium=0 low=2

### Docs findings

### [domain: docs] [section: C] [severity: low]

**File**: PLAN.md (Audit 1's high-finding #1, now closed) + Audit 2 range verification
**What**: Re-anchoring Audit 1's three high-severity docs findings against HEAD confirms all three are closed by this audit's range:
  - **Audit 1 high #1 (dangling Source cross-ref)** — the `gstack-symptom-wrappers` row's `Source` column pointed at `kit/ROADMAP.md § Gstack-symptom workarounds — Chromium fallback + screenshot allow-list`, which the PR itself deleted. Closed by `1bb1347` (chore(plan): close gstack-symptom-wrappers row that this PR ships) — the entire row + Source cell were deleted. Verified: `grep -n 'gstack-symptom-wrappers' PLAN.md` returns no match at HEAD. No remaining stale references to `Gstack-symptom workarounds` anywhere under `kit/`, `PLAN.md`, `CLAUDE.md`, or `README.md`.
  - **Audit 1 high #2 (PLAN row still listed as Planned despite shipping)** — same commit `1bb1347` deleted the row entirely per PLAN.md:50 lifecycle. Verified: row absent from HEAD.
  - **Audit 1 high #3 (un-release: kit/version 1.32.0→1.31.0 + CHANGELOG block deleted + plan-close-shipped-rows specs deleted)** — caused by the branch being forked before `origin/main`'s v1.32.0 release commit (`3f122d4`). The Audit 1 recommended fix offered rebase OR merge as the action; commit `32db717` is the merge-up of `origin/main` into the feature branch. Verified at HEAD: `cat kit/version` → `1.32.0`; `grep -c '^## v1.32.0' kit/docs/CHANGELOG.md` → `1`; `ls specs/plan-close-shipped-rows/{review.md,gates/audit-1-docs.md,gates/audit-1-tests.md}` all present.
**Why**: Recorded as a low-severity COHERENCE check rather than a finding — this is an audit-trail entry, not a defect. The "merge fallback" (rebase tripped a virtiofs phantom error per `/ak-merge-devshop § Phase 2 known limitations`) preserves the same end-state as rebase from a release-history standpoint: when `/ak-merge-devshop` later squashes this feature branch onto `main`, the squash diff against `origin/main` will no longer contain any kit/version regression or CHANGELOG deletion (those paths are now identical between feature HEAD and `origin/main`). The merge commit `32db717` itself stays on the feature branch and is collapsed by the squash.
**Fix**: None — verification entry only. The squash merge that lands this feature will diff cleanly against `origin/main` on the release-history paths.

---

### [domain: docs] [section: A] [severity: low]

**File**: n/a — Audit 2 range coverage check
**What**: Section A baseline pass for the new commits in this audit's range (`2f08711..HEAD`):
  - `b6b700a` (Audit 1 scaffold) — touches only `specs/gstack-symptom-wrappers/{review.md,gates/audit-1-docs.md,gates/audit-1-tests.md}`. Spec-artifact carve-out per the rubric — no doc edit required.
  - `32db717` (merge of origin/main) — no in-feature source changes; brings in content already audited as part of `plan-close-shipped-rows` Audit 1 (kit/version, CHANGELOG, PLAN.md `home-os-skill-polish-batch` Hook consolidation) and as part of the v1.32.0 release commit itself.
  - `1bb1347` (close PLAN row) — touches only `PLAN.md` (1 deletion). `PLAN.md` is itself the destination doc; the row deletion IS the documentation action per CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships". Coverage satisfied.
  - `3f122d4` + `24561a0` — origin/main commits surfaced by the merge; already audited in their own scope (`plan-close-shipped-rows/gates/audit-1-docs.md` covers `24561a0`; the release commit `3f122d4` is a `release.sh`-generated artifact in the carve-out).
**Why**: Recorded as a low-severity coverage trace rather than a finding — Section A has no defect to flag.
**Fix**: None.

---

**Section B — Adequacy**: No new touched reference docs in the Audit 2 range (only PLAN.md and audit-artifact files). The two adequacy-low findings from Audit 1 against `CLAUDE.md § Known Footguns` (Browse-binary cross-routing) and `kit/scripts/capture-screenshot.sh` Usage docstring are outside this audit's range (those were authored in `2f08711` and earlier, which `origin/main..HEAD` for Audit 1 covered) — they remain as low-severity nudges, neither closed nor re-opened by anything in `2f08711..HEAD`. Recommend the operator decide whether to action them before merge or carry as accepted low findings; no Audit 2 escalation.

**Section C — Cross-doc coherence**: PLAN.md worked-example reference at line 45 (post-merge) now cites `auth-ux-conventions`. Verified: row exists at PLAN.md:74. No stale cross-references to the deleted `gstack-symptom-wrappers` row or to `Gstack-symptom workarounds` ROADMAP section anywhere in tracked content. No coherence defects.

**Section D — Bypass trailer audit**: No `Docs-Coverage-Bypass:` trailers in range (`git log --format='%H%n%B%n---' 2f08711..HEAD | grep -E '^(Docs-Coverage-Bypass|CLAUDE-MD-Bypass):'` returns zero rows).

**Section E — CLAUDE.md hygiene**: Skipped (devshop self-mode; Section E is project-mode only per `ak-docs-review § Step E`).

**Summary**: `high=0 medium=0 low=2`

---

**Audit 2 verdict**: Audit 1's three high-severity findings are all resolved at HEAD by commits `1bb1347` (high #1 + #2) and `32db717` (high #3 — merge-up of origin/main per the Audit 1 recommended-fix's "rebase or merge first" recipe, with merge chosen due to virtiofs phantom error on rebase). Audit 1's two adequacy-low findings (CLAUDE.md Browse-binary cross-routing + capture-screenshot.sh Usage docstring) are outside the `2f08711..HEAD` range and persist unchanged — operator discretion on whether to action before merge. No new defects in the Audit 2 commit range.

### Tests findings

# Audit 2 — Tests

**Range**: `2f08711c297722a90f322df991e155b74ab270dc..HEAD`
**Feature dir**: `specs/gstack-symptom-wrappers/`

## Scope summary

The 5-commit range contains zero shell, hook, skill, or test changes. The diff is entirely:

- `PLAN.md` (close gstack-symptom-wrappers row + close 2 unrelated shipped rows from upstream merge)
- `kit/docs/CHANGELOG.md` + `kit/version` (1.32.0 bump from upstream merge)
- `specs/gstack-symptom-wrappers/` audit-1 artifacts (`review.md`, `gates/audit-1-docs.md`, `gates/audit-1-tests.md`)
- `specs/plan-close-shipped-rows/` audit-1 artifacts (from upstream merge)

Verification:

```bash
$ git diff --name-only 2f08711c..HEAD -- 'kit/scripts/**' 'kit/hooks/**' 'kit/tests/**' '.claude/skills/**'
(empty)

$ git diff --name-only 2f08711c..HEAD -- '*.bats' '*.sh' '*.test.*' '*.spec.*'
(empty)
```

The shell wrappers introduced earlier on this branch (`kit/scripts/capture-screenshot.sh` and the `init-devshop.sh` Chromium fallback / projects-symlink additions) plus their paired `.bats` suite were already audited in Audit 1 (tests side: high=0 medium=0 low=2). The upstream merge brought in only `PLAN.md` reconciliation + a version bump — no new shell or test surface that this branch would owe paired coverage for.

## Section A — Coverage of new behavior

No source changes in range → no coverage gaps possible. **No findings.**

## Section B — Test quality

No tests added or modified in range. **No findings.**

## Section C — Bypass trailer audit

Harvested `Tests-Coverage-Bypass:` trailers in `2f08711c..HEAD`:

```bash
$ git log --format='%H%n%B%n---' 2f08711c..HEAD | \
    awk '/^Tests-Coverage-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}'
(empty)
```

Zero trailers. **No findings.**

## Summary

Tests look solid — no findings.

`high=0 medium=0 low=0`

### Bypass trailer audit

- (none)
