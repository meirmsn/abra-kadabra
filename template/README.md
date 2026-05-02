# <project-name>

<one-line description>

## Documentation

- [`OVERVIEW.md`](./OVERVIEW.md) — product map: what this app does, who uses it, core flows, features
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — system map: components, data flow, deployment topology, module map
- Per-package READMEs (when present): [`apps/<x>/README.md`](./apps), [`packages/<x>/README.md`](./packages), [`supabase/functions/README.md`](./supabase/functions)
- [`PLAN.md`](./PLAN.md) — what's being built right now · [`BUILD-LOG.md`](./BUILD-LOG.md) — what's shipped · [`PRODUCT-ROADMAP.md`](./PRODUCT-ROADMAP.md) — long-term

## Development

1. Open in VS Code and select **Reopen in Container**
2. Run `claude` in the terminal

### Commands

- `pnpm turbo run test:unit` — fast test loop
- `pnpm turbo run test` — full test suite
- `pnpm turbo run build` — production build
- `pnpm turbo run dev` — dev server

> Without the devcontainer: `pnpm install && pnpm turbo run dev`
