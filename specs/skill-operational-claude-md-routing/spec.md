<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: skill-operational-claude-md-routing -->
<!-- date: 2026-06-02 -->

# Spec: skill-operational-claude-md-routing

**Sources:**

- Operator steer (session `d29ed969`, 2026-06-02) — the bandaid-vs-root-cause
  directive was over-generalized into always-loaded CLAUDE.md by commit `f2c1e34`;
  operator wants the operational mechanic relocated into the ak-build skill and the
  classification gate hardened so the mis-homing can't recur.
- `CLAUDE.md § Implementation Approach` — current "Root-cause over bandaid" directive (the mis-homed text).
- `kit/docs/guide/conventions.md § Root-cause over bandaid` — taxonomy + worked example.
- `kit/docs/guide/claude-md.md` — inclusion rule, 3-class taxonomy, routing table.
- `kit/scripts/commit-hooks/check-claude-md-classification.sh` — Layer B gate.
- `kit/scripts/adversarial-review.sh § claudeMdClassification` (rule 15) — the Sonnet judge.
- `kit/tests/guard-claude-md-classification.bats` — the gate's bats coverage.

Relocate the root-cause-vs-bandaid _operational_ directive out of always-loaded
CLAUDE.md into the ak-build skill where it fires, and teach the CLAUDE.md
classification gate to route skill-operational logic into the owning SKILL.md so
the mis-homing class becomes structurally catchable.

---

## Product update

### Headline + Detail (combined)

Infrastructure update — no user-visible change in this PR. Relocates the
root-cause-vs-bandaid _operational_ directive out of always-loaded CLAUDE.md into
the ak-build skill where it actually fires, and adds a "skill-operational" routing
rule to the CLAUDE.md classification gate so operational logic for a named skill is
routed into that skill's SKILL.md instead of accreting in the always-loaded file.

---

## Decisions (resolved at spec time)

### D1: Where the operational mechanic lives

**Decision:** ak-build `devshop-mode.md` Phase 0 fix-handling step — when the
feature is a fix (esp. one sourced from a TODOS/ROADMAP/FRICTION blurb), assess
whether the proposed approach removes the cause or mitigates the symptom, and
surface the root-cause option alongside any mitigation via the existing Phase 0
decisions `AskUserQuestion`.

**Rationale:** Operator-locked. Matches the original ak-build-scoped framing; the
mechanic only bites inside an ak-build run.

### D2: What stays in CLAUDE.md

**Decision:** A thin one-line value kernel in `§ Implementation Approach` ("bias
fixes toward root cause; label honestly which a proposal is") + pointer to the
ak-build skill and conventions.md. Drop the `/ak-build Phase 0 AskUserQuestion`
mechanic prose from CLAUDE.md.

**Rationale:** Operator-locked. The general engineering value can stay ambient; the
operational mechanic relocates.

### D3: New routing destination, not a 4th taxonomy class

**Decision:** Add a "skill SKILL.md" routing destination (routing table row +
taxonomy note + reviewer rule), NOT a literal 4th classification class. Skill-
operational content is `reference`-class whose canonical home is a SKILL.md.

**Rationale:** Operator-locked (go). Less taxonomy churn; reuses the existing
reachability test (rule 15(f) already names skills). The gap was only that the
routing table had no skill row and rule 15(c) couldn't enforce a skill destination.

### D4: conventions.md § Root-cause over bandaid

**Decision:** Keep the taxonomy + worked example; repoint its "/ak-build Phase 0"
reference at the ak-build skill as the operational owner.

**Rationale:** The guide stays the reference home for the spectrum; the ownership
pointer follows the relocation.

---

<!-- /ak-spec (Phase 1) expanded below. Product update + Decisions stay verbatim. -->

## In scope

1. **Relocate the operational mechanic into ak-build.** The bandaid-vs-root-cause
   _assessment + surfacing_ step moves into `devshop-mode.md` (Phase 0 source
   routing / decisions area) as an explicit fix-handling step.
2. **Shrink the CLAUDE.md directive** to a one-line value kernel + pointers.
3. **Add a "skill SKILL.md" routing destination** to `claude-md.md` (routing table
   row + 3-class taxonomy note + reachability prose).
4. **Wire skill-operational into the gate**: the hook BLOCK guidance lists the skill
   destination; reviewer rule 15(c)/(f) enforce it.
5. **Repoint conventions.md § Root-cause over bandaid** at the ak-build skill.
6. **bats coverage** pinning the new skill-operational guidance in the hook.

## Out of scope

- Re-litigating the bandaid-vs-root-cause taxonomy itself (kept verbatim).
- A literal 4th classification class (decided against — D3).
- Auditing other CLAUDE.md entries for skill-operational leaks (separate sweep if wanted).

## Files to create/modify

| File                                                         | Change                                                                                              |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `CLAUDE.md`                                                  | Shrink `§ Implementation Approach` Root-cause directive to one-line kernel + pointers.              |
| `.claude/skills/ak-build/devshop-mode.md`                    | Add fix-assessment Phase 0 step (the relocated mechanic).                                           |
| `kit/docs/guide/conventions.md`                              | Repoint § Root-cause over bandaid's `/ak-build Phase 0` reference at the skill.                     |
| `kit/docs/guide/claude-md.md`                                | Add skill-operational routing-table row + taxonomy note + reachability prose.                       |
| `kit/scripts/commit-hooks/check-claude-md-classification.sh` | (denied path → sudo install) Add skill destination to BLOCK guidance + header `What/Why`.           |
| `kit/scripts/adversarial-review.sh`                          | (denied path → sudo install) Extend rule 15(c) destinations + sharpen 15(f) skill-operational test. |
| `kit/tests/guard-claude-md-classification.bats`              | New test: BLOCK guidance names the skill SKILL.md destination.                                      |

## Tests

- **bats** `guard-claude-md-classification.bats`: a new `@test` asserting the BLOCK
  guidance output names the skill-operational relocation destination (parallel to
  the existing Test 3b that pins the placement requirement). This is the LOUD-failure
  pin — if a future edit drops the skill destination from the guidance, the test reds.
- Full suite green: `pnpm turbo run test` (bats + any unit).

## Task order

1. **T1** — Relocate: ak-build `devshop-mode.md` fix-assessment step + shrink
   CLAUDE.md kernel + repoint conventions.md. (One logical change: the relocation.)
2. **T2** — Routing rule: `claude-md.md` skill-operational destination (table +
   taxonomy + reachability).
3. **T3** — Enforcement: hook BLOCK guidance + reviewer rule 15 (both via sudo
   install) + bats test. (Test written alongside.)

## Dependencies

None new. Denied-path edits (`kit/scripts/**`) use the `/tmp` + `sudo install -m … -o root -g root` handoff per `kit/docs/guide/security.md § Authoring locked files`.

## Gotchas

- `check-claude-md-classification.sh` and `adversarial-review.sh` are root-owned under
  `kit/scripts/**` — Write/Edit and Bash file-creation are denied. Author in `/tmp`,
  then `sudo install` preserving mode/owner. They can still be `git add`-ed.
- The husky hooks run under dash — keep the new bats/test edits POSIX (no bash-isms in any shell the hook sources). The bats test itself runs under bats.
- This PR edits CLAUDE.md → the very gate being changed fires on commit. The kernel
  shrink is a net **deletion + one-line replacement**; classify honestly (the
  relocation targets — skill + conventions.md — are staged in the same commit).

## Acceptance

- CLAUDE.md `§ Implementation Approach` carries only the one-line kernel + pointers; no Phase 0 mechanic prose.
- `devshop-mode.md` carries the fix-assessment step.
- `claude-md.md` routing table has a skill-SKILL.md row; reviewer rule 15 enforces it.
- New bats test green; full suite green.
