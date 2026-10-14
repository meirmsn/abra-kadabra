Review of specs/pinned-tools-on-path.md. Each finding is a claim for you to check. I checked them against dispatch.sh, install/bootstrap.sh, runtime/hooks/session-start.sh, tests/bootstrap.test.sh and the project's gitleaks tests.

1. **Root cause and design.** The cause is real. The bootstrap links the tools only into `/opt/devshop-tools/bin`. Only `runtime/git-hooks/pre-push` uses that path, and it does so itself with `tools=/opt/devshop-tools/bin` and `PATH="$tools:$PATH" scripts/lint.sh`. The project's checks (`tests/gitleaks.test.sh`, `tests/secret-scan.test.sh`, `tests/git-hooks.test.sh`, `scripts/secret-scan.sh`) resolve `${GITLEAKS:-gitleaks}` on PATH. Putting a line in `CLAUDE_ENV_FILE` from the dispatcher fixes the cause and is about the right size. One option is missing from the spec: changing the project scripts to fall back to `/opt/devshop-tools/bin`. It should be listed as rejected, because it changes project code, CI doesn't need it, and the fixture is pinned to an old version. A settings `env` of `GITLEAKS=...` would also work literally, but it covers gitleaks only. The spec rejects `env` for a different reason (it can't extend PATH), which is true but isn't the whole picture.

2. **Wrong cross-reference (sure, fix).** Decision 1 says "only AC-6 shows Claude Code doing it on the owner's surface". AC-6 is the priming-log item; the fresh-session check is AC-7.

3. **The dcg rule is ambiguous and probably more than needed.** "dcg is left out … when the existing dcg line … already reports it" makes the dispatcher repeat session-start.sh's condition. That line is printed only when all of these hold:
   - a version resolved and isn't in prime-only mode;
   - that version's session-start.sh has the check (older pins like `6190c0e0` may not);
   - hooks.json registers pre-bash.

   Simpler options: always name every missing tool and accept one repeated mention of dcg, or leave dcg out only if `$out` already contains "dcg is not installed". The rule should be decided and then tested; right now no AC covers it.

4. **Missing edge case: an old version passes as present.** `install_tools` does `rm -rf "$dir"` where `dir=$TOOLS/$name-$version`. If a pin bumps the version and the new download fails, the old `$name-<oldversion>` directory survives and the link still points to it. The `-x` check passes and the session runs a version CI doesn't, which is what the owner is trying to avoid. This only happens if `/opt` survives an environment rebuild. Owner question: does `/opt` persist across cache rebuilds? If it does, the check (or the bootstrap) should compare the link target against `<name>-<pinned version>`.

5. **Scope question.** The owner asked that a missing tool "still fail loudly". The project's checks already do that ("gitleaks not found", non-zero exit), and AC-3 relies on it. The new missing-tools `DEVSHOP:` line, the read of tools.pin at default-ref, and the dcg rule in finding 3 are added scope. They're defensible as early warning, but the owner should confirm them.

6. **New failure modes.**
   - The env file is sourced before every Bash command, so a quoting mistake breaks every command in the session. One AC should source the exact written file under `bash -n` / `set -u`.
   - The dispatcher must append (`>>`), never overwrite. Say so explicitly.
   - Tool names read from tools.pin end up in paths and messages. Apply the bootstrap's `^[a-z0-9-]+$` check before using them.

7. **The dispatcher's own child processes don't get the new PATH.** The version's session-start.sh runs the project's `scripts/setup.sh` from the dispatcher, and the env file doesn't apply there, so a setup that calls shellcheck or gitleaks still misses them. Exporting PATH inside dispatch.sh too would cover it. Say whether that's intended or out of scope.

8. **Ambiguous output.** It isn't specified whether the new lines go through `say` (and so end with the copy date and project) or are plain `echo` like session-start.sh's lines. AC-3 and AC-4 can't be checked exactly until that's decided. The lines must also come before `[ -n "$out" ] || exit 0` and be part of `$out`, so they reach the JSON. Today they would, since `dispatch` always prints, but the spec says the new lines sit outside version selection.

9. **AC-7 can only run after merge.** The plugin is extracted from `$REF` (main) at bootstrap, so the fixture session sees this only after the change is on main and the environment rebuilds. Say so, so the owner doesn't expect it before the PR lands.

10. **SessionStart also fires on resume, clear and compact.** AC-5 covers sourcing twice and running the hook twice. Nothing says whether a fresh `CLAUDE_ENV_FILE` per event keeps PATH, and the 2026-10-14 experiment covered startup only. That belongs in Out of scope or as an owner question.

11. **The literal code fits the codebase.** It matches the dispatcher's structure, `DEVSHOP_PRIME_ONLY`, `PRE_MOVE=6190c0e0…` in tests/bootstrap.test.sh, and the `-x` style used in session-start.sh. The `case ":$PATH" in :/opt/devshop-tools/bin:*)` line is correct: it leaves the directory first and only once.

### Critical Files for Implementation
- <replay>/pinned/install/plugin/devshop/hooks/dispatch.sh
- <replay>/pinned/install/bootstrap.sh
- <replay>/pinned/tests/bootstrap.test.sh
- <replay>/pinned/runtime/hooks/session-start.sh
- <replay>/pinned/install/README.md
