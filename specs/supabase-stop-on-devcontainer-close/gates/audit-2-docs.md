Clean — no docs findings.

Audit 1's medium docs finding closed: both `kit/docs/guide/ops.md` (lines 178-179) and `kit/docs/guide/local-supabase-compose-isolation.md` (lines 108-109) now use `<project>_devcontainer-supabase-runner-1` in the Stop variants code blocks. Repo-wide grep for the stale `<project>-supabase-runner-1` (without `_devcontainer`) pattern returns zero hits — naming is consistent with the five canonical citations in the Debugging tree section.

Fix commit (`86536e3`) touches only docs + tests; no source-code change, so Section A coverage rubric has nothing to require. Section B adequacy: the two-character correction is the smallest substantive edit that closes the medium finding — load-bearing recipe correction, no stub. Section C coherence: existing guide prose at `ops.md:173` and `local-supabase-compose-isolation.md:96,103` correctly describes the SIGTERM-trap shutdown at the right grain (cites `cmd-relay.mjs § Shutdown` + `compose.yml § stop_grace_period: 30s`) — no contradiction with the relay's 25s budget or `shuttingDown` re-entrancy guard pinned by the tests (both are implementation details below the doc's chosen grain).

No `Docs-Coverage-Bypass:` trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop self-mode (`$GIT_ROOT == /devshop/.worktrees/supabase-stop-on-devcontainer-close`, a devshop worktree).
