1. **Possible push blocker: PyYAML in sessions isn't confirmed.** The spec has `scripts/lint.sh` run `ci-tiers-check.py`, which needs PyYAML. It says "sessions use the image's" copy, but nothing under `bootstrap.sh`, `install/` or `CLAUDE.md` installs PyYAML or mentions it. The pre-push hook runs `lint.sh`, and when PyYAML is missing the check exits 2 ("couldn't run"), so every push from a session would stop. The same gap would print the CI `DEVSHOP:` line at every session start. The spec should either say where the image gets PyYAML (and test for it), or keep the check out of the hook's lint.

2. **Cause vs. symptom, and a smaller option nobody listed.** The owner's question was about waste. In the current `ci.yml`, the waste is that the `secret-scan` job (which also runs every test) and the `lint` job each set up a runner and both install shellcheck and run `npm ci`. Merging `lint` into the existing job fixes that in a few lines. The tier design goes well beyond the question: a new checker, a template, a session-start check, test markers and a fixture retrofit. The owner did say "do it all", so the size is authorised. Still, the spec should say plainly that the waste is fixed by merging jobs and the tiers are a separate goal. As specced, the slow job still pays for a second checkout with full history, the sysctl and its setup, so the saving is smaller than the first decision implies.

3. **The spec's literal design doesn't match `lint.sh`.** `lint.sh`'s `check()` runs `"$here/$name"`, which only reaches files in `scripts/`. `ci-tiers-check.py` lives in `runtime/scripts/`. The spec needs either a wrapper in `scripts/` or a change to `check()`. `tests/lint.test.sh` stubs its checks by name (`checks=(...)`, 4 entries, `wc -l = 4`), so the spec should say how the fifth check, which lives elsewhere, gets stubbed.

4. **`tests/bootstrap.test.sh` mixes both tiers.** Lines 41-53 check that `install/tools.pin` matches the `*_VERSION`/`*_SHA256` env lines in `ci.yml`. That is a static check, fast by the spec's own rule, but it sits in the file being marked slow. Two consequences:
   - Pin drift would only be caught after `fast` passes.
   - The rewritten `ci.yml` must keep those top-level env lines with exactly two-space indent, or the slow tier fails. The spec says neither. Suggest moving the pin check into a fast test.

5. **Exit codes are inconsistent.** Each script must exit 0, 1 or 2 by the worst part. But `tests/run.sh` exits 1 for "no tests found" (by that convention it's "couldn't run", so 2), and the spec says a tier with no files "fails like an empty suite does". `secret-scan.sh` passes gitleaks' own exit code straight through, so it may not be 1 on findings. The spec should say how `check-fast.sh` maps each part's exit code.

6. **The `DEVSHOP:` CI line needs more definition, and may nag.**
   - "Exactly one line" when several rules fail: does it name the first rule or all of them?
   - It isn't defined whether the 30 s limit counts as "couldn't run".
   - Projects whose CI isn't GitHub Actions, or whose workflow isn't named `ci.yml`, would get the warning every session with no way to silence it. That noise is a new failure mode.

7. **AC-1's `"$BASE"` rule is ambiguous.** "Line starts with the script's path" doesn't say whether the argument `"$BASE"` is required, or whether `BASE` must be set to `pull_request.base.sha || event.before`. A `fast` job with no `BASE` env would pass the check while the commit-identity and secret scans fall back to the whole history (or fail). Add a test case for each.

8. **AC-6 can't be tested as written.** "With the tools listed above, shown by `tests/run.sh`": no test is named that checks which tools each job has. Either name the test (for example a step-name grep) or move that part to review.

9. **This repo's `ci.yml` won't match the template.** The template's `slow` "does the same setup" (`setup.sh`, gitleaks), but here `slow` gets only the sysctl, full history and `jq`. The spec should say a project may drop setup the slow tier doesn't need, or new projects will copy work they don't need.

10. **Edge cases to state.**
   - `tests/reviewer-live.sh` isn't a `*.test.sh`, so it belongs to neither tier; the docs should say so.
   - A `# tier: slow` marker with trailing spaces or CRLF line endings: is it accepted?
   - Do workflows that skip `fast` on docs-only changes (path filters) count as violating the "no `if:`" rule? The skip happens at workflow level, not job level.

11. **Process risk.** Branch protection: if the owner swaps the required checks before `main` has the `fast` and `slow` jobs, every other open PR is blocked on checks that never report. The spec's order covers this, but only as prose. A pre-merge checklist line in the PR would make it harder to miss.

12. **Scope added beyond the owner's words.** The session-start check, the `ci-tiers-check.py` checker and its rule list, and the deploy-`needs` rule were not asked for, though they arguably answer "how do new projects pick up the pattern". Worth confirming with the owner that they want the checker and not just the template plus a note in the `build` skill.

Files involved (all under `<replay>/tiers/`):
- `specs/ci-fast-slow-tiers.md`
- `scripts/lint.sh`
- `tests/lint.test.sh`
- `tests/bootstrap.test.sh`
- `tests/run.sh`
- `runtime/hooks/session-start.sh`
- `.github/workflows/ci.yml`
