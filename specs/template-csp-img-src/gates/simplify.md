## Gate 4: /simplify

- Result: pass

Scope: the only executable code in `git diff origin/main...HEAD` is the CSP-builder
snippet in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`. Everything else
in the diff is markdown prose, a `template/apps/web/next.config.ts` header-comment
edit, and spec/tasks tracking files — no code to simplify there.

Judged the refactor of the inline IIFE from `((): string => ...)()` (single
`connect-src` string) to `...((): string[] => ...)()` (array-spread returning
`connect-src` + `img-src`):

- **Reuse:** Correct and minimal. `supabaseUrl` is computed once (with the Pattern 1
  `.trim()` landing once) and consumed by both directives; `supabaseWs` is derived
  once and used once. No duplicated env reads, no duplicated trim, no dead bindings.
  This is exactly the DRY goal the change states ("origin stays in lockstep").

- **Array-spread vs. const-lift:** Considered hoisting `supabaseUrl`/`supabaseWs`
  above the headers object and referencing them in two plain string entries (dropping
  the IIFE). Rejected as worse for this artifact: the snippet is a paste-in *fragment*
  of a `headers()` return value's `value: [...]` literal with no enclosing scope shown.
  A const-lift would force the bindings into an outer scope the excerpt doesn't depict,
  splitting the env-derivation away from the directives that use it and making the
  copy-paste boilerplate harder to drop in. The spread-of-IIFE keeps derivation and
  consumption co-located — the right shape here. Spread-of-IIFE is idiomatic TS for
  "emit N related array entries from shared local state," not over-clever.

- **Clarity / over-cleverness:** None found. The regex `^http(s?):\/\/` → `ws$1://`
  is unchanged from origin/main (pre-existing, already-reviewed). Comments are
  load-bearing (explain why the appended `${supabaseUrl}` on `img-src` is not
  redundant) and accurate; not noise.

Snippet is already clean — no fix recommended.

## Dismissals

None
