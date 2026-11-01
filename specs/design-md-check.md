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

- **`DESIGN.md`'s token keys are the baseline's token names.** gstack's `/design-consultation`
  writes its own slugs (`primary`, `on-primary`, `surface`, `text`, `text-muted`; `rounded`
  `sm`/`md`/`lg`/`full`; `spacing` `xs`…`2xl`; roles `display`/`body`/`label`/`mono`; one face per
  `fontFamily`) and knows no dark mode and no decisions log (its `lib/design-md.ts`: five token
  groups, eight canonical sections). The devshop's `DESIGN.md`, as the three spike fixtures already
  write it, keeps gstack's file shape (front matter between `---` lines, a Markdown body) and
  renames inside it: `colors` keys are the baseline's (`background`, `foreground`, `primary`,
  `card`, …), the dark value of `<name>` is `dark-<name>`, `spacing` keys are the baseline's steps
  (`1`, `2`, `4`, …), `rounded` has `default`, each `fontFamily` carries the full stack the theme
  declares, colours are in the theme's colour space, and the body has a `## Decisions` section. So
  the derivation is `name` → `--name` with no mapping table, and the reviewer, `tokens-check.mjs`,
  this check and the builder read one vocabulary. The design-direction slice does the renaming when
  it lands `DESIGN.md` and the theme in one PR; `ui.md` § Design direction's "as the skill writes
  it" bullet gains the clause that says so (one clause; spec A left that section to the slices
  change, and this is the first change since with a reason to touch it). Rejected: reading a mapping
  from `DESIGN.md` (a second vocabulary for the reviewer and the builder to hold, and a devshop
  extension to gstack's format either way) (Claude's proposal, 2026-11-01; **owner's call at the
  go**)
- **The shape, rule by rule.** Each finding is one stdout line
  `design-md-check: <rule>: <message naming the key or token>`, then a count line, exit 1, as
  `tokens-check.mjs` prints; can't judge is one stderr line `design-md-check: can't judge: …`, exit 2.
  - `front-matter`: after a byte-order mark and CRLF line endings are dropped (as gstack's reader
    does), the file opens with `---` and the next line that is only `---` (trailing spaces allowed)
    closes the front matter; none is can't judge. The YAML between is read by the check's own
    reader for this subset: block mappings to any depth; bare scalars; single- and double-quoted
    scalars with the double-quoted form's escapes; `>` and `|` block scalars; lists of scalars; a
    `#` comment on its own line or after a space. A flow mapping or list (`{…}`, `[…]`), an anchor
    or alias, a tag, a tab indent, or a line the reader can't place is can't judge naming the line.
    Not "what gstack's emitter writes": the consultation's file is written by the model from a
    Markdown template, whose colour lines carry trailing comments and whose `description` may be a
    block scalar, so those are in the subset. A duplicate key in one mapping is a finding
    (`duplicate-key`). A `{path}` reference (`"{colors.foreground}"`) resolves to its target's
    value, up to ten hops; one that resolves to nothing is `bad-reference`.
  - `colors`: present and a mapping (`missing-group`, `not-a-mapping`); every key
    `[a-z0-9-]+` (`bad-key`); each `<name>` has `dark-<name>` (`colour-without-dark`) and each
    `dark-<name>` has `<name>` (`dark-without-light`), since `ui.md` makes a new colour get both;
    each value is hex or `oklch()`, the two forms `tokens-check.mjs` reads (`not-a-colour`;
    `rgb()`, `hsl()` or a named colour would pass here and make the sibling can't judge);
    `background`, `foreground`, `primary`, `primary-foreground`, `muted-foreground` and `border`
    are named (`missing-colour`): the ground, the text, the action and its label, secondary text
    and edges, which every baseline page paints.
  - `typography`: present, a mapping of roles (`missing-group`, `not-a-mapping`); `body` has a
    non-empty `fontFamily` (`missing-font`); every role's `fontFamily`, where given, is a non-empty
    string (`empty-font`); a role named `sans` is `bad-key` (that name is `body`'s token). Sizes,
    weights, line heights and letter spacing are prose to the check: the baseline has no tokens for
    them.
  - `spacing`: present, a mapping, at least one entry (`missing-group`, `not-a-mapping`,
    `empty-group`); keys `[a-z0-9-]+` after YAML quoting (`bad-key`); values a length:
    `<number>(px|rem|em|%)` or `0` (`not-a-length`).
  - `rounded`: present, a mapping with `default` (`missing-group`, `not-a-mapping`,
    `missing-default`); values lengths (`not-a-length`).
  - `no-decisions`: the body has a `## Decisions` or `## Decisions Log` heading (case-insensitive,
    outside code fences, `##` only) with at least one non-blank line under it; the pick and its
    reasons live there (`ui.md` § Design direction).
  - **The derivation,** against the theme named by `--theme`, read as `tokens-check.mjs` reads it
    (`:root`; `:root[data-theme="dark"]`; `:root:not([data-theme="light"])` in
    `@media (prefers-color-scheme: dark)`; a theme of another shape is can't judge with the sibling's
    three messages: no `:root` with tokens, a dark rule missing, custom properties in another
    block). `colors.<name>` equals `--<name>` in `:root`; `colors.dark-<name>` equals `--<name>` in
    both dark rules; `typography.body.fontFamily` equals `--font-sans`, `typography.mono.fontFamily`
    `--font-mono`, any other role `--font-<role>` (the guideline's dry run derived `--font-display`
    that way); `spacing.<k>` equals `--space-<k>`; `rounded.default` equals `--radius`, another key
    `--radius-<k>`. Equality is of the whole value as text, after `var()` in the theme and `{path}`
    in the front matter are followed, whitespace collapsed, case folded, and quotes around a font
    family name removed (`'Instrument Serif'`, `"Instrument Serif"` and a bare name are one): the
    slice copies values verbatim between the two files, so `0.50` against `0.5` or hex against
    `oklch()` is a real difference (`theme-differs`). A token the theme lacks is
    `theme-missing-token`.
  - **The other way, `theme-not-in-design`:** a token in `:root` or a dark rule that the front
    matter doesn't name (a dark rule's `--<name>` is named by `dark-<name>`) when its value is a
    colour by shape, hex, `oklch()`, `rgb()`/`hsl()`, `lab()`/`lch()`/`color()`/`color-mix()` or a
    CSS named colour (broad on purpose: a `--card: white` tuned in CSS is what this rule is for),
    or its name starts `--space-` or `--radius`, or its name starts `--font-` and its value is a
    family list (a comma, a quoted name or a generic family: `serif`, `sans-serif`, `monospace`,
    `system-ui`, `ui-monospace`, `ui-serif`, `ui-sans-serif`, `cursive`, `fantasy`; a weight or
    size under a `--font-*` name is not). A token whose value is `var(--other)` and resolves to a
    token the front matter names is derived, not a finding, as `tokens-check.mjs` treats aliases.
    The cost, said plainly: every literal colour in the theme is in `colors` with its `dark-` pair
    (a baseline-shaped theme has 19), or is a `var()` alias; `--tap`, `--measure`, `--page-max` and
    `--shadow` (a shadow list, not a colour by shape) stay the theme's. This direction is the
    spec's addition to the owner's "values equal", and the reason is the Why above. Rejected: one
    direction only, which lets a colour tuned in CSS and never written back pass (Claude's
    proposal, 2026-11-01; **owner's call at the go**)
- **Usage `scripts/ui/design-md-check.mjs --theme <theme.css> <DESIGN.md>`,** exit 0 clean, 1
  findings, 2 can't judge (bad arguments, `--theme` with an empty or missing value, a missing or
  unreadable file, no front matter, YAML outside the subset, a theme of another shape, a `DESIGN.md`
  in gstack's legacy format or any other prose shape); never a pass when it can't judge. The file
  is shipped executable (`#!/usr/bin/env node`) and the contract checks `executable`, unlike its two
  siblings (`file`), so the fast tier's part can name it (`part scripts/ui/design-md-check.mjs …`
  prints "scripts/ui/design-md-check.mjs failed", where `part node …` would print "node failed").
  One dependency-free file like its siblings: the theme reader (`rules()`, `decls()`, the three
  selectors) is a second copy of `tokens-check.mjs`'s, accepted duplication whose root cause is
  that the siblings export nothing and run at import; the copy keeps the sibling's can't-judge
  words. Rejected: gstack's own `gstack-design-md.ts tokens` under the check (Bun and a gstack
  checkout aren't on a project's CI runner) (Claude's proposal, 2026-11-01)
- **Where it runs: the fast tier, only when the project has a `DESIGN.md`.** The template
  `runtime/templates/check-fast.sh` gains a design part after lint: a `THEME_CSS` variable with a
  comment (the theme CSS the pages load, which `DESIGN.md`'s tokens derive; the stack home names
  the file in its own change, not this one), then `if [ -f DESIGN.md ]`, the check as a `part` with
  `--theme "$THEME_CSS" DESIGN.md`, no guard on the copy's presence; else one line, "no DESIGN.md:
  the baseline is the design (ui.md § Design direction)", and the tier's exit is untouched. So a
  project without `DESIGN.md` gets no check and a line that says why, not a pass: a pass would
  claim a derivation nobody made. With `DESIGN.md` present and the copy absent, bash's 127 makes the
  part "couldn't run", exit 2; with `THEME_CSS` empty the check exits 2 saying `--theme` names no
  file; both are the honest state, never a skip (the lint part's `[ -x ]` guard is not copied: lint
  is the stack's and may not exist, the derivation must). The check itself exits 2 on a missing
  `DESIGN.md` path: it can't tell "no design yet" from a wrong path, the tier can. A `DESIGN.md`
  that is a symlink passes `[ -f ]` and fails the contract check in the same tier. A seed: existing
  projects take the part when their `check-fast.sh` is next edited; the upgrade shows the template
  diff. Rejected: a synthetic `DESIGN.md` of the baseline for every project (the baseline is the
  design there, and the file would be a brand nobody chose); rejected for scope: running
  `tokens-check.mjs` from the same part (its file list is the stack home's; spec A paired that
  wiring with the stack homes) (Claude's proposal, 2026-11-01; **owner's call at the go on the
  second**)
- **The devshop's own proof:** `tests/ui-design-md-check.test.sh` (fast tier; every case prints
  `design-md-check AC-<n>`) feeds the check a known-bad `DESIGN.md` or theme per rule named above,
  the can't-judge inputs, and two good pairs committed by hand under `tests/fixtures/design-md/`,
  never generated at test time: `baseline/DESIGN.md`, naming every token of the real
  `runtime/templates/ui/base.css` and checked against it, so the baseline is shown derivable and a
  `base.css` edit without its `DESIGN.md` line fails this test on purpose; and `ledger/` (a
  `DESIGN.md` with a display face, `{path}` references and `var()` aliases, and its theme). The
  fixtures are linked from `docs/README.md` (the docs map counts every tracked Markdown file).
  `tests/check-fast-template.test.sh` gains the design part's cases and
  `tests/contract-check.test.sh` the new item (its counts: 26 items, 12 optional). The PR's
  Evidence records each rule's mutant (its finding line removed or its comparison inverted) and
  the case that killed it. Rejected: the spike fixtures as inputs (they are records, and their
  `colors` lack dark values for half the names, a finding under this check) (Claude's proposal,
  2026-11-01)
- **The contract and the manifest:** `runtime/project-contract.txt` gains
  `scripts/ui/design-md-check.mjs` (owner `devshop`, `optional`, check `executable`), and
  `runtime/project-files.txt` the matching `optional` line, which is the upgrade's re-copy list;
  the `DESIGN.md` item's `must` and `for` name the check. The contract test's template scan then
  requires the template's new path to be an item, which it is. No stack `supplies` change:
  `DESIGN.md` is optional on every stack, and so is its check (Claude's proposal, 2026-11-01)
- **Docs, in files this change owns:** `ui.md` § The baseline names three copies, § Checks gains
  the shape check's fast-tier line, § Design direction's "as the skill writes it" bullet gains the
  renaming clause; `design.md` § `DESIGN.md` first says the derivation is checked and what the
  devshop adds to gstack's format, and § Done item 1 names the check, within spec A's cap of 120
  lines and 1200 words; `runtime/guidelines/README.md` and `docs/README.md` name the check, its test
  and the fixtures. No edit to a shipped spec (`ui-baseline.md`, `project-contract.md`,
  `design-guideline.md`): a dated note there made the reviewer take the spec as the change's
  (LOG #95) (Claude's proposal, 2026-11-01)
- **Not here:** the React home (D); `runtime/reviewer/`; a wall on the design review's findings
  (this check blocks through required CI like every fast-tier part, which is what the owner asked
  for); wiring `tokens-check.mjs` into the template (unless the owner says so at the go); the stack
  homes' `supplies` and READMEs; gstack's `components` group, `{path}` references outside the four
  groups, and the prose sections' content; a check that `DESIGN.md`'s fonts are self-hosted (the
  reviewer's browser sees that); contrast (`tokens-check.mjs`'s)

## Acceptance items

- **AC-1** `runtime/templates/ui/design-md-check.mjs --theme <theme.css> <DESIGN.md>` exits 1 with
  a `design-md-check: <rule>:` line naming the key, on each known-bad `DESIGN.md`: a duplicate key,
  a reference to nothing, a token group missing or not a mapping, a bad key, a colour without its
  dark value, a dark value without its light, a value that isn't hex or `oklch()`, a required
  colour missing, no `typography.body.fontFamily`, an empty `fontFamily`, a role named `sans`, an
  empty `spacing`, a spacing or rounded value that isn't a length, no `rounded.default`, no
  `## Decisions` section, and an empty one
- **AC-2** The derivation: it exits 1 naming the token when the theme lacks a front-matter token
  (`theme-missing-token`), when a light value differs in `:root`, when a dark value differs in
  either dark rule, when a font family differs from `--font-sans`, `--font-mono` or
  `--font-<role>`, when a spacing step or the radius differs (`theme-differs`), and when the theme
  declares a literal colour (hex, `oklch()`, `rgb()`, `color-mix()` or a named colour), a
  `--space-*`, a `--radius*` or a `--font-*` family list the front matter doesn't name
  (`theme-not-in-design`); it exits 0 when the values match through `var()` aliases and `{path}`
  references, whitespace, quote style and case, and when a `--font-*` token holds a weight or size
- **AC-3** It exits 2, never 0, with no arguments, without `--theme` or with an empty one, on a
  missing `DESIGN.md`, a missing theme, a `DESIGN.md` with no front matter or no closing `---`,
  front matter outside the subset (a flow mapping, an anchor, a tab indent), and a theme of another
  shape (no `:root` with tokens, no dark rules, custom properties in another block); a byte-order
  mark, CRLF line endings, a trailing `#` comment and a `>` block scalar in the front matter are
  read, not can't judge
- **AC-4** The committed fixtures pass: `tests/fixtures/design-md/baseline/DESIGN.md` against
  `runtime/templates/ui/base.css`, and `tests/fixtures/design-md/ledger/DESIGN.md` against its
  theme (exit 0)
- **AC-5** `runtime/templates/check-fast.sh`, as a project copies it: with a `DESIGN.md` present it
  runs `scripts/ui/design-md-check.mjs --theme <THEME_CSS> DESIGN.md` as a part whose exit 1 fails
  the tier and exit 2 makes it can't run, with the other parts still run, and a missing copy makes
  it can't run; without a `DESIGN.md` it prints the "no DESIGN.md" line and the tier's exit is
  unchanged
- **AC-6** `runtime/project-contract.txt` has `scripts/ui/design-md-check.mjs` as an optional
  `devshop` item checked `executable`, `runtime/project-files.txt` the matching `optional` entry,
  and `tests/contract-check.test.sh` holds them together and counts the item
- **AC-7** `ui.md` § The baseline, § Checks and § Design direction, `design.md` § `DESIGN.md` first
  and § Done, `runtime/guidelines/README.md`, `docs/README.md` and the contract's `DESIGN.md` item
  say what Decisions says; `design.md` stays within 120 lines and 1200 words;
  `scripts/docs-map-check.py` passes; no file under `specs/` other than this one changes — verified
  by review: the diff and CI on the PR's head
- **AC-8** `tests/run.sh fast` passes with the new test file in it, and the PR's Evidence lists each
  rule's mutant and the case that killed it — verified by review: the Evidence section and CI on
  the PR's head
- **AC-9** `kit/notes/revamp/LOG.md` has an entry, and `kit/notes/revamp/workstreams/W10-v2.md`
  W10.8.3 carries a dated note that the shape check landed and the home at M3 wires it — verified
  by review: the diff

## Out of scope

- The React home's defaults and its library pin (D, M3), and wiring the check into any existing
  project's `check-fast.sh` (the upgrade shows the template's diff; the stack home's next change
  takes it and names the theme file `THEME_CSS` points at)
- `runtime/reviewer/` (prompt, `review.sh`, eval), and any wall on the design review's findings
- Wiring `tokens-check.mjs` into the template's fast tier (the owner's call at the go), and the
  stack homes' `supplies` and READMEs
- gstack's `components` token group, references outside the four groups, the prose sections'
  content, fonts' self-hosting, contrast (that is `tokens-check.mjs`'s)
- A `DESIGN.md` in gstack's legacy format or any prose shape without front matter: can't judge,
  with the line that says so; converting such a file is the project's design-direction work
