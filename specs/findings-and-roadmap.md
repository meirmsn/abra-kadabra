# Every repo keeps a roadmap of what was decided and a findings log of what was noticed

**Go:** pending

## Intent

After the website's first real change, three devshop sessions argued in parallel about how to keep
findings, and the owner was left with nine open questions and a third rewrite of the findings rule
in one day. The owner's words (2026-10-15):

> i do think we need roadmap on both devshop and each project, which has the list of tasks we do
> want to do (also useful to file things we don't want to forget to get to) - and to keep the
> findings but this is more a tool to capture all the noise of failures to not be fixing them
> (specially because they bring up more failures and because some are ephemeral etc) on knee jerk
> reaction + giving chance to identiy the truly repetitive ones - and the findings we think are
> med/high should be surfaced to me to decide whether to put on v+ of the roadmap or keep in
> findings to keep counting as usually with findings

> i also wonder if instead of supressing the findings we dont and instead log as explained above

> i'm afraid we're back in territory of the tool not working OR creating a bunch of noise of
> unnecesary improvements

On a devshop finding seen in a project (owner, earlier session, 2026-10-15): "in that case the entry
should have gone only to the devshop finding (or if in the devshop roadmap then not filed in
findings) not to the project findings."

The owner said "go" (2026-10-16) to the plan and its defaults: one table format; a fixed finding's
row is deleted (git history is its record); the files at each repo's root; roadmap statuses `Open`,
`Done` and `Dropped`; the table's order is the priority; the website doesn't rename its tests ahead
of the devshop's fix for finding 13.

## Decisions

- **Two files per repo, the devshop and every project, in one format:** `ROADMAP.md` holds what
  the owner decided will happen; `FINDINGS.md` holds what Claude noticed. An item lives in exactly
  one of the four places (project or devshop, roadmap or findings). Rejected: one file with both
  (the owner, 2026-10-15: "roadmap should be in a different file than the findings")
- **Log, don't suppress, and don't fix:** anything noticed that the current task doesn't need is a
  row in `FINDINGS.md`, or a new sighting on the row it matches. The session does not fix it. This
  replaces W10.9.6's filing rule ("file only what blocked") and D-17 item 3. The bloat came from
  grading every row, linting the file and fixing on reflex, not from logging one line (owner,
  2026-10-16)
- **A findings row:** `| ID | Severity | What was noticed | Seen |`. Severity is `high` (breaks
  production, data or security, or blocks the work), `med` (costs time on a common path or every
  change) or `low` (anything else). Seen holds one `date · where` per session that hit it, so a
  repeat adds a line instead of a row. No size, risk, leverage or status columns: a row in the file
  is open, and a row that's fixed or moved to the roadmap is deleted, with git history as its record
  (owner, 2026-10-16). Rejected: the grades the earlier session proposed (severity, size, risk,
  repeat count, status), as grading ceremony
- **Surfacing:** when a session tells the owner it's done (the PR's link in a project; the PR or
  the chat in the devshop), it lists each finding it logged or added a sighting to that is `med` or
  `high`, and each `low` with 3 or more sightings, and asks for each: "roadmap or keep watching?".
  "Roadmap" deletes the row and adds a roadmap entry; "keep watching", or no answer, leaves the row
  as it is and isn't asked again until it's seen again (owner's rule, 2026-10-15)
- **A roadmap entry:** a table `| ID | Added | What | Status |`, then a section per open entry that
  quotes the owner's request word for word in a fenced `text` block. IDs are `R-<n>`, never reused.
  Status is `Open`, `Done` (with the PR) or `Dropped` (with the reason); the section goes when the
  entry closes, because the spec quotes the request from then on. The table's order is the
  priority; the top `Open` entry is next. This is the website's draft (its PR 6) without
  `In progress` (the open PR shows that). Rejected: an explicit "next" marker (owner, 2026-10-16)
- **Where each kind goes:** about the project: its own files. About the devshop: only the devshop's
  files. A project session never records a devshop finding in the project; it lists them, at the
  end of the session, in one block the owner pastes into a devshop session, saying when one matches
  a row of the devshop's `FINDINGS.md` (the session can read it in `/opt/devshop-current/`). The
  devshop session logs them under the same rules. A repeat of something on a roadmap is not logged;
  Claude mentions it only if it makes the entry more urgent
- **When a devshop fix will change the project:** the project does nothing ahead of it. The upgrade
  PR that brings the fix carries what the project must adapt (`devshop:upgrade`). Only when the
  project is blocked today does it get a local workaround, labelled as a mitigation and naming the
  devshop finding's ID, which that upgrade removes. Rejected: applying the devshop's future change
  in the project now (it makes the project's state depend on a devshop change that may not land
  as planned)
- **The records change only through a change's PR:** a row or entry decided before `ship` goes in
  that PR. One decided after it (a reviewer `low` finding, the owner's "roadmap" answer to the
  surfacing list) is written by the project's next change, which logs the Low findings list of the
  PR merged before it. Rejected: a commit after the reviewer's pass (it costs a full review round);
  a records-only PR for each (more PRs for the owner to approve). The owner's "put it on the
  roadmap" for a new request is its own small PR with no spec, the owner's words being the go
- **The devshop's own files move to its root:** `ROADMAP.md` lists the devshop's open work in
  priority order, one line each linking to the task's detail in `kit/notes/revamp/workstreams/`,
  and replaces "the first unblocked `[ ]` task" as how the next task is picked (CLAUDE.md, PROCESS
  § 1). `FINDINGS.md` starts with the live rows not covered by a roadmap entry (F-NEW-77, 78 and 79,
  regraded to the new row format) and the 13 findings from the website's first change (F-NEW-80 to
  F-NEW-92). `kit/notes/revamp/FINDINGS.md` becomes a frozen archive with its Closed table, so the
  IDs that `lessons.md` and the notes cite still resolve. Devshop IDs carry on as `F-NEW-<n>`;
  project IDs start at `F-1`. Of today's Fix queue, F-NEW-73 is closed (shipped in PR #122), and
  F-NEW-63, 70, 75 and 42 leave the findings because their roadmap tasks hold them (W10.10.1,
  W10.9.1, W10.10.5)
- **Where Claude reads the rule:** the templates `runtime/templates/findings.md` and
  `runtime/templates/roadmap.md` carry it in a comment, and a project creates each file from its
  template on its first entry (not listed in `project-files.txt`: an empty file in every project is
  what Shape 3 avoids). The skills say when: `build` § 3 logs what the task doesn't need, `pr` § 3
  logs and surfaces and writes the devshop block, `intent` § 1 offers the top roadmap entry for
  "what's next?" and records "later" requests on the roadmap. The devshop's PROCESS § 4, TARGET
  Shape 8 and Ship 9 say the same and link the templates rather than repeating them
- No check reads either file (CLAUDE.md: prose and notes need none; the dropped findings linter
  was the bloat)

## Acceptance items

- **AC-1** `runtime/templates/findings.md` and `runtime/templates/roadmap.md` exist, each with the
  table header from the Decisions and a comment stating the rules above: what goes in, severity,
  sightings, surfacing, deletion, statuses, order — verified by review: read both templates
  against the Decisions
- **AC-2** The `build`, `pr` and `intent` skills say the steps from "Where Claude reads the rule",
  and no runtime file still says a finding is recorded only when it blocked the task —
  verified by review: read the three skills, and grep `runtime/` for "only if it blocked" and
  "only when it blocked"; neither is found
- **AC-3** The devshop has `ROADMAP.md` and `FINDINGS.md` at its root in the templates' format.
  The roadmap holds every open (`[ ]`, `[~]`) W10 task and the PLAN.md § After the revamp items,
  each linking to its detail. The findings hold F-NEW-77 to F-NEW-92 and nothing else —
  verified by review: compare with `grep -n "^- \[[ ~]\]" kit/notes/revamp/workstreams/W10-v2.md`
  and the 13 findings in the owner's messages
- **AC-4** `CLAUDE.md`, `PROCESS.md` § 1 and § 4, TARGET Shape 8 and Ship 9, and the revamp README's
  file map say the new rule and point at the root files; `kit/notes/revamp/FINDINGS.md` says it is
  frozen, and every finding ID in today's file is in the archive or the root file — verified by
  review: read them, and compare the IDs before and after
- **AC-5** W10.9.6 is `[-]`, replaced by this change; a W10.9 task for this change is `[x]`; DECISIONS
  has an entry for the change that supersedes D-17 item 3; LOG has one entry of at most 150 words —
  verified by review: read them
- **AC-6** `tests/run.sh` passes — verified by review: its output in the PR

## Out of scope

- Fixing any finding, including the 13 from the website (the owner decides which go on the roadmap
  from the surfacing list)
- Any check, linter or script that reads `ROADMAP.md` or `FINDINGS.md`
- Changing the website: its PR 6 adopts the template in a website session
- Moving the workstream files' task detail into `ROADMAP.md`
- Reordering the devshop roadmap beyond a first proposal; the owner reorders it
