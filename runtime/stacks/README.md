# Stack homes

One directory per stack, each the single home for that stack's setup, guidelines and lessons
(TARGET § L3 Reach). A change loads only the homes of the stacks its project uses: the `build`
skill runs [`scripts/stack-homes.sh`](../scripts/stack-homes.sh), which prints a `STACKS:` line for
the PR and the home of each stack that applies.

A stack home `<stack>/` holds:

- `README.md`: the home. It may link further files in the same directory.
- `detect`: project-relative paths or globs, one per line (`#` starts a comment), such as
  `wrangler.toml` or `next.config.*`. A line may also be `<path>: <pattern>`, which matches only
  when that file has a line matching the `grep -E` pattern, e.g. `package.json: "next" *:` for a
  Next.js dependency. The stack applies when any line matches in the project.
  The script stops (exit 2), and never skips a home it can't judge, when a home has no `README.md`
  or no `detect`, when its `detect` lists no paths, when a path is absolute or leaves the project,
  or when a pattern is empty or not a valid `grep -E` pattern.

The first real homes are built with the first projects that need them (M2). Today there is one
placeholder, [`nextjs-supabase/`](nextjs-supabase/README.md), which is also the north-star decoy:
the fixture must never load it ([`tests/decoy-stack.test.sh`](../../tests/decoy-stack.test.sh)).
Proven by [`tests/stack-homes.test.sh`](../../tests/stack-homes.test.sh).
