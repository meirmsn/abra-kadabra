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
