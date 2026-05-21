# Audit 1 — Docs Review

- **Branch**: fix/squash-primary-judgment
- **Range**: origin/main..HEAD
- **Commits in range**:
  - `8027d02` fix(adversarial-review): stop FAILing clean titles on the squash surface
  - `41ee2d7` docs: enumerate both squash-surface NOTEs + lock the procedural-marker string
- **Verdict**: high=0 medium=0 low=0

## Scope of doc-touching changes

Code/test changes in range:

- `kit/scripts/adversarial-review.sh` — added `NOTE 1` (primary judgment vs bypass review) to the squash-surface CONTEXT block in the `prTextHygieneReason` case; renamed pre-existing surface-shape NOTE → `NOTE 2`. Both NOTEs now carry distinct, named, load-bearing semantics.
- `kit/tests/util-adversarial-review-narrowing.bats` — added 8 new assertions in the existing `prTextHygieneReason squash-surface` happy-path test pinning the new NOTE 1 prompt language (`Primary judgment`, `operator has NOT supplied a bypass`, `procedural marker`, `Do NOT apply the generic`).

Doc changes in range (committed in `41ee2d7` to close prior Audit 1 findings):

- `kit/docs/guide/hooks.md § Dual-surface check-types` (L473) — paragraph rewritten to enumerate both `NOTE 1` and `NOTE 2`, name what each does, and codify the dual-call-pattern contract (primary-judgment vs bypass-review distinction) for future dual-surface check-types.
- `.claude/skills/devshop/merge-devshop/SKILL.md § 0.4.5` (L534-545) — new paragraph after the `adversarial-review.sh` invocation bash block anchors the procedural-marker contract on the literal `"auto-check at compose time"` string, points at NOTE 1 on the script side as the canonical contract, warns that any "tightening" refactor that strips or operator-supplies the string would silently flip the surface back into bypass-review mode.

## Findings

### High

None.

### Medium

None.

### Low

None.

## Verification of prior Audit 1 findings (closure check)

Prior Audit 1 on `fix/squash-primary-judgment` reported `high=0 medium=1 low=1`:

1. **Medium — hooks.md § Dual-surface stale claim** ("one inlined NOTE skipping rule (c)" after the `8027d02` change added a second load-bearing NOTE): **CLOSED**.
   - L473 now reads "two inlined `NOTE` blocks the squash surface adds", followed by explicit per-NOTE breakdowns (`NOTE 1 — primary judgment, not bypass review` / `NOTE 2 — skip rule (c)`).
   - The dual-call-pattern contract is named at the end of the paragraph as guidance for future dual-surface check-types — extends the lesson beyond this single case.
   - Coherence: no stale "one NOTE" / "inlined NOTE telling the reviewer to skip rule (c)" phrasing remains anywhere in `kit/docs/` or `.claude/skills/devshop/` (verified by `grep -rn "inlined NOTE"` returning empty, and `grep -rn "NOTE.*skip"` returning only the new enumerated paragraph).
   - Other references to the squash surface that don't name a NOTE-count (CLAUDE.md L115; hooks.md L98, L200) remain accurate at their level of abstraction and do not need editing.

2. **Low — SKILL.md § 0.4.5 doesn't lock the procedural-marker string contract**: **CLOSED**.
   - L534-545 added a paragraph immediately after the bash block invoking `adversarial-review.sh`.
   - The paragraph (a) calls the literal string a "procedural telemetry marker, not an operator bypass-defense rationale"; (b) points the reader at `NOTE 1` in `kit/scripts/adversarial-review.sh` as the "canonical anchor"; (c) explicitly warns against "tightening" refactors that strip the value or make it operator-supplied; (d) names the failure mode (flip back into bypass-review mode, start FAILing clean titles again).
   - Reciprocal anchor on the script side: the engine's NOTE 1 names the example literal (`'auto-check at compose time'`), so a reader navigating either direction (skill → script or script → skill) finds the contract.

## Coverage / Adequacy / Coherence summary

- **Coverage**: every doc-relevant code change has a corresponding doc update. The `NOTE 1` addition in `adversarial-review.sh` is reflected in (a) the canonical anchor at `hooks.md § Dual-surface check-types` and (b) the caller-side reciprocal anchor in `merge-devshop/SKILL.md § 0.4.5`. Test-file additions do not require external doc updates (the tests are self-documenting and pin the new prompt language by `grep` — itself an in-test commentary on the contract).
- **Adequacy**: the new doc paragraphs are substantive (each names a specific failure mode, points at a canonical anchor, and codifies a contract a future refactor could break). The hooks.md addition extends the lesson into a generalizable dual-call-pattern contract for future dual-surface check-types — appropriate for a guide doc, not just a bug-fix note.
- **Coherence**: cross-references between hooks.md (canonical contract anchor) and merge-devshop/SKILL.md § 0.4.5 (caller-side procedural-marker note) are bidirectional and accurate. No stale claims remain elsewhere in the docs tree.

## Dismissals

None.
