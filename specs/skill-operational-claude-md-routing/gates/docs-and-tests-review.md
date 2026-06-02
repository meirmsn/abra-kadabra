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
