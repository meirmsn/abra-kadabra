<!-- audited-at: 2b0e60bab0bb996dc9c4436919b41333dac0f195 -->

# Pre-ship review — init-devshop-mtime-bump (devshop mode)

## Router Summary

- Gates dispatched (6): docs-check, fast-job-local (bats), simplify, convention, docs-and-tests-review, review — all `pass`.
- Carve-out gates (13): n/a or structural-blocked per devshop-self-mode (no UI / Supabase / migrations / METRICS / perf surface).
- Gate 5 (docs-and-tests) findings: high=0 medium=3 low=2 — 2 mediums fixed in commit 8f557b2 (manifest+architecture legend sync; content-match re-lock test pin); remainder advisory (see below).
- Dismissals: none across dispatched gates.
- Audit stamp 2b0e60b is one commit behind HEAD (8f557b2 = the medium-finding fix); /ak-merge-devshop Phase 1.1 re-audits the delta by construction.

---

## Gate 1: docs-check

**Verdict: pass.** Every devshop behavior change in `git diff origin/main..HEAD` carries a same-change doc update; in-script comments are accurate; the architecture.md § File lifecycle description is consistent with the new conditional-refresh behavior; and the cross-doc survey for stale "every container start" / "always-chown" phrasing found no doc that _misdescribes_ the post-fix behavior.

### (1) Behavior change ↔ doc coverage (same change)

The diff has exactly two behavior changes, both documented in-change:

- **Content-conditional `[locked]` refresh** (`cmp -s "$src" "$dst"` gates the `install`) → covered by the architecture.md table `[locked]` row rewrite ("content-conditionally refreshed every container start … a content match is a true filesystem no-op, so a quiet boot never bumps mtime") and the in-script comment block + inline comments.
- **Ownership-conditional chown/chmod lock steps** (`stat -c '%U:%G %a'` tuple guard on all five lock sites: manifest content-match branch, firewall-extras lock, devshop-self for-loop, recursive `find` over kit scripts, and the devshop-self-mode early-exit branch) → covered by the architecture.md hybrid-lifecycle paragraph rewrite ("re-locks it … ownership-conditionally — the chown/chmod runs only when the `stat -c '%U:%G %a'` tuple has drifted") and the in-script comment block.

Two new bats regression tests (`manifest-lifecycle.bats`) statically pin both guards. Spec § Files-to-modify also calls for deleting the `kit/TODOS.md` entry that scoped this — not in this diff's file set; flagged below as a tracker-closure item to confirm (outside this gate's grep-on-`kit/docs`+`CLAUDE.md` mandate, noted for the merge step).

### (2) In-script comment accuracy

Accurate. The comment block (added ~after the early-exit branch) says "Every chown/chmod lock step **below**" and enumerates the four sites that follow it (manifest content-match branch, firewall-extras lock, devshop-self for-loop, recursive find). The fifth guarded site (the devshop-self-mode early-exit `settings.json`/`.dcg.toml` loop) sits _above_ the block and is separately commented ("Lock essentials even in devshop-self mode"), so the "below" scoping is correct, not an omission. The inline comments at the `install`/`else` branch correctly state the `install` is the script's only mtime-bumping write and that the `else` branch still recovers ownership/mode a git op eroded. The `cmp -s` exits-2-on-missing-dst behavior (preserving first-propagation) is correctly captured in both the inline comment and spec § Out-of-scope.

### (3) architecture.md § File lifecycle consistency

Consistent. Both the `[locked]` annotation-table row and the Hybrid-lifecycle paragraph were rewritten from the old unconditional framing to the conditional framing, and they agree with the script: refresh gated on content (`cmp -s`), lock gated on ownership tuple (`stat`). No internal contradiction between the two updated passages or with the script.

### (4) Cross-doc stale-phrasing survey (grep over kit/docs/ + CLAUDE.md)

Grepped for `every container start`, `every start`, `refreshed on every`, `chown … on every`, `always-chown`, `overwrite … on every`, `re-?lock … every`. Hits triaged below. **None misdescribe the post-fix behavior** — every survivor describes the lifecycle _guarantee_ (the locked copy is kept current from template / ends up root-owned), which the conditional refresh preserves exactly (a content-match is a no-op _because_ content already matches; an ownership-match is a no-op _because_ ownership already matches). None makes an mtime / always-write claim that the fix invalidated.

In-scope `[locked]`-refresh mentions (survivors, all accurate):

- `kit/docs/FAQ.md:25` — "root-owned copies refreshed every container start". Compressed lifecycle-bucket summary; no mtime/always-write claim. Accurate. _(Borderline — see optional polish below.)_
- `kit/docs/guide/architecture.md:176` — sync-exclude context, "refreshed every container start by init-devshop.sh". Describes which lifecycle bucket the leaves belong to (for the exclude rationale). Accurate.
- `kit/docs/guide/security.md:39` — "refreshed from template by init-devshop.sh on every container start". Lifecycle-bucket altitude; guarantee holds. Accurate. _(Borderline — see optional polish below.)_
- `kit/docs/guide/workflow.md:421` — firewall-extra-domains "locked to root:root 644 on every container start"; "reverts on every start". Describes the lock invariant; the ownership-conditional guard preserves the end-state. Accurate.
- `kit/docs/guide/ops.md:405` — firewall-extra-domains "chowned root:root 644 on every container start". Same lock invariant. Accurate.
- `kit/docs/guide/ops.md:326` — buggy `init-firewall.sh` self-heal: "overwrites the project's copy from the fixed template on every container start". The buggy file _differs_ from the fixed template → `cmp -s` mismatches → `install` fires → self-heal still works. Outcome unchanged and correct; the "every start" is the recovery guarantee, not an mtime claim. Accurate.

Out-of-scope hits (different subsystems, not `[locked]` refresh — listed to show they were checked, not flagged): `architecture.md:91` (port-derive), `ops.md:114` (compose env), `ops.md:281` (init-firewall run), `ops.md:305` (compose port interpolation), `ops.md:503` (playwright-cache populate), `local-supabase-compose-isolation.md:53` (init-host-env), `CLAUDE.md:170` / `workflow.md:323`/`487` (unrelated "every" matches). None describe the `[locked]` install/lock cadence.

### Optional, non-blocking polish (NOT required for this gate to pass)

Two summary-altitude lines could optionally pick up the same one-clause "content-/ownership-conditional" qualifier the architecture.md canonical passages now carry, purely for symmetry — they are **not stale** (no mtime claim to falsify) and are explicitly outside the spec's scoped doc-update set:

- `kit/docs/FAQ.md:25` — could read "content-conditionally refreshed every container start" to mirror the table.
- `kit/docs/guide/security.md:39` — could note the refresh is content-conditional.

These are author-discretion improvements, not findings. Surfaced for the merge author; no halt.

## Dismissals

None.

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

- Result: pass (1628 ok, 0 not ok — full kit/tests/ bats suite, exit 0; devshop test surface)
- Includes the two new regression tests (cmp -s guard + stat-tuple idempotence guard) and the preserved Test-8 install-pattern test.

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

**Result:** pass (no fixes applied — diff already clean).

**Scope:** `git diff origin/main..HEAD` over `kit/scripts/init-devshop.sh`
(content-aware `[locked]` refresh + idempotent chown/chmod stat-tuple guards),
`kit/tests/manifest-lifecycle.bats` (two static-grep regression tests), and
`kit/docs/guide/architecture.md` (prose: unconditional → conditional).

Quality-only review across four angles (reuse / simplification / efficiency /
altitude). No correctness-bug hunting (that is `/review` / `/cso`'s job).

Note: the gstack Agent/Task tool is unavailable in this gate's environment, so
the four angles were reviewed inline against the full diff plus the complete
surrounding `init-devshop.sh` (read end-to-end, not just the hunks). Findings
below are the consolidated result.

### Verification

`kit/tests/lib/bats-core/bin/bats kit/tests/manifest-lifecycle.bats` → 30/30
green, including the two new guards (#29 cmp -s, #30 stat-tuple) and all
Test-8-pinned substrings intact (`src_mode=$(stat -c '%a' "$src")`,
`install -D -m "$src_mode" -o root -g root`, `if [ -f "$src" ]; then`).

### Findings

None applied. The diff reduces work (skips no-op installs/chowns on quiet
boots), adds no dead code, no collapsible copy-paste that survives a
behavior-preserving rewrite, and is implemented at the correct altitude — each
guard sits at an existing lock site rather than fighting the deliberately
non-unified lifecycle carve-outs the architecture doc already documents.

## Dismissals

- **Reuse — collapse the five stat-tuple guards into a shared
  `relock_if_drifted()` helper.** Dismissed. (a) The gate brief explicitly
  instructs leaving the five parallel `if` blocks unless a helper is a clear net
  win that keeps each call-site readable. (b) CLAUDE.md § Implementation
  Approach mandates readable/debuggable over clever for this security-critical,
  root-run boot script — each lock line must stay independently auditable. (c)
  The five sites are not uniform: one lives inside the content-match `else`
  branch keyed on `$src_mode` (line 208), one inside a `find … -print0` pipe
  loop (line 277), one in the devshop-self early-exit `for` loop (line 70), and
  two are flat 644 locks (lines 225, 269). A helper would have to thread a
  variable mode and would hide the security intent behind an indirection in a
  script where the value of the code is its directness. Not a clear net win →
  leave.

- **Simplification — the manifest-loop `else` branch (lines 205-211) re-locks
  ownership redundantly after `install` already sets owner/mode.** Dismissed as
  a false positive. The `else` branch fires only on the `cmp -s` content-match
  path, where `install` is intentionally skipped (that skip is the whole mtime
  fix); the stat-gated chown/chmod is the _only_ thing recovering ownership a
  git op eroded on an otherwise-unchanged file. Removing it would regress the
  security re-lock. Necessary, not redundant.

- **Simplification — the two-part comment block (header lines 169-178 + inline
  lines 200-210) is verbose.** Dismissed. This documents a silent-failure
  security gate whose revert is invisible without rebuilding a container;
  CLAUDE.md explicitly wants exactly this class of trap documented inline.
  Trimming it trades durable clarity for nothing.

- **Efficiency — the added `stat` / `cmp -s` calls are extra per-boot work.**
  Dismissed (inverted). The guards replace unconditional `install`/`chown`
  writes with a cheap `stat` (or `cmp -s`, only over the small `[locked]` set)
  that elides the far costlier mtime-bump cascade re-arming VS Code's rebuild
  prompt. Net efficiency win, which is the feature's intent — nothing to fix.

- **Altitude — per-site conditional guards are a bandaid; generalize into one
  manifest annotation / mechanism.** Dismissed. The five sites span three
  lifecycles (manifest `[locked]`, bespoke firewall-extras, devshop-self
  bootstrap + recursive-find) that `architecture.md` documents as deliberately
  _not_ unifiable under a single annotation ("Two hardcoded carve-outs remain by
  design"; "Hybrid lifecycle … stays bespoke … Promote to a manifest annotation
  when a second file needs the same shape"). Applying the same guard uniformly
  at each existing site matches the intended structure — the correct altitude
  given the carve-outs are by-design, not accidental.

- **Tests — the two new tests are thin static greps, not behavioral.**
  Dismissed. The regression is silent (only observable by rebuilding a
  container), so a runtime assertion is not available in CI; pinning the guard
  substrings statically is the appropriate and proportionate guard against a
  silent revert. Consistent with the suite's existing static-grep tests
  (#14-#28).

---

# Gate 5: docs-and-tests-review

Result: PASS (no high-severity findings) — 0 high / 3 medium / 2 low. Records advisory medium/low findings for follow-up; none block the gate.

## Audit 1

<!-- audited-at: 2b0e60bab0bb996dc9c4436919b41333dac0f195 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=3 low=2

label: pre-polish (Gate 5, init-devshop-mtime-bump)

### Docs findings

- [medium] kit/manifest.txt:10 — The `[locked]` annotation legend (the manifest's own single-source-of-truth header) still reads "root-owned copy, refreshed every container start by init-devshop.sh" with no content-conditional qualifier. The diff's whole premise is that a content-match boot is now a true no-op (no install, no mtime bump); architecture.md § File lifecycle was updated to say so but this legend — which `architecture.md` itself names as "the single source of truth" — was not. A future reader cross-checking the two will see the legend assert unconditional refresh. Recommend appending a clause like "(install runs only when the destination content differs — a content match is a no-op)" to keep the canonical legend consistent with the behavior it documents. Not high: the imprecision is a softening, not a falsehood (content genuinely does refresh when it differs), and the authoritative prose now lives in architecture.md.
- [low] kit/docs/FAQ.md:25 — Summary bullet "root-owned copies refreshed every container start" carries the same now-imprecise unconditional phrasing. FAQ is intentionally high-level so this is borderline-dismissable, but flagged for consistency since the same edit pass touched the sibling architecture.md row.
- [low] kit/docs/guide/security.md:39 / kit/docs/guide/architecture.md:176 — Both say `[locked]` files are "refreshed from template by init-devshop.sh on every container start." These describe the refresh-from-template _direction/semantics_, which remain true (a drifted file still refreshes); the only changed nuance is that an unchanged file is now a filesystem no-op. Strictly still-accurate, but a one-clause parenthetical ("when content differs") would remove any apparent tension with the new architecture.md table row. Low / accepted as-is is defensible.

### Tests findings

- [medium] kit/tests/manifest-lifecycle.bats:533 — The stat-tuple idempotence test pins the _substring_ `stat -c '%U:%G %a'` via a single `grep -qE`, but that pattern matches all 6 occurrences in init-devshop.sh (devshop-self for-loop, firewall-extras lock, recursive find, the devshop-self settings block, AND the new content-match re-lock branch). The test therefore stays green if the one genuinely-new branch — the security re-lock inside the `cmp -s` content-match `else` (init-devshop.sh:204-208, `chown root:root && chmod "$src_mode"` when the dst tuple drifted) — were dropped, because the 5 pre-existing call-sites still satisfy the grep. That re-lock is the load-bearing security property of the content-aware path (a git op that erodes ownership on a content-identical file must still get re-locked); it is currently NOT pinned by any test that would fail on its specific removal. Recommend a second assertion scoped to the install-loop region (e.g. grep for the `chown root:root "$dst" && chmod "$src_mode" "$dst"` line, or an anchored multi-line pattern around the `else` branch) so the new branch is independently regression-pinned. Not high: the branch is exercised in practice every boot and is covered by the broader security-files-freshness hook posture, but its test pin is weaker than the cmp -s pin.
- [medium] kit/tests/manifest-lifecycle.bats:514,533 — Both new tests are static source-greps, not behavioral exercises: they assert the guard _strings are present_, not that the guard _behaves correctly_. They correctly fail on a literal revert (verified: the current script contains `cmp -s "$src" "$dst"` ×1 and the stat tuple ×6; a revert removes both literals → both greps fail → tests fail, so they are NOT trivially-passing). But a logic-preserving-string refactor would slip through: e.g. inverting the `cmp -s` sense (gating the install on _match_ instead of _differ_), or moving the stat-guard onto the wrong write, leaves both literals intact and both tests green while reintroducing the mtime bump or breaking the re-lock. No fixture-level test runs init-devshop.sh and asserts (a) mtime is preserved across a content-match boot and (b) a drifted tuple is recovered. A true behavioral test needs root/chown which unprivileged bats can't cleanly do, so the static pin is a defensible tradeoff consistent with this file's existing structural-assertion style — but the adequacy ceiling is "revert-detector," not "behavior-verifier," and that should be acknowledged rather than assumed away.
- [low] kit/tests/manifest-lifecycle.bats:514 — The cmp -s pin's regex `'cmp -s "\$src" "\$dst"'` is tightly coupled to the exact variable names `$src`/`$dst`. A benign rename (e.g. `$source`/`$target`) during future refactoring would silently break the pin (false-fail on a correct script). Minor brittleness; acceptable given the variables are stable and the test comment explains intent, but noted as a maintenance footgun.

### Bypass trailer audit

- (none) — no Docs-Coverage-Bypass or Tests-Coverage-Bypass trailers in origin/main..HEAD.

## Dismissals

- **gstack/.gstack ignore false-positive** — n/a to this diff (no gstack surface touched).
- **METRICS.md coverage** — n/a: devshop-self mode has no METRICS.md / user-facing-event surface; the diff is infra-only (shell + bats + guide doc).
- **Responsive / theme / a11y** — n/a: no UI surface.
- **architecture.md § File lifecycle table + Hybrid-lifecycle paragraph** — NOT a finding: both were correctly updated in the same diff (table row now says "content-conditionally refreshed … a content match is a true filesystem no-op"; the firewall paragraph now says "re-locks … ownership-conditionally … only when the stat -c '%U:%G %a' tuple has drifted"). These are the primary docs and they track the code.
- **init-devshop.sh inline comments** — NOT a finding: the new block comment (lines 169-180) and the two install-loop branch comments accurately describe the cmp -s gate and the content-match re-lock; no stale inline comment was left behind by the change.
- **cmp -s exit-2 (dst missing) handling** — NOT a finding: `cmp -s` returns non-zero (2) when `$dst` is absent, so `! cmp -s` is true and the install fires, correctly covering the seed-on-missing case; comment at init-devshop.sh:197 documents this. Behavior is correct and documented.

---

## Gate 6: /review

**Result: clean — 0 findings (0 critical, 0 informational).**

Scope: devshop-self change. `kit/scripts/init-devshop.sh` (root-run container-boot
script, `#!/usr/bin/env bash`, `set -euo pipefail`) made content-aware via a `cmp -s`
guard around the manifest `[locked]` `install`, plus stat-tuple guards making every
chown/chmod lock step idempotent. Two static bats regression tests + one doc update.
No SQL, no auth, no LLM trust boundary, no UI. Diff: 346 lines total, of which only
~73 are code/test churn (rest is spec/doc artifacts).

Scope Check: CLEAN. Intent (commit + spec): stop init-devshop.sh re-mtiming/re-chowning
locked files on every quiet container boot (which re-arms VS Code's "Configuration
file(s) changed — Rebuild?" prompt and churns ctime), while preserving the security
re-lock. Delivered: exactly that — a `cmp -s` content gate on the one mtime-bumping
write, stat-tuple gates on the metadata writes, regression tests, doc rewrite. No scope
creep, no missing requirements.

### Shell correctness under `set -euo pipefail` (verified empirically under bash 5.2)

- **`cmp -s` on a missing dst exits 2**, and `if ! cmp -s "$src" "$dst"` correctly
  takes the refresh branch (exit 2 ≠ 0 → `!` → true). Verified. The diff's inline
  comment ("dst missing — cmp -s exits 2") is accurate. Condition-context exit codes
  do not trip `set -e`.
- **`$(stat ...)` failure does not abort.** At the two unguarded-stat sites (line 208
  manifest-else, line 277 find-loop) the dst is guaranteed to exist (208 runs only
  after `cmp -s` matched; 277 iterates `find -type f` output), so stat never fails
  there. The three `[ -e "$f" ] && [ "$(stat ...)" != ... ]` sites (70, 225, 269)
  short-circuit on the `[ -e ]` test before stat runs. Even in the contrived
  missing-file case, a failed `$(stat)` inside `[ "..." != ... ]` yields an empty
  string and a clean test exit (0/1) — `set -e` is not tripped. Verified.
- **`chown root:root "$f" && chmod ... "$f"` as the last statement in each guarded
  branch** is byte-for-byte **pre-existing** in origin/main (lines 70/200/242/248 there).
  This PR only wraps it in stat-guarded `if` blocks; it does not alter the compound.
  Under bash 5.2 a trailing `chmod` failure in that compound _would_ abort, but chmod/
  chown on an existing file cannot fail for root (the script runs as root via sudo on
  container start, and every branch is entered only when the file exists). No new risk,
  no behavior change vs. main.

### Security re-lock semantics — preserved

The content-match (else) branch is NOT a no-op for eroded ownership: line 208 re-checks
the `%U:%G %a` tuple against `root:root $src_mode` and re-locks (`chown && chmod`) on any
drift. `$src_mode` is derived from the same `stat -c '%a' "$src"` (line 198) that the
`install -m "$src_mode"` path uses, so a content-identical file whose owner _or_ mode a
git op eroded is still recovered to exactly the install path's target. The recursive
find-loop, FWE lock, and devshop-self for-loop likewise re-lock on tuple drift. A
content match is a true filesystem no-op only when ownership+mode already match.

### Could the `cmp -s` guard skip a needed refresh? — No

`cmp -s` compares full byte content, so it cannot skip a content refresh. Mode/owner
drift on a content-identical file is caught by the else-branch's `%a`-inclusive tuple
check (mode is part of `%U:%G %a`), so there is no "content matches but exec bit wrong"
gap. The find-loop's hardcoded 644 is unchanged from main (devshop scripts are invoked
via `bash <script>`, never executed directly).

### Tests

Both bats tests are **static `grep` pins** on the guard text, not behavioral execution
(the script needs root + a live container to run, so it cannot be unit-executed). This
is an appropriate choice and is called out honestly in the test comments ("a revert that
drops the guard regresses the bug SILENTLY (only visible by rebuilding a container)").
Verified the two grep patterns actually match the current script text (genuine green,
not false-green from a typo'd pattern): `cmp -s "$src" "$dst"` matches, `stat -c
'%U:%G %a'` matches (6 occurrences: 5 real guards + 1 doc comment).

### Doc

`kit/docs/guide/architecture.md` manifest-annotation table + hybrid-lifecycle paragraph
rewritten from "refreshed every container start" / "always-chown" to the content/
ownership-conditional present-tense description. Matches shipped behavior; no stale
"reverts on every start" prose left behind. Doc-staleness check: clean.

## Dismissals

None

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

**Result: pass** — zero mechanical violations; nothing fixed, nothing pending.

Scope: devshop convention check (`kit/docs/guide/conventions.md` + CLAUDE.md non-negotiables) over `git diff origin/main..HEAD`. Files: `kit/scripts/init-devshop.sh`, `kit/tests/manifest-lifecycle.bats`, `kit/docs/guide/architecture.md`, plus `specs/` artifacts (spec.md, tasks.md, verification.log).

### Checks performed

- **Shell-script structure/header style (`init-devshop.sh`)** — PASS. In-place edit to an existing script; no header change. The new logic preserves surrounding style: `set -euo pipefail` + `ERR` trap untouched; the added inline `#`-block comment (lines ~166-178) matches the existing block-comment voice that documents the manifest-driven lock loop; the conditional guards (`if [ -e "$f" ] && [ "$(stat -c '%U:%G %a' "$f")" != ... ]`, the `cmp -s "$src" "$dst"` install branch) use the same 2-space indentation and quoting discipline as the rest of the file. No bash-isms-under-dash concern (this script is `#!/usr/bin/env bash`, not a husky hook).

- **Bats tests match Test-8 family style/naming (`manifest-lifecycle.bats`)** — PASS. The two new `@test` blocks (lines 504, 521) are static-grep guards in the exact shape of the existing init-devshop Test-8 family (e.g. line 255 "refreshes [locked] content via mode-deriving install"): each uses `local script="$SCRIPTS_DIR/init-devshop.sh"` (worktree-correct, with the same explanatory comment about pre-push verifying the branch not `/devshop`), the `[ -f "$script" ] || skip` guard, a rich rationale comment explaining the silent-regression risk, and `run grep -qE ... ; assert_success`. Naming matches the descriptive-sentence convention used throughout the file.

- **Guide-doc internal consistency (`architecture.md`)** — PASS. The `[locked]` table row (line 84) updated from "refreshed every container start" to "content-conditionally refreshed ... `cmp -s` ... a content match is a true filesystem no-op" — consistent with the implemented `cmp -s` install branch. The firewall-extras hybrid-lifecycle paragraph (line 101) updated from "always-chown ... on every subsequent start" to "re-locks ... ownership-conditionally ... only when the `stat -c '%U:%G %a'` tuple has drifted" — consistent with the implemented guard. Table remains well-formed (all rows 3 columns / 4 pipes; cell padding re-balanced for alignment). Line 176's "refreshed every container start" is about the `[sync]`-exclusion rationale (why locked leaves don't round-trip), not mtime semantics — not made inconsistent by this change (the content-conditional install still yields a current file).

- **No new script under `kit/scripts/` without a bats test** — N/A / PASS. `git diff --name-status` over `kit/scripts/` shows a single `M init-devshop.sh` (edit only, no additions). The edit itself is covered by the two new bats regression tests.

- **Conventional-commit subjects, observable change, ≤72 chars** — PASS (7/7). All valid types (chore/docs/test/fix), all ≤72 chars (max 68). The two `fix:` subjects describe behavior ("make chown/chmod locks idempotent on stat tuple", "refresh [locked] files only on content difference"), not implementation mechanics. Logical-change-per-commit honored: content-refresh guard (T1), chown idempotence (T2), and tests (T3) land as separate commits.

- **"Every devshop tooling change includes doc updates in the same commit" non-negotiable** — PASS. The `architecture.md` doc edits and the load-bearing in-script comments landed in the same commit range as the code; the two `fix:` commits each carry the matching doc/comment delta rather than deferring docs to a trailing commit.

- **Bats suite re-run** — 30/30 pass (`kit/tests/lib/bats-core/bin/bats kit/tests/manifest-lifecycle.bats`), including the two new tests (#29, #30). No fixes were applied, but the suite was confirmed green at gate time.

### Dismissals

- **architecture.md line 176 "refreshed every container start" left unchanged** — Not a stale-language violation. This sentence documents why `[locked]` leaves are excluded from the `[sync]` round-trip (template→project canonical direction), a claim orthogonal to the mtime/`cmp -s` semantics this feature changed. The leaves are still effectively refreshed each start (the content-conditional install produces an up-to-date file); rewording it here would muddy the sync-exclusion explanation. Dismissed as out-of-scope, not deferred.

---

## Phase 3 → 4 advance log

### 2026-06-01T19:50:56Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T19:50:56Z -->

### 2026-06-01T19:50:56Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T19:50:56Z -->

### 2026-06-01T19:50:56Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface (Gate 2d)
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T19:50:56Z -->

### 2026-06-01T19:50:56Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-06-01T19:50:56Z -->

## Audit 2: manual (2026-06-01)

<!-- audited-at: 26eb625436007f3f37b01a7f422147547439079a -->
<!-- range: f2e2db9707834d64d48c574734fd90e5c976921b..26eb625436007f3f37b01a7f422147547439079a -->

findings: high=0 medium=0 low=5

Re-audit over the full range (Phase 0 → HEAD), covering Audit-1's medium-finding
fix (8f557b2: manifest+architecture legend sync, content-match re-lock test pin)
and the trailing bookkeeping commits (64784a3 gate sinks, 26eb625 BUILD-LOG/PLAN/
TODOS closure). Both Audit-1 mediums (docs: manifest.txt:10 legend; tests:
content-match re-lock unpinned) verified RESOLVED at HEAD; the content-match
re-lock pin was mutation-checked (drop the line → Test 6 grep fails). The
bookkeeping commits touch only carve-out paths (specs/\*\*, BUILD-LOG.md, PLAN.md,
kit/TODOS.md) — no new source surface. Remaining findings are the carried-forward
Audit-1 lows plus one new low (architecture.md heading/body label drift).

### Docs findings

- [low] kit/docs/guide/architecture.md:101 — Hybrid-lifecycle heading still labeled "chown-on-every-start" while the body now (correctly) says the re-lock is ownership-conditional (runs only on stat-tuple drift). Mild internal label/body drift in a touched doc; not a contradiction (chown is still attempted every start, just short-circuited).
- [low] kit/docs/FAQ.md:25 — Summary bullet "root-owned copies refreshed every container start" keeps the pre-change unconditional phrasing; the content-conditional no-op nuance now lives in architecture.md but not in this glanceable FAQ. Still semantically true; softening, not falsehood. (Carried from Audit 1; 8f557b2 did not touch FAQ.md.)
- [low] kit/docs/guide/security.md:39 / kit/docs/guide/architecture.md:176 — Both say [locked] files are "refreshed from template ... on every container start" without the content-conditional caveat. Both describe refresh direction/semantics, which remain true; only the unchanged-file no-op nuance is new. architecture.md:176 makes a sync-exclusion point where conditionality is not load-bearing. (Carried from Audit 1; unchanged in range.)

Verified-fixed since Audit 1 (not findings): manifest.txt:10 legend now reads "refreshes content only when it differs from the template source (cmp -s) and re-locks owner/mode only on drift, so a quiet boot is a no-op" — canonical legend tracks behavior. Named-mechanism empirical checks confirmed under the live shell: cmp -s exits 2/1/0 on missing/differ/identical; stat -c '%U:%G %a' emits the owner:group mode tuple form.

### Tests findings

- [low] kit/tests/manifest-lifecycle.bats:501-550 — All three new regression tests are static grep pins (revert-detectors), not behavioral exercises; a logic-preserving refactor could leave them green. Accepted tradeoff (root/chown/live-boot unavailable to unprivileged bats), now explicitly acknowledged in the test comments. Downgraded from Audit-1 medium to low because the comment honesty + BUILD-LOG record close the "assumed-away" gap.
- [low] kit/tests/manifest-lifecycle.bats:514 — cmp -s pin regex coupled to exact var names $src/$dst; a benign rename would false-fail. Minor maintenance brittleness; vars are stable, comment explains intent. (Carried from Audit 1.)

Verified-fixed since Audit 1 (not a finding): the content-match re-lock branch is now independently pinned by Test 6 (bats:548, grep -qF on `chown root:root "$dst" && chmod "$src_mode" "$dst"`), unique to the content-match else-branch (line 209; all other sites use literal chmod 644). Mutation-checked: removing the line → grep exit 1 → test fails. All 6 init-devshop bats tests pass green (vendored bats: ok 1-6). Coverage rubric (kit/scripts/\*\*.sh → matching .bats) satisfied. Skip scan clean (only benign file-existence guard skips; no .only / hard / dead-conditional skips).

### Bypass trailer audit

- (none) — no Docs-Coverage-Bypass or Tests-Coverage-Bypass trailers in f2e2db9..26eb625.
