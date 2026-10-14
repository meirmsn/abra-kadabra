1. **Session start would never reach the CI check (the spec doesn't say where it goes).** `runtime/hooks/session-start.sh` exits early at line 28 (`[ "$cur" = "$hooks" ] && exit 0`) whenever hooksPath is already set, which is most sessions. Unless the spec says the CI check runs before that line, AC-3 can pass in a fresh-clone test and still never run in a real session. AC-3 also leaves out the 30 s timeout case: what line prints when the check times out? And the line should name the installed template path (`/opt/devshop-current/templates/ci.yml`?), not the repo-relative `runtime/templates/ci.yml`, which doesn't exist in a project.

2. **The Go line contradicts the Decisions.** The header says `**Go:** pending`, but a decision is recorded as "Changed after the go (owner, 2026-10-13, 'option 1')" and talks about "the former items 7, 8, 9". Either the go was given and the Go line is stale, or the "after the go" framing is wrong. Ask the owner which.

3. **Two literal claims don't match the codebase.**
   - "`slow` gets … `jq`" but not `fast`: `jq` is used by fast tests too (review-guard, reviewer, reviewer-pr, ship, git-hooks, post-edit, pre-bash). It works only because the ubuntu-24.04 image ships jq. List it for both jobs or for neither.
   - Moving `tests/bootstrap.test.sh` to the slow tier also moves its tools.pin vs `ci.yml` pin consistency check (lines 41-53). That check greps `^  GITLEAKS_VERSION:` etc. at the top-level `env:` of `ci.yml`, so the new `ci.yml` must keep those env keys at top level, and the spec doesn't say so. This static check would now also run only in the slow tier, which goes against "by concept".

4. **The `$BASE` rule isn't fully specified.** AC-1 requires `fast` to run `scripts/check-fast.sh "$BASE"` but never requires `BASE` to be defined (today it is a step-level `env:`). A workflow with an empty BASE passes the check, and `secret-scan.sh` then silently scans the whole history. Also, "a line starts with the script's path" rejects `./scripts/check-fast.sh` and `bash scripts/check-fast.sh`, and it's unclear whether `$BASE` without quotes counts. State this, or test it.

5. **PyYAML in the pre-push path is a new failure mode.** `scripts/lint.sh` will run `ci-tiers-check.py`, and the pre-push hook runs `lint.sh`. If a session image lacks PyYAML, the check exits 2 and every push is blocked. The spec says "sessions use the image's" but nothing installs or verifies it, and no AC covers it. Is a blocked push acceptable, or should `setup.sh` install it?

6. **Several items can't really be tested as written.**
   - AC-6 "with the tools listed above": no test can check this, and "Shown by `tests/run.sh`" doesn't cover it.
   - AC-7 "a grep for the old job names finds only history": `lint` and `secret-scan` are also script names (`scripts/lint.sh`, `secret-scan.sh`) and appear everywhere, so the grep has no defined pattern.
   - AC-5 "both run every part": `check-slow.sh` has a single part.
   - AC-4 "leading comment block" is undefined for blank lines and `#!` with no comment.

7. **Edge cases are missing from AC-1.**
   - More than one `environment:` job.
   - `needs:` on a deploy given as a string.
   - A tier script run inside a reusable workflow (`uses:`).
   - Workflow-level `on:` path filters, which skip the whole run so required checks never report.
   - A job named `fast` running under a matrix.
   - The YAML `on` key parsing as boolean `True` under PyYAML (harmless here, but worth a test).

8. **Secret-scan exit codes don't fit the "worst code" rule.** The rule assumes 0/1/2, but `scripts/secret-scan.sh` returns gitleaks' raw code: 1 for leaks and also for some gitleaks failures, since it runs under `set -e`. So "couldn't run" can surface as "findings". Decide whether to map the codes in `check-fast.sh`.

9. **Possible scope beyond the ask.** The owner asked for tiers, how new projects pick up the pattern, and "do it all". Several things go further and are worth confirming:
   - A PyYAML-based structural checker.
   - Its integration into `lint.sh` and session start.
   - Hash-pinned PyYAML in CI.
   - The `# tier: slow` marker system.

   Arguably they answer "how new projects pick up the pattern", but they are the bulk of the work. Confirm the owner wants the checker rather than just the template and docs.

10. **The required-check order is risky.** Branch protection's required checks are swapped "just before merging each PR". Open PRs then show `fast`/`slow` as pending forever until they merge `main`. Worth stating, or accept it as known.

11. **Minor:**
   - `tests/lint.test.sh` "covers five checks" is right (four today plus the new one), but its header comment names CI's `lint` job and needs updating; AC-7's doc list doesn't include test comments.
   - `CLAUDE.md`'s pre-push guidance now runs the slow bootstrap test locally, which needs `unshare` and the sysctl.

### Critical Files for Implementation
- <replay>/tiers/specs/ci-fast-slow-tiers.md
- <replay>/tiers/runtime/hooks/session-start.sh
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/tests/bootstrap.test.sh
- <replay>/tiers/scripts/lint.sh
