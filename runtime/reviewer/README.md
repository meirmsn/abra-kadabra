# The independent reviewer

`review.sh` reviews one committed change against its spec with a fresh, locked-down `claude -p` that
has none of the builder's context (TARGET Verify 3–6, W10.6.2). It finds the spec itself: the one
`specs/**.md` file the change adds or changes. With none (a bug fix, a change working from a task
line) it reviews against the PR's own words, else the commit messages, and a change that should
have had a spec fails. Given the PR's title and body, it also checks them against the commit
(Review 5). A hook starts it before the PR is created and before each later push (W10.6.7), so the
builder never chooses whether it runs, and the PR opens only once it passes (W10.6.6). The interface (call, exit
codes, stdout line, verdict file and format) is in
[W10-v2.md § W10.6.2](../../kit/notes/revamp/workstreams/W10-v2.md). Change it there first.

```sh
/opt/devshop-current/reviewer/review.sh --base origin/main --pr <pr-words.json>
# pr-words.json: {"title": "<the PR title>", "body": "<the PR body>"}; --pr is optional
```

## Files (all pinned with the devshop version)

| File                     | What                                                                            |
| ------------------------ | ------------------------------------------------------------------------------- |
| `review.sh`              | The script. Model, tools, timeout and rounds-to-ask are constants at its top    |
| [`prompt.md`](prompt.md) | The reviewer's prompt: spec and intent first, then the lenses; severity scale   |
| `verdict.schema.json`    | The schema the model's reply must match (`--json-schema`)                       |
| `settings.json`          | Bash allowlist: read-only git and test commands. Anything else is refused       |
| `pr-comment.sh`          | Renders a verdict file as the PR comment: per lens and item, tied to its commit |
| `verdict-check.sh`       | Reads a PR's comments: is there a passing verdict for the head commit?          |
| `verdict-wait.sh`        | The PR's `review-verdict` check: polls the comments until ok or time is up      |

## On the PR

Each review is recorded on the PR as one comment, rendered by `pr-comment.sh` from the verdict file
(TARGET Verify 7, L-25). Its first line is a marker with the full commit and the outcome; text from
the model has `<` escaped and newlines flattened, so it can't form a second one, and `@` and `[`
escaped, so it can't mention people or render markdown links and images (F-NEW-25; bare URLs and
`#123` references still autolink). Paths shown in code spans stay literal. The hook (W10.6.7)
posts it right after the PR is created or pushed. The `review-verdict` workflow runs
`verdict-wait.sh` on every PR push: it passes once the latest marker is a pass for the head commit,
and fails when the verdict is missing, stale (for an older commit) or failing after 10 minutes. It
waits because a run triggered by the comment would report on `main`, not on the PR. The session
cannot post a commit status (its GitHub access refuses status writes), hence a comment. It is not a
required check: the agent can post a comment itself, and the PR's own copy of the workflow runs.

## How it is locked down, and what that is worth

- `claude -p --restricted --safe-mode` loads no CLAUDE.md, skills, hooks, plugins or MCP. Its tools
  are Read, Grep, Glob and Bash, and in `dontAsk` mode Bash runs only the `settings.json` allowlist.
  Edit and Write don't exist for it. The prompt has it run one simple command per call, keep
  going after a refusal, and review commit by commit (W10.6.5: a reviewer that stopped at the
  first refused compound command reviewed by reading and missed most planted mistakes).
- Its `claude` runs without the calling session's identity variables (`SESSION_TIES` in
  `review.sh`): a nested `claude` that inherits them reports the caller's session id and could
  reach the caller's session.
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
- This is **feedback, not a wall.** An agent that controls its session can skip or fake all of
  this. The walls are GitHub's rules, plain CI and the owner's approval, and a missing or stale
  verdict on the PR is the tripwire (TARGET Verify, "what this protects against").

## Proof

- [`tests/reviewer.test.sh`](../../tests/reviewer.test.sh) (in CI, stub `claude`) checks the
  locked-down call, the outcome rule, rounds → ask-owner, the verdict file, the spec found from the
  diff (none, one, two, nested, changed, deleted, non-`.md`), the PR's words reaching the prompt
  verbatim and checked (`pr` lens), and could-not-run for every bad input. Its W10.6.2 mutants (14)
  and W10.6.6 mutants (21 of 22; the survivor is equivalent) are killed.
- [`tests/reviewer-pr.test.sh`](../../tests/reviewer-pr.test.sh) (in CI, stub `gh`) checks the
  comment (per lens, marker not forgeable from model text), ok / missing / stale / failing for the
  head, the wait, and could-not-run for bad input. 33 of 34 mutants killed (the survivor is
  equivalent).
- The W10.6.5 eval ([spike](../../kit/notes/revamp/spikes/w10-6-5-reviewer-eval/README.md)) ran
  the real reviewer on the fixture: 15 honest changes all pass and 15 changes planted by the
  north-star harness all fail, each on its plant (A-12).
- [`tests/reviewer-live.sh`](../../tests/reviewer-live.sh) (`[runs]`, in a session only, because it
  calls the real model and CI runs no LLM jobs) runs the real reviewer on the A-04 fixtures in
  [`tests/fixtures/reviewer/`](../../tests/fixtures/reviewer) (spec: [`spec.md`](../../tests/fixtures/reviewer/spec.md)). The planted change (AC-4 skipped)
  must fail with exactly AC-4 unmet, and the honest one must pass. W10.6.6 cases: the honest change
  with true PR words passes and with a false claim fails on the `pr` lens; a new feature with no
  spec fails on the `intent` lens; an honest bug fix with no spec (its failing test is the spec)
  passes; two spec files are could-not-run.

## Limits

- Only specs whose acceptance items are named `AC-<n>` are reviewed. Others are could-not-run.
- A change with two or more spec files is could-not-run: one change, one spec (TARGET Intent 2).
  Every `.md` under `specs/` counts, so `specs/` holds spec files only (the Intent skill says so);
  a README or template added there makes the review could-not-run, never a pass.
- What "run" can run is the allowlist above. Stack homes (W10.5.2) will extend it per stack. There
  is no browser yet, so the design and QA lenses review by reading.
- Rounds count distinct failing commits since the branch's last pass, and they don't reset when the
  owner decides something. Each further fail asks the owner again. Kept on purpose for now (owner,
  2026-10-12): if the north-star run or the reviewer eval (W10.6.4–5) shows repeat questions,
  reset the count when a commit changes the spec file.
- Screenshots in the PR body (Review 5, L-29) are not checked yet: there is no browser.
- The hook that starts the reviewer and posts its comment is W10.6.7.
