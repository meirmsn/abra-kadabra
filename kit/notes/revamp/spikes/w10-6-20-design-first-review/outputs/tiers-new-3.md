Findings on specs/ci-fast-slow-tiers.md, most important first. All paths are under the `tiers/` project root.

1. **Root cause, and whether the size fits.** The waste the owner asked about is in today's `ci.yml`: two jobs each do a checkout, install shellcheck and run `npm ci`, and the job named `secret-scan` also runs the whole test suite. Merging them into one job would remove the duplication. The two tiers are the owner's own idea and are justified. What isn't proportionate is the extra machinery:
   - `ci-tiers-check.py`, which adds a new third-party dependency (PyYAML);
   - its run at session start;
   - its run in `lint.sh`.
   No Python file in the repo imports anything outside the standard library today. A test on the template (AC-2) plus this repo's own `ci.yml` covers most of the risk. The spec should say why each place the checker runs is worth its cost. The cheapest cut is dropping the session-start run (AC-3).

2. **New failure mode: pushes from a session blocked by PyYAML.** `runtime/git-hooks/pre-push` runs `scripts/lint.sh`, and AC-6 adds the checker to `lint.sh`. If PyYAML is missing it exits 2 by design, so every push from a session is stopped. "Sessions use the image's" PyYAML is not checked anywhere: `install/tools.pin` and `bootstrap.sh` never install it. Either confirm the image has it and add a test, or install it pinned the way gitleaks is.

3. **Missing artifact for "hash-pinned" PyYAML.** There is no requirements or lock file, and the spec doesn't name one. It should name the file and the install step (`pip install --require-hashes -r ...`).

4. **The session-start check would be skipped in most sessions.** `runtime/hooks/session-start.sh` exits early with `[ "$cur" = "$hooks" ] && exit 0` once `core.hooksPath` is already set. It also exits early outside a git repo. AC-3 has to say the CI check runs before those exits, and the test should cover a session where hooks were already set.

5. **The literal code doesn't match `lint.sh`.** The `check()` helper in `scripts/lint.sh` only runs `"$here/$name"`, a file in `scripts/`, with the given arguments. The checker lives in `runtime/scripts/` and needs `.github/workflows/ci.yml` as its argument. The spec should say how it is called: a wrapper in `scripts/`, or a change to `check()`.

6. **Existing tests the spec doesn't mention will break.**
   - `tests/lint.test.sh:46` greps `ci.yml` for `run: scripts/lint.sh "$BASE"`, which disappears.
   - The stubbed checks list in `lint.test.sh` needs the fifth check.
   - `tests/bootstrap.test.sh:44-51` greps `ci.yml` for the top-level `GITLEAKS_VERSION`/`_SHA256` lines. The new layout has to keep those env names at the same indentation.
   - The pin-vs-`ci.yml` comparison is a static check, but because tiers are chosen per file it now runs only in the slow tier.

7. **New projects get no template for the scripts themselves.** The template covers `ci.yml` only. A new project still has to write `check-fast.sh`, `check-slow.sh` and `secret-scan.sh` by hand, and the template's `fast` job calls them. Answering "how do new projects pick up the pattern" needs templates for those scripts too, or the build skill has to say what goes in them.

8. **The 0/1/2 exit rule doesn't hold for the secret scan.** `scripts/secret-scan.sh` runs gitleaks under `set -e`. gitleaks exits 1 both for leaks and for many internal errors, so "couldn't run" comes out as "findings". This is minor, but the spec claims every part follows the rule.

9. **The checker's matching rule is ambiguous or too loose.**
   - "A line of `run:` starts with the script's path" rejects `./scripts/check-fast.sh` and `bash scripts/check-fast.sh`.
   - It accepts `scripts/check-fast.sh "$BASE" || true`, which silently skips the tier.
   - It doesn't check that `BASE` is defined. With an empty `BASE`, the secret scan and identity check run over all history and still pass.
   - It doesn't say whether the `if:` rules also cover `slow`'s `needs` being made conditional.
   Each needs a decision and an AC-1 case.

10. **Gaps in AC-3.** It doesn't say what happens when the 30 s limit is hit; that should count as "couldn't run" and be tested. "Exactly one line" needs a case where the project setup also fails, so two `DEVSHOP:` lines appear. And a project with no CI on purpose gets the nag every session.

11. **Unspecified edge cases in AC-4.** The spec doesn't define:
    - a file with no leading comment block;
    - `#tier: slow` with no space, or trailing whitespace;
    - more than one argument.
    "An unknown argument fails" also needs an exit code.

12. **Small extra cost.** Slow `needs: fast` makes the bootstrap test run after the fast job instead of alongside it. That is accepted, but CI wall time per PR now grows; the spec should state it.

13. **Possible scope additions.** Each item below is beyond what the owner asked for. Ask the owner rather than cutting:
    - running the checker at session start;
    - the `build` skill wording;
    - the "deploy needs both" rule (no deploy job exists in this repo).

14. **AC-7 is hard to test.** "A grep for the old job names finds only history" is unreliable: `lint` and `secret-scan` are also script and test names. Give the exact patterns, e.g. `ci / lint` and `ci / secret-scan`, plus "job `lint`".

### Critical files
- `.github/workflows/ci.yml`
- `scripts/lint.sh`
- `runtime/hooks/session-start.sh`
- `runtime/git-hooks/pre-push`
- `tests/lint.test.sh` (with `tests/bootstrap.test.sh` and `tests/run.sh`)
