# W3 — Verification foundation

Make "it works" something we can demonstrate anywhere, automatically.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W3.1 Devshop CI — P0 · M0 · S

Findings: F-TEST-01.
Done when: every PR to the devshop runs the full bats suite + shellcheck + link lint
in GitHub Actions from a clean clone, and it's a required check.

- [ ] **W3.1.1** `.github/workflows/devshop-ci.yml`: install deps (rsync, gawk, jq, gitleaks pinned), run `pnpm test:kit`, shellcheck `kit/**/*.sh`; note: workflow files may need a human push (CLAUDE.md footgun) — V4 (green run linked in LOG)
- [ ] **W3.1.2** Make it a required status check on `main` (owner action) — V1

## W3.2 Tests run anywhere — P0 · M0 · M

Findings: F-TEST-01, F-TEST-02, F-HOOK-08, F-TEST-04.
Done when: bats suite is green in CI, in a cloud session, and in a linked worktree,
with zero environment-caused skips.

- [ ] **W3.2.1** Self-locating scripts: one helper resolves the kit root from the script's own path (worktree-correct); replace hardcoded `/devshop/...` in scripts, hooks, settings hooks, and tests (keep `/devshop` only where a mount is genuinely meant) (F-TEST-01, F-HOOK-08) — V2 + run suite from a worktree
- [ ] **W3.2.2** Fix the 18 environment failures: declare deps (rsync, gawk) in CI/setup; resolve `vendor-bats-libs.sh` mode contradiction; make awk usage POSIX or require gawk explicitly (F-TEST-02) — V2
- [ ] **W3.2.3** Confirm the fixture-identity guard (`61de613`) blocks `Test <test@test.com>` commits outside bats (F-TEST-04) — V3
- [ ] **W3.2.4** Fail (not skip) when a required precondition is missing, except an explicit allowlist of skips with reasons — V2

## W3.3 Fixture project + end-to-end harness — P0 · M1→M2 · L

Findings: F-TEST-05 (untested critical scripts); enables V3/V4 everywhere.
Done when: a small public-safe fixture app (in-repo under `kit/tests/fixtures/` or
a separate `abra-kadabra-fixture` repo) can be installed/scaffolded, exercised by
scripted scenarios, and driven by Claude in a cloud session.

- [ ] **W3.3.1** Decide fixture location (in-repo fixture dir vs separate GitHub repo for real PR/CI flows) — record in DECISIONS
- [ ] **W3.3.2** Scenario runner: `kit/tests/scenarios/*.sh` creating scratch repos from the fixture, run hooks/sync/install, assert outcomes; wired into CI — V3
- [ ] **W3.3.3** **Attack suite**: one scenario per bypass in W1 (no-verify forms, env overrides, chmod -x, mkdir kit, HEAD:main push, reviewer garbage output, humanReviewed under CLAUDECODE, manifest `../`, secrets in env) — all must be blocked — V3
- [ ] **W3.3.4** Cover today's untested critical scripts at least at scenario level: init (non-root parts), session-start, release (dry run), sync (F-TEST-05) — V3
- [ ] **W3.3.5** Dogfood script: a checklist + prompt to run a patch-tier change on the fixture in a cloud session and capture evidence (used at M2/M3 exits) — V4

## W3.4 Test-suite triage — P2 · M5 · M

Findings: F-TEST-03.
Done when: prose-pinning greps replaced by behaviour/structure tests; suite runtime and count recorded vs baseline.

- [ ] **W3.4.1** Classify `util-*.bats` tests: behaviour / structural-invariant / prose-pin
- [ ] **W3.4.2** Delete prose-pin tests whose skill text is rewritten in W6/W8; keep link/anchor/wiring invariants
- [ ] **W3.4.3** Add a small LLM-in-the-loop eval for the reviewer and the conformance gate (fixed fixtures, expected verdicts), run on demand, not per commit
