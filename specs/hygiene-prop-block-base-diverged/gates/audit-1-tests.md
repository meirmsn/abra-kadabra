### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-adversarial-review-narrowing.bats:344-352`
**What**: Test 18 asserts the phantom surface is absent (`assert_failure` on `grep -qF "template/.gitignore"`) and that `NOTE 3` is still present, but does not positively assert that the squash precompute now reports the propagation-surface list as empty for this branch (e.g. `grep -qF "If the list is EMPTY"` as test 16 does, or that the `Propagation-relevant files changed ... empty means none:` block has no entries). The current assertions establish "the phantom is gone" but not "and the list is correctly empty so dimension (d) is N/A for this branch."
**Why**: A future regression that broke the three-dot diff in a *different* way (e.g. emitting a partial/garbled surface list that still happened not to contain the exact string `template/.gitignore`) would slip past — the absence-only assertion is satisfied by any output that omits that one literal. Pairing the negative with a positive "list is empty / dimension d is N/A" assertion would pin the intended end-state, not just the one known phantom path.
**Fix**: After the existing assertions, add a positive check that the surface list is empty for this branch, mirroring test 16, e.g.:
```bats
grep -qiF "If the list is EMPTY" "$CAPTURED_PROMPT"
# and/or assert the precompute reported no surfaces for docs/base-diverged
```
This is optional polish — the test is already a valid regression guard (verified: fails pre-fix with the two-dot diff, passes post-fix with three-dot), so this does not block ship.

---

**Audit summary**: The range is a one-line fix in `kit/scripts/adversarial-review.sh` (dimension (d) `PROP_SURFACES` precompute switched from two-dot `origin/main..$HYG_BRANCH` to three-dot `origin/main...$HYG_BRANCH`) plus one new bats regression test.

- **Section A (coverage)**: PASS. The devshop-side rubric requires `kit/scripts/**.sh` changes to carry matching `.bats` coverage. Test 18 (`dimension d uses three-dot diff — no phantom surface on base-diverged branch`) directly exercises the new code path: it builds a branch whose base fell behind `origin/main` after `origin/main` moved ahead on a propagation-surface file (`template/.gitignore`), then asserts the phantom path does NOT enter the reviewer prompt. This is behavior coverage, not mere file-pairing.
- **Verified the test is a genuine regression guard** (not a tautology): reproduced the two-dot vs three-dot git behavior directly (two-dot reports `README.md` + phantom `template/.gitignore`; three-dot reports only `README.md`), then ran the new test's scenario against a two-dot-reverted copy of the script — the phantom `template/.gitignore` appeared in the captured prompt, which would make `assert_failure` fail (test FAILS pre-fix). Against the shipped three-dot script the phantom is absent (test PASSES post-fix). Full suite: 23/23 pass.
- **Section B (quality)**: Assertions are specific (named phantom path + NOTE 3 presence) rather than weak `toBeTruthy`-style checks. One low-severity completeness note above. No weak assertions, no skipped/`.only` tests, no shape-only-without-render concerns (devshop bats, no DOM surface), no mocked-internals coupling. The mocked `claude` stub is the established pattern in this file and is appropriate (avoids network).
- **Section C (bypass trailers)**: No `Tests-Coverage-Bypass:` trailers in the range. Zero rows — legitimate.

The test adequately covers the change.
