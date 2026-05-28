## Gate 5: docs-and-tests-review

<!-- audited-at: 23518d9504164240972a4e8dd0c345f63c1860d7 -->
<!-- range: origin/main..HEAD (merge-base: ab7745a) -->

findings: high=0 medium=2 low=2

Note: `origin/main` has diverged by 1 commit (`c5e3aaa`) that is not on
this branch. Changes to `release.sh`, `release-devshop/SKILL.md`,
`propagation-entry.bats`, and the two responsive/theme convention lines
in `conventions.md` are artifacts of that divergence and are excluded
from this audit. The actual feature diff is `ab7745a..HEAD`.

### Docs findings

- [low] **SKILL.md § 3.0 preflight: local-env-health.sh positioned after supabase-bootstrap.sh but spec says "alongside".** The conventions.md addition says the health check runs "alongside the Supabase bootstrap," and the spec (D1) says "Called from Phase 3.0 preflight." In practice, the SKILL.md wiring places the `local-env-health.sh check` call *after* `supabase-bootstrap.sh up` (line 857 vs line 852). This is correct behavior (Supabase must be up before the health check queries its status), but the word "alongside" in conventions.md is slightly misleading. It suggests parallelism when the calls are sequential. Not blocking -- the ordering is correct for correctness; the prose is just imprecise.

- [low] **No cross-reference from `local-env-health.sh` script header to conventions.md.** The script header (line 20) references `specs/local-env-pillar/spec.md` for its provenance, and the SKILL.md wiring is documented. The new `conventions.md` subsection documents the script. However, the script header's `Does NOT:` section could mention that the 1GB threshold is documented in conventions.md for discoverability. Not blocking since the conventions.md subsection is the canonical reference and the script is well-commented.

### Tests findings

- [medium] **Zombie detection failure path untested in `preship-local-env-health.bats`.** Test at line 148 ("check exits 1 on zombie processes") explicitly notes "We can't easily mock /proc/<pid>/status in the real filesystem, so this test verifies the healthy path (no zombies = pass)." The spec lists zombie detection as one of the 4 core checks (D2) and the test matrix (spec § Tests item 4) calls for "check exits 1 on zombie processes (mocked lsof/ss)." The failure path for Check 4 is exercised only in production -- never in the bats suite. This means a regression in the zombie detection logic (e.g., a typo in the `grep '^State:'` pattern at script line 173) would not be caught by tests. Recommendation: create a mock `/proc/<pid>/status` file via `BATS_TEST_TMPDIR` and point the script at it (the script already reads from `/proc/$pid/status` directly, so this would require a small refactor to make the proc path injectable, similar to how `PROC_MEMINFO` is already injectable).

- [medium] **`recover` success-kill path untested.** The bats suite tests two `recover` paths: (1) no processes to kill, (2) refuses to kill the protected dev server PID. The third path -- successfully killing a non-protected zombie and reporting "killed: PID X on port Y" -- is never exercised. The spec (§ Tests item 5) lists "recover kills identified zombies (mocked kill)" as a required test case. The `kill` mock is already scaffolded in the PID-protection test (line 228-233) but never used for the success path. Recommendation: add a test where `ss` reports a PID on a port, `DEV_SERVER_PID` is set to a different value (or empty), and the mock `kill` succeeds, then assert the "killed:" output and verify the kill mock was called.

### Bypass trailer audit

- (none found in the feature commits)

## Dismissals

None
