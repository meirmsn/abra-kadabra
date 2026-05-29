<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: hygiene-threedot-polish -->
<!-- date: 2026-05-28 -->

# Spec: hygiene-threedot-polish (devshop)

**Sources:**

- `kit/TODOS.md § Harden the Phase 0.4.5 dimension-(d) three-dot fix (workflow.md cross-ref + test N/A assertion)` — primary scope (the two non-blocking lows)
- `PLAN.md § Planned (v0)` row `hygiene-threedot-polish` — scope summary + source pointer
- Shipped fix `b174a11` (`fix(hygiene): no phantom propagation-block flag on diverged squashes`) — the change this hardens
- Audit trail: `specs/hygiene-prop-block-base-diverged/review.md § Audit 1` — where the two lows were flagged
- `kit/scripts/adversarial-review.sh` (lines 360–435) — NOTE 3 + `$PROP_SURFACES` prompt construction (read at Phase 0 for empirical D2 verification)

Follow-up polish to the shipped dimension-(d) three-dot fix: a doc cross-ref so readers don't infer the `/ak-merge-devshop` Phase 1.0 rebase alone covers every base-divergence phantom, plus a stronger bats assertion that positively verifies dimension (d) is N/A (surface list empty) rather than merely asserting one phantom filename is absent.

---

## Product update

### Headline + Detail (combined)

**Headline (user-facing):** Infrastructure update — no user-visible change.

**Detail (team-facing):** Hardens the shipped dimension-(d) three-dot phantom-surface fix (`b174a11`) by closing the two non-blocking lows its Audit 1 flagged: (1) a doc cross-ref in `workflow.md` (and a complementary NOTE 3 description in `hooks.md § Dual-surface check-types`) so a reader doesn't infer the Phase 1.0 rebase alone is the remedy for all base-divergence phantoms — the Phase 0.4.5 dimension-(d) precompute fires BEFORE the rebase and got its own three-dot fix; (2) a positive bats assertion in test 18 that the rendered propagation-surface list is empty, so a differently-broken three-dot that produces a *different* phantom path can't slip past the existing one-filename absence check. No script/behavior change — `adversarial-review.sh` is untouched.

---

## Decisions (resolved at spec time)

3 decisions resolved in Phase 0 with the operator (D2 deviates from the source TODO based on empirical verification).

### D1: Where the doc cross-ref lives

**Decision:** Add the clause to `kit/docs/guide/workflow.md:488` (the `/ak-merge-devshop` skill-map row) **AND** add a NOTE 3 description to `kit/docs/guide/hooks.md § Dual-surface check-types` as the cross-ref target.

**Rationale:** The TODO offers hooks.md as "alternatively/additionally," but a cross-ref needs something to point at — `hooks.md § Dual-surface check-types` currently documents NOTE 1 + NOTE 2 but omits NOTE 3 (dimension d), so `workflow.md` would dangle without it. Adding the NOTE 3 description (which records the three-dot `origin/main...$BRANCH` basis and why) gives `workflow.md:488` a real, complete target.

### D2: Test 18 positive-assertion mechanism

**Decision:** In `kit/tests/util-adversarial-review-narrowing.bats` test 18, positively assert the rendered `$PROP_SURFACES` region is empty (extract the lines between the `empty means none:` header and the `Squash body contains an` line; assert that region is whitespace-only). Do **NOT** use the TODO's suggested `grep -qiF "If the list is EMPTY"`.

**Rationale:** **Empirically verified at Phase 0.2.5** — `"If the list is EMPTY"` is static boilerplate inside NOTE 3 at `adversarial-review.sh:427`; it is emitted in every prompt regardless of whether the surface list is actually empty, so it adds zero discriminating power over the existing `grep -qF "NOTE 3"`. The TODO author's *goal* (positively assert dimension d is N/A) is correct; the suggested *mechanism* does not achieve it. Asserting the rendered `$PROP_SURFACES` region is empty genuinely catches any phantom-surface regression (any path, not just the one `template/.gitignore` literal test 18 currently greps for).

### D3: Whether to also harden test 16

**Decision:** No — leave test 16 (`dimension d is N/A when diff touches no propagation surface`) unchanged. Out of scope.

**Rationale:** Test 16 shares the same weak `grep -qiF "If the list is EMPTY"` assertion, but the TODO scopes only test 18. Deferring keeps this an XS change. Noted as a discovered-but-deferred item; not tracked separately (low value — test 16's scenario is already covered structurally by the dimension-d N/A path).

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Product update +
     Decisions sections above are verbatim from the Phase 0 skeleton. -->

## Core user story

N/A — devshop-internal doc + test hardening; no user-facing flow added or modified.

## In scope

Three surgical edits closing the two non-blocking lows from `specs/hygiene-prop-block-base-diverged/review.md § Audit 1`, plus the cross-ref target that low (1) implies:

1. **`workflow.md:488` cross-ref clause** — the `/ak-merge-devshop` skill-map row currently credits ONLY Phase 1.0's rebase as the remedy for base-divergence two-dot phantom findings in the audit. Add a clause noting that the Phase 0.4.5 dimension-(d) propagation-surface precompute fires BEFORE the rebase and got its OWN complementary three-dot fix (codified `b174a11`), so a reader doesn't infer the rebase alone covers all base-divergence phantoms. Cross-ref `hooks.md § Dual-surface check-types`.

2. **`hooks.md § Dual-surface check-types` NOTE 3 description** (the cross-ref target) — the section documents NOTE 1 and NOTE 2 but omits NOTE 3 (dimension d). Add a NOTE 3 description recording that dimension (d) precomputes the propagation-surface list via three-dot `git diff --name-only origin/main...$BRANCH` (NOT two-dot `origin/main..$BRANCH`), so a base-diverged worktree doesn't get every origin/main-only propagation-surface file reported as a phantom touched path. Cite the worked incident (docs/csp-img-src merge 2026-05-28 phantom-FAILed on `template/.gitignore`; codified `b174a11`).

3. **bats test 18 positive surface-empty assertion** — in `kit/tests/util-adversarial-review-narrowing.bats`, the test titled `prTextHygieneReason squash-surface: dimension d uses three-dot diff — no phantom surface on base-diverged branch` (line 310) asserts the phantom file is ABSENT but does not positively assert the rendered propagation-surface list is empty. Add a positive assertion that the rendered `$PROP_SURFACES` region of the captured prompt is whitespace-only (extract the region between the `empty means none:` header line and the `Squash body contains an` line; assert it has no non-whitespace chars).

## Out of scope

- **No script / behavior change.** `kit/scripts/adversarial-review.sh` is NOT modified. The three-dot fix it carries (`b174a11`) is already shipped and correct; this feature only documents it and strengthens the test that pins it. (Note: the canonical `kit/scripts/**` tree is permission-locked, but no edit to it is needed regardless.)
- **No new bats file.** Test 18 already exists in `util-adversarial-review-narrowing.bats`; the change is one added assertion inside it.
- **Test 16 left unchanged** (per D3) — it shares the same weak `grep -qiF "If the list is EMPTY"` assertion but is out of this feature's TODO scope; deferred, not separately tracked.
- No `workflow.md` change beyond the single skill-map row clause at line 488.

## Files to create / modify

| File | Change |
| ---- | ------ |
| `kit/docs/guide/workflow.md` | MODIFY — append a cross-ref clause to the `/ak-merge-devshop` skill-map row (line 488) noting the Phase 0.4.5 dimension-(d) three-dot precompute as a complementary base-divergence remedy alongside the Phase 1.0 rebase; point at `hooks.md § Dual-surface check-types`. |
| `kit/docs/guide/hooks.md` | MODIFY — add a NOTE 3 description to the `§ Dual-surface check-types` prose (after the NOTE 1 / NOTE 2 descriptions, around line 495), recording the three-dot `origin/main...$BRANCH` basis, why two-dot manufactured phantoms, and the worked incident. This is the cross-ref target for `workflow.md:488`. |
| `kit/tests/util-adversarial-review-narrowing.bats` | MODIFY — inside test 18 (line 310), add a positive assertion that the rendered `$PROP_SURFACES` prompt region is whitespace-only. |

No files created. `adversarial-review.sh` is untouched (read-only at Phase 0 for D2 verification).

## Tests (bats)

Test surface is bats (`kit/tests/`), not vitest/Playwright. One test is strengthened; no new test file.

- **Strengthen test 18** (`util-adversarial-review-narrowing.bats:310`) — the existing test already drives the squash surface against a base-diverged branch and asserts (a) `template/.gitignore` is ABSENT from the captured prompt and (b) `NOTE 3` is present. Add a third assertion that positively verifies dimension (d) is N/A by confirming the rendered `$PROP_SURFACES` region is empty:

  ```bash
  # Positively assert the rendered propagation-surface region is EMPTY (dimension
  # d is genuinely N/A), not merely that the one known phantom filename is absent.
  # A differently-broken three-dot could emit a DIFFERENT phantom path the
  # filename-absence check above would miss; an empty rendered region catches all.
  # NOTE: do NOT grep for the static "If the list is EMPTY" boilerplate — it lives
  # in NOTE 3 unconditionally (adversarial-review.sh:427) and has zero
  # discriminating power. Extract the region between the surface-list header and
  # the next prompt line, then assert it is whitespace-only.
  PROP_REGION=$(awk '/empty means none:/{f=1;next} /^Squash body contains an/{f=0} f' "$CAPTURED_PROMPT")
  [ -z "$(printf '%s' "$PROP_REGION" | tr -d '[:space:]')" ]
  ```

  The awk extraction targets the prompt construction at `adversarial-review.sh:389–392`: the `empty means none:` header line (389), then `$PROP_SURFACES` (390), then a blank line (391), then `Squash body contains an **Existing projects:** block: ...` (392). When the branch touches no propagation surface, `$PROP_SURFACES` expands to empty, so the captured region between the markers is whitespace-only — the assertion passes. A regression that re-introduces a two-dot diff would expand `$PROP_SURFACES` with phantom paths, leaving non-whitespace content in the region — the assertion fails.

- **Full suite stays green** — `pnpm turbo run test` (or the bats run for the touched file) must pass. The two doc files have no test coverage of their own (prose); the test change is the only executable delta.

### Why the D2 mechanism, not the TODO's suggested grep

The source TODO suggested `grep -qiF "If the list is EMPTY"`. D2 (empirically verified at Phase 0) rejects it: that string is static boilerplate emitted in NOTE 3 on **every** squash-surface prompt regardless of whether the surface list is actually empty (`adversarial-review.sh:427`), so it has zero discriminating power over the existing `grep -qF "NOTE 3"`. The region-extraction approach asserts the actual rendered `$PROP_SURFACES` value, which is the thing that genuinely differs between the fixed (empty) and regressed (phantom paths) states.

## Dependencies

- bats + the vendored submodules (`bats-support`, `bats-assert`) — already present; this is a worktree, so `git -C <worktree> submodule update --init --recursive` was run at worktree creation (no further setup).
- No package installs, no schema, no service dependencies. Pure doc + test edit.

## Task order

Flat (3 tasks, ≤15):

1. **workflow.md:488 cross-ref clause** — append the dimension-(d)/Phase-0.4.5 complementary-remedy clause to the `/ak-merge-devshop` skill-map row; cross-ref `hooks.md § Dual-surface check-types`. Commit.
2. **hooks.md NOTE 3 description** — add the NOTE 3 description to `§ Dual-surface check-types` (three-dot basis, two-dot-phantom rationale, worked incident, `b174a11`); this is the target `workflow.md:488` points at. Commit. (Tasks 1 and 2 land the cross-ref + target together; both touch only docs.)
3. **bats test 18 positive assertion** — add the `$PROP_SURFACES`-region whitespace-only assertion to test 18 via the D2 awk-extraction mechanism. Run the bats file to confirm green. Commit.

## Gotchas

- **Static-boilerplate trap (D2)** — the obvious `grep "If the list is EMPTY"` does NOT test what it appears to; it is unconditional NOTE 3 text. The test MUST assert the rendered `$PROP_SURFACES` value, not the surrounding boilerplate. This is the whole point of low (3) — a stronger assertion, not a redundant one.
- **awk region boundaries are exact** — the start marker `empty means none:` and stop marker `^Squash body contains an` are verbatim substrings of `adversarial-review.sh:389` and `:392`. If a future edit to the script reworded either line, the awk would silently capture the wrong region (or everything). The assertion is coupled to those two literal strings by design; a script reword must update the test in the same change.
- **Three-dot vs two-dot is the load-bearing distinction** — both doc edits must say `origin/main...$BRANCH` (three dots, merge-base delta) and contrast it with two-dot `origin/main..$BRANCH`. Getting the dot-count wrong in the prose would document the bug as the fix.
- **Don't imply the rebase covers everything** — the entire reason for low (1) is that `workflow.md:488` over-credits the Phase 1.0 rebase. The new clause must make clear the dimension-(d) precompute fires BEFORE the rebase and needed its own fix; phrasing that reads as "and the rebase also handles this" reintroduces the misconception.
- **Husky uses dash** — any shell snippet that ends up in a hook runs under `sh`; this change only touches a bats test (runs under bash) and prose, so no dash-ism risk, but keep the awk/`tr` snippet POSIX-portable anyway (it is).
- **Per-commit doc-coverage guard** — devshop's commit guard requires doc updates alongside tooling changes; here the tooling (script) is unchanged and the change IS the docs+test, so the guard is satisfied structurally. Commit the test (task 3) on its own or with the docs — no script touched means no doc-coverage objection.

## Acceptance

- [ ] `kit/docs/guide/workflow.md:488` skill-map row carries a clause crediting the Phase 0.4.5 dimension-(d) three-dot precompute (codified `b174a11`) as a complementary base-divergence remedy that fires BEFORE the Phase 1.0 rebase, with a cross-ref to `hooks.md § Dual-surface check-types`.
- [ ] `kit/docs/guide/hooks.md § Dual-surface check-types` has a NOTE 3 description recording the three-dot `origin/main...$BRANCH` basis, the two-dot phantom failure mode it avoids, the worked incident (docs/csp-img-src 2026-05-28, `template/.gitignore` phantom), and `b174a11`.
- [ ] The `workflow.md:488` cross-ref resolves to a real, complete target (no dangling pointer).
- [ ] `util-adversarial-review-narrowing.bats` test 18 contains a positive assertion that the rendered `$PROP_SURFACES` region is whitespace-only, implemented via the D2 awk-extraction mechanism (NOT `grep "If the list is EMPTY"`).
- [ ] The new assertion passes on the current (fixed) `adversarial-review.sh` and would fail if dimension (d)'s diff regressed to two-dot.
- [ ] `adversarial-review.sh` is byte-for-byte unchanged; no new bats file; test 16 unchanged.
- [ ] Full bats suite green (`pnpm turbo run test` or the touched file's bats run).
- [ ] `kit/TODOS.md § Harden the Phase 0.4.5 dimension-(d) three-dot fix` entry is deleted in the shipping commit (closes the tracker entry per the "Closing TODO / ROADMAP entries" convention).
