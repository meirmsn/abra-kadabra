# The session-start line says when the bootstrap failed

**Go:** pending

## Intent

F-NEW-135. The bootstrap logs each step to `/tmp/devshop-setup.log`, which survives into sessions,
and ends it with `RESULT: bootstrap done (...)` or `RESULT: bootstrap FAILED (see FAILED lines
above)` after `FAILED: <step>: <why>` lines. The `DEVSHOP:` line reads the copy's date and the
pinned version, never that result, so when the gstack step failed in every environment, every
session ran for a day without gstack's dependencies, setup, linked skills and browse binary, and
nothing said so. The owner (2026-11-01): "one more clause on the `DEVSHOP:` line when the log ends
`RESULT: bootstrap FAILED`, naming the failed steps (the text after `FAILED: ` up to the first
colon, de-duplicated) and pointing at the log, e.g. `; bootstrap FAILED (gstack, impeccable): see
/tmp/devshop-setup.log`. A missing log adds nothing." Feedback, like every hook: it tells the owner,
it guards nothing.

## Decisions

- **The plugin's dispatcher adds the clause, on every `DEVSHOP:` line it prints:** the dispatcher
  builds the line, and it runs even when no devshop version could be primed, which is when a failed
  bootstrap matters most; rejected: the version's own `session-start.sh`, which runs only once a
  version is active and would print a second line (Claude, 2026-11-01)
- **Only the last bootstrap run counts:** the bootstrap appends to the log, and the cache build can
  run it more than once, so the log is read from its last `bootstrap start` line; a run with no
  `RESULT:` line yet (or none at all) adds nothing (Claude, 2026-11-01)
- **A step is the text after `[HH:MM:SS] FAILED: ` up to the first colon, or the whole text when
  it has none:** only the bootstrap's own `FAILED:` lines count, not output other tools appended to
  the log; the steps keep the order they failed in, each named once, joined by `, `. A `FAILED`
  result with no such line still gets the clause, without the parentheses (Claude, 2026-11-01)
- **The clause goes last on the line:** after the project and any other note, as
  `; bootstrap FAILED (<steps>): see /tmp/devshop-setup.log` (Claude, 2026-11-01)
- **An unreadable log counts as missing:** nothing is added (Claude, 2026-11-01)

## Acceptance items

- **AC-1** When the last bootstrap run in `/tmp/devshop-setup.log` ends `RESULT: bootstrap FAILED`,
  every `DEVSHOP:` line the dispatcher prints ends with
  `; bootstrap FAILED (<steps>): see /tmp/devshop-setup.log`, `<steps>` being that run's failed
  steps as the Decisions define them, de-duplicated, in the order they failed
- **AC-2** A log whose last run ends `RESULT: bootstrap done`, a last run with no `RESULT:` line, and
  no log at all each add no bootstrap clause; a `FAILED` result from an earlier run followed by a
  `done` run adds none either
- **AC-3** `install/README.md`'s table of `DEVSHOP:` lines has a row for the failed bootstrap

## Out of scope

- A bootstrap killed before its `RESULT:` line (a timeout), or one that failed before the plugin was
  installed: no line, as today
- Fixing the steps themselves, or re-running the bootstrap from a session
