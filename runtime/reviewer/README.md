# The independent reviewer

`review.sh` reviews one committed change against its spec with a fresh, locked-down `claude -p` that
has none of the builder's context (TARGET Verify 3–6, W10.6.2). A hook starts it from the "done" /
open-PR step (W10.4.4), so the builder never chooses whether it runs. The interface (call, exit
codes, stdout line, verdict file and format) is in
[W10-v2.md § W10.6.2](../../kit/notes/revamp/workstreams/W10-v2.md). Change it there first.

```sh
/opt/devshop-current/reviewer/review.sh --base origin/main --spec specs/<change>.md
```

## Files (all pinned with the devshop version)

| File                     | What                                                                          |
| ------------------------ | ----------------------------------------------------------------------------- |
| `review.sh`              | The script. Model, tools, timeout and rounds-to-ask are constants at its top  |
| [`prompt.md`](prompt.md) | The reviewer's prompt: spec and intent first, then the lenses; severity scale |
| `verdict.schema.json`    | The schema the model's reply must match (`--json-schema`)                     |
| `settings.json`          | Bash allowlist: read-only git and test commands. Anything else is refused     |

## How it is locked down, and what that is worth

- `claude -p --restricted --safe-mode` loads no CLAUDE.md, skills, hooks, plugins or MCP. Its tools
  are Read, Grep, Glob and Bash, and in `dontAsk` mode Bash runs only the `settings.json` allowlist.
  Edit and Write don't exist for it.
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
  locked-down call, the outcome rule, rounds → ask-owner, the verdict file, and could-not-run for
  every bad input. 14 mutants of the script are all killed.
- [`tests/reviewer-live.sh`](../../tests/reviewer-live.sh) (`[runs]`, in a session only, because it
  calls the real model and CI runs no LLM jobs) runs the real reviewer on the A-04 fixtures in
  [`tests/fixtures/reviewer/`](../../tests/fixtures/reviewer) (spec: [`spec.md`](../../tests/fixtures/reviewer/spec.md)). The planted change (AC-4 skipped)
  must fail with exactly AC-4 unmet, and the honest one must pass.

## Limits

- Only specs whose acceptance items are named `AC-<n>` are reviewed. Others are could-not-run.
- What "run" can run is the allowlist above. Stack homes (W10.5.2) will extend it per stack. There
  is no browser yet, so the design and QA lenses review by reading.
- Rounds count distinct failing commits since the branch's last pass, and they don't reset when the
  owner decides something. Each further fail asks the owner again. Kept on purpose for now (owner,
  2026-10-12): if the north-star run or the reviewer eval (W10.6.4–5) shows repeat questions,
  reset the count when a commit changes the spec file.
- Publishing the verdict on the PR, per lens and tied to its commit (L-25), is W10.6.3.
