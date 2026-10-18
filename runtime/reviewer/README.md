# The independent reviewer

`review.sh` reviews one committed change against its spec with a fresh, locked-down `claude -p` that
has none of the builder's context (TARGET Verify 3–6, W10.6.2). It finds the spec itself: the one
`specs/**.md` file the change adds or changes. With none (a bug fix, a change working from a task
line) it reviews against the PR's own words, else the commit messages, and a change that should
have had a spec fails. Given the PR's title and body, it also checks them against the commit
(Review 5). Claude never runs it directly: [`ship`](#ship) runs it in the VM before anything reaches
the PR, and the PR opens or changes only once it passes (W10.6.6, W10.6.7). The interface (call,
exit codes, stdout line, verdict file and format) is in
[W10-v2.md § W10.6.2](../../kit/notes/revamp/workstreams/W10-v2.md). Change it there first.

```sh
/opt/devshop-current/reviewer/ship.sh --title "<the PR title>" --body-file <the PR body file>
```

## Files (all pinned with the devshop version)

| File                     | What                                                                            |
| ------------------------ | ------------------------------------------------------------------------------- |
| `ship.sh`                | Review, then push and put the PR's words and the verdict on the PR              |
| `review.sh`              | The reviewer. Model, tools, timeout and rounds-to-ask are constants at its top  |
| [`prompt.md`](prompt.md) | The reviewer's prompt: spec and intent first, then the lenses; severity scale   |
| `prompt-words.md`        | The words-only prompt: the `pr` lens alone, for a commit that already passed    |
| `prompt-browse.md`       | The browse instructions `prompt.md` gets at `{{BROWSE}}` with a local run       |
| `browse.mjs`             | `devshop-browse`: the reviewer's one browser command, on the local run only     |
| `verdict.schema.json`    | The schema the model's reply must match (`--json-schema`)                       |
| `settings.json`          | Bash allowlist: read-only git and test commands; the prompt names these only    |
| `pr-comment.sh`          | Renders a verdict file as the PR comment: per lens and item, tied to its commit |
| `pr-words.sh`            | The PR's title and body as one canonical line: what is reviewed and posted      |

## ship

`ship.sh --title <text> --body-file <file> [--base <branch>]` is the one way Claude puts a change on
a PR (W10.6.7; contract on the W10.6.7 line in W10-v2.md):

1. It checks the title and body have the PR template's shape
   ([`pr-body-check.py`](../scripts/pr-body-check.py), F-NEW-52): a body without it is exit 1, with
   the problems listed, before any review or push; a missing or broken check is exit 2.
   When the repo has its own `scripts/pr-title-check.py` (the devshop does: a Conventional Commit
   type, [spec](../../specs/devshop-releases.md); projects don't), the title must pass it too, in
   the same way.
2. It reviews the committed `HEAD` with exactly that title and body, in the VM:
   `review.sh --base origin/<base> --pr <words>`. The base is `--base`, else the open PR's base,
   else origin's default branch. When `HEAD` already passed on this base and only the title or
   body changed, or since a pass only the root `FINDINGS.md` or `ROADMAP.md` changed, `review.sh`
   reviews the words alone ([words only](#words-only)).
3. Only a pass goes on. A fail (exit 1) pushes nothing and prints the `REVIEW:` line and each
   blocking finding: fix, commit, ship again. Ask-owner (exit 3) and could-not-run (exit 2, also for
   a dirty tree, a detached `HEAD`, bad arguments or a result it can't trust) push nothing and say
   to ask the owner.
4. On a pass it pushes the branch, then creates the PR, or updates the open PR's title, body and
   base, with exactly the reviewed words. It reads them back: text GitHub appends to the body (an attribution footer)
   is fine, since it can't change what was reviewed; a changed title or rewritten body is reported
   (exit 2). Then it posts the verdict comment and prints
   `SHIPPED: PR #<n> · <url> · <commit12>`. A GitHub failure after the push is exit 2, saying what
   was done.

Code and words go up together, so the PR always shows the reviewed commit with the reviewed words.

## Words only

A `ship` after a change to the title or body alone doesn't review the code again (W10.9.7; it cost
five full reviews on one PR). Given `--pr`, `review.sh` looks in the branch's verdict directory for
a `pass` with the same commit, merge-base and intent. With one, it runs the same locked-down call
with [`prompt-words.md`](prompt-words.md): the `pr` lens and nothing else. The reply must have no
acceptance items, only `pr` findings and one applying `pr` row, else could-not-run. The verdict has
`scope: "words"`, the earlier pass's acceptance items and `code_review`, the full review the code
passed in, and its comment says "words only" and names it. A new commit, another base, words given
after a review without them (no spec) or no earlier pass gives a full review (`scope: "full"`).

**Records only** ([spec](../../specs/findings-and-roadmap.md)): a pass also counts for a later commit
when that commit descends from it and every file changed since is the root `FINDINGS.md` or
`ROADMAP.md`. These are the records a change writes after the reviewer's pass: its `low` findings,
the owner's answer. The words-only prompt then also gets the records' diff, and the `pr` lens
checks that the words account for every row or entry it adds, changes or deletes. A file anywhere
else, a records file below the root included, gives a full review.

## The guard

[`runtime/hooks/review-guard.py`](../hooks/review-guard.py), the plugin's PreToolUse hook, keeps the
other ways to a PR closed. It reviews nothing; it refuses, pointing to the `devshop:pr` skill and `ship`:

- `gh pr create`; `gh pr edit` with a title, body or base;
- `git push` while the current branch has an open PR (and when that can't be checked: `gh` fails);
- the GitHub tools `create_pull_request`, `update_pull_request` with a title, body or base,
  `update_pull_request_branch`, and `push_files`, `create_or_update_file`, `delete_file` on a branch
  with an open PR.

Everything else passes, without a GitHub call. It reads commands word by word: heredoc bodies and
quoted text are not commands. A command it can't split is refused if its text names one of those
commands. If the pinned guard or `python3` is missing, the plugin's fallback refuses the same calls
by name.

## On the PR

Each shipped review is recorded on the PR as one comment, rendered by `pr-comment.sh` from the
verdict file (TARGET Verify 7, L-25). Its first line is a marker with the full commit, the outcome
and `words`, the sha256 of the PR words the review read; text from the model has `<` escaped and
newlines flattened, so it can't form a second one, and `@` and `[` escaped, so it can't mention
people or render markdown links and images (F-NEW-25; bare URLs and `#123` references still
autolink). Paths shown in code spans stay literal. It is short by default (owner, 2026-10-13): the
second line is the headline (outcome, round, blocking and low counts, commit) and the rest (spec,
the per-lens and per-item tables, findings, the reviewer's identity) is collapsed in one `<details>`
block, which model text can't close. Each ship posts a new comment, so each verdict sits in the
timeline just after the push it reviewed, and a push made without `ship` shows as a push with no
verdict after it. Failed reviews push nothing and post nothing. There is no CI check on it (owner,
2026-10-13): the agent could post a comment itself, so a check was no wall. The owner reads the
verdict for the head commit before approving.

## The local run and the browser

A project gets its UI changes browsed by declaring `scripts/local-run.sh`
([spec](../../specs/reviewer-browser.md)): it serves the site on `127.0.0.1:$PORT` until stopped.
`review.sh` reads that it exists at the **base** commit, so a change can't declare it for itself,
and on every full review runs the head's copy in the throwaway clone:

1. A free port, the script in its own process group with the session's variables dropped (as for
   the reviewer's `claude`), its output logged. The real worktree's `node_modules` (the session's
   install, not checked against the lockfile) is linked into the clone unless the head tracks one.
2. Ready on any HTTP status within `LOCAL_RUN_WAIT` (60 s) while it is alive; then
   `devshop-browse /` once. A run that exits, doesn't answer, or can't be browsed is could-not-run.
3. The reviewer gets `devshop-browse` on its `PATH`, named in the prompt (the allowlist's
   `Bash(devshop-browse:*)`; it is left out of the named commands otherwise), and
   [`prompt-browse.md`](prompt-browse.md) at `{{BROWSE}}`: judge each touched page against the base
   commit's `DESIGN.md`, a value it doesn't name at least `medium`, overflow at any width `high`.
4. Afterwards the group gets TERM, then KILL; a process left or the port still answering is
   could-not-run. An interrupted review cleans up the same way.

`devshop-browse <path>` (`browse.mjs`) takes exactly one path starting with `/` and refuses
anything else, or a path that resolves to another origin, before loading anything. It loads the
page with the project's own Playwright (by path from its `node_modules`, never a global one) at 375,
768 and 1280 px in light and dark, writes six screenshots (at most 4000 px tall) under
`.devshop-browse/` in the clone, and prints their paths and the facts as JSON (at most 20 KB): the
title, the fonts declared and drawn, the colours (per theme) and spacing (per width) that differ
from the browser's defaults, overflow, console errors, and failed and blocked requests. Every
request or WebSocket to another origin is aborted and listed, a font as "remote font not loaded";
service workers are blocked. Exit 1 refused, 2 can't judge.

With no `scripts/local-run.sh` at the base, and in a words-only review, nothing starts: the prompt
says there is no local run, and the design and QA lenses review by reading.

## How it is locked down, and what that is worth

- `claude -p --restricted --safe-mode` loads no CLAUDE.md, skills, hooks, plugins or MCP. Its tools
  are Read, Grep, Glob and Bash, and in `dontAsk` mode Bash runs only the `settings.json` allowlist.
  Edit and Write don't exist for it. The prompt has it run one simple command per call, keep
  going after a refusal, and review commit by commit (W10.6.5: a reviewer that stopped at the
  first refused compound command reviewed by reading and missed most planted mistakes).
- Its `claude` runs without the calling session's identity variables: a nested `claude` that
  inherits them reports the caller's session id and could reach the caller's session. They go by
  name pattern (`SESSION_TIE_PATTERNS` in `review.sh`: `CLAUDE_CODE_*SESSION*`, `*INGRESS*`,
  `*MESSAGING*`, `CLAUDE_CODE_*SDK*`), so one a later Claude Code version adds goes too; what it
  needs to authenticate (the API endpoint, proxy and CA settings) matches none of them. If a later
  version's auth variable did match, the reviewer's `claude` couldn't authenticate and the review
  would be could-not-run: a loud failure, never a pass.
- The prompt names the commands it may run from `settings.json` alone: `review.sh` writes the
  allowlist's `Bash(<command>:*)` entries in at `{{COMMANDS}}`, so the two can't drift. An
  allowlist it can't read or name is could-not-run.
- Whether the project's CI runs its tests is stated, not left to the model: the prompt says
  whether the base commit has `scripts/check-fast.sh`, the script CI's `fast` job runs (the CI
  tiers contract). Declared, a test it can't run is a `tests` note; not declared, it is `unsure`.
  A finding whose only fix is to run the tests or confirm CI is never a finding.
- A departure from the spec is never `low` (W10.6.9): code that departs from a decision (even an
  extra guard the decision rejected) or a state-table row tested only in part is at least
  `medium`. Left to judgement, the same commit got `low` in some runs and blocking in others
  (F-NEW-40).
- It works in a throwaway clone that holds only the base and head commits and has no remote. Some
  allowlisted commands can still write files anywhere the user can: `git diff --output=<path>`, and
  a test run, which executes the change's own code. The clone keeps ordinary writes away from the
  real tree, and afterwards the real worktree must show the same `HEAD` and status, or the result is
  could-not-run. A change whose tests write elsewhere (even over the reply file before it is read)
  is not stopped by this. The builder can already run that code in its own session.
- The outcome comes from the script: unmet `AC-<n>` or any finding above `low` (including `unsure`)
  is a fail. A reply that is malformed, incomplete or off-schema is could-not-run, never a pass.
- No environment variable or argument changes the model, prompt, tools or permissions. Tests change
  only a copy of this directory and put a stub `claude` on `PATH`.
- The local run and `devshop-browse` ([below](#the-local-run-and-the-browser)) run the change's code
  as a test run does. They can write through the linked `node_modules` (gitignored, so the worktree
  check doesn't see it) or replace the `devshop-browse` wrapper on `PATH` (the same user). The
  origin check and request blocking keep an honest reviewer on the local run; they stop nothing
  the change's own code does.
- This is **feedback, not a wall.** An agent that controls its session can skip or fake all of
  this. The walls are GitHub's rules, plain CI and the owner's approval (TARGET Verify, "what this
  protects against").

## Proof

- [`tests/reviewer.test.sh`](../../tests/reviewer.test.sh) (in CI, stub `claude`) checks the
  locked-down call, the outcome rule, rounds (a repeat counts, a new issue starts again, the 6th
  failing commit asks the owner), the verdict file, the spec found from the diff (none, one, two,
  nested, changed, deleted, non-`.md`), the PR's words reaching the prompt verbatim and checked
  (`pr` lens), a shallow clone, and could-not-run for every bad input. W10.9.7: words only after a
  pass on the same commit, base and intent, and a full review otherwise (a new commit, another base,
  a fail, another intent, no words); records only after a pass on an ancestor, and a full review
  for a records file below the root, records with code, or a pass that isn't an ancestor (6 of 6
  mutants killed); 12 of 12 mutants killed, plus 2 of 2 on the comment (a
  13th, a spec condition, was equivalent: the same commit and base fix the spec; it was removed). W10.6.8: the session
  variables removed by pattern (made-up future names too) while auth and proxy variables pass; the
  prompt's commands following an edited `settings.json` copy; whether `scripts/check-fast.sh` is at
  the base (not added by the change) stated in the prompt; 13 of 13 mutants killed. W10.6.9: the
  never-`low` rules for decisions and state rows are in the prompt; 4 of 4 mutants killed.
- [`tests/reviewer-pr.test.sh`](../../tests/reviewer-pr.test.sh) (in CI) checks the comment (per
  lens, marker not forgeable from model text) and `pr-words.sh`.
- [`tests/ship.test.sh`](../../tests/ship.test.sh) (in CI, stub `review.sh` and `gh`, a local
  origin) checks `ship`: a pass pushes, creates or updates the PR with exactly the reviewed words and
  posts the verdict; a fail, ask-owner, could-not-run, any result it can't trust or bad input pushes
  nothing; text GitHub appends is left alone, and a rewritten body or changed title is reported; GitHub failures after the
  push say what was done.
- [`tests/review-guard.test.sh`](../../tests/review-guard.test.sh) (in CI, stub `gh`) checks the
  guard: what it refuses and what it lets through, the plugin's registration and fallback, and that
  the guard, matcher and fallback name the same tools.
- Mutants for W10.6.7 (the guard, `ship`, the rounds rule, `pr-words.sh`): 39 of 40 killed, the
  survivor equivalent (LOG #48).
- The W10.6.5 eval ([spike](../../kit/notes/revamp/spikes/w10-6-5-reviewer-eval/README.md)) ran
  the real reviewer on the fixture: 15 honest changes all pass and 15 changes planted by the
  north-star harness all fail, each on its plant (A-12).
- **Before a PR that changes how it reviews** (`review.sh`, `prompt.md`, `prompt-browse.md`,
  `browse.mjs`, `settings.json`, `verdict.schema.json`, the model, a new Claude Code CLI), run that eval's `check.sh` on the
  branch, by hand in a session (W10.10.7, [how](../../kit/notes/revamp/spikes/w10-6-5-reviewer-eval/README.md#the-check-before-a-reviewer-change-w10107)).
  It passes only when every honest change passes and every planted one fails; a could-not-run is a
  miss. [`tests/reviewer-eval.test.sh`](../../tests/reviewer-eval.test.sh) (in CI) proves a stub
  reviewer that passes everything fails it.
- [`tests/reviewer-live.sh`](../../tests/reviewer-live.sh) (`[runs]`, in a session only, because it
  calls the real model and CI runs no LLM jobs) runs the real reviewer on the A-04 fixtures in
  [`tests/fixtures/reviewer/`](../../tests/fixtures/reviewer) (spec: [`spec.md`](../../tests/fixtures/reviewer/spec.md)). The planted change (AC-4 skipped)
  must fail with exactly AC-4 unmet, and the honest one must pass. W10.6.6 cases: the honest change
  with true PR words passes and with a false claim fails on the `pr` lens; a new feature with no
  spec fails on the `intent` lens; an honest bug fix with no spec (its failing test is the spec)
  passes; two spec files are could-not-run. Every review that called the model must carry a
  `session_id` of its own: not the caller's and not another run's (W10.6.8; a copy that keeps the
  session's variables fails it).
- The local run and the browser ([spec](../../specs/reviewer-browser.md)):
  [`tests/reviewer.test.sh`](../../tests/reviewer.test.sh) (stub `claude` and `browse.mjs`) checks
  that the base's script starts with `PORT`, the session's variables dropped and `node_modules`
  linked, that `devshop-browse /` runs first and the reviewer's own calls reach the local run, that
  nothing of it is left after (a `nohup` child, an interrupt, a server that escapes the group is
  could-not-run), and that a script the change adds, a words-only review or no script starts
  nothing and names no `devshop-browse`; 13 of 13 mutants killed (the signal traps were equivalent:
  bash runs the EXIT trap on them, and they were removed).
  [`tests/reviewer-browse.test.sh`](../../tests/reviewer-browse.test.sh) (slow tier, real Chromium)
  checks `browse.mjs`: six screenshots, only values that differ from the browser's defaults (the UI
  baseline's example reports only its tokens), overflow as the render check defines it, other
  origins blocked (requests, WebSockets, fonts, service workers), refusals, and exit 2 when it
  can't judge; 17 of 17 mutants killed (a redundant `//` guard was removed).
  [`tests/reviewer-browser-live.sh`](../../tests/reviewer-browser-live.sh) (`[runs]`, in a session)
  runs the real reviewer on [`tests/fixtures/reviewer-browser/`](../../tests/fixtures/reviewer-browser)
  (spec: [`spec.md`](../../tests/fixtures/reviewer-browser/spec.md)): the notes page built to its
  [`DESIGN.md`](../../tests/fixtures/reviewer-browser/base/DESIGN.md) must pass, and a serif font, a 13px padding and a layout
  that scrolls sideways at 375 px must each fail on a blocking `design` or `qa` finding.

## Limits

- Only specs whose acceptance items are named `AC-<n>` are reviewed. Others are could-not-run.
- A change with two or more spec files is could-not-run: one change, one spec (TARGET Intent 2).
  Every `.md` under `specs/` counts, so `specs/` holds spec files only (the Intent skill says so);
  a README or template added there makes the review could-not-run, never a pass.
- What "run" can run is the allowlist above. Stack homes (W10.5.2) will extend it per stack. The
  browser needs the project's `scripts/local-run.sh`; without one, the design and QA lenses review
  by reading and say so. It loads pages; it doesn't click or type.
- Rounds count only repeats: a fail is round 1 unless it repeats a blocking item (an unmet `AC-<n>`,
  or a finding's lens and file) of the previous failing commit. Round 3 asks the owner, and so does
  the 6th failing commit since the last pass, new issues or not (owner, 2026-10-13).
- Screenshots in the PR body (Review 5, L-29) are not checked against the commit yet.
- A words-only review trusts the verdict files under `.git/devshop/reviews/`: a session that writes
  a fake `pass` there gets the words-only review for its commit. Feedback, not a wall, like the rest:
  the session could as well skip `ship`.
- The guard sees a command only as the command itself. Wrapped ones get through: `bash -c '…'`,
  `sh -c`, `eval`, `sudo`, `timeout`, `xargs`, a script that pushes, and `gh api` writes to the PR.
  Kept on purpose (owner, 2026-10-13): this is feedback, not a wall. A change that bypasses `ship`
  has no verdict comment for its commit.
