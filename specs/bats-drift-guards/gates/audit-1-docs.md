Clean — no docs findings.

---

## Audit notes (devshop self-mode; $GIT_ROOT == /devshop → Section E skipped)

**Range**: `f2c1e34..4d174f2` (bats-drift-guards feature).

**Section A — Coverage**: PASS. The diff touches no source surface (`kit/scripts/**`,
`kit/hooks/**`, `template/**`, `.devcontainer/**`, `kit/manifest.txt`) — confirmed via
`git diff --name-only`. The changed surfaces are `kit/tests/**` (carve-out — no firing),
trackers (`PLAN.md`, `kit/TODOS.md`, `kit/FRICTION-LOG.md`, `BUILD-LOG.md` — carve-outs),
the security notes (`kit/notes/**` — carve-out), and `kit/docs/guide/conventions.md` (the
guide doc the audit itself owns). The new `# pins:` convention IS documented in
`conventions.md § Kit Testing (devshop infrastructure)`, satisfying the
`.claude/skills/**/SKILL.md`-adjacent test-behavior change. No Docs-Coverage-Bypass
trailers in range. No Existing-Project Migration Block required (no propagation-relevant
surface touched in this range — the sudo-scoping Dockerfile change shipped historically
~2026-04-10 and is only tracker-closed here).

**Section B — Adequacy**: PASS, with empirical verification of named mechanisms (cheap,
under-one-minute checks per the named-mechanism rule):

- The 3 seeded `# pins:` annotations all resolve in their targets at HEAD:
  `grep -qF` confirmed `One bare hostname per line` in
  `template/.devcontainer/firewall-extra-domains`; `.devcontainer/firewall-extra-domains
[scaffold-once]` in `kit/manifest.txt`; `/ak-check-docs-and-tests` in
  `.claude/skills/devshop/build/SKILL.md`.
- Doc claim "everything after the FIRST `::` is the literal, so the literal may contain
  colons" — verified by shell repro: `${annotation#* :: }` on `path :: foo: bar :: baz`
  yields literal `foo: bar :: baz`. Matches the test's parsing.
- Doc claim "a trailing `::` with nothing after it is flagged malformed, not silently
  passed" — verified: empty-literal parse correctly flags malformed (load-bearing because
  `grep -qF "" file` matches any non-empty file). The test code's empty-literal guard is
  present and the convention prose accurately describes it.
- Doc claim "`reconcile-task-commits.sh` + `virtiofs-rebase.sh` were pruned and are now
  caught by autodetect; `vendor-bats-libs.sh` stays" — verified: both pruned scripts ARE
  whole-FILENAME-token matched in a SKILL.md; `vendor-bats-libs.sh` is NOT in any SKILL.md.
- Doc claim "whole-FILENAME-token grep (bounded by `[^A-Za-z0-9._-]`), not `grep -wF`,
  so `url.sh` does not false-match `extract-prod-url.sh`" — matches the test's
  `(^|[^A-Za-z0-9._-])${script_re}([^A-Za-z0-9._-]|$)` regex exactly.
- Full `structural-invariants.bats` suite runs green at HEAD (62/62, including new test 62
  grep-drift and the autodetect-dependent wiring test 31), corroborating the BUILD-LOG
  "full kit bats suite green" claim for this file.
- The `sudo-hardening.md` open→solved rewrite is substantive (Problem/Desired-state prose
  replaced with the shipped scoped-NOPASSWD model + a concrete `sudo -n true` verification
  recipe + the "clean pass would signal a leak" inverse-check) — not a stub edit.

**Section C — Cross-doc coherence**: PASS.

- No renamed/deleted files in range (`--diff-filter=DR` empty) — no stale-path sweep needed.
- `security-model.md § Sudo scoping` was rewritten in lockstep with `sudo-hardening.md`
  (open-problem prose → shipped scoped model); the two no longer contradict. `kit/notes/
README.md` index line was updated from "analysis of … risks" to "the shipped scoped-
  NOPASSWD model" — consistent. No lingering reference to the old "analysis"/"Problem"
  framing anywhere under `kit/`.
- Tracker closure is coherent: no surviving references to `sudo-scoping-node`,
  `grep-test-drift-guard`, or `wiring-test-skill-autodetect` outside `specs/` after the
  PLAN/TODOS/FRICTION-LOG deletions. Friction recurrence history was folded into the
  BUILD-LOG entry (close-on-ship convention satisfied).
- Cross-refs INTO `conventions.md § Kit Testing` (from `init-firewall-port-allowance.bats`
  and `structural-invariants.bats` line 1003) resolve to the real section (line 760); the
  TOC entry exists and needs no update (content appended under the existing subheading).

**Section D — Bypass trailer audit**: No Docs-Coverage-Bypass trailers in range.

**Section E — CLAUDE.md hygiene**: Skipped (devshop self-mode).
