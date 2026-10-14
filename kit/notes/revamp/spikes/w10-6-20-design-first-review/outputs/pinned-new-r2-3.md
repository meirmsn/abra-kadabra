Review of specs/pinned-tools-on-path.md. Treat these as claims to check, not settled facts.

1. **Wrong AC cross-reference (sure, fix it).** The first Decision says "only AC-6 shows Claude Code doing it on the owner's surface". The owner's-session check is AC-7. AC-6 is the priming-log item.

2. **The dcg dedup can't be built or tested as written.** "dcg is left out of that line when the existing dcg line in `runtime/hooks/session-start.sh` already reports it" makes the dispatcher guess what a version's script printed. That line (session-start.sh:13-16) only exists in some versions. It only fires when the plugin's hooks.json registers pre-bash.sh. The script doesn't run at all when the pin fails to resolve (the dispatcher returns early at dispatch.sh lines ~46, 52, 62). So for the fixture's old pin, or a pin that doesn't resolve, it's unclear whether dcg gets named. Suggestion: always name dcg (a repeated line costs little), or check `$out` after the version's script has run. Ask the owner which.

3. **Where the new code goes in dispatch.sh.** `dispatch()` returns early in three places before the version's script runs. The env-file write and the tools check have to sit outside `dispatch()`, or before those returns, or AC-2 fails. The spec says "outside its version selection" but doesn't say where. Name the spot. Their lines also have to go into `$out` so they reach the JSON that is shown to the owner.

4. **Root cause, and an option the spec never lists.** The cause is real: two lookup rules exist side by side. The devshop's hooks use absolute paths (pre-push:12, pre-bash.sh:8), and post-edit.sh:15 already does `PATH="/opt/devshop-tools/bin:$PATH"` for each call. The project's scripts look on bare PATH (secret-scan.sh:9, tests/gitleaks.test.sh:10, shellcheck.test.sh:10). The strongest unlisted option: the project's scripts fall back to `/opt/devshop-tools/bin/<tool>` when `$GITLEAKS`/`$SHELLCHECK` aren't set. That works in every process, hook processes included, and needs no `CLAUDE_ENV_FILE`. Its cost: every project's copies must be upgraded, so the fixture's pin wouldn't get the fix without an upgrade. The spec should reject it in a line with that reason.

5. **A new failure mode: prepending overrides the project's own tool choice.** "So a session runs what CI runs" holds only if the project's CI pins the same versions as the devshop's tools.pin. tools.pin's header refers to the devshop repo's own ci.yml. A project whose CI or `scripts/setup.sh` pins a different gitleaks or shellcheck would now get the devshop's version locally and differ from its own CI. Question for the owner: is the devshop's pin authoritative for projects?

6. **A gap in "missing still fails loudly".** If the pinned link is missing but the image has some other gitleaks on PATH, the check silently runs that other version. Only the `DEVSHOP:` line is loud. AC-3 tests only with a PATH of system directories and no other copy. State this as accepted, or test it.

7. **A missing edge case: tools.pin can't be read.** The check reads `install/tools.pin` at `$(cat default-ref)` from the mirror. If default-ref is missing or `git show` fails, the spec doesn't say what happens. A silent empty list would report "all present". It should print a `DEVSHOP:` line instead. The same question applies to an unwritable `$CLAUDE_ENV_FILE`.

8. **AC-4 can't be tested as worded.** "its other lines are unchanged" doesn't say compared to what. Make it: identical to the same run with `CLAUDE_ENV_FILE` set, except for the added line.

9. **The project's setup script doesn't get the tools.** The version's session-start runs `scripts/setup.sh` from inside the hook process, which doesn't source the env file. If a project's setup calls gitleaks or shellcheck, it still won't find them. The cheap fix is to `export PATH` in the dispatcher before running the version's script. Either add that or list it under Out of scope.

10. **Smaller points.**
    - The SessionStart hook has no matcher, so it also fires on resume, clear and compact. AC-5's "run twice" covers that; worth saying so.
    - The dispatcher header still says it "Prints one DEVSHOP: line"; it will now print more. Update that comment along with AC-8's docs.
    - Size is in proportion: a few lines in the dispatcher plus tests.
    - Codebase claims I confirmed:
      - tests/pre-bash.test.sh:13 does use `command -v dcg`.
      - bootstrap.test.sh has `PRE_MOVE=6190c0e0…`.
      - Priming runs before `install_tools` (install/bootstrap.sh).
      - A failed re-install does leave a dangling link: `rm -rf "$dir"` then a failed download keeps the old `bin/<name>` link.

Critical files:
- <replay>/pinned/install/plugin/devshop/hooks/dispatch.sh
- <replay>/pinned/install/bootstrap.sh
- <replay>/pinned/runtime/hooks/session-start.sh
- <replay>/pinned/tests/bootstrap.test.sh
- <replay>/pinned/scripts/secret-scan.sh
