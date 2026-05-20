// What: Vitest config for unit tests in apps/web — wires the `@/` alias to
//       match tsconfig.json so `import "@/lib/foo"` resolves at runtime.
// Why: Next's tsconfig `paths` only resolves at compile time. Vitest does
//      not consume tsconfig paths by default — first test importing via
//      `@/...` fails with "Failed to load url @/lib/...". Codified in
//      `/ak-new-project § Step 12.5`; promoted here as a checked-in baseline.
// Does NOT: Configure E2E (Playwright owns that via `playwright.config.ts`)
//           or run integration tests against a live Supabase stack
//           (those run from `*.integration.test.ts` files with their own setup).

import path from 'node:path';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './'),
    },
  },
  test: {
    environment: 'jsdom',
    include: ['**/*.test.{ts,tsx}'],
    exclude: ['node_modules', '.next', 'e2e/**'],
    setupFiles: ['./vitest.setup.ts'],
  },
});
