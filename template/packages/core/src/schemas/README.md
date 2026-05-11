# Schemas

Runtime [Zod](https://zod.dev/) schemas for boundaries TypeScript can't prove at compile time — primarily LLM-backed edge-function responses and external HTTP APIs not under your control.

One file per feature: `add-item.ts`, `<feature>.ts`. Each file exports the schema (`<Feature>ResponseSchema`) and the inferred type (`<Feature>Response = z.infer<typeof ...>`). The wrapper in `../api/<feature>.ts` is the parse site — call `.safeParse()`, report failures to Sentry with a scrubbed payload, and throw a typed `<Feature>ValidationError` so the app-level error boundary can render the right user-facing copy.

Defaults:

- `.passthrough()` on objects (don't crash on a forward-compat field).
- `.safeParse()`, never `.parse()` (gives observability a chance before the throw).
- `.optional()` / `.nullable()` only when the boundary genuinely permits absence — don't paper over server bugs by making everything optional.

When NOT to add a schema here: PostgREST queries (generated types + CI drift check cover them), form inputs (HTML5 + platform validation cover them), app-internal function arguments (TypeScript already proves these). Full rationale + worked examples: `/devshop/kit/docs/guide/wrapper-boundaries.md § Runtime Validation at LLM / Edge-Function Boundaries`.
