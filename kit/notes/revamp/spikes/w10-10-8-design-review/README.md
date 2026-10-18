# W10.10.8 spike: `/design-review` in build, on a scratch site

The proof for [specs/design-review-in-build.md](../../../../../specs/design-review-in-build.md)
(AC-5). Two runs of gstack's `/design-review` as `runtime/guidelines/ui.md` § Design review words
them, on a scratch site made from `runtime/templates/ui/`: a change with three planted breaks of the
site's `DESIGN.md`, and an honest change.

## Grading, fixed before the runs (2026-10-17)

Not changed after the runs. Each run is one fresh helper (a `general-purpose` agent) given only the
guideline section, the scratch repo, its local URL and its branch; it invokes `/design-review` and
returns gstack's report verbatim, every question it would have put to the owner, and the commits and
files it wrote.

**Planted run passes** when all three hold:

1. Its report names each plant as a departure from `DESIGN.md` (citing the file or the token it
   departs from): the font family `"Comic Neue", cursive` (`DESIGN.md` names only the system stack);
   the padding `13px` (off the 4 / 8 / 12 / 16 / 24 / 32 px scale); the colour `#ff00aa` (outside
   the palette). A finding that names the value without tying it to `DESIGN.md` does not count.
2. Its fix loop fixes all three in the branch: after the run, `notes.css` holds none of the three
   values, and each fix is a commit on the branch.
3. Rule 3 below.

**Honest run passes** when both hold:

1. Its report has no finding that calls a value on the changed page a departure from `DESIGN.md`
   (generic advice, AI-slop notes or a score below A don't count against it).
2. No commit changes a colour, font, spacing or radius value. Rule 3 below.

**Rule 3, both runs:** it puts no question to the owner, and writes none of the files the guideline
rules out (`TODOS.md`, `TESTING.md`, a `CLAUDE.md` edit, a `DESIGN.md` edit, a test framework
bootstrap); it sends nothing to Codex or another outside voice.

A run that can't start its browser, or reads outside its scratch repo, is a could-not-run: recorded,
and re-run once.

## The scratch site

Both repos start from the same `main`: `index.html` (the template's `example.html`), `base.css`,
`theme.js`, and [`DESIGN.md`](site/DESIGN.md) in gstack's spec format with the baseline's tokens.
Each change adds a "Notes" section to the page, styled by a new `notes.css`:

- **honest** ([`site/notes-honest.css`](site/notes-honest.css)): only the baseline's tokens;
- **planted** ([`site/notes-planted.css`](site/notes-planted.css)): the three breaks above.

`GSTACK_CHROMIUM_PATH=/opt/pw-browsers/chromium` is exported before every gstack browser call, in
place of the settings `env` the bootstrap writes (this session started before that change).

## Round 1 (2026-10-17): planted passes 1–2, honest fails 1, both needed an improvised browser step

Reports: [planted](outputs/r1-planted.md), [honest](outputs/r1-honest.md).

| Run     | Item 1                                                                                                                                                          | Item 2                                                                                                                                             | Rule 3                                                                                                                                             |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| planted | pass: FINDING-001 (font, "DESIGN.md: system font stack only"), 002 (`#ff00aa`, "No other colour appears"), 003 (`13px`, "not on the 4 px scale")                 | pass: commits `030b3a1`, `f231441`, `4dc1ba4`; `notes.css` holds none of the three values                                                         | met in what it did; but the skill's browser check printed `NEEDS_SETUP`, whose wording says to ask the owner and run `./setup`; the helper drove `$B` directly instead |
| honest  | **fail**: FINDING-003, headings at 700 against `DESIGN.md`'s 650. A true departure: the scratch `DESIGN.md` said 650 and `base.css` renders 700, a mistake in the fixture, not in the review. The planted run caught it too (FINDING-004) | pass: its one fix (`7facc68`, Notes uses `.card` and gains its shadow) changes no colour, font, spacing or radius value                            | as planted                                                                                                                                        |

Causes, fixed for round 2: the fixture's `DESIGN.md` now says `fontWeight: 700`, what `base.css`
renders; the guideline now says what to do on that `NEEDS_SETUP` (drive `$B` directly; never run
gstack's setup or ask; F-NEW-101). The grading above is unchanged. Round 2 re-runs both arms from
fresh scratch repos, one helper each, each started from its own repo's directory (round 1's helpers
shared the devshop repo as working directory, so gstack's per-repo browser daemon crossed over twice).

## Round 2 (2026-10-17): both pass

Reports: [planted](outputs/r2-planted.md), [honest](outputs/r2-honest.md). Fresh scratch repos,
the same grading.

| Run     | Item 1                                                                                                                                                               | Item 2                                                                                                                                          | Rule 3                                                                                                                                                         |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| planted | pass: FINDING-001 (font, "a font DESIGN.md doesn't name"), 002 (`#ff00aa`, "outside the palette", quoting `DESIGN.md`), 003 (`13px`, "off the 4px scale")               | pass: commits `d2f7738`, `a40713b`, `1d4056d`; `notes.css` holds none of the three values                                                      | pass: no question asked; `NEEDS_SETUP` handled as the guideline says; no ruled-out file written; nothing sent out                                              |
| honest  | pass: no finding calls a value a departure from `DESIGN.md` ("12 colours, all DESIGN.md/base.css tokens"; the font "the system stack DESIGN.md mandates")              | pass: its one fix (`2e9e551`, Notes uses `.card` and gains its shadow) changes no colour, font, spacing or radius value                         | pass, as planted                                                                                                                                               |

**What this shows and doesn't.** The skill, run by a fresh agent from the guideline alone, finds
planted departures from a spec-format `DESIGN.md`, fixes only the change's own lines in the
project's commit format, logs the rest, and runs without asking, once the browser check's false
`NEEDS_SETUP` is handled (F-NEW-101). It runs in about 5 to 7 minutes. Not shown here: the
website's own environment, the settings `env` reaching a session's shell (this session started
before the bootstrap change), and `FINDINGS.md` rows committed (a subagent's file write is refused
by the harness; a builder session writes them itself). gstack's telemetry consent question also
comes back on each run while its marker is unset; the guideline's "its questions don't go to the
owner" covered it. The website's first UI change after the merge is the live check.
