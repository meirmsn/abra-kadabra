<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: skip-bats-docs-only -->
<!-- date: 2026-05-31 -->

# Spec: skip-bats-docs-only

**Sources:**

- `kit/TODOS.md § Skip bats on docs-only devshop commits` — primary scope (first-pass, ~15 min inline)
- `.husky/pre-commit` lines 38–90 — the `main`-branch full-suite block being guarded
- Prior art: `kit/tests/util-husky-hooks.bats`, `kit/tests/pre-commit-router.bats` — hook-test style reference

Docs-only commits to the devshop repo skip the ~30s kit bats suite, with a visible "skipped (docs-only diff)" line so it's never silent.

---

## Product update

This is a devshop tooling change; the audience is the operator. Single
source-of-truth for the BUILD-LOG entry and the merge-commit summary.

### Headline (user-facing)

Docs-only commits to the devshop repo now finish instantly — the ~30s kit test
suite is skipped when a commit touches only Markdown, with a clear
"skipped (docs-only diff)" line so it's never silent.

### Detail (team-facing)

`.husky/pre-commit` gains a guard between the gitleaks scan and the
`main`-branch full bats block: when every staged path ends in `.md`, it prints
`✓ Kit tests: skipped (docs-only diff)` and bypasses the suite. The check is
mechanical (no adversarial review) — a false-negative just runs bats
unnecessarily, and the next non-docs commit re-covers.

---

## Decisions (resolved at spec time)

5 decisions resolved in Phase 0 with the user.

### D0: Worktree or a `feat/` branch directly in `/devshop`?

**Decision:** Worktree (`.worktrees/skip-bats-docs-only`), with `core.worktree`
scrubbed immediately after `git submodule update`.

**Rationale:** Honors the explicit request; /devshop stays on `main`. The scrub
neutralizes the HIGH worktree-corruption footgun (`kit/TODOS.md`, hit
2026-05-31). Verified not-injected this run.

### D1: What counts as "docs-only"?

**Decision:** Every staged path ends in `.md`.

**Rationale:** Covers the enumerated set (`PLAN.md`, `kit/ROADMAP.md`,
`kit/TODOS.md`, `BUILD-LOG.md`, `kit/docs/**`, any `*.md`). Conservative — one
non-`.md` staged path forces the full suite.

### D2: Which bats run gets skipped?

**Decision:** Only the `main`/`master` full-suite block (`.husky/pre-commit`
lines 38–90).

**Rationale:** That is the ~30s offender the TODO measured. The on-branch path
(line 92 → `kit/hooks/pre-commit.sh` → affected-only `check-bats-devshop.sh`)
is already fast; left untouched.

### D3: First-pass inline, or the "eventual" `path-classifier --mode=devshop`?

**Decision:** First-pass inline bash only.

**Rationale:** The TODO scopes first pass as ~15 min inline; the classifier
refactor stays a separate TODO item (left in `kit/TODOS.md`).

### D4: Test coverage for the skip?

**Decision:** New bats spec: docs-only staged diff → skip message + bats not
invoked; mixed diff → bats runs.

**Rationale:** "No code without tests"; mirrors `util-husky-hooks.bats`.

---

## In scope

- Add an inline docs-only predicate to the **devshop repo's** `.husky/pre-commit`
  (the one in this worktree), computed once after the `gitleaks` line.
- Gate the existing `main`/`master` full bats suite block on the predicate: on
  a docs-only staged diff, print `✓ Kit tests: skipped (docs-only diff)` and do
  not run the suite.
- Bats coverage via a fixture-script + parity test (the established pattern for
  inline `.husky/pre-commit` logic — see `kit/tests/guard-husky-branch.bats`).
- Close the first-pass item of the `kit/TODOS.md` entry.

## Out of scope

- `template/.husky/pre-commit` — projects have no `kit/tests/`, so the
  full-suite block never fires there (and `template/**` is a locked path). The
  TODO is explicitly about _devshop_ docs-only commits.
- The on-branch affected-only path (line 92 → `kit/hooks/pre-commit.sh` →
  `check-bats-devshop.sh`) — already fast; untouched. (D2)
- The "Eventual (clean)" `path-classifier.sh --mode=devshop` refactor — stays a
  separate `kit/TODOS.md` item. (D3)

## Files to create / modify

- **Modify** `.husky/pre-commit` — insert the `_docs_only_diff` predicate after
  the `gitleaks protect` line; change the bats-block opener so a docs-only diff
  prints the skip line instead of running the suite.
- **Create** `kit/tests/guard-bats-docs-only.bats` — behavior tests of the
  predicate (via a fixture holding identical logic) + a parity test asserting
  the production block matches the fixture.
- **Modify** `kit/TODOS.md` — close the first-pass item (D3 keeps the eventual
  note).

## The predicate (canonical)

```bash
# Skip the full kit bats suite on docs-only commits (guaranteed no-op — the
# suite tests scripts/hooks/templates, never Markdown). Every staged path must
# end in .md (covers PLAN.md, kit/ROADMAP.md, kit/TODOS.md, BUILD-LOG.md,
# kit/docs/**, any *.md). An empty staged set is NOT docs-only. False-negative
# just runs bats unnecessarily; the next non-docs commit re-covers.
_docs_only_diff=0
_staged_files=$(git diff --cached --name-only)
if [ -n "$_staged_files" ] && ! printf '%s\n' "$_staged_files" | grep -qvE '\.md$'; then
  _docs_only_diff=1
fi
```

`! grep -qvE '\.md$'` is true iff NO staged line fails the `.md$` test — i.e.
every staged path ends in `.md`. The `-n "$_staged_files"` guard makes an empty
staged set fall through to running the suite.

## Tests

`kit/tests/guard-bats-docs-only.bats`, mirroring `guard-husky-branch.bats`:

- Fixture script = the predicate above + a trailing `echo "$_docs_only_diff"`.
- `all-.md staged diff → 1` (e.g. `PLAN.md` + `kit/docs/guide/x.md`).
- `mixed staged diff (.md + .sh) → 0`.
- `non-.md only (.sh) → 0`.
- `empty staged set → 0`.
- Parity: the `_docs_only_diff` block extracted from `.husky/pre-commit`
  (`sed -n '/^_docs_only_diff=0/,/^fi$/p'`) equals the fixture predicate.

## Task order

1. Add the `_docs_only_diff` predicate + skip-branch to `.husky/pre-commit`.
2. Add `kit/tests/guard-bats-docs-only.bats` (behavior + parity), run it green.
3. Close the first-pass item in `kit/TODOS.md`.

## Gotchas

- Husky re-execs the hook under bash (lines 1–5), so `printf '%s\n'` / `grep -E`
  are fine. Keep the predicate POSIX-ish anyway for clarity.
- Keep the production block byte-identical to the fixture or the parity test
  fails (that's its job — drift protection).
- Edit only this worktree's `.husky/pre-commit`; do NOT touch `template/`.

## Acceptance

- A staged diff of only `*.md` paths on `main` prints the skip line and runs no
  bats; any non-`.md` staged path runs the full suite as before.
- `kit/tests/guard-bats-docs-only.bats` passes; the parity test pins the
  production block to the fixture.
- First-pass `kit/TODOS.md` item closed; eventual path-classifier note retained.

<!-- devshop-self-mode: no METRICS.md; test surface is bats (kit/tests/). -->
