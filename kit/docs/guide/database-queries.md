# Database queries

PostgREST's response shape on a failed query is the trap this guide closes: a non-existent column (typo, stale generated types, deliberately-unmapped FK) returns `{ data: null, error: { ... } }` — both fields populated. Call sites that destructure `data` and ignore `error` crash one frame later with a generic null-deref, swallowing the diagnostic. This guide codifies the error-first pattern that surfaces the real cause at the seam.

## Contents

- [The pattern](#the-pattern)
- [Where to apply it](#where-to-apply-it)
- [Why we don't ship a typed wrapper (yet)](#why-we-dont-ship-a-typed-wrapper-yet)
- [Cross-references](#cross-references)
- [PostgREST relationship inference does not chain through `auth.*`](#postgrest-relationship-inference-does-not-chain-through-auth)

When a Supabase / PostgREST query selects a column that doesn't exist (typo, stale type cache, deliberately-unmapped FK), the response is `{ data: null, error: { message: 'column "<x>" does not exist', ... } }` — both fields populated. Most call sites destructure `data` and ignore `error`, so the next line crashes with a generic `TypeError: Cannot read properties of null (reading '<field>')` and the actual root cause (the column-name typo) is swallowed. The bug looks like a null-data bug; debugging starts down the wrong path.

The convention: at every `.from(...).select(...)` call site, **check `error` first** and surface it before consuming `data`. Either inline the check or wrap the call in a helper that throws on `error` regardless of `data` shape.

## The pattern

```ts
// ❌ Swallows the column-typo error:
const { data } = await supabase
  .from('items')
  .select('id, name') // `items.name` doesn't exist — `name_canonical` does
  .single();
return data.id; // → TypeError: Cannot read properties of null (reading 'id')

// ✅ Surfaces the typo immediately:
const { data, error } = await supabase
  .from('items')
  .select('id, name_canonical')
  .single();
if (error) throw new Error(`items.select failed: ${error.message}`);
return data.id;
```

Two non-obvious shapes that hit the same trap:

1. **Typo'd column** — `from('table').select('id, nonexistent')` — the typo is in the SELECT list itself.
2. **Deliberately-unmapped FK** — `from('purchase_history').select('list_entry_id, ...')` when `purchase_history.list_entry_id` was intentionally not added at migration time. The `select` looks plausible against a casual reading of the schema; the error message is the only signal that the FK isn't there.

Both surface as `data: null`; both crash one frame later with a generic null-deref.

## Where to apply it

- **Every `.select()` call site** in API wrappers (`packages/core/src/api/**`) and any direct call elsewhere.
- **Both `.single()` and array selects** — `.single()` populates `error` on column-not-found AND on PGRST116 (zero-rows-when-one-expected); the array form populates `error` on column-not-found and returns `data: []` on zero rows. Both shapes need the `error`-first check.
- **Don't lean on `<T>` generics for safety** — `client.from<Row>('...')` is a compile-time cast against the generated types. If the generated types are stale (post-migration before `pnpm db:gen-types`), the cast lies; only the runtime `error` check catches it.

## Why we don't ship a typed wrapper (yet)

A `select()` helper that throws on `error` regardless of `data` would enforce this at the type-system level. We've deferred that until a third project hits the same bug — the call-site convention is cheap to land and lets each project apply it in the shape that fits their wrapper layer. If the convention drifts, the typed-wrapper option is `kit/TODOS.md` v1 candidate fodder.

## Cross-references

- `template/CLAUDE.md § Gotchas` — preemptive entry inherited by every new project explaining the failure mode + the `error`-first pattern (so the trap is documented before the project's first PostgREST query is written, not after the first incident).
- Lalista PR #49 (2026-05-07) — hit this twice in one PR (`items.name` typo + `purchase_history.list_entry_id` deliberately-unmapped FK), each surfacing as a generic null-deref in Playwright; root cause was found by re-reading the query against the schema, not by reading the swallowed error message.
- `kit/docs/guide/ops.md § Known Footguns § PostgREST null-deref masks column typos` — symptom-first surface of this rule (same trap, two phrasings).

## PostgREST relationship inference does not chain through `auth.*`

PostgREST's natural-join syntax — `from('child').select('parent!fk_name(col)')` — relies on a FK pointing directly at a table in a PostgREST-reachable schema (default `public`). It does NOT chain through `auth.*`: a FK from `public.child(user_id)` to `auth.users(id)` does not let you join through to `public.profiles(user_id)` via shared FK target.

The fix is a two-query read — first select the child rows, union the `user_id`s into a unique set, then issue a second `profiles.select('user_id, display_name').in('user_id', uniqueIds)` and dedupe + map. The two-query shape is load-bearing — don't "simplify" it back to a single join without also adding a direct `child.user_id → profiles.user_id` FK, which would conflict with any `ON DELETE SET NULL` semantics on the `auth.users` reference (see `migrations.md § ON DELETE on auth.users FK references`).

Render a graceful fallback in the UI when either side is null: the `auth.users` row may have been deleted (`SET NULL` clears the column), or the `profiles` row may be unreadable under RLS. A null-safe display string ("someone" / "deleted user") avoids a UI crash and matches the soft-delete semantics of `ON DELETE SET NULL`.
