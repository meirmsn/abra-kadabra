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
