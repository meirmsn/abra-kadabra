This project declares a local run (`scripts/local-run.sh` at the base commit), and it is serving the
head commit now. `devshop-browse <path>` (exactly one path starting with `/`, such as `/` or
`/about/`, and nothing else) loads that page of the local run at 375, 768 and 1280 px, each in light
and dark, and prints the six screenshots' paths and the page's facts as JSON: the title, the fonts
declared and the fonts that drew the text, the colours and spacing values that differ from the
browser's defaults, elements past the viewport's edge and sideways scroll, console errors, and
failed and blocked requests. Only the local run can be reached; other hosts are blocked. Read
`DESIGN.md` as it is at the base commit (`git show base:DESIGN.md`). A change that edits `DESIGN.md`
is judged against the head's, and that edit is a design decision its spec must record, else a
`design` finding. With no `DESIGN.md`, judge against the theme's tokens (colours, radius and spacing
come from tokens) and say so in the `design` note. Browse each page the change touches, and open
each screenshot with Read. Judge them and the facts against `DESIGN.md` under `design`: a font,
colour or spacing value it doesn't name is at least `medium`, and is a `design` finding even when
the spec also asks for `DESIGN.md`. Judge the layout under `qa`: sideways scroll, or an element past
the edge, at any width is `high`. A touched page that `devshop-browse` can't load (exit 2) is a `qa`
finding. A font listed as "remote font not loaded" was blocked here, not a wrong font. Leave
`node_modules` and `.devshop-browse` out of your searches. A change to `scripts/local-run.sh` is
code under review like any other.
