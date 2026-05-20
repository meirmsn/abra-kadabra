// What: Next.js config for the apps/web shell — Sentry source-map upload wrapper,
//       PostHog runtime instrumentation, and host normalization for HMR + auth.
// Why: One file ships the cross-cutting wirings (telemetry, dev-host policy)
//      so per-feature work doesn't reach for them. `allowedDevOrigins`
//      includes both `localhost` AND `127.0.0.1` because Supabase emits auth
//      URLs rooted at `127.0.0.1` while Next 16 prefers `localhost` for HMR
//      — without both, cross-origin HMR is blocked by default in Next 16.
// Does NOT: Define env vars (they live in `.env.local` per
//           `/ak-new-project § Step 13b`) or set CSP headers — those
//           belong in THIS file via the Pattern 2 `connect-src` builder
//           (`kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 2`),
//           added when Supabase / Realtime wiring lands.

import { withSentryConfig } from '@sentry/nextjs';
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  allowedDevOrigins: ['localhost', '127.0.0.1'],
  transpilePackages: ['@PROJECT_NAME_PLACEHOLDER/core'],
  typedRoutes: true,
};

export default withSentryConfig(nextConfig, {
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  authToken: process.env.SENTRY_AUTH_TOKEN,
  silent: !process.env.CI,
  widenClientFileUpload: true,
});
