<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: bats-drift-guards -->
<!-- date: 2026-06-02 -->

# Spec: bats-drift-guards (devshop)

**Sources:**

- `PLAN.md § Planned (v0)` — rows `wiring-test-skill-autodetect`, `grep-test-drift-guard`, `sudo-scoping-node` (bundled)
- `kit/TODOS.md` — "Auto-detect skill-invoked kit scripts in the wiring test", "Guard against `grep`-based bats tests drifting", "Investigate scoping node user's sudo access"
- `kit/FRICTION-LOG.md` — "Devshop kit scripts ship a red `main` when a new skill-invoked script isn't added to the wiring allow-list" (score 8) + "A doc/SKILL.md or source edit can silently drift a `grep`-based bats test" (score 15 family / count 5)
- `kit/notes/security/sudo-hardening.md` — sudo-scoping problem analysis (now resolved)
- `kit/tests/structural-invariants.bats` — the file both guards live in
- Prior shipped spec `specs/worktree-shared-config-corruption/spec.md` — style/structure reference

Three independently-tracked items that all edit `kit/tests/structural-invariants.bats`, bundled into one PR to save merge ceremony. Two add structural-invariant guards that kill recurring red-`main` classes; the third is tracker hygiene for an already-solved item.

---

## Product update

Pure-infrastructure PR — no project-facing user-visible change.

### Headline + Detail (combined)

Infrastructure update — no user-visible change. Two new `structural-invariants.bats` guards stop a class of red-`main`: (1) a new skill-invoked kit script (called from a SKILL.md prompt, not a hook) no longer needs a hand-edit to the wiring allow-list to keep `main` green; (2) a `grep`-based bats assertion that drifts from the doc/source text it pins now fails loudly at the editing commit instead of silently reaching `main`. Plus tracker hygiene: the already-solved `sudo-scoping-node` item is closed and recorded.

---

## Decisions (resolved at spec time)

### D1: wiring-autodetect detection mechanism

**Decision:** In the `@test "wiring: every non-exempt kit script is wired into a hook or pre-commit"` test (`structural-invariants.bats:217-277`), add a skill-invocation check: a script whose basename appears in any `.claude/skills/**/SKILL.md` is treated as "wired (skill-invoked)". This is **additive** — checked alongside the existing hook-wired / `exempts` / `infra_scripts` paths, before flagging a script as unwired.

**Rationale:** Exactly the TODO's prescribed fix. Verified the candidate scripts grep correctly: `reconcile-task-commits.sh` (implement + build SKILL.md), `virtiofs-rebase.sh` (merge-devshop SKILL.md).

### D2: prune `infra_scripts` for now-autodetected scripts

**Decision:** Remove `reconcile-task-commits.sh` and `virtiofs-rebase.sh` from the in-test `infra_scripts` allow-list (both are now caught by the SKILL.md grep). **Keep** `vendor-bats-libs.sh` — verified it is NOT referenced in any SKILL.md (operator-invoked manual re-vendor path), so it remains a genuine internal helper. Keep all other genuinely-internal helpers (called by other scripts, not skills/hooks).

**Rationale:** Pruning the two scripts proves the autodetect path actually works — if the grep failed, they would flip to red. Keeping `vendor-bats-libs.sh` confirms the autodetect is not over-broad.

### D3: grep-drift-guard mechanism

**Decision:** Introduce a declarative annotation convention: a grep-asserting bats test that pins a literal in a doc/source file carries a comment of the form `# pins: <repo-relative-path> :: <exact literal>`. Append a new `@test` to `structural-invariants.bats` that scans all `kit/tests/*.bats` for these annotations and, for each, asserts (`grep -qF`) that `<exact literal>` still appears in `<path>` (resolved against the worktree root via `git rev-parse --show-toplevel` — the tree being shipped). Red if any annotated literal has drifted out of its target file; the failure message lists each drifted pin.

**Rationale:** Boring/deterministic. `structural-invariants.bats` runs on **every** commit (not just the affected subset), so the guard fires at the _editing_ commit that removes the literal — the exact mechanism that lets assertion-drift reach `main` today (the editing commit's affected-subset hook never runs the asserting test in another file). `grep -qF` (fixed-string) handles literals with spaces/regex chars. The literal lives in both the grep line and the annotation, but co-located in the same test stanza so an editor sees both.

### D4: grep-drift-guard seed scope

**Decision:** Seed-annotate 2-3 known offenders named in the friction log (e.g. `firewall-extras-overlay.bats` #14, `util-build-phase58-audit-parser.bats`, `util-adversarial-review-narrowing.bats`) so the guard ships with live coverage, and document the `# pins:` convention in `kit/docs/guide/conventions.md` (test-authoring section). Full retrofit of every grep-based test is explicitly out of scope — future tests adopt the convention incrementally.

**Rationale:** Live coverage proves the guard catches a real case on day one; documenting the convention lets it spread without a big-bang retrofit. The implement agent picks the exact seed set (each must be a literal that genuinely appears in a stable target file).

### D5: grep-drift-guard scope honesty (root-cause vs bandaid)

**Decision:** The guard catches **assertion-drift** (asserted literal removed from the pinned file → red), which is 4 of the 5 logged instances and the entire red-`main` direction. It does **NOT** catch **under-assertion** (a test that pins too little, letting a later edit silently drop coverage and ship green) — that is a judgment problem no mechanical check solves. The spec, the convention doc, and the BUILD-LOG entry all state this limit explicitly.

**Rationale:** Honest labeling per CLAUDE.md root-cause-over-bandaid. For the assertion-drift direction the guard is genuinely root-cause (makes the drift structurally detectable at edit time); for under-assertion it is no help, and saying so prevents a future session believing the whole drift class is closed.

### D6: sudo-scoping-node BUILD-LOG framing

**Decision:** `sudo-scoping-node` is verified solved (general sudo requires a password node lacks; only `init-firewall.sh` + `init-devshop.sh` are NOPASSWD; blanket `/etc/sudoers.d/node` removed in `Dockerfile:111-112`). Record it as a dated **"Historical backfill"** BUILD-LOG entry (~2026-04-10, in date order near the bottom) citing `5d3bf7f` (seed blanket-removal) + the scoped NOPASSWD entries + the `sudo -n true` → "a password is required" verification. This PR's own ship entry mentions the tracker closure. Delete the PLAN row + `kit/TODOS.md` entry; rewrite `kit/notes/security/sudo-hardening.md` from open-problem prose to solved/imperative; unwind cross-refs in `kit/notes/README.md` + `kit/notes/security/security-model.md`.

**Rationale:** The scoping shipped in the seed; this PR only closes a stale tracker, so "where it should be" is a date-ordered historical backfill matching the existing convention — not a today-dated ship entry claiming this PR did the scoping.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. -->

## In scope

Three independently-tracked items, bundled because all three touch `kit/tests/structural-invariants.bats`.

1. **Wiring-test skill-autodetect** (D1 + D2). Edit the `@test "wiring: every non-exempt kit script is wired into a hook or pre-commit"` (`structural-invariants.bats:217-277`) so a kit script whose basename appears as a whole token in any `.claude/skills/**/SKILL.md` is treated as "wired (skill-invoked)" — checked additively alongside the existing hook-wired / `exempts` / `infra_scripts` paths. Then **prune** `reconcile-task-commits.sh` and `virtiofs-rebase.sh` from the in-test `infra_scripts` allow-list (both now covered by the SKILL.md grep), and update the explanatory comment block (lines ~233-242) to reflect the new detection path. **Keep** `vendor-bats-libs.sh` in `infra_scripts` (verified: not referenced in any SKILL.md — operator-invoked re-vendor path). The prune is itself the validation: if the autodetect grep doesn't actually catch the two pruned scripts, they flip to red.

2. **Grep-drift guard** (D3 + D4 + D5). Append a new `@test` to `structural-invariants.bats` that scans every `kit/tests/*.bats` for `# pins: <repo-relative-path> :: <exact literal>` annotation comments and, for each, asserts (`grep -qF`) that `<exact literal>` still appears in `<path>` (resolved under the worktree root). Red if any annotated literal has drifted out of its target file; the failure message lists each drifted pin. Document the `# pins:` convention in `kit/docs/guide/conventions.md § Kit Testing (devshop infrastructure)`. Seed-annotate 2-3 known offenders (named in the friction log) with `# pins:` comments so the guard ships with live coverage on day one.

3. **`sudo-scoping-node` tracker closure** (D6). The sudo-scoping itself already shipped (blanket `/etc/sudoers.d/node` removed in the Dockerfile seed; only `init-firewall.sh` + `init-devshop.sh` are NOPASSWD; general `sudo` requires a password node lacks). This PR only closes the stale tracker: delete the `PLAN.md` row + `kit/TODOS.md` entry, rewrite `kit/notes/security/sudo-hardening.md` from open-problem prose to solved/imperative, unwind the two cross-refs (`kit/notes/README.md`, `kit/notes/security/security-model.md`), and record a dated **Historical backfill** BUILD-LOG entry for the original scoping work.

**Out of scope (explicit):**

- **Full grep-test retrofit.** Only 2-3 seed tests get `# pins:` annotations now; the convention spreads incrementally as future tests adopt it. No mass-annotation of every existing grep-based bats test.
- **Under-assertion detection** (D5). The guard catches **assertion-drift** (an asserted literal removed from the pinned file → red), which is 4 of the 5 logged friction instances and the entire red-`main` direction. It does NOT catch **under-assertion** (a test that pins too little, letting a later edit silently drop coverage and ship green) — that is a judgment problem no mechanical check solves. The spec, the convention doc, and the BUILD-LOG entry all state this limit honestly.
- **No new `kit/scripts/` file** is created, so `check-tests-coverage-devshop.sh` won't demand a new paired test file. Both guards live inside the existing `structural-invariants.bats`.
- **The worktree-blind `$DEVSHOP`-hardcoded read** friction (separate open friction-log entry, score 8) is NOT addressed here — it's a different root cause and out of scope for this PR.

## Files to create / modify

| File                                   | Change                                                                                                                                                                                                                                                                                                                                                                                                                              |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/tests/structural-invariants.bats` | Both guards: (a) edit the wiring `@test` — add the SKILL.md-basename autodetect branch + comment update + prune `reconcile-task-commits.sh` / `virtiofs-rebase.sh` from `infra_scripts`; (b) append the new `# pins:`-scanning `@test`.                                                                                                                                                                                             |
| `kit/docs/guide/conventions.md`        | Document the `# pins: <path> :: <literal>` convention in `§ Kit Testing (devshop infrastructure)` (near "Adding tests for a new script" / the production-execution-context note). State the assertion-drift-only scope honestly.                                                                                                                                                                                                    |
| `kit/tests/<seed-1>.bats`              | Add `# pins:` annotation(s) over an existing grep assertion (annotation only — no behavior change). Candidate: `util-build-phase58-audit-parser.bats` (clean `grep -q '/ak-check-docs-and-tests'` literal pin against `$SKILL_FILE`).                                                                                                                                                                                               |
| `kit/tests/<seed-2>.bats`              | Same — second seed offender from the friction log. Implement agent picks the exact literal (must genuinely appear, plain-text, in a stable target file).                                                                                                                                                                                                                                                                            |
| `kit/tests/<seed-3>.bats`              | Optional third seed if a clean literal is available. 2-3 total.                                                                                                                                                                                                                                                                                                                                                                     |
| `PLAN.md`                              | Delete the `sudo-scoping-node` row (`§ Planned (v0)`, line ~78). The two guard rows (`grep-test-drift-guard`, `wiring-test-skill-autodetect`) are this PR's own deliverables — handle their Planned-row removal at Phase 4.0 per the build-log/PLAN-closure convention.                                                                                                                                                             |
| `kit/TODOS.md`                         | Delete 3 entries: "Auto-detect skill-invoked kit scripts in the wiring test…", "Guard against `grep`-based bats tests drifting…", "Investigate scoping node user's sudo access".                                                                                                                                                                                                                                                    |
| `kit/notes/security/sudo-hardening.md` | Rewrite from open-problem analysis to solved/imperative present tense (records the shipped scoped-NOPASSWD model; what's NOPASSWD, what requires a password node lacks).                                                                                                                                                                                                                                                            |
| `kit/notes/README.md`                  | Unwind the `sudo-hardening.md` cross-ref (line ~50) — reword from "analysis of … risks" to the solved framing.                                                                                                                                                                                                                                                                                                                      |
| `kit/notes/security/security-model.md` | Unwind the "Sudo scoping" bullet (line ~140) — rewrite from "Current model relies on password requirement…" to the shipped scoped-NOPASSWD state.                                                                                                                                                                                                                                                                                   |
| `kit/FRICTION-LOG.md`                  | Delete the 2 promoted entries ("A doc/SKILL.md or source edit can silently drift a `grep`-based bats test" + "Devshop kit scripts ship a red `main` when a new skill-invoked script isn't added to the wiring allow-list"). Fold their recurrence history (counts + per-session detail) into the corresponding BUILD-LOG ship entry. Per close-on-ship convention.                                                                  |
| `BUILD-LOG.md`                         | (1) Historical-backfill entry (~2026-04-10, in date order near the bottom) for the already-shipped sudo scoping — cite the seed blanket-removal commit + scoped NOPASSWD entries + the `sudo -n true` → "a password is required" verification. (2) This-PR ship entry — handled at Phase 4.0 (not in spec/implement); must fold in the two deleted friction entries' recurrence histories and state the assertion-drift-only scope. |

## Tests

This is devshop-self-mode (no vitest/Playwright; the test surface is bats). Each guard is validated by `structural-invariants.bats` itself running green after the edits.

- **Wiring autodetect**: the existing wiring tests must stay green after pruning `reconcile-task-commits.sh` + `virtiofs-rebase.sh` from `infra_scripts`. **This IS the validation** — the two pruned scripts are now covered only by the new SKILL.md-basename autodetect branch, so if the autodetect grep is wrong (wrong path glob, substring-vs-token mismatch, non-recursive), they flip to red. A green run proves the autodetect path actually catches them. No separate fixture needed.
- **Grep-drift guard**: self-exercises via the seed annotations against real target files. The 2-3 seeded `# pins:` comments each assert a literal that genuinely appears in a stable doc/SKILL/source file at HEAD, so the guard passes green and proves it parses + resolves + greps correctly on day one. A deliberately-broken fixture annotation in a throwaway test would **over-engineer** it (D4/D5) — the seed annotations against real files are the live test, and a broken-on-purpose fixture would itself be a drift liability. So: no negative fixture.
- **No new `kit/scripts/` file** → `check-tests-coverage-devshop.sh` won't demand a new paired test file (both guards live in the existing `structural-invariants.bats`).
- Run `kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats` after each of Task 1 and Task 2; full `kit/tests/lib/bats-core/bin/bats kit/tests/` before marking done.

## Task order

Dependency-ordered. Tasks 1 and 2 are independent edits to the same file; do them sequentially to keep the bats run between them clean. Task 3 is pure tracker/doc hygiene.

1. **wiring-test-skill-autodetect** (D1 + D2) — surgical edit to the wiring `@test`: add the SKILL.md-basename autodetect branch, update the comment block, prune `reconcile-task-commits.sh` + `virtiofs-rebase.sh` from `infra_scripts` (keep `vendor-bats-libs.sh`). Then run `kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats`.
2. **grep-test-drift-guard** (D3 + D4 + D5) — append the new `# pins:`-scanning `@test`; document the `# pins:` convention in `conventions.md § Kit Testing`; seed-annotate 2-3 offender `.bats` files. Then run `kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats`.
3. **sudo-scoping-node tracker closure** (D6) — delete the PLAN row + the 3 `kit/TODOS.md` entries; rewrite `sudo-hardening.md` to solved; unwind the `kit/notes/README.md` + `security-model.md` cross-refs; delete the 2 promoted FRICTION-LOG entries (folding history into BUILD-LOG); add the Historical-backfill BUILD-LOG entry for the sudo scoping. (This-PR ship-entry + the two guard PLAN-row removals are Phase 4.0.)

Run the full `kit/tests/lib/bats-core/bin/bats kit/tests/` at the end.

## Gotchas

- **The `# pins:` literal must EXACTLY match (`grep -qF`) text that genuinely appears in a STABLE target file.** Pick seeds whose pinned literal is unlikely to be reworded (e.g. a skill/command name like `/ak-check-docs-and-tests`, a flag, a structural token) — not volatile prose. A literal that doesn't currently appear in its target ships the guard red.
- **The new grep-drift `@test` must itself parse robustly.** Use `::` (space-colon-colon-space) as the path/literal separator. Tolerate literals that themselves contain colons by splitting on the **FIRST** `::` only (everything after it is the literal, colons and all). Don't naively split on `:`.
- **The wiring-autodetect grep must be recursive over `.claude/skills/**/SKILL.md`** — skills are nested under `devshop/`, `gstack/`, etc. (e.g. `.claude/skills/devshop/build/SKILL.md`), so a non-recursive `.claude/skills/\*/SKILL.md`glob misses them. Match the basename as a **whole token** (word-boundary or exact-line match), not a bare substring, to avoid false-positives (e.g.`port.sh`should not match`report.sh`).
- **Don't annotate a seed whose pinned literal also appears in the SAME bats file** — the guard greps the TARGET doc/source/SKILL file (resolved from the `# pins:` path), not the test file itself. If the literal happens to live in the `.bats` file too, the annotation is still resolved against the target path, but choosing such a literal is confusing; pick a literal that lives in the target file, distinct from the test's own grep mechanics.
- **FRICTION-LOG entry deletion must fold recurrence history into the BUILD-LOG entry** per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — the friction log keeps only live observations (no `## Resolved` archive). The two deleted entries' counts (grep-drift count 5, wiring count 2) + notable per-session detail land in the BUILD-LOG ship entry (Phase 4.0).
- **`grep -qF` (fixed-string)** is mandatory for the pin assertion — literals contain spaces/slashes/regex metacharacters; a regex grep would mis-match.
- **Worktree-root resolution**: the new grep-drift `@test` should resolve target paths against `git rev-parse --show-toplevel` (the worktree under test) — matching the existing scaffold/convention tests in this file (lines ~805+) — NOT the hardcoded `$DEVSHOP=/devshop` literal, so the test validates the source being shipped in this worktree.
- **Backfill date ordering**: the sudo Historical-backfill BUILD-LOG entry goes in date order with oldest at the bottom (`### <title> (~2026-04-10)` placed among the other `**Note:** Historical backfill.` entries near the file's tail), each carrying the `**Note:** Historical backfill.` tail line per the existing convention.

## Dependencies

None external. All three deliverables are self-contained devshop edits (bats test, a markdown convention doc, and tracker/notes hygiene). No new tooling, no migrations, no app code, no third-party APIs.

## Acceptance

- `kit/tests/lib/bats-core/bin/bats kit/tests/` is fully green (all `structural-invariants.bats` tests pass, including the unchanged wiring tests after the `infra_scripts` prune and the new grep-drift guard).
- The wiring `@test` contains the SKILL.md-basename autodetect branch; `reconcile-task-commits.sh` + `virtiofs-rebase.sh` are removed from `infra_scripts`; `vendor-bats-libs.sh` is retained.
- The new grep-drift `@test` is present and exercised by 2-3 live seed `# pins:` annotations against real target files.
- The `# pins:` convention is documented in `conventions.md § Kit Testing (devshop infrastructure)`, including the explicit assertion-drift-only (not under-assertion) scope.
- `PLAN.md` `sudo-scoping-node` row deleted; the 3 `kit/TODOS.md` entries deleted; `sudo-hardening.md` rewritten to solved; both cross-refs (`kit/notes/README.md`, `security-model.md`) unwound; the 2 promoted FRICTION-LOG entries deleted.
- A Historical-backfill BUILD-LOG entry for the sudo scoping is present and correctly date-ordered (oldest at bottom), with the `**Note:** Historical backfill.` tail.
- `grep -rn` is clean for orphan cross-refs to the dropped entries: no lingering pointer to the deleted PLAN row, the deleted TODOS entries, or the deleted FRICTION-LOG entries (e.g. `grep -rn "sudo-scoping-node\|wiring-test-skill-autodetect\|grep-test-drift-guard" kit/ PLAN.md` returns only this PR's own intended mentions, not stale "still pending" references).
