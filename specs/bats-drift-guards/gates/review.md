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
