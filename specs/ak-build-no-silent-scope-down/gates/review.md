## Gate 6: /review

- Result: pass

Scope: devshop-self-mode, prose-only diff against `origin/main...HEAD`. Substantive
files: `.claude/skills/devshop/build/SKILL.md` (prohibition block + Phase 0
one-liner), `kit/docs/guide/workflow.md` (one coherence line in Step 4),
`kit/tests/util-ak-build-skill.bats` (new Section E, 6 grep-assertion tests).
No SQL, no auth/trust boundary, no conditional side effects, no runtime code,
no migrations — the standard /review surfaces are all n/a (see Dismissals).

The three substantive questions for this diff were examined directly:

### 1. Is the bats Section E sound? (positive greps non-trivial, absence assertions meaningful)

PASS. All 6 tests run green via the vendored bats binary (tests 31–36 `ok`).

- **Positive greps are not trivially-true.** Each positive pattern was traced to a
  single line, all inside the newly-added block (SKILL.md lines 57–97): `every
  phase, every task` (1 occurrence, L57), `no matter how small` (1, L58), `no
  discretion to hand-roll a lighter flow` (L64), `single exception` / `ask, never
  act` (L79), the three AskUserQuestion option labels (L89/L92/L97), and the
  enumeration requirement clauses (L93/L95). None pre-existed in the file, so a
  regression deleting the block flips each from match to no-match. Not anchored to
  incidental boilerplate.
- **`AskUserQuestion` (14 occurrences file-wide) is the one weak positive** — it
  pre-exists elsewhere in SKILL.md (the blocked-gate-override flow), so that single
  grep alone would survive deletion of the new block. But it is one assertion among
  a cluster in test 33 that also requires `single exception` + `ask, never act`
  (both block-unique), so the test as a whole still fails if the block is removed.
  Coverage holds; noted as low (see findings).
- **The two absence assertions are meaningful and NOT self-defeating.** The block's
  own prose says "no routine **applicability** check" (L66) and "no … pre-run
  **assessment**" (L68) — it deliberately avoids the exact strings the negative
  greps forbid. `! grep -qiE 'assess pipeline applicability'` → 0 matches file-wide;
  `! grep -qiE 'Step 0\.1'` → 0 matches (the literal "Step 0.1"; the file's `### 0.1:`
  heading and a `§0.1` cross-ref do NOT match the `Step 0\.1` pattern, confirmed).
  Both forbidden strings are the canonical regression phrasings named in spec.md D2
  (`### D2`, lines 54–63 and 146–148). So the negatives pin the specific shape D2
  forbids (a "Step 0.1: assess pipeline applicability" beat) without colliding with
  the prohibition prose itself — they are real guards, not tautologies.
- **Known narrowness (inherent to grep-based prose guards, not a defect):** the
  absence assertions catch the *canonical* regression wording but not an arbitrary
  reword (e.g. "Step 0.5: gauge scope"). The positive cluster pinning the
  unconditional-default + exception framing is the complementary coverage. This is
  the documented limit of literal-string guards and matches the spec's intent.

### 2. Does the prohibition block have an internal contradiction or loophole?

PASS. The block is internally consistent:
- Unconditional default (L57–70) + no-agent-discretion (L64–70) + single exception
  routed to AskUserQuestion (L79–99) + "ONLY path … Absent an explicit operator pick
  of option 2, you run every phase" (L101–102) form a closed loop with no escape.
- The acknowledgement that the agent may "feel a genuine impulse to deviate" (L79)
  is not a loophole: it is explicitly channelled to `AskUserQuestion` ("you do NOT
  act on it … You STOP and fire AskUserQuestion") rather than to action — this is
  the intended "ask, never act" design, distinct from the forbidden *routine* sizing
  beat (L66–69, which bans a systematic per-run gate, not an ad-hoc impulse).
- Option 2 ("reduced flow") is gated behind a hard precondition — the agent must
  first enumerate exactly which phases/artifacts drop and why each is safe — and is
  "selectable only by the operator, never by you" (L82). No self-service path.

### 3. Doc-coherence of the new H2?

PASS. The new `## Non-negotiable: run the full pipeline` is placed between the mode
description (L44–53) and `## Architecture: subagent delegation` (L104). Its forward
reference "Subagent delegation (below)" (L60) resolves correctly (that section is
below). The Phase 0 one-liner (L302–304) back-references `§ Non-negotiable: run the
full pipeline` — the section exists, anchor valid. The workflow.md Step 4 line is a
faithful prose summary of the block (full-by-default + asks-before-deviating) and
introduces no new H2 or broken pointer. No anchor drift.

### Findings

Low (1):

- **L-1: `AskUserQuestion` standalone grep in test 33 is non-block-specific.** The
  bare `grep -q 'AskUserQuestion'` matches a pre-existing occurrence (blocked-gate
  flow), so on its own it would survive block deletion. The test still fails overall
  because the two adjacent block-unique greps (`single exception`, `ask, never act`)
  carry it, so coverage is not actually lost — purely a precision nit.
  Fix: optionally tighten to anchor AskUserQuestion to the block, e.g. assert it
  co-occurs within the `## Non-negotiable` … next-`##` region via an `awk` range
  (mirroring the test-35 Phase-0 `awk` pattern). Non-blocking; leave as-is if the
  pair-grep coverage is deemed sufficient.

This is a HALT-ON-FIND gate, but the single finding is low-severity and does not
weaken the behavior the suite guards (the block-unique greps already fail-closed on
regression). Overall verdict: pass.

## Dismissals

- **SQL safety** — n/a. No SQL, migrations, or query strings in the diff.
- **LLM trust-boundary / prompt-injection** — n/a. The AskUserQuestion template is
  static operator-facing prose inside a skill doc, not a runtime prompt assembled
  from untrusted input.
- **Conditional side effects** — n/a. No runtime code; the diff is markdown + bats
  grep assertions only.
- **Structural / error-handling issues** — n/a. No control flow added; bats tests are
  flat single-assertion `@test` blocks consistent with the file's existing Sections A–D.
- **Auth / route protection** — n/a. No auth surface touched.
- **Performance** — n/a. Prose + 6 grep tests; negligible.
