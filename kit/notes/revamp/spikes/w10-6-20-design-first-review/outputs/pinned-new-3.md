Review of specs/pinned-tools-on-path.md. Every path below is under <replay>/pinned. Each point is a claim to check.

1. **Root cause and design are right.** The cause: `install/bootstrap.sh` (install_tools) links the tools into a private directory, but the project's scripts call them by bare name on PATH (`scripts/secret-scan.sh:9` `${GITLEAKS:-gitleaks}`, `scripts/shellcheck.sh:10`, and `tests/gitleaks.test.sh:13`, `tests/secret-scan.test.sh:9`, `tests/git-hooks.test.sh:18`, `tests/pre-bash.test.sh:13`). Putting the PATH line in the dispatcher, outside version selection, is the only option listed that also fixes projects pinned to an older version. One option is missing from the rejected list: have the project scripts fall back to `/opt/devshop-tools/bin/<tool>`. It fails because it changes project files, which only an upgrade brings, so the pinned fixture would still break. Say that in the spec. The size is in proportion, except for the dcg handling in point 3.

2. **The new lines break existing tests, and the spec doesn't say what happens to them.** `check()` in `tests/bootstrap.test.sh:228-229` fails unless there is exactly one `DEVSHOP:` line. Every existing case runs the hook without `CLAUDE_ENV_FILE`, so each would now get AC-4's extra line and fail. The `tools-bad` case (line 373) would also get the missing-tool line. Several places also promise a single line: the header of `dispatch.sh` ("Prints one DEVSHOP: line"), the `install/README.md` § The `DEVSHOP:` line ("The hook emits one line"), and "its other lines are unchanged" in AC-4. The spec should say:
   - the existing cases now set `CLAUDE_ENV_FILE`, or `check` changes;
   - the new lines go into `out`, so they reach the hook JSON;
   - whether they use `say()` (with the copy date and project tail);
   - where they go, since `dispatch()` returns early on a bad or unknown pin;
   - that the README section is updated (AC-8 covers only § Pinned tools).

3. **The dcg rule is fragile.** The spec leaves dcg out of the new line "when the existing dcg line already reports it". That line (`runtime/hooks/session-start.sh:13-16`) prints only when all of these hold:
   - the version's session-start script actually runs: the pin resolved, it isn't a priming run, and the version has the script;
   - the plugin's `hooks.json` registers `pre-bash.sh`.

   The dispatcher would have to predict all of that. Simpler: always name dcg (one duplicate in a rare failure), or check the version's output for `dcg is not installed`. Ask the owner.

4. **Bug in the literal env-file line.** `case ":$PATH" in :/opt/devshop-tools/bin:*)` misses the case where PATH is exactly `/opt/devshop-tools/bin`, with no trailing colon, so it prepends a duplicate. Use `":$PATH:"`. Also, if the original PATH already has the directory further down, the line prepends a second copy. AC-5's "on it once" holds only if the original PATH lacked it, so either word the AC that way or remove the existing entry.

5. **Wrong cross-reference.** Decisions say "only AC-6 shows Claude Code doing it on the owner's surface". That is AC-7; AC-6 is the priming run. Fix.

6. **Missing edge case: an unpinned copy on the image's PATH.** If a pinned tool failed to install but the image has another version, the project check silently passes with that version. That goes against "a session runs what CI runs", and the `DEVSHOP:` line is the only signal. AC-3 tests only "no copy on PATH". Add a case where a decoy is on PATH and the tool is missing: the line names the tool and the decoy runs. Or ask the owner whether that should fail.

7. **Unclear source for the tools list.** The spec says to read "`install/tools.pin` from the local copy at the environment's default ref". Say exactly how: `git --git-dir=/opt/devshop.git show "$(cat /opt/devshop-versions/default-ref):install/tools.pin"`. Also say what happens if `default-ref` or the file is unreadable: no line, or a line saying the list couldn't be read? Not covered.

8. **Edge cases not covered.**
   - SessionStart fires again on resume, clear and compact, possibly with a fresh `CLAUDE_ENV_FILE`; AC-5 only covers re-running with the same file.
   - `CLAUDE_ENV_FILE` is set but can't be written: no line is specified for that failure.
   - A bad-format pin (the `case` refusal) isn't in AC-2's list of unresolved pins.

9. **Scope.** The no-env-file line (AC-4) and the missing-tool line go beyond "find the tools, fail loudly". The project check already fails with "not found". I think they are justified by point 6. Confirm with the owner that both are wanted.

10. **AC-3 setup.** In "a shell that sources the env file over a PATH of only system directories", the test must make sure `/usr/bin` and `/bin` really contain no gitleaks, shellcheck or dcg in the test namespace. Otherwise the AC is environment-dependent.

**Checked against the code and found accurate:** priming runs before install_tools, with `DEVSHOP_PRIME_ONLY=1`. A failed re-install leaves a dangling link, because `rm -rf "$dir"` runs before the download. A bad checksum on a fresh install leaves no link (test line 372). The existing tests run the dispatcher in a scratch `/opt` via `unshare`, so the hardcoded `/opt/devshop-tools/bin` works there. `PRE_MOVE=6190c0e0…` exists. `W10-v2.md` exists.
