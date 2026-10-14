1. **New failure mode in this repo's own tests (the most serious).** `tests/git-hooks.test.sh` sets `gitleaks_bin=$(command -v gitleaks)` on line 18, before line 19 mounts a scratch tmpfs over `/opt`. Line 26 then runs `ln -s "$gitleaks_bin" /opt/devshop-tools/bin/gitleaks`. Once this change puts `/opt/devshop-tools/bin` first on PATH, `gitleaks_bin` is `/opt/devshop-tools/bin/gitleaks`. After the mount, that link points at itself, so the test breaks. `tests/pre-bash.test.sh` does the same with dcg: `real_dcg=$(command -v dcg)` runs before the mount, and then `ln -s "$real_dcg" /opt/devshop-tools/bin/dcg`. The spec even cites `pre-bash.test.sh` as a reason to expose dcg. So the change turns this repo's checks red, which is the problem the owner wants gone. Fix: resolve with `readlink -f` before the mount, or copy the binary into the scratch `/opt`. Add that to the spec's scope and give it an AC: both tests pass when PATH holds the real `/opt/devshop-tools/bin`. The fixture's tests may have the same pattern; check them.

2. **Wrong AC reference.** The first Decision says "only AC-6 shows Claude Code doing it on the owner's surface". AC-6 is the priming-run item. The fixture-session check is AC-7. Fix it.

3. **Cause, and the strongest option not listed.** The spec fixes where the problem starts: the bootstrap installs the tools to a path the session's PATH doesn't include. The fix is in the right layer. But one option isn't listed or rejected: have the bootstrap add the PATH line to the shell profile (`~/.bashrc` or `/etc/profile.d`). Claude Code snapshots the user's shell config for its Bash tool. That option doesn't depend on `CLAUDE_ENV_FILE` or the plugin's hook running. It covers the no-env-file case and terminals outside Claude. It also lives in the bootstrap, which is per environment, the same reasoning the spec uses to put this in the dispatcher. The other unlisted option: project scripts fall back to `/opt/devshop-tools/bin`. Rejecting that one is easy (devshop paths in project code), but say so. The owner should decide whether the profile option beats the env file.

4. **A missing tool can still run instead of failing.** If a pinned tool failed to install and the image has its own copy, the session silently runs the image's version. Example: a distro shellcheck in `/usr/bin`. That isn't "fails loudly"; it's the version drift the spec says prepending avoids. Only the `DEVSHOP:` line warns. AC-3 avoids this case by using "a PATH of only system directories with no copy of it". Either say this outcome is accepted, or make the `DEVSHOP:` line say an unpinned copy may run. Also, on CI-like runners `/usr/bin/shellcheck` often exists, so AC-3's test has to use gitleaks or a tool name it controls.

5. **Where in `dispatch.sh` this goes is ambiguous.** `dispatch()` returns early for an invalid pin, an unknown pin, and a version with no runtime. "Outside its version selection" needs to say before or after the `$(dispatch)` capture. Also say whether the tools line uses `say`, with the copy date and project suffix like the other lines. AC-2 tests only the unknown-pin case. Add the invalid-pin text (e.g. `-x`) and the no-runtime version.

6. **Missing edge cases in the tools check.**
   - `default-ref` or the mirror is missing, so `tools.pin` can't be read: is that silent or its own line?
   - `CLAUDE_ENV_FILE` is set but can't be written.
   - A `CLAUDE_PROJECT_DIR` with no git repo.
   - The dcg rule ("left out when the existing dcg line already reports it") ties the dispatcher to a version's `session-start.sh`. Projects pinned to an older version may not have that dcg line, so dcg is either reported twice or not at all. Simpler: always name dcg in the new line and accept the overlap, or state the rule exactly. Today the old line fires only when the plugin's `hooks.json` registers `pre-bash.sh`.

7. **Docs drift.** `install/README.md` § "The `DEVSHOP:` line" says "The hook emits one line". With this change it can emit more. Update it under AC-8. The § Pinned tools text in that file ("where the devshop's hooks run it") also needs the new wording.

8. **The reviewer's nested `claude -p` doesn't get the tools.** It runs with `--restricted --safe-mode --settings runtime/reviewer/settings.json`, so it probably loads no plugin and gets no env file. Its allow-list has no gitleaks or shellcheck anyway, so it changes nothing. Add it to Out of scope so nobody expects it to work.

9. **The literal code is right.** The `case ":$PATH" in :/opt/devshop-tools/bin:*)` line is idempotent and correctly quoted. `-x` follows symlinks, so a dangling link counts as missing, as the spec says. The bootstrap's `rm -rf "$dir"` before a re-download does leave a dangling `bin/<name>` link when the re-install fails, so AC-3's dangling-link case is real. The priming run uses `CLAUDE_PROJECT_DIR=/nonexistent` with no env file, which matches the spec's skip rule and AC-6.

10. **Size is in proportion.** One dispatcher block, tests in the existing harness, and docs, plus the test fix from #1.

Paths:
- <replay>/pinned/tests/git-hooks.test.sh
- <replay>/pinned/tests/pre-bash.test.sh
- <replay>/pinned/install/plugin/devshop/hooks/dispatch.sh
- <replay>/pinned/install/bootstrap.sh
- <replay>/pinned/runtime/hooks/session-start.sh
- <replay>/pinned/install/README.md
