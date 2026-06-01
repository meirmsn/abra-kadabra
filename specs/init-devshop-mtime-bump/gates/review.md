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
