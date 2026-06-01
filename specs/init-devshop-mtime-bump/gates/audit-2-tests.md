findings: high=0 medium=0 low=2

### [domain: tests] [section: B] [severity: low]

**File**: kit/tests/manifest-lifecycle.bats:501-550 (all three new tests)
**What**: All three new regression tests are static `grep` pins on guard text (`cmp -s "$src" "$dst"`, `stat -c '%U:%G %a'`, and the content-match re-lock line), not behavioral exercises of init-devshop.sh. They are revert-detectors: they fail if the guard literal is removed, but a logic-preserving refactor (e.g. inverting the `cmp -s` sense, or moving the stat guard onto the wrong write) leaves the literals intact and the tests green. (Carried forward from Audit 1 [medium]; now downgraded to low/accepted.)
**Why**: A behavioral test would need root + chown + a live container boot, which unprivileged bats cannot cleanly do — so a true "mtime-preserved-on-content-match / tuple-recovered-on-drift" assertion is not feasible in this suite. The static-pin ceiling is "revert-detector," not "behavior-verifier."
**Fix**: None required — accepted tradeoff, now explicitly acknowledged in the test comments ("A revert that drops the guard regresses the bug SILENTLY (only visible by rebuilding a container), so pin the guard statically here"). Consistent with this file's existing structural-assertion style. Downgraded from Audit-1 medium to low because the comment honesty + the BUILD-LOG record close the "assumed-away" gap the medium flagged.

### [domain: tests] [section: B] [severity: low]

**File**: kit/tests/manifest-lifecycle.bats:514
**What**: The cmp -s pin regex `'cmp -s "\$src" "\$dst"'` is tightly coupled to the exact variable names `$src`/`$dst`. A benign rename during future refactoring (e.g. `$source`/`$target`) would silently break the pin (false-fail on a correct script). (Carried forward from Audit 1 [low].)
**Why**: Minor maintenance brittleness — a false-fail, not a missed bug. The variables are stable and the test comment explains intent.
**Fix**: Acceptable as-is; noted as a footgun. A looser anchor (e.g. `! cmp -s`) would reduce coupling if the names ever churn.

### Resolved-since-Audit-1 (not findings — verified fixed + mutation-checked at HEAD)

- [was medium, Audit 1 @ bats:533] The content-match re-lock branch was not independently pinned — the generic stat-tuple grep matched all six lock sites and stayed green even if the content-match re-lock were dropped. FIXED in 8f557b2: new Test 6 (bats:548) uses `grep -qF 'chown root:root "$dst" && chmod "$src_mode" "$dst"'`. Verified at HEAD that `chmod "$src_mode" "$dst"` is unique to the content-match else-branch (line 209; every other lock site uses literal `chmod 644`). Mutation-checked: removing the re-lock line makes Test 6's grep exit nonzero → test fails on revert. Genuine revert-detector for the load-bearing security re-lock. RESOLVED.

### Coverage (Section A)

- New behavior in kit/scripts/init-devshop.sh (cmp -s content gate + stat-tuple idempotent locks + content-match security re-lock) → matched by 3 new tests in kit/tests/manifest-lifecycle.bats. Devshop rubric (new/changed kit/scripts/\*\*.sh → matching .bats spec) satisfied. All 6 init-devshop tests pass green (verified via vendored bats: ok 1-6).

### Skipped-tests audit

- The three `[ -f "$script" ] || skip "init-devshop.sh not found"` lines are file-existence guard skips, not coverage-hiding skips — the script always exists in-tree, so the skip never fires. Not the test.skip(true)/.only antipattern. No `.only`, no hard skips, no conditional skips that run nowhere. Clean.

### Bypass trailer audit

- No Tests-Coverage-Bypass trailers in range.
