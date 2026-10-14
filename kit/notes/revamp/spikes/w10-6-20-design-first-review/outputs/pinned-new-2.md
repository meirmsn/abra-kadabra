Findings on specs/pinned-tools-on-path.md. Treat each one as a claim to verify.

1. **Root cause: the spec has it right, but leaves one option out.** The cause is that the bootstrap puts the pinned tools only in `/opt/devshop-tools/bin`, and the project's scripts look on PATH. Every project script uses `${GITLEAKS:-gitleaks}` / `${SHELLCHECK:-shellcheck}`, and nothing adds that directory to PATH. `runtime/hooks/post-edit.sh:15` already works around this locally with `PATH="/opt/devshop-tools/bin:$PATH"`. A CLAUDE_ENV_FILE line from the dispatcher is a reasonable, proportionate fix. One option is neither listed nor rejected: the bootstrap could append the same idempotent PATH line once to `~/.bashrc` / `~/.profile`. `$HOME` survives the environment cache, since gstack installs there. That needs no runtime hook and no CLAUDE_ENV_FILE, but it depends on Claude Code's shell snapshot reading the rc file. Either reject it in the spec or ask the owner.

2. **The new lines will break existing tests unless the spec says how.** `tests/bootstrap.test.sh:228-229` (`check()`) fails unless there is exactly one `DEVSHOP:` line. The existing dispatcher runs set no CLAUDE_ENV_FILE, and some run with no tools installed. Under AC-4 and the missing-tool rule, both kinds would now print a second line and fail. The spec needs to say whether those cases set CLAUDE_ENV_FILE and install the tools, or whether `check()` changes. The file header and the README section "The `DEVSHOP:` line" both say the hook prints one line, so they need updating too. AC-4's "its other lines are unchanged" doesn't say what they are compared against.

3. **The env-file step needs a defined place in the code.** `dispatch()` returns early in four places: an invalid pin, a pin missing from the local copy, a version with no runtime, and (implicitly) an empty pin. AC-2 covers only the pre-move pin and the pin missing from the copy. The spec should say the step runs outside `dispatch()`, after it, and AC-2 should add the invalid/empty pin and the no-runtime case.

4. **The dcg rule is ambiguous and hard to test.** "dcg is left out when the existing dcg line in session-start.sh already reports it" depends on whether the pinned version's script has that line. The fixture's 6190c0e0 may not. Make the rule concrete. Simplest: the dispatcher drops dcg if its own captured output already contains `dcg is not installed`. Otherwise, always name dcg and accept the duplicate.

5. **Unlisted edge case: the tool list can't be read.** The missing-tool check reads `install/tools.pin` from the mirror at `default-ref`, which can be `HEAD`. If the mirror is missing or the file can't be read, nothing is reported, which is a silent pass. Specify a loud fallback, or have the bootstrap write the expected names into `/opt/devshop-tools`.

6. **The cited proof isn't where the spec says.** Decisions says the CLAUDE_ENV_FILE experiment is "recorded in the LOG entry". LOG #65 (`kit/notes/revamp/LOG.md` from line 2637) only says gitleaks isn't on PATH and "Next: put /opt/devshop-tools/bin on the session's PATH". Nothing about CLAUDE_ENV_FILE is in kit/ or docs/. Either record the experiment or fix the claim. Also, Decisions says "only AC-6 shows Claude Code doing it", but that is AC-7 (AC-6 is the priming run). Fix that number.

7. **New failure modes.**
   - Claude Code sources the env file before every Bash command, so a malformed line would break every command. The quoting and a test that sources the file under `bash -n` / `set -u` matter.
   - Prepending changes which shellcheck the session runs. The image's copy apparently satisfied the fixture: only gitleaks failed, in 2 of 9 files. So the session's lint results may change. That is intended, but say so.
   - The spec doesn't say what happens if the env file can't be written. "Never fails the session" implies a `DEVSHOP:` line.
   - Append (`>>`), never truncate, because other hooks may write to the same file.

8. **AC-3 detail.** A dangling link really does happen: the bootstrap runs `rm -rf "$dir"` and then the download fails, leaving the old `bin/<name>` link pointing at nothing. So `-x` is the right test. "A PATH of only system directories with no copy of it" can't be guaranteed on a runner whose `/usr/bin` has shellcheck. Use a scratch directory as the system PATH in the test.

9. **Scope.** Exposing dcg on PATH is justified by `tests/pre-bash.test.sh:13`, but that serves only this repo, not the fixture. That's fine, but it is added scope. AC-8's W10 task line also adds scope, but it is consistent with the repo's practice.

10. **The literal code matches the codebase:** paths, `DEVSHOP_PRIME_ONLY`, the priming run happening before the tool install (`install/bootstrap.sh:37` vs `:64`), the `PRE_MOVE` SHA, the `/tmp/devshop-setup.log` name, and the `tests/gitleaks.test.sh` "not found" message. The fixture's pinned versions (8.30.1, 0.11.0) match `install/tools.pin`.

### Critical Files for Implementation
- `<replay>/pinned/install/plugin/devshop/hooks/dispatch.sh`
- `<replay>/pinned/tests/bootstrap.test.sh`
- `<replay>/pinned/install/bootstrap.sh`
- `<replay>/pinned/runtime/hooks/session-start.sh`
- `<replay>/pinned/install/README.md`
