## Gate 1: docs-check

**Result:** pass — every devshop tooling/behavior change in `git diff origin/main...HEAD` has a corresponding doc update in the same diff. No gaps, no mechanical fixes required.

### Scope checked

Diff under review (devshop-self-mode; reference docs = `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`, `CLAUDE.md`):

- `kit/tests/structural-invariants.bats` — wiring-test skill-autodetect branch + `infra_scripts` prune; new `# pins:` grep-drift `@test`
- `kit/docs/guide/conventions.md` — `# pins:` convention
- `kit/tests/firewall-extras-overlay.bats`, `kit/tests/util-build-phase58-audit-parser.bats` — seed `# pins:` annotations
- sudo closure: `PLAN.md`, `kit/TODOS.md`, `kit/FRICTION-LOG.md`, `kit/notes/security/sudo-hardening.md`, `kit/notes/README.md`, `kit/notes/security/security-model.md`, `BUILD-LOG.md`

### Verifications

**(a) `# pins:` grep-drift convention IS documented — PASS.**
`kit/docs/guide/conventions.md § Kit Testing (devshop infrastructure)` adds a "Pin a grep assertion to its target with a `# pins:` annotation" block (conventions.md:800-815 in the new file). It documents: the annotation form, the `::` first-split rule, stable-literal guidance, `grep -qF` resolution against worktree root, the every-commit firing mechanism, and — per D5 — the **honest assertion-drift-only scope** ("Does NOT catch under-assertion … `/ak-tests-review` is the backstop") plus incremental-adoption note. Matches the new `@test`'s in-file header comment. Complete.

**(b) Wiring-test skill-autodetect behavior change — no stale doc, none needed — PASS.**
Searched all living reference docs for prose describing the wiring test's prior contract (`infra_scripts`, "allow-list", "hook-wired or allow-listed", "every kit script must be wired"). Findings:

- The ONLY reference-doc mention of the wiring test is the generic Test-categories table row at `conventions.md:773` ("System-level wiring: hook paths resolve, symlinks intact, manifest consistent …"). It does not assert an allow-list-only contract, so it is not stale and needs no edit.
- No reference doc anywhere describes the `infra_scripts` allow-list or an "every kit script must be hook-wired or allow-listed" rule. That contract lived only inside the bats test's own comments — which the diff updated (the new SKILL.md-autodetect comment block + the pruned-script NOTE). The behavior change is therefore self-documenting in-test; there is no external prose to drift.
- `workflow.md:340` references `reconcile-task-commits.sh` only for its runtime resume-reconcile behavior, not its wiring-test classification — unaffected by the prune.
- `kit/docs/CHANGELOG.md:21` ("exempt skill-invoked reconcile-task-commits.sh from wiring") is a historical release-log entry, not living-reference prose — exempt, and not contradicted (the script is still treated as wired-via-skill, just by autodetect rather than a hand-edit).

**(c) Sudo closure — no other doc still describes sudo as an open problem — PASS.**

- `kit/notes/security/sudo-hardening.md` rewritten from open-problem ("## Problem / ## Desired state / ## When to do this") to "SOLVED" + shipped scoped-NOPASSWD model + verification.
- Both cross-refs unwound in the same diff: `kit/notes/README.md:50` (now "the shipped scoped-NOPASSWD model") and `kit/notes/security/security-model.md:137-141` (now the shipped two-NOPASSWD-script state).
- Swept every other doc mentioning `sudo` (`security.md`, `ops.md`, `architecture.md`, `security-model.md:12`, `macos-host-setup.md`, bootstrap notes). All describe the scoped-NOPASSWD model as the current/shipped state (e.g. `architecture.md:95` canonical-shape, `ops.md:474` Dockerfile-default, `security-model.md:12` "Removes passwordless sudo"). None frames sudo scoping as desired/future/risk-pending. No orphan.

**Tracker-closure orphan sweep (informational, supports (c)):** `sudo-scoping-node` row gone from `PLAN.md`; the 3 `kit/TODOS.md` entries deleted; the 2 promoted `kit/FRICTION-LOG.md` entries deleted. `grep -rn "sudo-scoping-node"` across `kit/` + `PLAN.md` is clean. The two guard rows (`grep-test-drift-guard`, `wiring-test-skill-autodetect`) still present at `PLAN.md:78-79` — this is **expected**, not a gap: per spec § Files table, their Planned-row removal is deferred to Phase 4.0 (this PR's own deliverables), and we are at Phase 3.

### Dismissals

- `kit/docs/CHANGELOG.md:21` ("exempt skill-invoked reconcile-task-commits.sh from wiring") — rationale: historical release-log entry, not a living reference doc; the doc-coverage rule targets reference docs (guide/OVERVIEW/CLAUDE.md), and the entry is not contradicted by the autodetect change.
- `PLAN.md:78-79` guard rows still present — rationale: spec § Files table explicitly defers these two rows to Phase 4.0; not in scope for the Phase 3 docs gate, so not a coverage gap.
- `kit/notes/bootstrap/v1.2-*.md`, `kit/notes/projects/home-os.md` sudo mentions — rationale: historical bootstrap/project build notes describing the (already-shipped) "removes passwordless sudo" state; consistent with the closure, not open-problem framing.
