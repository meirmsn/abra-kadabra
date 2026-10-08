# W3 — Verification foundation

Make "it works" something we can demonstrate anywhere, automatically. CI is the
only gate whose result the agent can't change — until W3.1 lands, state in LOG
that local/cloud hook results differ (F-CLOUD-06).
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W3.1 Devshop CI — P0 · M0 · S

Findings: F-TEST-01.
Done when: every PR to the devshop runs the full bats suite + shellcheck in GitHub
Actions from a clean clone, and it's a required check in the W0.6 ruleset.

- [ ] **W3.1.1** `.github/workflows/devshop-ci.yml`: deps (rsync, gawk, jq, gitleaks pinned with checksum), `pnpm test:kit`, shellcheck; `permissions: contents: read`. `[owner]` may need to push the workflow file if the agent's token lacks `workflow` scope (unverified in cloud — REVIEW-1 R4) — evidence: green run linked in LOG
- [ ] **W3.1.2** `[owner]` Add as required check to the `main` ruleset (W0.6.1)

## W3.2 Tests run anywhere — P0 · M0 · M

Findings: F-TEST-01, F-TEST-02, F-HOOK-08, F-TEST-04.
Done when: bats green in CI, in a cloud session, and in a linked worktree, with zero environment-caused skips.

- [ ] **W3.2.1** Self-locating scripts: one helper resolves the kit root from the script's own path (worktree-correct); replace hardcoded `/devshop/...` in scripts, hooks, settings hooks, tests (F-TEST-01; F-HOOK-08 path part — the missing `.hooks/` symlinks part is W1.1.5) — V2 + run suite from a worktree
- [ ] **W3.2.2** Fix the 18 environment failures: declare deps (rsync, gawk) in CI/setup; resolve `vendor-bats-libs.sh` mode contradiction; POSIX awk or require gawk (F-TEST-02) — V2
- [ ] **W3.2.3** Confirm the fixture-identity guard (`61de613`) holds — R1 found 0 fixture-identity commits after it (F-TEST-04) — V2
- [ ] **W3.2.4** Fail (not skip) when a required precondition is missing, except an explicit allowlist — V2

## W3.3 Fixture project + scenario runner + attack suites — P0 · M0→M1 · L

Findings: F-TEST-05; enables scenario verification everywhere.
Done when (M0 part): fixture exists and the scenario runner runs in CI. (M1 part): both attack suites run in CI/fixture and pass.

- [ ] **W3.3.1** **(M0)** Fixture: a separate public-safe GitHub repo (`abra-kadabra-fixture`) is recommended so PR/CI/ruleset scenarios are real; record in DECISIONS
- [ ] **W3.3.2** **(M0)** Scenario runner: `kit/tests/scenarios/*.sh` building scratch repos, running hooks/install, asserting outcomes; in CI — V2
- [ ] **W3.3.3** **(M1)** Attack suites — runner + CI wiring only; individual scenarios are written by their W1/W0 tasks:
  - **in-VM** (must be blocked by hooks/scripts): failing lint/typecheck/gitleaks, env overrides (`DEVSHOP`, `DEVSHOP_FORCE_MODE`), `kit/` dir mode flip, reviewer garbage/auth-error output, `humanReviewed` under `CLAUDECODE`, manifest `../`, secrets in env, unlocked hook replacement
  - **outside-VM** (must be rejected by GitHub on the fixture repo): `git commit -n` / `--no-verify` reaching `main`, direct push to `main`, force-push, merge with red checks, `pull_request` workflow reading a deploy secret
- [ ] **W3.3.4** Scenario coverage for untested critical scripts: init (non-root parts), session-start, release (dry run), sync, `adversarial-review.sh` (until deleted) (F-TEST-05) — V3
- [ ] **W3.3.5** Dogfood checklist + prompt: patch-tier change on the fixture in a cloud session, evidence captured (used at M2/M3 exits)

## W3.5 Walking skeleton — P0 · M1 · M

Assumptions tested: A-06, A-08, A-15, A-16. Done when: on the fixture, in a fresh
cloud session, the thinnest version of the target runs end-to-end — pinned install
(crude is fine) → one skill → change → PR → required CI gate incl. acceptance→test
check → rulesets enforce → owner merges — and the run is recorded against the
north-star scenario ([TARGET.md](../TARGET.md)). From then on, every epic re-runs it
before it's done.

- [ ] **W3.5.1** Define the skeleton's minimal parts under the D-14 outcome (one page, reviewed)
- [ ] **W3.5.2** Build each part at its crudest working form; run end-to-end; record gaps as tasks
- [ ] **W3.5.3** Script the re-run (`kit/tests/scenarios/skeleton.sh` + dogfood checklist) so every epic can repeat it

## W3.4 Test-suite triage — P1 · before W6/W8 rewrites · M

Findings: F-TEST-03. Moved earlier by REVIEW-1: ~1,070 prose greps would break on every skill rewrite.
Done when: prose-pinning greps replaced by behaviour/structure tests; count and runtime recorded vs baseline.

- [ ] **W3.4.1** Classify `util-*.bats`: behaviour / structural-invariant / prose-pin
- [ ] **W3.4.2** Delete prose-pin tests for text being rewritten; keep link/anchor/wiring invariants
- [ ] **W3.4.3** LLM eval set for reviewer/conformance (fixed fixtures, expected verdicts; ≥5 seeded + ≥5 honest) — used by W6.1; on demand, not per commit
