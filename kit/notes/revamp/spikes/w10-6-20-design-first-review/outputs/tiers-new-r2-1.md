Review of specs/ci-fast-slow-tiers.md. These are claims for you to check. I read only files under replay/tiers.

1. **New failure mode that blocks pushes: PyYAML in sessions.** The spec has `scripts/lint.sh` run `ci-tiers-check.py`, and says sessions "use the image's" PyYAML, with a missing PyYAML treated as exit 2. But the pre-push hook runs `lint.sh` and stops the push on any non-zero exit (`runtime/git-hooks/pre-push`). Nothing in `bootstrap.sh`, `runtime/` or `install/` installs or mentions PyYAML. So if the image lacks it, every push in this repo is blocked, and session start prints a `DEVSHOP:` line in every project. Either verify the image has PyYAML and record that as evidence, or install it pinned in bootstrap.

2. **Cause versus symptom; the saving is smaller than claimed.** The real waste today is that CI runs two jobs, `secret-scan` (which also runs `tests/run.sh`) and `lint`, and both install shellcheck and run `npm ci`. Merging those into `fast` fixes that. But adding `slow` brings back a second runner with its own checkout, setup and sysctl. The Decisions text says "one runner's setup instead of two or three", yet you still get two. Worse, `needs: fast` makes the runs serial: wall-clock time becomes fast plus bootstrap test, where today the two jobs run in parallel.

3. **Strongest alternative, not listed: one job with two steps.** A single `ci` job could run `check-fast.sh` and then `check-slow.sh` (the second step is skipped if the first fails). That is one runner, one setup, and the same fail-fast behaviour. Each project still has both scripts, so the owner's concept split survives. The only cost is that branch protection sees one check instead of two. The spec should argue against this option explicitly, because "a skipped required job counts as passed" is also a reason to prefer one job.

4. **Size.** A YAML policy checker, a session-start hook, a marker parser in `tests/run.sh`, a template, docs, and a fixture PR is a lot for a question about duplicated lint. `ci-tiers-check.py` plus running it at session start is the part added beyond what the owner asked. The owner asked how new projects pick up the pattern, and a template plus a line in the `build` skill answers that. Confirm the owner wants the checker, or cut it.

5. **More session-start noise.** The spec only looks for `.github/workflows/ci.yml`. A project with `ci.yaml`, or with its CI under another file name, gets a false "no ci.yml" line every session. Also undefined: what happens when the 30 s limit is hit (is that "couldn't run"?), and whether the line repeats every session with no way to silence it.

6. **The checker can be fooled by an empty base.** It checks that a line starts with `scripts/check-fast.sh "$BASE"`, but not that `BASE` is set in the step or job `env`. If `BASE` is empty, `secret-scan.sh` silently falls back to scanning the whole history. Also unclear is whether `./scripts/check-fast.sh` or `bash scripts/check-fast.sh` count as running the script; as written they would fail. Add both to AC-1 or say how they are handled.

7. **The tool list per job is incomplete.** The spec gives `jq` only to `slow`, but fast tests use jq too: `git-hooks`, `post-edit`, `pre-bash`, `review-guard`, `reviewer`, `ship`. It works only because ubuntu-24.04 ships jq. Say so, or list jq for `fast` as well.

8. **Ambiguous marker rule (AC-4).** "Leading comment block" doesn't say whether a blank line or a `#!`-less file ends it, or whether the match allows trailing whitespace or CRLF line endings. Pin this down in the AC with a test case for each.

9. **The fixture's tier wiring is not specified.** The fixture's `check-fast.sh` runs `tests/run.sh`. Does the fixture's `tests/run.sh` understand `fast` and `slow`, or does it run everything? The rule "a tier with no files fails", combined with the fixture's `check-slow.sh` "says so and exits 0", is consistent only if the fixture's `check-slow.sh` never calls `tests/run.sh slow`. State that.

10. **Exit-code aggregation.** `secret-scan.sh` returns gitleaks' own exit code, which is 1 both for leaks found and for some failures to run. So "worst of 0/1/2" can report "couldn't run" as "findings". This is minor, but it contradicts the stated 0/1/2 contract for `check-fast.sh`.

11. **Rollout order risk.** The owner swaps the required checks "just before merging". Between the swap and the merge, every other open PR has neither `fast` nor `slow`, so all of them are blocked until they merge `main`. The spec states this order, but it doesn't say that open PRs are blocked in the meantime. Say so in the owner's step.

12. **Matches with the codebase.** These literal details in the spec are correct: `lint.sh` aggregates exit codes as described; the hook runs gitleaks plus `lint.sh`; the user-namespace sysctl is needed by `bootstrap`, `git-hooks`, `post-edit` and `pre-bash`; `scripts/setup.sh` exists. AC-6 says "five checks" in `lint.test.sh`, which is consistent with today's four stubbed checks plus `ci-tiers-check.py`.

### Critical Files for Implementation
- <replay>/tiers/specs/ci-fast-slow-tiers.md
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/runtime/git-hooks/pre-push
- <replay>/tiers/scripts/lint.sh
- <replay>/tiers/runtime/hooks/session-start.sh
