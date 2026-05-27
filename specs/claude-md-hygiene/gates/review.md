## Gate 6: /review

- Result: findings (1) pending

### Finding 1 (medium): hooks.md implies `Claude-MD-Classification:` trailers are harvested at audit time, but no harvester exists yet

**File:** `kit/docs/guide/hooks.md` lines 91-97

The prepare-commit-msg documentation reads:

> `append-bypass-trailers.sh`: when `devshop.{tests,docs}CoverageReason` or
> `devshop.claudeMdClassification` is set, appends a `Tests-Coverage-Bypass:` /
> `Docs-Coverage-Bypass:` / `Claude-MD-Classification:` trailer to the commit
> message via `git interpret-trailers --in-place`. Trailers travel with the
> commit (survive rebase, push, clone) and audit-time `/ak-{docs,tests}-review`
> harvests them as `[bypass-revisit]` findings.

The final sentence claims `/ak-{docs,tests}-review` harvests these trailers. This is true for `Docs-Coverage-Bypass:` and `Tests-Coverage-Bypass:`, but `/ak-docs-review` Step E.4 only harvests `CLAUDE-MD-Bypass:` (the legacy trailer). No existing code harvests `Claude-MD-Classification:` trailers. The spec explicitly scoped this out ("Out of scope: Changes to `/ak-docs-review` Section E"), so the code is correct -- but the doc misleads a future reader into thinking audit-time harvesting already works for the new trailer.

**Fix:** Change the sentence to: "Trailers travel with the commit (survive rebase, push, clone). `Docs-Coverage-Bypass:` and `Tests-Coverage-Bypass:` are harvested at audit time by `/ak-{docs,tests}-review` as `[bypass-revisit]` findings. `Claude-MD-Classification:` trailers are recorded for future audit-time harvesting (see `kit/docs/guide/claude-md.md` Section E.4)." Or add a parenthetical: "(`Claude-MD-Classification:` harvest deferred -- see spec § Out of scope)."

### Notes (no action required)

- **CLAUDE.md condensed entry slightly inaccurate:** "Per-commit hooks run only Layer 1 (deterministic checks)" was already inexact before this diff (dirtyTreeReason, hookBypass, etc. are per-commit semantic/adversarial reviews). The new gate makes it marginally more misleading but this is pre-existing imprecision, not a regression from this branch. Noting for awareness; no fix needed in this PR since the entry's purpose is a pointer to the full contract, not a precise statement.

- **Spec line 101 says `Claude-MD-Classification-Bypass:` but code uses `Claude-MD-Classification:`** -- specs are historical after execution and not runtime artifacts. No fix needed.

- **Script correctness:** `check-claude-md-classification.sh` logic is sound: exit-early guards, pure-deletion detection via awk (portability-safe), bypass-flag reading, adversarial-review invocation, and blocking message all work correctly. No command injection risk -- the REASON value flows through `git config --get` (which is safe) into `adversarial-review.sh` as a positional argument (properly quoted), then into a temp-file prompt sent to `claude -p`. All 10 bats tests pass.

- **Security:** No path traversal risk. The script resolves `adversarial-review.sh` via `$GIT_ROOT/kit/scripts` (validated as non-symlink) or `/devshop/kit/scripts` (hardcoded). No user-controlled path interpolation.

- **Test coverage:** 10 tests cover: no-CLAUDE.md, pure-deletion, additions-no-bypass, bypass+PASS, bypass+FAIL, empty-bypass, devshop-self, project-mode, carve-out, mixed-deletion+other-files. The pre-commit-router.bats also validates wiring in all three dispatch paths. Coverage is thorough.

## Dismissals

None
