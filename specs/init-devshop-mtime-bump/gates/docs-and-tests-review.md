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
