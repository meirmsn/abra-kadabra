Findings on specs/ci-fast-slow-tiers.md. Each one is a claim for you to check. I read only files under the tiers directory.

1. **The session-start check can be skipped.** `runtime/hooks/session-start.sh` exits early with `[ "$cur" = "$hooks" ] && exit 0` once core.hooksPath is set, which is every session after the first. If the CI check goes after that line, AC-3 holds in the test's first run but stops working in real later sessions. The spec should say where the check runs, and AC-3 should test a second session start.

2. **PyYAML can block every push.** No file in the repo uses PyYAML, so "sessions use the image's" copy is not backed by anything here. The spec makes `scripts/lint.sh` run `ci-tiers-check.py`, and a missing PyYAML gives exit 2. The pre-push hook treats exit 2 from lint.sh as "push stopped". So an image without PyYAML would block every push in this repo, not just give feedback. Either confirm the image has PyYAML (and say how) or decide how lint.sh should treat that case. This is a question for the owner.

3. **The tool list per job doesn't match the tests.** The spec gives `jq` only to `slow`, but fast tests use jq too: git-hooks, post-edit, pre-bash, review-guard, reviewer and ship. It works today only because ubuntu-24.04 ships jq. Also, `tests/bootstrap.test.sh` (slow) greps ci.yml for top-level `^  GITLEAKS_VERSION:` / `_SHA256:` lines (and the same for shellcheck and dcg), so the new ci.yml must keep those pins in the workflow-level `env:`. The spec doesn't say so.

4. **New projects get no scripts to start from.** The template calls `scripts/check-fast.sh "$BASE"` and `scripts/check-slow.sh`, but the spec ships no template for either script. The template also installs gitleaks while the spec says nothing about where a new project's secret scan comes from (this repo has `scripts/secret-scan.sh`). Nor does it say which gitleaks pin the template carries, or what keeps that pin in line with `install/tools.pin`. For the owner's "how do new projects pick it up", the template alone falls short.

5. **The checker's "starts with the path" rule has holes.**
   - `scripts/check-fast.sh "$BASE" || true` passes but swallows the result. AC-1 should reject that, or the spec should state it is accepted.
   - Nothing checks that `BASE` is set; an unset BASE quietly scans the whole history or does nothing.
   - `./scripts/...`, `bash scripts/...` and multi-line `run: |` blocks are not specified.
   - "Naming the rule" needs a fixed message per rule so the test can assert it.

6. **Parts of AC-6 and AC-7 can't be tested as written.**
   - AC-6: "with the tools listed above … shown by `tests/run.sh`" has no mechanism behind it. Either name what a test asserts or move the tool list out of the acceptance item.
   - AC-7: "a grep for the old job names finds only history" does not work for `lint`, which matches `lint.sh` everywhere. Name the patterns, e.g. ``job `lint` `` and `ci / secret-scan`. The latter is at `install/README.md:78`, and the other is at `docs/README.md:22`.
   - AC-7 also checks only this repo's docs. The fixture's docs fall to the owner's merge check, which matches the "option 1" note.

7. **Some decisions lack the owner's attribution.**
   - `needs: fast` (tiers run one after the other), the single template, and the CI checker plus `DEVSHOP:` line carry dates but no "owner".
   - The checker, its session-start hook-in and AC-1's long list of rules go beyond "how new projects pick up the pattern". Confirm with the owner that this extra scope is wanted.
   - Running the tiers in sequence adds the fast job's time to every PR's slow result.

8. **Requiring deploys to need both jobs is redundant.** Since `slow` already needs `fast`, `needs: slow` alone already implies `fast`. The rule forcing both is harmless but stricter than it needs to be. Say that it's deliberate.

9. **The fixture can't be checked here.** It is not in this tree, so I couldn't verify its `npm test`, schema check, existing `tests/run.sh` or `deploy` job. The spec has its `check-fast.sh` run `tests/run.sh`. If the fixture adopts the tiered run.sh, `tests/run.sh fast` and `slow` would fail on a tier with no files. State that the fixture keeps the untiered run.sh, and how it adds slow tests later.

10. **Smaller points.**
    - "Every part runs even after one fails" plus "worst code" needs a rule for exit codes other than 0, 1 or 2. `secret-scan.sh` passes gitleaks' own exit codes through, and lint.sh maps anything above 1 to 2. Say check-fast.sh does the same.
    - For the session-start check's 30 s limit, say what a timeout prints (presumably the "couldn't run" line).
    - AC-3 lives in `tests/git-hooks.test.sh`, which is fine since it already exercises session-start, but that file's header comment will need updating.

### Critical Files for Implementation
- <replay>/tiers/specs/ci-fast-slow-tiers.md
- <replay>/tiers/runtime/hooks/session-start.sh
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/runtime/git-hooks/pre-push
- <replay>/tiers/tests/bootstrap.test.sh
