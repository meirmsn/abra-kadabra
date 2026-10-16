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
- **Log, don't suppress, and don't fix on reflex:** something noticed is fixed in this change only
  when the task needs it or it sits in lines the change already edits. Anything else, a reviewer
  `low` finding left unfixed included, is a row in `FINDINGS.md`, or a new sighting on the row it
  matches. This replaces W10.9.6's filing rule ("file only what blocked"), D-17 item 3, PROCESS
  § 4's "small issue in code you're touching: fix it" and the `pr` skill's "unless one is clear,
  quick and important". The bloat came from grading every row, linting the file and fixing on
  reflex, not from logging one line (owner, 2026-10-16)
- **A findings row:** `| ID | Severity | What was noticed | Seen |`. Severity is `high` (it can
  break production, lose data or open a security hole), `med` (it costs time on a common path or
  on every change) or `low` (anything else). Seen holds one `date · where` per session that hit it,
  so a repeat adds a line, not a row. No size, risk, leverage or status columns: a row in the file
  is open. A row is deleted, with git history as its record and the reason in the commit, when it
  is fixed, moved to the roadmap, or can no longer happen (what it was about is gone). Rejected: the
  grades the earlier session proposed (severity, size, risk, repeat count, status), as ceremony
  (owner, 2026-10-16)
- **Surfacing, at most twice per row:** when a session hands over (in the PR body's findings line
  and the chat message with the PR's link), it lists a row it logged as `med` or `high`, and any row
  whose sightings just reached 3, and asks for each: "roadmap or keep watching?". Nothing else is
  ever surfaced. "Roadmap" deletes the row and adds a roadmap entry; "keep watching", or no answer,
  leaves it (owner's rule, 2026-10-15, bounded against noise)
- **A roadmap entry:** a table `| ID | Added | What | Status |`, then a section per `Open` entry that
  quotes the owner's request word for word in a fenced `text` block. IDs are `R-<n>`, never reused.
  Status is `Open`, `Done` (with the PR) or `Dropped` (with the reason). A closed entry keeps its
  table row as a one-line record and loses its section, because the spec quotes the request from
  then on. The table's order is the priority; the top `Open` entry is next. This is the website's
  draft (its PR 6) without `In progress`, which the open PR shows. Rejected: an explicit "next"
  marker (owner, 2026-10-16)
- **Where each kind goes:** about the project: its own files. About the devshop: only the devshop's
  files. A project session never records a devshop finding in the project. At hand-over it lists
  them, one plain line each (what happened, where), in one block the owner pastes into a devshop
  session, which matches and logs them under the same rules. A repeat of something already on a
  roadmap is not logged; Claude mentions it only if it makes the entry more urgent
- **When a devshop fix will change the project:** the project does nothing ahead of it. The upgrade
  PR that brings the fix carries what the project must adapt (`devshop:upgrade`). Only when the
  project is blocked today does it get a local workaround, labelled as a mitigation and naming the
  devshop finding's ID, which that upgrade removes. Rejected: applying the devshop's future change
  in the project now (the project would depend on a devshop change that may not land as planned)
- **The records change only through a change's PR, and its body says so:** a row or entry known
  before `ship` goes in that PR, and the body's findings line names it, so the reviewer reads it as
  part of the change. A record known only after `ship` (the reviewer's `low` findings on a pass,
  the owner's answer to the surfacing list) is posted by the session as a PR comment headed
  "For the records", and the project's next change writes every such comment on PRs merged since
  `FINDINGS.md` and `ROADMAP.md` last changed. _Mitigation:_ the root cause is that any commit
  after the reviewer's pass costs a full review; letting the reviewer pass a records-only commit
  is a reviewer change, logged as F-NEW-93 for the owner to
  place. A new request the owner wants "on the roadmap"
  is its own small PR with no spec (no choice is involved, so the reviewer's `intent` lens passes
  it)
- **Parallel sessions:** before `ship`, the session merges the latest `main` and takes the next free
  `F-` or `R-` number from it; a clash in the table is resolved by renumbering its own row
- **The devshop's own files move to its root:** `ROADMAP.md` lists the devshop's open work in
  priority order, one line each linking to the task's detail in `kit/notes/revamp/workstreams/`,
  and replaces "the first unblocked `[ ]` task" as how the next task is picked (CLAUDE.md, PROCESS
  § 1). `kit/notes/revamp/FINDINGS.md` becomes a frozen archive (its Watch list and Grades as they
  are) so the IDs that `lessons.md` and the notes cite still resolve. Today's Fix queue goes:
  F-NEW-73 to the archive's Closed (shipped in PR #122); F-NEW-63 to Closed, held by W10.10.1
  (the website's environment allows its hosts) and W10.10.2; F-NEW-70 to Closed, held by W10.9.1;
  F-NEW-75 to Closed, held by W10.10.5; F-NEW-42, 77, 78 and 79 to the root `FINDINGS.md` in the
  new row format (42's pre-merge health check is deferred, not on the roadmap). Devshop IDs carry
  on as `F-NEW-<n>`; project IDs start at `F-1`
- **The 13 findings from the website's first change** (owner's messages, 2026-10-15) become
  F-NEW-80 to F-NEW-92, in the owner's order: (1) slow-tier proofs delete meta tags with line-wise
  `sed`, which breaks once Prettier wraps them; (2) the page check fetched `og:image` from
  production; (3) fonts weren't a byte-budget kind; (4) acceptance items true only after merge
  block the reviewer; (5) `spec-check.py` rejects any mention of a removed AC id; (6) the PR body
  check needs the exact `**Preview:** none —` form; (7) the spec review should check new variables
  and outputs are wired end to end; (8) gstack's design skills don't run in a cloud session (an
  OpenAI key, a board on 127.0.0.1, Chromium blocked); (9) a skipped question is not "no
  preference"; (10) `tests/run.sh` changes directory, so repo-relative tests must `cd` back; (11)
  the UI guideline doesn't ask to prove the blocked-fonts state; (12) the spec review can be
  skipped and nothing notices; (13) `spec-check.py` matches AC ids per spec, so a second spec's
  items count as tested. Findings 1, 2, 3, 10 and 11's stack-home part are also named in W10.10.2's
  line, as content for the Cloudflare stack home
- **Where Claude reads the rule:** the templates `runtime/templates/findings.md` and
  `runtime/templates/roadmap.md` carry it in a comment; a project creates each file from its
  template on its first entry (not listed in `project-files.txt`: an empty file in every project is
  what Shape 3 avoids). The skills say when: `build` § 3 logs what the task doesn't need and § 1
  writes the "For the records" comments; `pr` § 3 surfaces and writes the devshop block; `intent`
  § 1 records "later" requests on the roadmap and answers "what's next?" with the top `Open`
  entry. PROCESS § 4, TARGET Shape 8 and Ship 9 are rewritten to say the same and link the
  templates
- No check reads either file (CLAUDE.md: prose and notes need none; the dropped findings linter
  was the bloat)

## Acceptance items

- **AC-1** `runtime/templates/findings.md` and `runtime/templates/roadmap.md` exist, each with the
  table header from the Decisions and a comment stating the rules above: what goes in, severity,
  sightings, surfacing, deletion, statuses, order, numbering — verified by review: read both
  templates against the Decisions
- **AC-2** The `build`, `pr` and `intent` skills say the steps from "Where Claude reads the rule",
  and no live rule still says a finding is filed only when it blocked the task — verified by
  review: read the three skills, and grep `runtime/`, `CLAUDE.md` and `kit/notes/revamp/` (the
  archive, LOG and REVIEW files aside) for "only when it blocked" and "only if it blocked"; none is
  found
- **AC-3** The devshop has `ROADMAP.md` and `FINDINGS.md` at its root in the templates' format.
  The roadmap holds every open (`[ ]` or `[~]`) W10 task but W10.9.6, and the PLAN.md § After the
  revamp items, each linking to its detail. The findings hold F-NEW-42, F-NEW-77 to F-NEW-93 and
  nothing else, 80 to 92 matching the list in the Decisions — verified by review: compare with the
  W10 file and the Decisions
- **AC-4** Every row of today's Fix queue has the destination the Decisions give it, and
  `kit/notes/revamp/FINDINGS.md` says it is frozen. `CLAUDE.md`, PROCESS § 1 and § 4, TARGET
  Shape 8 and Ship 9 (rewritten, not patched) and the revamp README's file map say the new rule and
  point at the root files — verified by review: read them
- **AC-5** W10.9.6 is `[-]`, replaced by this change; a W10.9 task for this change is `[x]`;
  DECISIONS has an entry for the change that supersedes D-17 item 3; LOG has one entry of at most
  150 words — verified by review: read them
- **AC-6** `tests/run.sh` passes — verified by review: its output in the PR

## Out of scope

- Fixing any finding, the 13 from the website included (the owner decides which go on the roadmap
  from the surfacing list)
- The reviewer passing a records-only commit without a full review (F-NEW-93)
- Any check, linter or script that reads `ROADMAP.md` or `FINDINGS.md`
- Changing the website: its PR 6 adopts the template in a website session
- Moving the workstream files' task detail into `ROADMAP.md`
- Reordering the devshop roadmap beyond a first proposal; the owner reorders it
