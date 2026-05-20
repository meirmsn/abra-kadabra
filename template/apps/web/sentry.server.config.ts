// What: Server-side Sentry init for the Node.js runtime — captures
//       errors from SSR rendering, Route Handlers, and Server Actions.
// Why: Server errors don't surface to the browser SDK; without server
//       init, they're invisible past `console.error`.
// Does NOT: Run on the Edge runtime (that's `sentry.edge.config.ts`).

import * as Sentry from '@sentry/nextjs';

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN?.trim() ?? process.env.SENTRY_DSN?.trim();

if (dsn) {
  Sentry.init({
    dsn,
    tracesSampleRate: 0.1,
    environment: process.env.NODE_ENV,
  });
}
