## Gate 4: simplify

**Result: pass** — no genuine over-complexity to simplify.

Scope per the gate brief: only two real code surfaces in this devshop-self diff
(the rest is prose/docs/markdown + deliberately-explicit orchestration bash).

### Surface 1 — gitleaks gate bash block (`merge-devshop/SKILL.md § Phase 2`)

```bash
if [ -n "$WORKTREE_PATH" ]; then
  ( cd "$WORKTREE_PATH" && gitleaks protect --staged --redact )
else
  gitleaks protect --staged --redact
fi
```

As simple as it can be while staying correct. The cwd-pin is load-bearing
(spec Gotcha 2: running from `/devshop` while the squash lives in a worktree
scans `/devshop`'s index — on `main`, empty staged delta — and false-passes).
The only candidate simplification — collapsing both branches to
`( cd "${WORKTREE_PATH:-/devshop}" && gitleaks ... )` — was rejected: it
hardcodes a `/devshop` literal that the rest of Phase 2 deliberately derives via
`GIT_CMD` / `--git-common-dir`, and forces a `cd` on the non-worktree path where
the squash cwd is already correct. That trades clarity + the orchestration's
path-derivation discipline for a one-line save. Net: leave the explicit if/else.

### Surface 2 — two new bats `@test` blocks (`util-ak-merge-devshop.bats § Section G`)

- Presence test: single `awk '/^## Phase 2:/,/^## Phase 3:/' | grep -qE` —
  minimal, matches the file's existing grep-assertion style verbatim.
- Ordering test: extracts line numbers via `grep -n | head -1 | cut -d: -f1`
  for both anchor lines and compares. This is the standard "X before Y" idiom
  and is consistent with the rest of the suite. Not convoluted.

Full suite re-run after review: `kit/tests/util-ak-merge-devshop.bats` → 106/106
green (incl. the two new tests, 103 + 104). No edits applied — nothing to fix.

## Dismissals

- Collapse the gitleaks if/else to `cd "${WORKTREE_PATH:-/devshop}"` — rationale: hardcodes a `/devshop` literal the surrounding Phase 2 orchestration intentionally derives via `GIT_CMD`/`--git-common-dir`, and forces a `cd` on the path where cwd is already correct; a one-line save at the cost of clarity + path-derivation discipline. Keep explicit.
- Orchestration-skill prose bash + doc/markdown prose — rationale: out of /simplify scope per the gate brief (read by an agent, not executed as a golfed script); readable prose is not "complex code."
