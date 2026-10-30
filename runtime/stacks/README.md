# Stack homes

One directory per stack, each the single home for that stack's setup, guidelines and lessons
(TARGET § L3 Reach). A change loads only the homes of the stacks its project uses: the `build`
skill runs [`scripts/stack-homes.sh`](../scripts/stack-homes.sh), which prints a `STACKS:` line for
the PR and the home of each stack that applies.

A stack home `<stack>/` holds:

- `README.md`: the home. It may link further files in the same directory.
- In `README.md`, a `## Set-up` section once the home is real: the owner's steps the stack needs
  (accounts, tokens, environments, hosts for the network allowlist), each with how the session
  checks it from outside, then Claude's steps. A new project starts stack-neutral; its first
  change names the stack in its spec and gives the owner these steps then
  ([spec](../../specs/new-project.md)).
- `detect`: project-relative paths or globs, one per line (`#` starts a comment), such as
  `wrangler.toml` or `next.config.*`. A line may also be `<path>: <pattern>`, which matches only
  when that file has a line matching the `grep -E` pattern, e.g. `package.json: "next" *:` for a
  Next.js dependency. The stack applies when any line matches in the project.
  The script stops (exit 2), and never skips a home it can't judge, when a home has no `README.md`
  or no `detect`, when its `detect` lists no paths, when a path is absolute or leaves the project,
  or when a pattern is empty or not a valid `grep -E` pattern.
- `supplies` (optional): the optional items of the project contract
  ([`runtime/project-contract.txt`](../project-contract.txt), [spec](../../specs/project-contract.md))
  that every project on this stack carries, one per line (`#` starts a comment), spelled as the
  contract spells them. When the stack applies, session start requires them; a line naming anything
  but an optional contract item makes the check can't-run, never a pass. A home without the file
  supplies nothing. Proven by [`tests/contract-check.test.sh`](../../tests/contract-check.test.sh).

A real home is built with the first project that needs it. Today there are two:

- [`cloudflare/`](cloudflare/README.md): Cloudflare Workers, written from the owner's website
  (W10.10.1) and the M1 fixture; loads for a project with a wrangler config
  ([`tests/cloudflare-stack.test.sh`](../../tests/cloudflare-stack.test.sh)).
- [`nextjs-supabase/`](nextjs-supabase/README.md): a placeholder until the pilot web app (M3); loads only for
  a Next.js or Supabase project ([`tests/decoy-stack.test.sh`](../../tests/decoy-stack.test.sh)).

Proven by [`tests/stack-homes.test.sh`](../../tests/stack-homes.test.sh).
