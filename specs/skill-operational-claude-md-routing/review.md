<!-- audited-at: c6ed8a375741428550357725156a0e69263909d8 -->

# Pre-ship review — skill-operational-claude-md-routing (devshop mode)

## Router Summary

- Gates dispatched: docs-check(1), fast-job-local(2d), /simplify(4), docs-and-tests-review(5), /review(6), convention(11)
- Carve-outs (n/a / blocked per scope): 2,2b,2c,2e,2f,2g,3,8b,10b (n/a); 7,8,9,10 (blocked — structural, no UI/auth/perf surface)
- Result: PASS — 0 high, 0 medium-blocking. Gate 5 surfaced 2 medium + 4 low coherence findings; 3 fixed (worked-examples row, SKILL.md-dir wording, project-mode overclaim), 3 accepted with rationale (below).

### Accepted findings (non-blocking)

- M1 (tests): the discriminating skill-operational rule lives in the live adversarial reviewer (rule 15(f)/(c)), which bats mocks out — not unit-testable. Test 5 pins the testable surface (hook BLOCK guidance). Accepted.
- L2 (owner split): 'surface both options' phrasing appears in conventions.md (taxonomy reference) + devshop-mode.md (operational owner). Intentional split — guide is reference, skill owns the mechanic. Accepted.
- L4 (dense kernel): CLAUDE.md kernel is one line with a parenthetical; judged acceptable pointer context (no procedural/tier detail). Accepted.

## Preflight

- TOUCHES_UI= (none)
- TOUCHES_MIGRATIONS= (none)
- TOUCHES_FUNCTIONS= (none)
- TOUCHES_KIT=kit/
- Mode: devshop-self
- Chromium: n/a (no UI surface)
- Supabase: n/a (no supabase surface)
- Result: pass

## Gate 1: docs-check

- Result: pass (docs-coverage pre-commit gate passed on every commit; kit/scripts edits paired with hooks.md; routing/taxonomy in claude-md.md)

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass (full bats suite 1647/1647 green at Phase 2.5; guard-claude-md-classification 12/12)

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

Reviewed the changed code surface in `git diff origin/main...HEAD` for reuse / simplification / efficiency / altitude cleanups (quality only, no bug-hunting). Docs (`.md`) out of scope. The code surface:

- `kit/scripts/commit-hooks/check-claude-md-classification.sh` — added a 5-line `echo` guidance block (skill-operational routing) + extended the header `# Why:` and the relocation-destination echo line.
- `kit/scripts/adversarial-review.sh` — extended the rule-15 reviewer prompt string (relocation-target destination clause + a "Skill-operational sub-test" paragraph).
- `kit/tests/guard-claude-md-classification.bats` — new test 3c pinning the skill-operational routing guidance in the block message.

**Outcome: nothing to simplify (pass).**

## Dismissals

- **Duplication between hook guidance and reviewer prompt → keep both.** Both surfaces now describe the skill-operational routing rule, but they serve different consumers at different altitudes: the hook `echo` text is concise operator-facing teaching shown at commit time (and already points at `kit/docs/guide/claude-md.md` for the canonical routing table), while the reviewer prompt is the LLM judge's rubric — necessarily more detailed (near-tells, sub-test phrasing) because it makes a judgment rather than teaches a human. This mirroring is pre-existing: the trap/reference/convention classification lines are already duplicated across the same two surfaces. There is no sourced-fragment mechanism in this codebase, and inventing one for a handful of `echo` lines would add more complexity than it removes and break the established pattern. Not a worthwhile simplification.

- **bats test 3c structure → keep as-is.** Uses the same two-`echo`-append idiom and the same shape as its neighbors (tests 3, 3b). 14 lines including comments, comparable to 3b. Matching the established file style is correct; not over-long.

- **Hook echo "or owning skill's SKILL.md" addition to the relocation line (110-111) vs. the new definition block (95-99) → keep both.** The definition block and the relocation-destination enumeration do different jobs, consistent with how the existing text already restates "relocate to canonical home" in both the classify list and the relocation line. Not redundant.

Validation: `bash -n` clean on both touched scripts; all 12 tests in `kit/tests/guard-claude-md-classification.bats` pass.

## Gate 5: docs-and-tests-review

findings: high=0 medium=2 low=4

Audit of `git diff origin/main...HEAD` for the `fix/skill-operational-claude-md-routing` branch.
Devshop-self docs/gate change (no app runtime). Findings surfaced, not fixed.

Scope of change: a new "skill-operational logic" classification case that closes the regrowth
vector where a step/check/gate/decision a named skill performs gets phrased as an ambient
CLAUDE.md directive. Touches CLAUDE.md (kernel shrink), claude-md.md (reachability bullet +
routing row + reference-class clause), conventions.md (repoint), hooks.md (gate-table entry),
adversarial-review.sh (rule 15(c) + 15(f) sub-test), check-claude-md-classification.sh (block
guidance), devshop-mode.md (new Phase 0 fix-assessment section), and one new bats test.

### Verified coherent (no finding)

- **CLAUDE.md kernel shrink** (CLAUDE.md:48): the remaining one-line value ("bias toward the
  root-cause fix … always label honestly which one a proposal is") fully carries the ambient
  posture; the removed operational mechanic (assess approach / surface as Phase 0 decision when
  cost differs) is relocated with an accurate pointer. Pointer
  `.claude/skills/ak-build/devshop-mode.md § Phase 0 fix-assessment` RESOLVES — `ak-build` is a
  symlink to `devshop/build`, and `devshop-mode.md` line 67 carries the
  `### Phase 0 fix-assessment — root-cause vs bandaid` heading. No dangling reference.
- **conventions.md repoint** (conventions.md:653-661): correctly rewritten. The prior text said
  "(in `/ak-build`) surface the root-cause option … via the Phase 0 decisions `AskUserQuestion`";
  the new text generalizes the surface step and attributes the operational mechanic to
  `/ak-build` (`.claude/skills/ak-build/devshop-mode.md § Phase 0 fix-assessment`) with
  `CLAUDE.md § Implementation Approach` named as the ambient-value home. No stale claim implying
  CLAUDE.md owns the mechanic.
- **hooks.md rule references accurate** (hooks.md:184): `rule 15(f)` (Reachability split, now
  carrying the Skill-operational sub-test) and `rule 15(c)` (Relocations landed — requires the
  named skill file staged) both match adversarial-review.sh's claudeMdClassification check-type
  (rule 15, sub-rules a–f at lines 1226-1296). Commit `f2c1e34` cited as the gap-incident is real
  ("docs(claude-md): bias fixes toward root-cause over bandaid"). `claude-md.md § Layer B`
  resolves (claude-md.md:124).
- **claude-md.md internal consistency**: the new reachability bullet (line 23), reference-class
  clause (line 63), and routing-table row (line 99) are mutually consistent and all cross-cite the
  `§ Reachability split` heading (line 17) and each other. The routing row's "fails the
  reachability test (§ Reachability split)" pointer resolves.
- **devshop-mode.md tier references correct**: the new section's bandaid-spectrum tiers
  (avoid-blast-radius / detect-and-repair / containment = tiers 1–3 mitigation; source-elimination
  = tier 4 root cause) match conventions.md § Root-cause over bandaid (lines 636-650) exactly.
- **devshop-mode.md does not contradict project-mode Phase 0**: SKILL.md § 0.2 (lines 373-382)
  defines the shared Decisions-table mechanic with `[USER MUST DECIDE]`; the new section hooks a
  fix-assessment row into that same table and explicitly says project mode inherits via the
  project-side Phase 0.2. Extends, does not duplicate.
- **bats Test 3c pins the right behavior** for what it asserts: the BLOCK guidance must surface
  the skill-operational routing rule (`assert_output --partial "Skill-operational"` +
  `"SKILL.md"`), which guard-classification.sh now prints (lines 95-99 of the script). This reds
  if a future edit drops the routing text from the gate.

### Findings

**[MEDIUM] Tests — no coverage that the gate PASSES a correctly-relocated skill-operational entry.**
File: kit/tests/guard-claude-md-classification.bats:92-105 (Test 3c).
The new test only pins the BLOCK _guidance text_ (deterministic-layer message). It does NOT
exercise the actual new rule: that a skill-operational entry reduced to a one-line value + pointer,
with the owning skill file staged, PASSES, while the same entry inlining the mechanic (or omitting
the skill-file stage) FAILS. That judgment lives in adversarial-review.sh rule 15(f) sub-test +
15(c), which the deterministic bats suite mocks out (Test 4/5 use `mock_adversarial_review PASS/FAIL`
and never assert _what reason shape_ drives the verdict). The new rule's actual discriminating
behavior — relocate-to-skill passes, inline-the-mechanic fails — is therefore unpinned by any test;
only the operator-facing nudge string is. A regression in the reviewer prompt (e.g. dropping the
15(f) sub-test or the 15(c) skill-file-staged clause) would not red any test.
Recommendation: add a positive-path test in the style of Test 4 — stage a CLAUDE.md one-line value +
pointer AND a skill SKILL.md/devshop-mode.md file, set a `claudeMdClassification` reason naming the
skill relocation, mock adversarial PASS, assert success. Optionally a negative companion asserting
the gate's deterministic layer still defers the judgment to the reviewer (documents that the
deterministic layer intentionally can't catch inline-mechanic-without-relocation). At minimum,
note in the test file that the skill-operational _judgment_ is reviewer-owned and exercised only at
audit time / via the reviewer mock, so a future maintainer doesn't read Test 3c as full coverage.

**[MEDIUM] Docs — skill-operational case absent from the Reachability-split worked-examples table.**
File: kit/docs/guide/claude-md.md:27-35.
The change adds the skill-operational case to the reachability prose (line 23), the reference-class
clause (line 63), and the routing table (line 99) — but NOT to the `**Worked examples**` table
(lines 29-35) directly under § Reachability split. That table is the at-a-glance "given this gotcha
shape, what's the verdict" reference, and the new case is precisely a gotcha-shape with a
non-obvious verdict (reads as ambient posture, routes to a skill). Its omission means the table no
longer enumerates the full set of split outcomes the section teaches, and a reader scanning only the
table would miss the new regrowth vector.
Recommendation: add a row, e.g. `| "/ak-build Phase 0 always assesses root-cause vs bandaid" |
Skill-operational → relocate to skill SKILL.md (one-line value + pointer stays) | Only fires inside
the skill run; can't bite ambiently. |`. The routing row already carries the same 2026-06-02 worked
example, so this is for completeness/discoverability, not correctness.

**[LOW] Docs — hooks.md narrows the relocation target to "SKILL.md" but the rule (and this PR)
allow any file in the skill's dir.**
File: kit/docs/guide/hooks.md:184 ("must relocate to the owning skill's SKILL.md (rule 15(c)
requires that skill file staged)").
Both rule 15(c) (adversarial-review.sh:1245-1249) and the routing-table row (claude-md.md:99)
explicitly permit "a file in the skill's dir, e.g. `.claude/skills/devshop/build/devshop-mode.md`",
and this very PR relocated to `devshop-mode.md`, NOT `SKILL.md`. The hooks.md prose says only
"SKILL.md", which is technically narrower than the enforced rule and the demonstrated example.
Recommendation: soften to "the owning skill's `SKILL.md` (or a file in the skill's dir)" to match
the rule it summarizes. Cosmetic — the cited rule 15(c) is the binding source and is correct.

**[LOW] Docs — conventions.md and devshop-mode.md split the "surface both options" instruction
without a single owner.**
Files: kit/docs/guide/conventions.md:653-661, .claude/skills/devshop/build/devshop-mode.md:67-95.
conventions.md now says "surface the root-cause option alongside it so the operator picks the
depth" generically (no longer naming the Phase 0 AskUserQuestion), then says `/ak-build` owns the
operational mechanic. devshop-mode.md step 3 restates the same "surface both … mark
`[USER MUST DECIDE]` … at the Phase 0 `AskUserQuestion`" mechanic. The split is intentional (guide =
taxonomy, skill = mechanic) and not contradictory, but the "surface both" obligation is now stated
in two places at slightly different altitude. Low risk of drift if one is edited without the other.
Recommendation: none required; flagged so a future editor keeps the two in sync. Acceptable as-is.

**[LOW] Docs — devshop-mode.md asserts "Project mode inherits the same assessment" but no
project-mode fix-assessment instruction exists.**
File: .claude/skills/devshop/build/devshop-mode.md:91-95.
The closing paragraph claims project mode inherits the fix-assessment "via the project-side Phase
0.2 Decisions table." SKILL.md § 0.2 (lines 373-382) defines a _generic_ Decisions table with
`[USER MUST DECIDE]` but contains NO explicit fix-assessment / root-cause-vs-bandaid step. The
inheritance is therefore aspirational/implicit: a project-mode `/ak-build` run on a `fix/` branch
has no instruction telling it to add the root-cause row. If the intent is that project fixes get
the same forcing function, the mechanic currently only fires in devshop mode.
Recommendation: either (a) add a one-line fix-assessment pointer to SKILL.md § 0.2 (e.g. "for
`fix/` features, add a root-cause-vs-bandaid row — see `devshop-mode.md § Phase 0 fix-assessment`,
which applies in both modes"), or (b) soften devshop-mode.md's claim to "project mode can apply the
same assessment via its Decisions table" rather than asserting it inherits automatically. Surfacing
only — the change is internally coherent within devshop mode.

**[LOW] Docs — CLAUDE.md kernel line is dense (single ~80-word sentence with two nested pointers).**
File: CLAUDE.md:48.
The shrunk kernel line packs the value + the operational-mechanic pointer + the taxonomy pointer
into one long sentence. It reads correctly but is at the upper bound of "one-line ambient value"
the routing row prescribes. Not a defect (it IS shorter than the prior version and is value-not-
mechanic), flagged only as a readability nit.
Recommendation: optional — none needed; the line satisfies the new rule it codifies.

## Dismissals

- **gstack `.gitignore` finding** — n/a for this gate (no `.gstack/` change in range).
- **"Phase 0 fix-assessment pointer is broken" (potential)** — dismissed: verified the `ak-build`
  symlink → `devshop/build` resolves the path, so the pointer is live, not dangling.
- **"hooks.md rule 15(f)/(c) numbering is wrong" (potential)** — dismissed: verified against
  adversarial-review.sh:1226 (rule 15) and sub-rules (c) line 1241 / (f) line 1273. Accurate.
- **"devshop-mode.md duplicates project-mode Phase 0" (potential)** — dismissed: it extends the
  shared Decisions-table mechanic with a fix-specific row; no contradictory restatement of the
  preview/blurb/tracker mechanics SKILL.md owns.

## Gate 6: /review

**Surface**: devshop-self docs + one shell hook + adversarial reviewer prompt + bats test + ak-build skill file. No app runtime, no SQL, no auth, no trust-boundary surface.

**Verdict: PASS** — no findings.

### Shell correctness

- `bash -n kit/scripts/adversarial-review.sh` → clean.
- `bash -n kit/scripts/commit-hooks/check-claude-md-classification.sh` → clean.
- The hook's three added `echo` lines (the skill-operational guidance block + the two appended clauses) are plain double-quoted strings with no embedded `"`, `` ` ``, `$`, or `\`; the BLOCK guidance still renders and the `exit 1` path is untouched. The existing `\"` escapes in the `Usage:` line are unchanged.
- `adversarial-review.sh` rule-15 edits sit entirely inside the large `PROMPT="..."` double-quoted string (opens L1047, closes on the `...what was missed>"` line ~L1306). Added prose uses single quotes (`'when you do X, always Y'`, skill names) which are literal inside a double-quoted string, and contains no unescaped `"`, backtick, or `$`. `bash -n` (the authoritative parse check) confirms the heredoc/string boundaries are intact — no stray char broke the gate.

### Logical soundness — rule 15(c)/(f)

- **15(f) skill-operational sub-test** correctly targets the failure mode: a "trap" whose body is operational logic for a NAMED skill fails the reachability test by construction (can't bite before the skill is opened), even when phrased as an ambient directive. The near-tell ("entry names a specific skill / phase / gate") is a concrete, non-circular discriminator. It does NOT false-positive on legitimate ambient traps (symptom + first-action) because those bite before any skill is opened and name no owning skill as the locus of behavior.
- **15(c)/(f) coherence**: the two clauses compose without contradiction. 15(f) forces a misfiled inline trap to be reclassified as reference→relocate; 15(c) then enforces that the named skill destination file is staged in the same commit. The "or a file in the skill's dir, e.g. `.claude/skills/devshop/build/devshop-mode.md`" clause is coherent with how this very PR relocated the root-cause mechanic (into devshop-mode.md, not SKILL.md) — the relaxation is intentional and self-consistent with the worked example cited in claude-md.md.

### bats test quality (Test 3c)

- Test 3c has no skip guard and runs in devshop-self mode. It asserts `assert_failure` plus the two exact substrings the new hook `echo` lines emit (`Skill-operational`, `SKILL.md`), so dropping the guidance from the gate reds the test — a genuine LOUD pin on the routing destination.
- Scope note (not a finding): the bats layer pins the BLOCK-message _guidance text_, not the reviewer's semantic _judgment_ that skill-operational content gets rejected. That is correct by design — the adversarial reviewer is mocked in this suite, so the semantic judgment lives in rule 15(f) prose and is not unit-testable here. The pin is meaningful for what it can pin.
- Full suite (`guard-claude-md-classification.bats`) → exit 0.

### Doc coherence

- Symlink path `.claude/skills/ak-build/devshop-mode.md` and real path `.claude/skills/devshop/build/devshop-mode.md` BOTH resolve (`ak-build` → `devshop/build` symlink confirmed). The pointers in CLAUDE.md / conventions.md (symlink form) and the routing-table row + reviewer prompt (real form) all point at the same live file.
- Cross-reference anchors all resolve: `§ Reachability split` (claude-md.md L17), `§ Phase 0 fix-assessment` heading (devshop-mode.md L67), the **skill-operational** routing-table row (claude-md.md L99), `§ Root-cause over bandaid` (conventions.md).
- CLAUDE.md § Implementation Approach now correctly keeps only the one-line ambient value + pointer; the mechanic prose was removed and relocated to devshop-mode.md — consistent with the new routing rule the same PR introduces (eats its own dog food).

### Trust-boundary / SQL / auth

NONE, as expected. Diff grep for SQL verbs / `getUser` / service-role / `eval`/`exec` returns only doc-prose substring matches ("Delete from CLAUDE.md…", existing guard-table text quoting `posthog.capture`), no added code.

## Dismissals

None.

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

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

## Audit 1: manual (2026-06-02)

<!-- audited-at: c6a3109adb7ee24ce937784094cfba82990aaaa9 -->
<!-- range: origin/main..c6a3109 -->

findings: high=0 medium=1 low=3

### Docs findings

- [medium] (commit bodies c90bd3d, 21588ff) — kit/scripts/** commits lack an `**Existing projects:**`block. RESOLVED at squash: the /ak-merge-devshop squash message carries`**Existing projects:\*\* [auto]` and Phase 0.4.5 hygiene (dimension d) verified its presence.
- [low] CLAUDE.md:48, conventions.md:653 cite `.claude/skills/ak-build/devshop-mode.md` while claude-md.md/hooks.md/adversarial-review.sh cite `.claude/skills/devshop/build/devshop-mode.md`. ACCEPTED — `ak-build` is a symlink to `devshop/build`; both resolve, neither dangles. Dual form is intentional (prose uses the skill-name form; enforcement uses the on-disk form).

### Tests findings

- [low] guard-claude-md-classification.bats:94 — Test 3c name/comment overclaim ("routes skill-operational logic"); it pins the BLOCK-guidance _string_, not routing behavior (the discriminating judgment is in the mocked reviewer). ACCEPTED — it's the only deterministic surface; framing nit noted for a future touch.
- [low] adversarial-review.sh rule 15(c)/(f) — the reviewer sub-test has no bats coverage (reviewer is a live `claude -p` call, mocked by design). ACCEPTED structural gap — a PASS-path test would collapse into the canned-mock and prove nothing; deterministic prompt-rule coverage is a separate (out-of-scope) capability.

### Bypass trailer audit

- `c6ed8a3` Docs-Coverage-Bypass — VERIFIED (verification.log is a specs/ artifact, outside the coverage rubric)
