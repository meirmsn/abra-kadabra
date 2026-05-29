## Gate 4: /simplify

**Verdict: pass.** No genuine simplifications found in the branch diff
(`.claude/skills/devshop/build/SKILL.md` Phase 1.1 shell snippet + prose,
`kit/tests/util-ak-build-skill.bats` Section G). Quality-only review across
reuse / simplification / efficiency / altitude. Suite green (46/46) at review
time.

### Shell snippet (Phase 1.1) — simplest correct form

```bash
git add "$FEATURE_DIR/spec.md"
if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then
  git commit -m "docs($FEATURE): expand spec (Phase 1)"
fi
```

- **Canonical idempotence pattern.** Stage first, then `git diff --cached
  --quiet` to detect whether staging produced a delta. This is the simplest
  correct guard. The obvious "shorter" alternative — `git commit ... || true` —
  is rejected correctly: it would swallow *real* commit errors, not just the
  "nothing to commit" no-op. The explicit guard is right, not over-engineered.
- **The `-- "$FEATURE_DIR/spec.md"` pathspec on the diff is load-bearing, not
  redundant.** Scoping the guard to the same file keeps it from sweeping any
  unrelated staged change a prior phase might have left in the index. Defensive-
  correct; keep it.
- **Mirrors the Phase 0.3 skeleton-commit precedent** (`chore($FEATURE): Phase 0
  spec skeleton`) — reuse, not reinvention.
- The 3-line idempotence comment is dense but every clause is load-bearing
  (explains *why* the guard exists for resume re-run safety). Valuable in a
  SKILL.md an LLM orchestrator reads top-to-bottom; not a trim target.

### bats Section G (G1–G4) — non-redundant, minimal

- Each assertion guards a **distinct surface**: G1 subsection header exists; G2
  commit-step content + no-push (scoped via `awk '/^## Phase 1: Spec/,/^## Phase
  2:/'`); G3 registry row; G4 resume rungs (scoped via `awk '/^### Resume
  check/,/^## Phase 0/'`, the same boundary Section F uses).
- **No overlap with existing assertions.** Section F guards rung 2 / reconcile —
  a different concern; no `committed` / `git show HEAD` / `## Task order`
  assertions pre-existed Section G.
- Reuses the established file patterns exactly: `awk ... > /tmp/...txt` region
  scoping, `grep -qF` for literal strings, `grep -c ... -ge N` for count. The
  G2 negative assertion (`! grep -q 'git push'`) is meaningful — the awk region
  boundary is verified correct (Phase 1 region contains no `git push`).

### Prose edits — tight

- Registry row 1, rungs 4/5, and the discriminator-paragraph amendment are
  minimal, accurate, and consistently phrased against committed state. The
  one-clause append to the discriminator paragraph (lines ~325–327) is exactly
  the light touch the spec prescribed, not a rewrite.
- The Phase 1.1 prose carries a mild intro/outro overlap on the resume-check
  rationale (the commit "so Step 0's resume check sees a complete spec" appears
  before the code block and again after as "so a session crash + restart finds
  the full spec"). Judged **acceptable-as-is, not a finding**: the text was
  approved verbatim at spec time (Edit region A), the two mentions anchor
  distinct decisions (commit-now vs no-push-yet), and trimming would diverge
  from approved spec scope. The repetition reinforces a load-bearing crash-
  safety rationale in a doc LLMs read sequentially.

## Dismissals

None.
