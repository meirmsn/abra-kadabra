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
