# Flaky tests

Read when CI fails on a test the change doesn't touch
([spec](../../specs/shared-changes-first.md)). Once, the fix for a flaky test sat in a branch near
the end of the merge queue while the flake failed CI on at least three other PRs, and two more
flakes stayed unfixed. In the same project, seven flakes were then fixed at their cause, with no
re-run, and each stayed fixed. This guideline is how.

## Never re-run to get green

- **An unrelated failure** is a test that fails on a change that touches neither it nor what it
  tests, on the change's PR or on `main`.
- **It is never re-run to get green, not even once.** A pass on a re-run says nothing about the
  cause, and the flake comes back on the next PR.
- **One sighting is enough.** Reproduce the failure on `main`'s code and find its cause (below).
  With the cause shown, propose a fix PR to the owner; on a yes, open it as a shared change
  ([parallel.md](parallel.md#shared-changes-go-first-in-their-own-pr)): its own branch from a
  freshly fetched `main`, a bug fix whose failing check is the spec, and a PR that asks to merge
  first.
- **Until the fix merges,** the failure is a row in `FINDINGS.md`, or a sighting on its row,
  logged in the records-only commit (`ak:pr` § 3).
- **A cause you can't reproduce** after the steps below goes to the owner with what was tried.
  Still no re-run.

## Find the cause

1. **Tell load from logic.** Run the test alone, then under load: several suites at once, busy CPU
   loops beside it, a throttled CPU.
2. **Measure the raw values** the test asserts on, not only pass or fail. A value that moves with
   load measures the machine, not the code.
3. **Make the failure deterministic.** Seed the random source, set the state at a boundary,
   simulate the arithmetic, slow the frames. A failure that happens every time can be fixed and
   proven.
4. **The fix's first check is the old test failing under that cause,** then the new test passing
   under it.
5. **A mutation check:** the fixed test still fails when the behaviour it protects is broken. A
   test made to pass by asserting less is not a fix.
6. **Probes that proved the cause become committed tests,** not local runs only.

## Where to look first

These are the causes found so far:

- a fixed wait (`waitForTimeout`, `sleep`) instead of waiting on a state;
- time in the code advancing before the test takes control of the clock;
- state read before the frame or tick that updates it has run;
- a single pixel or instant sampled, where something passing through can change it;
- a wall-clock duration asserted, which measures the scheduler on a busy runner;
- a floating-point step that lands just under a boundary;
- a timer in the code that the test's clock doesn't control;
- a port, file or other resource shared by tests that run at once.

## The fix

- **Take the cause out of the test:** wait on a state, not a time; take the clock or the
  randomness under the test's control; sample an area, not one pixel or instant.
- **Or change the code so it can be tested reliably:** a clock, a seed or a manual-step switch the
  test can set. A code change is a real choice, so the fix then gets its own spec and the owner's
  go.
- **Never:** retries or repeated samples, a looser limit for CI only, a skip or a quarantine, or
  "passed N times" offered as proof.
