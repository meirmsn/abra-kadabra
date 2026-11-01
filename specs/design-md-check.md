# A `DESIGN.md` shape check in the fast tier

**Go:** pending

## Intent

Spec C of the UI tooling strategy the owner accepted on 2026-10-31 ("agree with your 4 recs"; the
order A, B, C, then D). The owner asked (2026-11-01): "C a `DESIGN.md` shape check in the fast
tier", where "Spec A's decisions name C's job: React stack homes derive their theme CSS by hand from
`DESIGN.md`'s tokens under the baseline's token names so one `tokens-check` covers both, and 'the
shape check that proves the derivation is the next change'". The spec must settle "what 'the shape'
is: the front matter keys the devshop relies on (colors with light and dark values, typography,
spacing, rounded), the decisions log, and the rule that the theme CSS's token values equal the front
matter's (the derivation), under the baseline's token names so `tokens-check.mjs` covers both";
"where it runs: a project's fast tier (`check-fast.sh`) and the devshop's own tests; what a project
without `DESIGN.md` gets (the baseline is the design: no check, or a pass that says so; say which and
why)"; "exit codes like the other UI checks: 0 pass, 1 findings, 2 can't judge (a missing file or
tool never passes)"; "every check is proven to fail: a known-bad `DESIGN.md` for each rule, and its
mutants killed, recorded under the PR's Evidence"; "the project contract and the upgrade's re-copy
list gain the new script as an optional `devshop` copy, like the two existing checks". Out of scope
by the owner's words: "the React home itself (D), the reviewer's prompt, any wall on design
findings". Surface: none; this change renders no page.

Why: today nothing proves that a project's theme CSS says what its `DESIGN.md` says. The reviewer
finds a value `DESIGN.md` doesn't name on the pages it browses, and `tokens-check.mjs` proves the
theme is whole and readable, but a theme that quietly drifts from the front matter (a colour tuned
in CSS and never written back, a dark value `DESIGN.md` never had) passes both. The shape check
closes that gap in the fast tier, before any browser.

## Decisions

- **The format the check reads is gstack's spec format as the devshop writes it**
  ([`ui.md`](../runtime/guidelines/ui.md) § Design direction; the two spike fixtures): YAML front
  matter between `---` lines, then a Markdown body. The front matter the devshop relies on: `colors`
  (a mapping of `<name>` to a colour, with the dark value under `dark-<name>`), `typography` (a
  mapping of roles, each with a `fontFamily`), `spacing` (a mapping of scale steps to lengths),
  `rounded` (a mapping with `default`). The `dark-<name>` convention and the `## Decisions` section
  are the devshop's, not gstack's (its `lib/design-md.ts` knows five token groups and eight
  canonical sections, none of them a decisions log or a dark mode); the guideline says so in one
  line, so a consultation run knows what to write. Rejected: a format of the devshop's own (the
  consultation writes gstack's, and `DESIGN.md` is the owner's file to read) (Claude's proposal,
  2026-11-01)
- **The shape, rule by rule,** each a finding with the rule's name and the key or token it is about,
  exit 1:
  - `front-matter`: the file opens with `---` and a closing `---` line; the YAML between them is
    block mappings of scalars (quoted or bare), comments and lists of scalars allowed. Anything
    else (flow style `{…}`/`[…]`, anchors, multi-line scalars, a tab indent) is can't judge, exit 2,
    naming the line: the check is one dependency-free file like its siblings, and that subset is
    exactly what gstack's emitter writes. A `{path}` reference (`"{colors.foreground}"`) resolves to
    its target's value; an unresolvable one is a finding.
  - `colors`: present, a mapping; every key is `<name>` or `dark-<name>`; each `<name>` has its
    `dark-<name>` (`colour-without-dark`) and each `dark-<name>` its `<name>` (`dark-without-light`);
    each value is a colour (`#…`, `oklch(`, `rgb(a)(`, `hsl(a)(`; `not-a-colour`); `background`,
    `foreground`, `primary`, `primary-foreground`, `muted-foreground` and `border` are named
    (`missing-colour`): the ground, the text, the action and its label, secondary text and edges,
    which every baseline page paints and `tokens-check.mjs` pairs. Light and dark are both
    required because `ui.md` makes a new colour get both.
  - `typography`: present; `body` has a non-empty `fontFamily` (`missing-font`); every role's
    `fontFamily`, where given, is a non-empty string. Sizes, weights and line heights are prose to
    the check: the baseline has no tokens for them.
  - `spacing`: present, at least one entry; keys `[a-z0-9-]+` (YAML quoting stripped), values
    lengths (`<number>(px|rem|em)`; `not-a-length`).
  - `rounded`: present, with `default`; values lengths.
  - `decisions`: the body has a `## Decisions` or `## Decisions Log` section with at least one
    non-blank line (`no-decisions`): the pick and its reasons live there (`ui.md` § Design
    direction).
  - The derivation, against the theme named by `--theme`, read as `tokens-check.mjs` reads it
    (`:root`; `:root[data-theme="dark"]`; `:root:not([data-theme="light"])` in
    `@media (prefers-color-scheme: dark)`; a theme of another shape is can't judge with the same
    words): `colors.<name>` equals `--<name>` in `:root`; `colors.dark-<name>` equals `--<name>` in
    both dark rules; `typography.body.fontFamily` equals `--font-sans`, `typography.mono.fontFamily`
    `--font-mono`, any other role `--font-<role>` (the guideline's dry run derived `--font-display`
    that way); `spacing.<k>` equals `--space-<k>`; `rounded.default` equals `--radius`, another key
    `--radius-<k>`. A token the theme lacks is `theme-missing-token`; a value that differs after
    `var()` and `{path}` are followed, whitespace collapsed, quotes unified and case folded, is
    `theme-differs`. The other way, `theme-not-in-design`: a `:root` or dark-rule token whose value
    is a colour, or whose name starts `--space-`, `--font-` or `--radius`, that the front matter
    doesn't name (its dark value under `dark-<name>`). The baseline's layout constants (`--tap`,
    `--measure`, `--page-max`, `--shadow`) are none of those shapes and stay the theme's.
    Rejected: one direction only, which lets a colour tuned in CSS and never written back pass
    (Claude's proposal, 2026-11-01)
- **Usage `node scripts/ui/design-md-check.mjs --theme <theme.css> <DESIGN.md>`,** exit 0 clean,
  1 findings, 2 can't judge (bad arguments, a missing or unreadable file, no front matter, YAML
  outside the subset, a theme of another shape); never a pass when it can't judge. The file is
  shipped executable (`#!/usr/bin/env node`) and the contract checks `executable`, unlike its two
  siblings (`file`), so the fast tier's part can name it (`part scripts/ui/design-md-check.mjs …`
  prints "scripts/ui/design-md-check.mjs failed", where `part node …` would print "node failed").
  Rejected: gstack's own `gstack-design-md.ts tokens` under the check (Bun and a gstack checkout
  aren't on a project's CI runner) (Claude's proposal, 2026-11-01)
- **Where it runs: the fast tier, only when the project has a `DESIGN.md`.** The template
  `runtime/templates/check-fast.sh` gains a design part after lint: a `THEME_CSS` variable the
  stack home fills (the theme CSS the pages load), then `if [ -f DESIGN.md ]`, the check as a
  `part` with `--theme "$THEME_CSS" DESIGN.md`; else one line, "no DESIGN.md: the baseline is the
  design (ui.md § Design direction)", and the tier's exit is untouched. The check itself exits 2 on
  a missing `DESIGN.md` path: it can't tell "no design yet" from a wrong path, and the tier can.
  So a project without `DESIGN.md` gets no check and a line that says why, not a pass: a pass
  would claim a derivation nobody made. With `DESIGN.md` present and `THEME_CSS` empty the check
  exits 2 and the tier can't run, which is the honest state. A seed: existing projects take the
  part when their `check-fast.sh` is next edited; the upgrade shows the template diff. Rejected:
  running on every project with a synthetic `DESIGN.md` of the baseline (the baseline is the design
  there, and the file would be a brand nobody chose) (Claude's proposal, 2026-11-01)
- **The devshop's own proof:** `tests/ui-design-md-check.test.sh` (fast tier) feeds the check a
  known-bad `DESIGN.md` or theme per rule, each named above, the can't-judge inputs, and two good
  pairs: a fixture pair under `tests/fixtures/design-md/` written for the test, and a `DESIGN.md`
  that names every token of the real `runtime/templates/ui/base.css`, so the baseline itself is
  shown derivable. The PR's Evidence records each rule's mutant (its finding line removed or its
  comparison inverted) and the test case that killed it. Rejected: reusing the spike fixtures as
  inputs (they are records, and their `colors` lack dark values for half the names, a finding
  under this check) (Claude's proposal, 2026-11-01)
- **The contract and the manifest:** `runtime/project-contract.txt` gains
  `scripts/ui/design-md-check.mjs` (owner `devshop`, `optional`, check `executable`), and
  `runtime/project-files.txt` the matching `optional` line, which is the upgrade's re-copy list;
  the `DESIGN.md` item's `must` and `for` name the check. No stack `supplies` change: `DESIGN.md`
  is optional on every stack, and so is its check (Claude's proposal, 2026-11-01)
- **Docs, all in files this change owns:** `ui.md` § The baseline names three copies and § Checks
  gains the shape check's fast-tier line; `design.md` § `DESIGN.md` first says the theme's
  derivation is checked by it and what the devshop adds to gstack's format, and § Done item 1
  names it; `runtime/guidelines/README.md` and `docs/README.md` name the check and its test. No
  edit to a shipped spec (`ui-baseline.md`, `project-contract.md`, `design-guideline.md`): a dated
  note there made the reviewer take the spec as the change's (LOG #95) (Claude's proposal,
  2026-11-01)
- **Not here:** the React home (D); `runtime/reviewer/`; a wall on design findings; wiring
  `tokens-check.mjs` into the template (its file list is the stack home's); the stack homes'
  `supplies`; gstack's `components` group, `{path}` references outside the four groups, and the
  prose sections' content; a check that `DESIGN.md`'s fonts are self-hosted (the reviewer's
  browser sees that)

## Acceptance items

- **AC-1** `runtime/templates/ui/design-md-check.mjs --theme <theme.css> <DESIGN.md>` exits 1,
  naming the rule and the key, on each known-bad `DESIGN.md`: a colour without its dark value, a
  dark value without its light, a value that isn't a colour, a required colour missing, no
  `typography.body.fontFamily`, a spacing or rounded value that isn't a length, no `spacing`, no
  `rounded.default`, no `## Decisions` section, an empty one, and a `{path}` reference to nothing
- **AC-2** The derivation: it exits 1 naming the token when the theme lacks a front-matter token,
  when a light value differs in `:root`, when a dark value differs in either dark rule, when a font
  family differs from `--font-sans`, `--font-mono` or `--font-<role>`, when a spacing step or the
  radius differs, and when the theme declares a colour, a `--space-*`, a `--font-*` or a
  `--radius*` token the front matter doesn't name; it exits 0 when the values match through `var()`
  and `{path}` references, whitespace, quote style and case
- **AC-3** It exits 2, never 0, with no arguments, without `--theme`, on a missing `DESIGN.md`, a
  missing theme, a `DESIGN.md` with no front matter or an unclosed one, front matter outside the
  block-mapping subset (flow style, an anchor, a tab indent), and a theme of another shape (no
  `:root`, no dark rules, custom properties in another block)
- **AC-4** The fixture pair under `tests/fixtures/design-md/` passes (exit 0), and a `DESIGN.md`
  naming every token of `runtime/templates/ui/base.css` passes against it
- **AC-5** `runtime/templates/check-fast.sh`, as a project copies it: with a `DESIGN.md` present it
  runs `scripts/ui/design-md-check.mjs --theme <THEME_CSS> DESIGN.md` as a part whose exit 1 fails
  the tier and exit 2 makes it can't run, with the other parts still run; without one it prints the
  "no DESIGN.md" line and the tier's exit is unchanged
- **AC-6** `runtime/project-contract.txt` has `scripts/ui/design-md-check.mjs` as an optional
  `devshop` item checked `executable`, `runtime/project-files.txt` the matching `optional` entry,
  and `tests/contract-check.test.sh` holds them together and counts the item
- **AC-7** `ui.md` § The baseline and § Checks, `design.md` § `DESIGN.md` first and § Done,
  `runtime/guidelines/README.md`, `docs/README.md` and the contract's `DESIGN.md` item name the
  check as decided; `scripts/docs-map-check.py` passes; no file under `specs/` other than this one
  changes — verified by review: the diff and CI on the PR's head
- **AC-8** `tests/run.sh fast` passes with the new test file in it, and the PR's Evidence lists each
  rule's mutant and the case that killed it — verified by review: the Evidence section and CI on
  the PR's head
- **AC-9** `kit/notes/revamp/LOG.md` has an entry, and `kit/notes/revamp/workstreams/W10-v2.md`
  W10.8.3 carries a dated note that the shape check landed and the home at M3 wires it — verified
  by review: the diff

## Out of scope

- The React home's defaults and its library pin (D, M3), and wiring the check into any existing
  project's `check-fast.sh` (the upgrade shows the template's diff; the stack home's next change
  takes it)
- `runtime/reviewer/` (prompt, `review.sh`, eval) and any wall: the check is CI feedback in a
  project's fast tier, not a branch protection
- Wiring `tokens-check.mjs` into the template's fast tier, and the stack homes' `supplies`
- gstack's `components` token group, references outside the four groups, the prose sections'
  content, fonts' self-hosting, contrast (that is `tokens-check.mjs`'s)
- A `DESIGN.md` in gstack's legacy format (headings, no front matter): can't judge, with the line
  that says so
