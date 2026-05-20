// What: Edge proxy that refreshes the Supabase session on every request
//       via `@supabase/ssr`, so SSR routes always see a current auth
//       state. Defensively `.trim()`s every `NEXT_PUBLIC_*` env read per
//       supabase-ssr-boilerplate Pattern 1 — trailing-whitespace
//       fat-fingers silently 500 SSR routes otherwise.
// Why: Without proxy-side refresh, a stale cookie hits an SSR route with
//       `getUser()` returning null even though the user is signed in; UI
//       re-renders as anonymous and bounces to `/sign-in`. Filename +
//       export name both follow the Next 16 convention (`proxy.ts` +
//       `export async function proxy`); renamed from `middleware.ts` +
//       `export async function middleware`.
// Does NOT: Enforce auth-gated routes (per-route guards do that) or set
//           CSP headers (extend this file if needed per Pattern 2).
//
// File-doc exemption: `proxy.ts` is on the test-coverage exempt list per
// `kit/docs/guide/conventions.md § Test Presence` (entry-point).

import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request: { headers: request.headers } });

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim();

  if (!supabaseUrl || !supabaseAnonKey) return response;

  type CookieToSet = { name: string; value: string; options: CookieOptions };

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (cookiesToSet: CookieToSet[]) => {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        );
        response = NextResponse.next({ request: { headers: request.headers } });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options)
        );
      },
    },
  });

  await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
