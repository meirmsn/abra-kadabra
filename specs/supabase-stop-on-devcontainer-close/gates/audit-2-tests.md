# Audit 2 — Tests review

**Range**: `d394e3404df39240ad40a94303ed684605bb6fdc..HEAD` (2 commits)
**Feature dir**: `specs/supabase-stop-on-devcontainer-close`

## Audit 1 carry-forward — closed

Both Audit 1 low findings on `kit/tests/template-compose-isolation.bats`'s `cmd-relay.mjs traps SIGTERM + SIGINT and runs supabase stop` test are closed by commit `86536e3`:

- **Low 1 (25s timer pin)** — added `run grep -q '25_000' "$f"; assert_success` (line 119-120). Pins the `}, 25_000);` literal inside the force-exit `setTimeout` on `cmd-relay.mjs:50` — keeping the 5s slack against compose's 30s `stop_grace_period` (already pinned by the sibling `compose-isolation: compose.yml sets stop_grace_period on supabase-runner` test at line 125-131) loud against silent drift.
- **Low 2 (re-entrancy guard pin)** — added `run grep -q 'if (shuttingDown) return' "$f"; assert_success` (line 121-122). Pins the early-return guard at `cmd-relay.mjs:41` that prevents a SIGTERM-then-SIGINT race from double-spawning `supabase stop`.

The added comment block above the new assertions (lines 108-111) names the WHY of each pin — both cross-reference the canonical sibling test or the race scenario — so the assertions are self-documenting at audit time.

Verified every new `grep -q` literal resolves against the actual source patterns in `template/.devcontainer/supabase-runner/cmd-relay.mjs` (read from the worktree, not the pre-`d394e34` `/devshop/template/` checkout):

| Assertion literal | Source occurrence | Status |
|---|---|---|
| `25_000` | `cmd-relay.mjs:50` (`}, 25_000);`) | match |
| `if (shuttingDown) return` | `cmd-relay.mjs:41` (`if (shuttingDown) return;`) | match |

Both new assertions land on unambiguous patterns; no false positives or accidentally-matching unrelated lines.

## Section A — Coverage of new behavior

No new source files in this range — the fix commit `86536e3` only touches docs (`kit/docs/guide/ops.md`, `kit/docs/guide/local-supabase-compose-isolation.md`) and the bats test itself. The doc edits are container-name string corrections in code blocks (no executable behavior); no test pair required.

## Section B — Test quality

- No `test.only` / `describe.only` / `test.skip` patterns introduced (the file is `.bats`, not Vitest — but the scan covered both shapes; `git diff ... | grep -nE '\b(test|describe|it)\.(skip|only)\b'` returned empty).
- No weak assertions (`toBeDefined`, `toBeTruthy`, `length > 0`) introduced.
- The two new assertions follow the file's established shape: bats `run grep -q '<literal>' "$f"; assert_success`. Each pins an exact literal that appears once in the target source — no implementation-detail coupling, no shape-only assertion (these are file-content guards against silent drift, which is the design contract of the entire `template-compose-isolation.bats` suite per its head comment "Pure file-content checks; no real container needed").

## Section C — Bypass trailer audit

No `Tests-Coverage-Bypass:` trailers in either commit. Zero rows to harvest.

## Findings

Tests look solid — no findings.

**high=0 medium=0 low=0**
