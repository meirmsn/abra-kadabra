# The session-start line says when the bootstrap failed

**Go:** pending

## Intent

F-NEW-135; this change deletes its row in `FINDINGS.md`. The bootstrap logs each step to
`/tmp/devshop-setup.log`, which survives into sessions, and ends it with `RESULT: bootstrap done
(...)` or `RESULT: bootstrap FAILED (see FAILED lines above)` after `FAILED: <step>: <why>` lines.
The `DEVSHOP:` line reads the copy's date and the pinned version, never that result, so when the
gstack step failed in every environment, every session ran for a day without gstack's dependencies,
setup, linked skills and browse binary, and nothing said so. The owner (2026-11-01): "one more
clause on the `DEVSHOP:` line when the log ends `RESULT: bootstrap FAILED`, naming the failed steps
(the text after `FAILED: ` up to the first colon, de-duplicated) and pointing at the log, e.g.
`; bootstrap FAILED (gstack, impeccable): see /tmp/devshop-setup.log`. A missing log adds nothing."
Feedback, like every hook: it tells the owner, it guards nothing.

## Decisions

- **The plugin's dispatcher adds the clause, not `runtime/hooks/session-start.sh`:** the owner's
  words name the version's script, but the `DEVSHOP:` line is built by the plugin's dispatcher
  (`install/plugin/devshop/hooks/dispatch.sh`), which runs even when no version could be primed.
  The plugin is installed from `main` at the cache build, so the clause reaches every project
  whatever version it pins; in the version's script it would reach only projects pinning a version
  that has it. It takes effect in each environment at its next cache rebuild (Claude, 2026-11-01)
- **Once, at the end of the main line:** the clause goes on the one line that names the version
  (or says it was kept), after the project and any other note, as
  `; bootstrap FAILED (<steps>): see /tmp/devshop-setup.log`; never on the line saying the version's
  session-start script failed, nor on lines that script prints. A dcg failure also keeps that
  script's own dcg line: the overlap is intended, one says what broke, the other what it costs
  (Claude, 2026-11-01)
- **Only the bootstrap's own lines count, and only the last run's:** the three markers are read at
  the start of a line as the bootstrap's `log` writes them, `[HH:MM:SS] bootstrap start `,
  `[HH:MM:SS] FAILED: ` and `[HH:MM:SS] RESULT: bootstrap done|FAILED`; output other tools append to
  the log (claude, tar, curl, the priming run of the dispatcher) never counts. The log is appended
  to (a re-run adds a run), and the bootstrap's priming run reads it before its own `RESULT:`, so
  the log is read from its last `bootstrap start` line, or whole if it has none. "Ends FAILED" means
  that run's `RESULT:` line says FAILED; a run with no `RESULT:` line adds nothing (Claude,
  2026-11-01)
- **A step is the text after `FAILED: ` up to the first colon, or the whole text when it has none:**
  each named once, in the order they failed, joined by `, ` (a tool's step is `tool <name>`). A
  FAILED result with no `FAILED:` line in its run, which the bootstrap never writes but a truncated
  log could hold, gets `; bootstrap FAILED: see /tmp/devshop-setup.log` (Claude, 2026-11-01)
- **A log that exists but can't be read is said, not skipped:** the line gets
  `; couldn't read /tmp/devshop-setup.log to check the bootstrap's result`, since staying silent
  is the failure this change fixes; beyond the owner's words, so it is asked at the go (Claude,
  2026-11-01)
- **The check, as the owner set it:** `tests/bootstrap.test.sh` asserts the clause with the failed
  step's name after a real failed bootstrap (`session '' <branch> FAILED`) and its absence after a
  `done` one, then feeds the hook written logs for the mutants: a log saying `done`, one with no
  `RESULT:` line, no log, plus the cases below (owner, 2026-11-01)

## Acceptance items

- **AC-1** When the last run in `/tmp/devshop-setup.log` ends `RESULT: bootstrap FAILED`, the hook's
  output carries `; bootstrap FAILED (<steps>): see /tmp/devshop-setup.log` exactly once, at the end
  of the main `DEVSHOP:` line, `<steps>` being that run's failed steps as the Decisions define them,
  de-duplicated, in the order they failed; an earlier FAILED run's steps are not among them. A
  FAILED run with no `FAILED:` line gets `; bootstrap FAILED: see /tmp/devshop-setup.log`
- **AC-2** A log whose last run ends `RESULT: bootstrap done`, a last run with no `RESULT:` line, no
  log at all, and a FAILED run followed by a `done` run each add no bootstrap clause; `FAILED` text
  in a line that isn't the bootstrap's own (another tool's output) changes nothing
- **AC-3** A log that exists but can't be read adds
  `; couldn't read /tmp/devshop-setup.log to check the bootstrap's result` to the main line
- **AC-4** `install/README.md`'s table of `DEVSHOP:` lines has a row for the failed bootstrap, and its
  prose on what the line ends with names the clause — verified by review: the diff

## Out of scope

- A bootstrap killed before its `RESULT:` line (a timeout), or one that failed before the plugin was
  installed: no clause, as today
- Fixing the steps themselves, or re-running the bootstrap from a session
