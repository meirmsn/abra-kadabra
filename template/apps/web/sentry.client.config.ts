// What: Client-side Sentry init — captures errors + traces from the
//       browser bundle and ships them to the configured DSN.
// Why: Without this, runtime errors thrown in the client surface only as
//       console noise; Sentry's PR + release annotations rely on the
//       browser SDK being initialized for every page.
// Does NOT: Init the server SDK (that's `instrumentation.ts` /
//           `sentry.server.config.ts`); both are required to capture
//           errors across runtime boundaries.

import * as Sentry from '@sentry/nextjs';

const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN?.trim();

if (dsn) {
  Sentry.init({
    dsn,
    tracesSampleRate: 0.1,
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 1.0,
    environment: process.env.NODE_ENV,
  });
}
