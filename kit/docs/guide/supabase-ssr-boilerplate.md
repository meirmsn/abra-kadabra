# Supabase SSR + Realtime + E2E Boilerplate

Canonical code patterns for any devshop project using Supabase + Next.js + Playwright. Source the snippets here when scaffolding a new project (`/ak-new-project § Step 12`) or adding a new env-var read site / Realtime-using table / E2E test (`/ak-implement` + `/ak-tests-review`).

Each pattern was codified from a real lalista incident (most from PR 26, 2026-04-26). Don't paraphrase the patterns; copy them verbatim and adapt the project-specific names. The behaviors they encode are subtle — drift breaks production silently.

---

## Pattern 1: `.trim()` defense at every `process.env.NEXT_PUBLIC_*` read site

**Why:** Vercel / GitHub / local `.env` are all surfaces where a copy-paste fat-finger can leave a trailing newline on an env var value. Without sanitization, the value flows into `fetch(url)` calls (via supabase-js or others) that throw on the malformed URL — uncaught in SSR — yielding a silent HTTP 500 on whichever route hits the bad path first.

Lalista PR 26 (2026-04-26): `NEXT_PUBLIC_SUPABASE_URL` had a trailing `\n` since project setup. Production `/` returned 500 because `apps/web/app/page.tsx`'s server component called `supabase.auth.getUser()` which fetched `https://...supabase.co\n/auth/v1/user`. `/sign-in` worked (client-rendered, no SSR auth). The `%0A` was also visible URL-encoded in the deployed CSP `connect-src` header.

**Apply to all 4 standard read sites in `apps/web/`:**

### `apps/web/lib/supabase/server.ts`

```ts
import { createServerClient } from '@supabase/ssr';
import { assertNotProdUrlInTestEnv, type Database } from '@<project>/core';
import { cookies } from 'next/headers';

export async function createClient() {
  // .trim() defends against whitespace-contaminated env vars on Vercel.
  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL ?? '').trim();
  const anonKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '').trim();
  assertNotProdUrlInTestEnv(url);
  const cookieStore = await cookies();
  return createServerClient<Database>(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Component — middleware handles cookie refresh.
        }
      },
    },
  });
}
```

### `apps/web/lib/supabase/client.ts`

```ts
'use client';

import { createBrowserClient } from '@supabase/ssr';
import { assertNotProdUrlInTestEnv, type Database } from '@<project>/core';

export function createClient() {
  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL ?? '').trim();
  const anonKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '').trim();
  assertNotProdUrlInTestEnv(url);
  return createBrowserClient<Database>(url, anonKey);
}
```

### `apps/web/middleware.ts` (excerpt — only the env-var read part)

```ts
const url = (process.env.NEXT_PUBLIC_SUPABASE_URL ?? '').trim();
const anonKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '').trim();
assertNotProdUrlInTestEnv(url);

const supabase = createServerClient(url, anonKey, {
  cookies: {
    /* ... */
  },
});
```

### Unit test pattern (mirror in `server.test.ts` + `client.test.ts`)

```ts
it('trims whitespace from URL + ANON_KEY env vars (Vercel fat-finger defense)', async () => {
  process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://project.supabase.co\n';
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = '  anon-key-abc\t';

  const { createServerClient } = await import('@supabase/ssr'); // or createBrowserClient
  const { createClient } = await import('./server'); // or ./client

  await createClient();

  const [url, key] = vi.mocked(createServerClient).mock.calls[0];
  expect(url).toBe('https://project.supabase.co');
  expect(key).toBe('anon-key-abc');
});
```

---

## Pattern 2: CSP `connect-src` builder handles BOTH `https→wss` and `http→ws`

**Why:** CSP scheme matching is strict — listing `https://<host>` does NOT permit `wss://<host>`. Supabase Realtime requires the `ws/wss` entry. The replace must handle both prod (https → wss) and local-stack (http → ws) cases; the http→ws case silently breaks Realtime against local Supabase in dev mode + `realtime.spec.ts` tests if missed.

Lalista PR 26 caught this: the test surfaced the bug. The original regex was `^https://` which was a no-op for `http://127.0.0.1:54321`, so the CSP allowed `http://` but not `ws://` and the realtime WebSocket was silently CSP-blocked.

### `apps/web/next.config.ts` (CSP builder excerpt)

```ts
{
  key: 'Content-Security-Policy',
  value: [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' <script-cdn-hosts>",
    "style-src 'self' 'unsafe-inline' <style-cdn-hosts>",
    "font-src 'self' <font-cdn-hosts>",
    // CSP treats schemes strictly. The replace handles both prod (https→wss)
    // and local-stack (http→ws). Missing http→ws silently breaks Realtime in
    // dev mode. .trim() defends against whitespace-contaminated env vars
    // (codified in supabase-ssr-boilerplate.md § Pattern 1).
    ((): string => {
      const supabaseUrl = (
        process.env.NEXT_PUBLIC_SUPABASE_URL ?? ''
      ).trim();
      const supabaseWs = supabaseUrl.replace(/^http(s?):\/\//, 'ws$1://');
      return `connect-src 'self' ${supabaseUrl} ${supabaseWs} <other-connect-hosts>`;
    })(),
    "img-src 'self' data: blob:",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join('; '),
},
```

---

## Pattern 3: E2E helpers — `helpers/admin-client.ts` with the 5 canonical exports

**Why:** Playwright tests against a slow-job CI Supabase need (a) a service-role client for DB-level assertions, (b) an anon-key client for auth round-trips that recover a user's UUID without touching the unreliable `auth.admin.listUsers()` API, (c) a local-stack predicate to skip cleanly on hosted Supabase, (d) a structural URL guard so a future spec that forgets the `test.skip(!isLocalSupabase, ...)` predicate refuses to dial hosted with admin credentials.

Lalista PR 26 codified all 5 exports in `apps/web/e2e/helpers/admin-client.ts`. Paste verbatim into new projects.

### `apps/web/e2e/helpers/admin-client.ts`

```ts
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL ?? '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

/** Predicate that matches the local Supabase stack URL shapes. */
export function isLocalSupabase(): boolean {
  return (
    SUPABASE_URL.startsWith('http://127.0.0.1:') ||
    SUPABASE_URL.startsWith('http://localhost:')
  );
}

/** Skip-reason string used by `test.skip(!isLocalSupabase(), ...)` in specs. */
export function localSupabaseSkipReason(specName: string): string {
  return `${specName} E2E requires a local Supabase stack (slow-job only)`;
}

/**
 * Service-role admin Supabase client. Refuses non-local-stack URLs
 * structurally — defense-in-depth so a forgotten test.skip() can't
 * accidentally dial hosted Supabase with admin credentials.
 */
export function adminClient(): SupabaseClient {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error(
      'admin-client requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY env vars (set in slow-job CI).'
    );
  }
  if (!isLocalSupabase()) {
    throw new Error(
      `admin-client refuses non-local Supabase with a service-role JWT (got ${SUPABASE_URL}). Pair with \`test.skip(!isLocalSupabase(), ...)\`.`
    );
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

/**
 * Anon-key Supabase client for tests that need a real auth round-trip
 * without admin privileges. Local-stack-only by symmetry with adminClient.
 */
export function anonClient(): SupabaseClient {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error(
      'anon-client requires SUPABASE_URL + SUPABASE_ANON_KEY env vars (set in slow-job CI).'
    );
  }
  if (!isLocalSupabase()) {
    throw new Error(
      `anon-client refuses non-local Supabase from test infra (got ${SUPABASE_URL}). Pair with \`test.skip(!isLocalSupabase(), ...)\`.`
    );
  }
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

/**
 * Resolve the user UUID for a known {email, password} pair via anon-client
 * sign-in. Avoids `admin.auth.admin.listUsers()` which 500s intermittently
 * in slow-job CI with accumulated test users.
 */
export async function userIdFromSignIn(
  email: string,
  password: string
): Promise<string> {
  const { data, error } = await anonClient().auth.signInWithPassword({
    email,
    password,
  });
  if (error || !data.user) {
    throw new Error(
      `userIdFromSignIn: signInWithPassword failed for ${email}: ${error?.message ?? 'no user returned'}`
    );
  }
  return data.user.id;
}
```

---

## Pattern 4: Realtime publication setup migration

**Why:** Supabase Realtime delivers `postgres_changes` events only for tables explicitly added to the `supabase_realtime` publication. Older Supabase CLI versions auto-included `FOR ALL TABLES`; newer versions don't always. Without an explicit migration, cross-session Realtime (`subscribeToList(...)` etc.) silently doesn't deliver — the subscriber stays connected but never receives INSERT/UPDATE/DELETE events.

Lalista PR 26 carry-forward: `realtime-cross-session-publication-setup` confirmed the publication wasn't including the project's monitored table on the slow-job CI's Supabase version.

### `supabase/migrations/<NNN>_realtime_publication.sql`

```sql
-- Add the table(s) you want cross-session Realtime delivery on.
-- Required for any subscribeToList / subscribeTo<X> helper to actually
-- receive postgres_changes events from other sessions' INSERT/UPDATE/DELETE.

alter publication supabase_realtime add table list_entries;
-- Repeat for any other table that needs realtime — purchase_history, etc.

-- ROLLBACK:
-- alter publication supabase_realtime drop table list_entries;
```

Verify post-apply with:

```bash
supabase db inspect-sql "SELECT pubname, schemaname, tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY tablename;"
```

The result should list every table your `subscribeTo*` helpers reference.

---

## Pattern 5: WebKit form-state hydration race in Playwright `mobile` tests

**Why:** Playwright's default `mobile` project uses `devices['iPhone SE']` which runs WebKit. Direct `page.goto('/sign-in')` followed by immediate `fill()` + `click()` on a controlled-input form races React 18's state-hydration — the input event dispatches but React state hasn't committed by the time the click fires, so the form's React-side validator (e.g. `EMAIL_FORMAT.test(email)`) runs against an empty state and rejects. Symptom: form refuses to submit on mobile only; no auth API call ever fires; assertions like `waitForURL(/\/list/)` time out.

Lalista PR 26 caught this on `auth-edge-cases.spec.ts:31`. Trace evidence: `fill("...@example.com")` succeeded, then `click(Continue)` 30ms later, snapshot at submit showed the form's own `<p role="alert">Enter a valid email address.</p>` (form has `noValidate`, so this is React, not HTML5). No `auth/v1/token` call in the network log.

### Workaround: navigate via a click chain, not direct goto

```ts
// ❌ BAD: races React state hydration on WebKit
await page.goto('/sign-in');
await page.getByLabel(/email/i).fill(email);
await page.getByLabel(/password/i).fill(password);
await page.getByRole('button', { name: /continue/i }).click();
await page.waitForURL(/\/list/);

// ✅ GOOD: navigate via the public landing's CTA — gives React time to hydrate
await page.goto('/');
await page.getByRole('link', { name: /get started/i }).click();
await page.waitForURL(/\/sign-in/);
await page.getByLabel(/email/i).fill(email);
await page.getByLabel(/password/i).fill(password);
await page.getByRole('button', { name: /continue/i }).click();
await page.waitForURL(/\/list/);
```

If your project doesn't have a public landing → /sign-in click chain, the alternative is `await page.waitForLoadState('networkidle')` after the direct goto. Less reliable than a real click navigation but works for most cases.

This applies to ANY controlled-input form on the WebKit project, not just sign-in. Apply the same pattern to onboarding, settings edits, etc. when E2E-testing form submits on mobile.

---

## Pattern 6: Testing realtime WebSocket failures with `page.routeWebSocket`, not `page.route().fulfill(503)`

**Why:** When E2E-testing "what happens when the realtime WebSocket fails?" (e.g. asserting a sync-error banner renders on `'CHANNEL_ERROR'`), the **wrong** API is `page.route('**/realtime/v1/websocket**', route => route.fulfill({status: 503}))`. supabase-js's realtime client absorbs the HTTP-503-on-WS-upgrade into its `onerror → onclose → silent-retry` loop without emitting `'CHANNEL_ERROR'` within any reasonable test budget — the banner never fires; the test either times out or (worse) silently passes when shaped as "no banner". The **right** API is `page.routeWebSocket(pattern, ws => ws.close())` (Playwright 1.48+), purpose-built for WebSocket interception. It triggers a deterministic close that supabase-js converts to `'CHANNEL_ERROR'` via the subscribe-status callback.

Lalista PR 26's `realtime.spec.ts` originally used the 503-fulfill shape; the test stayed `test.skip(true, ...)` for an entire PR cycle while diagnosis ran. PR 27 fixed both halves: switched to `routeWebSocket` AND extended `subscribeToList(..., callback, onError?)` to actually pass a status callback to `.subscribe()` — without the wrapper-side fix, the close fires but the banner-trigger path never gets the signal (see `wrapper-boundaries.md § Wrapper API design`).

### The pattern

```ts
import { test, expect } from '@playwright/test';

test('sync-error banner renders when realtime WebSocket fails', async ({
  page,
}) => {
  // ❌ DOES NOT WORK: supabase-js absorbs the 503 into a silent-retry loop
  // await page.route('**/realtime/v1/websocket**', route => route.fulfill({ status: 503 }));

  // ✅ WORKS: deterministic WS close → 'CHANNEL_ERROR' via subscribe-status callback
  await page.routeWebSocket('**/realtime/v1/websocket**', (ws) => ws.close());

  await page.goto('/list');
  await expect(
    page
      .getByRole('alert')
      .filter({ hasText: /connection lost|sync error|reconnecting/i })
  ).toBeVisible();
});
```

### Prereqs

1. **Playwright ≥ 1.48** — `page.routeWebSocket` was added in 1.48. Check `apps/web/package.json`'s `@playwright/test` pin and bump if needed.
2. **Wrapper exposes lifecycle events** — the close fires regardless, but the banner-trigger path is wired through the wrapper's status callback. If your wrapper around `supabase.channel(...).subscribe()` only exposes the data callback and swallows status, the close has no path to the banner. See `kit/docs/guide/wrapper-boundaries.md § Wrapper API design`.

### Assertion shape

Prefer `getByRole('alert')` + text-content match over a data-testid — keeps the test stable against small copy edits and forces the banner to be accessible to screen readers (real users with broken connectivity benefit). The text regex absorbs banner-copy variants ("Connection lost", "Sync error — reconnecting", etc.) without per-project tuning.

Cited prior art: lalista PR 26 (the original 503-fulfill shape + test.skip during diagnosis); lalista PR 27 (`routeWebSocket` switch + the `subscribeToList(..., onError?)` wrapper extension).

---

## Cross-references

- `/ak-new-project § Step 12 (Scaffold apps/web)` — the entry point that should apply Patterns 1, 2, 3 at scaffold time
- `/ak-implement` — when adding a new env-var read site (Pattern 1), Realtime-using table (Pattern 4), or E2E test (Patterns 5 + 6)
- `/ak-tests-review` — when reviewing E2E specs, flag direct-goto on WebKit (Pattern 5), missing realtime publication migration (Pattern 4), and `route().fulfill(503)` on realtime WS endpoints (Pattern 6)
- `kit/docs/guide/migrations.md § Supabase Hardening Defaults` — high-level rule pointing at this guide
- `kit/docs/guide/wrapper-boundaries.md § Wrapper API design` — companion rule that makes Pattern 6's banner-trigger path reachable
- Lalista PR 26 (2026-04-26) — the source incident for Patterns 1, 2, 3, 4 (carry-forward), 5, and Pattern 6 (initial 503-fulfill shape)
- Lalista PR 27 (2026-04-27) — Pattern 6 fix shipped (`routeWebSocket` switch + wrapper-side `onError` extension)
