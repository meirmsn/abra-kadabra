1. **The new `DEVSHOP:` lines have to go out through the hook's JSON.** `dispatch.sh` captures `out=$(dispatch)` and wraps it with `jq` into `systemMessage`/`additionalContext`. If the new lines are echoed outside `dispatch()`, they land next to the JSON on stdout. That likely makes Claude Code drop the hook output, so the owner never sees the missing-tool line. The spec should say both new lines go into `$out`. A test should also check that the output still parses as JSON with the new line in `additionalContext`.

2. **Where the PATH line goes is not stated, and three of `dispatch()`'s early exits are untested.** `dispatch()` stops early with `return 0` in four places: a bad pin, a pin not in the local copy, a version with no `runtime/`, and the fall-through after linking. "Outside its version selection" implies the env-file line and the tools check run before or after `dispatch()`, not inside it. The spec should say that outright. AC-2 covers only the pre-move pin and the pin not in the copy. Add the malformed pin (for example `-x`) and the version with no `runtime/`.

3. **Wrong cross-reference.** Decisions say "only AC-6 shows Claude Code doing it on the owner's surface". AC-6 is the priming-run item. The owner's-session item is AC-7.

4. **The dcg exception can't be tested as written.** "dcg is left out … when the existing dcg line … already reports it" depends on three things the dispatcher doesn't know:
   - whether the pinned version's `session-start.sh` has that line (older pins, such as the fixture's `6190c0e0`, may not);
   - whether the script runs at all (it doesn't on an unresolved pin or during priming);
   - whether the plugin's `hooks.json` registers `pre-bash.sh`.

   No AC covers it. Either always name dcg in the new line and accept the duplicate, or give the exact rule plus an AC for each case. This is a question for the owner.

5. **"A missing tool still fails loudly, never pass" only holds when no other copy exists.** AC-3 tests a PATH of system directories with no copy of the tool. If the image has its own `shellcheck` (or anything else on PATH does), a failed pinned install falls through to that unpinned version. The checks would then run against a version CI doesn't use and could pass. The `DEVSHOP:` line still warns, but the check itself won't fail. Ask the owner whether the warning line is enough, or whether a missing pinned tool should hide other copies (for example a stub in `/opt/devshop-tools/bin` that exits non-zero).

6. **AC-4's "its other lines are unchanged" has no baseline.** Unchanged compared with what: the same run with `CLAUDE_ENV_FILE` set, or the dispatcher before this change? Name the comparison.

7. **Reading `tools.pin` can fail, and that case isn't covered.** The dispatcher would run `git show "$(cat default-ref):install/tools.pin"` against the mirror. If `default-ref` is missing, or that ref has no `tools.pin`, nothing is defined: no line, or a false all-clear. Say what happens (one `DEVSHOP:` line saying it couldn't check) and add an AC.

8. **SessionStart fires again on resume, clear and compact.** `hooks.json` has no matcher, so the hook runs on all of them, and each run appends a line to the env file. AC-5 covers two runs. Confirm that this is the intended behaviour and that Claude Code keeps the same `CLAUDE_ENV_FILE` across those events. This is a claim from the experiment, so check it.

9. **Docs scope may be too narrow.** `install/README.md` § "The `DEVSHOP:` line" says the hook "emits one line". After this change it can print up to three (the version line, missing tools, not on PATH). AC-8 names only § Pinned tools. The § Pinned tools text ("where the devshop's hooks run it") also needs the PATH sentence, which AC-8 already covers.

10. **The literal code matches the codebase.** I checked:
    - the `/opt/devshop-tools/bin` path, the 8.30.1 and 0.11.0 versions, and the `/tmp/devshop-setup.log` name;
    - `DEVSHOP_PRIME_ONLY` priming before `install_tools` and without `CLAUDE_ENV_FILE`, so AC-6 is achievable;
    - the dangling link left by a failed re-install (`rm -rf "$dir"` runs before the download);
    - `PRE_MOVE=6190c0e0…`, the scratch `/opt` via `unshare`, and the fake tools in `tests/bootstrap.test.sh`;
    - `tests/pre-bash.test.sh` using `command -v dcg`;
    - the `secret-scan`/`gitleaks`/`shellcheck` scripts and tests looking up tools on PATH;
    - `W10-v2.md` exists.

    The `case` line is POSIX and idempotent. One small point: the decoy in AC-1 must be earlier on the original PATH, not in a directory the test adds afterwards. The wording already implies that.

11. **No scope added beyond the ask.** Exposing dcg goes slightly past "gitleaks/shellcheck". It's justified by `pre-bash.test.sh` and recorded as a decision, so I'm not flagging it. Out of scope is sensible.

12. **AC-7 depends on surface behaviour.** It relies on the owner's surface sourcing `CLAUDE_ENV_FILE` the same way the nested `claude -p` experiment did. That's fine because it's verified by the owner's session. Make sure the owner knows AC-7 is the only item that can catch it if the web or desktop surface behaves differently.
