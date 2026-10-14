1. **New failure mode (confirmed in code): the change breaks two of this repo's own tests in its own sessions.** `tests/git-hooks.test.sh:18` runs `gitleaks_bin=$(command -v gitleaks)`, then mounts a tmpfs over `/opt` (l.19), then runs `ln -s "$gitleaks_bin" /opt/devshop-tools/bin/gitleaks` (l.26). `tests/pre-bash.test.sh:13,28` does the same with dcg. Once `/opt/devshop-tools/bin` is first on PATH, `command -v` returns the path under `/opt`. That path is hidden by the scratch mount, so the link points at itself (a loop), and both tests fail. The spec even lists "pre-bash.test.sh looks for dcg on PATH" as a reason to expose dcg. Fix: resolve the tool with `readlink -f` before the mount, in both tests. Add this to the spec's changes and give it an AC (run both tests with the env-file PATH).

2. **Root cause: the fix lands where it should.** The cause is that the bootstrap installs the tools into a directory that nothing project-facing puts on PATH. Only the devshop's own hooks use the absolute path, and `post-edit.sh:15` already prepends it for its one call. The strongest unlisted option is to have the devshop-owned `scripts/secret-scan.sh` (and `check-fast.sh`) prepend the directory the way post-edit.sh does. It doesn't reach project-owned tests like `tests/gitleaks.test.sh`, which is where the 2 failures came from. So the env-file approach is the better one, and the spec should say why this option was rejected. The other rejections (symlinks into `~/.local/bin`, an `env` setting) are argued well. The size is reasonable.

3. **Wrong cross-reference.** The first Decision says "only AC-6 shows Claude Code doing it". AC-6 is the priming check; the live-session check is AC-7. Safe to fix.

4. **The experiment isn't recorded.** The spec says the CLAUDE_ENV_FILE experiment is "recorded in the LOG entry" (#65). LOG #65 (`kit/notes/revamp/LOG.md` around l.2637) only notes the missing gitleaks and "Next: put /opt/devshop-tools/bin on the session's PATH". It has nothing on CLAUDE_ENV_FILE or the experiment. Either add the experiment to the log or reword the claim. Also, the experiment used `--plugin-dir`. The real install is a marketplace plugin at user scope (`install/bootstrap.sh:40-41`). That's probably equivalent, but only AC-7 proves it.

5. **The dcg de-duplication is fragile and untested.** To leave dcg out "when the existing dcg line already reports it", the dispatcher has to copy session-start.sh's condition: hooks.json registers pre-bash, dcg isn't `-x`, *and* the pinned version has that line and its script actually ran. A version with no runtime and a pin that doesn't resolve both skip session-start, and the spec doesn't say whether an older version like `6190c0e0` has the line. No AC covers this. Simpler: always name dcg and accept two lines, or never name it. Owner's call.

6. **Unclear source for the tools list.** "Read from the local copy at the environment's default ref" doesn't say what happens when `default-ref` is missing or unreadable, or when that ref has no `install/tools.pin` (an old default). Say whether that fails silently or prints a line. Also say that the tools check and the env-file line sit outside `dispatch()`, which returns early for a bad pin or a missing runtime. AC-2 implies this but the Decisions don't spell it out.

7. **AC-3 depends on the test machine.** GitHub's ubuntu runners ship `/usr/bin/shellcheck`, so "a PATH of only system directories" would find a copy. The AC says "with no copy of it", but the test has to build that PATH itself (an empty bin plus the shell built-ins it needs), not use `/usr/bin:/bin`. Spell this out.

8. **Effect on the existing DEVSHOP: line checks.** The existing `session` calls in `bootstrap.test.sh` (l.204, 265, 274) run without CLAUDE_ENV_FILE, so after this change every one of them prints the new "not on PATH" line. AC-4 says the other lines are unchanged, but the existing assertions may need updating, or the tests should set CLAUDE_ENV_FILE by default. The `install/README.md` table of DEVSHOP: lines needs the two new lines; AC-8 only names § Pinned tools.

9. **Repeat runs.** SessionStart also fires on resume, clear and compact. The env line is idempotent (AC-5), but the missing-tool line will be repeated to the owner each time. That's acceptable; just state it.

10. **Claim to soften.** "So a session runs what CI runs" holds only where the project's CI pins the same tools. The fixture's template CI (`runtime/templates/ci.yml`) pins only gitleaks; shellcheck there is whatever the runner image has.

### Critical Files for Implementation
- <replay>/pinned/install/plugin/devshop/hooks/dispatch.sh
- <replay>/pinned/tests/bootstrap.test.sh
- <replay>/pinned/tests/git-hooks.test.sh
- <replay>/pinned/tests/pre-bash.test.sh
- <replay>/pinned/runtime/hooks/session-start.sh
