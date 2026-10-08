# W5 — Stack isolation _(conditional — D-08; shrunk by REVIEW-1)_

Two projects run one stack (Next.js + Supabase + Vercel). Designing a general
capability contract from a single example would encode that stack as "the
abstraction". So: **isolate vendor code now; generalise only when a second stack is real.**
Findings: F-STACK-01, F-TPL-06, F-PIPE-13 (migrate).
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W5.1 Isolate vendor code — P2 · M4 · M

Done when: vendor-specific scripts/docs/template parts live under `stack/<vendor>/`
(e.g. `stack/supabase/`, `stack/vercel/`, `stack/nextjs/`, `stack/playwright/`); the
project selects them with one `stack:` line; a lint shows no vendor names in core;
fixture + one real project produce identical gate results before/after (V4 + V5).

- [ ] **W5.1.1** Move Supabase-specific gates/scripts (bootstrap, rollback round-trip, RLS coverage, advisor, local-env health) and guides under `stack/supabase/`; same for Vercel/Next/Playwright pieces — no behaviour change
- [ ] **W5.1.2** One `stack:` selector (plain `case`), vendor-name lint for core — V2
- [ ] **W5.1.3** Broaden the prod-URL test guard beyond `*.supabase.co` (custom domains) and route `proxy.ts` through it (F-TPL-06) — V2

## W5.2 Second stack — only when a real project commits to one · L

Done when: the second stack (likely Cloudflare Workers + D1) works on a tiny fixture,
and the capability contract (checks every stack must provide) is extracted from the
two real implementations, with contract tests.

- [ ] **W5.2.1** Build the second stack's scripts for the real project's needs
- [ ] **W5.2.2** Extract the shared contract + resolver + contract tests from both implementations
- [ ] **W5.2.3** Short "how to add a stack" guide

## W5.3 Adopting existing (non-devshop) apps — only when needed · M

- [ ] **W5.3.1** Stack detection from repo files proposes the `stack:` selection; `/ak-migrate-project` = detect → confirm → install pinned devshop → report uncovered parts (F-PIPE-13) — V4 on an existing repo
