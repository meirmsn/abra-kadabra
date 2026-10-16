# Findings

What Claude noticed while working on this repo and didn't fix, kept so the owner can watch what
comes back. A finding is not a task: what the owner decided to do is in `ROADMAP.md`.

<!--
Findings template (specs/findings-and-roadmap.md in the devshop). Create the repo's root
FINDINGS.md from it on its first row; delete this comment there.

- What goes in: anything noticed that this change doesn't need, a reviewer `low` finding left
  unfixed included. Fix it now only when the task needs it or it sits in lines the change already
  edits. Never fix a row on reflex.
- Only this repo's: a project's FINDINGS.md holds findings about the project. One about the devshop
  goes in the block of devshop findings the session gives the owner at hand-over, never here.
  Something already on a roadmap is not logged; mention a repeat only if it makes the entry more
  urgent.
- Match first: on a row for the same thing, add a line to its Seen cell (one per session), not a
  new row.
- ID: the next free number, F-<n> (the devshop: F-NEW-<n>), checked against the latest main
  before ship; on a clash, renumber your own row.
- Severity: high (it can break production, lose data or open a security hole), med (it costs time
  on a common path or on every change), low (anything else).
- Seen: one "YYYY-MM-DD · <PR or session>" per session that hit it, separated by <br>.
- Surfacing: at hand-over, list each row logged as med or high, and each row whose sightings just
  reached 3, and ask the owner "roadmap or keep watching?". Nothing else is surfaced. "Roadmap"
  deletes the row and adds a ROADMAP.md entry; "keep watching", or no answer, leaves it.
- Delete a row when it is fixed, moved to the roadmap, or can no longer happen; git history is its
  record, and the commit says why.
- When: in the change's PR. The reviewer's low findings arrive with its pass: log them as one
  commit that changes only this file (and ROADMAP.md), and ship again; the reviewer then checks
  the words only.
-->

| ID  | Severity | What was noticed | Seen |
| --- | -------- | ---------------- | ---- |
