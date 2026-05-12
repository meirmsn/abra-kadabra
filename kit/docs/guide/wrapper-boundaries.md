# Wrapper boundaries

Two paired conventions that govern the seam between an external surface (LLM, edge function, event-emitter library) and the application code that consumes it: runtime validation of structured responses, and exposure of lifecycle / error events. Both rules harden the wrapper layer in `packages/core/src/api/**` against silent failures — the kind that surface five frames later as a generic null-deref or an unfired UX banner, not at the seam where the data shape actually broke.

## Contents

- [Runtime Validation at LLM / Edge-Function Boundaries](#runtime-validation-at-llm--edge-function-boundaries)
  - [Where to add it (and where not to)](#where-to-add-it-and-where-not-to)
  - [Schema module pattern](#schema-module-pattern)
  - [Wrapper boundary parse + typed error](#wrapper-boundary-parse--typed-error)
  - [How errors should surface](#how-errors-should-surface)
  - [Template scaffold](#template-scaffold)
- [Wrapper API design](#wrapper-api-design)
  - [Worked example: `subscribeToList` (lalista PR 27)](#worked-example-subscribetolist-lalista-pr-27)
  - [Test-time enforcement](#test-time-enforcement)
  - [Cross-references](#cross-references)
- [Removed-member realtime leak — thread invariant data back from the wrapper](#removed-member-realtime-leak--thread-invariant-data-back-from-the-wrapper)

## Runtime Validation at LLM / Edge-Function Boundaries

TypeScript's `client.functions.invoke<T>(...)` generic and `(await fetch()).json() as T` are compile-time assertions, not runtime checks — whatever the server returns flows through untyped. For most endpoints, generated types + CI drift check are enough; the values are mechanically derived from the same schema. **LLM-backed endpoints are the genuine exception**: a prompt tweak, model swap, or function refactor changes the output shape with zero compile-time signal, and the bug surfaces as `response.foo.bar is undefined` at the use site instead of a clear "the boundary returned an unexpected shape" error at the seam.

The convention: parse with [Zod](https://zod.dev/) at every LLM / edge-function boundary that returns structured data.

### Where to add it (and where not to)

| Boundary                                                                | Add Zod?                                    | Why                                                                                                |
| ----------------------------------------------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| LLM-backed edge function response (e.g. `add-item` returning `entries`) | **Yes**                                     | Output shape is implicit in the prompt; one prompt edit can change it silently.                    |
| Other Supabase Edge Function with hand-written response shape           | **Yes**                                     | Same boundary, same drift risk; the function's JSON-shape contract isn't enforced by the database. |
| Generic external HTTP API call (`fetch().json()`)                       | **Yes** if the API isn't under your control | Third-party shape drift is the original use case for runtime validation.                           |
| PostgREST query result (Supabase `.from(...).select(...)`)              | No                                          | `supabase gen types` + the CI type-drift check already enforce shape against the schema.           |
| Form input                                                              | No                                          | HTML5 attributes + platform validation cover this layer; Zod here adds bundle weight without ROI.  |
| App-internal function arguments / class methods                         | No                                          | TypeScript already proves these. Zod in this layer is paranoia, not validation.                    |

### Schema module pattern

- Schemas live in `packages/core/src/schemas/<feature>.ts` next to the API wrappers that call them.
- Use `z.infer<typeof Schema>` for the TypeScript type so one source produces both the runtime schema and the compile-time type — `models/index.ts` (or whatever the type-only module is called) re-exports the inferred type so call sites import the type from where they always have.
- Default to `.passthrough()` on object schemas: extra fields don't throw, so a future server-side addition (new field `confidence`, new field `entries[].brand`) doesn't crash old clients. Only require explicit shape; never require closed-set unknown fields.
- Use `.safeParse()` — never `.parse()`. The thrown-exception form skips the observability hook below; structured-result + branch lets the wrapper report cleanly to Sentry before throwing a typed error.

```ts
// packages/core/src/schemas/add-item.ts
import { z } from 'zod';

export const AddItemEntrySchema = z
  .object({
    name_canonical: z.string(),
    quantity: z.number().nullable().optional(),
    unit: z.string().nullable().optional(),
  })
  .passthrough();

export const AddItemResponseSchema = z
  .object({
    entries: z.array(AddItemEntrySchema),
    needs_followup: z.boolean().optional(),
    followup_options: z.array(z.string()).optional(),
  })
  .passthrough();

export type AddItemResponse = z.infer<typeof AddItemResponseSchema>;
```

### Wrapper boundary parse + typed error

The API wrapper (in `packages/core/src/api/<feature>.ts`) is the parse site — never inside a React component or a server action. Wrappers are the seam.

```ts
// packages/core/src/api/add-item.ts
import {
  AddItemResponseSchema,
  type AddItemResponse,
} from '../schemas/add-item';

export class AddItemValidationError extends Error {
  constructor(
    public readonly raw: unknown,
    public readonly issues: string
  ) {
    super(`add-item response failed validation: ${issues}`);
    this.name = 'AddItemValidationError';
  }
}

export async function invokeAddItem(
  client: SupabaseClient,
  payload: AddItemPayload
): Promise<AddItemResponse> {
  const { data, error } = await client.functions.invoke<unknown>('add-item', {
    body: payload,
  });
  if (error) throw error;

  const result = AddItemResponseSchema.safeParse(data);
  if (!result.success) {
    // Sentry capture BEFORE throw — gives observability a chance even if the
    // throw path is caught and silenced upstream. Scrub the raw payload of
    // anything user-identifying before sending; treat it as untrusted.
    Sentry?.captureException(new Error('add-item validation failed'), {
      extra: { issues: result.error.issues, raw_excerpt: scrubExcerpt(data) },
    });
    throw new AddItemValidationError(data, result.error.toString());
  }
  return result.data;
}
```

### How errors should surface

- **Sentry first**, with the issue list and a scrubbed payload excerpt. Untransformed payload is untrusted — it might contain user-typed text or LLM-paraphrased PII. Scrub before sending.
- **Throw a feature-named error class** (`{Feature}ValidationError`) so the existing app-level error boundary can render the right user-facing message ("we couldn't read the response — try again"), separate from a network error or an auth error.
- **Don't fall back to `as`-cast** when validation fails. The whole point of the gate is to refuse silently-broken data; coercing it back into the type system defeats the design.

### Template scaffold

`/ak-new-project` adds Zod to `packages/core/package.json` at scaffold time and creates `packages/core/src/schemas/` with a `README.md` pointing at this section. New projects inherit the convention; existing projects adopt it the first time they ship an LLM-backed endpoint (lalista PR 6, `feature/zod-validation`, is the canonical first-adopter — see `lalista/PRODUCT-ROADMAP.md § v0 § 1j`).

## Wrapper API design

When wrapping an event-emitter-style library — Supabase Realtime channel, EventEmitter, MQTT client, SSE source, raw WebSocket — the wrapper's signature must include a way for consumers to receive **error / lifecycle events**, not only the data event. If the wrapped library exposes a status callback (e.g. supabase-js's `.subscribe(statusCallback)`), pass it through. Consumers may choose to ignore it; the wrapper must not foreclose the option.

The failure mode this rule prevents is silent UX degradation: the data callback gets wired to a banner / sync indicator / error toast, but the path that should fire on async failure (`'CHANNEL_ERROR'`, `'TIMED_OUT'`, `onerror`, etc.) never receives the signal. Synchronous-throw paths (the WebSocket constructor failing immediately) are usually handled by a `try/catch` around the wrapper invocation; the async-failure path is the common one in production and the easy one to miss.

### Worked example: `subscribeToList` (lalista PR 27)

Before — only the data callback exposed; status events swallowed:

```ts
export function subscribeToList(
  client: SupabaseClient,
  householdId: string,
  callback: (entry: HydratedListEntry) => void
) {
  return client
    .channel(`list:${householdId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'list_entries',
        filter: `household_id=eq.${householdId}`,
      },
      callback
    )
    .subscribe(); // ← no status callback; CHANNEL_ERROR / TIMED_OUT never reach the consumer
}
```

After — `onError?` exposed; status callback wired:

```ts
export function subscribeToList(
  client: SupabaseClient,
  householdId: string,
  callback: (entry: HydratedListEntry) => void,
  onError?: (status: 'CHANNEL_ERROR' | 'TIMED_OUT') => void
) {
  return client
    .channel(`list:${householdId}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'list_entries',
        filter: `household_id=eq.${householdId}`,
      },
      callback
    )
    .subscribe((status) => {
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT')
        onError?.(status);
    });
}
```

The consumer (`ListClient.tsx`) wires `onError` to a sync-error banner. Without the wrapper change, the banner had no trigger path on real WS failures — the only way to fire it was a synchronous WebSocket-constructor throw (a near-zero-frequency path). Real production failures silently no-op'd the banner that was supposed to fire.

### Test-time enforcement

`/ak-tests-review` runs a deterministic check on PR diffs adding new wrappers in `packages/core/src/api/**`: any new exported function whose body calls `.subscribe(`, `.on(`, or `addEventListener(` and whose signature does NOT accept an `onError`-shaped parameter is flagged as a **critical** finding. The check is heuristic — false positives are negotiated at review time (e.g., a fire-and-forget wrapper that intentionally swallows lifecycle events) — but the default is "expose the lifecycle event."

### Cross-references

- `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 6` — the E2E recipe that exercises this rule (close the WS, assert the banner)
- `.claude/skills/devshop/tests-review/SKILL.md § Wrapper API design — lifecycle events not just data` — the deterministic check
- Lalista PR 27 (2026-04-26 → 2026-04-27) — surfaced the gap; closed both halves (wrapper signature + E2E recipe)

## Removed-member realtime leak — thread invariant data back from the wrapper

When a wrapper pairs a list query (REST) with a realtime subscription (WebSocket) on the same data, REST and Realtime tear down asymmetrically when membership changes. RLS on the REST side enforces "must be a member" on the next request — instant. The Realtime channel keeps emitting until the JWT refreshes — up to one JWT-refresh round-trip of leaked events to a removed member.

Mitigate by threading the membership invariant back through the wrapper's return shape, so the consumer can self-heal on every realtime tick:

```ts
// Before — bare array; consumer has no way to detect membership revocation
export async function fetchListEntries(client, householdId): Promise<Entry[]> { ... }

// After — return shape carries the membership signal
export async function fetchListEntries(client): Promise<{
  entries: Entry[];
  currentHouseholdId: string;
}> {
  const { data: hh } = await client.rpc('current_household_id');
  if (!hh) throw new RemovedFromHouseholdError();
  const { data: entries } = await client.from('list_entries').select('*');
  return { entries, currentHouseholdId: hh };
}
```

Consumers debounce-refetch on every realtime event; when the wrapper throws `RemovedFromHouseholdError`, the consumer tears down the subscription and routes the user to a "you've been removed" screen. Bounds the leak to ~1 round-trip.

Don't "simplify" the wrapper back to a bare array — the membership signal is the recovery path; collapsing the shape resurrects the leak.
