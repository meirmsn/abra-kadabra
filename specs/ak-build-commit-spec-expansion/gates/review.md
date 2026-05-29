## Gate 6: /review

**Diff reviewed:** `git diff origin/main..HEAD` — `.claude/skills/devshop/build/SKILL.md` (Phase 1.1 commit step + registry row 1 + resume rungs 4/5 + discriminator paragraph), `kit/tests/util-ak-build-skill.bats` (Section G), `kit/TODOS.md` (pre-existing-failure note). Devshop-self-mode: no app code, so the review targets the correctness of the instructional shell logic the orchestrator follows at runtime.

**Verdict: pass.** No findings. The shell logic is idempotent, the committed-state reads degrade safely on every edge case I exercised, the cross-region wording is internally consistent, and all 46 bats (incl. 4 new G-section) pass.

### What I verified (and why each is safe)

1. **Phase 1.1 commit snippet — idempotent + safe on first-run AND resume.** `git add "$FEATURE_DIR/spec.md"` then `if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then git commit ...; fi`.
   - First run: spec expanded → staged diff is non-empty → commits. Correct.
   - Resume re-entry where spec is already committed at HEAD: re-running the spec agent reproduces identical content → `git add` stages nothing new → `git diff --cached --quiet` is true → guard skips the commit (no "nothing to commit" error). Idempotent as designed (D4). Correct.
   - `$FEATURE_DIR` unset: not a real risk here — it is set once at Step 0 (line 252, `FEATURE_DIR="specs/$FEATURE"`) and used unquoted-safely throughout; the snippet quotes it (`"$FEATURE_DIR/spec.md"`), matching the existing Phase 0.3 precedent (line 665).
   - Wrong-branch / pre-commit interaction: the bare `git commit` relies on the orchestrator already being on the feature branch — identical to the Phase 0.3 skeleton commit (line 666), which has shipped without issue. A `docs()` commit of a single `spec.md` file clears the clean-tree / docs-coverage / mixed-commit guards the same way the Phase 0.3 `chore()` commit of the same single file does. The spec's Gotchas address this with the Phase 0.3 precedent; reasoning is sound.

2. **Committed-state reads (registry row 1 + rungs 4/5) — `git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'`.** Exercised the three states in a throwaway repo:
   - **Uncommitted (working-tree only) / unborn HEAD:** `git show HEAD:...` exits 128 ("invalid object name 'HEAD'" / path-not-in-HEAD), but piped into `grep -q` the pipeline's exit status is grep's (1) → rung evaluates false. Both rungs 4 and 5 fall through to **rung 6 (start from Phase 0)**, which is idempotent (re-runs the decisions preview + re-commits the skeleton). Safe — no error surfaced, correct routing.
   - **Crash-before-1.1-commit (HEAD = skeleton, working tree = expansion with `## Task order`):** rung 4 false (HEAD lacks the header), rung 5 true (skeleton committed, lacks header) → re-run Phase 1; the spec agent reads the working-tree file, preserves Decisions, re-expands, and 1.1 commits. This matches rung 5's "(or crashed before its 1.1 commit)" comment exactly. Verified empirically. Correct.
   - **Committed + expanded:** rung 4 true → skip to Phase 2. Correct.

3. **Registry row 0 vs row 1 read-state asymmetry is intentional, not a defect.** Row 0 (Phase 0 skeleton) still checks "file exists" (working tree); row 1 now checks committed state. A working-tree-only skeleton that never committed is caught by rung 6 (restart Phase 0, idempotent), so no scenario mis-routes.

4. **Cross-region consistency.** The discriminator paragraph (lines 325–330) was reworded to read against committed state (`git show HEAD:…`), matching rungs 4/5. The rung-5 producer attribution flipped to "Phase 0.3 committed the skeleton" — accurate (line 666). No dangling reference to the old working-tree `grep -q` shape remains.

5. **Pipe-escaping + bats.** Registry row 1 escapes the pipe as `\|` inside the markdown cell (line 146); G3's regex matches the escaped/rendered form. G4 asserts `committed at HEAD` count ≥ 2 (actual: 2) and the rung-4 inline `git show HEAD:` pipe. G2 scopes to the Phase 1 region and asserts the canonical message, the `git diff --cached --quiet` guard, and `! grep -q 'git push'`. All 46 tests pass (`kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-build-skill.bats`).

### Notes (non-blocking, no action required)

- The `kit/TODOS.md` entry correctly files the pre-existing `structural-invariants.bats:267` failure (`reconcile-task-commits.sh` not wired to a hook) as out-of-scope for this PR — it is unrelated to the SKILL.md/bats edits and predates this branch. Routing is per the TODO Protocol (devshop, fix-soon → `kit/TODOS.md`). No action in this gate.

## Dismissals

None.
