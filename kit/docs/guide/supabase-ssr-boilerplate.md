# Supabase SSR + Realtime + E2E Boilerplate

Canonical code patterns for any devshop project using Supabase + Next.js + Playwright. Source the snippets here when scaffolding a new project (`/ak-new-project § Step 12`) or adding a new env-var read site / Realtime-using table / E2E test (`/ak-implement` + `/ak-tests-review`).

Each pattern was codified from a real lalista incident (most from PR 26, 2026-04-26). Don't paraphrase the patterns; copy them verbatim and adapt the project-specific names. The behaviors they encode are subtle — drift breaks production silently.

## Contents

- [Pattern 1: `.trim()` defense at every `process.env.NEXT_PUBLIC_*` read site](#pattern-1-trim-defense-at-every-processenvnext_public_-read-site)
- [Pattern 2: CSP `connect-src` builder handles BOTH `https→wss` and `http→ws`](#pattern-2-csp-connect-src-builder-handles-both-httpswss-and-httpws)
- [Pattern 3: E2E helpers — `helpers/admin-client.ts` with the 5 canonical exports](#pattern-3-e2e-helpers--helpersadmin-clientts-with-the-5-canonical-exports)
- [Pattern 4: Realtime publication setup migration](#pattern-4-realtime-publication-setup-migration)
- [Pattern 5: WebKit form-state hydration race in Playwright `mobile` tests](#pattern-5-webkit-form-state-hydration-race-in-playwright-mobile-tests)
- [Pattern 6: Testing realtime WebSocket failures with `page.routeWebSocket`, not `page.route().fulfill(503)`](#pattern-6-testing-realtime-websocket-failures-with-pageroutewebsocket-not-pageroutefulfill503)
- [Pattern 7: `emailRedirectTo` origin resolution + query-string survival](#pattern-7-emailredirectto-origin-resolution--query-string-survival)
- [Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows](#pattern-8-middleware-allow-list-authed-bypass-carve-out-for-recovery-flows)
- [Pattern 9: E2E mail helper for Mailpit (post-CLI-v2.x rename from Inbucket)](#pattern-9-e2e-mail-helper-for-mailpit-post-cli-v2x-rename-from-inbucket)
- [Pattern 10: Host-anchored redirect in `/auth/*` route handlers](#pattern-10-host-anchored-redirect-in-auth-route-handlers)
- [Cross-references](#cross-references)

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

**See also:** [`migrations.md § Realtime publication setup`](./migrations.md#realtime-publication-setup) — the convention layer that restates this rule and ties it to FK-cascade discipline; Pattern 4 here is the migration template, migrations.md is the convention-doc target.

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

## Pattern 7: `emailRedirectTo` origin resolution + query-string survival

Two coupled rules for any `signUp` / `signInWithOtp` / `resetPasswordForEmail` call site that passes `emailRedirectTo`.

**Origin resolution prefers an env var, falls back to `window.location.origin`:**

```ts
const origin = process.env.NEXT_PUBLIC_SITE_URL ?? window.location.origin;
await supabase.auth.signUp({
  email,
  password,
  options: { emailRedirectTo: `${origin}/auth/callback?invite=${token}` },
});
```

Set `NEXT_PUBLIC_SITE_URL` on **Production** Vercel to pin the canonical URL even if the call ever runs from an unusual origin (CDN proxy, iframe). Leave it **unset on Preview** so previews self-route via `window.location.origin` — preview-to-preview testing works without a per-deploy env-var update.

**Query strings on `emailRedirectTo` survive Supabase's redirect-URL allow-list, but verify empirically before relying on it.** Supabase's Auth → URL Configuration matches by path, not query — an entry for `https://<host>/auth/callback` covers `?invite=<token>`, `?reset=<id>`, etc., automatically. Pre-merge manual test: trigger a real `signUp` against the prod Supabase project with `emailRedirectTo: <site>/auth/callback?test=42`, fetch the resulting email, confirm the link in the email body still contains `?test=42`. If not, add a wildcarded entry to Auth → URL Configuration. Make this a HARD BLOCKER on the PR test plan for any feature whose mechanism depends on the query-string surviving.

---

## Pattern 8: Middleware allow-list authed-bypass carve-out for recovery flows

Most marketing/auth-screen routes (`/sign-in`, `/sign-up`, `/forgot-password`) should bounce authed users away — visiting them mid-session is a confused state. Recovery routes (`/reset-password`, `/auth/callback`) are different: they arrive WITH a session because the route handler created one (magic-link exchange, recovery-token exchange).

```ts
// apps/web/middleware.ts
const PUBLIC_PATHS = [
  '/',
  '/sign-in',
  '/sign-up',
  '/forgot-password',
  '/reset-password',
  '/auth/callback',
];
const AUTHED_BOUNCE_PATHS = ['/sign-in', '/sign-up', '/forgot-password'];
// NOT in AUTHED_BOUNCE_PATHS: '/reset-password', '/auth/callback'

if (session && AUTHED_BOUNCE_PATHS.includes(path)) {
  return NextResponse.redirect(new URL('/list', req.url));
}
```

Bouncing authed users away from `/reset-password` would break recovery — the user arrives with the session the route handler just minted and immediately gets redirected away from the password form. Same for `/auth/callback` — the exchange happens inside that handler.

PWA `start_url` should point at the authed landing route (e.g. `/list`) so installed users skip the marketing screen on launch.

---

## Pattern 9: E2E mail helper for Mailpit (post-CLI-v2.x rename from Inbucket)

Supabase CLI v2.x swapped the local-stack mail catcher from **Inbucket** to **Mailpit** but kept the env-var name `INBUCKET_URL` (the `supabase status -o env` output emits both `INBUCKET_URL` and `MAILPIT_URL` pointing at the same port). The two services share a port but expose **incompatible REST APIs**: an Inbucket-shaped helper hitting `/api/v1/mailbox/<addr>` against Mailpit returns nothing — and the magic-link E2E spec times out at the poll without a clear failure signal.

Lalista hit this on slow-job rollout; home-os hit it on PR #15 magic-link spec. Canonical helper below — keep the filename `helpers/inbucket.ts` for grep-continuity with old specs, but rename the comments to reflect Mailpit:

### `apps/web/e2e/helpers/inbucket.ts`

```ts
// What: Tiny helper for fetching emails from the local Supabase mail relay
//       (Mailpit; previously Inbucket pre-CLI v2.x) and parsing the most
//       recent magic-link URL out of the message body.
// Why: Sign-up confirmation, forgot-password, magic-link, and invite E2Es
//      need to follow the magic-link the way a real user would. Mailpit
//      exposes a JSON API at port 54324 (default) that we poll until the
//      message lands.
// Does NOT: Talk to hosted Supabase (email-template rendering happens on
//           Supabase's mail relay there; specs gate on the local stack
//           via isLocalSupabase()).
//
// Naming: file is `inbucket.ts` for historical reasons — Supabase CLI swapped
// inbucket for mailpit in v2.x and never updated the env var name (it still
// surfaces as INBUCKET_URL in `supabase status -o env`). The relay is mailpit;
// the helper name preserves the env-var naming for grep continuity.

/**
 * Derive mailpit's host from SUPABASE_URL so the helper works in both:
 *   - Workspace devcontainer (test SKIPS here — `isLocalSupabase()` only
 *     trues for 127.0.0.1/localhost shapes, not the workspace's
 *     `host.docker.internal` URL).
 *   - GitHub Actions slow-job: SUPABASE_URL=http://127.0.0.1:54321 (Supabase
 *     binds directly to the runner's localhost; mailpit listens on 54324
 *     on the same host).
 */
function deriveMailpitBase(): string {
  const supabaseUrl = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
  try {
    const host = new URL(supabaseUrl).hostname;
    return `http://${host}:54324`;
  } catch {
    return 'http://127.0.0.1:54324';
  }
}

const MAILPIT_BASE = deriveMailpitBase();

interface MailpitSummary {
  ID: string;
  From: { Name: string; Address: string };
  To: { Name: string; Address: string }[];
  Subject: string;
  Snippet: string;
  Created: string;
}

interface MailpitListResponse {
  total: number;
  messages_count: number;
  start: number;
  messages: MailpitSummary[];
}

interface MailpitMessage {
  HTML?: string;
  Text?: string;
}

export interface EmailSummary {
  id: string;
  subject: string;
  to: string;
  date: string;
}

/**
 * Wait until mailpit has at least `minCount` messages addressed to `address`,
 * then return the latest summary. Polls every 500ms up to the given timeout.
 *
 * We use mailpit's search endpoint (`/api/v1/search?query=to:<addr>`) so
 * cross-test mailbox pollution from other parallel specs doesn't trip us up.
 */
export async function waitForLatestEmail(
  address: string,
  options: { minCount?: number; timeoutMs?: number } = {}
): Promise<EmailSummary> {
  const minCount = options.minCount ?? 1;
  const timeoutMs = options.timeoutMs ?? 30_000;
  const start = Date.now();
  let lastErr: unknown = null;
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(
        `${MAILPIT_BASE}/api/v1/search?query=${encodeURIComponent(`to:${address}`)}&limit=50`
      );
      if (res.ok) {
        const data = (await res.json()) as MailpitListResponse;
        if (data.messages.length >= minCount) {
          const m = data.messages[0]!;
          return {
            id: m.ID,
            subject: m.Subject,
            to: m.To[0]?.Address ?? address,
            date: m.Created,
          };
        }
      }
    } catch (err) {
      lastErr = err;
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(
    `mailpit: no message for ${address} after ${timeoutMs}ms (expected at least ${minCount}; base=${MAILPIT_BASE}; lastErr=${lastErr instanceof Error ? lastErr.message : String(lastErr)})`
  );
}

/** Fetch the full body for a given mailpit message. */
export async function fetchEmailBody(
  _address: string,
  id: string
): Promise<{ body?: { html?: string; text?: string } }> {
  const res = await fetch(`${MAILPIT_BASE}/api/v1/message/${id}`);
  if (!res.ok) {
    throw new Error(
      `mailpit: failed to fetch message ${id} (status ${res.status}; base=${MAILPIT_BASE})`
    );
  }
  const data = (await res.json()) as MailpitMessage;
  return { body: { html: data.HTML, text: data.Text } };
}

/**
 * Pull the magic-link URL out of an email body. HTML body carries the
 * rendered template (anchor href); text body carries the plain-text link.
 * Try HTML first, fall back to text.
 *
 * Link path shape depends on Supabase's flow:
 *   - Token-hash flow (default `{{ .ConfirmationURL }}`):
 *     `{SiteURL}/auth/v1/verify?token=<hash>&type=<type>&redirect_to=<...>`
 *   - Direct PKCE flow: link points at redirect_to with `?code=<...>` appended.
 * Either is fine for E2E — `page.goto(link)` follows redirects — so the
 * regex matches both.
 */
export function extractMagicLink(message: {
  body?: { html?: string; text?: string };
}): string {
  const html = message.body?.html ?? '';
  const text = message.body?.text ?? '';
  const re =
    /https?:\/\/[^\s"'<>]*(?:\/auth\/v1\/verify|\/verify|\/auth\/callback|[?&](?:code|token|token_hash)=)[^\s"'<>]*/i;
  const fromHtml = html.match(re)?.[0];
  if (fromHtml) return rewriteBareVerify(decodeHtmlEntities(fromHtml));
  const fromText = text.match(re)?.[0];
  if (fromText) return rewriteBareVerify(decodeHtmlEntities(fromText));
  throw new Error(
    `mailpit: no auth-flow URL found in email body (html=${html.slice(0, 400)}…, text=${text.slice(0, 400)}…)`
  );
}

/**
 * Some Supabase CLI versions render `{{ .ConfirmationURL }}` with a bare
 * `/verify?...` path on the auth host (`http://127.0.0.1:54321/verify?...`)
 * instead of the Kong-prefixed `/auth/v1/verify?...`. The bare path 404s
 * because Kong only proxies `/auth/v1/*`. We rewrite to the Kong path so
 * the recovery flow exercises end-to-end. Production hosted Supabase
 * doesn't have this issue (the external URL includes /auth/v1 by default).
 */
function rewriteBareVerify(url: string): string {
  return url.replace(
    /^(https?:\/\/[^/]+)\/verify(\?|$)/,
    '$1/auth/v1/verify$2'
  );
}

/**
 * Decode the handful of HTML entities that show up in an `href`. Supabase's
 * email template renders `{{ .ConfirmationURL }}` into an HTML-escaped href,
 * so `?token=foo&type=recovery` becomes `?token=foo&amp;type=recovery`.
 * Passing that to `page.goto` would treat `&amp;` as a literal query
 * separator and Supabase 400s with "Verify requires a verification type."
 */
function decodeHtmlEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&#x2F;/gi, '/')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}
```

### Why each block is load-bearing

| Block                                               | Why                                                                                                                                                                                                         |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `deriveMailpitBase()` parses SUPABASE_URL hostname  | Works in CI (`127.0.0.1`) AND any future devcontainer setup where the local stack lives at `host.docker.internal` — no env-var fork.                                                                        |
| `rewriteBareVerify()`                               | Defensive — some CLI versions emit `<host>/verify?...` (bare) instead of `<host>/auth/v1/verify?...`. The bare path 404s because Kong only proxies `/auth/v1/*`. A no-op if the URL already has the prefix. |
| `decodeHtmlEntities()`                              | Supabase's email template HTML-escapes `&` → `&amp;`. Without decoding, `page.goto(url)` parses `&amp;type=recovery` as `amp;type=recovery` and the verify endpoint 400s with "missing type parameter".     |
| Wider regex (`?code=` / `?token=` / `?token_hash=`) | Covers both PKCE (`?code=`) and implicit (`?token=`) flow shapes; works even when Supabase tweaks the template URL path.                                                                                    |
| Three-function split (wait / fetch / extract)       | Lets specs assert subject/recipient before extracting the link (useful for sign-up vs reset-password discrimination); single-function shape works for one spec but doesn't compose.                         |
| 30s timeout / 500ms poll / `minCount` parameter     | Slow-job runner cold-starts the Mailpit container; 10s default flakes. `minCount > 1` covers "wait for resend" patterns.                                                                                    |

### How port is sourced

Helper hardcodes **54324** (Supabase default mailpit port). Projects that rebound ports (e.g., the home-os +100 rebound shift: db 54422, mailpit 54424) must update the constant accordingly — there is no env var that surfaces only the mailpit port from `supabase status -o env`, so the helper can't derive it dynamically. If you rebound the supabase ports in `supabase/config.toml`, also update `deriveMailpitBase()`'s port constant.

---

## Pattern 10: Host-anchored redirect in `/auth/*` route handlers

Don't use `new URL(path, request.url)` in `/auth/callback` or `/auth/signout` route handlers. **Next.js 16 normalizes `request.url`'s hostname to whatever Next is configured for (defaults to `localhost`), regardless of the actual Host header on the incoming request.** Combined with browser-side cookies that scope by request host and CSP `form-action 'self'` enforcement on the final redirect target, this produces two distinct failure modes:

1. **`/auth/callback` (GET):** Client visits `http://127.0.0.1:3000/auth/callback?code=...`. Handler sets session cookies on `127.0.0.1` (via `@supabase/ssr` setAll, no Domain= attribute → host-scoped). Handler then `new URL('/home', request.url)` → emits `http://localhost:3000/home`. Browser follows redirect to `localhost` — cookies on `127.0.0.1` are NOT sent. Middleware on `/home` sees an anonymous request → bounces to `/login?next=/home`. The user never reaches the authed area.

2. **`/auth/signout` (POST):** Form on `http://127.0.0.1:3000/home` POSTs to `/auth/signout` (resolves to `127.0.0.1:3000/auth/signout`). Handler returns `303 Location: http://localhost:3000/login`. The page's CSP `form-action 'self'` evaluates the final redirect target (browsers MUST check the redirect chain, not just the initial action) — `localhost:3000` is a different origin from `127.0.0.1:3000`. The browser silently aborts the redirect. Form submit POST shows status `-1` in network traces; page stays on `/home`; sign-out never completes.

Home-os PR #15 hit both during slow-job rollout. Fix: anchor the redirect on the actual request Host header, not the normalized `request.url`.

### The helper

```ts
// apps/web/app/auth/_lib/same-origin-url.ts (or inline per route)
import type { NextRequest } from 'next/server';

/** Build a same-origin redirect URL anchored on the request's Host header
 *  rather than `request.url`'s host. See kit/docs/guide/supabase-ssr-boilerplate.md
 *  § Pattern 10 for the failure modes this defends against.
 *
 *  Security: callers MUST sanitize `path` to a same-origin relative URL
 *  (start with `/`, NOT `//`) — see `safeNext` below. A spoofed Host
 *  header otherwise opens an open-redirect class.
 */
export function sameOriginUrl(request: NextRequest, path: string): string {
  const host = request.headers.get('host') ?? new URL(request.url).host;
  const proto =
    request.headers.get('x-forwarded-proto') ??
    new URL(request.url).protocol.replace(':', '');
  return `${proto}://${host}${path}`;
}
```

### `apps/web/app/auth/callback/route.ts` shape

```ts
import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { sameOriginUrl } from '../_lib/same-origin-url';

export const dynamic = 'force-dynamic';

/** Same-origin redirect target. Accept only paths that begin with `/` and
 *  are NOT protocol-relative (`//evil.example`). Closes the open-redirect
 *  class. */
function safeNext(raw: string | null): string {
  if (!raw) return '/home';
  if (!raw.startsWith('/') || raw.startsWith('//')) return '/home';
  return raw;
}

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const next = safeNext(url.searchParams.get('next'));

  if (!code) {
    return NextResponse.redirect(
      sameOriginUrl(request, '/login?error=callback_failed'),
      { status: 303 }
    );
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(
      sameOriginUrl(request, '/login?error=callback_failed'),
      { status: 303 }
    );
  }

  return NextResponse.redirect(sameOriginUrl(request, next), { status: 303 });
}
```

### `apps/web/app/auth/signout/route.ts` shape

```ts
import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { sameOriginUrl } from '../_lib/same-origin-url';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(sameOriginUrl(request, '/login'), {
    status: 303,
  });
}

function methodNotAllowed() {
  return new Response(null, { status: 405, headers: { Allow: 'POST' } });
}
export const GET = methodNotAllowed;
export const PUT = methodNotAllowed;
export const PATCH = methodNotAllowed;
export const DELETE = methodNotAllowed;
```

### Unit-test mock shape

The handlers read `request.headers.get('host')` AND `request.url`. The test's `mockRequest()` must stub both:

```ts
function mockRequest(url: string): NextRequest {
  const parsed = new URL(url);
  const headers = new Headers({ host: parsed.host });
  return { url, headers } as unknown as NextRequest;
}
```

### When this isn't a problem in production

Vercel (and most managed hosts) terminate TLS upstream and forward requests with the canonical Host header in `x-forwarded-host` + the public hostname in `host`. `request.url` is then constructed correctly because the host matches the configured `NEXT_PUBLIC_SITE_URL` / project domain. The bug only surfaces locally and in CI where multiple loopback aliases (`127.0.0.1` vs `localhost`) are reachable on the same Next process — the symptom looks like "cookies aren't being set" but is actually "cookies are being set on the wrong host".

---

## Pattern 11: App Router layout-vs-page render race — defense-in-depth auth re-check

In Next.js App Router, the layout and the page's server-component data fetches run **in parallel** when both are server components. If both can throw, the **first throw wins** — and the order isn't deterministic across cold/warm caches or fresh-after-POST navigations.

This bites authenticated routes that rely SOLELY on the layout for auth gating:

```
app/(app)/layout.tsx         — calls supabase.auth.getUser(); redirect('/login') if null
app/(app)/cards/[id]/page.tsx — calls supabase.from('cards').select() under RLS
```

The page's RLS-scoped query can run concurrently with the layout's `getUser()` and throw `notFound()` (because the unauthenticated client sees zero rows under RLS) **before** the layout throws `redirect('/login')`. Result: a fresh-after-POST navigation that should bounce to `/login` instead produces a confusing 404. The user sees "not found" for content they could view if signed in, with no clear path forward.

### The fix — re-check auth in the page

Re-call `getUser()` at the top of the page and `redirect()` early before any RLS-scoped query:

```tsx
// app/(app)/cards/[id]/page.tsx
export default async function CardDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params; // Next 16 requires await for params
  const supabase = await createSupabaseServerClient();

  // Defense in depth: layout redirects too, but the page can throw notFound() before
  // the layout's redirect fires (server components run in parallel; first throw wins).
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/login?next=/cards/${id}`);

  // Now safe to do RLS-scoped queries — getUser() check ran first in this frame.
  const { data: card, error } = await supabase
    .from('cards')
    .select('...')
    .eq('id', id)
    .single();
  // ...
}
```

The duplicate `getUser()` call adds ~5-15ms of latency (cookie-only check, no network round-trip when the JWT is fresh) and saves the bad-UX 404. Apply to any authenticated page that runs an RLS-scoped query — relying solely on the layout's redirect is racy.

### Why not move the auth check to middleware

Middleware doesn't have access to React Server Component data-fetch context — it can intercept the request and redirect based on cookies, but it can't see what the page's `select()` is about to query. Middleware redirects work for the static case (unauthenticated → `/login`) — that defense IS in place at `apps/web/middleware.ts`. The race is specifically for the moment AFTER the middleware passes (because cookies say "authenticated") but BEFORE the layout's defense-in-depth `getUser()` resolves.

### Where this surfaces

- Fresh-after-POST navigations where the action invalidates the auth cookie (sign-out from the (app) header, account deletion) — common path.
- Stale session in a long-lived tab where the cookie has expired but `middleware.ts`'s `try/catch` falls through as "anonymous" (intentional — see `apps/web/middleware.ts`); the page then needs its own gate.
- Any RLS-scoped read inside an authenticated route that doesn't have its own `getUser()` check at the top.

Home-os PR `triage-route-handler` (2026-05-15) hit this exactly — `/cards/[id]` produced a 404 instead of `/login` for invitees on first-cold-load. Fixed at `apps/web/app/(app)/cards/[id]/page.tsx` by adding the `getUser()` + early redirect.

---

## Cross-references

- `/ak-new-project § Step 12 (Scaffold apps/web)` — the entry point that should apply Patterns 1, 2, 3 at scaffold time
- `/ak-implement` — when adding a new env-var read site (Pattern 1), Realtime-using table (Pattern 4), or E2E test (Patterns 5 + 6)
- `/ak-tests-review` — when reviewing E2E specs, flag direct-goto on WebKit (Pattern 5), missing realtime publication migration (Pattern 4), and `route().fulfill(503)` on realtime WS endpoints (Pattern 6)
- `kit/docs/guide/migrations.md § Supabase Hardening Defaults` — high-level rule pointing at this guide
- `kit/docs/guide/wrapper-boundaries.md § Wrapper API design` — companion rule that makes Pattern 6's banner-trigger path reachable
- Lalista PR 26 (2026-04-26) — the source incident for Patterns 1, 2, 3, 4 (carry-forward), 5, and Pattern 6 (initial 503-fulfill shape)
- Lalista PR 27 (2026-04-27) — Pattern 6 fix shipped (`routeWebSocket` switch + wrapper-side `onError` extension)
- Home-os PR #15 (2026-05-14) — sources of Patterns 9 (lifted verbatim from lalista's mature helper) and 10 (host-anchored redirect debugged on slow-job)
