# A skills regression eval: the free check and the first runner

**Go:** "go with their answers ... then build the system and then run it" (owner, 2026-11-04)

## Intent

The owner, 2026-11-02: "A simple practical no nonsense way to be confident when we make
modifications to the skills that they are not regressing." Mechanical checks first; checks that
call a model second and only if needed; not in CI, run when the skills change ("not in CI" is read
as the model tier: the free tier costs nothing and runs in CI with the other checks, which the owner
can veto). This is the first
slice, R-16 (the split and its entries: `ROADMAP.md`, R-16 to R-18): a free check, in CI, of what a
skill edit breaks most cheaply, and one command that runs the real skills on one case, so the next
slices are judged on a real run. The spike that priced it:
`kit/notes/revamp/spikes/skills-eval-runner/README.md`.

## Decisions

- **The owner delegated the open questions** to the adversarial review and took its answers
  (owner, 2026-11-04: "feed this to the adversarial review together with the plan, I guess, and
  then go with their answers"). They are the decisions below and the roadmap entries.
- **Two tiers:** a free static tier inside `scripts/skills-check.py`, run by `tests/run.sh` in CI;
  a model tier, `tests/skills-eval.sh`, run by hand when the skills change, never in CI (D-06's outcome: no LLM jobs in PR CI).
  Rejected: the model tier alone (it misses a deleted rule or a broken section reference, the
  breakage an edit causes) and the static tier alone (it can't see a rule present but not followed,
  every regression on record) (review, 2026-11-04)
- **Section references,** matched on the skill's text with line breaks folded, N digits only:
  `` `devshop:<x>` § N ``, `` `<x>` § N ``, `` `devshop:<x>` step N `` and `` `<x>`, step N `` (comma
  optional) name a "## N." heading of skill <x>; a bare "§ N" or "step N" one of its own; and
  `` `/opt/devshop-current/<file>` § <text> `` a heading of that file, its "(…)" tail dropped, that
  the text starts with. A reference to anything else ("TARGET § L3 Intent", a spec) is not checked:
  those files aren't in the runtime a session gets (Claude, 2026-11-04; the spec review)
- **Rule lines:** `tests/skills-eval/rules.txt` lists the load-bearing lines, one per line as
  `<skill> | <why> | <text>`; each text must appear in its skill, whitespace folded (lines wrap). An
  edit that removes or rewords one fails until the PR edits the list too, so the owner sees it
  (review, 2026-11-04)
- **The model tier runs the real environment:** the branch's commit is fetched into the local
  devshop copy and pinned in a scratch project placed by `project-files.py`, as the spike did; only
  `runtime/` is under test, never `install/plugin/**` (review, 2026-11-04)
- **The child's environment:** the session-tie variables `review.sh` drops, plus `GH_TOKEN`,
  `GITHUB_TOKEN`, `GIT_ASKPASS` and `GIT_CONFIG_*`, are removed. A mitigation: the agent proxy may
  still authenticate, and the token's scope is the wall. Permission mode `auto`, the mode real
  sessions use, with refused calls counted on each line; a shared allowlist is built only if the
  first run shows `-p` refusing `auto` (review, 2026-11-04)
- **The scratch project:** placed by `project-files.py init` at the copy's newest release, then
  pinned to the commit under test with its devshop copies re-applied, `check` passing, and committed
  as the base before the first owner turn; the grader diffs the tree, untracked files included,
  against that base (the spec review)
- **The shared link (F-NEW-144):** the runner writes the original `/opt/devshop-current` target to a
  record file before the first case, restores it on exit, restores a record a crashed run left on
  start, and fails if the link isn't back (review, 2026-11-04)
- **Outcomes:** a case is PASS, FAIL or could-not-run (CNR). A run whose session line doesn't name
  the commit under test, or with no init event, or an unparseable stream, is CNR, never a pass.
  Exit 1 on any FAIL (a regression found is never downgraded), else 2 on any CNR, else 0. Defaults:
  1 run, case `trigger`. The runner's paths (`DEVSHOP_GIT`, `DEVSHOP_CURRENT`, the record file) can
  be overridden, so `tests/skills-eval.test.sh` runs it with a fake `claude` and never moves the
  real link (Claude, 2026-11-04; the spec review)
- **The first case, `trigger`:** the spike's small change ("Add a --shout flag to cli.js that
  prints the greeting in upper case."), one owner turn. It passes when `devshop:intent` is loaded
  before any Write or Edit call, nothing outside `specs/` changed, and the spec it wrote passes
  `spec-check.py`. Its lines: intent's "Every request starts here" and "nothing is built before the
  "go"" (review, 2026-11-04)
- **The first run** is 3 runs of `trigger` on this branch, then 1 run on a planted commit whose
  intent says to edit code directly, which must FAIL. Their lines go in the PR body. A stability
  check, not a baseline (review, 2026-11-04)
- **Added after the go, for the owner to confirm:** the first run found that the installed plugin
  loads none of the runtime's skills on Claude Code 2.1.318 (F-NEW-147), so every run could not
  run. `SKILLS_EVAL_PLUGIN_DIR` makes the runner also pass `--plugin-dir`, so the cases can still be
  shown to pass and fail on real sessions; it is off by default, a mitigation (the root cause is
  F-NEW-147's), and a run using it says so. Raised to the owner at the hand-over (Claude,
  2026-11-04)
- **Results stay out of the repo:** each run works in a fresh `mktemp -d`; transcripts carry
  session ids. The grader's tests use hand-written event streams, never real transcripts (CLAUDE.md
  rule; review, 2026-11-04)

## Acceptance items

- **AC-1** `skills-check.py` fails, naming the skill and the reference, when a skill's reference to
  another skill's section (§ or step, with or without `devshop:` and the comma) names a section the
  other skill doesn't have (a renumbered section), also across a line break, and passes when it
  exists.
- **AC-2** It fails on a bare "§ N" or "step N" naming a section its own skill lacks.
- **AC-3** It fails on a `` `/opt/devshop-current/<file>` § <Heading> `` whose file has no heading,
  its "(…)" tail dropped, that the text after the § starts with.
- **AC-4** With `--rules FILE`, it fails, naming the skill and the line, when a listed text no longer
  appears in its skill (a deleted rule); a malformed line or an unknown skill in the file is
  can't-run (exit 2).
- **AC-5** It passes on the current skills with `tests/skills-eval/rules.txt`, in `tests/run.sh`.
- **AC-6** The grader (tested by `tests/skills-eval.test.sh`, like AC-7 to AC-12) gives PASS on a stream where `devshop:intent` is loaded before any write and
  the repo changed only under `specs/` with a spec that passes `spec-check.py`.
- **AC-7** The grader gives FAIL on a stream that writes a file before loading `devshop:intent`, and
  on a repo with a change outside `specs/` (an untracked file included), naming the line it tests.
- **AC-8** The grader gives CNR on a stream whose session-start line names another commit, on one
  with no init event, and on one that isn't JSON lines.
- **AC-9** `tests/skills-eval.sh [runs] [case]` prints one line per run: the outcome (`PASS`,
  `FAIL` or `CNR`), the case, the run number, and `sha=`, `model=`, `cli=`, `cost=$`, `time=` (s)
  and `refused=` fields, then the reason; then a tally and `link restored: <target>`. It exits 1 on any
  FAIL, else 2 on any CNR, else 0.
- **AC-10** The runner removes the session-tie and credential variables from the child's
  environment.
- **AC-11** The runner restores the shared link on exit, restores a record left by a crashed run
  before it starts, and fails when the link isn't back.
- **AC-12** The runner refuses, as CNR before any model call, an unknown case, a commit under test
  that isn't one, and (testing `HEAD`, the default) a working tree whose `runtime/` has changes the
  commit lacks; a commit named by `SKILLS_EVAL_REF` is tested as it is.
- **AC-13** `tests/skills-eval/README.md` has the finding → case table and the per-rule coverage
  table, and CLAUDE.md's reviewer-eval sentence covers a PR that changes a skill — verified by
  review: read both.

## Out of scope

- Every case but `trigger`: the F-NEW-91 and F-NEW-78 cases are R-17, a build smoke test and F-NEW-79
  are R-18, both judged on this slice's real numbers.
- `pr` § 3–5 (they need GitHub), `new-project` (the pin the runner writes stops it) and the plugin's
  `upgrade` (it isn't in `runtime/`): left to the static tier and a north-star run.
- The root fix of F-NEW-144 in the plugin's dispatcher, and F-NEW-88's rule (R-19).
- Long sessions: short cases catch what an edit to the text does, not compliance deep into a long
  session.
