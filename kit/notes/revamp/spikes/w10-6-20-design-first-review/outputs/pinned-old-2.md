Review of specs/pinned-tools-on-path.md. Treat each item as a claim to check.

1. **A stale pinned version can pass silently.** `install_tools` installs into `$TOOLS/$name-$version` and only re-links on success. Say tools.pin bumps a version and the new download or checksum fails. Only the new dir is removed, so `bin/<name>` still points at the old version's directory, which still exists and is executable. The `-x` check passes and the session runs a version CI doesn't, which is the problem the owner wants gone. The check should compare the link target with `<name>-<version>` from tools.pin, or AC-3 should list this case. Edge case: if /opt is never kept across rebuilds, this can't happen and AC-3's "dangling link" case can't either. Ask the owner which is true.

2. **The proof of the experiment isn't where the spec says it is.** Decisions says the CLAUDE_ENV_FILE experiment is "recorded in the LOG entry". LOG #65 (kit/notes/revamp/LOG.md:2637 on) only says gitleaks isn't on PATH and "Next: put /opt/devshop-tools/bin on the session's PATH, or file it". There is no probe, no Claude Code 2.1.299, no `--plugin-dir` result. Record it, or soften the claim.

3. **Wrong AC reference.** Decisions says "only AC-6 shows Claude Code doing it on the owner's surface". AC-6 is the priming run; the owner's fresh session is AC-7.

4. **The dcg rule can't be implemented or tested as written.** "dcg is left out … when the existing dcg line in session-start.sh already reports it" has three problems:
   - The dispatcher can't know whether that line fires. It depends on whether the pinned version's session-start.sh exists and has the line, whether `DEVSHOP_PRIME_ONLY` is set, and whether hooks.json registers pre-bash.sh.
   - `dispatch()` returns early, without running session-start.sh, for a bad pin, a pin missing from the copy, and a pin with no runtime.
   - A pre-move pin has no such line.

   No AC tests the de-dup. Simpler: always name dcg (two lines) or never, and add an AC for it.

5. **AC-2 misses the pre-move pin's real path.** bootstrap.test.sh:315-319 shows `PRE_MOVE` may take the "has no devshop runtime" early return, not "using". AC-2 should name all early-return paths (invalid pin, not in copy, no runtime). The env-file line and the tools check must run outside `dispatch()`'s returns and inside the `out=$(dispatch)` capture, or their lines are lost. The spec should say where they sit.

6. **No rule for a missing or unreadable tools.pin or default ref.** If `$VERSIONS/default-ref` or `git show <ref>:install/tools.pin` fails, what does the tools check print? Silence would turn a missing tool into a pass. Add a decision and an AC: it says it couldn't check.

7. **AC-4's "its other lines are unchanged" can't be tested as written.** It names no baseline: unchanged from what, under which pin? Name the comparison, e.g. the same lines as with CLAUDE_ENV_FILE set, minus none.

8. **AC-7 may be weaker than the owner's case.** The fixture's `check-fast.sh` runs its own scripts and tests. The owner's failure was "2 of 9 script test files", meaning tests/gitleaks.test.sh and secret-scan.test.sh, which use `command -v`. Confirm none of the fixture's tests reset PATH; this repo's don't. Also, AC-7 lists gitleaks and shellcheck but not dcg, though the Decisions expose dcg.

9. **Scope check.** Exposing dcg on PATH goes beyond the owner's words, which name only the project's checks failing on gitleaks. It is justified by tests/pre-bash.test.sh:13 (`command -v dcg`), but that is this repo, not project sessions. It is fine, but flag it as added scope. The missing-tool `DEVSHOP:` line and the no-CLAUDE_ENV_FILE line are also additions. They support "fail loudly", but the owner only asked that the check fail, not the hook.

10. **Hook ordering.** "Another hook's env file resetting PATH" is out of scope. But the gstack install also registers hooks? It runs with its hooks off (`--no-plan-tune-hooks`, `--no-timeline-stop-hook`), so the risk is low. Name it as a known non-risk.

11. **The literal code matches the repo**, with one gap:
    - These all match: the dispatch.sh path; the `DEVSHOP_PRIME_ONLY` priming with no CLAUDE_ENV_FILE (install/bootstrap.sh); /tmp/devshop-setup.log; /opt/devshop-tools/bin; the tools.pin versions 8.30.1 and 0.11.0; `PRE_MOVE=6190c0e0…`; the session-start.sh dcg line; the install/README.md "Pinned tools" bullet; W10-v2.md.
    - The bad-checksum fresh install leaves no link, as AC-3 assumes. The "dangling link from a failed re-install" case has no existing test fixture; AC-3 will need a new one.

12. **Quoting.** "Single-quoted when written" is right in intent, but the line itself contains no single quotes. Make sure the writer uses `printf '%s\n'` with the literal line, so `$PATH` isn't expanded at hook time. AC-5 covers the idempotence but not the expansion; add a check that the file contains the literal `$PATH`.
