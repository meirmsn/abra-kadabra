<!-- audited-at: 525a03ea762d5d8bcdc5529627b88da63901f244 -->

# Pre-ship review — bats-drift-guards (devshop mode)

## Router Summary

- Gates dispatched: 6 (docs-check, fast-job-local, /simplify, docs-and-tests-review, /review, convention)
- Carve-outs (devshop-self-mode, no UI/supabase/metrics/perf): 13
- Result: **pass** — 0 blocked (real), 0 findings_pending after focused fixes
- Findings fixed in-gauntlet: Gate 11 (1 close-on-ship: guard PLAN rows), Gate 6 (2: empty-literal false-pass + whole-token boundary), Gate 5 (coherence: spec/doc worktree-root wording)
- Dismissals: see per-gate `## Dismissals` blocks below (Gate 6 recorded 6; all others None)

---

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

---

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

---

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

---

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

---

## Gate 2d: fast-job-local

- Result: pass (bats kit/tests/ → 1646 ok / 0 not ok; devshop-self-mode test suite)

bats is the devshop's equivalent of the project turbo pipeline. Full suite run
green at HEAD (verified at Phase 2 finish + Phase 2.5 verification).

## Dismissals

None

---

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

---

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

---

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

---

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

---

## Gate 4: /simplify

Code-quality pass (reuse / simplification / efficiency / altitude) over
`git diff origin/main...HEAD`, scoped to the two substantive bats blocks in
`kit/tests/structural-invariants.bats`:

1. The skill-autodetect branch in the `wiring: every devshop script is wired` `@test`.
2. The new `@test "grep-drift: every '# pins:' annotation still resolves in its target file"`.

(The 3 seed `# pins:` annotations and the docs/tracker edits carry no logic and
were not in quality scope.)

**Result: clean pass — no changes warranted.**

The two blocks are tractable and idiomatic for this file. They reuse the file's
established conventions: `local` declarations, the defensive
`[ -z "$x" ] && continue` loop guard (identical to the wiring test's
`[ -z "$script" ] && continue`), per-iteration `grep` filtering, and
fixed-string `grep -qF` / `grep -qwF` matching. No dead state, no copy-paste
variation, no redundant I/O, no leftover locals from the `infra_scripts`
pruning (`skills_dir` is declared and consumed; `root` feeds only `tests_dir`
and the `"$root/$path"` resolve).

Altitude is a net improvement, not a regression: the autodetect branch _removes_
two hardcoded entries (`reconcile-task-commits.sh`, `virtiofs-rebase.sh`) from
`infra_scripts` and replaces them with a general SKILL.md-basename mechanism —
de-special-casing, the right depth. The annotation-parsing in the grep-drift
test (`${line#*# pins: }` after a marker-anchored grep, single `%% :: ` /
`#* :: ` split) is already the simple form; splitting on colons would be more
complex, not less.

### Dismissals

- **`grep-drift` test uses `git rev-parse --show-toplevel` while every other
  test in the file uses `$DEVSHOP` (`/devshop`).** Surfaced under the
  reuse/consistency angle as a candidate to switch to `$DEVSHOP` for uniformity.
  rationale: the divergence is deliberate and load-bearing — switching would
  change behavior, so it is out of /simplify scope (quality only, no behavior
  change). The guard must resolve against the _current worktree_ root so it
  catches `# pins:` annotations that exist only in the worktree at the editing
  commit (the whole point of firing at the commit that introduces the drift);
  `$DEVSHOP` would scan the canonical `/devshop` tree and miss worktree-local
  annotations. It also matches the pre-commit bats runner's own root resolution
  (`check-bats-devshop.sh` derives `GIT_ROOT=$(git rev-parse --show-toplevel)`),
  so the two are consistent with each other, just not with the canonical-tree
  tests that assert against fixed `/devshop` paths.
- **Two-condition malformed-annotation guard
  (`[ "$path" = "$annotation" ] || [ "$literal" = "$annotation" ]`).** When no
  `::` separator is present, both halves are true, so the `||` is belt-and-
  suspenders. rationale: harmless, cheap, and arguably clearer as a paired
  check; collapsing it is churn with no readability or efficiency payoff.
- **Verbose `NOTE:` comment block explaining the pruning-as-validation rationale
  in the wiring test.** rationale: documents a genuinely non-obvious design
  choice (why the two scripts were removed from `infra_scripts` rather than left
  in); trimming it is prose churn the gate brief explicitly warns against.

Tests confirmed green before the pass (no edits made):
`kit/tests/lib/bats-core/bin/bats kit/tests/structural-invariants.bats` → 62/62 ok
(test 62 = the new grep-drift guard).

---

## Gate 5: docs-and-tests-review

Adversarial docs + tests audit over `origin/main..HEAD` (branch `feat/bats-drift-guards`). Range adds two `structural-invariants.bats` guards (skill-autodetect wiring branch + grep-drift `# pins:` guard), a `# pins:` convention block in `conventions.md § Kit Testing`, 3 seed annotations, and the `sudo-scoping-node` tracker closure.

Full bats suite verified green in-worktree (structural-invariants 62/62; both seed files green). Each new behavior was mutation-tested, not just read.

### Tests — are the new behaviors actually PINNED?

**(a) Wiring skill-autodetect branch — PROVEN by the live prune.** The diff prunes `reconcile-task-commits.sh` + `virtiofs-rebase.sh` from the hand-maintained `infra_scripts` list, relying on the new `grep -rqwF "$script" "$skills_dir" --include=SKILL.md` branch to keep them green. I confirmed the autodetect is the _actual_ source of green via mutation: renaming `virtiofs-rebase.sh` → `virtiofs-DISABLED.sh` in the canonical merge-devshop `SKILL.md` (the dir the test reads — see finding M1) flips the wiring test red (`Scripts not wired into any hook or pre-commit chain: virtiofs-rebase.sh`). The prune is therefore a genuine live assertion: if the autodetect grep stopped catching them, the test would go red on the next run. A separate positive assertion is NOT missing — the prune _is_ the positive assertion, and it is honest.

**(b) grep-drift `@test` genuinely asserts (not a no-op).** Mutation-tested: rewording the pinned literal in `kit/manifest.txt` (`[scaffold-once]` → `[scaffold-twice]`) flips the guard red with a precise failure message naming the source `.bats` file, the target path, and the drifted literal. The `# pins:` line-anchored grep (`^[[:space:]]*# pins: `) correctly excludes the guard's own prose/placeholder forms (`<repo-relative-path>`-style) so it does not self-trip. The `false` at the end ensures a real failure exit. Confirmed not a tautology.

**(c) The 3 seed pins are real + currently stable.** All three pinned literals resolve in their targets right now:

- `template/.devcontainer/firewall-extra-domains :: One bare hostname per line` — present (1×), stable header prose.
- `kit/manifest.txt :: .devcontainer/firewall-extra-domains [scaffold-once]` — present (1×), structural manifest token (good stable choice).
- `.claude/skills/devshop/build/SKILL.md :: /ak-check-docs-and-tests` — present (10×), a skill name (stable per the doc's own guidance).

**(d) Under-assertion gap honestly out of scope (not silently dropped).** Both `conventions.md` ("Scope (honest): … does NOT catch under-assertion … a judgment problem no mechanical check solves") and the guard's header comment explicitly disclaim under-assertion, naming `/ak-tests-review` as the backstop. spec.md § 89 and the friction-log history corroborate. This is honestly scoped, not glossed.

### Docs — invalidations + accuracy

- **Sudo closure is complete and accurate.** `sudo-hardening.md` rewritten from open-problem prose to a "SOLVED" shipped model; `security-model.md` rewritten from conditional ("relies on password requirement") to imperative present (scoped two-script NOPASSWD); `kit/notes/README.md` pointer updated. No lingering doc describes node sudo as open/full/blanket (only the _new_ removal descriptions remain). The doc's claims match `.devcontainer/Dockerfile` exactly (two NOPASSWD entries in `node-firewall`, `rm -f /etc/sudoers.d/node`). The stated verification (`sudo -n true` → "a password is required") holds empirically in this container. Tracker closure follows the convention: PLAN row + `kit/TODOS.md` entry deleted, friction-log recurrence history folded into a `BUILD-LOG.md` backfill entry (which honestly notes the scoping itself shipped earlier; only the tracker closure is in this PR).
- **`# pins:` convention block is accurate, and its assertion-drift-only scope claim matches the guard behavior.** The doc's separator rule (`::`, first-occurrence split), "pick a stable literal", "grep-qF fixed-string", and "fires at the editing commit because structural-invariants runs on every commit" all match the implemented `@test`. The assertion-drift-only / not-under-assertion scope claim is faithful to the code.
- No existing doc, CLAUDE.md section, or Gotchas entry was invalidated-without-update by the diff. The new `# pins:` block sits under the existing `### Kit Testing` heading already covered by the TOC entry at line 53 — no new TOC entry required.

### Findings

**MEDIUM — M1: grep-drift guard and 2/3 of its seed tests resolve the SAME path against DIFFERENT roots; the convention doc's "annotate against the file the grep actually reads" is inaccurate for those seeds.** The grep-drift guard resolves `# pins:` paths against the worktree root (`git rev-parse --show-toplevel`) — correct, matches spec § 135 and the existing line-816 worktree-aware convention. But two of the three seed tests it scans assert against `$DEVSHOP=/devshop` (canonical): `firewall-extras-overlay.bats` greps `$DEVSHOP/template/...` and `util-build-phase58-audit-parser.bats` greps the hardcoded `/devshop/.claude/skills/devshop/build/SKILL.md`. In a linked worktree these are genuinely separate files (verified: not symlinks). Consequence: a session that edits the SKILL.md/overlay _in the worktree_ makes the grep-drift guard go red (it reads the worktree copy) while the asserting test it is meant to protect stays green (it reads canonical `/devshop`), and vice-versa — the two halves of the same drift-protection mechanism look at different files. The `conventions.md` rule "The path is resolved from the worktree root, so annotate against the file the grep actually reads" is therefore literally false for the 2 `$DEVSHOP`-based seeds. The underlying `$DEVSHOP`-worktree-blind read is a known, separately-tracked friction (friction-log entry, score 8) that spec § 89 _explicitly_ declares out of scope — so the seeds' defect itself is honestly scoped-out and not a regression. The finding is the doc-accuracy gap it introduces: the new convention is documented as worktree-root-resolved while 2/3 of the shipped examples it points at are not, which will mislead the next author annotating a `$DEVSHOP`-based grep test. Recommend either (a) one sentence in the `# pins:` convention noting that a `$DEVSHOP`-hardcoded grep test's annotation pins the worktree copy while the assertion reads canonical — until the worktree-blind friction lands — or (b) tightening the wording so it does not over-promise. Code change not required for correctness today (worktree == canonical content at this HEAD); this is a docs/coherence finding.

**LOW — L1: spec.md is internally inconsistent on the guard's resolution base.** spec § 46 says target paths are "resolved under `$DEVSHOP`", while spec § 80 and § 135 say "resolved against the worktree root" / `git rev-parse --show-toplevel`. The shipped code uses `git rev-parse` (matching § 80/135), so § 46 is a stale spec artifact. Spec is historical-after-execution, so impact is low, but the contradiction could mislead a reader reconstructing intent. Recommend reconciling § 46 to the as-shipped worktree-root resolution.

### Dismissals

- **"Skill-autodetect needs a dedicated positive assertion in addition to the prune"** — dismissed. The infra_scripts prune is itself the positive assertion (mutation-confirmed: removing the SKILL.md mention flips the wiring test red). A redundant standalone test would assert the same invariant twice.
- **"grep-drift guard might self-trip on its own `# pins:` documentation/echo lines"** — dismissed. The `^[[:space:]]*# pins: ` line-anchor plus the `<placeholder>` skip (`case "$path" in *'<'*|*'>'*) continue`) correctly exclude the guard's own prose, the convention's example block, and the failure-message echo. Verified by the clean green run.
- **"sudo verification claim (`sudo -n true`) is unverifiable / aspirational"** — dismissed. Ran it; returns "sudo: a password is required" as documented.
- **"The 2 `$DEVSHOP`-based seeds make the guard wrong"** — partially dismissed → folded into M1 as a docs-accuracy finding only. The guard itself is correct (worktree-aware); the seeds carry a separately-tracked, explicitly-out-of-scope worktree-blind defect. Not a code-correctness finding at this HEAD.

findings: high=0 medium=1 low=1

---

## Gate 6: /review

**Mode:** devshop-self-mode, report-only (HALT-ON-FIND). Fixes routed by the orchestrator, not applied here. gstack onboarding/telemetry/Greptile/Codex ceremony skipped (non-interactive devshop gate).

**Base:** `origin/main` → HEAD (`feat/bats-drift-guards`, 8 commits). Diff: 14 files, +417/-88. Substantive code: two bats additions to `kit/tests/structural-invariants.bats` (skill-autodetect wiring branch + grep-drift guard) plus three `# pins:` annotations and docs/tracker closure.

**Scope check:** CLEAN. Intent (from spec + commits): close 3 trackers via 2 bats guards (grep-drift, wiring-autodetect) + sudo-scoping-node tracker closure. Delivered: exactly that, no scope creep. Plan items (`specs/bats-drift-guards/tasks.md`) all map to diff hunks.

**Verification performed:**

- All 3 affected suites run green: `structural-invariants.bats` (62 tests inc. new grep-drift #62), `firewall-extras-overlay.bats`, `util-build-phase58-audit-parser.bats` — 0 `not ok`.
- All 3 `# pins:` literals resolve in their targets (grep -c: `template/.devcontainer/firewall-extra-domains`=1, `kit/manifest.txt`=1, `build/SKILL.md`=10).
- Both pruned `infra_scripts` entries (`reconcile-task-commits.sh`, `virtiofs-rebase.sh`) confirmed present in SKILL.md files → autodetect catches them (the prune-as-validation holds). `vendor-bats-libs.sh` correctly retained (not in any SKILL.md).
- Sudo-scoping doc claims verified against canonical signal: `.devcontainer/Dockerfile:103-112` has the two scoped NOPASSWD entries + `rm -f /etc/sudoers.d/node`; runtime `sudo -n true` → "a password is required". Docs accurately describe shipped reality (this is a docs-only closure of an already-shipped fix — no Dockerfile drift).
- Recursion over nested skill dirs (depth 4-5) confirmed working.

### Findings

**[INFORMATIONAL] (confidence: 9/10) kit/tests/structural-invariants.bats:301-302 (+ spec.md:131) — `grep -wF` word-boundary claim is overstated; `-` and `.` are boundaries, so a hyphen/dot-suffix basename can false-match.**
The code comment claims the basename is matched "as a whole token (grep -wF) so e.g. port.sh does not match report.sh." That specific example is true (no boundary between `re` and `port`), but `grep -wF` treats hyphen and dot as word boundaries — verified: searching `port-offset.sh` whole-token-MATCHES inside `apply-port-offset.sh` and `next-port-offset.sh`. So a script whose basename is a hyphen/dot-delimited suffix of another script's basename, mentioned in any SKILL.md, would wrongly mark the suffix script "wired (skill-invoked)". **Latent, not active:** scanned all kit/scripts basenames — zero current suffix-collision pairs exist, so no script is presently mis-detected. Impact is a future false-positive (an unwired script escaping the wiring guard) only if such a collision is later introduced. Fix options: (a) tighten the match to anchor on a non-token-char boundary or exact backtick/path form; (b) at minimum, correct the comment + spec line 131 to state the true boundary semantics so a future author doesn't trust the overstated claim. Cheap mitigation given no live collision: correct the wording.

**[INFORMATIONAL] (confidence: 8/10) kit/tests/structural-invariants.bats:1024-1031 — grep-drift guard silently passes a malformed annotation with an empty literal (`# pins: foo.md :: ` with nothing after the separator).**
The malformed-detection branch catches only the no-separator case (`path == annotation`). An annotation with a valid `::` separator but an empty literal yields `literal=""`, and `grep -qF "" "$target"` matches ANY non-empty file → silent false-pass (the guard reports "resolves" without asserting anything). Verified directly. The anchoring regex `^[[:space:]]*# pins: ` does require trailing content after `pins: `, but `foo.md :: ` satisfies it. **Low likelihood** (requires an author to write a separator then leave the literal blank) but it is a genuine silent-no-op hole the guard was meant to preclude. Fix: also flag malformed when `[ -z "$literal" ]` (or when `literal` is all-whitespace). Note a related sharp edge: a literal with trailing whitespace in the annotation is captured verbatim into the `grep -qF` pattern and would fail to match — currently harmless (no such annotations) but worth a trim.

**[INFORMATIONAL] (confidence: 7/10) kit/tests/structural-invariants.bats:279-281 — prose mention of a script basename in a SKILL.md counts as "wired", weakening the wiring guard (accepted design tradeoff, undocumented as a risk).**
The autodetect treats a basename appearing ANYWHERE in a SKILL.md — including prose, table cells, or a `kit/scripts/<x>.sh` path reference that is NOT an actual invocation — as "wired (skill-invoked)." This is deliberate (spec D1/D2) and the realistic worst case is a false-NEGATIVE (a genuinely-unwired script whose name happens to appear in prose escapes the wiring guard), which is low-probability/low-impact. Noting it because the orchestrator asked: the guard cannot distinguish "invoked from a skill step" from "merely named in skill prose." No change required; if desired, the spec's Scope/limitations could state this explicitly so it isn't mistaken for a bug later.

### Non-code (docs/tracker) review

- Tracker closure follows `CLAUDE.md § Closing TODO/ROADMAP entries when a fix ships` correctly: both FRICTION-LOG entries deleted (recurrence history folded into BUILD-LOG/spec), two `kit/TODOS.md` rows deleted, three `PLAN.md § Planned (v0)` rows reduced to the one remaining (`gstack-vendored-upgrade`), cross-refs in `kit/notes/README.md` + `security-model.md` unwound. No stale "still pending" residue found.
- No broken cross-references introduced. The BUILD-LOG historical-backfill entry cites `5d3bf7f` and the live Dockerfile lines; all assertions in the sudo-hardening rewrite + security-model edit are backed by the canonical Dockerfile + runtime check (verified above).
- `conventions.md § Pin a grep assertion...` accurately describes the shipped guard (first-`::`-split, `grep -qF`, worktree-root resolution, honest assertion-drift-only scope). One minor inconsistency vs the test, non-blocking: the doc says the path is "resolved against the worktree root" (true — guard uses `git rev-parse --show-toplevel`), whereas the sibling wiring test hardcodes `DEVSHOP="/devshop"`. The two tests resolve roots differently; in this worktree they happen to point at the same canonical skills tree (identical `ls`), so no behavioral divergence today, but the wiring-autodetect grep reads the canonical `/devshop/.claude/skills`, not the worktree's copy. Worth a one-line awareness note; not a correctness defect for this diff.

### Severity summary

- CRITICAL / P0 / P1: none.
- INFORMATIONAL: 3 (overstated `-wF` whole-token claim [9/10, latent]; empty-literal silent-pass [8/10]; prose-counts-as-wired tradeoff [7/10, by-design]).

All three are INFORMATIONAL — none blocks landing. The two highest-confidence ones (overstated comment, empty-literal hole) are cheap doc/guard tightenings the orchestrator may route or defer.

## Dismissals

- **Substring-vs-token false match for `port.sh`/`report.sh`** — dismissed (n/a). Verified `grep -wF 'port.sh'` does NOT match `report.sh` (no word boundary between `re` and `port`). The specific example in the comment/spec is correct; only the _generalization_ to hyphen/dot suffixes is overstated (captured as a separate INFORMATIONAL finding).
- **Non-recursive skill glob missing nested skills** — dismissed (n/a). The guard uses `grep -r ... --include=SKILL.md`, which recurses; confirmed it finds SKILL.md at depths 4-5 (`devshop/merge-devshop/SKILL.md` etc.).
- **Nonexistent pinned path / target file missing** — dismissed (n/a). `grep -qF "$literal" "$root/$path"` on a missing file returns non-zero → correctly flags drift (red), not a false-pass. Verified.
- **`bash -n` syntax error on structural-invariants.bats** — dismissed (false positive). `.bats` uses bats' `@test "..." {` syntax, invalid as bare bash; the bats runner parses and passes all tests. Not a defect.
- **Doc grep `-qE` vs guard `-qF` mismatch on pinned literals** — dismissed (n/a). The guard is intentionally looser (fixed-string substring vs the test's anchored regex). For all three annotations the literal contains no regex metachar that changes matching, and the guard only asserts presence, so there is no false-pass path. Verified each literal resolves.
- **Template Dockerfile has a 3rd NOPASSWD entry (`refresh-allowed-ips.sh`) not mentioned in sudo-hardening.md** — dismissed (n/a). The note is explicitly scoped to the devshop container model (two entries), which matches `.devcontainer/Dockerfile` exactly. The template's additional entry is out of scope for this docs closure and not asserted against.

---

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

---

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

---

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

---

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

---

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

---

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

---

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

---

## Phase 3 focused-fix log

Halt-on-find gates surfaced findings on the just-shipped guard code; the
orchestrator dispatched/applied mechanical fixes (single-file, no API/auth/
migration surface) and re-ran bats green (62/62 structural-invariants):

- **Gate 11 (convention)** — close-on-ship gap: the two guard PLAN rows
  (`grep-test-drift-guard`, `wiring-test-skill-autodetect`) were still live
  in `PLAN.md § Planned (v0)`. Deleted (commit 525a03e).
- **Gate 6 (/review) M2 (8/10)** — empty-literal annotation (`# pins: foo.md :: `)
  silently passed (`grep -qF ""` matches any file). Now flagged malformed.
- **Gate 6 (/review) M1 (9/10, latent)** — `grep -wF` treats `-`/`.` as word
  boundaries; replaced with a whole-FILENAME-token regex ([^A-Za-z0-9._-]).
- **Gate 5 + Gate 6 coherence** — corrected the worktree-root resolution
  wording in spec.md D3 and conventions.md (was "resolved under \$DEVSHOP").
- **Gate 6 #3 (7/10, by-design)** — basename in SKILL.md prose counts as wired:
  intentional per D1/D2 (low-impact false-negative); no change. Not pending.

---

## Phase 3 → 4 advance log

### 2026-06-02T18:16:24Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-02T18:16:24Z -->

### 2026-06-02T18:16:24Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-02T18:16:24Z -->

### 2026-06-02T18:16:24Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface and run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-02T18:16:24Z -->

### 2026-06-02T18:16:24Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-02T18:16:24Z -->

## Audit 1: manual (2026-06-02)

<!-- audited-at: 4d174f24d61f4d3b17b8aaed9d4a1a40a4916e12 -->
<!-- range: f2c1e34bfb7a4c6b541885042408eb7d8d1700b5..4d174f24d61f4d3b17b8aaed9d4a1a40a4916e12 -->

findings: high=0 medium=0 low=0

(/ak-merge-devshop Phase 1.1 re-audit over the full feature delta — both Layer-2
reviews clean. Empirically verified: the 3 `# pins:` seeds resolve, the wiring
autodetect catches the two pruned scripts + excludes vendor-bats-libs.sh, the
empty-literal/first-`::` parsing matches the prose, and the sudo open→solved
rewrite is coherent across sudo-hardening.md / security-model.md / notes/README.md.)

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
