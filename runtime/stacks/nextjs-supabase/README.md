# Next.js + Supabase

**Placeholder.** The real home for this stack is built with the first project that uses it (lalista
at M2: [PLAN](../../../kit/notes/revamp/PLAN.md), [lessons](../../../kit/notes/revamp/lessons.md)).
Until then a project on this stack gets no stack-specific guidance from here: follow the project's
own `CLAUDE.md` and docs, and say in the PR that this home is a placeholder.

It also serves as the north-star scenario's decoy (W10.5.3): the fixture, a Cloudflare Workers + D1
project that also has a `package.json`, must never load it. `tests/decoy-stack.test.sh` proves both
sides: it loads for a Next.js or Supabase project and never for the fixture's shape or near misses.
