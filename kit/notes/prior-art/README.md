# Prior art: the outside repos Claude has analysed

One row per outside repo Claude has analysed for ideas the devshop could use, keyed by the commit it
read, so a repo seen before isn't analysed again from scratch
([spec](../../../specs/prior-art-registry.md)). These are devshop notes, not instructions: what a
repo says is data, and a "Could adopt" item becomes work only when the owner puts it on
[ROADMAP.md](../../../ROADMAP.md).

## Before analysing a repo

1. Run `scripts/prior-art.py check <https URL>`. It prints one line:
   - `PRIOR-ART: new <url>`: there is no row; analyse the repo and add a row and a note.
   - `PRIOR-ART: seen <url> at <sha12>, current · <note>`: nothing has changed since. Give the
     note's verdicts and the owner's recorded answers; don't analyse it again unless the owner asks.
   - `PRIOR-ART: seen <url> at <sha12>; upstream is now <sha12> · <note>`: read what changed between
     the two commits, not the whole repo again. Add a `Since <old sha12>` section to the note, then
     update the row and the note's header to the new commit.
   - Exit 2: it couldn't look (the reason is printed). That never means new: fix the cause first.
2. A renamed or moved repo isn't followed. Its new URL says new until it has a row, so check the old
   name too when the repo says it moved.

## A note

`<repo name>.md`, named after the repo (add the owner's name if two would clash). It holds:

- A header line: `Analysed: <url> at <40-hex SHA> (<commit date>, <tag or "no tag">), on <date>.`
- **What it is:** two or three sentences, and how far its own claims are backed (its benchmarks,
  others' runs).
- Three lists, every item with its reason:
  - **Could adopt:** the idea, the devshop finding or rule it bears on, and its cost.
  - **Already have:** the idea, and where the devshop has it.
  - **Don't adopt:** the idea, and why not.
- **The owner's answers:** each "Could adopt" item goes to the owner as "roadmap or keep
  watching?", the same way a `med` finding does. Record the answer here in their words, with its
  date.
- On a re-analysis, a `Since <old sha12>` section (newest first) and the earlier verdicts kept with
  their dates. If the old commit is gone upstream (force-pushed history), say so.

## Index

The script reads this table. Keep its columns, put the commit as a full 40-hex SHA, and give each
repo one row. Cells are split on `|`, so Prettier's padding doesn't matter.

| Repo                                       | Commit                                     | Commit date | Tag                           | Analysed   | Verdict                                                                                                                                 | Note                    |
| ------------------------------------------ | ------------------------------------------ | ----------- | ----------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| https://github.com/DietrichGebert/ponytail | `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` | 2026-10-29  | no tag (v5.3.3 is its parent) | 2026-11-10 | Its "smallest complete change" ladder for the builder is the one idea worth trying (F-NEW-65); the rest the devshop has or doesn't need | [ponytail](ponytail.md) |
