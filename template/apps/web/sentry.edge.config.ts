// What: Edge-runtime Sentry init for middleware and edge route handlers.
// Why: Edge code runs in a different runtime than Node.js — needs its
//       own Sentry init to capture middleware errors and edge route
//       failures.
// Does NOT: Run on Node.js (that's `sentry.server.config.ts`) or in the
//           browser (`sentry.client.config.ts`).

import * as Sentry from '@sentry/nextjs';

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN?.trim() ?? process.env.SENTRY_DSN?.trim();

if (dsn) {
  Sentry.init({
    dsn,
    tracesSampleRate: 0.1,
    environment: process.env.NODE_ENV,
  });
}
