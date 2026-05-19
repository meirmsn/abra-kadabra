# LLM trust boundaries

> Patterns for treating Large Language Model output as untrusted input — runtime validation of tool-use payloads, server-side defense against forced-tool-choice refusal, and shared schema validation at multiple trust boundaries.
>
> Stack-agnostic at the pattern level; examples reference `@anthropic-ai/sdk` because home-os is the first instance, but the patterns reproduce across OpenAI, Gemini, and any vendor's tool-use surface.

## Contents

- [The trust posture](#the-trust-posture)
- [Pattern 1: `tool_choice` forces, but the model can refuse](#pattern-1-tool_choice-forces-but-the-model-can-refuse)
- [Pattern 2: SDK tool-name version drift](#pattern-2-sdk-tool-name-version-drift)
- [Pattern 3: Shared schema validator at LLM-output + user-PATCH boundaries](#pattern-3-shared-schema-validator-at-llm-output--user-patch-boundaries)
- [Cross-references](#cross-references)

## The trust posture

A model response is **untrusted input**. The TypeScript type system says "this field is `string`" because the SDK's response type declares it that way. Runtime says: the model returned `null`, or an object instead of a string, or omitted the required field, or returned a tool_use block with `input` that doesn't match the declared schema.

Three trust-boundary postures to apply at every call site that ingests model output:

1. **Validate the response shape** against the tool's declared `input_schema` at runtime, regardless of TypeScript type narrowing. The schema is the contract; the type is a hint.
2. **Treat `tool_choice` forcing as a routing hint, not a guarantee.** The model can still respond with a text block (refusing the tool) or a malformed `tool_use.input`.
3. **Persist the model's payload AS-IS** for the audit trail, but make every downstream consumer parse it through the same validator. The validator is the trust seam.

## Pattern 1: `tool_choice` forces, but the model can refuse

When a route handler needs the model to produce a structured response, the SDK's `tool_choice: { type: 'tool', name: '<custom_tool_name>' }` is the right hammer. It tells the model "respond with a tool_use block named X" — almost always works.

But "almost always" is the wrong defense posture. The model can:

- Return a `text` block explaining inability + no `tool_use` block. (Most common refusal mode — "I cannot determine X from this image" instead of using the tool.)
- Return a `tool_use` block whose `input` is missing required fields, has invalid enum values, or has the wrong nesting.
- Return a `tool_use` block named differently than requested (rare with current models, but observed historically on capability boundaries).

### The recipe

For each tool-use surface, ship a runtime validator that returns a discriminated union:

```typescript
type ParseResult<T> =
  | { ok: true; value: T }
  | { ok: false; field: string; reason: string };

export function parseRecordInitialRead(
  content: ContentBlock[]
): ParseResult<InitialRead> {
  const toolBlock = content.find(
    (b) => b.type === 'tool_use' && b.name === 'record_initial_read'
  );
  if (!toolBlock)
    return { ok: false, field: '(root)', reason: 'no tool_use block' };
  // ... validate every field + enum + array-length constraint
}
```

Route handler dispatch:

```typescript
const response = await anthropic.messages.create({ /* ... */, tool_choice: { type: 'tool', name: '...' } });
const parsed = parseRecordInitialRead(response.content);
if (!parsed.ok) {
  await revertStateBestEffort();
  Sentry.captureException(new Error(`triage_invalid_output: ${parsed.field} — ${parsed.reason}`));
  return Response.json({ error: 'triage_invalid_output' }, { status: 502 });
}
// safe to persist parsed.value
```

The 502 (Bad Gateway) is the right status code — upstream returned a response we couldn't use.

### What the validator MUST check

- **All required fields are present.** Don't trust the SDK's TypeScript type assertion that a field exists — verify at runtime.
- **Enum values match the declared schema.** `severity: 'note' | 'watch' | 'act_soon'` means the validator rejects `'mild'` even if the type system silently accepts it.
- **Array length bounds.** A `what_i_need_to_know: string[]` with `minItems: 1, maxItems: 3` in the schema needs a runtime `Array.isArray(x) && x.length >= 1 && x.length <= 3` check.
- **Nested object shapes.** A `sources: { url: string; title: string }[]` field needs each row validated.
- **Forward-compat tolerance.** Extra fields in the response are OK — don't reject on "unknown property X" because the model may add fields the validator doesn't yet know about. Only reject on missing-required or wrong-shape.

### Force-confirm semantics

When the route forces a specific tool (`tool_choice: { type: 'tool', name: 'confirm_assessment' }` after 3 rounds OR on user-skip), the model can still:

- Return `ask_next_question` (defying the force).
- Return `confirm_assessment` with malformed input.

The route still dispatches through the same `parseQaTurn(...)` validator and branches on `parsed.tool` (the discriminated union's tag). Force-confirm doesn't bypass validation; it just routes the parsed result to `confirm_triage` RPC instead of `answer_triage_round`. If `parsed.ok === false`, return 502 — DO NOT persist a half-validated payload.

Home-os instance: `apps/web/app/api/triage/route.ts` + `apps/web/app/api/triage/answer/route.ts` + `apps/web/app/api/triage/_lib/parse-tool-output.ts` + `apps/web/app/api/triage/_lib/parse-qa-output.ts`.

## Pattern 2: SDK tool-name version drift

Vendor SDKs version server tools (web_search, code_execution, computer_use) by date string in their `type` field. When the SDK ships a new version, the `ToolUnion` may include TWO variants of the same tool — both shareable, semantically different.

**Don't take the type-string from memory or vendor docs.** The SDK pinned in `package.json` is the source of truth.

### The recipe

For each server tool used, declare an explicit constant pinned to the SDK version:

```typescript
// apps/web/app/api/triage/_lib/anthropic.ts
// Pinned to @anthropic-ai/sdk@0.96.0 — re-verify on every SDK bump.
// Verified via: grep -E "WebSearchTool[0-9]+" node_modules/@anthropic-ai/sdk/resources/messages/messages.d.ts
export const WEB_SEARCH_TOOL_TYPE = 'web_search_20260209' as const;
export const DEFAULT_TRIAGE_MODEL = 'claude-sonnet-4-6' as const;
```

When bumping the SDK version:

1. `grep -E "<ToolName>[0-9]+" node_modules/<vendor-sdk>/...d.ts` for the available variants.
2. Pick the newest variant compatible with your prompt + tool schema.
3. Update the constant and re-run the integration test that exercises the tool.
4. Update the version comment.

The constant lives in code, not in CLAUDE.md or a guide — it's a single-file concern that next-reader of the file should see at the call site.

### Why this is borderline-loud-not-silent

The SDK's TypeScript type system catches OBVIOUSLY wrong values (`'web_search_made_up'` won't compile). But two valid type-string options of the same tool may have subtly different behavior — model trained on one variant, request shipped with the other, the model's response shape differs in ways that pass parse-validation but fail downstream consumer assumptions. The constant + grep-recipe is the cheap defense; the integration test is the empirical verifier.

## Pattern 3: Shared schema validator at LLM-output + user-PATCH boundaries

When the same shape needs validating at TWO trust boundaries — LLM output AND user-PATCH input — the validator is **one module imported at both call sites**. NOT inlined per call site (silent drift over time guaranteed).

The home-os `decide-state` work locked two jsonb shapes (`DiyExpansion`, `ContractorExpansion`) that:

- Claude's `confirm_assessment` tool output populates (`apps/web/app/api/triage/_lib/parse-qa-output.ts § parseConfirmAssessment`).
- User-PATCH on `/api/card/[id]/estimate` overrides (`apps/web/app/api/card/[id]/estimate/_lib/parse-estimate-override.ts`).

Both trust boundaries delegate to the shared module:

```typescript
// apps/web/app/api/triage/_lib/estimate-shapes.ts
export function parseDiyExpansion(input: unknown): ParseResult<DiyExpansion> {
  /* ... */
}
export function parseContractorExpansion(
  input: unknown
): ParseResult<ContractorExpansion> {
  /* ... */
}
```

Both call sites import + use:

```typescript
// parse-qa-output.ts (LLM-output boundary)
import { parseDiyExpansion, parseContractorExpansion } from './estimate-shapes';

// parse-estimate-override.ts (user-PATCH boundary)
import {
  parseDiyExpansion,
  parseContractorExpansion,
} from '../../../../triage/_lib/estimate-shapes';
```

When the shape tightens (new required field, narrower enum), both trust boundaries get the update for free. When the shape relaxes, same.

### What NOT to do

- **Don't inline the validator per call site.** Silent shape drift over months; one path will accept what the other rejects.
- **Don't put the validator on the consumer side.** "The route handler parses; the LLM module just calls the SDK" sounds clean but means LLM-output validation has to be duplicated everywhere an LLM call is made.
- **Don't put the validator in the database layer.** Postgres `jsonb` can declare CHECK constraints (`jsonb_typeof`, `jsonb_path_query`) but they're slow + hard to evolve compared to a TypeScript validator. Keep the validator at the application boundary; the database trusts the application.

### When the shapes diverge

If at some point the LLM-output shape NEEDS to differ from the user-PATCH shape (LLM produces a fuller object; user PATCH allows partial), keep the SHARED CORE in `estimate-shapes.ts` and add boundary-specific wrappers:

```typescript
// estimate-shapes.ts — the canonical shapes
export const DIY_EXPANSION_BASE = {
  /* shared fields */
};

// parse-qa-output.ts
export function parseLlmDiyExpansion(
  input: unknown
): ParseResult<LlmDiyExpansion> {
  // calls parseDiyExpansion + requires additional LLM-only fields
}

// parse-estimate-override.ts
export function parseUserDiyExpansion(
  input: unknown
): ParseResult<UserDiyExpansion> {
  // calls parseDiyExpansion + allows partial / has narrower allowlist
}
```

Resist this if at all possible — divergence is where the drift creeps back in.

## Cross-references

- `kit/docs/guide/wrapper-boundaries.md § Runtime Validation at LLM / edge-function boundaries` — the parent pattern this guide refines for the tool-use case specifically.
- `kit/docs/guide/database-queries.md § The pattern` — sibling trust-boundary pattern (PostgREST error swallowing); same posture, different vendor.
- Home-os PR `triage-route-handler` (#19) — Pattern 1 origin. `apps/web/app/api/triage/_lib/parse-tool-output.ts` is the canonical home-os validator.
- Home-os PR `triage-conversation` (#26) — Pattern 1 extended for Q&A turn dispatch.
- Home-os PR `decide-state` (#27) — Pattern 3 origin. `apps/web/app/api/triage/_lib/estimate-shapes.ts` is the canonical shared validator.
- Home-os `apps/web/app/api/triage/_lib/anthropic.ts` — Pattern 2 instance.
