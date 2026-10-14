Review findings for specs/ci-fast-slow-tiers.md. Treat each one as a claim to check.

1. **The cause is fixed, but the claimed saving isn't stated correctly.** The waste comes from today's `ci.yml`: `secret-scan` and `lint` are two runners that each install shellcheck and run `npm ci`. Merging them into `fast` removes that. But the spec then adds `slow` with `needs: fast`. That makes two runners again, run one after the other, so a green PR now takes longer than it does with today's parallel jobs. The Decisions line "one runner's setup instead of two or three" should say that the saving is the duplicated tool installs, and that the cost is longer time to green.

2. **Strongest option not listed: one job with two steps** (`check-fast.sh "$BASE"`, then `check-slow.sh`). The tiers stay split by concept in the scripts, and the slow step is cut off when the fast one fails. Setup happens once and there is one required check. Adding slow tests later still changes no CI. The spec rejects "tiers in parallel" and "optional slow job", but not this. Ask the owner whether two required checks are worth a second runner.

3. **New failure mode: PyYAML becomes a dependency of every push.** Nothing in the repo uses PyYAML today, and `bootstrap.sh` doesn't install it. "Sessions use the image's" is unverified. Because `scripts/lint.sh` will run `ci-tiers-check.py`, a session without PyYAML gets exit 2 and the pre-push hook stops every push in this repo. Either verify the image has it, or say which setup installs it.

4. **Existing test the spec doesn't account for.** `tests/lint.test.sh:45` greps `ci.yml` for `run: scripts/lint.sh "$BASE"` and says "CI's lint job". Once the `lint` job goes, this assertion fails. AC-6 only mentions "five checks", so this test needs an explicit item: either drop the assertion or replace it with the `check-fast.sh` one.

5. **The template is incomplete for new projects.** `check-fast.sh` "runs the secret scan", but `secret-scan.sh` and `.gitleaks.toml` exist only in this repo and the fixture, not in `runtime/templates`. A new project that starts from `ci.yml` gets gitleaks installed but no script to call it. Either ship a `check-fast.sh`/`check-slow.sh`/secret-scan template too, or say where projects get them.

6. **AC-7 can't be tested as written.** "A grep for the old job names finds only history": the old names `lint` and `secret-scan` are also the live script names (`scripts/lint.sh`, `scripts/secret-scan.sh`), so the grep matches current docs everywhere. Name the exact pattern instead, e.g. `jobs.lint` or "the `lint` job".

7. **The session-start line will nag projects with valid CI forever.** A project whose CI isn't GitHub Actions, or whose workflow is `ci.yaml` or another file name, gets a `DEVSHOP:` line every session with no way to silence it. That noise reaches the owner. Decide whether there is an opt-out, and whether `.yaml` counts.

8. **The rule for what counts as running the script is ambiguous.** "A line of its `run:` starts with the script's path": does `./scripts/check-fast.sh`, `bash scripts/check-fast.sh`, or `"$GITHUB_WORKSPACE"/scripts/...` count? Must the argument be literally `"$BASE"`, and must `BASE` be set in `env:`? AC-1 should fix each of these with a case.

9. **The fixture's slow tier will break later.** The fixture's `check-fast.sh` runs `tests/run.sh`, which is all tests. When slow tests arrive, they will run in `fast`, and `check-slow.sh` will still say there are none. That contradicts "adding slow tests later changes no CI". Should the fixture's `tests/run.sh` get the tier argument too, with `check-fast.sh` calling `tests/run.sh fast` now?

10. **Exit codes for `tests/run.sh` aren't defined.** An unknown argument, or a tier with no files, "fails", but with which code? Under the worst-code rule, 2 ("couldn't run") seems right; today's empty-suite case exits 1. Pin this in AC-4.

11. **Scope added beyond the owner's words.** `ci-tiers-check.py`, the session-start `DEVSHOP:` line and the PyYAML pinning answer "how do new projects pick it up". That's a reasonable reading, but it is the largest part of the change. The owner may have expected only the template plus the `build` skill pointer. Confirm with the owner.

12. **Minor points:**
    - **jq:** it is listed only for `slow`, yet eight test files use it, most of them fast tests (e.g. `reviewer.test.sh`, `ship.test.sh`). It works only because the runner image ships jq. The tools list is wrong, or the image is being relied on without saying so.
    - **Skipped jobs:** "a skipped required job counts as passed" also applies to `slow` when `fast` fails. That's harmless, because `fast` still blocks. Saying so in the spec heads off reviewer confusion.

**Literal code checks:** `scripts/lint.sh`, `secret-scan.sh`, `setup.sh` and the pre-push hook all match the spec's description. The three `unshare` fast tests are `git-hooks`, `post-edit` and `pre-bash` (plus `bootstrap`), which matches.

### Critical Files for Implementation
- <replay>/tiers/specs/ci-fast-slow-tiers.md
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/tests/lint.test.sh
- <replay>/tiers/tests/run.sh
- <replay>/tiers/runtime/hooks/session-start.sh
