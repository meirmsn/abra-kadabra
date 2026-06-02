## Gate 11: convention

**Result: findings (1) fixed**

Devshop convention check against `git diff origin/main...HEAD` on `feat/bats-drift-guards`. One real close-on-ship finding (fixed + committed); all other checklist items pass.

### Checklist

- **Bats test idioms (new/edited `@test`s in `structural-invariants.bats`)** — PASS.
  - The wiring-test autodetect branch (edit) and the `grep-drift` guard (new `@test`) both follow the file's existing structure: `# ===` banner-comment section header + rationale block, `setup()`-provided `DEVSHOP`/`git rev-parse` root resolution, the `local foo=""; while IFS= read -r ...; echo -e; false` accumulate-and-fail idiom used throughout the file.
  - The new guard uses `root=$(git rev-parse --show-toplevel)` rather than `$DEVSHOP`. This is consistent — the file already runs a documented cluster of `git rev-parse --show-toplevel`-rooted tests (line 816 carries an `IMPORTANT:` comment explaining the choice; lines 836–921 use it). Worktree-correct rooting is the right call for a guard that resolves repo-relative paths.
  - The `# pins:` annotation convention is internally consistent: the guard's parser, the convention doc, and the three seeded annotations (`firewall-extras-overlay.bats` ×2, `util-build-phase58-audit-parser.bats` ×1) all agree on the `# pins: <path> :: <literal>` shape and the `::` (space-colon-colon-space) separator with first-`::`-wins literal split.

- **Guide-doc routing index** — N/A (no new guide doc; `conventions.md` already exists and is already indexed).

- **`# pins:` convention doc placement + style (`conventions.md`)** — PASS. Placed inside `§ Kit Testing`, immediately after the related "preserve the production execution context" pipefail convention — the correct neighborhood. Style matches surrounding entries: bold lead-in sentence, code-block example, rules bullets, and an honest **Scope** note delimiting assertion-drift (caught) from under-assertion (not caught; `/ak-tests-review` backstop). Stable-literal guidance and incremental-adoption note are well-judged.

- **Commit subjects describe the observable change** — PASS. All seven branch commits are conventional-commit form with observable-change framing (e.g. `test(structural-invariants): guard grep-based bats tests against assertion-drift`, `docs(security): close sudo-scoping-node tracker as solved`). None ≤72-char limit exceeded for the load-bearing subject line.

- **Close-on-ship convention (CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships")** — **FINDING (fixed)**. See below. The sudo-scoping closure portion was done correctly and completely (verified): PLAN `sudo-scoping-node` row deleted; `kit/TODOS.md` entry deleted; all three FRICTION-LOG entries (grep-drift, wiring, sudo) deleted; `sudo-hardening.md` rewritten title→`(SOLVED)` and body from conditional ("Problem"/"Desired state"/"Approach"/"When to do this") to imperative present ("Shipped model"/"What this prevents"/"Verification"); `security-model.md` + `kit/notes/README.md` cross-refs unwound from "analysis" → shipped-model phrasing; BUILD-LOG entry added. The documented sudo claim is backed by reality (`.devcontainer/Dockerfile` lines 101–112: two narrow NOPASSWD entries in `/etc/sudoers.d/node-firewall` + `rm -f /etc/sudoers.d/node`). No stale "still pending" framing left for sudo.

- **No new `kit/scripts/` file (so no missing paired bats test)** — PASS. Diffstat touches no `kit/scripts/**`; the work lives entirely in `kit/tests/*.bats`, docs, and trackers.

### Finding (fixed)

**Close-on-ship: two shipped-feature PLAN rows survived Phase 4.0 closure.** Both `grep-test-drift-guard` and `wiring-test-skill-autodetect` are this branch's own deliverables (commits `c96f480` and `ee0383b`), yet their `PLAN.md § Planned (v0)` rows were still present on HEAD. The Phase 4.0 closure commit (`82da6b6`) deleted only the `sudo-scoping-node` row. The spec itself flagged the intent (`spec.md` line ~100: _"handle their Planned-row removal at Phase 4.0 per the build-log/PLAN-closure convention"_) and the spec's own acceptance check (line ~150) asserts `grep -rn` is clean of stale pointers — but Phase 4.0 missed the two guard rows. Left unfixed, future sessions would cite both as "still pending," recreating the false belief the fix removed (the exact failure the convention guards against).

Fixed: deleted both rows from `PLAN.md § Planned (v0)`. The matching `kit/TODOS.md` + `kit/FRICTION-LOG.md` entries for both were already deleted earlier in the branch, so this completes the cross-tracker closure. Verified no remaining slug references outside this PR's own `specs/bats-drift-guards/` artifacts and the legitimate BUILD-LOG closure note. Committed as `525a03e` (PLAN.md only). `structural-invariants.bats` re-run after commit: 62/62 pass, 0 failures.

(Commit note: a dirty-tree bypass with a specific reason was required — the worktree's `.husky/prepare-commit-msg` had checked out non-executable, so `chmod +x` was applied as a local runtime fix to let hooks fire; that mode change was deliberately left unstaged, and the gate-output sink `specs/bats-drift-guards/gates/` is untracked. The Sonnet-routed dirtyTreeReason reviewer accepted the named, scoped rationale.)

## Dismissals

- **New guard uses `git rev-parse --show-toplevel` instead of the file's `$DEVSHOP="/devshop"` idiom** — dismissed (n/a). Not a deviation: the file already maintains a documented cluster of `git rev-parse`-rooted tests (line 816 `IMPORTANT:` comment + lines 836–921). Worktree-correct rooting is required for a guard that resolves repo-relative paths against the actual checkout, and `/devshop` would be wrong when run in a linked worktree.
- **`.husky/prepare-commit-msg` mode-only change (100644 → 100755) in the working tree** — dismissed (environment artifact, intentionally not committed). The worktree checked the hook out non-executable; restoring `+x` is a local runtime fix so husky hooks exec. Left unstaged; the only file committed by this gate is `PLAN.md`. Not a convention finding.
