1. **The design doesn't save what the owner asked about.** Today CI has two runners: `secret-scan`, which also runs all of `tests/run.sh`, and `lint`. They set up the same tools twice (shellcheck, `npm ci`). The cause of the waste is that duplicated job setup, not lint running in both CI and the hook. The proposal still uses two runners (`fast` + `slow`), and `needs: fast` makes them run one after the other, so wall-clock time per PR goes up. The simplest fix for the waste would be to fold `lint.sh` into the existing job: one runner, no new scripts. Tiering is the owner's explicit wish, so keep it, but the Decisions line "one runner's setup instead of two or three" should state honestly that the runner count stays at 2 and the slow job now waits. Owner question: is serial worth the longer wall-clock here, where the only slow file is `bootstrap.test.sh`?

2. **Size vs problem.** `ci-tiers-check.py` (PyYAML, 10 rules, exit codes, a session-start hook, a 30 s limit) is the largest new piece. The owner asked *how* new projects pick up the pattern, and the template plus a line in the `build` skill answers that. The checker is feedback only (out of scope says no wall), so it adds a lot of code for an advisory signal. Treat it as added scope and ask the owner.

3. **A fast-tier check is stuck in the slow tier.** `tests/bootstrap.test.sh:42-53` checks that `install/tools.pin` matches ci.yml's `*_VERSION`/`*_SHA256` lines. That is a static check, but it lives in the file marked slow, so a pin drift is only caught after `fast` passes. The new `runtime/templates/ci.yml` also pins gitleaks, a third copy nothing checks against `tools.pin`. Move the pin check into a fast test and extend it to cover the template. The spec should also require the pins to stay as top-level `env:` lines, because the grep at line 50 depends on that.

4. **Literal breakages the spec doesn't mention:**
   - `tests/lint.test.sh:46` greps ``run: scripts/lint.sh "$BASE"`` in ci.yml. The new ci.yml won't contain that line, so the test must change. AC-6 only mentions "five checks".
   - `tests/git-hooks.test.sh` around line 68 asserts session start prints nothing (`[ -z "$out" ]`) for a test project that has no ci.yml. The new "no ci.yml" `DEVSHOP:` line breaks that assertion. AC-3 should say the existing cases get a passing ci.yml or that the assertion changes.
   - `runtime/hooks/session-start.sh` has `[ "$cur" = "$hooks" ] && exit 0` partway through. The CI check must run before it, or it silently never runs on a repeat start. The spec should state where it goes.

5. **New failure modes:**
   - This repo's `lint.sh` will run `ci-tiers-check.py`, and the pre-push hook runs `lint.sh`. If an environment lacks PyYAML, exit 2 blocks every push in the devshop repo. "Sessions use the image's" PyYAML is an assumption: it is in this container (6.0.1), but `install/tools.pin` and bootstrap don't guarantee it.
   - A project with no ci.yml gets a `DEVSHOP:` line at every session start, indefinitely. Owner question: is that wanted?

6. **Step detection is loose.** "A line starts with the script's path" accepts `scripts/check-fast.sh "$BASE" || true` and rejects `./scripts/check-fast.sh` or `bash scripts/check-fast.sh`. AC-1 should name the expected result for each, or at least for `|| true` and the `./` form.

7. **Inconsistent "empty" semantics.** `tests/run.sh slow` with no files fails, but a project with no slow tests ships a `check-slow.sh` that exits 0, so the required `slow` check is a green no-op. That's defensible, but the fixture's no-op needs a test, or AC-5 should state the fixture's behavior.

8. **jq ambiguity.** The tool list gives `jq` only to `slow`, yet nine fast test files use jq (git-hooks, post-edit, pre-bash, review-guard, reviewer*, ship). It works only because ubuntu-24.04 ships jq. Either list it for `fast` or say "preinstalled".

9. **Untestable or ambiguous.**
   - AC-7's "a grep for the old job names finds only history" is unreliable: `lint` and `secret-scan` are also script names (`scripts/lint.sh`, `scripts/secret-scan.sh`). Name the exact patterns: `ci / secret-scan`, ``job `lint` ``.
   - AC-1 doesn't say what happens with several jobs, matrix jobs, or a `slow` that runs the script in more than one step.
   - "Exactly one `DEVSHOP:` line about CI" needs a stable prefix to grep for.

10. **Branch-protection ordering risk.** "Swap required checks just before merging" means every other open PR is blocked on `fast`/`slow` until it merges `main`. The ordering text gives no fallback if the owner swaps the checks and the PR then needs more rounds. Ask the owner.

Fixable now: 3, 4, 6, 8, 9. Questions for the owner: 1, 2, 5, 10.

### Critical Files for Implementation
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/tests/bootstrap.test.sh
- <replay>/tiers/tests/lint.test.sh
- <replay>/tiers/runtime/hooks/session-start.sh
- <replay>/tiers/tests/git-hooks.test.sh
