# A registry of the outside repos Claude has analysed

**Go:** "go" (owner, 2026-11-10)

## Intent

The owner, 2026-11-10, asking for an analysis of an outside repo: "check if we have already analyzed
this repo, and if you cannot find it, we should have a registry of repos that we have that we
analyze, and I'm guessing the version or date and or fingerprint or something, so that if I keep
when so that when we analyze again, we know if we already seen it or if we saw a previous version,
so that we don't have to keep redoing this analysis. Potentially we could have a summary of the
insights of which ones we think at the time that we could integrate and why, and the ones which
should not integrate and why."

Today nothing records an outside repo's analysis. A search of the repo for the one the owner asked
about found nothing, so each analysis is redone and its conclusions are lost with the chat. The
analysis itself goes to the owner in chat now. This change records it as the first entry.

## Decisions

- **The fingerprint is the commit:** each entry records the full 40-hex SHA of the default-branch
  commit Claude analysed. For people to read, it also records that commit's date and the tag that
  points at it, or "no tag". A SHA names exact content. A date or a tag does not: a day has many
  commits, and a tag can move. Rejected: a date or a version number as the key (Claude, 2026-11-10;
  the owner's go, 2026-11-10)
- **Where:** `kit/notes/prior-art/`, as devshop-only notes, not in `runtime/`, because projects don't
  analyse outside repos yet. Rejected: a section of `lessons.md`, which would mix harvested lessons
  with verdicts on third-party code (Claude, 2026-11-10; the owner's go, 2026-11-10)
- **One index, one note per repo:** `kit/notes/prior-art/README.md` holds the format and the table.
  Each row has the repo's URL, the SHA, the commit date, the tag, the date analysed, a one-line
  verdict and a link to the note. A re-analysis updates the same row and note: the note gets the new
  SHA and a "Since <old sha12>" section on what changed, and keeps the earlier verdicts with their
  dates. If the old SHA is gone upstream (force-pushed history), the note says so (Claude, 2026-11-10;
  the owner's go, 2026-11-10)
- **Every insight goes in one of three lists, each item with its reason:**
  - "Could adopt", naming the devshop finding or rule it bears on
  - "Already have", saying where
  - "Don't adopt"

  A "Could adopt" item goes to the owner as "roadmap or keep watching?", the same way a `med` finding
  does. The owner's answer is written back into the note with its date. Only the owner puts work on
  `ROADMAP.md` (Claude, 2026-11-10; the owner's go, 2026-11-10)

- **The check is a tested script:** `scripts/prior-art.py check <url> [--index <path>]`, with the
  index defaulting to `kit/notes/prior-art/README.md`. It writes one line to stdout and exits 0:
  - `PRIOR-ART: new <url>`
  - `PRIOR-ART: seen <url> at <sha12>, current · <note path>`
  - `PRIOR-ART: seen <url> at <sha12>; upstream is now <sha12> · <note path>`

  It reads upstream's head with `git ls-remote <url> HEAD`, without a clone. It sets
  `GIT_TERMINAL_PROMPT=0` and gives up after 30 seconds. It accepts `https://` URLs and, so that
  tests never touch the network, local paths and `file://`. Any other form, including `http://` and
  `git@host:`, is exit 2. URLs match when they differ only in the case of the host or the path, a
  trailing `.git` or a trailing `/`. GitHub treats owner and repo names as case-insensitive. It
  parses table cells by the `|` separators, so Prettier's padding doesn't matter (CLAUDE.md:
  mechanical steps live in tested scripts). The owner kept the script over a table alone: "2. yes keep" (owner, 2026-11-10)

- **A renamed or moved repo is a known limit:** the old URL says "seen", while the new one says
  "new" until a row is added for it. The script doesn't follow redirects: "3. ok" (owner, 2026-11-10)
- **Outside repos are named:** CLAUDE.md's no-identifiers rule gains one exception: a third-party
  public repo's URL, in `install/*.pin` and `kit/notes/prior-art/`. The owner's projects and people
  stay out of these notes, as they do everywhere else. The rule lists the README as its only
  exception today: "1. OK" (owner, 2026-11-10)

## Acceptance items

- **AC-1** For a URL with no row in the index, `scripts/prior-art.py check` prints
  `PRIOR-ART: new <url>` and exits 0
- **AC-2** For a URL whose row's SHA equals upstream's `HEAD`, it prints
  `PRIOR-ART: seen <url> at <sha12>, current · <note path>` and exits 0
- **AC-3** For a URL whose row's SHA differs from upstream's `HEAD`, it prints
  `PRIOR-ART: seen <url> at <sha12>; upstream is now <sha12> · <note path>` and exits 0
- **AC-4** URLs that differ only in the case of the host or path, a trailing `.git` or a trailing
  `/` match the same row
- **AC-5** The following exit 2 with the reason and never print `new`:
  - an unreachable or unknown remote
  - a remote with no `HEAD`
  - a URL form the script doesn't accept
  - a missing index
  - a malformed row: a SHA that isn't 40 hex, or a missing cell
  - two rows that normalise to the same URL
- **AC-6** The index still parses after Prettier formats it
- **AC-7** `docs/README.md` links `kit/notes/prior-art/README.md` and this spec, and has a Layout row
  for `kit/notes/prior-art/`. The index links each note, and the docs-map check passes
- **AC-8** The first entry exists: an index row for the repo named in the Intent, and its note with
  the three lists, each item with a reason. `check` prints `seen` for it, current or not, and the
  note's SHA matches the row — verified by review: read the note and run
  `scripts/prior-art.py check` on its URL
- **AC-9** CLAUDE.md has one line saying to run the check before analysing an outside repo and to
  update the entry after, pointing to the index for the procedure. Its identifiers rule names the
  exception above — verified by review: the two lines in CLAUDE.md

## Out of scope

- Analysing repos the owner hasn't asked about, or re-analysing on a schedule
- Diffing the old commit against the new one automatically: the script says a newer version exists,
  and reading what changed is the analysis
- Adopting any of the first entry's "Could adopt" items
- Registries in projects (`runtime/`)
