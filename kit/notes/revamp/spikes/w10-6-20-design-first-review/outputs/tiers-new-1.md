1. **Existing tests break, and the spec doesn't say how they change.** `tests/git-hooks.test.sh` (around line 66) checks that session start prints nothing (`[ -z "$out" ]`) in a temp project that has no `ci.yml`. Under AC-3 that project would now print a `DEVSHOP:` line about CI. `tests/bootstrap.test.sh` (`check`, around lines 223-228) expects exactly one `DEVSHOP:` line per case after running the real SessionStart in fixture projects that also have no `ci.yml`. The spec needs to say whether those test projects get a passing `ci.yml` or the assertions change.

2. **PyYAML in sessions is assumed, not shown.** "Sessions use the image's" PyYAML: nothing in `install/` or `scripts/setup.sh` installs it or proves it is there. If it's missing:
   - Session start prints a "couldn't run" line in every project, every session.
   - Worse, `scripts/lint.sh` would run `ci-tiers-check.py`, exit 2, and the pre-push hook would block every push from a session in this repo.

   Either confirm the image has it and add a check for that, or don't parse YAML at all. A line-based check is enough for these rules.

3. **Size versus the problem.** The owner's root question was wasted duplicate CI setup. The direct cause here is that `lint` and `secret-scan` each install shellcheck and run `npm ci` separately. Merging those two jobs into one fixes that. The two tiers are the owner's explicit ask, so they stay. What goes beyond the owner's words is `ci-tiers-check.py` plus a session-start nag in every project. The owner asked "how do new projects pick up the pattern"; the template plus a line in the `build` skill answers that. The checker brings a new dependency (PyYAML), a 30 s step at session start, findings 1 and 2, and a permanent line in projects that deliberately have no `ci.yml` (no opt-out is defined). Ask the owner whether the checker belongs in this change.

4. **The checker can be fooled.** AC-1's rule, "a line of `run:` starts with the script's path", accepts `scripts/check-fast.sh "$BASE" || true`, so the tier can never fail. It also leaves these undefined:
   - `./scripts/...` or `bash scripts/...`
   - leading whitespace
   - `"$BASE"` replaced by another argument
   - the step not setting `BASE` at all

   AC-1 tests none of these.

5. **The fixture can't be checked against its literal code.** It isn't in this tree, so none of its claims could be verified: its `tests/run.sh` existing or supporting tiers, `npm test`, the "schema check", the `deploy` job, PR #11. "A tier with no files fails" (AC-4) conflicts with a `check-slow.sh` that exits 0 when there are no slow tests. That only works if it doesn't call `tests/run.sh slow`; say so explicitly.

6. **jq is listed inconsistently.** Only `slow` "gets jq", but `git-hooks`, `post-edit`, `pre-bash`, `review-guard`, `reviewer*` and `ship` tests (all fast) use jq too. It is preinstalled on ubuntu-24.04 and today's CI never installs it. Either drop jq from the list or list it for both jobs. As written, "with the tools listed above" in AC-6 can't be tested.

7. **Hidden coupling with the slow test.** `tests/bootstrap.test.sh` lines 43-51 grep `ci.yml` for top-level `GITLEAKS_/SHELLCHECK_/DCG_VERSION` and `_SHA256` env lines. Restructuring `ci.yml` must keep those top-level env keys even though `slow` doesn't install the tools. The spec doesn't mention this.

8. **AC-6's "five checks" undercounts.** Today `lint.sh` has four checks (format, shellcheck, docs map, commit identity), so adding the CI check makes five. But `tests/lint.test.sh` copies only `lint.sh` and stubs the checks. The new check lives in `runtime/scripts/` and needs the workflow path as its argument. The spec should say how `lint.sh` calls it (path, argument) and that the stub list grows.

9. **Exit codes in `check-fast.sh`.** `secret-scan.sh` passes on gitleaks' raw exit code, and gitleaks' generic error is also 1, so "couldn't run" would be counted as findings. That doesn't affect pass/fail, but it doesn't match the stated 0/1/2 contract.

10. **Ambiguous details:**
    - The `# tier: slow` marker rule ("leading comment block after the shebang") doesn't say whether blank lines end the block.
    - The session-start 30 s limit has no test. AC-3 doesn't say what happens on timeout; presumably "couldn't run".
    - Running the session-start check in the devshop repo itself duplicates the lint run. Harmless, but undecided.

11. **The `needs: fast` reasoning is sound.** When `fast` fails, `slow` is skipped, but `fast` still blocks the merge. The "no job-level `if`" rule is the right guard.

12. **Scope check:** AC-7 adds the `build` skill and the workstream line, which fits "new projects pick up the pattern". The old item 7/8 move to the owner's merge checks is recorded consistently.

### Critical Files for Implementation
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/runtime/hooks/session-start.sh
- <replay>/tiers/tests/git-hooks.test.sh
- <replay>/tiers/tests/bootstrap.test.sh
- <replay>/tiers/scripts/lint.sh
