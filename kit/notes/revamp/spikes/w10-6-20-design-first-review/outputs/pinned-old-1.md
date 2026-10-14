Findings on specs/pinned-tools-on-path.md, most important first. Treat each as a claim to check.

1. **The new lines break the existing bootstrap test, and the spec never mentions it.** In `tests/bootstrap.test.sh`, `check()` fails unless there is exactly one `DEVSHOP:` line. `session()` runs the hook without `CLAUDE_ENV_FILE`. Under AC-4, every existing `session`/`check` case would gain a "not on PATH" line and fail. The `tools-bad` case would also gain a missing-gitleaks line. `install/README.md` § "The `DEVSHOP:` line" also says "The hook emits one line" and has a table of cases. The spec should either change that contract and its test (and AC-8 should cover the README table), or decide that `session()` sets `CLAUDE_ENV_FILE` by default.

2. **The env-file line in Decisions is wrong for one case.** It matches `case ":$PATH" in :/opt/devshop-tools/bin:*)`. If PATH is exactly `/opt/devshop-tools/bin`, `":$PATH"` has no trailing colon, so it doesn't match and the directory is added again. Use `":$PATH:"`. Also, if the directory is already on PATH but not first, the line prepends it and leaves the later copy. That breaks AC-5's "on it once". Either remove the later copy or narrow AC-5 to the starting PATHs it covers.

3. **Wrong cross-reference.** Decisions says "only AC-6 shows Claude Code doing it on the owner's surface". AC-6 is the priming-log item. The owner's fresh-session check is AC-7.

4. **The dcg rule can't be pinned down or tested as written.** "dcg is left out of that line when the existing dcg line in `runtime/hooks/session-start.sh` already reports it" doesn't say how the dispatcher knows. That script only prints its dcg line when the plugin's `hooks.json` registers `pre-bash.sh` and the version's script actually runs. It doesn't run when priming, when the pin isn't in the copy, or when the version has no runtime. The pre-move pin `6190c0e0` may not have that line at all. No AC covers a missing dcg. Either always name all three tools (simplest, at the cost of a possible duplicate) or define the rule and add an AC. This is a question for the owner.

5. **AC-3 doesn't test what the owner asked.** The owner wants the project's check to fail loudly. AC-3 only shows that bash can't find the binary. A stronger test runs a check that looks the tool up on PATH, such as `scripts/secret-scan.sh`, and asserts exit 2 with `FAIL: gitleaks not found`. Also, "a PATH of only system directories" hides a real case: if the image has an unpinned gitleaks or shellcheck on PATH, a failed pinned install silently falls through to it. Only the `DEVSHOP:` line would warn, so the check is neither red nor pinned. The spec should name that case and decide whether it's acceptable.

6. **Scope added beyond the ask.** The missing-tool `DEVSHOP:` line and the "no `CLAUDE_ENV_FILE`" line weren't requested. The owner asked for tools found on PATH and loud failure, which the project's checks already give for a missing tool. They are reasonable, but the owner should confirm them, especially the "not on PATH" line, which could appear on every session of any surface that lacks `CLAUDE_ENV_FILE`.

7. **What "unchanged" compares against is undefined in AC-4.** AC-4's "its other lines are unchanged" doesn't say compared with what: the same run with `CLAUDE_ENV_FILE` set, or the output before this change? Name the comparison.

8. **Missing edge cases:**
   - SessionStart also fires on resume, clear and compact, so the same env file gets more lines. AC-5 partly covers this.
   - `CLAUDE_ENV_FILE` set but not writable: what does the hook print?
   - A pin rejected by the pattern check (`'' | -* | …`) returns early. The env-file line must still be written. AC-2 covers "not in the copy" but not this path.
   - The env-file line and the tools check must run outside `dispatch()` or before its early `return`s, since each failure branch returns before the end. Say so.

9. **AC-7 compares exact text.** Say "contains 8.30.1" rather than "prints 8.30.1", since gitleaks or shellcheck may add a prefix such as `v` or other text. It also depends on an environment rebuild whose default ref includes this change. That's worth stating, because the dispatcher comes from the plugin at the environment's ref, not from the project's pin.

10. **Code claims that match the codebase:**
    - The dispatcher path is right, and the priming run has `DEVSHOP_PRIME_ONLY=1` with no `CLAUDE_ENV_FILE`.
    - Tools are installed after priming, and a failed re-install does leave a dangling link (`rm -rf "$dir"`, then `continue`).
    - `PRE_MOVE=6190c0e0…` exists in the test.
    - `tests/pre-bash.test.sh` finds dcg with `command -v dcg`.
    - The post-edit and pre-push hooks call the tools by `/opt/devshop-tools/bin`.
    - `scripts/secret-scan.sh` prints `FAIL: gitleaks not found` and `scripts/shellcheck.sh` prints `FAIL: shellcheck not found`. The owner's quoted "(set $GITLEAKS or put it on PATH)" suffix is the fixture's version, not this repo's.
    - LOG #65 records the gitleaks finding but not the 2026-10-14 `CLAUDE_ENV_FILE` experiment (Claude Code 2.1.299) that Decisions cites. Add it before saying it is "recorded in the LOG entry".

Relevant files:
- <replay>/pinned/install/plugin/devshop/hooks/dispatch.sh
- <replay>/pinned/tests/bootstrap.test.sh
- <replay>/pinned/runtime/hooks/session-start.sh
- <replay>/pinned/install/README.md
- <replay>/pinned/install/bootstrap.sh
