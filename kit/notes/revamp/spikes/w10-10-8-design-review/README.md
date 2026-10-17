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
