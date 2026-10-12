# Stack homes

One directory per stack, each the single home for that stack's setup, guidelines and lessons
(TARGET § L3 Reach). A change loads only the homes of the stacks its project uses: the `build`
skill runs [`scripts/stack-homes.sh`](../scripts/stack-homes.sh), which prints a `STACKS:` line for
the PR and the home of each stack that applies.

A stack home `<stack>/` holds:

- `README.md`: the home. It may link further files in the same directory.
- `detect`: project-relative paths or globs, one per line (`#` starts a comment), such as
  `wrangler.toml` or `next.config.*`. The stack applies when any of them exists in the project.
  A path that is absolute or leaves the project, a missing `README.md` or `detect`, or a `detect`
  with no paths stops the script (exit 2); it never skips a home it can't judge.

None ship yet: the first are built with the first projects that need them (M2). Proven by
[`tests/stack-homes.test.sh`](../../tests/stack-homes.test.sh).
