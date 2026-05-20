# apps/web

Next.js 16 App Router shell, scaffolded by `/ak-new-project` from
`template/apps/web/`.

## Quick start

```bash
pnpm install
pnpm dev          # boots http://localhost:3000
pnpm test         # vitest (unit)
pnpm test:e2e     # playwright (boots dev server via `webServer`)
pnpm typecheck
```

## Where things live

- `app/` — App Router routes + layouts. `layout.tsx` is the document root;
  `globals.css` owns Tailwind v4 tokens + light/dark theme.
- `e2e/helpers/inbucket.ts` — Mailpit poller for magic-link / recovery
  E2Es (post-CLI-v2.x rename; helper name preserved for env-var
  continuity per `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 9`).
- `proxy.ts` — refreshes the Supabase session on every request (Next 16
  rename from `middleware.ts`). Defensively `.trim()`s `NEXT_PUBLIC_*`
  env vars per Pattern 1.
- `instrumentation.ts` + `sentry.{client,server,edge}.config.ts` —
  Sentry init across the three Next.js runtimes.
- `playwright.config.ts` — `webServer` block boots `pnpm dev`
  automatically so `pnpm test:e2e` is self-contained.
- `vitest.config.ts` — wires the `@/` alias (Vitest doesn't consume
  tsconfig paths by default).

## Env vars

Project consumers of Supabase / PostHog / Sentry read from
`NEXT_PUBLIC_*` env vars sourced via `apps/web/.env.local` (locally) or
piped to Vercel (deployed). See `/ak-new-project § Step 13 + Step 13b`
for the canonical wire-up.
