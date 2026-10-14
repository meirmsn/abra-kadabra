Findings, most important first. Treat each one as a claim to check.

1. **Intent mismatch on "integration".** The owner drew the line at "unit tests vs integration/e2e tests", so integration tests go to slow. The spec's fast tier also takes tests run "against local stubs, emulators or sandboxes", and its slow tier is only "end to end". Integration tests against a local DB emulator, which is the usual case for the Workers + D1 fixture, would land in fast. That redefines the owner's line. Ask the owner whether integration-against-emulators is fast or slow.

2. **"Go: pending" conflicts with "Changed after the go (owner, 2026-10-13, 'option 1')".** One of the two is wrong. A reviewer can't tell whether this spec is approved.

3. **AC-7's check doesn't work as written.** "A grep for the old job names finds only history" fails because `lint` and `secret-scan` are also the names of the scripts that stay (`scripts/lint.sh`, `scripts/secret-scan.sh`). Every doc will match. Name a pattern that can tell them apart (e.g. "the `lint` job", "`secret-scan` job") or drop the grep.

4. **Tool lists don't match the code.**
   - `jq` is listed only for `slow`. But `tests/git-hooks.test.sh`, `post-edit`, `pre-bash`, `review-guard`, `reviewer*` and `ship.test.sh` all use jq, and they are fast. It works only because ubuntu-24.04 ships jq. Either list it for both jobs or for neither.
   - AC-6 says "with the tools listed above … shown by `tests/run.sh`", but no test checks which tools each job gets. As written, that part can't be tested.

5. **PyYAML failure mode in sessions.** `scripts/lint.sh` will now run `ci-tiers-check.py`, and the pre-push hook runs `lint.sh`. If the session image lacks PyYAML, the check exits 2 and every push is blocked. "Sessions use the image's" is an unverified assumption. Nothing in the repo shows PyYAML in the image, and `scripts/setup.sh` only runs `npm ci`. Two more gaps:
   - `lint.sh`'s `check` resolves names under `scripts/`, while the checker lives in `runtime/scripts/`. The spec should say how `lint.sh` calls it.
   - AC-6's "five checks" means `tests/lint.test.sh` (currently hard-coded to 4) needs updating. Fine, but say so.

6. **AC-1 misses cases that silently break branch protection or tiering:**
   - A job-level `name:` on `fast`/`slow`, or a `matrix`, changes the required check's name.
   - A workflow that doesn't trigger on `pull_request`.
   - `BASE` never defined, so `check-fast.sh ""` scans all history.
   - The script invoked as `./scripts/...` or `bash scripts/...`. "A line starts with the script's path" makes these false failures, and leading whitespace in `run: |` is unspecified.
   - `needs: fast` on `fast` itself, or `slow` sitting in a different workflow file.

7. **Empty base is undefined.** AC-5 / `check-fast.sh <base>` don't say what happens with an empty or all-zeros base (new branch, first push). `secret-scan.sh` handles it, but say that `check-fast.sh` passes it through unchanged.

8. **AC-3 gaps.** The 30 s timeout case isn't listed as "couldn't run", and nothing tests it. AC-3 places the test in `tests/git-hooks.test.sh`. Session-start is currently tested there and in `bootstrap.test.sh`, which is now slow. Make sure the new cases live in the fast one.

9. **The "saving" rationale doesn't hold for this repo.** Today there are two runners (`secret-scan`, `lint`). After the change there are still two (`fast`, `slow`), each doing checkout, full history and the sysctl. The saving is real only for the fixture (three to two). Reword, or the owner may expect a cost cut here that doesn't happen.

10. **The `needs: fast` reasoning.** When `fast` fails, `slow` is skipped, and a skipped required job reports success. This is safe only because `fast` is required too. State that dependency, so nobody later makes only `slow` required.

11. **Scope added beyond the ask:**
    - `ci-tiers-check.py` with PyYAML, its session-start `DEVSHOP:` line and the 30 s limit. The owner asked "how do new projects pick up the pattern", which the template plus the `build` skill note arguably answer.
    - The fixture's new `scripts/lint.sh` and `scripts/setup.sh`. The owner said to "move existing checks", not add a hook lint to the fixture.
    
    Confirm with the owner, or mark them as decisions they made.

12. **Literal code checks out:**
    - Existing job names `secret-scan`/`lint`, `scripts/lint.sh`'s 0/1/2 convention and the pre-push behaviour match the spec.
    - Exactly three fast tests use `unshare` (`git-hooks`, `post-edit`, `pre-bash`).
    - `bootstrap.test.sh` does replay the install.
    
    One constraint the spec omits: `bootstrap.test.sh` greps `ci.yml` for top-level `  GITLEAKS_VERSION:` / `_SHA256:` lines (shellcheck and dcg too). The restructured `ci.yml` must keep those pins in the workflow-level `env:`.

13. **Minor:**
    - The `# tier: slow` marker isn't defined for CRLF files or for test files with no shebang.
    - "A tier with no files fails" means a project whose `check-slow.sh` calls `tests/run.sh slow` before it has slow tests would fail. Only this repo uses `run.sh` tiers, so that's fine, but the template's comment should not tell projects to do it.

### Critical Files for Implementation
- <replay>/tiers/specs/ci-fast-slow-tiers.md
- <replay>/tiers/.github/workflows/ci.yml
- <replay>/tiers/scripts/lint.sh
- <replay>/tiers/tests/run.sh
- <replay>/tiers/runtime/hooks/session-start.sh
