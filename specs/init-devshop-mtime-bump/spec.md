<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: init-devshop-mtime-bump -->
<!-- date: 2026-06-01 -->

# Spec: init-devshop-mtime-bump

**Sources:**

- `kit/TODOS.md § init-devshop.sh mtime-bumps [locked] files` — primary scope (surfaced 2026-05-09)
- `PLAN.md` row `init-devshop-mtime-bump` — scope summary + score (16.0)
- `kit/scripts/init-devshop.sh` — edit target (the manifest `[locked]` refresh loop + chown/chmod lock steps)
- `kit/tests/manifest-lifecycle.bats` — existing test surface (Test-8 family pins the install loop statically)
- Prior shipped spec `specs/virtiofs-rebase-auto-switch/spec.md` — style/structure reference

Make `init-devshop.sh`'s root-owned `[locked]`-file refresh content-aware so a
quiet container boot is a true filesystem no-op — VS Code's "Configuration
file(s) changed — Rebuild?" prompt stops re-arming on every start.

---

## Product update

Single source-of-truth — `/ak-build` Phase 4.0 copies these into the
`BUILD-LOG.md` entry (`Headline:` ← Headline, `Summary:` ← Detail), and
`/ak-merge-devshop` reads this section when composing the squash commit body.

### Headline (user-facing)

Infrastructure update — no user-visible change in this PR.

### Detail (team-facing)

`init-devshop.sh` now refreshes its root-owned `[locked]` files content-aware:
it rewrites a file only when the template source actually differs, instead of
unconditionally `install`-ing every file on every container start. This stops
VS Code's "Configuration file(s) changed — Rebuild?" prompt from re-arming on
every boot after a clean rebuild — behavior that had been training operators to
reflexively dismiss a rebuild signal that matters for real changes. The
chown/chmod lock steps are likewise made idempotent (skip when ownership + mode
already match), eliminating redundant per-boot metadata churn while preserving
the security re-lock that recovers from git-op ownership erosion.

---

## Decisions (resolved at spec time)

3 `/ak-spec`-time decisions resolved in Phase 0 with the operator.

### D1: Stop the mtime bump on the manifest `[locked]` refresh loop

**Decision:** Wrap the `install -D -m "$src_mode" -o root -g root "$src" "$dst"`
in a `cmp -s "$src" "$dst" ||` guard so the content rewrite fires only when the
file actually differs. A missing destination makes `cmp -s` exit 2 (non-zero),
which still falls through to `install -D` (creating the file + parent dirs) — so
first-propagation of a new `[locked]` file is unaffected.

**Rationale:** The unconditional `install` is the only content rewrite in the
script, hence the only mtime bump, hence the sole trigger of VS Code's spurious
rebuild prompt. `cmp -s` exit codes verified empirically at Phase 0.2.5
(missing → 2, identical → 0, differ → 1).

### D2: Make the chown/chmod lock steps idempotent too

**Decision:** Guard every `chown root:root && chmod NNN` step with a
`stat -c '%U:%G %a' "$dst"` equality check against the desired `root:root NNN`
tuple, so the metadata write fires only when ownership/mode has actually drifted.
Applies to: the manifest loop's content-matches branch, the firewall-extras
trailing lock, the hardcoded devshop-self `for` loop, the recursive `find`
script-lock, and the devshop-self-mode settings/.dcg lock.

**Rationale:** The TODOS entry explicitly asks for this. chown/chmod bump ctime
(not mtime) so they don't trigger the VS Code prompt, but the guard eliminates
redundant per-boot metadata churn (notably the recursive `find` over every kit
script). The security re-lock is preserved — a git-op that erodes ownership to
`node:node` still triggers a re-`chown` on the next boot because the stat tuple
no longer matches.

### D3: Test a root-only boot script via static-grep regression tests

**Decision:** Add static-grep regression tests to `kit/tests/manifest-lifecycle.bats`
pinning the `cmp -s` guard and the `stat`-based ownership-idempotence guard.
Do NOT extract the loop into a sourceable lib for a functional test.

**Rationale:** `init-devshop.sh` runs root operations at load time and is not
safely sourceable; the maintainers already established static-grep as the test
pattern for this exact loop (Test-8 family, "without needing sudo"). A behavioral
test would require a new lib on a security-critical boot path and a rewrite of
the existing `install -D` grep test — higher blast radius than this bug warrants.

---

<!-- /ak-spec (Phase 1) expands the file from here. The Product update +
     Decisions sections above stay verbatim. -->

## Core user story

N/A — root-only container-boot script change; no user-facing flow added or modified. The observable effect (VS Code stops re-arming its rebuild prompt) is verifiable only by rebuilding a container, which is outside the bats test surface; the change is pinned statically instead (see Tests).

## In scope

- `kit/scripts/init-devshop.sh` — the canonical edit target (the `.devcontainer/init-devshop.sh` copy is a 3-line forwarder and is NOT touched).
- D1: wrap the manifest `[locked]` refresh-loop `install` in a `cmp -s "$src" "$dst" ||` guard so content is rewritten only when the template source and workspace destination actually differ.
- D2: make every `chown root:root` + `chmod NNN` lock step idempotent — guard each with a `stat -c '%U:%G %a' "$dst"` equality check against the desired `root:root NNN` tuple, writing metadata only on drift. Five sites:
  1. the manifest loop's content-matches else-branch (new, per D1/D2),
  2. the firewall-extras trailing lock (~line 200),
  3. the hardcoded devshop-self `for f in … ; do … chown … chmod …; done` loop (~lines 215–243),
  4. the recursive `find "$DEVSHOP/kit/scripts/" -type f -name '*.sh'` chown/chmod loop (~lines 246–249),
  5. the devshop-self-mode branch's `settings.json` / `.dcg.toml` lock (~lines 69–71).
- D3: static-grep regression tests in `kit/tests/manifest-lifecycle.bats` pinning the `cmp -s` content guard and a `stat -c '%U:%G %a'` ownership-idempotence guard.
- Doc update in the same commit (Non-Negotiable: every devshop tooling change ships doc updates). The in-script comment block (~lines 153–177) describing the lock model is updated to state the refresh + lock steps are now content/ownership-conditional. Close the `kit/TODOS.md` entry that scoped this.

## Out of scope

- The `.devcontainer/init-devshop.sh` forwarder (unchanged — logic lives in `kit/scripts/`).
- The sticky-bit `[locked-dir]` loops (`chmod 1755`) — `chmod` of an already-sticky dir is a cheap no-op and not a churn source the TODOS entry called out; leaving them avoids touching more surface than the bug warrants. (May be revisited later; not this PR.)
- Extracting the refresh loop into a sourceable lib for a functional test (explicitly rejected in D3 — higher blast radius on a security-critical boot path).
- Any change to password setup, symlink creation, Playwright-cache, gstack-symlink, or Supabase-port-derive sections.
- The `install -D` first-propagation path for a missing destination — preserved unchanged (D1: `cmp -s` exits 2 on a missing `dst`, which is non-zero, so the `||` still runs `install -D`).

## Files to create / modify

- **Modify** `kit/scripts/init-devshop.sh` — D1 `cmp -s` guard + D2 five `stat`-tuple ownership guards + the comment-block doc touch.
- **Modify** `kit/tests/manifest-lifecycle.bats` — append two static-grep regression tests (Test-8 family style).
- **Modify** `kit/TODOS.md` — delete the `init-devshop.sh mtime-bumps [locked] files` entry (closed by this PR).
- **No new files.** No METRICS.md (devshop-self mode). No migrations, no UI, no Supabase.

## Tests (D3)

Two new `@test` blocks appended to `kit/tests/manifest-lifecycle.bats`, matching the existing Test-8-family pattern: read the script from `$SCRIPTS_DIR/init-devshop.sh` (so the assertion holds in worktrees), `skip` if absent, then `grep -q` / `grep -qE` for the load-bearing substrings. No sudo, no sourcing of the script.

1. **`cmp -s` content guard present** — assert the refresh loop wraps the install in a difference check:
   - `run grep -qE 'cmp -s "\$src" "\$dst"' "$script"` → `assert_success`
   - Comment explains: this is the mtime-bump fix — an unconditional `install` rewrites (and re-mtimes) every `[locked]` file on every boot, re-arming VS Code's rebuild prompt. A revert that drops the `cmp -s` guard regresses the bug silently (only visible by rebuilding a container).

2. **`stat`-tuple ownership-idempotence guard present** — assert the lock steps gate on the current ownership/mode tuple:
   - `run grep -qE "stat -c .%U:%G %a." "$script"` → `assert_success`
   - Comment explains: chown/chmod bump ctime (not mtime) so they don't trigger the VS Code prompt, but the guard eliminates redundant per-boot metadata churn (notably the recursive `find` over every kit script). A revert to unconditional `chown`/`chmod` is a churn regression, not a correctness one — pin it statically so it's caught at gate time.

**Preserved existing tests** — the Test-8 assertion `init-devshop.sh refreshes [locked] content via mode-deriving install` (lines 255–277) stays green: the D1 refactor keeps all three pinned substrings present. See Gotchas.

## Task order

1. **T1 — `cmp -s` content guard (D1).** In the manifest `[locked]` refresh loop, wrap the `install -D -m "$src_mode" -o root -g root "$src" "$dst"` so it runs only when `cmp -s "$src" "$dst"` reports a difference (or the destination is missing). Keep the outer `if [ -f "$src" ]; then` absent-source guard and the `src_mode=$(stat -c '%a' "$src")` line intact (test-preservation — see Gotchas). The content-matches branch falls through to the T2 ownership guard.

2. **T2 — ownership-idempotence guards (D2).** Add a `stat -c '%U:%G %a' "$dst"` equality check against the desired `root:root NNN` tuple to each of the five lock sites, writing `chown`/`chmod` only on mismatch. The manifest loop's new content-matches else-branch re-locks ownership when content already matches (so a content no-op still recovers eroded ownership). Update the in-script comment block (~lines 153–177) to describe the conditional refresh + lock.

3. **T3 — static-grep regression tests (D3).** Append the two `@test` blocks described in Tests to `kit/tests/manifest-lifecycle.bats`. Run the bats suite to confirm both new tests pass and the existing Test-8 install-pattern test still passes.

(Flat list — 3 tasks, well under the 15-task phasing threshold.)

## Gotchas

- **CRITICAL — test-preservation on the D1 refactor.** `kit/tests/manifest-lifecycle.bats` lines 255–277 grep `init-devshop.sh` for three EXACT substrings: `src_mode=$(stat -c '%a' "$src")`, `install -D -m "$src_mode" -o root -g root`, and the `if [ -f "$src" ]; then` guard (matched as `if \[ -f "\$src" \]; then`). The D1 `cmp -s` guard MUST wrap _around_ the install without altering any of these — the `if [ -f "$src" ]` outer guard stays, `src_mode=…` stays, and the `install -D -m "$src_mode" -o root -g root` invocation stays textually intact (the `cmp -s "$src" "$dst" ||` prefix is added on the same or preceding line, not by rewriting the install args). If any substring changes, the existing test fails. Verify by running the suite after T1.

- **ctime-vs-mtime nuance (D2 scope rationale).** Only the `install` content rewrite bumps **mtime** — that is the sole trigger of VS Code's "Configuration file(s) changed — Rebuild?" prompt, so D1 alone fixes the user-visible symptom. `chown`/`chmod` bump **ctime**, which does NOT trigger the prompt. D2's ownership guards therefore don't fix the prompt — they exist to eliminate redundant per-boot metadata churn (the recursive `find` chowns every kit script on every boot). Don't conflate the two: T1 is the prompt fix, T2 is churn reduction.

- **Security re-lock preservation.** The ownership guards compare against the _desired_ `root:root NNN` tuple, so a git-op that erodes a locked file's ownership to `node:node` (the exact failure the lock defends against) makes the stat tuple mismatch → the guard fires `chown`/`chmod` on the next boot. The defense is preserved; only the redundant write when nothing drifted is skipped. The manifest loop's content-matches else-branch must still run the ownership guard (a file whose content matches can still have drifted ownership) — don't let a content no-op skip the ownership recovery.

- **`cmp -s` exit codes (verified at Phase 0.2.5).** Missing `dst` → exit 2; identical → exit 0; differ → exit 1. So `cmp -s "$src" "$dst" || install …` correctly installs when the destination is missing (2) or differs (1) and skips only when identical (0). First-propagation of a new `[locked]` file is unaffected.

- **Editability.** `kit/scripts/**` is permission-locked in the canonical `/devshop` tree but the worktree copy under `.worktrees/init-devshop-mtime-bump/kit/scripts/` is intentionally editable — do all edits there.

## Acceptance

- `kit/scripts/init-devshop.sh` refresh loop runs `install` only when `cmp -s` reports a content difference (or missing destination); all three Test-8-pinned substrings remain present.
- All five lock sites gate `chown`/`chmod` on a `stat -c '%U:%G %a'` mismatch against `root:root NNN`.
- The two new static-grep tests pass; the existing Test-8 install-pattern test still passes; full bats suite green.
- In-script comment block + `kit/TODOS.md` updated in the same commit.

## Rollback

Single-file logic change plus tests — revert the `init-devshop.sh` edit and the two test blocks. No state migration, no data, no deploy. The pre-fix behavior (unconditional `install` + `chown`/`chmod` every boot) is functionally correct, just churny, so a revert is safe at any time. Worst case if the `cmp -s` guard were buggy: a `[locked]` file fails to refresh on content change — caught by `check-security-files-freshness.sh` in pre-commit, which already validates freshness independently.
