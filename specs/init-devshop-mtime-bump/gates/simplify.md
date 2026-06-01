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
