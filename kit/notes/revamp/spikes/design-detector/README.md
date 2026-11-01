# The design-detector spike: does `/design-review` open with impeccable's engine once the bootstrap placed it?

The proof for [specs/design-detector-in-bootstrap.md](../../../../../specs/design-detector-in-bootstrap.md)
(AC-7). One run of gstack's `/design-review` as `runtime/guidelines/ui.md` § Design review words it,
on a scratch site made from `runtime/templates/ui/` with one page carrying the planted tells, after
`install/impeccable.sh` placed the pinned engine in this session's `$HOME`. The grading below is
committed before the engine is placed and before any run (the commits' order is the record).

## Set-up (fixed before any run, 2026-11-01)

- **The engine:** placed by `install/impeccable.sh install/impeccable.pin "$HOME"` from the
  committed pin, the script's one live run against the real registry; its output is recorded below.
- **The scratch site:** a directory outside the repo, `git init`ed with one commit on `main`:
  `index.html` (the template's `example.html`), `base.css` and `theme.js` unchanged, and
  [`site/DESIGN.md`](site/DESIGN.md), the earlier design-review spike's `DESIGN.md` in gstack's spec
  format (the baseline's tokens, system fonts, one blue). A branch adds
  [`site/launch.html`](site/launch.html), a copy of the test fixture
  `tests/fixtures/design-detector/planted.html`: a purple-violet gradient hero with white text on
  violet, Inter as the display face, a tracked ALL-CAPS eyebrow above an oversized h1, three nested
  rounded cards. Served with `python3 -m http.server --bind 127.0.0.1 <port>` from the branch.
- **The helper:** one fresh `general-purpose` agent, given only `ui.md` § Design review, the scratch
  repo's path, its branch and `http://127.0.0.1:<port>/launch.html` as the scope. It invokes
  `/design-review` and returns gstack's final report verbatim, the set-up lines gstack printed
  (`IMPECCABLE_*`), every question it would have put to the owner, and the commits it wrote. No
  edits outside the scratch repo. `GSTACK_CHROMIUM_PATH=/opt/pw-browsers/chromium` as the bootstrap
  sets it; gstack's browser check still prints `NEEDS_SETUP` (F-NEW-101), handled as the guideline
  says.

## Pass rule (fixed before the run)

The run **passes** only when all four hold, judged on the helper's literal output:

1. **Engine found:** the set-up lines include `IMPECCABLE_READY: <path>` and the path is
   `$HOME/.impeccable/bin/<pinned version>/impeccable` (the placed engine, not another).
2. **The detector counted:** the report's `Detector: N → M` line (gstack's wording; "not installed"
   or "off" when it did not run) has N ≥ 3.
3. **The planted tells, by rule id:** `[ai-color-palette]`, `[overused-font]` and
   `[hero-eyebrow-chip]` each appear as a rule tag on a finding in the report.
4. **No install offer, no other question:** the report and the questions list hold no
   "Install impeccable's design detector engine?" offer and no other question for the owner, except
   gstack's telemetry-consent question, which comes back on every run while its marker is unset and
   the guideline already covers.

A helper that can't start its browser, or reads outside its scratch repo, is a could-not-run:
recorded, and re-run once; a second could-not-run is recorded, no pass is claimed, and the owner
hears it. The baseline is the earlier spike's reports (`Detector: not installed`, the install offer
declined); no control run here.

## The engine placed (2026-11-01)

[`outputs/place-engine.txt`](outputs/place-engine.txt): `install/impeccable.sh install/impeccable.pin
"$HOME"` against the real registry printed `placed /root/.impeccable/bin/0.1.3/impeccable` in 0.53 s;
the file's sha256 is the pin's (`afc7a424…`), 15 991 120 bytes, mode 755. From the scratch repo,
gstack's probe then printed `IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable`.

## Result (2026-11-01, one fresh helper, one run, 1106 s)

The hand-back, verbatim: [`outputs/run-1.md`](outputs/run-1.md).

| Line                            | Result                                                                                                                                                                               |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 engine found                  | pass: `IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable` in the set-up lines, the placed path                                                                                 |
| 2 the detector counted          | pass: `Detector: 5 → 0 (engine 0.1.3; DOM mode, page launch)`; the baseline scan `DETECT_TOP total=5 rules=5`                                                                          |
| 3 the planted tells, by rule id | pass: FINDING-002 `[ai-color-palette]`, FINDING-003 `[overused-font]`, FINDING-004 `[hero-eyebrow-chip]`; also FINDING-001 `[low-contrast]` and FINDING-005 `[nested-cards]`           |
| 4 no install offer, no question | pass: no `DESIGN_DETECTOR_INSTALL_OFFER` line, no question put to the owner; gstack's telemetry was off, so its consent question didn't come back either                                |

**Pass.** The review opened with the detector, confirmed each hit in the rendered page, fixed the
five detector findings on the page's own lines in four commits (`launch.html` only), and its summary
line reads as the guideline now words it: "detector: ran, 5 → 0 findings (engine 0.1.3)".

**What else the run showed.** `nested-cards` fires in DOM mode (the rendered page) and not in the
engine's file-scan mode on the same markup, which is why `tests/design-detector.test.sh` asserts the
three ids and not that one. The helper's § 5 lists what did not work as the skill or the guideline
words it, each a devshop finding: gstack's browse binary (`$B`) is not built in this environment and
gstack has no `node_modules`, because the bootstrap's gstack step stopped at its Bun check (the
image's Bun is 1.4.4, the pinned gstack is tested on 1.4.2; this session's `/tmp/devshop-setup.log`
says so), so the guideline's F-NEW-101 mitigation assumes a binary that isn't there and the helper
ran the browse CLI from source under bun (F-NEW-135, med); full-page screenshots wedge the browse
daemon (F-NEW-136); dcg blocks three of the skill's own steps (F-NEW-137). None touched the
detector, which needs neither the browse binary nor gstack's dependencies.

## Mutants (2026-11-01)

[`outputs/mutants.txt`](outputs/mutants.txt): the fixture with the eyebrow removed fails the test
naming `[hero-eyebrow-chip]` (the engine reported `nested-cards` in its place); the pin with another
checksum fails the sha256 case; no engine exits 2 naming `install/impeccable.sh`; the unmutated test
passes.
