# Gate 11: convention

Branch: `fix/skill-operational-claude-md-routing` · Range: `origin/main...HEAD` · Date: 2026-06-02

**Verdict: PASS** — 0 blocking findings. The PR is a correctly-labeled root-cause fix
that closes a routing-gap class; no stale tracker entry maps to it; commit subjects
and pointer paths are clean.

## Checks run

### Closing TODO/ROADMAP entries when a fix ships — PASS (nothing to close)

Searched `kit/FRICTION-LOG.md`, `kit/TODOS.md`, `kit/ROADMAP.md` for an entry about
CLAUDE.md regrowth via skill-operational logic, the `f2c1e34` mis-homing, or a
classification-gate gap that fails to catch skill-operational content. **No such
entry exists** — `grep -rni "skill-operational|mis-hom|f2c1e34|operational logic|operational mechanic|reads as posture"`
across all three trackers returns nothing. The mis-homing was caught and fixed
within this same session (operator steer `d29ed969`, per `spec.md:9`) without ever
having been filed as friction, so there is nothing to delete/rewrite per
`CLAUDE.md § Closing TODO/ROADMAP entries`.

The nearest-neighbor entry — `kit/FRICTION-LOG.md:249` "Layer-B CLAUDE.md
classification gate doesn't re-fire at the `/ak-merge-devshop` squash boundary" — is
a **distinct gap** (audit-trail/harvest at the squash transport) and is correctly
NOT closed by this PR (which changes _what the gate catches_, not _whether it fires
at merge time_). No mis-attribution.

### Commit + PR text style (conventions.md) — PASS

The instruction named 4 subjects; the branch actually carries 7 commits (4 named +
3 spec/scaffold commits). All observable-change-led, all ≤72 except one borderline:

| SHA     | len | subject                                                                            | verdict                                              |
| ------- | --- | ---------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 21588ff | 73  | refactor(claude-md): relocate root-cause fix mechanic into ak-build skill          | 73 chars — 1 over the ≤72 guideline (see Dismissals) |
| 1654a52 | 64  | docs(claude-md-guide): add skill-operational routing destination                   | ok                                                   |
| c90bd3d | 82  | feat(claude-md-gate): enforce skill-operational routing in the classification gate | 82 chars — 10 over (see Dismissals)                  |
| c6ed8a3 | 69  | test(verify): record clean verification for skill-operational routing              | ok                                                   |
| 2082a19 | 68  | docs(skill-operational-claude-md-routing): record tasks.md (Phase 2)               | ok (spec scaffold)                                   |
| 1a8f947 | 77  | chore(skill-operational-claude-md-routing): Phase 0 spec skeleton (decisions)      | 77 — over, spec scaffold (see Dismissals)            |
| d745893 | 64  | docs(skill-operational-claude-md-routing): expand spec (Phase 1)                   | ok                                                   |

All subjects describe the observable change (relocate / add / enforce / record), not
implementation detail. The over-length subjects are addressed in Dismissals — they
are already committed history (immutable without a rebase/re-squash) and the
`/ak-merge-devshop` squash collapses them into one operator-authored subject anyway,
so the per-commit lengths never reach `main`.

### Root-cause vs bandaid (the convention being edited) — PASS, honestly labeled

This PR is itself a **root-cause fix**, and is labeled as such. It does not merely
move the one mis-homed entry (the bandaid) — it closes the _routing gap that allowed
the mis-homing class_:

1. relocates the mechanic into the skill (`devshop-mode.md § Phase 0 fix-assessment`),
2. adds a permanent **skill-operational routing-table row** to `claude-md.md`,
3. teaches the classification reviewer the **skill-operational sub-test** (rule 15(f))
   - relocation-staged enforcement (rule 15(c)) in `adversarial-review.sh`,
4. pins it with a LOUD bats test (3c) so the gate guidance can't silently regress.

`spec.md § D3` correctly frames it as "make the mis-homing class structurally
catchable," not a one-off scrub — i.e. tier-4 source-elimination, not a tier-1–3
mitigation. Honest labeling confirmed.

### Self-sufficiency (project CLAUDE.md) — PASS (n/a)

Diff touches only devshop `CLAUDE.md` and devshop `kit/` docs/skills. No project-side
CLAUDE.md is modified, so no `/devshop/...` cross-ref can leak into a public
contributor's view. Out of scope by construction.

### Reachability split — inline-vs-relocated placement — PASS

The relocation is correct per `§ Reachability split`:

- The **operational mechanic** (assess approach, surface root-cause-vs-mitigation as a
  Phase 0 decision, bandaid-spectrum tiers) moved OUT of always-loaded CLAUDE.md INTO
  the skill — it only fires inside an `/ak-build` run, so it failed the reachability
  test and belongs in the skill. Verified GONE from CLAUDE.md, PRESENT in
  `devshop-mode.md § Phase 0 fix-assessment` (verification.log:18-20).
- What stays inline in `CLAUDE.md § Implementation Approach` is a **one-line ambient
  value** ("bias toward the root-cause fix … always label honestly") + pointers — the
  correct residue. The one-clause parenthetical on the kernel line is acceptable
  pointer context (no step/tier/procedure detail).
- The new claude-md.md routing-table row + adversarial-review.sh sub-test are
  themselves _enforcement reference content_ and correctly live in the guide / script,
  not CLAUDE.md.

### Headers/JSDoc — n/a; shell/bats style — PASS

No `.ts`/`.tsx` touched. `check-claude-md-classification.sh` header block updated in
place (What/Why/Does-NOT preserved). New bats test 3c follows the existing file's
exact pattern (`run_script` / `assert_failure` / `assert_output --partial`, ordered
after 3b, well-commented with the LOUD-pin rationale). `bash -n` clean on both
scripts (verification.log:28-29).

### Cross-reference resolution — PASS

`.claude/skills/ak-build` is a symlink to `devshop/build`; both pointer forms used in
the diff (`.claude/skills/ak-build/devshop-mode.md` in CLAUDE.md/conventions.md and
`.claude/skills/devshop/build/devshop-mode.md` in claude-md.md/adversarial-review.sh)
resolve to the same real file. `§ Phase 0 fix-assessment` heading exists there. No
dangling section refs. (Independently confirmed; matches verification.log:5-15.)

## Dismissals

- **`c90bd3d` subject is 82 chars (10 over the ≤72 guideline)** — `n/a (committed
history + squashed away)`. Conventions.md's ≤72 rule is a per-subject readability
  guideline, not a blocking gate; this is already-committed history (rewriting needs a
  rebase the operator hasn't requested) and `/ak-merge-devshop` collapses all 7
  commits into ONE operator-authored squash subject, so this length never reaches
  `git log` on `main`. Surfaced for awareness; not actionable at this gate. Operator
  may tighten the squash subject at merge time.
- **`21588ff` (73), `1a8f947` (77) subjects 1–5 over** — `n/a (same reason)`. Marginal
  overage on committed history; squashed away at merge. The `1a8f947` length is
  inflated by the long `skill-operational-claude-md-routing` scope token (a
  scaffold-commit convention), not by a verbose description.
- **7 commits present vs 4 named in the brief** — `n/a (expected)`. The 3 extra
  (`1a8f947` Phase 0 skeleton, `d745893` Phase 1 spec, `2082a19` tasks.md) are the
  standard `/ak-build` spec-scaffold commits; their presence is correct, not a finding.
- **`kit/FRICTION-LOG.md:249` squash-boundary entry not closed** — `n/a (distinct
gap)`. Audit-harvest-at-squash is orthogonal to what-the-gate-catches; correctly
  left open.
- **Kernel-line parenthetical in CLAUDE.md describes the relocated mechanic** —
  `n/a (acceptable pointer context)`. Single line, no procedure detail; consistent
  with the routing row's "one-line ambient value + pointer" contract.
