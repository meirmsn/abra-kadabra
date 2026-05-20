// What: Next.js instrumentation entry — fires once at server start to
//       initialize Sentry on the correct runtime (Node.js for SSR + API
//       routes; Edge for middleware + edge functions).
// Why: Sentry's `@sentry/nextjs` package needs separate init paths per
//       runtime; the `register()` hook is the Next-supplied seam for that
//       wiring.
// Does NOT: Initialize client-side Sentry (that's `sentry.client.config.ts`,
//           imported by Next's client bootstrap automatically).
//
// File-doc exemption: `instrumentation.ts` is on the test-coverage exempt
// list per `kit/docs/guide/conventions.md § Test Presence` (entry-point).

export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./sentry.server.config');
  }
  if (process.env.NEXT_RUNTIME === 'edge') {
    await import('./sentry.edge.config');
  }
}
